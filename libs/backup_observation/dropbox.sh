#!/usr/bin/env bash
# Author: GauchoCode
# Version: 0.2.0
################################################################################
# Dropbox observation adapter.  This module uses only the fixed Dropbox JSON
# API endpoints below.  The legacy dropbox_uploader helper is never sourced:
# it exposes mutation-capable operations and human table output.
#
# The OAuth refresh exchange and API bearer token are placed only in a mode
# 0600 curl config file inside the observer's bounded temporary directory.
# Curl receives only the config-file path in argv; credentials never enter
# argv, protocol reports, or diagnostics.
################################################################################

readonly BO_DROPBOX_TOKEN_ENDPOINT="https://api.dropboxapi.com/oauth2/token"
readonly BO_DROPBOX_ACCOUNT_ENDPOINT="https://api.dropboxapi.com/2/users/get_current_account"
readonly BO_DROPBOX_LIST_ENDPOINT="https://api.dropboxapi.com/2/files/list_folder"
readonly BO_DROPBOX_CONTINUE_ENDPOINT="https://api.dropboxapi.com/2/files/list_folder/continue"
readonly BO_DROPBOX_MAX_RESPONSE_BYTES=4194304

bo_dropbox_profile_available() {
    command -v curl >/dev/null 2>&1 && command -v base64 >/dev/null 2>&1 || return 1
    local version
    version="$(curl --version 2>/dev/null | sed -n '1s/^curl \([0-9][0-9]*\)\.\([0-9][0-9]*\).*/\1 \2/p')"
    [[ -n "${version}" ]] || return 1
    local major minor
    read -r major minor <<<"${version}"
    (( major > 7 || (major == 7 && minor >= 76) ))
}

bo_dropbox_valid_root() {
    [[ -n "${1}" && "${1}" == /* && ${#1} -le 2048 ]] || return 1
    [[ "${1}" != *$'\x7f'* && "${1}" != *'"'* ]] || return 1
    ! printf '%s' "${1}" | LC_ALL=C grep -q '[[:cntrl:]]'
}

bo_dropbox_credential_path() {
    local configured="${BACKUP_OBSERVATION_DROPBOX_CONFIG_FILE:-}"
    if [[ -n "${configured}" ]]; then
        printf '%s' "${configured}"
    else
        printf '%s' '/root/.dropbox_uploader'
    fi
}

bo_dropbox_error_code() {
    local response_file="${1}" curl_status="${2:-1}"
    if [[ -f "${response_file}" ]]; then
        if "${BO_JQ_BIN}" -e '(.error_summary // "") | test("rate|too[_ ]many|throttle"; "i")' "${response_file}" >/dev/null 2>&1; then
            printf 'rate_limited'
            return
        fi
        if "${BO_JQ_BIN}" -e '(.error[".tag"] // .error.tag // "") == "path"' "${response_file}" >/dev/null 2>&1; then
            printf 'inaccessible_path'
            return
        fi
        if "${BO_JQ_BIN}" -e '(.error[".tag"] // .error.tag // "") == "reset"' "${response_file}" >/dev/null 2>&1; then
            printf 'cursor_invalid'
            return
        fi
    fi
    if [[ ${curl_status} -eq 63 || ${curl_status} -eq 124 || ${curl_status} -eq 137 || ${curl_status} -eq 153 ]]; then
        printf 'budget_exceeded'
    elif [[ ${curl_status} -eq 28 ]]; then
        printf 'timeout'
    elif [[ ${curl_status} -eq 6 || ${curl_status} -eq 7 ]]; then
        printf 'unreachable'
    else
        printf 'authentication'
    fi
}

################################################################################
# Build and execute one fixed endpoint request.  Body and response are files
# within BO_TEMP_DIR; no caller-controlled URL, header, method, or command is
# accepted.
################################################################################
bo_dropbox_request() {
    local operation="${1}" body_file="${2}" response_file="${BO_TEMP_DIR}/dropbox-${1}.json"
    local config_file="${BO_TEMP_DIR}/dropbox-${1}.curl.conf"
    local credential_file app_key app_secret refresh_token token max_time

    credential_file="$(bo_dropbox_credential_path)"
    if [[ ${operation} == "token" ]]; then
        bo_parse_literal_credentials "${credential_file}" || return 41
        app_key="${BO_DROPBOX_APP_KEY}"
        app_secret="${BO_DROPBOX_APP_SECRET}"
        refresh_token="${BO_DROPBOX_REFRESH_TOKEN}"
    else
        token="${BO_DROPBOX_ACCESS_TOKEN:-}"
        [[ -n "${token}" ]] || return 41
    fi

    local now_ns remaining_ns remaining_ms
    now_ns="$(bo_monotonic_ns)"
    remaining_ns=$((BO_MAX_RUNTIME_SECONDS * 1000000000 - now_ns + BO_START_MONOTONIC_NS))
    remaining_ms=$((remaining_ns / 1000000))
    [[ ${remaining_ms} -gt 0 ]] || return 124
    [[ ${remaining_ms} -gt 60000 ]] && remaining_ms=60000
    max_time="$(printf '%d.%03d' $((remaining_ms / 1000)) $((remaining_ms % 1000)))"

    case "${operation}" in
        token)
            cat >"${config_file}" <<EOF
url = "${BO_DROPBOX_TOKEN_ENDPOINT}"
request = "POST"
user = "${app_key}:${app_secret}"
header = "Content-Type: application/x-www-form-urlencoded"
data = @${body_file}
output = "${response_file}"
silent = true
show-error = true
fail-with-body = true
connect-timeout = 15
max-time = ${max_time}
max-filesize = ${BO_DROPBOX_MAX_RESPONSE_BYTES}
EOF
            ;;
        account)
            cat >"${config_file}" <<EOF
url = "${BO_DROPBOX_ACCOUNT_ENDPOINT}"
request = "POST"
header = "Authorization: Bearer ${token}"
header = "Content-Type: application/json"
data = @${body_file}
output = "${response_file}"
silent = true
show-error = true
fail-with-body = true
connect-timeout = 15
max-time = ${max_time}
max-filesize = ${BO_DROPBOX_MAX_RESPONSE_BYTES}
EOF
            ;;
        list)
            cat >"${config_file}" <<EOF
url = "${BO_DROPBOX_LIST_ENDPOINT}"
request = "POST"
header = "Authorization: Bearer ${token}"
header = "Content-Type: application/json"
data = @${body_file}
output = "${response_file}"
silent = true
show-error = true
fail-with-body = true
connect-timeout = 15
max-time = ${max_time}
max-filesize = ${BO_DROPBOX_MAX_RESPONSE_BYTES}
EOF
            ;;
        continue)
            cat >"${config_file}" <<EOF
url = "${BO_DROPBOX_CONTINUE_ENDPOINT}"
request = "POST"
header = "Authorization: Bearer ${token}"
header = "Content-Type: application/json"
data = @${body_file}
output = "${response_file}"
silent = true
show-error = true
fail-with-body = true
connect-timeout = 15
max-time = ${max_time}
max-filesize = ${BO_DROPBOX_MAX_RESPONSE_BYTES}
EOF
            ;;
        *) return 125 ;;
    esac

    chmod 600 "${config_file}" "${body_file}" 2>/dev/null || return 125
    BO_DROPBOX_RESPONSE_FILE="${response_file}"
    bo_safe_provider_exec dropbox curl --config "${config_file}" >/dev/null 2>"${BO_TEMP_DIR}/dropbox-curl.err"
}

bo_dropbox_refresh_token() {
    local body_file="${BO_TEMP_DIR}/dropbox-token.body"
    local request_status
    printf 'grant_type=refresh_token&refresh_token=%s' "${BO_DROPBOX_REFRESH_TOKEN:-}" >"${body_file}"
    if bo_dropbox_request token "${body_file}"; then
        :
    else
        request_status=$?
        BO_PROVIDER_ERROR_CODE="$(bo_dropbox_error_code "${BO_DROPBOX_RESPONSE_FILE:-/dev/null}" "${request_status}")"
        return 1
    fi
    if ! "${BO_JQ_BIN}" -e 'type == "object" and (.access_token | type == "string" and length > 0 and length <= 4096)' "${BO_DROPBOX_RESPONSE_FILE}" >/dev/null 2>&1; then
        BO_PROVIDER_ERROR_CODE="malformed_response"
        return 1
    fi
    BO_DROPBOX_ACCESS_TOKEN="$("${BO_JQ_BIN}" -r '.access_token' "${BO_DROPBOX_RESPONSE_FILE}")"
    [[ "${BO_DROPBOX_ACCESS_TOKEN}" =~ ^[A-Za-z0-9._~-]+$ ]] || { BO_PROVIDER_ERROR_CODE="malformed_response"; return 1; }
    return 0
}

bo_dropbox_account() {
    local body_file="${BO_TEMP_DIR}/dropbox-account.body"
    local request_status
    printf '{}' >"${body_file}"
    if bo_dropbox_request account "${body_file}"; then
        :
    else
        request_status=$?
        BO_PROVIDER_ERROR_CODE="$(bo_dropbox_error_code "${BO_DROPBOX_RESPONSE_FILE:-/dev/null}" "${request_status}")"
        return 1
    fi
    if ! "${BO_JQ_BIN}" -e 'type == "object" and (.account_id | type == "string" and length > 0 and length <= 128)' "${BO_DROPBOX_RESPONSE_FILE}" >/dev/null 2>&1; then
        BO_PROVIDER_ERROR_CODE="malformed_response"
        return 1
    fi
    BO_DROPBOX_ACCOUNT_ID="$("${BO_JQ_BIN}" -r '.account_id' "${BO_DROPBOX_RESPONSE_FILE}")"
    BO_DROPBOX_NAMESPACE_ID="$("${BO_JQ_BIN}" -r '.root_info.root_namespace_id // .root_info.home_namespace_id // empty' "${BO_DROPBOX_RESPONSE_FILE}")"
    if [[ -n "${BO_DROPBOX_NAMESPACE_ID}" && ( ${#BO_DROPBOX_NAMESPACE_ID} -gt 128 || ! "${BO_DROPBOX_NAMESPACE_ID}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ) ]]; then
        BO_DROPBOX_NAMESPACE_ID=""
    fi
    return 0
}

bo_dropbox_discovery_item() {
    local outcome="${1}" root="${2}" account="${3:-}" namespace="${4:-}"
    local identity_kind="provisional_origin_scoped" account_json="null" namespace_json="null"
    if [[ -n "${account}" && "${account}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
        identity_kind="native"
        account_json="\"${account}\""
    fi
    if [[ -n "${namespace}" && "${namespace}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
        namespace_json="\"${namespace}\""
    fi
    "${BO_JQ_BIN}" -cn --arg outcome "${outcome}" --arg sid "${BO_SOURCE_ID}" --arg root "${root}" \
        --arg identity_kind "${identity_kind}" --argjson account_id "${account_json}" --argjson namespace_id "${namespace_json}" \
        --arg generation "${BACKUP_OBSERVATION_DROPBOX_STATUS:-disabled}" '
      {configuration_id:"dropbox-root",scope:{kind:"location",source_id:$sid,provider:"dropbox",location_id:"dropbox-root"},outcome:$outcome,
       generation_enabled:($generation == "enabled"),
       destination:{identity_kind:$identity_kind,account_id:$account_id,namespace_id:$namespace_id,repository_native_id:null,authorized_root:$root},
       resource_hints:[],schedule:{value:null,reason:"Dropbox schedule is not part of this observer profile."},
       retention:{value:null,reason:"Dropbox retention is not exposed by the native listing API."}}'
}

bo_dropbox_discover() {
    BO_DROPBOX_DISCOVERY_ITEMS='[]'
    BO_DROPBOX_DISCOVERY_ERRORS='[]'
    [[ ${BACKUP_OBSERVATION_DROPBOX_STATUS:-disabled} == "enabled" || -n "${BACKUP_OBSERVATION_DROPBOX_ROOT:-}" ]] || return 0

    local root="${BACKUP_OBSERVATION_DROPBOX_ROOT:-}"
    if ! bo_dropbox_valid_root "${root}"; then
        BO_DROPBOX_DISCOVERY_ERRORS="[$(bo_error_json "${BO_SCOPE_JSON}" "invalid_configuration" "" "Dropbox discovery requires an explicit authorized root path." false)]"
        return 1
    fi
    if ! bo_dropbox_profile_available; then
        BO_DROPBOX_DISCOVERY_ERRORS="[$(bo_error_json "${BO_SCOPE_JSON}" "dependency_unavailable" "" "The tested Dropbox JSON transport is unavailable." false)]"
        return 1
    fi
    if ! bo_parse_literal_credentials "$(bo_dropbox_credential_path)"; then
        local location_scope
        location_scope="$("${BO_JQ_BIN}" -cn --arg sid "${BO_SOURCE_ID}" '{kind:"location",source_id:$sid,provider:"dropbox",location_id:"dropbox-root"}')"
        BO_DROPBOX_DISCOVERY_ERRORS="[$(bo_error_json "${location_scope}" "authentication" "" "Dropbox credentials are unavailable or invalid." false)]"
        BO_DROPBOX_DISCOVERY_ITEMS="[$(bo_dropbox_discovery_item failed "${root}")]"
        return 1
    fi
    if ! bo_dropbox_refresh_token || ! bo_dropbox_account; then
        local location_scope code
        location_scope="$("${BO_JQ_BIN}" -cn --arg sid "${BO_SOURCE_ID}" '{kind:"location",source_id:$sid,provider:"dropbox",location_id:"dropbox-root"}')"
        code="${BO_PROVIDER_ERROR_CODE:-authentication}"
        BO_DROPBOX_DISCOVERY_ERRORS="[$(bo_error_json "${location_scope}" "${code}" "" "Dropbox account identity could not be observed." true)]"
        BO_DROPBOX_DISCOVERY_ITEMS="[$(bo_dropbox_discovery_item failed "${root}")]"
        return 1
    fi
    BO_DROPBOX_DISCOVERY_ITEMS="[$(bo_dropbox_discovery_item complete "${root}" "${BO_DROPBOX_ACCOUNT_ID}" "${BO_DROPBOX_NAMESPACE_ID:-}")]"
    return 0
}

bo_dropbox_b64url_encode() {
    printf '%s' "${1}" | base64 | tr -d '\n=' | tr '+/' '-_'
}

bo_dropbox_b64url_decode() {
    local value="${1}" padding=$((4 - ${#1} % 4))
    [[ ${padding} -eq 4 ]] && padding=0
    value="$(printf '%s' "${value}" | tr '_-' '/+')"
    while [[ ${padding} -gt 0 ]]; do
        value="${value}="
        padding=$((padding - 1))
    done
    printf '%s' "${value}" | base64 -d 2>/dev/null
}

bo_dropbox_binding_hash() {
    printf '%s' "${BO_SOURCE_ID}|dropbox|${BO_DROPBOX_ACCOUNT_ID}|${BO_DROPBOX_NAMESPACE_ID:-}|${BACKUP_OBSERVATION_DROPBOX_ROOT}|${BO_SCAN_ID}|full|${BO_MAX_ITEMS}" | sha256sum | cut -d' ' -f1
}

bo_dropbox_make_token() {
    local cursor="${1}" next_page="${2}" encoded mac mac_status
    encoded="$(bo_dropbox_b64url_encode "${cursor}")"
    [[ -n "${encoded}" && ${#encoded} -le 4000 ]] || return 1
    mac="$(bo_hmac_sha256 "${BO_DROPBOX_REFRESH_TOKEN}" "dropbox-cursor-v1|$(bo_dropbox_binding_hash)|${next_page}|${cursor}")"
    mac_status=$?
    [[ ${mac_status} -eq 0 && "${mac}" =~ ^[A-Fa-f0-9]{64}$ ]] || return "${mac_status:-1}"
    printf 'd%sm%sc%s' "$(bo_dropbox_binding_hash)" "${mac}" "${encoded}"
}

bo_dropbox_decode_token() {
    local token="${1}" page_index="${2}" expected encoded supplied_mac actual_mac cursor
    local mac_status
    BO_DROPBOX_CURSOR_ERROR_CODE="cursor_invalid"
    expected="d$(bo_dropbox_binding_hash)m"
    [[ "${token}" == "${expected}"* ]] || return 1
    token="${token#${expected}}"
    supplied_mac="${token:0:64}"
    [[ "${token:64:1}" == "c" ]] || return 1
    encoded="${token:65}"
    [[ "${supplied_mac}" =~ ^[A-Fa-f0-9]{64}$ && -n "${encoded}" ]] || return 1
    cursor="$(bo_dropbox_b64url_decode "${encoded}" 2>/dev/null || true)"
    [[ -n "${cursor}" ]] || return 1
    actual_mac="$(bo_hmac_sha256 "${BO_DROPBOX_REFRESH_TOKEN}" "dropbox-cursor-v1|$(bo_dropbox_binding_hash)|${page_index}|${cursor}")"
    mac_status=$?
    if [[ ${mac_status} -ne 0 ]]; then
        [[ ${mac_status} -eq 124 ]] && BO_DROPBOX_CURSOR_ERROR_CODE="budget_exceeded" || BO_DROPBOX_CURSOR_ERROR_CODE="dependency_unavailable"
        return 1
    fi
    [[ "${supplied_mac}" == "${actual_mac}" ]] || return 1
    printf '%s' "${cursor}"
}

bo_dropbox_timestamp() {
    local value="${1}" base fraction validation validation_status
    if [[ "${value}" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(\.([0-9]+))?Z$ ]]; then
        base="${BASH_REMATCH[1]}"
        fraction="${BASH_REMATCH[3]:-}"
        validation="$(bo_python_profile to-utc "${base}" UTC 2>/dev/null)"
        validation_status=$?
        [[ ${validation_status} -eq 0 && "${validation}" == *'"status":"ok"'* ]] || return 1
        if [[ -n "${fraction}" ]]; then
            fraction="${fraction}000"
            printf '%s.%sZ' "${base}" "${fraction:0:3}"
        else
            printf '%sZ' "${base}"
        fi
        return 0
    fi
    return 1
}

bo_dropbox_infer_backup_time() {
    local name="${1}" raw converted
    if [[ "${name}" =~ (20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(Z)? ]]; then
        raw="${BASH_REMATCH[1]}"
        # Parsing through the tested timezone helper validates real calendar
        # dates as well as converting naive filename timestamps. A trailing Z
        # is already UTC, so UTC is the conversion timezone in that case.
        if [[ "${BASH_REMATCH[2]:-}" == "Z" ]]; then
            converted="$(bo_python_profile to-utc "${raw}" UTC 2>/dev/null || true)"
            converted="$(printf '%s' "${converted}" | "${BO_JQ_BIN}" -r '.value // empty' 2>/dev/null || true)"
        else
            converted="$(bo_borg_to_utc "${raw}" 2>/dev/null || true)"
        fi
        printf '%s' "${converted}"
    fi
}

bo_dropbox_artifact_json() {
    local entry="${1}" observed_at="${2}"
    local id name path revision size server_modified client_modified backup_value classification class_reason project_hint
    id="$(printf '%s' "${entry}" | "${BO_JQ_BIN}" -r '.id')"
    name="$(printf '%s' "${entry}" | "${BO_JQ_BIN}" -r '.name')"
    path="$(printf '%s' "${entry}" | "${BO_JQ_BIN}" -r '.path_display')"
    revision="$(printf '%s' "${entry}" | "${BO_JQ_BIN}" -r '.rev')"
    size="$(printf '%s' "${entry}" | "${BO_JQ_BIN}" -r '.size')"
    server_modified="$(printf '%s' "${entry}" | "${BO_JQ_BIN}" -r '.server_modified')"
    client_modified="$(printf '%s' "${entry}" | "${BO_JQ_BIN}" -r '.client_modified')"
    backup_value="$(bo_dropbox_infer_backup_time "${name}")"

    if [[ "${path}" == */database/* || "${name}" == *.sql || "${name}" == *.sql.gz || "${name}" == *.dump* ]]; then
        classification="database"
        class_reason="Classified from the Dropbox path or filename; contents were not inspected."
    elif [[ "${name}" == *site-files* || "${name}" == *.tar.gz || "${name}" == *.tgz ]]; then
        classification="files"
        class_reason="Classified from the Dropbox filename; contents were not inspected."
    else
        classification="unknown"
        class_reason="No tested Dropbox naming pattern matched."
    fi

    local backup_json provider_json meta_json associations='[]'
    if [[ -n "${backup_value}" && "${backup_value}" =~ ^[0-9]{4}- ]]; then
        backup_json="$("${BO_JQ_BIN}" -cn --arg value "${backup_value}" '{value:$value,provenance:"naming_inference",reason:null}')"
    else
        backup_json='{"value":null,"provenance":"unknown","reason":"No complete UTC timestamp was inferred from the Dropbox filename."}'
    fi
    if provider_json="$(bo_dropbox_timestamp "${server_modified}")"; then
        provider_json="$("${BO_JQ_BIN}" -cn --arg value "${provider_json}" '{value:$value,provenance:"provider_metadata",reason:null}')"
    else
        provider_json='{"value":null,"provenance":"unknown","reason":"Dropbox server_modified was not a valid contract timestamp."}'
    fi
    local client_json
    if client_json="$(bo_dropbox_timestamp "${client_modified}")"; then
        meta_json="$("${BO_JQ_BIN}" -cn --arg value "${client_json}" '{client_modified_at:$value}')"
    else
        meta_json='{}'
    fi

    if [[ "${path}" =~ /site/([^/]+)/ || "${path}" =~ /database/([^/]+) ]]; then
        project_hint="${BASH_REMATCH[1]}"
        if [[ ${#project_hint} -le 512 && "${project_hint}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]]; then
            associations="$("${BO_JQ_BIN}" -cn --arg hint "${project_hint}" '[{resource_hint:$hint,provenance:"naming_inference",confidence:"inferred"}]')"
        fi
    fi

    "${BO_JQ_BIN}" -cn --arg id "${id}" --arg name "${name}" --arg path "${path}" --arg revision "${revision}" \
        --argjson size "${size}" --arg observed_at "${observed_at}" --argjson backup "${backup_json}" \
        --argjson provider "${provider_json}" --arg classification "${classification}" --arg reason "${class_reason}" \
        --argjson associations "${associations}" --argjson metadata "${meta_json}" \
        '{native_id:$id,name:$name,path:$path,revision:$revision,presence:"present",observed_at:$observed_at,
          backup_time:$backup,provider_modified_time:$provider,
          classification:{type:$classification,provenance:(if $classification == "unknown" then "unknown" else "naming_inference" end),reason:$reason},
          associations:$associations,sizes:[{value:$size,unit:"bytes",semantics:"file_size",provenance:"provider_metadata"}],metadata:$metadata}'
}

bo_dropbox_inventory() {
    local root="${BO_RESOLVED_ROOT:-${BACKUP_OBSERVATION_DROPBOX_ROOT:-}}"
    if ! bo_dropbox_valid_root "${root}"; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "scope_unresolved" "" "The Dropbox location has no explicit authorized root." false)"
        return 1
    fi
    if ! bo_parse_literal_credentials "$(bo_dropbox_credential_path)"; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "authentication" "" "Dropbox credentials are unavailable or invalid." false)"
        return 1
    fi
    if ! bo_dropbox_refresh_token || ! bo_dropbox_account; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "${BO_PROVIDER_ERROR_CODE:-authentication}" "" "Dropbox account identity could not be observed." true)"
        return 1
    fi

    BO_SCAN_ID="$("${BO_JQ_BIN}" -r '.scan.scan_id' <<<"${BO_REQUEST}")"
    local page_index continuation cursor body_file response_file
    page_index="$("${BO_JQ_BIN}" -r '.scan.page_index' <<<"${BO_REQUEST}")"
    continuation="$("${BO_JQ_BIN}" -r '.scan.continuation // empty' <<<"${BO_REQUEST}")"
    body_file="${BO_TEMP_DIR}/dropbox-list.body"
    cursor=""
    if [[ ${page_index} -eq 0 ]]; then
        [[ -z "${continuation}" ]] || { BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "cursor_invalid" "" "The first Dropbox page cannot carry a continuation token." false)"; return 1; }
        "${BO_JQ_BIN}" -cn --arg path "${root}" --argjson limit "${BO_MAX_ITEMS}" '{path:$path,recursive:true,include_deleted:false,include_media_info:false,include_has_explicit_shared_members:false,include_mounted_folders:true,limit:$limit}' >"${body_file}"
        if bo_dropbox_request list "${body_file}"; then
            :
        else
            local request_status=$?
            BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "$(bo_dropbox_error_code "${BO_DROPBOX_RESPONSE_FILE:-/dev/null}" "${request_status}")" "" "Dropbox listing could not be observed." true)"
            return 1
        fi
    else
        [[ -n "${continuation}" ]] || { BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "cursor_invalid" "" "A continuation token is required after the first Dropbox page." false)"; return 1; }
        cursor="$(bo_dropbox_decode_token "${continuation}" "${page_index}" 2>/dev/null || true)"
        [[ -n "${cursor}" && ${#cursor} -le 4096 ]] || { BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "${BO_DROPBOX_CURSOR_ERROR_CODE:-cursor_invalid}" "" "The Dropbox continuation token is unknown or bound to another scan." false)"; return 1; }
        "${BO_JQ_BIN}" -cn --arg cursor "${cursor}" '{cursor:$cursor}' >"${body_file}"
        if bo_dropbox_request continue "${body_file}"; then
            :
        else
            local request_status=$?
            BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "$(bo_dropbox_error_code "${BO_DROPBOX_RESPONSE_FILE:-/dev/null}" "${request_status}")" "" "Dropbox continuation could not be observed." true)"
            return 1
        fi
    fi
    response_file="${BO_DROPBOX_RESPONSE_FILE}"
    if [[ ! -f "${response_file}" || $(wc -c <"${response_file}") -gt ${BO_MAX_REPORT_BYTES} ]]; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "The Dropbox response exceeded the requested collector budget." false)"
        return 1
    fi
    if ! "${BO_JQ_BIN}" -e 'type == "object" and (.entries | type == "array") and (.has_more | type == "boolean") and all(.entries[]; (.[".tag"] == "folder") or (.[".tag"] == "file" and (.id|type=="string" and length>=1 and length<=128 and test("^[A-Za-z0-9][A-Za-z0-9._:-]*$")) and (.name|type=="string" and length>=1 and length<=512 and ((test("[[:cntrl:]]")|not))) and (.path_display|type=="string" and length>=1 and length<=2048 and ((test("[[:cntrl:]]")|not))) and (.rev|type=="string" and length>=1 and length<=128 and test("^[A-Za-z0-9][A-Za-z0-9._:-]*$")) and (.size|type=="number" and floor==. and .>=0 and .<=9007199254740991) and (.server_modified|type=="string" and length<=64) and (.client_modified|type=="string" and length<=64))) and (([.entries[] | select(.[".tag"] == "file") | .id] | length) == ([.entries[] | select(.[".tag"] == "file") | .id] | unique | length))' "${response_file}" >/dev/null 2>&1; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "malformed_response" "" "Dropbox returned an unexpected listing response." false)"
        return 1
    fi
    if ! "${BO_JQ_BIN}" -e --arg root "${root}" 'def under_root: ($root == "/" and startswith("/")) or ($root != "/" and ((. == ($root | rtrimstr("/"))) or startswith(($root | rtrimstr("/")) + "/"))); all(.entries[]; ((.[".tag"] == "folder" or .[".tag"] == "file") and (.path_display | under_root)))' "${response_file}" >/dev/null 2>&1; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "malformed_response" "" "Dropbox returned an entry outside the authorized root." false)"
        return 1
    fi

    local entry_count has_more next_cursor next_token_json outcome observed_at items_json
    entry_count="$("${BO_JQ_BIN}" -r '.entries | length' "${response_file}")"
    if [[ ${entry_count} -gt ${BO_MAX_ITEMS} ]]; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "Dropbox returned more entries than the requested page budget." false)"
        return 1
    fi
    has_more="$("${BO_JQ_BIN}" -r '.has_more' "${response_file}")"
    next_cursor="$("${BO_JQ_BIN}" -r '.cursor // empty' "${response_file}")"
    if [[ "${has_more}" == "true" && -z "${next_cursor}" ]]; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "malformed_response" "" "Dropbox marked a page incomplete without a cursor." false)"
        return 1
    fi
    if [[ "${has_more}" == "true" && -n "${cursor}" && "${next_cursor}" == "${cursor}" ]]; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "cursor_invalid" "" "Dropbox repeated the input cursor." false)"
        return 1
    fi
    next_token_json="null"
    outcome="complete"
    if [[ "${has_more}" == "true" ]]; then
        local next_token next_token_status
        next_token="$(bo_dropbox_make_token "${next_cursor}" "$((page_index + 1))" 2>/dev/null)"
        next_token_status=$?
        if [[ ${next_token_status} -ne 0 ]]; then
            local token_error="dependency_unavailable"
            [[ ${next_token_status} -eq 124 ]] && token_error="budget_exceeded"
            BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "${token_error}" "" "Dropbox continuation integrity could not be generated." false)"
            return 1
        fi
        [[ "${next_token}" =~ ^d[A-Za-z0-9]+m[A-Fa-f0-9]{64}c[A-Za-z0-9_-]+$ && ${#next_token} -le 4096 ]] || { BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "malformed_response" "" "Dropbox returned an invalid continuation cursor." false)"; return 1; }
        next_token_json="\"${next_token}\""
        outcome="partial"
    fi
    observed_at="$(bo_timestamp)"
    items_json="$("${BO_JQ_BIN}" -c '.entries[] | select(.[".tag"] == "file")' "${response_file}" | while IFS= read -r entry; do bo_dropbox_artifact_json "${entry}" "${observed_at}"; done | "${BO_JQ_BIN}" -sc '.')"
    if ! bo_within_runtime_budget; then
        BO_PROVIDER_ERROR_JSON="$(bo_error_json "${BO_SCOPE_JSON}" "budget_exceeded" "" "The collector runtime budget was exceeded while building the Dropbox page." false)"
        return 1
    fi
    BO_DROPBOX_INVENTORY_ITEMS="${items_json}"
    BO_DROPBOX_INVENTORY_PAGINATION="$("${BO_JQ_BIN}" -cn --arg scan_id "${BO_SCAN_ID}" --arg mode "full" --argjson page_index "${page_index}" --argjson has_more "${has_more}" --argjson next_token "${next_token_json}" '{scan_id:$scan_id,mode:$mode,page_index:$page_index,page_complete:true,has_more:$has_more,next_token:$next_token,checkpoint:null,consistency:"best_effort"}')"
    BO_DROPBOX_INVENTORY_OUTCOME="${outcome}"
    return 0
}
