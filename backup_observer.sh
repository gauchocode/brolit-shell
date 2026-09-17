#!/bin/bash -p
# Author: GauchoCode
# Version: 0.1.0
################################################################################
# Standalone, root-only backup observation boundary.
#
# This entry point intentionally does not source runner.sh, brolit_lite.sh,
# libs/commons.sh, provider controllers, or script_init.  Stdout is one compact
# protocol object; stderr contains fixed sanitized diagnostics only.
################################################################################

if [[ "$-" != *p* ]]; then
    exec /bin/bash -p "${BASH_SOURCE[0]}" "$@"
fi

set -u

# Fixture overrides are available only through an explicit test-only argument.
# Ambient environment variables must never change the production collector's
# executable paths, configuration roots, credentials, or timing behavior.
BO_TEST_MODE=0
if [[ ${1:-} == "--test-mode" ]]; then
    BO_TEST_MODE=1
    shift
fi
if [[ $# -ne 0 ]]; then
    printf 'backup observer: unsupported arguments\n' >&2
    exit 40
fi
if [[ ${BO_TEST_MODE} -eq 1 ]]; then
    export BROLIT_OBSERVER_TEST_MODE=1
else
    unset BROLIT_OBSERVER_TEST_MODE BO_EXEC_PATH BO_TOOL_PATH BO_BORG_TEST_TOKEN_KEY \
        BROLIT_OBSERVER_TEST_CONFIG_FILE BROLIT_OBSERVER_TEST_BORGMATIC_DIR \
        BROLIT_OBSERVER_TEST_CREDENTIAL_FILE BROLIT_OBSERVER_TEST_DROPBOX_MODE \
        BROLIT_OBSERVER_TEST_BORG_MODE BROLIT_OBSERVER_TEST_DELAY_SECONDS \
        BROLIT_OBSERVER_DISABLE_JQ 2>/dev/null || true
fi

# The production boundary does not inherit executable search paths or shell
# startup hooks from the caller.  The explicit test mode is used only by the
# isolated fixture harness and is never part of the Admin SSH command.
unset BASH_ENV ENV CDPATH PYTHONPATH PYTHONHOME RUBYOPT PERL5OPT 2>/dev/null || true
if [[ ${BROLIT_OBSERVER_TEST_MODE:-0} == "1" && -n "${BO_EXEC_PATH:-}" ]]; then
    export PATH="${BO_EXEC_PATH}:/usr/bin:/bin"
else
    export PATH="/usr/bin:/bin"
fi

readonly BO_MAIN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}" 2>/dev/null)" 2>/dev/null && pwd -P 2>/dev/null || printf '.')"
if [[ ${BROLIT_OBSERVER_TEST_MODE:-0} == "1" && ${BROLIT_OBSERVER_DISABLE_JQ:-0} == "1" ]]; then
    readonly BO_JQ_BIN=""
else
    readonly BO_JQ_BIN="$(command -v jq 2>/dev/null || true)"
fi
export BROLIT_MAIN_DIR="${BO_MAIN_DIR}"

if [[ -z "${BO_JQ_BIN}" || ! -x "${BO_JQ_BIN}" ]]; then
    bo_stderr() { printf 'backup observer: required JSON encoder is unavailable\n' >&2; }
    bo_stderr
    bo_emit_encoder_failure() { :; }
    printf '{"schema_version":"1.0","collector_version":"0.1.0","collection_id":"observer-encoder-unavailable","operation":"capabilities","scope":{"kind":"source","source_id":"observer"},"started_at":"1970-01-01T00:00:00Z","finished_at":"1970-01-01T00:00:00Z","outcome":"unsupported","items":[],"errors":[{"code":"dependency_unavailable","scope":{"kind":"source","source_id":"observer"},"item_id":null,"message":"A required JSON encoder is unavailable.","retryable":false}]}\n'
    exit 30
fi

# This file contains only definitions and its source-time assignments have
# been audited.  No normal loader function is invoked.
# shellcheck source=utils/brolit_configuration_manager.sh
source "${BO_MAIN_DIR}/utils/brolit_configuration_manager.sh"
# shellcheck source=libs/backup_observation/protocol.sh
source "${BO_MAIN_DIR}/libs/backup_observation/protocol.sh"
# shellcheck source=libs/backup_observation/config_projection.sh
source "${BO_MAIN_DIR}/libs/backup_observation/config_projection.sh"
# shellcheck source=libs/backup_observation/borg.sh
source "${BO_MAIN_DIR}/libs/backup_observation/borg.sh"
# shellcheck source=libs/backup_observation/dropbox.sh
source "${BO_MAIN_DIR}/libs/backup_observation/dropbox.sh"

BO_TEMP_DIR=""
BO_INTERRUPTED=0
BO_REQUEST_VALID=0

################################################################################
# Remove bounded temporary state on every exit and signal.
################################################################################
bo_cleanup() {
    if [[ -n "${BO_TEMP_DIR}" && -d "${BO_TEMP_DIR}" ]]; then
        rm -rf -- "${BO_TEMP_DIR}"
    fi
}
trap bo_cleanup EXIT

################################################################################
# Stop on cancellation without allowing a complete report after interruption.
################################################################################
bo_cancel() {
    trap - INT TERM HUP
    BO_INTERRUPTED=1
    if [[ ${BO_REQUEST_VALID:-0} -ne 1 ]]; then
        exit 20
    fi

    local cancellation_error
    local cancellation_pagination="null"
    cancellation_error="$(bo_error_json "${BO_SCOPE_JSON}" "cancelled" "" "Collection was cancelled before the observation completed." false)"
    if [[ ${BO_OPERATION} == "inventory" ]]; then
        cancellation_pagination="$(bo_inventory_pagination false)"
    fi
    bo_emit_report partial '[]' "[${cancellation_error}]" "${cancellation_pagination}"
    exit $?
}
trap bo_cancel INT TERM HUP

################################################################################
# Consume one bounded request without writing it to disk.
################################################################################
bo_read_request() {
    BO_REQUEST="$(head -c $((BO_MAX_REQUEST_BYTES + 1)))"
    local request_bytes
    request_bytes="$(printf '%s' "${BO_REQUEST}" | LC_ALL=C wc -c)"
    [[ ${request_bytes} -ge 1 && ${request_bytes} -le ${BO_MAX_REQUEST_BYTES} ]]
}

################################################################################
# Emit a malformed-request diagnostic without trusting request correlation.
################################################################################
bo_malformed() {
    bo_stderr "malformed or unsupported request"
    exit 40
}

################################################################################
# Load the dedicated read-only configuration projection.
################################################################################
bo_load_projection() {
    local config_file

    config_file="/root/.brolit_conf.json"
    if [[ ${BROLIT_OBSERVER_TEST_MODE:-0} == "1" && -n "${BROLIT_OBSERVER_TEST_CONFIG_FILE:-}" ]]; then
        config_file="${BROLIT_OBSERVER_TEST_CONFIG_FILE}"
    fi
    brolit_configuration_backup_observation_projection "${config_file}" >/dev/null 2>&1
}

################################################################################
# Main dispatch after request validation and the root gate.
################################################################################
bo_dispatch() {
    local errors_json
    local items_json
    local pagination_json="null"

    BO_STARTED_AT="$(bo_timestamp)"
    BO_START_MONOTONIC_NS="$(bo_monotonic_ns)"
    BO_TEMP_DIR="$(mktemp -d /tmp/brolit-observer.XXXXXX 2>/dev/null || true)"
    if [[ -z "${BO_TEMP_DIR}" ]]; then
        errors_json="$(bo_error_json "${BO_SCOPE_JSON}" "internal_error" "" "Unable to create bounded collector state." false)"
        [[ ${BO_OPERATION} == "inventory" ]] && pagination_json="$(bo_inventory_pagination false)"
        bo_emit_report failed '[]' "[${errors_json}]" "${pagination_json}"
        exit $?
    fi

    if ! bo_within_runtime_budget; then
        errors_json="$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "The collector runtime budget was exceeded." false)"
        [[ ${BO_OPERATION} == "inventory" ]] && pagination_json="$(bo_inventory_pagination false)"
        bo_emit_report failed '[]' "[${errors_json}]" "${pagination_json}"
        exit $?
    fi

    if [[ ${EUID} -ne 0 ]]; then
        errors_json="$(bo_error_json "${BO_SCOPE_JSON}" "internal_error" "" "Collector requires root privileges." false)"
        [[ ${BO_OPERATION} == "inventory" ]] && pagination_json="$(bo_inventory_pagination false)"
        bo_emit_report failed '[]' "[${errors_json}]" "${pagination_json}"
        exit $?
    fi

    if [[ ${BROLIT_OBSERVER_TEST_MODE:-0} == "1" && -n "${BROLIT_OBSERVER_TEST_DELAY_SECONDS:-}" ]]; then
        sleep "${BROLIT_OBSERVER_TEST_DELAY_SECONDS}"
    fi

    bo_load_projection
    if [[ ${BACKUP_OBSERVATION_CONFIG_STATUS:-invalid} != "valid" ]]; then
        errors_json="$(bo_error_json "${BO_SCOPE_JSON}" "invalid_configuration" "" "Backup configuration is missing, invalid, or requires migration." false)"
        if [[ ${BO_OPERATION} == "inventory" ]]; then pagination_json="$(bo_inventory_pagination false)"; fi
        bo_emit_report failed '[]' "[${errors_json}]" "${pagination_json}"
        exit 20
    fi

    case "${BO_OPERATION}" in
        capabilities)
            items_json="$(bo_capabilities_items)"
            if ! bo_within_runtime_budget; then
                errors_json="$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "The collector runtime budget was exceeded." false)"
                bo_emit_report failed '[]' "[${errors_json}]"
                exit $?
            fi
            bo_emit_report complete "${items_json}" '[]'
            exit $?
            ;;
        discover)
            # Each provider contributes independently.  A provider failure is
            # retained beside successful locations; an enabled provider with
            # no usable location is unsupported rather than an empty scan.
            local discover_outcome="complete"
            bo_borg_discover || discover_outcome="partial"
            items_json="${BO_BORG_DISCOVERY_ITEMS:-[]}"
            errors_json="${BO_BORG_DISCOVERY_ERRORS:-[]}"
            bo_dropbox_discover || discover_outcome="partial"
            items_json="$(${BO_JQ_BIN} -cn --argjson borg "${items_json}" --argjson dropbox "${BO_DROPBOX_DISCOVERY_ITEMS:-[]}" '$borg + $dropbox')"
            errors_json="$(${BO_JQ_BIN} -cn --argjson borg "${errors_json}" --argjson dropbox "${BO_DROPBOX_DISCOVERY_ERRORS:-[]}" '$borg + $dropbox')"
            if [[ "${errors_json}" != "[]" ]]; then
                if [[ "${items_json}" == "[]" ]]; then
                    discover_outcome="unsupported"
                else
                    discover_outcome="partial"
                fi
            elif [[ "${items_json}" == "[]" ]]; then
                discover_outcome="complete"
            fi
            if [[ ${#items_json} -gt ${BO_MAX_REPORT_BYTES} ]]; then
                discover_outcome="failed"
                items_json='[]'
                errors_json="[$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "Discovery results exceeded the requested byte budget." false)]"
            fi
            if ! bo_within_runtime_budget; then
                discover_outcome="failed"
                items_json='[]'
                errors_json="[$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "The collector runtime budget was exceeded." false)]"
            fi
            bo_emit_report "${discover_outcome}" "${items_json}" "${errors_json}"
            exit $?
            ;;
        inventory)
            if [[ ${BO_PROVIDER} == "dropbox" && $("${BO_JQ_BIN}" -r '.scan.mode' <<<"${BO_REQUEST}") == "incremental" ]]; then
                errors_json="$(bo_error_json "${BO_SCOPE_JSON}" "unsupported_version" "" "Dropbox incremental observation is not supported by this profile." false)"
                pagination_json="$(bo_inventory_pagination false)"
                bo_emit_report unsupported '[]' "[${errors_json}]" "${pagination_json}"
                exit $?
            fi
            if ! bo_resolve_location; then
                errors_json="$(bo_error_json "${BO_SCOPE_JSON}" "scope_unresolved" "" "The requested location handle is not authorized by current configuration." false)"
                pagination_json="$(bo_inventory_pagination false)"
                bo_emit_report failed '[]' "[${errors_json}]" "${pagination_json}"
                exit $?
            fi
            if [[ ${BO_PROVIDER} == "borg" ]]; then
                if bo_borg_inventory; then
                    bo_emit_report "${BO_BORG_INVENTORY_OUTCOME}" "${BO_BORG_INVENTORY_ITEMS}" '[]' "${BO_BORG_INVENTORY_PAGINATION}"
                    exit $?
                fi
                errors_json="${BO_PROVIDER_ERROR_JSON}"
            else
                if bo_dropbox_inventory; then
                    bo_emit_report "${BO_DROPBOX_INVENTORY_OUTCOME}" "${BO_DROPBOX_INVENTORY_ITEMS}" '[]' "${BO_DROPBOX_INVENTORY_PAGINATION}"
                    exit $?
                fi
                errors_json="${BO_PROVIDER_ERROR_JSON:-$(bo_error_json "${BO_SCOPE_JSON}" "dependency_unavailable" "" "No tested provider inventory profile is available." false)}"
            fi
            pagination_json="$(bo_inventory_pagination false)"
            bo_emit_report failed '[]' "[${errors_json}]" "${pagination_json}"
            exit $?
            ;;
    esac

    bo_malformed
}

################################################################################
# Construct a complete capabilities item without claiming provider support.
################################################################################
bo_capabilities_items() {
    local borg_tools='[]'
    local dropbox_tools='[]'
    local executable
    local tool_name
    local borg_operations='[]'
    local borg_modes='[]'
    local borg_unavailable='[]'

    # Presence probes do not execute provider binaries. A discovered tool is
    # still not a compatibility claim on its own.
    for tool_name in borg borgmatic yq python curl; do
        case "${tool_name}" in
            python) executable="python3" ;;
            *) executable="${tool_name}" ;;
        esac
        if command -v "${executable}" >/dev/null 2>&1; then
            if [[ ${tool_name} == "curl" ]]; then
                dropbox_tools="$(${BO_JQ_BIN} -cn --argjson tools "${dropbox_tools}" --arg name "${tool_name}" '$tools + [{name:$name,version:null}]')"
            else
                borg_tools="$(${BO_JQ_BIN} -cn --argjson tools "${borg_tools}" --arg name "${tool_name}" '$tools + [{name:$name,version:null}]')"
            fi
        fi
    done

    # Advertise provider operations only when the tested local transport
    # profiles are present.  Credentials and roots remain runtime gates.
    if bo_borg_parser_available && bo_borg_profile_version >/dev/null 2>&1; then
        borg_operations='["discover","inventory"]'
        borg_modes='["full"]'
    else
        borg_unavailable='[{"operation":"discover","reason":"A tested non-executing Borgmatic YAML parser is unavailable."},{"operation":"inventory","reason":"No tested structured Borg metadata profile is available."}]'
    fi

    local dropbox_operations='[]'
    local dropbox_modes='[]'
    local dropbox_unavailable='[{"operation":"discover","reason":"The fixed Dropbox JSON transport profile is unavailable."},{"operation":"inventory","reason":"The fixed Dropbox full-pagination profile is unavailable."},{"operation":"incremental","reason":"Crash-safe checkpoint and replay conformance is not implemented."}]'
    if bo_dropbox_profile_available; then
        dropbox_operations='["discover","inventory"]'
        dropbox_modes='["full"]'
        dropbox_unavailable='[{"operation":"incremental","reason":"Crash-safe checkpoint and replay conformance is not implemented."}]'
    fi

    "${BO_JQ_BIN}" -cn --argjson borg_tools "${borg_tools}" --argjson dropbox_tools "${dropbox_tools}" \
        --argjson borg_operations "${borg_operations}" --argjson borg_modes "${borg_modes}" --argjson borg_unavailable "${borg_unavailable}" \
        --argjson dropbox_operations "${dropbox_operations}" --argjson dropbox_modes "${dropbox_modes}" --argjson dropbox_unavailable "${dropbox_unavailable}" '[
      {provider:"borg", operations:$borg_operations, inventory_modes:$borg_modes, tools:$borg_tools, unavailable:$borg_unavailable},
      {provider:"dropbox", operations:$dropbox_operations, inventory_modes:$dropbox_modes, tools:$dropbox_tools, unavailable:$dropbox_unavailable}
    ]'
}

################################################################################
# Construct failed inventory pagination with no continuation/checkpoint.
################################################################################
bo_inventory_pagination() {
    "${BO_JQ_BIN}" -cn --arg scan_id "$("${BO_JQ_BIN}" -r '.scan.scan_id' <<<"${BO_REQUEST}")" --arg mode "$("${BO_JQ_BIN}" -r '.scan.mode' <<<"${BO_REQUEST}")" --argjson page_index "$("${BO_JQ_BIN}" -r '.scan.page_index' <<<"${BO_REQUEST}")" '{scan_id:$scan_id,mode:$mode,page_index:$page_index,page_complete:false,has_more:false,next_token:null,checkpoint:null,consistency:"best_effort"}'
}

if ! bo_read_request; then
    bo_malformed
fi
if ! bo_validate_request; then
    bo_malformed
fi
bo_load_request
BO_REQUEST_VALID=1
bo_dispatch
