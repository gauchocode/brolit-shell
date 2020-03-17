#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-beta7
#############################################################################

### Checking Script Execution
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/mysql_helper.sh
source ${SFOLDER}/libs/backup_helper.sh
source ${SFOLDER}/libs/mail_notification_helper.sh

################################################################################

# GLOBALS
BK_TYPE="File"
ERROR=false
ERROR_TYPE=""
SITES_F="sites"
CONFIG_F="configs"

# Starting Message
echo " > Starting file backup script ..." >>$LOG
echo -e ${GREEN}" > Starting file backup script ..."${ENDCOLOR}

# MAILCOW Files
if [[ "${MAILCOW_BK}" = true ]]; then
  make_mailcow_backup "${MAILCOW}"
fi

echo " > Creating Dropbox folder ${CONFIG_F} on Dropbox ..." >>$LOG
${DPU_F}/dropbox_uploader.sh mkdir /${CONFIG_F}

# TODO: refactor del manejo de ERRORES
# ojo que si de make_server_files_backup sale con error,
# en el mail manda warning pero en ningun lugar se muestra el error

# TAR Webserver Config Files
make_server_files_backup "configs" "nginx" "${WSERVER}" "."

# TAR PHP Config Files
make_server_files_backup "configs" "php" "${PHP_CF}" "."

# TAR MySQL Config Files
make_server_files_backup "configs" "mysql" "${MySQL_CF}" "."

# TAR Let's Encrypt Config Files
make_server_files_backup "configs" "letsencrypt" "${LENCRYPT_CF}" "."

# Get all directories
TOTAL_SITES=$(find ${SITES} -maxdepth 1 -type d)

## Get length of $TOTAL_SITES
COUNT_TOTAL_SITES=$(find ${SITES} -maxdepth 1 -type d -printf '.' | wc -c)
COUNT_TOTAL_SITES=$((${COUNT_TOTAL_SITES} - 1))

echo -e ${CYAN}" > ${COUNT_TOTAL_SITES} directory found ..."${ENDCOLOR}
echo " > ${COUNT_TOTAL_SITES} directory found ..." >>$LOG

# MORE GLOBALS
FILE_BK_INDEX=1
declare -a BACKUPED_LIST
declare -a BK_FL_SIZES

k=0

for j in ${TOTAL_SITES}; do

  echo -e ${YELLOW}" > Processing [${j}] ..."${ENDCOLOR}

  if [[ "$k" -gt 0 ]]; then

    FOLDER_NAME=$(basename $j)

    if [[ $SITES_BL != *"${FOLDER_NAME}"* ]]; then

      make_site_backup "site" "${FOLDER_NAME}" "${SITES}" "${FOLDER_NAME}"

    else
      echo " > Omiting ${FOLDER_NAME} TAR file (blacklisted) ..." >>$LOG

    fi

    echo -e ${GREEN}" > Processed ${FILE_BK_INDEX} of ${COUNT_TOTAL_SITES} directories"${ENDCOLOR}
    echo "> Processed ${FILE_BK_INDEX} of ${COUNT_TOTAL_SITES} directories" >>$LOG

    FILE_BK_INDEX=$((FILE_BK_INDEX + 1))

  fi

  echo -e ${CYAN}"###################################################"${ENDCOLOR}
  echo "###################################################" >>$LOG

  k=$k+1

done

# Deleting old backup files
rm -r ${BAKWP}/${NOW}

# DUPLICITY
duplicity_backup

# Configure Email
mail_filesbackup_section "${ERROR}" "${ERROR_TYPE}" ${BACKUPED_LIST} ${BK_FL_SIZES}
