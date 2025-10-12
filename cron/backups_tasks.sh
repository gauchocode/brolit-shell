#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.4
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
        
        # Process each directory in PROJECTS_PATH
        for folder in "${PROJECTS_PATH}"/*; do

            if [ -d "${folder}" ]; then

                local folder_name
                folder_name=$(basename "${folder}")

                # Skip HTML directory
                if [ "${folder_name}" == "html" ]; then
                    continue
                fi

                log_event "info" "Processing project: ${folder_name}" "false"

                # Generate Borg configuration
                if ! generate_borg_config "${folder_name}"; then
                    log_event "error" "Skipping ${folder_name}: failed to generate borgmatic config" "false"
                    continue
                fi

            fi

        done

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

        cp "${BROLIT_MAIN_DIR}/config/borg/${template_file}" "${yml_file}"
        
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

        log_event "info" "Config file ${yml_file} generated." "false"

    else
        log_event "info" "Config file ${yml_file} already exists." "false"
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
    
    log_event "info" "Starting multi-method backup for: ${project_domain}" "false"
    
    # 1. Database backup with borgmatic (if configured)
    if [[ ${BACKUP_BORG_STATUS} == "enabled" ]] && [[ -f "/etc/borgmatic.d/${project_domain}.yml" ]]; then
        
        log_event "info" "Running borgmatic backup for ${project_domain}" "false"
        
        # Setup project directories and initialize repository if needed
        setup_project_directories "${project_domain}"
        initialize_repository_if_needed "/etc/borgmatic.d/${project_domain}.yml" "${project_domain}"
        
        # Run borgmatic backup
        if borgmatic --config "/etc/borgmatic.d/${project_domain}.yml" --stats; then
            log_event "info" "Borgmatic backup completed for ${project_domain}" "false"
        else
            log_event "error" "Borgmatic backup failed for ${project_domain}" "false"
        fi
        
    else
        
        # Fallback to traditional database backup for Docker projects
        if [[ -f "${PROJECTS_PATH}/${project_domain}/.env" ]]; then
            log_event "info" "Running traditional database backup for Docker project: ${project_domain}" "false"
            borg_backup_database "${project_domain}"
            
            if [[ $? -eq 0 ]]; then
                log_event "info" "Traditional database backup for ${project_domain} completed successfully." "false"
            else
                log_event "error" "Traditional database backup for ${project_domain} failed." "false"
            fi
        else
            log_event "info" "No database backup needed for project: ${project_domain}" "false"
        fi
        
    fi
    
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

# Iterate over projects in PROJECTS_PATH
for project_dir in "${PROJECTS_PATH}"/*/; do
    # Verify that the directory exists and is actually a directory
    if [[ -d "${project_dir}" ]]; then
        project_domain=$(basename "${project_dir}")
        
        # Multi-method backup for each project
        backup_project_all_enabled_methods "${project_domain}"
        
    fi
done

# Files Backup
files_backup_result="$(backup_all_files)"

# Footer
mail_footer "${SCRIPT_V}"

# Preparing Mail Notifications Template
email_template="default"

# New full email file
email_html_file="${BROLIT_TMP_DIR}/full-email-${NOW}.mail"

# Copy from template
cp "${BROLIT_MAIN_DIR}/templates/emails/${email_template}/main-tpl.html" "${email_html_file}"

# Begin to replace
sed -i '/{{server_info}}/r '"${BROLIT_TMP_DIR}/server_info-${NOW}.mail" "${email_html_file}"
sed -i '/{{packages_section}}/r '"${BROLIT_TMP_DIR}/packages-${NOW}.mail" "${email_html_file}"
sed -i '/{{certificates_section}}/r '"${BROLIT_TMP_DIR}/certificates-${NOW}.mail" "${email_html_file}"
sed -i '/{{databases_backup_section}}/r '"${BROLIT_TMP_DIR}/databases-bk-${NOW}.mail" "${email_html_file}"
sed -i '/{{configs_backup_section}}/r '"${BROLIT_TMP_DIR}/configuration-bk-${NOW}.mail" "${email_html_file}"
sed -i '/{{files_backup_section}}/r '"${BROLIT_TMP_DIR}/files-bk-${NOW}.mail" "${email_html_file}"
sed -i '/{{footer}}/r '"${BROLIT_TMP_DIR}/footer-${NOW}.mail" "${email_html_file}"

# Delete vars not used anymore
grep -v "{{server_info}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"
grep -v "{{packages_section}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"
grep -v "{{certificates_section}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"
grep -v "{{databases_backup_section}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"
grep -v "{{configs_backup_section}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"
grep -v "{{files_backup_section}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"
grep -v "{{footer}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"

# Send html to a var
mail_html="$(cat "${email_html_file}")"

# Checking result status for mail subject
email_status="$(mail_subject_status "${database_backup_result}" "${files_backup_result}" "${STATUS_SERVER}" "${STATUS_CERTS}" "${OUTDATED_PACKAGES}")"

# Preparing email to send
email_subject="${email_status} [${NOWDISPLAY}] - Complete Backup on ${SERVER_NAME}"

# Sending email notification
mail_send_notification "${email_subject}" "${mail_html}"

# Write e-mail (debug)
# echo "${mail_html}" >"${BROLIT_TMP_DIR}/email-${NOW}.mail"

# If NETDATA is installed, restore alarm status
[[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]] && netdata_alerts_enable

# Cleanup
cleanup

# Log End
log_event "info" "Exiting script ..." "false" "1"
