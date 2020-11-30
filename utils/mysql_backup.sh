#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.7
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e "${RED} > Error: The script can only be runned by runner.sh! Exiting ...${ENDCOLOR}"
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
declare -g BK_TYPE="database"
declare -g ERROR=false
declare -g ERROR_TYPE=""
declare -g DBS_F="databases"

export BK_TYPE DBS_F

# Starting Messages
log_break
log_event "info" "Starting database backup script"
log_subsection "Backup Databases"
display --indent 6 --text "- Initializing database backup script" --result "DONE" --color GREEN

# Get MySQL DBS
DBS=$(${MYSQL} -u "${MUSER}" -p"${MPASS}" -Bse 'show databases')
clear_last_line #to remove mysql warning message

# Get all databases name
TOTAL_DBS="$(mysql_count_dabases "${DBS}")"
log_event "info" "Databases found: ${TOTAL_DBS}"
display --indent 6 --text "- Databases found" --result "${TOTAL_DBS}" --color GREEN

# MORE GLOBALS
declare -g BK_DB_INDEX=0
declare -a BACKUPED_DB_LIST
declare -a BK_DB_SIZES

for DATABASE in ${DBS}; do

  log_event "info" "Processing [${DATABASE}] ..."

  if [[ ${DB_BL} != *"${DATABASE}"* ]]; then

    make_database_backup "database" "${DATABASE}"

    BK_DB_INDEX=$((BK_DB_INDEX + 1))

    log_event "success" "Backup ${BK_DB_INDEX} of ${TOTAL_DBS} done"

    log_break "true"

  else
    log_event "info" "Ommiting the blacklisted database: [${DATABASE}]"
    #display --indent 2 --text "- Database backup for ${DATABASE}" --result "OMMITED" --color YELLOW
    #display --indent 4 --text "Database found on blacklist"

  fi

done

# Configure Email
log_event "info" "Preparing mail databases backup section ..."
mail_mysqlbackup_section "${BACKUPED_DB_LIST[@]}" "${BK_DB_SIZES[@]}" "${ERROR}" "${ERROR_TYPE}"