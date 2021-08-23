#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.53
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
log_event "info" "Running backups_taks.sh ..."

log_event "info" "Running apt update ..."

# Update packages index
apt update

# BACKUP_ALL
log_section "Backup All"

# Preparing Mail Notifications Template
HTMLOPEN="$(mail_html_start)"
BODY_SRV="$(mail_server_status_section "${SERVER_IP}")"

# Compare package versions
mail_package_status_section "${PKG_DETAILS}"
PKG_MAIL="${TMP_DIR}/pkg-${NOW}.mail"
PKG_MAIL_VAR=$(<"${PKG_MAIL}")

# Certificates
log_subsection "Certbot Certificates"

# Check certificates installed
mail_cert_section
CERT_MAIL="${TMP_DIR}/cert-${NOW}.mail"
CERT_MAIL_VAR=$(<"${CERT_MAIL}")

# Databases Backup
make_all_databases_backup

# Files Backup
make_all_files_backup

#"${SFOLDER}/utils/server_and_image_optimizations.sh"

# Mail section for Database Backup
DB_MAIL="${TMP_DIR}/db-bk-${NOW}.mail"
DB_MAIL_VAR=$(<"${DB_MAIL}")

# Mail section for Server Config Backup
CONFIG_MAIL="${TMP_DIR}/config-bk-${NOW}.mail"
CONFIG_MAIL_VAR=$(<"${CONFIG_MAIL}")

# Mail section for Files Backup
FILE_MAIL="${TMP_DIR}/file-bk-${NOW}.mail"
FILE_MAIL_VAR=$(<"${FILE_MAIL}")

MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

# Checking result status for mail subject
EMAIL_STATUS=$(mail_subject_status "${STATUS_BACKUP_DBS}" "${STATUS_BACKUP_FILES}" "${STATUS_SERVER}" "${STATUS_CERTS}" "${OUTDATED_PACKAGES}")

# Preparing email to send
log_event "info" "Sending Email to ${MAILA} ..."

EMAIL_SUBJECT="${EMAIL_STATUS} [${NOWDISPLAY}] - Complete Backup on ${VPSNAME}"
EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${PKG_MAIL_VAR} ${CERT_MAIL_VAR} ${CONFIG_MAIL_VAR} ${DB_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

# Sending email notification
mail_send_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

remove_mail_notifications_files

# Script cleanup
cleanup

# Log End
log_event "info" "BACKUP TASKS SCRIPT End -- $(date +%Y%m%d_%H%M)"
