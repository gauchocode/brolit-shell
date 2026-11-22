#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.15
#
# Description: Generates and converges the borgmatic configs that back up
# databases (one per project, plus one per standalone database), from the
# inventory and ownership rules of borg_database_inventory.sh.
#
# Layout: /etc/borgmatic.d/databases/<project>.yml. They live in a subdirectory so
# every existing glob over /etc/borgmatic.d (coverage check, unhandled configs,
# sanitizers, a package cron) leaves them alone.
#
# The dump runs through utils/borg/db_exec.sh, inside the container, so no
# credential reaches the host. Idempotent: the same inventory renders the same
# bytes, and a config is only replaced when its content changes.
################################################################################

BROLIT_BORGMATIC_MIN_VERSION="${BROLIT_BORGMATIC_MIN_VERSION:-2.0.8}"
BROLIT_DB_RETENTION_DAILY="${BROLIT_DB_RETENTION_DAILY:-7}"
BROLIT_DB_RETENTION_WEEKLY="${BROLIT_DB_RETENTION_WEEKLY:-4}"
BROLIT_DB_RETENTION_MONTHLY="${BROLIT_DB_RETENTION_MONTHLY:-6}"
BROLIT_DB_RETENTION_YEARLY="${BROLIT_DB_RETENTION_YEARLY:-1}"

function bdb_config_dir() {
    echo "${BROLIT_BORGMATIC_DB_CONFIG_DIR:-/etc/borgmatic.d/databases}"
}

################################################################################
# Are the Borg database configs in use on this server?
#   BACKUPS.config[0].databases[0].borg = enabled | disabled | auto (default)
# auto: only when Borg is the one method that can hold a dump, i.e. no
# Dropbox/SFTP/Local, whose own database backup keeps working untouched. Servers
# with Borg and another method can opt in with "enabled".
################################################################################
function bdb_borg_databases_enabled() {

    local mode

    [[ "${BACKUP_BORG_STATUS:-}" == "enabled" ]] || return 1
    mode="$(jq -r '.BACKUPS.config[0].databases[0].borg // "auto"' "$(bdb_config_file)" 2>/dev/null)" || mode="auto"
    [[ -n "${mode}" ]] || mode="auto"
    case "${mode}" in
    enabled) return 0 ;;
    disabled) return 1 ;;
    *) declare -F compression_backup_methods_enabled >/dev/null 2>&1 && ! compression_backup_methods_enabled ;;
    esac

}

# Version of the installed borgmatic ("2.1.10"), empty when there is none.
function bdb_borgmatic_version() {

    local cmd
    cmd="$(_borgmatic_resolve_cmd)"
    [[ -n "${cmd}" ]] || return 0
    # shellcheck disable=SC2086
    ${cmd} --version 2>/dev/null | grep -oE '^[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1

}

# True when ${1} >= ${2} (dotted versions).
function bdb_version_at_least() {
    [[ "$(printf '%s\n%s\n' "${2}" "${1}" | sort -V | head -1)" == "${2}" ]]
}

################################################################################
# Make sure borgmatic is at least the minimum version the database configs need,
# raising it when it is not. Idempotent and quiet when it is already enough.
# Returns 0 when it is usable, 1 when it is not and could not be raised.
################################################################################
function bdb_ensure_borgmatic_version() {

    local current pipx_bin
    current="$(bdb_borgmatic_version)"
    if [[ -n "${current}" ]] && bdb_version_at_least "${current}" "${BROLIT_BORGMATIC_MIN_VERSION}"; then
        return 0
    fi

    log_event "warning" "borgmatic ${current:-not found} is below the ${BROLIT_BORGMATIC_MIN_VERSION} the database backups need; raising it" "false"
    pipx_bin="$(command -v pipx || ls /root/.local/bin/pipx 2>/dev/null | head -1)"
    if [[ -z "${pipx_bin}" ]]; then
        log_event "error" "Cannot raise borgmatic: pipx is not installed. Install borgmatic >= ${BROLIT_BORGMATIC_MIN_VERSION} (pipx install borgmatic)" "false"
        return 1
    fi

    "${pipx_bin}" upgrade borgmatic >/dev/null 2>&1 || "${pipx_bin}" install --force borgmatic >/dev/null 2>&1
    current="$(bdb_borgmatic_version)"
    if [[ -n "${current}" ]] && bdb_version_at_least "${current}" "${BROLIT_BORGMATIC_MIN_VERSION}"; then
        log_event "info" "borgmatic raised to ${current}" "false"
        return 0
    fi
    log_event "error" "borgmatic is still ${current:-missing} after trying to raise it; database backups are not configured" "false"
    return 1

}

# A value that is written into a config must be a plain token.
function bdb_safe_token() {
    [[ "${1}" =~ ^[A-Za-z0-9][A-Za-z0-9_.@:-]*$ ]]
}

################################################################################
# Render the config of one owner (a project or a standalone database) on stdout.
#
# Arguments: ${1} owner name   ${2} file with the resolved rows of this owner
# Needs: BACKUP_BORG_USERS/SERVERS/PORTS arrays, BACKUP_BORG_GROUP, HOSTNAME.
# Returns 1 (and prints nothing) when a value is not safe to write.
################################################################################
function bdb_render_config() {

    local owner="${1}" rows_file="${2}"
    local exec_script i n
    local kind source engine container database
    local out="" mariadb="" mysql="" postgres=""

    exec_script="${BROLIT_MAIN_DIR}/utils/borg/db_exec.sh"
    n="${#BACKUP_BORG_USERS[@]}"

    bdb_safe_token "${owner}" || return 1
    bdb_safe_token "${BACKUP_BORG_GROUP:-}" || return 1
    bdb_safe_token "${HOSTNAME:-}" || return 1
    [[ "${n}" -ge 1 && "${#BACKUP_BORG_SERVERS[@]}" -eq "${n}" && "${#BACKUP_BORG_PORTS[@]}" -eq "${n}" ]] || return 1
    for ((i = 0; i < n; i++)); do
        bdb_safe_token "${BACKUP_BORG_USERS[i]}" && bdb_safe_token "${BACKUP_BORG_SERVERS[i]}" && [[ "${BACKUP_BORG_PORTS[i]}" =~ ^[0-9]{1,5}$ ]] || return 1
    done
    [[ "${exec_script}" =~ ^/[A-Za-z0-9_./-]+$ ]] || return 1

    while IFS=$'\t' read -r kind source engine container database _; do
        [[ -n "${database}" ]] || continue
        [[ "${database}" =~ ${BROLIT_DB_NAME_REGEX} ]] || return 1
        if [[ "${kind}" == "host" ]]; then
            # The host engine is reached with its own client and the root socket
            case "${engine}" in
            mariadb) mariadb+=$'  - name: "'"${database}"$'"\n    options: --single-transaction --quick\n' ;;
            mysql) mysql+=$'  - name: "'"${database}"$'"\n    options: --single-transaction --quick\n' ;;
            *) return 1 ;;
            esac
        else
            bdb_safe_token "${container}" || return 1
            case "${engine}" in
            mariadb)
                mariadb+=$'  - name: "'"${database}"$'"\n    hostname: "'"${container}"$'"\n'
                mariadb+=$'    mariadb_dump_command: "'"${exec_script}"' dump mariadb '"${container}"$'"\n'
                mariadb+=$'    mariadb_command: "'"${exec_script}"' client mariadb '"${container}"$'"\n'
                mariadb+=$'    password_transport: environment\n    options: --single-transaction --quick\n'
                ;;
            mysql)
                mysql+=$'  - name: "'"${database}"$'"\n    hostname: "'"${container}"$'"\n'
                mysql+=$'    mysql_dump_command: "'"${exec_script}"' dump mysql '"${container}"$'"\n'
                mysql+=$'    mysql_command: "'"${exec_script}"' client mysql '"${container}"$'"\n'
                mysql+=$'    password_transport: environment\n    options: --single-transaction --quick\n'
                ;;
            postgres)
                postgres+=$'  - name: "'"${database}"$'"\n    hostname: "'"${container}"$'"\n    format: custom\n'
                postgres+=$'    pg_dump_command: "'"${exec_script}"' dump postgres '"${container}"$'"\n'
                postgres+=$'    pg_restore_command: "'"${exec_script}"' restore postgres '"${container}"$'"\n'
                postgres+=$'    psql_command: "'"${exec_script}"' client postgres '"${container}"$'"\n'
                ;;
            *) return 1 ;;
            esac
        fi
    done <"${rows_file}"

    [[ -n "${mariadb}${mysql}${postgres}" ]] || return 1

    out+="# Generated by brolit-shell and regenerated every night: do not edit.\n"
    out+="# Which databases are backed up, and under which owner, is decided by the\n"
    out+="# ownership rules and by the decisions recorded in the Brolit configuration.\n"
    out+="constants:\n"
    out+="  project: \"${owner}\"\n  group: \"${BACKUP_BORG_GROUP}\"\n  hostname: \"${HOSTNAME}\"\n"
    for ((i = 0; i < n; i++)); do
        out+="  user_$((i + 1)): \"${BACKUP_BORG_USERS[i]}\"\n  server_$((i + 1)): \"${BACKUP_BORG_SERVERS[i]}\"\n  port_$((i + 1)): \"${BACKUP_BORG_PORTS[i]}\"\n"
    done
    out+="repositories:\n"
    for ((i = 1; i <= n; i++)); do
        out+="  - path: ssh://{user_${i}}@{server_${i}}:{port_${i}}/home/applications/{group}/{hostname}/projects-online/database/{project}\n    label: storage-{user_${i}}\n"
    done
    out+="archive_name_format: '{project}_database-{now:%Y-%m-%dT%H:%M:%S}'\n"
    out+="keep_daily: ${BROLIT_DB_RETENTION_DAILY}\nkeep_weekly: ${BROLIT_DB_RETENTION_WEEKLY}\nkeep_monthly: ${BROLIT_DB_RETENTION_MONTHLY}\nkeep_yearly: ${BROLIT_DB_RETENTION_YEARLY}\n"
    out+="checks:\n  - name: archives\ncheck_last: 3\n"
    printf '%b' "${out}"
    [[ -z "${mariadb}" ]] || printf 'mariadb_databases:\n%s' "${mariadb}"
    [[ -z "${mysql}" ]] || printf 'mysql_databases:\n%s' "${mysql}"
    [[ -z "${postgres}" ]] || printf 'postgresql_databases:\n%s' "${postgres}"
    printf 'commands:\n  - after: error\n    run:\n      - echo "Borgmatic database backup failed for {project}; see the brolit backup log for the classified reason"\n'

}

# borgmatic config validate on one file; true when it accepts it.
function bdb_validate_config() {

    local cmd
    cmd="$(_borgmatic_resolve_cmd)"
    [[ -n "${cmd}" ]] || return 1
    # shellcheck disable=SC2086
    ${cmd} config validate -c "${1}" >/dev/null 2>&1

}

################################################################################
# Converge the database configs with the inventory.
#
# Writes, replaces and retires configs under bdb_config_dir; never deletes one
# (retired configs move to <dir>/.retired). A rendered config that borgmatic does
# not accept is not installed and the previous file stays.
#
# Also writes the resolved inventory to ${BROLIT_BORG_DB_STATE_FILE} so the run
# and the report use exactly what was configured.
#
# Returns 0 when converged, 1 on a failure that left something unconverged,
# 2 when borgmatic is too old and nothing was done.
################################################################################
function bdb_converge() {

    local dir state_file inv resolved groups_dir owner file tmp stamp rc=0
    local kind source engine container database o evidence size writes dormant state target reason pending
    local -A owners=()
    local -a keep=()

    bdb_ensure_borgmatic_version || return 2

    dir="$(bdb_config_dir)"
    state_file="${BROLIT_BORG_DB_STATE_FILE:-${BROLIT_RUNTIME_STATE_DIR:-/tmp}/borg_databases_state.tsv}"
    mkdir -p "${dir}/.retired" 2>/dev/null && chmod 700 "${dir}" "${dir}/.retired" 2>/dev/null
    [[ -d "${dir}" ]] || {
        log_event "error" "Cannot create ${dir}" "false"
        return 1
    }

    inv="$(mktemp)"
    resolved="$(mktemp)"
    groups_dir="$(mktemp -d)"
    bdb_collect >"${inv}"
    bdb_resolve <"${inv}" >"${resolved}"
    install -m 600 "${resolved}" "${state_file}" 2>/dev/null

    # One group per owner: linked rows by project, standalone rows one each
    while IFS=$'\t' read -r kind source engine container database o evidence size writes dormant state target reason pending; do
        [[ "${state}" == "linked" || "${state}" == "standalone" ]] || continue
        printf '%s\t%s\t%s\t%s\t%s\n' "${kind}" "${source}" "${engine}" "${container}" "${database}" >>"${groups_dir}/${target}.rows"
        owners["${target}"]=1
    done <"${resolved}"

    stamp="$(date +%Y%m%d-%H%M%S)"
    for owner in "${!owners[@]}"; do
        file="${dir}/${owner}.yml"
        tmp="$(mktemp "${dir}/.brolit-render.XXXXXX")"
        if ! bdb_render_config "${owner}" "${groups_dir}/${owner}.rows" >"${tmp}" 2>/dev/null; then
            log_event "error" "Could not render the database backup config for ${owner}" "false"
            rm -f "${tmp}"
            rc=1
            [[ -f "${file}" ]] && keep+=("${owner}.yml")
            continue
        fi
        chmod 600 "${tmp}"
        keep+=("${owner}.yml")
        if [[ -f "${file}" ]] && cmp -s "${tmp}" "${file}"; then
            rm -f "${tmp}"
            continue
        fi
        if ! bdb_validate_config "${tmp}"; then
            log_event "error" "borgmatic does not accept the database backup config rendered for ${owner}; the previous one is kept" "false"
            rm -f "${tmp}"
            rc=1
            continue
        fi
        [[ -f "${file}" ]] && cp -p -- "${file}" "${dir}/.retired/${owner}.${stamp}.yml"
        mv -f -- "${tmp}" "${file}"
        log_event "info" "Database backup config for ${owner} written" "false"
    done

    # Retire what is no longer expected (database gone, ignored or held)
    for file in "${dir}"/*.yml; do
        [[ -f "${file}" ]] || continue
        o="$(basename "${file}")"
        [[ " ${keep[*]} " == *" ${o} "* ]] && continue
        mv -f -- "${file}" "${dir}/.retired/${o%.yml}.${stamp}.yml"
        log_event "info" "Database backup config ${o} retired: nothing to back up there any more" "false"
    done

    rm -rf "${inv}" "${resolved}" "${groups_dir}"
    return "${rc}"

}
