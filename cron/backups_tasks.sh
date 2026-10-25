#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
################################################################################

### Main dir check
BROLIT_MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BROLIT_MAIN_DIR=$(cd "$(dirname "${BROLIT_MAIN_DIR}")" && pwd)

[[ -z "${BROLIT_MAIN_DIR}" ]] && exit 1 # error; the path is not accessible

# shellcheck source=${BROLIT_MAIN_DIR}/libs/commons.sh
source "${BROLIT_MAIN_DIR}/libs/commons.sh"

################################################################################
# Helper functions for multi-method backup
################################################################################

# Load configurations from central sources
function load_configurations() {

    # Load backup borg configuration
    _brolit_configuration_load_backup_borg "/root/.brolit_conf.json"

    # Load ntfy configuration if available
    if command -v _brolit_configuration_load_ntfy &> /dev/null; then
        _brolit_configuration_load_ntfy "/root/.brolit_conf.json"
    fi

}

# Generate Borg configuration file for all projects
function generate_config() {

    # Load configuration
    load_configurations

    # Check if Borg backup is enabled
    if [ "${BACKUP_BORG_STATUS}" == "enabled" ]; then

        # Counters for reporting
        local total_projects=0
        local configs_created=0
        local configs_existing=0
        local configs_skipped=0
        local configs_failed=0
        local projects_without_config=()

        # Process each directory in PROJECTS_PATH
        for folder in "${PROJECTS_PATH}"/*; do

            if [ -d "${folder}" ]; then

                local folder_name
                folder_name=$(basename "${folder}")

                # Skip HTML directory
                if [ "${folder_name}" == "html" ]; then
                    continue
                fi

                ((total_projects++))
                log_event "info" "Processing project: ${folder_name}" "false"

                # Generate Borg configuration
                local config_status
                config_status=$(generate_borg_config "${folder_name}")

                case "${config_status}" in
                    "created")
                        ((configs_created++))
                        log_event "info" "✓ Created borgmatic config for: ${folder_name}" "false"
                        display --indent 6 --text "- Config created for ${folder_name}" --result "DONE" --color GREEN
                        ;;
                    "exists")
                        ((configs_existing++))
                        log_event "debug" "✓ Config already exists for: ${folder_name}" "false"
                        ;;
                    "skipped")
                        ((configs_skipped++))
                        display --indent 6 --text "- Config skipped for ${folder_name} (empty/alias project)" --result "SKIPPED" --color YELLOW
                        ;;
                    "failed")
                        ((configs_failed++))
                        projects_without_config+=("${folder_name}")
                        log_event "error" "✗ Failed to generate config for: ${folder_name}" "false"
                        display --indent 6 --text "- Config failed for ${folder_name}" --result "FAIL" --color RED
                        ;;
                esac

            fi

        done

        # Report summary
        log_event "info" "=== Borgmatic Configuration Summary ===" "false"
        log_event "info" "Total projects: ${total_projects}" "false"
        log_event "info" "Configs created: ${configs_created}" "false"
        log_event "info" "Configs existing: ${configs_existing}" "false"
        log_event "info" "Configs skipped (empty/alias): ${configs_skipped}" "false"
        log_event "info" "Configs failed: ${configs_failed}" "false"

        display --indent 4 --text "Borgmatic configuration summary:" --tcolor YELLOW
        display --indent 6 --text "Total projects: ${total_projects}" --tcolor WHITE
        display --indent 6 --text "New configs created: ${configs_created}" --tcolor GREEN
        display --indent 6 --text "Existing configs: ${configs_existing}" --tcolor BLUE
        display --indent 6 --text "Skipped (empty/alias): ${configs_skipped}" --tcolor YELLOW

        if [ ${configs_failed} -gt 0 ]; then
            display --indent 6 --text "Failed configs: ${configs_failed}" --tcolor RED
            log_event "warning" "Projects without config: ${projects_without_config[*]}" "false"
            display --indent 6 --text "Projects without config:" --tcolor RED
            for project in "${projects_without_config[@]}"; do
                display --indent 8 --text "- ${project}" --tcolor RED
            done
        fi

    else

        log_event "info" "Borg backup is not enabled" "false"

    fi

}

# Generation lives in libs/local/borg_config_helper.sh (loaded by commons).

# Prepare borgmatic environment if enabled
function prepare_borgmatic_environment() {
    
    # Load configuration and ensure borgmatic templates exist
    load_configurations
    generate_config    # Only generates missing configs
    sanitize_borgmatic_pause_hooks    # Self-heal configs generated before the template dropped the pause hooks

    log_event "info" "Borgmatic environment preparation completed" "false"
    
}

# Backup project using all enabled methods
function backup_project_all_enabled_methods() {

    local project_domain="${1}"
    local backup_status=0
    local config_dir="${BROLIT_BORGMATIC_CONFIG_DIR:-/etc/borgmatic.d}"
    local config_file="${config_dir}/${project_domain}.yml"

    log_event "info" "Starting multi-method backup for: ${project_domain}" "false"

    # Check if Borg is enabled
    if [[ ${BACKUP_BORG_STATUS} == "enabled" ]]; then

        # Verify config file exists
        if [[ -f "${config_file}" ]]; then

            backup_borgmatic_config_once "${config_file}" "${project_domain}" || backup_status=1

        elif [[ -z "$(find "${PROJECTS_PATH}/${project_domain}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then

            # Empty project directory -- an alias/placeholder for a site
            # served elsewhere (e.g. an nginx proxy_pass into another
            # project's docker-compose). Nothing to back up; not an error.
            log_event "info" "${project_domain} is an empty/alias project directory -- no backup needed" "false"
            display --indent 6 --text "- ${project_domain} (empty/alias project)" --result "SKIPPED" --color YELLOW
            borg_project_status_line="${project_domain};SKIPPED (empty/alias project)"

        else

            # Config file missing - log warning
            log_event "warning" "Borgmatic config missing for ${project_domain} at ${config_file}" "false"
            display --indent 6 --text "- No borgmatic config for ${project_domain}" --result "SKIP" --color YELLOW
            borg_project_status_line="${project_domain};SKIPPED (borgmatic config missing)"

            # Fallback to traditional database backup for Docker projects
            if [[ -f "${PROJECTS_PATH}/${project_domain}/.env" ]]; then
                log_event "info" "Running traditional database backup for Docker project: ${project_domain}" "false"
                display --indent 6 --text "- Using traditional backup method" --tcolor YELLOW
                borg_backup_database "${project_domain}"

                if [[ $? -eq 0 ]]; then
                    log_event "info" "Traditional database backup for ${project_domain} completed successfully." "false"
                    display --indent 8 --text "Backup completed" --result "DONE" --color GREEN
                else
                    log_event "error" "Traditional database backup for ${project_domain} failed." "false"
                    display --indent 8 --text "Backup failed" --result "FAIL" --color RED
                    backup_status=1
                fi
            else
                log_event "info" "No database backup method available for project: ${project_domain}" "false"
            fi

        fi

    else

        # Borg not enabled - use traditional backup
        if [[ -f "${PROJECTS_PATH}/${project_domain}/.env" ]]; then
            log_event "info" "Running traditional database backup for project: ${project_domain}" "false"
            borg_backup_database "${project_domain}"

            if [[ $? -eq 0 ]]; then
                log_event "info" "Traditional database backup for ${project_domain} completed successfully." "false"
            else
                log_event "error" "Traditional database backup for ${project_domain} failed." "false"
                backup_status=1
            fi
        else
            log_event "info" "No database backup needed for project: ${project_domain}" "false"
        fi

    fi

    return ${backup_status}

}

################################################################################

# Script Initialization
script_init "true"

# Running from cron
log_event "info" "Running backups_tasks.sh ..." "false"

# Single-instance guard: a previous run still working (or hung) must never
# accumulate nightly copies. Observed live: 44 stacked runs on one host
# whose borgmatic loop wedged for 18 days (disk 100% full), load ~30.
# flock is released automatically when this process dies, even on kill -9.
# shellcheck disable=SC2094
exec 200>"${BROLIT_RUNTIME_STATE_DIR:-/tmp}/brolit_backups_tasks.lock"
if ! flock -n 200; then
    log_event "warning" "Another backups_tasks.sh is still running (lock held). Exiting to avoid stacking runs." "false"
    send_notification "${SERVER_NAME}" "Backup run skipped: the previous backup run is still active. If this fires every night, a run is hung -- check for old backups_tasks.sh processes on the server." "alert"
    exit 1
fi

# Global counter incremented by storage_delete_old_backups() every time it
# fails to remove an old backup from a remote storage (e.g. Dropbox). Reset
# here so this run's report only reflects this run's failures.
declare -g -i STORAGE_DELETE_ERRORS=0

# If NETDATA is installed, disabled alarms
[[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]] && netdata_alerts_disable

# Update packages index
package_update

# Mail section for Server status and Packages
mail_server_status_section
mail_package_status_section

# Certificates
log_event "info" "Certbot Certificates" "false"

# Check certificates installed
mail_certificates_section

# Prepare borgmatic environment if enabled
if [[ ${BACKUP_BORG_STATUS} == "enabled" ]]; then
    log_section "Preparing Borgmatic Environment"
    prepare_borgmatic_environment
fi

# BACKUP_ALL
log_section "Backup All"

# Databases Backup (traditional - handled per project in multi-method approach)
# NOTE: capture exit code, not stdout. The old
# database_backup_result="$(backup_all_databases)" captured stdout (display
# output, sizes) so mail_subject_status() never saw a real 0/1.
backup_all_databases
database_backup_result=$?

# Verify PROJECTS_PATH is defined and is a valid directory
if [[ -z "${PROJECTS_PATH}" ]]; then
    log_event "error" "PROJECTS_PATH is not defined. Cannot proceed with project backups." "false"
    exit 1
fi

if [[ ! -d "${PROJECTS_PATH}" ]]; then
    log_event "error" "PROJECTS_PATH directory does not exist: ${PROJECTS_PATH}" "false"
    exit 1
fi

# Projects Backup with multi-method support
log_subsection "Backup Projects with Multi-Method Support"

# Initialize borg backup status. The per-project Docker DB fallback also
# reports through this flag (see borg_backup_database), so it must stay
# visible in the email body and not only in the subject.
borg_backup_result=0
borg_failed_projects=()
borg_backup_list=()
BORG_CONFIG_DIR="${BROLIT_BORGMATIC_CONFIG_DIR:-/etc/borgmatic.d}"
BORG_CONFIG_DIR="${BORG_CONFIG_DIR%/}"
declare -A BORG_HANDLED_CONFIGS=()

# Circuit-breaker state for an unreachable shared borg destination: after N
# consecutive repository-init failures the rest of the run is skipped and the
# root cause is reported once (see backup_project_all_enabled_methods and
# borg_repo_failure_limit in libs/borg_storage_controller.sh).
declare -i BORG_REPO_INIT_FAILURES=0
declare -i BORG_REPO_UNAVAILABLE=0
BORG_FIRST_FAILURE_REASON=""
borg_project_status_line=""

# Iterate over projects in PROJECTS_PATH
for project_dir in "${PROJECTS_PATH}"/*/; do
    # Verify that the directory exists and is actually a directory
    if [[ -d "${project_dir}" ]]; then
        project_domain=$(basename "${project_dir}")

        # Multi-method backup for each project
        backup_project_all_enabled_methods "${project_domain}"
        project_rc=$?

        PROJECT_CONFIG="${BORG_CONFIG_DIR}/${project_domain}.yml"
        [[ -f "${PROJECT_CONFIG}" ]] && BORG_HANDLED_CONFIGS["${PROJECT_CONFIG}"]=1

        # The function may set a detailed status line (e.g.
        # "domain;FAIL (repository: network)" or
        # "domain;SKIPPED (repository unavailable)") when the circuit
        # breaker or the init gate classified the failure. Prefer it so the
        # email body carries the root cause instead of N identical "FAIL".
        project_status_line="${borg_project_status_line}"
        borg_project_status_line=""

        # Capture any borg failures during project backups
        if [[ ${project_rc} -ne 0 ]]; then
            borg_backup_result=1
            borg_failed_projects+=("${project_domain}")
            if [[ -n "${project_status_line}" ]]; then
                borg_backup_list+=("${project_status_line}")
            else
                borg_backup_list+=("${project_domain};FAIL")
            fi
        elif [[ -n "${project_status_line}" ]]; then
            borg_backup_list+=("${project_status_line}")
        else
            borg_backup_list+=("${project_domain};OK")
        fi

    fi
done

# Files Backup
# NOTE: same as above - capture exit code, not stdout.
backup_all_files
files_backup_result=$?

# Run custom/standalone configs that were not owned by a project directory.
# Project configs were already executed above and must never run a second time.
if [[ ${BACKUP_BORG_STATUS} == "enabled" ]]; then
    backup_unhandled_borgmatic_configs BORG_HANDLED_CONFIGS borg_backup_result borg_failed_projects borg_backup_list
    if ! check_borgmatic_config_coverage; then
        borg_backup_result=1
        borg_failed_projects+=("configuration-coverage")
        borg_backup_list+=("configuration-coverage;FAIL")
    fi
fi

# Borg mail section: previously borg failures only drove the subject (ERROR)
# while the body showed all OK. Render them explicitly so subject and body
# always agree. When the run-level circuit breaker classified a shared
# destination failure, state that single root cause in the section title
# instead of a bare list of identical per-project failures.
if [[ "${BACKUP_BORG_STATUS}" == "enabled" ]]; then
    if [[ ${borg_backup_result} -eq 0 ]]; then
        mail_backup_section "none" "none" "borg" "${borg_backup_list[@]}"
    else
        borg_failure_title="Borg backup failed for: ${borg_failed_projects[*]}"
        if [[ -n "${BORG_FIRST_FAILURE_REASON}" ]]; then
            borg_failure_title="${borg_failure_title} — repository unavailable (${BORG_FIRST_FAILURE_REASON})"
        fi
        mail_backup_section "${borg_failure_title}" "borg_backup" "borg" "${borg_backup_list[@]}"
    fi
else
    mail_backup_section "none" "none" "borg" "Borg backup disabled - skipped;SKIPPED"
fi

# Footer
mail_footer "${SCRIPT_V}"

# Preparing Mail Notifications Template
email_html_file="${BROLIT_TMP_DIR}/full-email-${NOW}.mail"

# Assemble complete email using new template engine
# This replaces the previous 21 lines of grep/sed/mv operations with a single function call
# Note: the certificates section is intentionally NOT included here. Certificate
# health has its own monitoring (security scan, Brolit UI) and must not drive
# the backup report status.
if ! mail_template_assemble "${email_html_file}" "main" \
    "server_info=${BROLIT_TMP_DIR}/server_info-${NOW}.mail" \
    "packages_section=${BROLIT_TMP_DIR}/packages-${NOW}.mail" \
    "databases_backup_section=${BROLIT_TMP_DIR}/databases-bk-${NOW}.mail" \
    "configs_backup_section=${BROLIT_TMP_DIR}/configuration-bk-${NOW}.mail" \
    "files_backup_section=${BROLIT_TMP_DIR}/files-bk-${NOW}.mail" \
    "borg_backup_section=${BROLIT_TMP_DIR}/borg-bk-${NOW}.mail" \
    "footer=${BROLIT_TMP_DIR}/footer-${NOW}.mail"; then
    log_event "error" "Failed to assemble email template" "false"
    display --indent 6 --text "- Assembling email template" --result "FAIL" --color RED
    return 1
fi

# Send html to a var
mail_html="$(cat "${email_html_file}")"

# Retention/storage cleanup status: were there old backups that could not be
# deleted from remote storage (e.g. Dropbox)? Left unattended this fills up
# the storage quota and causes every subsequent backup upload to fail.
retention_backup_result=0
[[ ${STORAGE_DELETE_ERRORS} -gt 0 ]] && retention_backup_result=1

# The complete-backup subject describes this backup run only. Server health,
# certificates and packages remain visible in the body and in their dedicated
# monitoring, but cannot turn successful backup results into an error.
email_status="$(mail_backup_subject_status "${database_backup_result}" "${files_backup_result}" "${borg_backup_result}" "${retention_backup_result}")"

# Preparing email to send
email_subject="${email_status} [${NOWDISPLAY}] - Complete Backup on ${SERVER_NAME}"

# Determine notification status based on all backup results
notification_status="success"
notification_message="Complete backup completed successfully."

if [[ ${database_backup_result} -ne 0 ]] || [[ ${files_backup_result} -ne 0 ]] || [[ ${borg_backup_result} -ne 0 ]]; then
    notification_status="alert"
    notification_message="Complete backup completed with errors. Check logs for details."
elif [[ ${retention_backup_result} -ne 0 ]]; then
    notification_status="alert"
    notification_message="Backup completed, but ${STORAGE_DELETE_ERRORS} old backup(s) could not be deleted from remote storage. Check logs to avoid filling up storage quota."
fi

# Sending email notification (detailed report)
mail_send_notification "${email_subject}" "${mail_html}"

# Send push notification to other channels (email already sent above, skip it to avoid duplicates)
send_notification "${SERVER_NAME}" "${notification_message}" "${notification_status}" "email"

# Independent SSL certificate alert: sent ONLY when a certificate needs
# attention (missing, expired or expiring soon). Silent when all are OK,
# so certificate noise never mixes with the backup report again.
cert_section_file="${BROLIT_TMP_DIR}/certificates-${NOW}.mail"
if [[ -f "${cert_section_file}" ]] && grep -q "Certificates on server: WARNING" "${cert_section_file}" 2>/dev/null; then
    cert_alert_body="$(cat "${cert_section_file}")"
    mail_send_notification "⚠️ SSL certificates need attention on ${SERVER_NAME}" "${cert_alert_body}" "alert"
else
    log_event "debug" "All SSL certificates OK, skipping certificate alert email" "false"
fi

# Write e-mail (debug)
# echo "${mail_html}" >"${BROLIT_TMP_DIR}/email-${NOW}.mail"

# If NETDATA is installed, restore alarm status
[[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]] && netdata_alerts_enable

# Cleanup
cleanup

# Log End
log_event "info" "Exiting script ..." "false" "1"
