#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.1
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

if [ -t 1 ]; then

  # Running from terminal
  echo " > Error: The script can only be runned by runner. Exiting ..."

else

  # Running from cron
  log_event "info" "Running optimizer_tasks.sh from cron ..." "false"

  # Compare package versions
  #PKG_DETAILS=$(mail_package_section "${PACKAGES[@]}")
  #mail_package_status_section "${PKG_DETAILS}"
  #PKG_MAIL="${BAKWP}/pkg-${NOW}.mail"
  #PKG_MAIL_VAR=$(<"${PKG_MAIL}")

  # Check certificates installed
  #mail_cert_section
  #CERT_MAIL="${BAKWP}/cert-${NOW}.mail"
  #CERT_MAIL_VAR=$(<"${CERT_MAIL}")

  # Running scripts
  "${SFOLDER}/utils/server_and_image_optimizations.sh"
  
  #DB_MAIL="${BAKWP}/db-bk-${NOW}.mail"
  #DB_MAIL_VAR=$(<"${DB_MAIL}")

  #ONFIG_MAIL="${BAKWP}/config-bk-${NOW}.mail"
  #CONFIG_MAIL_VAR=$(<"${CONFIG_MAIL}")

  #FILE_MAIL="${BAKWP}/file-bk-${NOW}.mail"
  #FILE_MAIL_VAR=$(<"${FILE_MAIL}")

  #MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

  # Checking result status for mail subject
  #EMAIL_STATUS=$(mail_subject_status "${STATUS_D}" "${STATUS_F}" "${STATUS_S}" "${OUTDATED}")

  # Preparing email to send
  #log_event "info" "Sending Email to ${MAILA} ..." "true"

  #EMAIL_SUBJECT="${EMAIL_STATUS} on ${VPSNAME} Running Complete Backup - [${NOWDISPLAY}]"
  #EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${PKG_MAIL_VAR} ${CERT_MAIL_VAR} ${CONFIG_MAIL_VAR} ${DB_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

  # Sending email notification
  #send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

fi