#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.5
#############################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/mysql_helper.sh
source "${SFOLDER}/libs/mysql_helper.sh"
# shellcheck source=${SFOLDER}/libs/backup_helper.sh
source "${SFOLDER}/libs/backup_helper.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"
# shellcheck source=${SFOLDER}/libs/telegram_notification_helper.sh
source "${SFOLDER}/libs/telegram_notification_helper.sh"

################################################################################

# GLOBALS
BK_TYPE="File"
ERROR=false
ERROR_TYPE=""
SITES_F="sites"
CONFIG_F="configs"

export BK_TYPE
export SITES_F

# Starting Messages
log_event "info" "Starting files backup script" "false"
display --indent 2 --text "- Initializing files backup script" --result "DONE" --color GREEN

# MAILCOW Files
if [[ ${MAILCOW_BK} = true ]]; then

  if [ ! -d "${MAILCOW_TMP_BK}" ]; then
    log_event "info" "Folder ${MAILCOW_TMP_BK} doesn't exist. Creating now ..."
    mkdir "${MAILCOW_TMP_BK}"
    log_event "success" "Folder ${MAILCOW_TMP_BK} created"
  fi

  make_mailcow_backup "${MAILCOW}"

fi

# TODO: error_type needs refactoring

################################### SERVER CONFIG FILES ###################################

log_subsection "Backup Server Files"

# SERVER CONFIG FILES GLOBALS
declare -i BK_SCF_INDEX=0
declare -i BK_SCF_ARRAY_INDEX=0
declare -a BACKUPED_SCF_LIST
declare -a BK_SCF_SIZES

# TAR Webserver Config Files
if [[ ! -d ${WSERVER} ]]; then
  log_event "warning" "WSERVER var not defined! Skipping webserver config files backup ..." "true"

 else
  make_server_files_backup "${CONFIG_F}" "nginx" "${WSERVER}" "."

fi

# TAR PHP Config Files
if [[ ! -d ${PHP_CF} ]]; then
  log_event "warning" "PHP_CF var not defined! Skipping PHP config files backup ..." "true"

 else
  BK_SCF_INDEX="$((BK_SCF_INDEX + 1))"
  BK_SCF_ARRAY_INDEX="$((BK_SCF_ARRAY_INDEX + 1))"
  make_server_files_backup "${CONFIG_F}" "php" "${PHP_CF}" "."

fi

# TAR MySQL Config Files
if [[ ! -d ${MySQL_CF} ]]; then
  log_event "warning" "MySQL_CF var not defined! Skipping MySQL config files backup ..." "true"

 else
  BK_SCF_INDEX="$((BK_SCF_INDEX + 1))"
  BK_SCF_ARRAY_INDEX="$((BK_SCF_ARRAY_INDEX + 1))"
  make_server_files_backup "${CONFIG_F}" "mysql" "${MySQL_CF}" "."

fi

# TAR Let's Encrypt Config Files
if [[ ! -d ${LENCRYPT_CF} ]]; then
  log_event "warning" "LENCRYPT_CF var not defined! Skipping Letsencrypt config files backup ..." "true"

 else
  BK_SCF_INDEX="$((BK_SCF_INDEX + 1))"
  BK_SCF_ARRAY_INDEX="$((BK_SCF_ARRAY_INDEX + 1))"
  make_server_files_backup "${CONFIG_F}" "letsencrypt" "${LENCRYPT_CF}" "."

fi

# Configure Files Backup Section for Email Notification
mail_configbackup_section "${BACKUPED_SCF_LIST[@]}" "${BK_SCF_SIZES[@]}" "${ERROR}" "${ERROR_TYPE}"

################################### SITES FILES ###################################

log_subsection "Backup Sites Files"

# Get all directories
TOTAL_SITES=$(get_all_directories "${SITES}")

## Get length of $TOTAL_SITES
COUNT_TOTAL_SITES="$(find "${SITES}" -maxdepth 1 -type d -printf '.' | wc -c)"
COUNT_TOTAL_SITES="$((COUNT_TOTAL_SITES - 1))"

log_event "info" "Found ${COUNT_TOTAL_SITES} directories"
display --indent 2 --text "- Directories found" --result "${COUNT_TOTAL_SITES}" --color YELLOW

# FILES BACKUP GLOBALS
declare -i BK_FILE_INDEX=0
declare -i BK_FL_ARRAY_INDEX=0
declare -a BACKUPED_LIST
declare -a BK_FL_SIZES

k=0

for j in ${TOTAL_SITES}; do

  log_event "info" "Processing [${j}] ..."

  if [[ "$k" -gt 0 ]]; then

    FOLDER_NAME=$(basename "${j}")

    if [[ ${SITES_BL} != *"${FOLDER_NAME}"* ]]; then

      make_files_backup "site" "${SITES}" "${FOLDER_NAME}"
      BK_FL_ARRAY_INDEX="$((BK_FL_ARRAY_INDEX + 1))"

      log_break "true"

    else
      log_event "info" "Omitting ${FOLDER_NAME} (blacklisted) ..."

    fi

    BK_FILE_INDEX=$((BK_FILE_INDEX + 1))

    log_event "info" "Processed ${BK_FILE_INDEX} of ${COUNT_TOTAL_SITES} directories"

  fi

  k=$k+1

done

# Deleting old backup files
rm -r "${BAKWP:?}/${NOW}"

# DUPLICITY
duplicity_backup

# Configure Files Backup Section for Email Notification
mail_filesbackup_section "${BACKUPED_LIST[@]}" "${BK_FL_SIZES[@]}" "${ERROR}" "${ERROR_TYPE}"
