#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc07
#############################################################################

### Checking Script Execution
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
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

################################################################################

# GLOBALS
BK_TYPE="File"
ERROR=false
ERROR_TYPE=""
SITES_F="sites"
CONFIG_F="configs"

export BK_TYPE SITES_F

# Starting Message
echo " > Starting file backup script ..." >>$LOG
echo -e ${B_GREEN}" > Starting file backup script ..."${ENDCOLOR}

# MAILCOW Files
if [[ "${MAILCOW_BK}" = true ]]; then

  if [ ! -d "${MAILCOW_TMP_BK}" ]; then
    echo " > Folder ${MAILCOW_TMP_BK} doesn't exist. Creating now ..."
    mkdir "${MAILCOW_TMP_BK}"
    echo " > Folder ${MAILCOW_TMP_BK} created ..."
  fi

  make_mailcow_backup "${MAILCOW}"

fi

# TODO: error_type needs refactoring
# TODO: results of make_server_files_backup "configs" need to be on final mail notification

################################### SERVER CONFIG FILES ###################################

# SERVER CONFIG FILES GLOBALS
BK_SCF_INDEX=0
BK_SCF_ARRAY_INDEX=0
declare -a BACKUPED_SCF_LIST
declare -a BK_SCF_SIZES

# TAR Webserver Config Files
if [[ ! -d "${WSERVER}" ]]; then
  echo -e ${B_YELLOW}" > Warning: WSERVER var not defined! Skipping webserver config files backup ..."${ENDCOLOR}
  echo "> Warning: WSERVER var not defined! Skipping webserver config files backup ..." >>$LOG

 else
  make_server_files_backup "${CONFIG_F}" "nginx" "${WSERVER}" "."

fi

# TAR PHP Config Files
if [[ ! -d "${PHP_CF}" ]]; then
  echo -e ${B_YELLOW}" > Warning: PHP_CF var not defined! Skipping PHP config files backup ..."${ENDCOLOR}
  echo "> Warning: PHP_CF var not defined! Skipping PHP config files backup ..." >>$LOG

 else
  BK_SCF_INDEX=$BK_SCF_INDEX+1
  BK_SCF_ARRAY_INDEX=$BK_SCF_ARRAY_INDEX+1
  make_server_files_backup "${CONFIG_F}" "php" "${PHP_CF}" "."

fi

# TAR MySQL Config Files
if [[ ! -d "${MySQL_CF}" ]]; then
  echo -e ${B_YELLOW}" > Warning: MySQL_CF var not defined! Skipping MySQL config files backup ..."${ENDCOLOR}
  echo "> Warning: MySQL_CF var not defined! Skipping MySQL config files backup ..." >>$LOG

 else
  BK_SCF_INDEX=$BK_SCF_INDEX+1
  BK_SCF_ARRAY_INDEX=$BK_SCF_ARRAY_INDEX+1
  make_server_files_backup "${CONFIG_F}" "mysql" "${MySQL_CF}" "."

fi

# TAR Let's Encrypt Config Files
if [[ ! -d "${LENCRYPT_CF}" ]]; then
  echo -e ${B_YELLOW}" > Warning: LENCRYPT_CF var not defined! Skipping Letsencrypt config files backup ..."${ENDCOLOR}
  echo "> Warning: LENCRYPT_CF var not defined! Skipping Letsencrypt config files backup ..." >>$LOG

 else
  BK_SCF_INDEX=$BK_SCF_INDEX+1
  BK_SCF_ARRAY_INDEX=$BK_SCF_ARRAY_INDEX+1
  make_server_files_backup "${CONFIG_F}" "letsencrypt" "${LENCRYPT_CF}" "."

fi

# Configure Files Backup Section for Email Notification
echo -e ${CYAN}"> Preparing mail server configs section ..."${ENDCOLOR}
mail_configbackup_section "${BACKUPED_SCF_LIST[@]}" "${BK_SCF_SIZES[@]}" "${ERROR}" "${ERROR_TYPE}"

################################### SITES FILES ###################################

# Get all directories
TOTAL_SITES=$(get_all_directories "${SITES}")

## Get length of $TOTAL_SITES
COUNT_TOTAL_SITES=$(find ${SITES} -maxdepth 1 -type d -printf '.' | wc -c)
COUNT_TOTAL_SITES=$((${COUNT_TOTAL_SITES} - 1))

echo -e ${CYAN}" > ${COUNT_TOTAL_SITES} directory found ..."${ENDCOLOR}
echo " > ${COUNT_TOTAL_SITES} directory found ..." >>$LOG

# FILES BACKUP GLOBALS
BK_FILE_INDEX=0
BK_FL_ARRAY_INDEX=0
declare -a BACKUPED_LIST
declare -a BK_FL_SIZES

k=0

for j in ${TOTAL_SITES}; do

  echo -e ${CYAN}" > Processing [${j}] ..."${ENDCOLOR}

  if [[ "$k" -gt 0 ]]; then

    FOLDER_NAME=$(basename $j)

    if [[ $SITES_BL != *"${FOLDER_NAME}"* ]]; then

      make_files_backup "site" "${SITES}" "${FOLDER_NAME}"
      BK_FL_ARRAY_INDEX=$((BK_FL_ARRAY_INDEX + 1))

    else
      echo -e ${GREEN}" > Omitting ${FOLDER_NAME} TAR file (blacklisted) ..."${ENDCOLOR}
      echo " > Omitting ${FOLDER_NAME} TAR file (blacklisted) ..." >>$LOG

    fi

    BK_FILE_INDEX=$((BK_FILE_INDEX + 1))

    echo -e ${GREEN}" > Processed ${BK_FILE_INDEX} of ${COUNT_TOTAL_SITES} directories"${ENDCOLOR}
    echo "> Processed ${BK_FILE_INDEX} of ${COUNT_TOTAL_SITES} directories" >>$LOG

  fi

  echo -e ${MAGENTA}"######################################################################################################"${ENDCOLOR}
  echo "######################################################################################################" >>$LOG

  k=$k+1

done

# Deleting old backup files
rm -r "${BAKWP:?}/${NOW}"

# DUPLICITY
duplicity_backup

# Configure Files Backup Section for Email Notification
echo -e ${CYAN}"> Preparing mail files backup section ..."${ENDCOLOR}
mail_filesbackup_section "${BACKUPED_LIST[@]}" "${BK_FL_SIZES[@]}" "${ERROR}" "${ERROR_TYPE}"
