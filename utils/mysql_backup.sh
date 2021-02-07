#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.13
#############################################################################

# shellcheck source=${SFOLDER}/libs/mysql_helper.sh
source "${SFOLDER}/libs/mysql_helper.sh"
# shellcheck source=${SFOLDER}/libs/backup_helper.sh
source "${SFOLDER}/libs/backup_helper.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"

#############################################################################

function make_all_databases_backup() {

  # GLOBALS
  declare -g BK_TYPE="database"
  declare -g ERROR=false
  declare -g ERROR_TYPE=""
  declare -g DBS_F="databases"

  export BK_TYPE DBS_F

  # Starting Messages
  log_subsection "Backup Databases"
  display --indent 6 --text "- Initializing database backup script" --result "DONE" --color GREEN

  # Get MySQL DBS
  DBS=$("${MYSQL}" -u "${MUSER}" -p"${MPASS}" -Bse 'show databases')
  clear_last_line #to remove mysql warning message

  # Get all databases name
  TOTAL_DBS="$(mysql_count_dabases "${DBS}")"
  log_event "info" "Databases found: ${TOTAL_DBS}"
  display --indent 6 --text "- Databases found" --result "${TOTAL_DBS}" --color WHITE

  log_break "true"

  # MORE GLOBALS
  declare -g BK_DB_INDEX=0

  for DATABASE in ${DBS}; do

    if [[ ${DB_BL} != *"${DATABASE}"* ]]; then

      log_event "info" "Processing [${DATABASE}] ..."

      make_database_backup "database" "${DATABASE}"

      BK_DB_INDEX=$((BK_DB_INDEX + 1))

      log_event "success" "Backup ${BK_DB_INDEX} of ${TOTAL_DBS} done"

      log_break "true"

    else
      log_event "debug" "Ommiting blacklisted database: [${DATABASE}]"

    fi

  done

  # Configure Email
  log_event "debug" "Preparing mail databases backup section ..."
  mail_mysqlbackup_section "${ERROR}" "${ERROR_TYPE}"

}