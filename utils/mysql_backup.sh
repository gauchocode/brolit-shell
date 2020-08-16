#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/mysql_helper.sh
source "${SFOLDER}/libs/mysql_helper.sh"
# shellcheck source=${SFOLDER}/libs/backup_helper.sh
source "${SFOLDER}/libs/backup_helper.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"

#############################################################################

# GLOBALS
BK_TYPE="database"
ERROR=false
ERROR_TYPE=""
DBS_F="databases"

export BK_TYPE DBS_F

# Starting Message
log_event "" "################################################################################################" "true"
log_event "info" "Starting database backup script" "true"

# Get MySQL DBS
DBS="$(${MYSQL} -u "${MUSER}" -p"${MPASS}" -Bse 'show databases')"

# Get all databases name
TOTAL_DBS=$(mysql_count_dabases "${DBS}")
log_event "info" "Databases found: ${TOTAL_DBS}" "true"

# MORE GLOBALS
BK_DB_INDEX=0
declare -a BACKUPED_DB_LIST
declare -a BK_DB_SIZES

for DATABASE in ${DBS}; do

  log_event "info" "Processing [${DATABASE}] ..." "true"

  if [[ ${DB_BL} != *"${DATABASE}"* ]]; then

    make_database_backup "database" "${DATABASE}"

    BK_DB_INDEX=$((BK_DB_INDEX + 1))

    log_event "success" "Backup ${BK_DB_INDEX} of ${TOTAL_DBS} done" "true"

    log_event "" "################################################################################################" "true"

  else
    log_event "info" "Ommiting the blacklisted database: [${DATABASE}]" "true"

  fi

done

# Configure Email
log_event "info" "Preparing mail databases backup section ..." "true"
mail_mysqlbackup_section "${BACKUPED_DB_LIST[@]}" "${BK_DB_SIZES[@]}" "${ERROR}" "${ERROR_TYPE}"