#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 3.0
#############################################################################

### Checking Script Execution
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/mysql_helper.sh
source ${SFOLDER}/libs/mail_notification_helper.sh

################################################################################

make_server_files_backup() {

  # TODO: la funcion deberia retornar el path completo al archivo backupeado. Ej: /root/tmp/bk.tar.bz2
  # TODO: en caso de error debería retornar algo también, quizá el error_type

  # TODO: BK_TYPE debería ser "archive, project, server_conf"
  #       BK_SUB_TYPE (pensar si es necesario)

  # $1 = Backup Type: configs, logs, data
  # $2 = Backup SubType: php,nginx,mysql
  # $3 = Path folder to Backup
  # $4 = Folder to Backup

  BK_TYPE=$1
  BK_SUB_TYPE=$2
  BK_DIR=$3
  BK_FOLDER=$4

  echo -e ${CYAN}"###################################################"${ENDCOLOR}

  if [ -n "${BK_DIR}" ]; then

    OLD_BK_FILE="${BK_SUB_TYPE}-${BK_TYPE}-files-${ONEWEEKAGO}.tar.bz2"
    BK_FILE="${BK_SUB_TYPE}-${BK_TYPE}-files-${NOW}.tar.bz2"

    echo -e ${CYAN}" > Trying to make a backup of ${BK_DIR} ..."${ENDCOLOR}
    echo " > Trying to make a backup of ${BK_DIR} ..." >>$LOG

    $TAR -cf ${BAKWP}/${NOW}/${BK_FILE} - --directory=${BK_DIR} ${BK_FOLDER} --use-compress-program=lbzip2

    # Test backup file
    lbzip2 -t ${BAKWP}/${NOW}/${BK_FILE}

    if [ $? -eq 0 ]; then

      echo -e ${GREEN}" > ${BK_FILE} backup created"${ENDCOLOR}
      echo " > ${BK_FILE} backup created" >>$LOG

      echo -e ${CYAN}" > Uploading TAR to Dropbox ..."${ENDCOLOR}
      echo " > Uploading TAR to Dropbox ..." >>$LOG
      ${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/${BK_FILE} ${DROPBOX_FOLDER}/${BK_TYPE}

      dropbox_delete_backup "${BK_TYPE}" "${CONFIG_F}" "${OLD_BK_FILE}"

      echo -e ${GREEN}" > DONE"${ENDCOLOR}
      echo " > DONE" >>$LOG

    else

      ERROR=true
      ERROR_TYPE="ERROR: No such directory or file ${BAKWP}/${NOW}/${BK_FILE}"

      echo -e ${RED}" > ERROR: Can't make the backup!"${ENDCOLOR}
      echo $ERROR_TYPE >>$LOG

    fi

  else

    echo -e ${RED}" > ERROR: Directory '${BK_DIR}' doesnt exists!"${ENDCOLOR}
    echo " > ERROR: Directory '${BK_DIR}' doesnt exists!" >>$LOG

  fi

  echo -e ${CYAN}"###################################################"${ENDCOLOR}
  echo "###################################################" >>$LOG

}

make_site_backup() {

  # $1 = Backup Type
  # $2 = Backup SubType
  # $3 = Path folder to Backup
  # $4 = Folder to Backup

  local BK_TYPE=$1     #configs,sites,databases
  local BK_SUB_TYPE=$2 #config_name,site_domain,database_name
  local SITES=$3
  local FOLDER_NAME=$4

  local OLD_BK_FILE="${FOLDER_NAME}_${BK_TYPE}-files_${ONEWEEKAGO}.tar.bz2"
  local BK_FILE="${FOLDER_NAME}_${BK_TYPE}-files_${NOW}.tar.bz2"

  #echo -e ${CYAN}" > Making TAR.BZ2 from: ${FOLDER_NAME} ..."${ENDCOLOR}
  echo " > Making TAR.BZ2 from: ${FOLDER_NAME} ..." >>$LOG

  (tar --exclude '.git' --exclude '*.log' -cf - --directory=${SITES} ${FOLDER_NAME} | pv -ns $(du -sb ${SITES}/${FOLDER_NAME} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}) 2>&1 | dialog --gauge 'Processing '${FILE_BK_INDEX}' of '${COUNT_TOTAL_SITES}' directories. Making tar.bz2 from: '${FOLDER_NAME} 7 70
  #TAR_FILE=$($TAR --exclude '.git' --exclude '*.log' -cpf ${BAKWP}/${NOW}/${BK_FILE} --directory=${SITES} ${FOLDER_NAME} --use-compress-program=lbzip2)

  # Test backup file
  lbzip2 -t ${BAKWP}/${NOW}/${BK_FILE}

  if [ $? -eq 0 ]; then

    echo -e ${GREEN}" > ${BK_FILE} OK!"${ENDCOLOR}
    echo " > ${BK_FILE} OK!" >>$LOG

    #if "${BAKWP}/${NOW}/${BK_FILE}"; then
    #if ${TAR_FILE}; then

    BACKUPED_LIST[$FILE_BK_INDEX]=${BK_FILE}
    BACKUPED_FL=${BACKUPED_LIST[$FILE_BK_INDEX]}

    # Calculate backup size
    BK_FL_SIZES[$FILE_BK_INDEX]=$(ls -lah ${BAKWP}/${NOW}/${BK_FILE} | awk '{ print $5}')
    BK_FL_SIZE=${BK_FL_SIZES[$FILE_BK_INDEX]}

    echo -e ${GREEN}" > Backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE} ..."${ENDCOLOR}
    echo " > Backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE} ..." >>$LOG

    echo -e ${CYAN}" > Trying to create folder in Dropbox ..."${ENDCOLOR}
    echo " > Trying to create folders in Dropbox ..." >>$LOG

    ${DPU_F}/dropbox_uploader.sh -q mkdir /${SITES_F}

    # New folder structure with date
    ${DPU_F}/dropbox_uploader.sh -q mkdir /${SITES_F}/${FOLDER_NAME}
    #${DPU_F}/dropbox_uploader.sh -q mkdir /${SITES_F}/${FOLDER_NAME}/${NOW}

    echo -e ${CYAN}" > Uploading ${FOLDER_NAME} to Dropbox ..."${ENDCOLOR}
    echo " > Uploading ${FOLDER_NAME} to Dropbox ..." >>$LOG
    ${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/${BK_FILE} $DROPBOX_FOLDER/${SITES_F}/${FOLDER_NAME}/
    #${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/${BK_FILE} ${DROPBOX_FOLDER}/${SITES_F}/${FOLDER_NAME}/${NOW}

    echo -e ${CYAN}" > Trying to delete old backup from Dropbox with date ${ONEWEEKAGO} ..."${ENDCOLOR}
    echo " > Trying to delete old backup from Dropbox with date ${ONEWEEKAGO} ..." >>$LOG
    #${DPU_F}/dropbox_uploader.sh delete ${DROPBOX_FOLDER}/${SITES_F}/${FOLDER_NAME}/${ONEWEEKAGO}
    ${DPU_F}/dropbox_uploader.sh remove ${DROPBOX_FOLDER}/${SITES_F}/${FOLDER_NAME}/${OLD_BK_FILE}

    echo " > Deleting backup from server ..." >>$LOG
    rm -r ${BAKWP}/${NOW}/${BK_FILE}

    echo -e ${GREEN}" > DONE"${ENDCOLOR}

  else
    ERROR=true
    ERROR_TYPE="ERROR: Making backup ${BAKWP}/${NOW}/${BK_FILE}"
    echo ${ERROR_TYPE} >>$LOG

  fi

}

dropbox_upload_backup() {

  # $1 = Backup Type
  # $2 = Dropbox Folder to upload backup
  # $3 = Backup File to upload (entire path)

  DP_BK_TYPE=$1
  DP_BK_DIR=$2
  DP_BK_FILE=$3

  echo -e ${CYAN}" > Uploading backup to Dropbox ..."${ENDCOLOR}
  echo " > Uploading backup to Dropbox ..." >>$LOG
  ${DPU_F}/dropbox_uploader.sh upload ${DP_BK_FILE} ${DROPBOX_FOLDER}/${DP_BK_DIR}

}

dropbox_delete_backup() {

  # $1 = Backup Type
  # $2 = Dropbox Folder to delete backup
  # $3 = Backup File to delete (entire path)

  DP_BK_TYPE=$1
  DP_BK_DIR=$2
  DP_BK_FILE=$3

  echo -e ${CYAN}" > Trying to delete old backup from Dropbox ..."${ENDCOLOR}
  echo " > Trying to delete old backup from Dropbox ..." >>$LOG
  ${DPU_F}/dropbox_uploader.sh remove ${DP_BK_DIR}/${DP_BK_FILE}

}

duplicity_backup() {

  if [ "${DUP_BK}" = true ]; then

    # Check if DUPLICITY is installed
    DUPLICITY="$(which duplicity)"
    if [ ! -x "${DUPLICITY}" ]; then
      apt-get install duplicity
    fi

    # Loop in to Directories
    for i in $(echo ${DUP_FOLDERS} | sed "s/,/ /g"); do
      duplicity --full-if-older-than ${DUP_BK_FULL_FREQ} -v4 --no-encryption ${DUP_SRC_BK}$i file://${DUP_ROOT}$i
      RETVAL=$?

      # TODO: solo deberia borrar lo viejo si $RETVAL -eq 0
      duplicity remove-older-than ${DUP_BK_FULL_LIFE} --force ${DUP_ROOT}/$i

    done

    [ $RETVAL -eq 0 ] && echo "*** DUPLICITY SUCCESS ***" >>$LOG
    [ $RETVAL -ne 0 ] && echo "*** DUPLICITY ERROR ***" >>$LOG

  fi

}

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
COUNT_TOTAL_SITES=$(find /var/www -maxdepth 1 -type d -printf '.' | wc -c)
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
