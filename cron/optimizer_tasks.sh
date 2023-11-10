#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.5
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
log_event "info" "Running optimizer_tasks.sh from cron ..." "false"

# If NETDATA is installed, disabled alarms
if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
  netdata_alerts_disable
fi

# Running scripts
optimize_images_complete

optimize_pdfs

delete_old_logs

packages_remove_old

optimize_ram_usage

#DB_MAIL="${BROLIT_TMP_DIR}/databases-bk-${NOW}.mail"
#DB_MAIL_VAR=$(<"${DB_MAIL}")

#ONFIG_MAIL="${BROLIT_TMP_DIR}/configuration-bk-${NOW}.mail"
#CONFIG_MAIL_VAR=$(<"${CONFIG_MAIL}")

#FILE_MAIL="${BROLIT_TMP_DIR}/files-bk-${NOW}.mail"
#FILE_MAIL_VAR=$(<"${FILE_MAIL}")

#MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

# Checking result status for mail subject
#EMAIL_STATUS=$(mail_subject_status "${STATUS_BACKUP_DBS}" "${STATUS_BACKUP_FILES}" "${STATUS_SERVER}" "${OUTDATED_PACKAGES}")

# Preparing email to send
#log_event "info" "Sending Email to ${NOTIFICATION_EMAIL_MAILA} ..." "true"

#EMAIL_SUBJECT="${EMAIL_STATUS} on ${SERVER_NAME} Complete Backup - [${NOWDISPLAY}]"
#EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${PKG_MAIL_VAR} ${CERT_MAIL_VAR} ${CONFIG_MAIL_VAR} ${DB_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

# If NETDATA is installed, enable alarms
if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
  netdata_alerts_enable
fi

# Sending email notification
#mail_send_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"
