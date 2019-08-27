#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9.7
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/mysql_helper.sh
source ${SFOLDER}/libs/mail_notification_helper.sh

################################################################################

make_files_backup() {

  # TODO: separar a otra funcion el upload de dropbox y el delete del viejo backup
  # TODO: la funcion deberia retornar el path completo al archivo backupeado. Ej: /root/tmp/bk.tar.bz2
  # TODO: en caso de error debería retornar algo también, quizá el error_type

  # TODO: BK_TYPE debería ser "archive, project, server_conf"
  #       BK_SUB_TYPE (pensar si es necesario)

  # $1 = Backup Type
  # $2 = Backup SubType
  # $3 = Path folder to Backup
  # $4 = Folder to Backup

  BK_TYPE=$1     #configs,sites,databases
  BK_SUB_TYPE=$2 #config_name,site_domain,database_name
  BK_DIR=$3
  BK_FOLDER=$4

  echo -e ${CYAN}"###################################################"${ENDCOLOR}

  if [ -n "${BK_DIR}" ]; then

    echo " > Trying to make a backup of ${BK_DIR} ..." >>$LOG
    echo -e ${GREEN}" > Trying to make a backup of ${BK_DIR} ..."${ENDCOLOR}

    TAR_FILE=$($TAR -jcpf ${BAKWP}/${NOW}/${BK_SUB_TYPE}-${BK_TYPE}-files-${NOW}.tar.bz2 --directory=${BK_DIR} .)

    if ${TAR_FILE}; then

      echo " > ${BK_TYPE} backup created..." >>$LOG
      echo " > Uploading TAR to Dropbox ..." >>$LOG
      ${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/${BK_SUB_TYPE}-${BK_TYPE}-files-${NOW}.tar.bz2 ${DROPBOX_FOLDER}/${BK_TYPE}

      echo " > Trying to delete old backup from Dropbox ..." >>$LOG
      dropbox_delete_backup "${BK_TYPE}" "${CONFIG_F}" "${BK_SUB_TYPE}-${BK_TYPE}-files-${ONEWEEKAGO}.tar.bz2"
      #${DPU_F}/dropbox_uploader.sh remove ${CONFIG_F}/webserver-config-files-${ONEWEEKAGO}.tar.bz2

      echo -e ${GREEN}" > DONE"${ENDCOLOR}

    else

      ERROR=true
      ERROR_TYPE="ERROR: No such directory or file ${BAKWP}/${NOW}/${BK_SUB_TYPE}-${BK_TYPE}-files-${NOW}.tar.bz2"

      echo -e ${RED}" > ERROR: Can't make the backup!"${ENDCOLOR}

      echo $ERROR_TYPE >>$LOG

    fi

  else

    echo -e ${RED}" > ERROR: Directory '${BK_DIR}' doesnt exists!"${ENDCOLOR}

  fi

  echo -e ${CYAN}"###################################################"${ENDCOLOR}
  echo " ###################################################" >>$LOG

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

  echo -e ${YELLOW}" > Trying to delete old backup from Dropbox ..."${ENDCOLOR}
  echo " > Trying to delete old backup from Dropbox ..." >>$LOG
  ${DPU_F}/dropbox_uploader.sh remove ${DP_BK_DIR}/${DP_BK_FILE}

}

################################################################################

# TODO: refactor del manejo de ERRORES

### VARS
BK_TYPE="File"
ERROR=false
ERROR_TYPE=""
SITES_F="sites"
CONFIG_F="configs"

### Starting Message
echo " > Starting file backup script ..." >>$LOG
echo -e ${GREEN}" > Starting file backup script ..."${ENDCOLOR}

echo " > Creating Dropbox folder ${CONFIG_F} on Dropbox ..." >>$LOG
${DPU_F}/dropbox_uploader.sh mkdir /${CONFIG_F}

### TAR Webserver Config Files
make_files_backup "configs" "nginx" "${WSERVER}" "."

### TAR PHP Config Files
make_files_backup "configs" "php" "${PHP_CF}" "."

### TAR MySQL Config Files
make_files_backup "configs" "mysql" "${MySQL_CF}" "."

### TAR Let's Encrypt Config Files
make_files_backup "configs" "letsencrypt" "${LENCRYPT_CF}" "."

# Get all directories
TOTAL_SITES=$(find ${SITES} -maxdepth 1 -type d)
echo " > ${TOTAL_SITES} directory found ..." >>$LOG
echo -e ${CYAN}" > ${TOTAL_SITES} directory found ..."${ENDCOLOR}

# Settings some vars
k=0
COUNT=0
declare -a BACKUPED_LIST
declare -a BK_FL_SIZES

for j in ${TOTAL_SITES}; do

echo -e ${YELLOW}" > Processing [${j}] ..."${ENDCOLOR}

  if [[ "$k" -gt 0 ]]; then

    FOLDER_NAME=$(basename $j)

    if [[ $SITES_BL != *"${FOLDER_NAME}"* ]]; then

      echo -e ${CYAN}" > Making TAR from: $FOLDER_NAME ..."${ENDCOLOR}
      echo " > Making TAR from: $FOLDER_NAME ..." >>$LOG

      #tar cf - /folder-with-big-files -P | pv -s $(du -sb /folder-with-big-files | awk '{print $1}') | gzip > big-files.tar.gz

      #(tar --exclude '.git' --exclude '*.log' -cpf --directory=/root/broobe-utils-scripts/tmp-backup maktub-clientes | pv -s $(du -sb /root/broobe-utils-scripts/tmp-backup/maktub-clientes | awk '{print $1}') | bzip2 > /root/broobe-utils-scripts/tmp-backup/backup-maktub_files.tar.bz2) 2>&1 | dialog --gauge 'Progress' 7 70
      #tar -cpf --directory=/root/broobe-utils-scripts/tmp-backup maktub-clientes | pv -ns $(du -sb /root/broobe-utils-scripts/tmp-backup/maktub-clientes | awk '{print $1}') | bzip2 > /root/broobe-utils-scripts/tmp-backup/backup-maktub_files.tar.bz2
      #tar -cvf --directory=/root/broobe-utils-scripts/ tmp | pv -p -s $(du -sk /root/broobe-utils-scripts/tmp | cut -f 1)k | bzip2 -c > /root/broobe-utils-scripts/tmp/backup-maktub_files.tar.bz2

      TAR_FILE=$($TAR --exclude '.git' --exclude '*.log' -jcpf ${BAKWP}/${NOW}/backup-${FOLDER_NAME}_files_${NOW}.tar.bz2 --directory=${SITES} ${FOLDER_NAME} >>$LOG)

      if ${TAR_FILE}; then

        BACKUPED_LIST[$COUNT]=backup-${FOLDER_NAME}_files_${NOW}.tar.bz2
        BACKUPED_FL=${BACKUPED_LIST[$COUNT]}
        BK_FL_SIZES[$COUNT]=$(ls -lah ${BAKWP}/${NOW}/backup-${FOLDER_NAME}_files_${NOW}.tar.bz2 | awk '{ print $5}')
        BK_FL_SIZE=${BK_FL_SIZES[$COUNT]}

        echo -e ${GREEN}" > Backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE} ..."${ENDCOLOR}
        echo " > Backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE} ..." >>$LOG

        echo " > Trying to create folder ${FOLDER_NAME} in Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh mkdir /${SITES_F}
        ${DPU_F}/dropbox_uploader.sh mkdir /${SITES_F}/${FOLDER_NAME}/

        echo " > Uploading backup to Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/backup-${FOLDER_NAME}_files_${NOW}.tar.bz2 $DROPBOX_FOLDER/${SITES_F}/${FOLDER_NAME}/

        echo " > Trying to delete old backup from Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh remove $DROPBOX_FOLDER/${SITES_F}/${FOLDER_NAME}/backup-${FOLDER_NAME}_files_${ONEWEEKAGO}.tar.bz2

        echo " > Deleting backup from server ..." >>$LOG
        rm -r ${BAKWP}/${NOW}/backup-${FOLDER_NAME}_files_${NOW}.tar.bz2

        echo -e ${GREEN}" > DONE"${ENDCOLOR}

        COUNT=$((COUNT + 1))

        echo -e ${GREEN}" > Backup ${COUNT} of ${TOTAL_SITES} DONE"${ENDCOLOR}
        echo "> Backup ${COUNT} of ${TOTAL_SITES} DONE." >>$LOG

        echo -e ${GREEN}"###################################################"${ENDCOLOR}
        echo "###################################################" >>$LOG

      else
        ERROR=true
        ERROR_TYPE="ERROR: No such directory or file ${BAKWP}/${NOW}/backup-${FOLDER_NAME}_files_${NOW}.tar.bz2"
        echo ${ERROR_TYPE} >>$LOG

      fi

    else
      echo " > Omiting ${FOLDER_NAME} TAR file (blacklisted) ..." >>$LOG

    fi

    echo -e ${CYAN}"###################################################"${ENDCOLOR}
    echo " ###################################################" >>$LOG

  fi

  k=$k+1

done

# File Check
#AMOUNT_FILES=$(ls -d ${BAKWP}/${NOW}/*_files_${NOW}.tar.bz2 | wc -l)
#echo " > Number of backup files found: ${AMOUNT_FILES} ..." >>$LOG

# Deleting old backup files
rm -r ${BAKWP}/${NOW}

# DUPLICITY
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
    duplicity remove-older-than ${DUP_BK_FULL_LIFE} --force ${DUP_ROOT}/$i

  done

  [ $RETVAL -eq 0 ] && echo "*** DUPLICITY SUCCESS ***" >>$LOG
  [ $RETVAL -ne 0 ] && echo "*** DUPLICITY ERROR ***" >>$LOG

fi

# Configure Email
mail_filesbackup_section "${ERROR}" "${ERROR_TYPE}" "${BACKUPED_LIST}" "${BK_FL_SIZES}"

#export STATUS_F STATUS_ICON_F HTMLOPEN HEADER BODY FOOTER HTMLCLOSE
