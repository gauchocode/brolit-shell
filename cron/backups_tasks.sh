#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.3
################################################################################

### Main dir check
BROLIT_MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BROLIT_MAIN_DIR=$(cd "$(dirname "${BROLIT_MAIN_DIR}")" && pwd)

[[ -z "${BROLIT_MAIN_DIR}" ]] && exit 1 # error; the path is not accessible

# shellcheck source=${BROLIT_MAIN_DIR}/libs/commons.sh
source "${BROLIT_MAIN_DIR}/libs/commons.sh"

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

# BACKUP_ALL
log_section "Backup All"

# Databases Backup
database_backup_result="$(backup_all_databases)"
docker_database_backup_result="$(backup_all_databases_docker)"
# Borg Backup for Databases (loop through all projects in /var/www)
for project_domain in $(ls /var/www); do
    log_event "info" "Starting Borg backup for project: ${project_domain}" "false"
    
    borg_backup_database "${project_domain}"
    
    if [[ $? -eq 0 ]]; then
        log_event "info" "Borg backup for ${project_domain} completed successfully." "false"
    else
        log_event "error" "Borg backup for ${project_domain} failed." "false"
    fi
done
# Files Backup
files_backup_result="$(backup_all_files)"

# Root Project Backup (.airbyte)
log_event "info" "Starting backup of .airbyte directory" "false"
airbyte_backup_result="$(backup_root_project ".airbyte" "all")"
if [[ $? -eq 0 ]]; then
    log_event "info" "Backup of .airbyte directory completed successfully." "false"
else
    log_event "error" "Backup of .airbyte directory failed." "false"
fi

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
