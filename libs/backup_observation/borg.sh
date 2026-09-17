#!/usr/bin/env bash
# Author: GauchoCode
# Version: 0.2.0
################################################################################
# Borg observation adapter. Tested profile: borg 1.2.x structured JSON output
# (`borg info --json`, `borg list --json`) with a non-executing PyYAML safe_load
# parser for Borgmatic configurations. No hooks are run, no human output is
# scraped, and no repository is initialized. Read-only repository access uses
# the operator-approved unencrypted/relocated-access environment flags; see
# docs/backup-observation-compatibility.md.
################################################################################

readonly BO_BORG_SUPPORTED_MAJOR_MINOR="1.2"
readonly BO_BORG_SUPPORTED_VERSION="1.2.0"
readonly BO_BORG_LIST_TIMEOUT=120
readonly BO_BORG_MAX_CAPTURED_ARCHIVES=10000

bo_borg_exec_path() {
    if [[ ${BROLIT_OBSERVER_TEST_MODE:-0} == "1" && -n "${BO_EXEC_PATH:-}" ]]; then
        printf '%s' "${BO_EXEC_PATH}"
    else
        printf '%s' '/usr/bin:/bin'
    fi
}

bo_borg_tool_path() {
    if [[ ${BROLIT_OBSERVER_TEST_MODE:-0} == "1" && -n "${BO_TOOL_PATH:-}" ]]; then
        printf '%s' "${BO_TOOL_PATH}"
    else
        printf '%s' '/usr/bin:/bin'
    fi
}

bo_borg_remaining_timeout() {
    local now_ns remaining_ns remaining_ms
    now_ns="$(bo_monotonic_ns)"
    remaining_ns=$((BO_MAX_RUNTIME_SECONDS * 1000000000 - now_ns + BO_START_MONOTONIC_NS))
    remaining_ms=$((remaining_ns / 1000000))
    [[ ${remaining_ms} -gt 0 ]] || return 1
    printf '%d.%03ds' $((remaining_ms / 1000)) $((remaining_ms % 1000))
}

################################################################################
# Run python3 helpers in a minimal local environment. No network access is
# requested; provider access goes only through bo_borg_exec.
################################################################################
bo_python_profile() {
    local timeout_value
    timeout_value="$(bo_borg_remaining_timeout)" || return 124
    timeout "${timeout_value}" env -i PATH="$(bo_borg_tool_path)" LC_ALL=C python3 "${BO_MAIN_DIR}/libs/backup_observation/borgmatic_profile.py" "$@"
}

bo_hmac_sha256() {
    printf '%s\0%s' "${1}" "${2}" | bo_python_profile hmac
}

################################################################################
# Probe the safe YAML parser profile. Does not install anything.
################################################################################
bo_borg_parser_available() {
    # /dev/null is empty and therefore invalid YAML input, but a missing parser
    # exits the same path with status "unsupported"; distinguish via output.
    local probe probe_status
    probe="$(bo_python_profile parse-yml /dev/null 2>/dev/null)"
    probe_status=$?
    [[ ${probe_status} -eq 0 && ( "${probe}" == *'"status":"invalid"'* || "${probe}" == *'"status":"ok"'* ) ]]
}

################################################################################
# Probe the structured Borg profile (1.2.x). Version is read locally; no
# repository is contacted here.
################################################################################
bo_borg_profile_version() {
    local version timeout_value version_status
    BO_BORG_PROFILE_ERROR_CODE="unsupported_version"
    timeout_value="$(bo_borg_remaining_timeout)" || { BO_BORG_PROFILE_ERROR_CODE="budget_exceeded"; return 1; }
    version="$(env -i PATH="$(bo_borg_exec_path)" LC_ALL=C BO_ATTEMPT_LOG="${BO_ATTEMPT_LOG-}" timeout "${timeout_value}" borg --version 2>/dev/null)"
    version_status=$?
    [[ ${version_status} -eq 124 ]] && BO_BORG_PROFILE_ERROR_CODE="budget_exceeded"
    if [[ ${version_status} -eq 0 && "${version}" == "borg ${BO_BORG_SUPPORTED_VERSION}" ]]; then
            printf '%s' "${BO_BORG_SUPPORTED_VERSION}"
            return 0
    fi
    return 1
}

################################################################################
# Execute read-only Borg metadata commands with bounded time and a minimal
# environment. Only list/info are ever requested by callers.
################################################################################
bo_borg_exec() {
    local timeout_value
    timeout_value="$(bo_borg_remaining_timeout)" || return 124
    case "${1:-}" in
        info|list) ;;
        *) return 125 ;;
    esac
    env -i PATH="$(bo_borg_exec_path)" HOME=/root LC_ALL=C \
        BO_ATTEMPT_LOG="${BO_ATTEMPT_LOG-}" \
        BROLIT_OBSERVER_TEST_BORG_MODE="${BROLIT_OBSERVER_TEST_BORG_MODE-}" \
        BORG_RSH='ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=15' \
        BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes \
        BORG_RELOCATED_REPO_ACCESS_IS_OK=yes \
        timeout "${timeout_value}" borg "$@"
}

bo_borg_status_code() {
    case "${1}" in
        124|137|143|153) printf 'budget_exceeded' ;;
        *) bo_borg_error_code "${2:-}" ;;
    esac
}

bo_borg_token_key() {
    if [[ ${BROLIT_OBSERVER_TEST_MODE:-0} == "1" && -n "${BO_BORG_TEST_TOKEN_KEY:-}" ]]; then
        printf '%s' "${BO_BORG_TEST_TOKEN_KEY}"
    elif [[ -r /etc/shadow && ! -L /etc/shadow && -s /etc/shadow ]]; then
        sha256sum /etc/shadow | cut -d' ' -f1
    elif [[ -r /root/.config/brolit/backup-observer-token-key && ! -L /root/.config/brolit/backup-observer-token-key && -s /root/.config/brolit/backup-observer-token-key ]]; then
        local owner_mode
        owner_mode="$(stat -c '%u %a' /root/.config/brolit/backup-observer-token-key 2>/dev/null || true)"
        [[ "${owner_mode}" == "0 400" || "${owner_mode}" == "0 600" ]] || return 1
        sha256sum /root/.config/brolit/backup-observer-token-key | cut -d' ' -f1
    fi
}

bo_borg_exec_capture() {
    local output_file="${1}" error_file="${2}"
    shift 2
    local max_blocks=$(( (BO_MAX_REPORT_BYTES + 511) / 512 + 1 ))
    (ulimit -f "${max_blocks}" 2>/dev/null || exit 125; bo_borg_exec "$@") >"${output_file}" 2>"${error_file}"
}

################################################################################
# Validate a repository URL before it can reach a subprocess argument.
################################################################################
bo_borg_valid_repo_url() {
    [[ "${1}" =~ ^ssh://[A-Za-z0-9._-]+@[A-Za-z0-9._:-]+/[A-Za-z0-9./_-]+$ && ${#1} -le 1024 ]]
}

################################################################################
# Map bounded Borg stderr text onto the protocol error taxonomy.
################################################################################
bo_borg_error_code() {
    local stderr_text="${1}"
    case "${stderr_text}" in
        *"Failed to create"*"lock"*|*lock*|*Lock*|*LOCK*|*"Busy"*) printf 'busy_locked' ;;
        *"passphrase"*|*"Permission denied"*|[Aa]uthentication*) printf 'authentication' ;;
        *"does not exist"*|*"no such"*) printf 'repository_missing' ;;
        *"not a valid repository"*|*"Invalid"*[Rr]epository*) printf 'repository_invalid' ;;
        *"timed out"*|*"Connection"*|*"Network"*|*"Name or service"*) printf 'unreachable' ;;
        *) printf 'malformed_response' ;;
    esac
}

################################################################################
# Parse one Borgmatic file through the safe profile. Prints compact JSON.
################################################################################
bo_borg_parse_config() {
    bo_python_profile parse-yml "${1}" 2>/dev/null
}

bo_borg_parse_error_code() {
    case "${1}" in
        124|137|143) printf 'budget_exceeded' ;;
        *) printf 'invalid_configuration' ;;
    esac
}

################################################################################
# Convert a naive Borg timestamp to UTC using the configured server timezone.
# Prints the contract timestamp or nothing when conversion is not possible.
################################################################################
bo_borg_to_utc() {
    local result result_status
    result="$(bo_python_profile to-utc "${1}" "${BACKUP_OBSERVATION_TIMEZONE:-UTC}" 2>/dev/null)"
    result_status=$?
    if [[ ${result_status} -eq 0 && "${result}" == *'"status":"ok"'* ]]; then
        printf '%s' "${result}" | "${BO_JQ_BIN}" -r '.value' 2>/dev/null
    fi
}

################################################################################
# Discover Borg locations: parse every Borgmatic file, resolve repositories,
# and probe each repository identity with a read-only borg info. Populates
# BO_BORG_DISCOVERY_ITEMS and BO_BORG_DISCOVERY_ERRORS.
################################################################################
bo_borg_discover() {
    BO_BORG_DISCOVERY_ITEMS='[]'
    BO_BORG_DISCOVERY_ERRORS='[]'

    if [[ ${BACKUP_OBSERVATION_BORG_STATUS:-disabled} != "enabled" ]]; then
        return 0
    fi
    if ! bo_borg_parser_available; then
        BO_BORG_DISCOVERY_ERRORS="[$(bo_error_json "${BO_SCOPE_JSON}" "dependency_unavailable" "" "A tested non-executing YAML parser is unavailable." false)]"
        return 1
    fi

    local borgmatic_dir="/etc/borgmatic.d"
    if [[ ${BROLIT_OBSERVER_TEST_MODE:-0} == "1" && -n "${BROLIT_OBSERVER_TEST_BORGMATIC_DIR:-}" ]]; then
        borgmatic_dir="${BROLIT_OBSERVER_TEST_BORGMATIC_DIR}"
    fi
    if [[ ! -d "${borgmatic_dir}" || -L "${borgmatic_dir}" ]]; then
        local missing_dir_error
        missing_dir_error="$(bo_error_json "${BO_SCOPE_JSON}" "inaccessible_path" "" "The Borgmatic configuration directory is unavailable." false)"
        BO_BORG_DISCOVERY_ERRORS="[${missing_dir_error}]"
        return 1
    fi

    local config_file suffix parsed status parse_exit repo_count index repo_path location_id item error_json retention_value schedule_json retention_json config_count=0
    for config_file in "${borgmatic_dir}"/*.yml; do
        [[ -f "${config_file}" && ! -L "${config_file}" ]] || continue
        config_count=$((config_count + 1))
        if ! bo_within_runtime_budget; then
            BO_BORG_DISCOVERY_ERRORS="[$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "The collector runtime budget was exceeded during Borg discovery." false)]"
            return 1
        fi
        suffix="$(basename -- "${config_file}" .yml)"
        [[ "${suffix}" == *[!A-Za-z0-9._:-]* ]] && continue
        if [[ ${#suffix} -gt 90 ]]; then
            local overlong_error
            overlong_error="$(bo_error_json "${BO_SCOPE_JSON}" "invalid_configuration" "" "A Borgmatic configuration filename exceeds the observer handle bound." false)"
            BO_BORG_DISCOVERY_ERRORS="$(${BO_JQ_BIN} -cn --argjson errors "${BO_BORG_DISCOVERY_ERRORS}" --argjson error "${overlong_error}" '$errors + [$error]')"
            continue
        fi

        parsed="$(bo_borg_parse_config "${config_file}")"
        parse_exit=$?
        status="$(printf '%s' "${parsed}" | "${BO_JQ_BIN}" -r '.status' 2>/dev/null || printf 'invalid')"
        if [[ ${parse_exit} -ne 0 || "${status}" != "ok" ]]; then
            # A broken configuration retains diagnostic evidence without
            # claiming that historical backups do not exist. Errors carry the
            # location scope so they stay linked to their discovery item.
            local broken_scope
            broken_scope="$("${BO_JQ_BIN}" -cn --arg sid "${BO_SOURCE_ID}" --arg lid "borg-${suffix}-r0" '{kind:"location",source_id:$sid,provider:"borg",location_id:$lid}')"
            error_json="$(bo_error_json "${broken_scope}" "$(bo_borg_parse_error_code "${parse_exit}")" "" "Borgmatic configuration could not be parsed by the supported profile." false)"
            BO_BORG_DISCOVERY_ERRORS="$("${BO_JQ_BIN}" -cn --argjson errors "${BO_BORG_DISCOVERY_ERRORS}" --argjson error "${error_json}" '$errors + [$error]')"
            item="$(bo_borg_discovery_item "${suffix}" 0 "${config_file}" "" "${parsed}" failed null)"
            BO_BORG_DISCOVERY_ITEMS="$("${BO_JQ_BIN}" -cn --argjson items "${BO_BORG_DISCOVERY_ITEMS}" --argjson item "${item}" '$items + [$item]')"
            continue
        fi

        repo_count="$(printf '%s' "${parsed}" | "${BO_JQ_BIN}" -r '.repositories | length')"
        for ((index = 0; index < repo_count; index++)); do
            repo_path="$(printf '%s' "${parsed}" | "${BO_JQ_BIN}" -r --argjson i "${index}" '.repositories[$i].path')"
            location_id="borg-${suffix}-r${index}"
            if ! bo_borg_valid_repo_url "${repo_path}"; then
                local invalid_scope
                invalid_scope="$("${BO_JQ_BIN}" -cn --arg sid "${BO_SOURCE_ID}" --arg lid "${location_id}" '{kind:"location",source_id:$sid,provider:"borg",location_id:$lid}')"
                error_json="$(bo_error_json "${invalid_scope}" "invalid_configuration" "" "Repository path is not an authorized Borg SSH URL." false)"
                BO_BORG_DISCOVERY_ERRORS="$("${BO_JQ_BIN}" -cn --argjson errors "${BO_BORG_DISCOVERY_ERRORS}" --argjson error "${error_json}" '$errors + [$error]')"
                item="$(bo_borg_discovery_item "${suffix}" "${index}" "${config_file}" "" "${parsed}" failed null)"
                BO_BORG_DISCOVERY_ITEMS="$("${BO_JQ_BIN}" -cn --argjson items "${BO_BORG_DISCOVERY_ITEMS}" --argjson item "${item}" '$items + [$item]')"
                continue
            fi

            local probe probe_status repo_id probe_file="${BO_TEMP_DIR}/borg-probe.json" probe_exit
            bo_borg_exec_capture "${probe_file}" "${BO_TEMP_DIR}/borg-probe.err" info --json "${repo_path}"
            probe_exit=$?
            if [[ $(wc -c <"${probe_file}") -gt ${BO_MAX_REPORT_BYTES} ]]; then
                probe=''
            else
                probe="$(cat "${probe_file}")"
            fi
            probe_status=""
            [[ ${probe_exit} -eq 0 ]] && probe_status="$(printf '%s' "${probe}" | "${BO_JQ_BIN}" -r '.repository.id // empty' 2>/dev/null || true)"
            if [[ -n "${probe_status}" ]]; then
                repo_id="${probe_status}"
                item="$(bo_borg_discovery_item "${suffix}" "${index}" "${repo_path}" "${repo_id}" "${parsed}" complete true)"
            else
                local code
                code="$(bo_borg_status_code "${probe_exit}" "$(head -c 512 "${BO_TEMP_DIR}/borg-probe.err" 2>/dev/null || true)")"
                error_json="$(bo_error_json "$("${BO_JQ_BIN}" -cn --arg sid "${BO_SOURCE_ID}" --arg lid "${location_id}" '{kind:"location",source_id:$sid,provider:"borg",location_id:$lid}')" "${code}" "" "Repository identity could not be observed." true)"
                BO_BORG_DISCOVERY_ERRORS="$("${BO_JQ_BIN}" -cn --argjson errors "${BO_BORG_DISCOVERY_ERRORS}" --argjson error "${error_json}" '$errors + [$error]')"
                item="$(bo_borg_discovery_item "${suffix}" "${index}" "${repo_path}" "" "${parsed}" failed null)"
            fi
            BO_BORG_DISCOVERY_ITEMS="$("${BO_JQ_BIN}" -cn --argjson items "${BO_BORG_DISCOVERY_ITEMS}" --argjson item "${item}" '$items + [$item]')"
        done
    done

    if [[ ${config_count} -eq 0 ]]; then
        local empty_dir_error
        empty_dir_error="$(bo_error_json "${BO_SCOPE_JSON}" "inaccessible_path" "" "The Borgmatic configuration directory contains no usable configuration files." false)"
        BO_BORG_DISCOVERY_ERRORS="[${empty_dir_error}]"
        return 1
    fi

    return 0
}

################################################################################
# Build one discovery item. Resource hints come from configuration constants;
# schedule is unknown in this profile because cron belongs to a separate
# collection path.
################################################################################
bo_borg_discovery_item() {
    local suffix="${1}" index="${2}" repo_path="${3}" repo_id="${4}" parsed="${5}" item_outcome="${6}" probed="${7}"
    local location_id="borg-${suffix}-r${index}"
    local project db_hints classification retention_value retention_reason

    project="$(printf '%s' "${parsed}" | "${BO_JQ_BIN}" -r '.project // empty' 2>/dev/null || true)"
    db_hints="$(printf '%s' "${parsed}" | "${BO_JQ_BIN}" -r '.database_hints | length' 2>/dev/null || printf '0')"
    if [[ ${db_hints} -gt 0 && "${suffix}" == database.* ]]; then
        classification="database"
    elif [[ ${db_hints} -gt 0 ]]; then
        classification="mixed"
    elif [[ "${suffix}" == database.* ]]; then
        classification="database"
    else
        classification="files"
    fi
    retention_value="$(printf '%s' "${parsed}" | "${BO_JQ_BIN}" -r 'if .retention then (.retention | to_entries | map("\(.key)=\(.value)") | join(",")) else empty end' 2>/dev/null || true)"
    retention_reason=""
    if [[ ${#retention_value} -gt 512 ]]; then
        retention_value=""
        retention_reason="Retention configuration exceeds the wire contract bound."
    fi

    local identity_kind="provisional_origin_scoped" repo_json="null"
    if [[ -n "${repo_id}" && ${#repo_id} -le 128 && "${repo_id}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
        identity_kind="native"
        repo_json="\"${repo_id}\""
    fi

    local hints_json='[]'
    if [[ -n "${project}" && "${project}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
        hints_json="$("${BO_JQ_BIN}" -cn --arg hint "${project}" '[{resource_hint:$hint,provenance:"configuration",confidence:"confirmed"}]')"
    fi

    "${BO_JQ_BIN}" -cn \
        --arg cid "${suffix}" --arg sid "${BO_SOURCE_ID}" --arg lid "${location_id}" \
        --arg outcome "${item_outcome}" --arg root "${repo_path}" --arg identity_kind "${identity_kind}" \
        --argjson repo_id "${repo_json}" --argjson hints "${hints_json}" \
        --arg retention "${retention_value}" --arg retention_reason "${retention_reason}" \
        --arg generation "${BACKUP_OBSERVATION_BORG_STATUS}" \
        --arg class_reason "classification: ${classification}" '
      {
        configuration_id: $cid,
        scope: {kind:"location", source_id:$sid, provider:"borg", location_id:$lid},
        outcome: $outcome,
        generation_enabled: ($generation == "enabled"),
        destination: {identity_kind:$identity_kind, account_id:null, namespace_id:null, repository_native_id:$repo_id, authorized_root:$root},
        resource_hints: $hints,
        schedule: {value:null, reason:"Cron schedules are collected by the inventory path, not the backup observer."},
        retention: (if $retention == "" then {value:null, reason:(if $retention_reason == "" then "No retention is defined in this configuration." else $retention_reason end)} else {value:$retention, reason:null} end)
      }'
}

################################################################################
# Inventory one Borg location. The request handle resolves to a Borgmatic file
# plus repository index; the full archive listing is captured once (bounded)
# and served as contract pages.
################################################################################
bo_borg_inventory() {
    local parsed status parse_exit repo_count index repo_path
    parsed="$(bo_borg_parse_config "${BO_RESOLVED_CONFIG}")"
    parse_exit=$?
    status="$(printf '%s' "${parsed}" | "${BO_JQ_BIN}" -r '.status' 2>/dev/null || printf 'invalid')"
    if [[ ${parse_exit} -ne 0 || "${status}" != "ok" ]]; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "$(bo_borg_parse_error_code "${parse_exit}")" "" "Borgmatic configuration could not be parsed by the supported profile." false)"
        return 1
    fi

    index="${BO_RESOLVED_REPO_INDEX}"
    repo_count="$(printf '%s' "${parsed}" | "${BO_JQ_BIN}" -r '.repositories | length')"
    if [[ ${index} -ge ${repo_count} ]]; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "scope_unresolved" "" "The repository index is no longer present in the configuration." false)"
        return 1
    fi
    repo_path="$(printf '%s' "${parsed}" | "${BO_JQ_BIN}" -r --argjson i "${index}" '.repositories[$i].path')"
    if ! bo_borg_valid_repo_url "${repo_path}"; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "invalid_configuration" "" "Repository path is not an authorized Borg SSH URL." false)"
        return 1
    fi

    if ! bo_borg_profile_version >/dev/null; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "${BO_BORG_PROFILE_ERROR_CODE:-unsupported_version}" "" "The installed Borg version has no tested structured metadata profile." false)"
        return 1
    fi

    local listing listing_file="${BO_TEMP_DIR}/borg-list.json" listing_exit
    bo_borg_exec_capture "${listing_file}" "${BO_TEMP_DIR}/borg-list.err" list --json "${repo_path}"
    listing_exit=$?
    if [[ $(wc -c <"${listing_file}") -gt ${BO_MAX_REPORT_BYTES} ]]; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "The Borg listing exceeded the requested collector budget." false)"
        return 1
    fi
    local listing
    listing="$(cat "${listing_file}")"
    if [[ ${listing_exit} -ne 0 ]] || ! printf '%s' "${listing}" | "${BO_JQ_BIN}" -e '.archives | type == "array"' >/dev/null 2>&1; then
        local code
        code="$(bo_borg_status_code "${listing_exit}" "$(head -c 512 "${BO_TEMP_DIR}/borg-list.err" 2>/dev/null || true)")"
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "${code}" "" "The repository archive listing could not be observed." true)"
        return 1
    fi

    local total
    total="$(printf '%s' "${listing}" | "${BO_JQ_BIN}" -r '.archives | length')"
    if ! printf '%s' "${listing}" | "${BO_JQ_BIN}" -e 'all(.archives[]; (.id|type=="string" and length>=1 and length<=128 and test("^[A-Za-z0-9][A-Za-z0-9._:-]*$")) and (.name|type=="string" and length>=1 and length<=512) and ((.start // .time // null) == null or ((.start // .time)|type=="string" and length<=64))) and (([.archives[].id] | length) == ([.archives[].id] | unique | length))' >/dev/null 2>&1; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "malformed_response" "" "The Borg archive listing contained invalid or duplicate archive identities." false)"
        return 1
    fi
    if [[ ${total} -gt ${BO_BORG_MAX_CAPTURED_ARCHIVES} ]]; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "The repository exceeds the collector archive budget." false)"
        return 1
    fi
    if ! bo_within_runtime_budget; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "The collector runtime budget was exceeded during Borg inventory." false)"
        return 1
    fi

    # Persist compact archive lines once; pages are served deterministically
    # from this capture so continuation tokens cannot re-read the repository.
    printf '%s' "${listing}" | "${BO_JQ_BIN}" -c '.archives[] | {id,name,start,time}' >"${listing_file}"

    BO_BORG_REPOSITORY_PATH="${repo_path}"
    bo_borg_inventory_page "${listing_file}" "${total}"
}

################################################################################
# Serve one contract page from the captured listing. Tokens are opaque
# scan-bound offsets: s<scan hash>o<offset>.
################################################################################
bo_borg_inventory_page() {
    local listing_file="${1}" total="${2}"
    local scan_id mode page_index continuation offset next_offset has_more outcome
    scan_id="$("${BO_JQ_BIN}" -r '.scan.scan_id' <<<"${BO_REQUEST}")"
    mode="$("${BO_JQ_BIN}" -r '.scan.mode' <<<"${BO_REQUEST}")"
    page_index="$("${BO_JQ_BIN}" -r '.scan.page_index' <<<"${BO_REQUEST}")"
    continuation="$("${BO_JQ_BIN}" -r '.scan.continuation // empty' <<<"${BO_REQUEST}")"

    local scan_hash
    scan_hash="$(printf '%s' "${BO_SOURCE_ID}|borg|${BO_LOCATION_ID}|${BO_BORG_REPOSITORY_PATH:-}|${scan_id}|${mode}|${BO_MAX_ITEMS}" | sha256sum | cut -d' ' -f1)"

    offset=0
    if [[ ${page_index} -ge 1 ]]; then
        if [[ ! "${continuation}" =~ ^s${scan_hash}m([A-Fa-f0-9]{64})o([0-9]+)$ ]]; then
            BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "cursor_invalid" "" "The continuation token is unknown, expired, or bound to another scan." false)"
            return 1
        fi
        local supplied_mac="${BASH_REMATCH[1]}"
        offset="${BASH_REMATCH[2]}"
        local token_key actual_mac actual_mac_status
        token_key="$(bo_borg_token_key 2>/dev/null || true)"
        actual_mac="$(bo_hmac_sha256 "${token_key}" "borg-cursor-v1|${scan_hash}|${offset}")"
        actual_mac_status=$?
        if [[ ${actual_mac_status} -ne 0 ]]; then
            local mac_error="dependency_unavailable"
            [[ ${actual_mac_status} -eq 124 ]] && mac_error="budget_exceeded"
            BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "${mac_error}" "" "The continuation token integrity check could not be completed." false)"
            return 1
        fi
        [[ -n "${token_key}" && "${supplied_mac}" == "${actual_mac}" ]] || { BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "cursor_invalid" "" "The continuation token integrity check failed." false)"; return 1; }
        if [[ ${offset} -ne $((page_index * BO_MAX_ITEMS)) || ${offset} -ge ${total} ]]; then
            BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "cursor_invalid" "" "The continuation token does not match the requested page." false)"
            return 1
        fi
    elif [[ -n "${continuation}" ]]; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "cursor_invalid" "" "The first Borg page cannot carry a continuation token." false)"
        return 1
    fi

    next_offset=$((offset + BO_MAX_ITEMS))
    has_more=false
    outcome="complete"
    local next_token_json="null"
    if [[ ${next_offset} -lt ${total} ]]; then
        has_more=true
        outcome="partial"
        local token_key token_mac token_status
        token_key="$(bo_borg_token_key 2>/dev/null || true)"
        token_mac="$(bo_hmac_sha256 "${token_key}" "borg-cursor-v1|${scan_hash}|${next_offset}")"
        token_status=$?
        if [[ ${token_status} -ne 0 ]]; then
            local token_error="dependency_unavailable"
            [[ ${token_status} -eq 124 ]] && token_error="budget_exceeded"
            BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "${token_error}" "" "The continuation token integrity could not be generated." false)"
            return 1
        fi
        [[ -n "${token_key}" && "${token_mac}" =~ ^[A-Fa-f0-9]{64}$ ]] || { BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "dependency_unavailable" "" "A local cursor integrity key is unavailable." false)"; return 1; }
        next_token_json="\"s${scan_hash}m${token_mac}o${next_offset}\""
    fi

    local observed_at items_json
    observed_at="$(bo_timestamp)"
    items_json="$(tail -n +$((offset + 1)) "${listing_file}" | head -n "${BO_MAX_ITEMS}" | while IFS= read -r archive_line; do
        bo_borg_artifact_json "${archive_line}" "${observed_at}"
    done | "${BO_JQ_BIN}" -sc '.')"
    if ! bo_within_runtime_budget; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "The collector runtime budget was exceeded while building the Borg page." false)"
        return 1
    fi

    local pagination_json
    pagination_json="$("${BO_JQ_BIN}" -cn \
        --arg scan_id "${scan_id}" --arg mode "${mode}" --argjson page_index "${page_index}" \
        --argjson has_more "${has_more}" --argjson next_token "${next_token_json}" \
        '{scan_id:$scan_id,mode:$mode,page_index:$page_index,page_complete:true,has_more:$has_more,next_token:$next_token,checkpoint:null,consistency:"best_effort"}')"

    BO_BORG_INVENTORY_ITEMS="${items_json}"
    BO_BORG_INVENTORY_PAGINATION="${pagination_json}"
    BO_BORG_INVENTORY_OUTCOME="${outcome}"
    return 0
}

################################################################################
# Build one artifact. Native id is the Borg archive id; backup_time comes from
# archive metadata converted to UTC. Repository modification time is never
# relabeled as a backup time.
################################################################################
bo_borg_artifact_json() {
    local archive_line="${1}" observed_at="${2}"
    local archive_id name naive_start backup_value classification confidence_hint

    archive_id="$(printf '%s' "${archive_line}" | "${BO_JQ_BIN}" -r '.id')"
    name="$(printf '%s' "${archive_line}" | "${BO_JQ_BIN}" -r '.name')"
    naive_start="$(printf '%s' "${archive_line}" | "${BO_JQ_BIN}" -r '.start // .time // empty')"

    backup_value="$(bo_borg_to_utc "${naive_start}")"

    case "${name}" in
        *_site-files-*) classification="files" ;;
        *-20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*) classification="unknown" ;;
        *) classification="unknown" ;;
    esac

    local time_json hints_json='[]' meta_json='{}'
    if [[ -n "${backup_value}" ]]; then
        time_json="$("${BO_JQ_BIN}" -cn --arg value "${backup_value}" '{value:$value,provenance:"archive_metadata",reason:null}')"
        meta_json="$("${BO_JQ_BIN}" -cn --arg started "${backup_value}" '{archive_started_at:$started}')"
    else
        time_json='{"value":null,"provenance":"unknown","reason":"Archive timestamp could not be converted with the configured timezone."}'
    fi

    # The archive name embeds the project; that is naming inference, never a
    # verified content claim.
    local project_hint=""
    project_hint="${name%%_site-files-*}"
    if [[ "${project_hint}" != "${name}" && "${project_hint}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
        hints_json="$("${BO_JQ_BIN}" -cn --arg hint "${project_hint}" '[{resource_hint:$hint,provenance:"naming_inference",confidence:"inferred"}]')"
        confidence_hint="Naming-derived from the archive name."
    else
        confidence_hint="No naming pattern matched."
    fi

    "${BO_JQ_BIN}" -cn \
        --arg id "${archive_id}" --arg name "${name}" --arg observed_at "${observed_at}" \
        --argjson backup_time "${time_json}" --arg classification "${classification}" \
        --arg class_reason "${confidence_hint}" --argjson hints "${hints_json}" \
        --argjson meta "${meta_json}" '
      {
        native_id: $id, name: $name, path: null, revision: null, presence: "present",
        observed_at: $observed_at,
        backup_time: $backup_time,
        provider_modified_time: {value:null, provenance:"unknown", reason:"Repository modification time is never relabeled as a backup time."},
        classification: {type:$classification, provenance:(if $classification == "unknown" then "unknown" else "naming_inference" end), reason:$class_reason},
        associations: $hints,
        sizes: [],
        metadata: $meta
      }'
}
