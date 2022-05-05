#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc4
################################################################################

### Main dir check
BROLIT_MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BROLIT_MAIN_DIR=$(cd "$(dirname "${BROLIT_MAIN_DIR}")" && pwd)
if [[ -z "${BROLIT_MAIN_DIR}" ]]; then
  exit 1 # error; the path is not accessible
fi

# shellcheck source=${BROLIT_MAIN_DIR}/libs/commons.sh
source "${BROLIT_MAIN_DIR}/libs/commons.sh"

################################################################################

# Script Initialization
script_init "true"

# Running from cron
log_event "info" "Running backups_tasks.sh ..." "false"

# If NETDATA is installed, disabled alarms
if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then

  #The API is available by default, but it is protected by an api authorization token
  # that is stored in the file you will see in the following entry of http://NODE:19999/netdata.conf:
  # netdata management api key file = /var/lib/netdata/netdata.api.key

  netdata_api_key="$(cat /var/lib/netdata/netdata.api.key)"

  ## If all you need is temporarily disable all health checks, then you issue the following before your maintenance period starts:
  #curl "http://NODE:19999/api/v1/manage/health?cmd=DISABLE ALL" -H "X-Auth-Token: Mytoken"

  ## If you want the health checks to be running but to not receive any notifications during your maintenance period, you can instead use this:
  curl "http://localhost:19999/api/v1/manage/health?cmd=SILENCE ALL" -H "X-Auth-Token: ${netdata_api_key}"

  # Log
  log_event "info" "Disabling netdata alarms ..." "false"
  log_event "info" "Running: curl \"http://localhost:19999/api/v1/manage/health?cmd=SILENCE ALL\" -H \"X-Auth-Token: ${netdata_api_key}\"" "false"

fi

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
sed -i '/{{databases_backup_section}}/r '"${BROLIT_TMP_DIR}/db-bk-${NOW}.mail" "${email_html_file}"
sed -i '/{{configs_backup_section}}/r '"${BROLIT_TMP_DIR}/config-bk-${NOW}.mail" "${email_html_file}"
sed -i '/{{files_backup_section}}/r '"${BROLIT_TMP_DIR}/file-bk-${NOW}.mail" "${email_html_file}"
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

# Cleanup
remove_mail_notifications_files
cleanup

# Write e-mail (debug)
echo "${mail_html}" >"${BROLIT_TMP_DIR}/email-${NOW}.mail"

# Log End
log_event "info" "BACKUP TASKS SCRIPT End -- $(date +%Y%m%d_%H%M)" "false"
