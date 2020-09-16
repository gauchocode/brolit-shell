#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.2
################################################################################

### Main dir check
SFOLDER=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
SFOLDER=$( cd "$( dirname "${SFOLDER}" )" && pwd )
if [ -z "${SFOLDER}" ]; then
  exit 1  # error; the path is not accessible
fi

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

log_event "info" "Running backups_tasks.sh" "true"

if [ -t 1 ]; then

  # Running from terminal
  echo " > Error: The script can only be runned by cron. Exiting ..."
  exit 1

else

  # Script Initialization
  script_init

  # shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
  source "${SFOLDER}/libs/mail_notification_helper.sh"

  # Running from cron
  log_event "info" "Running backups_taks.sh from cron ..." "false"

  log_event "info" "Running apt update ..." "false"

  # Update packages index
  apt update

  # Preparing Mail Notifications Template
  HTMLOPEN=$(mail_html_start)
  BODY_SRV=$(mail_server_status_section "${SERVER_IP}")

  # Compare package versions
  mail_package_status_section "${PKG_DETAILS}"
  PKG_MAIL="${BAKWP}/pkg-${NOW}.mail"
  PKG_MAIL_VAR=$(<"${PKG_MAIL}")

  # Check certificates installed
  mail_cert_section
  CERT_MAIL="${BAKWP}/cert-${NOW}.mail"
  CERT_MAIL_VAR=$(<"${CERT_MAIL}")

  # Running scripts
  "${SFOLDER}/utils/mysql_backup.sh"
  "${SFOLDER}/utils/files_backup.sh"
  #"${SFOLDER}/utils/server_and_image_optimizations.sh"
  
  # Mail section for Database Backup
  DB_MAIL="${BAKWP}/db-bk-${NOW}.mail"
  DB_MAIL_VAR=$(<"${DB_MAIL}")

  # Mail section for Server Config Backup
  CONFIG_MAIL="${BAKWP}/config-bk-${NOW}.mail"
  CONFIG_MAIL_VAR=$(<"${CONFIG_MAIL}")

  # Mail section for Files Backup
  FILE_MAIL="${BAKWP}/file-bk-${NOW}.mail"
  FILE_MAIL_VAR=$(<"${FILE_MAIL}")

  MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

  # Checking result status for mail subject
  EMAIL_STATUS=$(mail_subject_status "${STATUS_D}" "${STATUS_F}" "${STATUS_S}" "${OUTDATED}")

  # Preparing email to send
  log_event "info" "Sending Email to ${MAILA} ..." "false"

  EMAIL_SUBJECT="${EMAIL_STATUS} on ${VPSNAME} Running Complete Backup - [${NOWDISPLAY}]"
  EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${PKG_MAIL_VAR} ${CERT_MAIL_VAR} ${CONFIG_MAIL_VAR} ${DB_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

  # Sending email notification
  send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

  remove_mail_notifications_files

fi