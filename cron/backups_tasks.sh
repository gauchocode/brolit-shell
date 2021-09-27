#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.56
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
script_init

# Running from cron
log_event "info" "Running backups_tasks.sh ..." "false"

log_event "info" "Running apt update ..." "false"

# Update packages index
apt-get update -qq

# Mail section for Server status and Packages
mail_server_status_html="$(mail_server_status_section "${SERVER_IP}")"
mail_package_status_html="$(mail_package_status_section "${PKG_DETAILS}")"

# Certificates
log_subsection "Certbot Certificates"

# Check certificates installed
mail_certificates_html="$(mail_certificates_section)"

# BACKUP_ALL
log_section "Backup All"

# Databases Backup
make_all_databases_backup

# Files Backup
make_all_files_backup

# Mail section for Database Backup
mail_databases_backup_html=$(<"${TMP_DIR}/db-bk-${NOW}.mail")

# Mail section for Server Config Backup
mail_config_backup_html=$(<"${TMP_DIR}/config-bk-${NOW}.mail")

# Mail section for Files Backup
mail_file_backup_html=$(<"${TMP_DIR}/file-bk-${NOW}.mail")

# Footer
mail_footer_html="$(mail_footer "${SCRIPT_V}")"

# Preparing Mail Notifications Template
email_template="default"
mail_html="$(cat "${SFOLDER}/templates/emails/${email_template}/main-tpl.html")"

mail_html="$(${mail_html//"{{server_info}}"/${mail_server_status_html}})"
mail_html="$(${mail_html//"{{packages_section}}"/${mail_package_status_html}})"
mail_html="$(${mail_html//"{{certificates_section}}"/${mail_certificates_html}})"
mail_html="$(${mail_html//"{{configs_backup_section}}"/${mail_config_backup_html}})"
mail_html="$(${mail_html//"{{databases_backup_section}}"/${mail_databases_backup_html}})"
mail_html="$(${mail_html//"{{files_backup_section}}"/${mail_file_backup_html}})"
mail_html="$(${mail_html//"{{footer}}"/${mail_footer_html}})"

#mail_html="$(echo "${mail_html}" | sed -e "s/{{server_info}}/${mail_server_status_html}/g")"
#mail_html="$(echo "${mail_html}" | sed -e "s/{{packages_section}}/${mail_package_status_html}/g")"
#mail_html="$(echo "${mail_html}" | sed -e "s/{{certificates_section}}/${mail_certificates_html}/g")"
#mail_html="$(echo "${mail_html}" | sed -e "s/{{configs_backup_section}}/${mail_config_backup_html}/g")"
#mail_html="$(echo "${mail_html}" | sed -e "s/{{databases_backup_section}}/${mail_databases_backup_html}/g")"
#mail_html="$(echo "${mail_html}" | sed -e "s/{{files_backup_section}}/${mail_file_backup_html}/g")"
#mail_html="$(echo "${mail_html}" | sed -e "s/{{footer}}/${mail_footer_html}/g")"

# Checking result status for mail subject
email_status="$(mail_subject_status "${STATUS_BACKUP_DBS}" "${STATUS_BACKUP_FILES}" "${STATUS_SERVER}" "${STATUS_CERTS}" "${OUTDATED_PACKAGES}")"

# Preparing email to send
email_subject="${email_status} [${NOWDISPLAY}] - Complete Backup on ${VPSNAME}"

# Sending email notification
mail_send_notification "${email_subject}" "${mail_html}"

# Cleanup
#remove_mail_notifications_files
cleanup

# Write e-mail (debug)
echo "${mail_html}" >>"${TMP_DIR}/email-${NOW}.mail"

# Log End
log_event "info" "BACKUP TASKS SCRIPT End -- $(date +%Y%m%d_%H%M)" "false"
