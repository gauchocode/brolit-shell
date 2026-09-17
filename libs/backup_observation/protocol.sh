#!/usr/bin/env bash
# Author: GauchoCode
# Version: 0.1.0
################################################################################
# Backup observation protocol helpers.  This file is definition-only: it does
# not source the normal shell, create files, inspect configuration, or invoke a
# provider.
################################################################################

readonly BO_SCHEMA_VERSION="1.0"
readonly BO_COLLECTOR_VERSION="0.1.0"
readonly BO_MAX_REQUEST_BYTES=16384
readonly BO_MAX_DEPTH=16

################################################################################
# Emit a fixed diagnostic to stderr.
################################################################################
bo_stderr() {
    printf 'backup observer: %s\n' "${1}" >&2
}

################################################################################
# Return an RFC3339 UTC timestamp with no more than millisecond precision.
################################################################################
bo_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

################################################################################
# Return a monotonic nanosecond clock reading.
################################################################################
bo_monotonic_ns() {
    python3 -c 'import time; print(time.monotonic_ns())' 2>/dev/null
}

################################################################################
# Return nonzero after the request's monotonic runtime budget has elapsed.
################################################################################
bo_within_runtime_budget() {
    local now_seconds
    now_seconds="$(bo_monotonic_ns)"
    [[ -n "${now_seconds}" && $((now_seconds - BO_START_MONOTONIC_NS)) -lt $((BO_MAX_RUNTIME_SECONDS * 1000000000)) ]]
}

################################################################################
# Validate JSON duplicate keys and nesting before jq sees the request.
################################################################################
bo_validate_json_transport() {
    if ! command -v python3 >/dev/null 2>&1; then
        return 2
    fi

    python3 -c '
import json
import sys

def pairs(items):
    result = {}
    for key, value in items:
        if key in result:
            raise ValueError("duplicate object key")
        result[key] = value
    return result

def depth(value, level=0):
    if level > 16:
        raise ValueError("object nesting too deep")
    if isinstance(value, dict):
        for child in value.values():
            depth(child, level + 1)
    elif isinstance(value, list):
        for child in value:
            depth(child, level + 1)

try:
    value = json.load(sys.stdin, object_pairs_hook=pairs)
    if not isinstance(value, dict):
        raise ValueError("request is not an object")
    depth(value)
except (ValueError, json.JSONDecodeError, UnicodeDecodeError):
    sys.exit(1)
' <<<"${BO_REQUEST}"
}

################################################################################
# Validate the exact request boundary described by the Admin v1.0 schema.
################################################################################
bo_validate_request() {
    local validation_status

    if [[ ${#BO_REQUEST} -eq 0 || ${#BO_REQUEST} -gt ${BO_MAX_REQUEST_BYTES} ]]; then
        return 1
    fi

    bo_validate_json_transport
    validation_status=$?
    [[ ${validation_status} -ne 0 ]] && return 1

    printf '%s' "${BO_REQUEST}" | "${BO_JQ_BIN}" -e '
      def handle: type == "string" and length >= 1 and length <= 128 and test("^[A-Za-z0-9][A-Za-z0-9._:-]*$");
      def token: type == "null" or (type == "string" and length >= 1 and length <= 4096 and test("^[A-Za-z0-9_-]+$"));
      def source_scope: type == "object" and (keys | sort) == ["kind", "source_id"] and .kind == "source" and (.source_id | handle);
      def location_scope: type == "object" and (keys | sort) == ["kind", "location_id", "provider", "source_id"] and .kind == "location" and (.source_id | handle) and (.provider == "borg" or .provider == "dropbox") and (.location_id | handle);
      def scan: type == "object" and (keys | sort) == ["continuation", "mode", "page_index", "scan_id"] and (.scan_id | handle) and (.mode == "full" or .mode == "incremental") and (.page_index | type == "number" and floor == . and . >= 0 and . <= 1000000) and (.continuation | token) and ((.page_index == 0 and .mode == "full" and .continuation == null) or (.page_index == 0 and .continuation == null) or (.page_index >= 1 and (.continuation | type) == "string"));
      (.schema_version == "1.0") and (.collection_id | handle) and (.operation == "capabilities" or .operation == "discover" or .operation == "inventory") and
      (.scope | source_scope or location_scope) and
      (.budgets | type == "object" and (keys | sort) == ["max_items", "max_report_bytes", "max_runtime_seconds"] and (.max_report_bytes | type == "number" and floor == . and . >= 1024 and . <= 4194304) and (.max_items | type == "number" and floor == . and . >= 1 and . <= 1000) and (.max_runtime_seconds | type == "number" and floor == . and . >= 1 and . <= 300)) and
      (if .operation == "inventory" then (.scope | location_scope) and (.scan | scan) and (if .scope.provider == "borg" then .scan.mode == "full" else true end) and ((keys | sort) == ["budgets", "collection_id", "operation", "scan", "schema_version", "scope"]) else ((.scope | source_scope) and ((keys | sort) == ["budgets", "collection_id", "operation", "schema_version", "scope"])) end)
    ' >/dev/null 2>&1
}

################################################################################
# Load validated request fields into internal variables.
################################################################################
bo_load_request() {
    BO_COLLECTION_ID="$(${BO_JQ_BIN} -r '.collection_id' <<<"${BO_REQUEST}")"
    BO_OPERATION="$(${BO_JQ_BIN} -r '.operation' <<<"${BO_REQUEST}")"
    BO_SCOPE_JSON="$(${BO_JQ_BIN} -c '.scope' <<<"${BO_REQUEST}")"
    BO_SOURCE_ID="$(${BO_JQ_BIN} -r '.scope.source_id' <<<"${BO_REQUEST}")"
    BO_PROVIDER="$(${BO_JQ_BIN} -r '.scope.provider // empty' <<<"${BO_REQUEST}")"
    BO_LOCATION_ID="$(${BO_JQ_BIN} -r '.scope.location_id // empty' <<<"${BO_REQUEST}")"
    BO_MAX_REPORT_BYTES="$(${BO_JQ_BIN} -r '.budgets.max_report_bytes' <<<"${BO_REQUEST}")"
    BO_MAX_ITEMS="$(${BO_JQ_BIN} -r '.budgets.max_items' <<<"${BO_REQUEST}")"
    BO_MAX_RUNTIME_SECONDS="$(${BO_JQ_BIN} -r '.budgets.max_runtime_seconds' <<<"${BO_REQUEST}")"
    BO_SCAN_JSON="$(${BO_JQ_BIN} -c '.scan // null' <<<"${BO_REQUEST}")"
}

################################################################################
# Build one sanitized contract error.  Callers provide only fixed messages.
################################################################################
bo_error_json() {
    "${BO_JQ_BIN}" -cn --argjson scope "${1}" --arg code "${2}" --arg item_id "${3}" --arg message "${4}" --argjson retryable "${5}" '
      {code: $code, scope: $scope, item_id: (if $item_id == "" then null else $item_id end), message: $message, retryable: $retryable}
    '
}

################################################################################
# Emit a report, enforcing the requested encoded-byte and item budgets.
################################################################################
bo_emit_report() {
    local outcome="${1}"
    local items_json="${2}"
    local errors_json="${3}"
    local pagination_json="${4:-null}"
    local report
    local report_bytes
    local item_count

    if [[ $("${BO_JQ_BIN}" -r 'length' <<<"${errors_json}") -gt 64 ]]; then
        outcome="failed"
        items_json='[]'
        errors_json="[$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "The collector produced too many diagnostics for the report budget." false)]"
        if [[ ${BO_OPERATION} == "inventory" ]]; then
            pagination_json="$(bo_inventory_pagination false)"
        fi
    fi

    item_count="$(${BO_JQ_BIN} -r 'length' <<<"${items_json}")"
    if [[ ${item_count} -gt ${BO_MAX_ITEMS} ]]; then
        outcome="failed"
        items_json='[]'
        errors_json="[$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "The report exceeded the requested item budget." false)]"
        if [[ ${BO_OPERATION} == "inventory" ]]; then
            pagination_json="$(bo_inventory_pagination false)"
        fi
    fi

    report="$(${BO_JQ_BIN} -cn \
        --arg collector_version "${BO_COLLECTOR_VERSION}" \
        --arg collection_id "${BO_COLLECTION_ID}" \
        --arg operation "${BO_OPERATION}" \
        --arg started_at "${BO_STARTED_AT}" \
        --arg finished_at "$(bo_timestamp)" \
        --arg outcome "${outcome}" \
        --argjson scope "${BO_SCOPE_JSON}" \
        --argjson items "${items_json}" \
        --argjson errors "${errors_json}" \
        --argjson pagination "${pagination_json}" \
        '{schema_version:"1.0", collector_version:$collector_version, collection_id:$collection_id, operation:$operation, scope:$scope, started_at:$started_at, finished_at:$finished_at, outcome:$outcome, items:$items, errors:$errors} + (if $operation == "inventory" then {pagination:$pagination} else {} end)')"
    report_bytes=$(printf '%s' "${report}" | LC_ALL=C wc -c)

    if [[ ${report_bytes} -gt ${BO_MAX_REPORT_BYTES} ]]; then
        local budget_error
        outcome="failed"
        items_json='[]'
        budget_error="$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "The report exceeded the requested byte budget." false)"
        if [[ ${BO_OPERATION} == "inventory" ]]; then
            pagination_json="$(${BO_JQ_BIN} -cn --arg scan_id "$("${BO_JQ_BIN}" -r '.scan.scan_id' <<<"${BO_REQUEST}")" --arg mode "$("${BO_JQ_BIN}" -r '.scan.mode' <<<"${BO_REQUEST}")" --argjson page_index "$("${BO_JQ_BIN}" -r '.scan.page_index' <<<"${BO_REQUEST}")" '{scan_id:$scan_id,mode:$mode,page_index:$page_index,page_complete:false,has_more:false,next_token:null,checkpoint:null,consistency:"best_effort"}')"
        fi
        report="$(${BO_JQ_BIN} -cn \
            --arg collector_version "${BO_COLLECTOR_VERSION}" --arg collection_id "${BO_COLLECTION_ID}" --arg operation "${BO_OPERATION}" \
            --arg started_at "${BO_STARTED_AT}" --arg finished_at "$(bo_timestamp)" --argjson scope "${BO_SCOPE_JSON}" \
            --argjson pagination "${pagination_json}" --argjson error "${budget_error}" \
            '{schema_version:"1.0",collector_version:$collector_version,collection_id:$collection_id,operation:$operation,scope:$scope,started_at:$started_at,finished_at:$finished_at,outcome:"failed",items:[],errors:[$error]} + (if $operation == "inventory" then {pagination:$pagination} else {} end)')"
        report_bytes=$(printf '%s' "${report}" | LC_ALL=C wc -c)
        if [[ ${report_bytes} -gt ${BO_MAX_REPORT_BYTES} ]]; then
            bo_stderr "unable to encode a report within the requested byte budget"
            return 40
        fi
    fi

    printf '%s\n' "${report}"
    case "${outcome}" in
        complete) return 0 ;;
        partial) return 10 ;;
        failed) return 20 ;;
        unsupported) return 30 ;;
        *) return 20 ;;
    esac
}

################################################################################
# Return a valid failure report for the case where JSON encoding is unavailable.
################################################################################
bo_emit_encoder_failure() {
    local timestamp
    timestamp="$(bo_timestamp 2>/dev/null || printf '1970-01-01T00:00:00Z')"
    printf '{"schema_version":"1.0","collector_version":"0.1.0","collection_id":"observer-encoder-unavailable","operation":"capabilities","scope":{"kind":"source","source_id":"observer"},"started_at":"%s","finished_at":"%s","outcome":"unsupported","items":[],"errors":[{"code":"dependency_unavailable","scope":{"kind":"source","source_id":"observer"},"item_id":null,"message":"A required JSON encoder is unavailable.","retryable":false}]}\n' "${timestamp}" "${timestamp}"
}
