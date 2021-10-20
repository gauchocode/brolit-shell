#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.63
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

# Running from cron
log_event "info" "Running optimizer_tasks.sh from cron ..." "false"

# Running scripts
optimize_images_complete

optimize_pdfs

delete_old_logs

remove_old_packages

optimize_ram_usage

#DB_MAIL="${TMP_DIR}/db-bk-${NOW}.mail"
#DB_MAIL_VAR=$(<"${DB_MAIL}")

#ONFIG_MAIL="${TMP_DIR}/config-bk-${NOW}.mail"
#CONFIG_MAIL_VAR=$(<"${CONFIG_MAIL}")

#FILE_MAIL="${TMP_DIR}/file-bk-${NOW}.mail"
#FILE_MAIL_VAR=$(<"${FILE_MAIL}")

#MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

# Checking result status for mail subject
#EMAIL_STATUS=$(mail_subject_status "${STATUS_BACKUP_DBS}" "${STATUS_BACKUP_FILES}" "${STATUS_SERVER}" "${OUTDATED_PACKAGES}")

# Preparing email to send
#log_event "info" "Sending Email to ${MAILA} ..." "true"

#EMAIL_SUBJECT="${EMAIL_STATUS} on ${VPSNAME} Complete Backup - [${NOWDISPLAY}]"
#EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${PKG_MAIL_VAR} ${CERT_MAIL_VAR} ${CONFIG_MAIL_VAR} ${DB_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

# Sending email notification
#mail_send_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"
