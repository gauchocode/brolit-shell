#!/usr/bin/env bash
# Author: GauchoCode
# Version: 0.1.0
################################################################################
# Definition-only observer configuration helpers.  The observer calls the
# dedicated projection in utils/brolit_configuration_manager.sh; this module
# contains validation and handle resolution that must not load normal shell
# configuration.
################################################################################

################################################################################
# Return true only for a safe absolute path without control characters.
################################################################################
bo_safe_absolute_path() {
    # Bash variables cannot contain NUL bytes; the stdin JSON transport rejects
    # them before any path can reach this function.
    [[ "${1}" == /* && "${1}" != *$'\n'* && "${1}" != *$'\r'* && "${1}" != *$'\t'* && "${1}" != *$'\x7f'* ]] || return 1
    ! printf '%s' "${1}" | LC_ALL=C grep -q '[[:cntrl:]]'
}

################################################################################
# Resolve a location handle against the current authorized configuration.
# No repository contents are read and no provider is invoked here.
################################################################################
bo_resolve_location() {
    BO_RESOLVED_CONFIG=""
    BO_RESOLVED_ROOT=""
    BO_RESOLVED_REPO_INDEX=""

    if [[ ${BO_PROVIDER} == "borg" ]]; then
        if [[ ${BACKUP_OBSERVATION_BORG_STATUS:-disabled} != "enabled" ]]; then
            return 1
        fi

        local suffix
        local repo_index=""
        local borgmatic_dir="/etc/borgmatic.d"
        if [[ ${BROLIT_OBSERVER_TEST_MODE:-0} == "1" && -n "${BROLIT_OBSERVER_TEST_BORGMATIC_DIR:-}" ]]; then
            borgmatic_dir="${BROLIT_OBSERVER_TEST_BORGMATIC_DIR}"
        fi
        # Handles name a Borgmatic file plus a repository index: borg-<file>-r<n>
        if [[ "${BO_LOCATION_ID}" =~ ^borg-([A-Za-z0-9._:-]+)-r([0-9]+)$ ]]; then
            suffix="${BASH_REMATCH[1]}"
            repo_index="${BASH_REMATCH[2]}"
        else
            return 1
        fi
        BO_RESOLVED_CONFIG="${borgmatic_dir}/${suffix}.yml"
        bo_safe_absolute_path "${BO_RESOLVED_CONFIG}" || return 1
        [[ -f "${BO_RESOLVED_CONFIG}" && ! -L "${BO_RESOLVED_CONFIG}" ]] || return 1
        BO_RESOLVED_ROOT="${BO_RESOLVED_CONFIG}"
        BO_RESOLVED_REPO_INDEX="${repo_index}"
        return 0
    fi

    if [[ ${BO_PROVIDER} == "dropbox" ]]; then
        # A root is an explicit authorization boundary.  Disabled generation
        # does not erase a known historical root, so inventory remains
        # resolvable when the root is configured but generation is disabled.
        [[ "${BO_LOCATION_ID}" == "dropbox-root" ]] || return 1
        [[ -n "${BACKUP_OBSERVATION_DROPBOX_ROOT:-}" ]] || return 1
        [[ "${BACKUP_OBSERVATION_DROPBOX_ROOT}" == /* ]] || return 1
        bo_safe_absolute_path "${BACKUP_OBSERVATION_DROPBOX_ROOT}" || return 1
        [[ ${#BACKUP_OBSERVATION_DROPBOX_ROOT} -le 2048 ]] || return 1
        BO_RESOLVED_ROOT="${BACKUP_OBSERVATION_DROPBOX_ROOT}"
        return 0
    fi

    return 1
}

################################################################################
# Parse literal Dropbox credential assignments without sourcing or evaluation.
# Values remain process-internal and are never printed by this function.
################################################################################
bo_parse_literal_credentials() {
    local credential_file="${1}"
    local line key value
    local found_key=0
    local found_secret=0

    BO_DROPBOX_APP_KEY=""
    BO_DROPBOX_APP_SECRET=""
    BO_DROPBOX_REFRESH_TOKEN=""

    bo_safe_absolute_path "${credential_file}" || return 1
    if [[ "${credential_file}" != "/root/.dropbox_uploader" ]]; then
        # Test fixtures may use a temporary path, but only when the caller has
        # explicitly entered the isolated harness. Production never widens
        # the authorized credential location through an environment variable.
        [[ ${BROLIT_OBSERVER_TEST_MODE:-0} == "1" && -n "${BROLIT_OBSERVER_TEST_CREDENTIAL_FILE:-}" && "${credential_file}" == "${BROLIT_OBSERVER_TEST_CREDENTIAL_FILE}" ]] || return 1
    fi
    [[ -f "${credential_file}" && ! -L "${credential_file}" ]] || return 1
    local credential_owner_mode credential_owner credential_mode
    credential_owner_mode="$(stat -c '%u %a' "${credential_file}" 2>/dev/null || true)"
    read -r credential_owner credential_mode <<<"${credential_owner_mode}"
    [[ "${credential_owner}" == "0" && -n "${credential_mode}" ]] || return 1
    # Credentials must not be writable or readable by group/other users.
    (( (8#${credential_mode} & 0077) == 0 )) || return 1

    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        [[ -z "${line}" || "${line}" == \#* ]] && continue

        if [[ ${line} =~ ^(OAUTH_APP_KEY|OAUTH_APP_SECRET|OAUTH_REFRESH_TOKEN)=([A-Za-z0-9._~:/+=-]+)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
        elif [[ ${line} =~ ^(OAUTH_APP_KEY|OAUTH_APP_SECRET|OAUTH_REFRESH_TOKEN)=\'([A-Za-z0-9._~:/+=-]+)\'$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
        else
            # This rejects shell operators, substitutions, functions, unknown
            # assignments and every format that has not been tested.
            return 1
        fi

        [[ -z "${value}" ]] && return 1
        case "${key}" in
            OAUTH_APP_KEY)
                [[ -n "${BO_DROPBOX_APP_KEY}" ]] && return 1
                BO_DROPBOX_APP_KEY="${value}"; found_key=1
                ;;
            OAUTH_APP_SECRET)
                [[ -n "${BO_DROPBOX_APP_SECRET}" ]] && return 1
                BO_DROPBOX_APP_SECRET="${value}"; found_secret=1
                ;;
            OAUTH_REFRESH_TOKEN)
                [[ -n "${BO_DROPBOX_REFRESH_TOKEN}" ]] && return 1
                BO_DROPBOX_REFRESH_TOKEN="${value}"
                ;;
        esac
    done <"${credential_file}"

    [[ ${found_key} -eq 1 && ${found_secret} -eq 1 && -n "${BO_DROPBOX_REFRESH_TOKEN}" ]]
}

################################################################################
# Execute only an already allowlisted binary in a minimal environment.
################################################################################
bo_safe_provider_exec() {
    local provider="${1}"
    shift
    local executable="${1}"
    shift

    case "${provider}:${executable}" in
        borg:borg|dropbox:curl)
            local exec_path="/usr/bin:/bin"
            if [[ ${BROLIT_OBSERVER_TEST_MODE:-0} == "1" && -n "${BO_EXEC_PATH:-}" ]]; then
                exec_path="${BO_EXEC_PATH}"
            fi
            local max_blocks=$(( (BO_MAX_REPORT_BYTES + 511) / 512 + 1 ))
            (ulimit -f "${max_blocks}" 2>/dev/null || exit 125; env -i PATH="${exec_path}" HOME=/root LC_ALL=C BO_ATTEMPT_LOG="${BO_ATTEMPT_LOG-}" BROLIT_OBSERVER_TEST_DROPBOX_MODE="${BROLIT_OBSERVER_TEST_DROPBOX_MODE-}" "${executable}" "$@")
            ;;
        *)
            return 125
            ;;
    esac
}
