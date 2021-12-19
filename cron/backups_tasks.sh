#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.7
################################################################################

### Main dir check
SFOLDER=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SFOLDER=$(cd "$(dirname "${SFOLDER}")" && pwd)
if [[ -z "${SFOLDER}" ]]; then
  exit 1 # error; the path is not accessible
fi

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

# Script Initialization
script_init "true"

# Running from cron
log_event "info" "Running backups_tasks.sh ..." "false"

log_event "info" "Running apt update ..." "false"

# Update packages index
apt-get update -qq

# Mail section for Server status and Packages
mail_server_status_section
mail_package_status_section

# Certificates
log_subsection "Certbot Certificates"

# Check certificates installed
mail_certificates_section

# BACKUP_ALL
log_section "Backup All"

# Databases Backup
database_backup_result="$(make_all_databases_backup)"

# Files Backup
files_backup_result="$(make_all_files_backup)"

# Footer
mail_footer "${SCRIPT_V}"

# Preparing Mail Notifications Template
email_template="default"

# New full email file
email_html_file="${TMP_DIR}/full-email-${NOW}.mail"

# Copy from template
cp "${SFOLDER}/templates/emails/${email_template}/main-tpl.html" "${email_html_file}"

# Begin to replace
sed -i '/{{server_info}}/r '"${TMP_DIR}/server_info-${NOW}.mail" "${email_html_file}"
sed -i '/{{packages_section}}/r '"${TMP_DIR}/packages-${NOW}.mail" "${email_html_file}"
sed -i '/{{certificates_section}}/r '"${TMP_DIR}/certificates-${NOW}.mail" "${email_html_file}"
sed -i '/{{databases_backup_section}}/r '"${TMP_DIR}/db-bk-${NOW}.mail" "${email_html_file}"
sed -i '/{{configs_backup_section}}/r '"${TMP_DIR}/config-bk-${NOW}.mail" "${email_html_file}"
sed -i '/{{files_backup_section}}/r '"${TMP_DIR}/file-bk-${NOW}.mail" "${email_html_file}"
sed -i '/{{footer}}/r '"${TMP_DIR}/footer-${NOW}.mail" "${email_html_file}"

# Delete vars not used anymore
grep -v "{{server_info}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"
grep -v "{{packages_section}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"
grep -v "{{certificates_section}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"
grep -v "{{databases_backup_section}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"
grep -v "{{configs_backup_section}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"
grep -v "{{files_backup_section}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"
grep -v "{{footer}}" "${email_html_file}" > "${email_html_file}_tmp"; mv "${email_html_file}_tmp" "${email_html_file}"

# Send html to a var
mail_html="$(cat "${email_html_file}")"

# Checking result status for mail subject
email_status="$(mail_subject_status "${database_backup_result}" "${files_backup_result}" "${STATUS_SERVER}" "${STATUS_CERTS}" "${OUTDATED_PACKAGES}")"

# Preparing email to send
email_subject="${email_status} [${NOWDISPLAY}] - Complete Backup on ${VPSNAME}"

# Sending email notification
mail_send_notification "${email_subject}" "${mail_html}"

# Cleanup
#remove_mail_notifications_files
cleanup

# Write e-mail (debug)
echo "${mail_html}" >"${TMP_DIR}/email-${NOW}.mail"

# Log End
log_event "info" "BACKUP TASKS SCRIPT End -- $(date +%Y%m%d_%H%M)" "false"
