#!/usr/bin/env bash
# Author: GauchoCode
# Version: 3.11
# Description: Side-effect-free Borgmatic configuration generation helpers.
################################################################################

################################################################################
# Generate a new profile without modifying any existing profile.
#
# Arguments:
#   ${1} = project_name
#   ${2} = config_dir (optional, defaults to /etc/borgmatic.d)
#   ${3} = projects_dir (optional, defaults to /var/www)
# Outputs:
#   created/exists/skipped on stdout and 0; failed and 1 on error.
#   Uses already-loaded BACKUP_BORG_* arrays; never reads the main JSON.
################################################################################
function generate_borg_config() (
    local project_name="${1}" config_dir="${2:-/etc/borgmatic.d}"
    local project_dir="${3:-/var/www}/${project_name}"
    local yml_file="${config_dir}/${project_name}.yml" stage=""
    local project_install_type db_engine template_file db_name="" needs_database=0
    local i number_of_servers exitstatus repository project_entry

    # A subshell scopes umask/traps, including early returns and interruptions.
    umask 077
    trap '[[ -z "${stage}" ]] || rm --force -- "${stage}"' EXIT
    trap 'exit 1' HUP INT TERM
    if [[ -e "${yml_file}" || -L "${yml_file}" ]]; then
        # An existing config is never overwritten. Warn when it contradicts the
        # project's no-database opt-out, otherwise the operator keeps an invalid
        # config and the run keeps failing with a generic class "config".
        if [[ -f "${project_dir}/.env" ]] && grep -qE '^BROLIT_DB_ENGINE=none$' "${project_dir}/.env" \
            && grep -qE 'mysql_databases|\$\{database\}' "${yml_file}"; then
            log_event "warning" "Existing borgmatic config for ${project_name} still has a database section but the project opts out (BROLIT_DB_ENGINE=none); remove ${yml_file} to regenerate it" "false"
        fi
        echo "exists"
        return 0
    fi
    if [[ ! "${project_name}" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
        echo "failed"
        return 1
    fi
    if [[ -d "${project_dir}" ]]; then
        if ! project_entry="$(find "${project_dir}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)"; then
            echo "failed"
            return 1
        fi
        if [[ -z "${project_entry}" ]]; then
            echo "skipped"
            return 0
        fi
    fi
    project_install_type="$(project_get_install_type "${project_dir}" 2>/dev/null)" || project_install_type="unknown"
    if [[ "${project_install_type}" == "default" ]]; then
        db_engine="$(project_get_database_engine "${project_name}" "${project_install_type}" 2>/dev/null)" || db_engine=""
        template_file="borgmatic.template-${db_engine:-mysql}.yml"
    elif [[ "${project_install_type}" == docker* ]]; then
        template_file="borgmatic.template-docker.yml"
    else
        template_file="borgmatic.template-${project_install_type}.yml"
    fi
    [[ -f "${BROLIT_MAIN_DIR}/config/borg/${template_file}" ]] || template_file="borgmatic.template-default.yml"
    template_file="${BROLIT_MAIN_DIR}/config/borg/${template_file}"
    if [[ ! -f "${template_file}" ]]; then
        echo "failed"
        return 1
    fi
    # Explicit opt-out for projects with no database (MinIO/S3, static sites):
    # an undetected engine falls back to the MySQL template and emits a
    # mysql_databases section whose ${database} constant cannot resolve. Swap
    # only database-aware templates so docker projects keep their log-capture
    # and notification hooks.
    if grep -qE '^BROLIT_DB_ENGINE=none$' "${project_dir}/.env" 2>/dev/null && grep -qF '{database}' "${template_file}"; then
        log_event "info" "Project ${project_name} opts out of database dumps (BROLIT_DB_ENGINE=none); using the no-database borgmatic template" "false"
        template_file="${BROLIT_MAIN_DIR}/config/borg/borgmatic.template-default.yml"
        if [[ ! -f "${template_file}" ]]; then
            echo "failed"
            return 1
        fi
    fi
    # Only database-aware templates need detection. Never interpret expressions.
    if grep -qF '{database}' "${template_file}"; then
        needs_database=1
        db_name="$(project_get_database_name "${project_name}" "${project_install_type}" 2>/dev/null)" || db_name=""
        if [[ ! "${db_name}" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]*$ ]]; then
            log_event "error" "Borg config generation failure class: config" "false" >&2
            echo "failed"
            return 1
        fi
    fi
    number_of_servers="${#BACKUP_BORG_USERS[@]}"
    if [[ "${number_of_servers}" -eq 0 || "${#BACKUP_BORG_SERVERS[@]}" -ne "${number_of_servers}" || "${#BACKUP_BORG_PORTS[@]}" -ne "${number_of_servers}" || ! "${BACKUP_BORG_GROUP}" =~ ^[a-zA-Z0-9_.-]+$ || ! "${HOSTNAME}" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        echo "failed"
        return 1
    fi
    for ((i=0; i<number_of_servers; i++)); do
        if [[ ! "${BACKUP_BORG_USERS[i]}" =~ ^[a-zA-Z0-9_.-]+$ || ! "${BACKUP_BORG_SERVERS[i]}" =~ ^[a-zA-Z0-9_.:-]+$ || ! "${BACKUP_BORG_PORTS[i]}" =~ ^[0-9]{1,5}$ ]]; then
            echo "failed"
            return 1
        fi
        if [[ "$((10#${BACKUP_BORG_PORTS[i]}))" -lt 1 || "$((10#${BACKUP_BORG_PORTS[i]}))" -gt 65535 ]]; then
            echo "failed"
            return 1
        fi
    done
    if ! mkdir --parents -- "${config_dir}" 2>/dev/null; then
        echo "failed"
        return 1
    fi
    # Hidden non-YAML staging is not a Borgmatic scan candidate.
    stage="$(mktemp "${config_dir}/.brolit-config.XXXXXX")" || { echo "failed"; return 1; }
    if ! cp -- "${template_file}" "${stage}" 2>/dev/null; then
        echo "failed"
        return 1
    fi
    if ! PROJECT="${project_name}" GROUP="${BACKUP_BORG_GROUP}" HOST="${HOSTNAME}" yq -i \
        '.repositories = [] | .constants.project = strenv(PROJECT) | .constants.group = strenv(GROUP) | .constants.hostname = strenv(HOST) | del(.constants.database)' "${stage}" 2>/dev/null; then
        echo "failed"
        return 1
    fi
    if [[ "${needs_database}" -eq 1 ]]; then
        if ! DATABASE="${db_name}" yq -i '.constants.database = strenv(DATABASE)' "${stage}" 2>/dev/null; then
            echo "failed"
            return 1
        fi
    fi
    for ((i=1; i<=number_of_servers; i++)); do
        if ! USER_VALUE="${BACKUP_BORG_USERS[i-1]}" SERVER_VALUE="${BACKUP_BORG_SERVERS[i-1]}" PORT_VALUE="${BACKUP_BORG_PORTS[i-1]}" \
            yq -i ".constants.user_${i} = strenv(USER_VALUE) | .constants.server_${i} = strenv(SERVER_VALUE) | .constants.port_${i} = strenv(PORT_VALUE) | .repositories += [{\"path\": \"ssh://{user_${i}}@{server_${i}}:{port_${i}}/home/applications/{group}/{hostname}/projects-online/site/{project}\", \"label\": \"storage-{user_${i}}\"}]" "${stage}" 2>/dev/null; then
            echo "failed"
            return 1
        fi
    done
    if ! EXPECTED="${number_of_servers}" PROJECT="${project_name}" GROUP="${BACKUP_BORG_GROUP}" HOST="${HOSTNAME}" yq --exit-status \
        '(.repositories | length) == env(EXPECTED) and ((.constants.project | tag) == "!!str") and ((.constants.group | tag) == "!!str") and ((.constants.hostname | tag) == "!!str") and (.constants.project == strenv(PROJECT)) and (.constants.group == strenv(GROUP)) and (.constants.hostname == strenv(HOST))' "${stage}" >/dev/null 2>&1; then
        echo "failed"
        return 1
    fi
    if [[ "${needs_database}" -eq 1 ]] && ! DATABASE="${db_name}" yq --exit-status '.constants.database == strenv(DATABASE)' "${stage}" >/dev/null 2>&1; then
        echo "failed"
        return 1
    fi
    for ((i=1; i<=number_of_servers; i++)); do
        repository="ssh://{user_${i}}@{server_${i}}:{port_${i}}/home/applications/{group}/{hostname}/projects-online/site/{project}"
        if ! USER_VALUE="${BACKUP_BORG_USERS[i-1]}" SERVER_VALUE="${BACKUP_BORG_SERVERS[i-1]}" PORT_VALUE="${BACKUP_BORG_PORTS[i-1]}" REPOSITORY="${repository}" \
            yq --exit-status "(.constants.user_${i} == strenv(USER_VALUE)) and (.constants.server_${i} == strenv(SERVER_VALUE)) and (.constants.port_${i} == strenv(PORT_VALUE)) and (.repositories[$((i-1))].path == strenv(REPOSITORY))" "${stage}" >/dev/null 2>&1; then
            echo "failed"
            return 1
        fi
    done
    if ! chmod 600 "${stage}" 2>/dev/null; then
        echo "failed"
        return 1
    fi
    # link(2) publishes atomically and refuses to clobber a concurrent creator.
    ln --no-target-directory -- "${stage}" "${yml_file}" 2>/dev/null
    exitstatus=$?
    if [[ "${exitstatus}" -eq 0 ]]; then
        echo "created"
    elif [[ -e "${yml_file}" || -L "${yml_file}" ]]; then
        echo "exists"
    else
        echo "failed"
        return 1
    fi
)
