#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.5
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

        local number_of_servers
        number_of_servers=$(jq ".BACKUPS.methods[].borg[].config | length" /root/.brolit_conf.json 2>/dev/null || echo "0")

        # Counters for reporting
        local total_projects=0
        local configs_created=0
        local configs_existing=0
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
        log_event "info" "Configs failed: ${configs_failed}" "false"

        display --indent 4 --text "Borgmatic configuration summary:" --tcolor YELLOW
        display --indent 6 --text "Total projects: ${total_projects}" --tcolor WHITE
        display --indent 6 --text "New configs created: ${configs_created}" --tcolor GREEN
        display --indent 6 --text "Existing configs: ${configs_existing}" --tcolor BLUE

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

# Generate Borg configuration file for a specific project
function generate_borg_config() {

    local project_name="${1}"
    local yml_file="/etc/borgmatic.d/${project_name}.yml"
    local project_install_type

    project_install_type="$(project_get_install_type "/var/www/${project_name}" 2>/dev/null || echo "unknown")"

    # Check if config file already exists
    if [ ! -f "${yml_file}" ]; then

        log_event "info" "Config file ${yml_file} does not exist" "false"
        log_event "info" "Generating configuration file..." "false"

        # Determine template file based on project type
        if [ "${project_install_type}" == "default" ]; then
            # For non-Docker projects, determine DB engine
            db_engine=$(project_get_database_engine "${project_name}" "${project_install_type}" 2>/dev/null || echo "")

            if [ -z "${db_engine}" ]; then
                # Default to mysql template if engine cannot be determined
                template_file="borgmatic.template-mysql.yml"
            else
                template_file="borgmatic.template-${db_engine}.yml"
            fi
        else
            # Normalize Docker install types to existing template
            if [[ "${project_install_type}" == "docker"* ]]; then
                template_file="borgmatic.template-docker.yml"
            else
                template_file="borgmatic.template-${project_install_type}.yml"
            fi
        fi

        # Verify template exists
        if [ ! -f "${BROLIT_MAIN_DIR}/config/borg/${template_file}" ]; then
            log_event "error" "Template ${template_file} not found, using default template" "false"
            template_file="borgmatic.template-default.yml"
        fi

        # Final check if default template exists
        if [ ! -f "${BROLIT_MAIN_DIR}/config/borg/${template_file}" ]; then
            log_event "error" "No template file available for ${project_name}" "false"
            echo "failed"
            return 1
        fi

        cp "${BROLIT_MAIN_DIR}/config/borg/${template_file}" "${yml_file}"

        if [ $? -ne 0 ]; then
            log_event "error" "Failed to copy template for ${project_name}" "false"
            echo "failed"
            return 1
        fi

        # Erase placeholder repositories to avoid duplication
        yq -i '.repositories = []' "${yml_file}" 2>/dev/null || true

        # Update configuration file with project-specific values
        PROJECT="${project_name}" yq -i '.constants.project = strenv(PROJECT)' "${yml_file}" 2>/dev/null || true
        GROUP="${BACKUP_BORG_GROUP}" yq -i '.constants.group = strenv(GROUP)' "${yml_file}" 2>/dev/null || true
        HOST="${HOSTNAME}" yq -i '.constants.hostname = strenv(HOST)' "${yml_file}" 2>/dev/null || true

        # Add server configuration for each backup server
        local number_of_servers
        number_of_servers=$(jq ".BACKUPS.methods[].borg[].config | length" /root/.brolit_conf.json 2>/dev/null || echo "0")
        for i in $(seq 1 "$number_of_servers"); do

            local user_var="user_${i}"
            local server_var="server_${i}"
            local port_var="port_${i}"

            # Add server configuration to constants
            USER_VALUE="${BACKUP_BORG_USERS[i-1]}" yq -i ".constants.${user_var} = strenv(USER_VALUE)" "${yml_file}" 2>/dev/null || true
            SERVER_VALUE="${BACKUP_BORG_SERVERS[i-1]}" yq -i ".constants.${server_var} = strenv(SERVER_VALUE)" "${yml_file}" 2>/dev/null || true
            PORT_VALUE="${BACKUP_BORG_PORTS[i-1]}" yq -i ".constants.${port_var} = strenv(PORT_VALUE)" "${yml_file}" 2>/dev/null || true

            # Add repository configuration using yq for safety
            yq -i ".repositories += [{\"path\": \"ssh://{${user_var}}@{${server_var}}:{${port_var}}/home/applications/{group}/{hostname}/projects-online/site/{project}\", \"label\": \"storage-{${user_var}}\"}]" "${yml_file}" 2>/dev/null || true

        done

        # Verify the config file was created successfully
        if [ -f "${yml_file}" ]; then
            log_event "info" "Config file ${yml_file} generated successfully." "false"
            echo "created"
            return 0
        else
            log_event "error" "Config file ${yml_file} creation failed." "false"
            echo "failed"
            return 1
        fi

    else
        log_event "debug" "Config file ${yml_file} already exists." "false"
        echo "exists"
        return 0
    fi

}

# Prepare borgmatic environment if enabled
function prepare_borgmatic_environment() {
    
    # Load configuration and ensure borgmatic templates exist
    load_configurations
    generate_config    # Only generates missing configs
    
    log_event "info" "Borgmatic environment preparation completed" "false"
    
}

# Backup project using all enabled methods
function backup_project_all_enabled_methods() {

    local project_domain="${1}"
    local backup_status=0

    log_event "info" "Starting multi-method backup for: ${project_domain}" "false"

    # Check if Borg is enabled
    if [[ ${BACKUP_BORG_STATUS} == "enabled" ]]; then

        # Verify config file exists
        if [[ -f "/etc/borgmatic.d/${project_domain}.yml" ]]; then

            log_event "info" "Running borgmatic backup for ${project_domain}" "false"
            display --indent 6 --text "- Backing up ${project_domain} with borgmatic" --tcolor YELLOW

            # Setup project directories and initialize repository if needed
            setup_project_directories "${project_domain}"
            initialize_repository_if_needed "/etc/borgmatic.d/${project_domain}.yml" "${project_domain}"

            # Run borgmatic backup
            if borgmatic --config "/etc/borgmatic.d/${project_domain}.yml" --stats; then
                log_event "info" "Borgmatic backup completed for ${project_domain}" "false"
                display --indent 8 --text "Backup completed" --result "DONE" --color GREEN
            else
                log_event "error" "Borgmatic backup failed for ${project_domain}" "false"
                display --indent 8 --text "Backup failed" --result "FAIL" --color RED
                backup_status=1
            fi

        else

            # Config file missing - log warning
            log_event "warning" "Borgmatic config missing for ${project_domain} at /etc/borgmatic.d/${project_domain}.yml" "false"
            display --indent 6 --text "- No borgmatic config for ${project_domain}" --result "SKIP" --color YELLOW

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
database_backup_result="$(backup_all_databases)"

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

# Initialize borg backup status
borg_backup_result=0

# Iterate over projects in PROJECTS_PATH
for project_dir in "${PROJECTS_PATH}"/*/; do
    # Verify that the directory exists and is actually a directory
    if [[ -d "${project_dir}" ]]; then
        project_domain=$(basename "${project_dir}")

        # Multi-method backup for each project
        backup_project_all_enabled_methods "${project_domain}"

        # Capture any borg failures during project backups
        if [[ $? -ne 0 ]]; then
            borg_backup_result=1
        fi

    fi
done

# Files Backup
files_backup_result="$(backup_all_files)"

# Backup All with Borg (runs borgmatic for all project configs if enabled)
if [[ ${BACKUP_BORG_STATUS} == "enabled" ]]; then
    backup_all_files_with_borg
    if [[ $? -ne 0 ]]; then
        borg_backup_result=1
    fi
fi

# Footer
mail_footer "${SCRIPT_V}"

# Preparing Mail Notifications Template
email_html_file="${BROLIT_TMP_DIR}/full-email-${NOW}.mail"

# Assemble complete email using new template engine
# This replaces the previous 21 lines of grep/sed/mv operations with a single function call
if ! mail_template_assemble "${email_html_file}" "main" \
    "${BROLIT_TMP_DIR}/server_info-${NOW}.mail" \
    "${BROLIT_TMP_DIR}/packages-${NOW}.mail" \
    "${BROLIT_TMP_DIR}/certificates-${NOW}.mail" \
    "${BROLIT_TMP_DIR}/databases-bk-${NOW}.mail" \
    "${BROLIT_TMP_DIR}/configuration-bk-${NOW}.mail" \
    "${BROLIT_TMP_DIR}/files-bk-${NOW}.mail" \
    "${BROLIT_TMP_DIR}/footer-${NOW}.mail"; then
    log_event "error" "Failed to assemble email template" "false"
    display --indent 6 --text "- Assembling email template" --result "FAIL" --color RED
    return 1
fi

# Send html to a var
mail_html="$(cat "${email_html_file}")"

# Checking result status for mail subject (including borg backup status)
email_status="$(mail_subject_status "${database_backup_result}" "${files_backup_result}" "${STATUS_SERVER}" "${STATUS_CERTS}" "${OUTDATED_PACKAGES}" "${borg_backup_result}")"

# Preparing email to send
email_subject="${email_status} [${NOWDISPLAY}] - Complete Backup on ${SERVER_NAME}"

# Determine notification status based on all backup results
notification_status="success"
notification_message="Complete backup completed successfully."

if [[ ${database_backup_result} -eq 1 ]] || [[ ${files_backup_result} -eq 1 ]] || [[ ${borg_backup_result} -eq 1 ]]; then
    notification_status="alert"
    notification_message="Complete backup completed with errors. Check logs for details."
fi

# Sending email notification
mail_send_notification "${email_subject}" "${mail_html}"

# Send push notification if available
send_notification "${SERVER_NAME}" "${notification_message}" "${notification_status}"

# Write e-mail (debug)
# echo "${mail_html}" >"${BROLIT_TMP_DIR}/email-${NOW}.mail"

# If NETDATA is installed, restore alarm status
[[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]] && netdata_alerts_enable

# Cleanup
cleanup

# Log End
log_event "info" "Exiting script ..." "false" "1"
