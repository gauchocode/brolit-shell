#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-beta7
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

make_mailcow_backup() {

  # TODO: la funcion deberia retornar el path completo al archivo backupeado. Ej: /root/tmp/bk.tar.bz2

  # $1 = Path folder to Backup

  BK_FOLDER=$1

  # VAR $BK_TYPE rewrited
  BK_TYPE="mailcow"

  echo -e ${CYAN}"###################################################"${ENDCOLOR}

  if [ -n "${MAILCOW}" ]; then

    OLD_BK_FILE="${BK_TYPE}_files-${ONEWEEKAGO}.tar.bz2"
    BK_FILE="${BK_TYPE}_files-${NOW}.tar.bz2"

    echo -e ${CYAN}" > Trying to make a backup of ${BK_DIR} ..."${ENDCOLOR}
    echo " > Trying to make a backup of ${BK_DIR} ..." >>$LOG

    MAILCOW_BACKUP_LOCATION=${MAILCOW_TMP_BK} ${MAILCOW}/helper-scripts/backup_and_restore.sh backup all

    if [ $? -eq 0 ]; then

      # Con un pequeño truco vamos a obtener el nombre de la carpeta que crea mailcow
      cd ${MAILCOW_TMP_BK}
      cd mailcow-*
      MAILCOW_TMP_FOLDER=$(basename $PWD)
      cd ..

      echo -e ${CYAN}" > Making TAR.BZ2 from: ${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER} ..."${ENDCOLOR}
      echo " > Making TAR.BZ2 from: ${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER} ..." >>$LOG

      echo -e ${CYAN}" > Runnning: (tar -cf - --directory=${MAILCOW_TMP_BK} ${MAILCOW_TMP_FOLDER} | pv -ns $(du -sb ${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER} | awk '{print $1}') | lbzip2 >${MAILCOW_TMP_BK}/${BK_FILE}) 2>&1 | dialog --gauge ' > Making tar.bz2 from: '${MAILCOW_TMP_FOLDER} 7 70"${ENDCOLOR}
      echo -e ${CYAN}"###################################################"${ENDCOLOR}
      echo " > Runnning: (tar -cf - --directory=${MAILCOW_TMP_BK} ${MAILCOW_TMP_FOLDER} | pv -ns $(du -sb ${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER} | awk '{print $1}') | lbzip2 >${MAILCOW_TMP_BK}/${BK_FILE}) 2>&1 | dialog --gauge ' > Making tar.bz2 from: '${MAILCOW_TMP_FOLDER} 7 70">>$LOG

      (tar -cf - --directory=${MAILCOW_TMP_BK} ${MAILCOW_TMP_FOLDER} | pv -ns $(du -sb ${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER} | awk '{print $1}') | lbzip2 >${MAILCOW_TMP_BK}/${BK_FILE}) 2>&1 | dialog --gauge ' > Making tar.bz2 from: '${MAILCOW_TMP_FOLDER} 7 70

      # Test backup file
      lbzip2 -t "${MAILCOW_TMP_BK}/${BK_FILE}"

      if [ $? -eq 0 ]; then

        echo -e ${GREEN}" > ${MAILCOW_TMP_BK}/${BK_FILE} backup created"${ENDCOLOR}
        echo " > ${MAILCOW_TMP_BK}/${BK_FILE} backup created" >>$LOG

        echo -e ${CYAN}" > Uploading Backup to Dropbox ..."${ENDCOLOR}
        echo " > Uploading Backup to Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh upload ${MAILCOW_TMP_BK}/${BK_FILE} ${DROPBOX_FOLDER}

        dropbox_delete_backup "${BK_TYPE}" "" "${OLD_BK_FILE}"
        rm -R ${MAILCOW_TMP_BK}

        echo -e ${GREEN}" > DONE"${ENDCOLOR}
        echo " > DONE" >>$LOG
      fi
  
    else

      ERROR=true
      ERROR_TYPE="ERROR: No such directory or file ${BK_FILE}"

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

  echo " > Making TAR.BZ2 from: ${FOLDER_NAME} ..." >>$LOG
  (tar --exclude '.git' --exclude '*.log' -cf - --directory=${SITES} ${FOLDER_NAME} | pv -ns $(du -sb ${SITES}/${FOLDER_NAME} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}) 2>&1 | dialog --gauge 'Processing '${FILE_BK_INDEX}' of '${COUNT_TOTAL_SITES}' directories. Making tar.bz2 from: '${FOLDER_NAME} 7 70

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

make_database_backup() {

  # $1 = Backup Type
  # $2 = Database

  local BK_TYPE=$1 #configs,sites,databases
  local DATABASE=$2

  local BK_FOLDER=${BAKWP}/${NOW}/
  local DB_FILE="${DATABASE}_${BK_TYPE}_${NOW}.sql"

  local OLD_BK_FILE="${DATABASE}_${BK_TYPE}_${ONEWEEKAGO}.tar.bz2"
  local BK_FILE="${DATABASE}_${BK_TYPE}_${NOW}.tar.bz2"

  echo -e ${CYAN}" > Creating new database backup of ${DATABASE} ..."${ENDCOLOR}
  echo " > Creating new database backup of ${DATABASE} ..." >>$LOG

  # Create dump file
  $MYSQLDUMP --max-allowed-packet=1073741824 -u ${MUSER} -h ${MHOST} -p${MPASS} ${DATABASE} >${BK_FOLDER}${DB_FILE}

  if [ "$?" -eq 0 ]; then

    echo -e ${GREEN}" > mysqldump OK!"${ENDCOLOR}
    echo " > mysqldump OK!" >>$LOG

    cd ${BAKWP}/${NOW}

    echo -e ${CYAN}" > Making a tar.bz2 file of [${DB_FILE}] ..."${ENDCOLOR}
    echo " > Making a tar.bz2 file of [${DB_FILE}] ..." >>$LOG

    #echo -e ${MAGENTA}" > tar -cf - --directory=${BK_FOLDER} ${DB_FILE} | pv -s $(du -sb ${BAKWP}/${NOW}/${DB_FILE} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}"${ENDCOLOR}
    tar -cf - --directory=${BK_FOLDER} ${DB_FILE} | pv -s $(du -sb ${BAKWP}/${NOW}/${DB_FILE} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}
    #(tar -cf - ${BAKWP}/${NOW}/${DB_FILE} | pv -ns $(du -sb ${BAKWP}/${NOW}/${DB_FILE} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}) 2>&1 | dialog --gauge 'Making backup of '${DB_FILE} 7 70
    #TAR_FILE=$($TAR -cpf ${BAKWP}/${NOW}/${BK_FILE} --directory=${BK_FOLDER} ${DB_FILE} --use-compress-program=lbzip2)

    # Test backup file
    echo -e ${CYAN}" > Testing backup file: ${DB_FILE} ..."${ENDCOLOR}
    echo " > Testing backup file: ${DB_FILE} ..." >>$LOG
    lbzip2 -t ${BAKWP}/${NOW}/${BK_FILE}

    if [ $? -eq 0 ]; then

      echo -e ${GREEN}" > ${BK_FILE} OK!"${ENDCOLOR}
      echo " > ${BK_FILE} OK!" >>$LOG

      BACKUPED_DB_LIST[$DB_BK_INDEX]=${BK_FILE}

      # Calculate backup size
      BK_DB_SIZES[$DB_BK_INDEX]=$(ls -lah ${BK_FILE} | awk '{ print $5}')
      BK_DB_SIZE=${BK_DB_SIZES[$DB_BK_INDEX]}

      echo -e ${GREEN}" > Backup for ${DATABASE} created, final size: ${BK_DB_SIZE} ..."${ENDCOLOR}
      echo " > Backup for ${DATABASE} created, final size: ${BK_DB_SIZE} ..." >>$LOG

      #echo " > Creating Dropbox Databases Folder ..." >> $LOG
      ${DPU_F}/dropbox_uploader.sh -q mkdir ${DBS_F}
      ${DPU_F}/dropbox_uploader.sh -q mkdir ${DBS_F}/${DATABASE}

      # New folder structure with date
      #${DPU_F}/dropbox_uploader.sh -q mkdir /${SITES_F}/${FOLDER_NAME}
      #${DPU_F}/dropbox_uploader.sh -q mkdir /${SITES_F}/${FOLDER_NAME}/${NOW}

      # Upload to Dropbox
      echo " > Uploading new database backup [${BK_FILE}] ..."
      #${DPU_F}/dropbox_uploader.sh upload ${BK_FILE} /${SITES_F}/${FOLDER_NAME}/${NOW}
      ${DPU_F}/dropbox_uploader.sh upload ${BK_FILE} $DROPBOX_FOLDER/${DBS_F}/${DATABASE}

      # Delete old backups
      echo " > Trying to delete old database backup [${OLD_BK_FILE}] ..."
      #${DPU_F}/dropbox_uploader.sh delete ${DROPBOX_FOLDER}/${SITES_F}/${FOLDER_NAME}/${ONEWEEKAGO}

      ${DPU_F}/dropbox_uploader.sh -q remove ${DBS_F}/${DATABASE}/${OLD_BK_FILE}

      echo -e ${CYAN}" > Deleting backup from server ..."${ENDCOLOR}
      echo " > Deleting backup from server ..." >>$LOG
      rm ${BAKWP}/${NOW}/${DB_FILE}
      rm ${BAKWP}/${NOW}/${BK_FILE}

    fi

  else

    echo " > mysqldump ERROR: $? ..." >>$LOG
    echo -e ${RED}" > mysqldump ERROR: $? ..."${ENDCOLOR}
    ERROR=true
    ERROR_TYPE="mysqldump error with ${DATABASE}"

  fi

}

make_project_backup() {

    # $1 = Backup Type
    # $2 = Backup SubType
    # $3 = Path folder to Backup
    # $4 = Folder to Backup

    local BK_TYPE=$1     #configs,sites,databases
    local BK_SUB_TYPE=$2 #config_name,site_domain,database_name
    local SITES=$3
    local FOLDER_NAME=$4

    local BK_FOLDER=${BAKWP}/${NOW}/

    local OLD_BK_FILE="${FOLDER_NAME}_${BK_TYPE}-files_${ONEWEEKAGO}.tar.bz2"
    local BK_FILE="${FOLDER_NAME}_${BK_TYPE}-files_${NOW}.tar.bz2"

    echo -e ${CYAN}" > Making TAR.BZ2 from: ${FOLDER_NAME} ..."${ENDCOLOR}
    echo " > Making TAR.BZ2 from: ${FOLDER_NAME} ..." >>$LOG

    (tar --exclude '.git' --exclude '*.log' -cf - --directory=${SITES} ${FOLDER_NAME} | pv -ns $(du -sb ${SITES}/${FOLDER_NAME} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}) 2>&1 | dialog --gauge 'Processing '${FILE_BK_INDEX}' of '${COUNT_TOTAL_SITES}' directories. Making tar.bz2 from: '${FOLDER_NAME} 7 70

    # Test backup file
    lbzip2 -t ${BAKWP}/${NOW}/${BK_FILE}

    if [ $? -eq 0 ]; then

        echo -e ${GREEN}" > ${BK_FILE} OK!"${ENDCOLOR}
        echo " > ${BK_FILE} OK!" >>$LOG

        BACKUPED_LIST[$FILE_BK_INDEX]=${BK_FILE}
        BACKUPED_FL=${BACKUPED_LIST[$FILE_BK_INDEX]}

        # Calculate backup size
        BK_FL_SIZES[$FILE_BK_INDEX]=$(ls -lah ${BAKWP}/${NOW}/${BK_FILE} | awk '{ print $5}')
        BK_FL_SIZE=${BK_FL_SIZES[$FILE_BK_INDEX]}

        echo -e ${GREEN}" > File backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE} ..."${ENDCOLOR}
        echo " > File backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE} ..." >>$LOG

        # Checking whether WordPress is installed or not
        if ! $(wp core is-installed); then

            # Check Composer and Yii Projects

            # Yii Project
            echo -e ${CYAN}" > Trying to get database name from project ..."${ENDCOLOR}
            echo " > Trying to get database name from project ..." >>$LOG
            DB_NAME=$(grep 'dbname=' ${SITES}/${FOLDER_NAME}/common/config/main-local.php | tail -1 | sed 's/$dbname=//g;s/,//g' | cut -d "'" -f4 | cut -d "=" -f3)

            local DB_FILE="${DB_NAME}.sql"

            # Create dump file
            echo -e ${CYAN}" > Creating a dump file of: ${DB_NAME}"${ENDCOLOR}
            echo " > Creating a dump file of: ${DB_NAME}" >>$LOG
            $MYSQLDUMP --max-allowed-packet=1073741824 -u ${MUSER} -h ${MHOST} -p${MPASS} ${DB_NAME} >${BK_FOLDER}${DB_FILE}

            # TODO: control dump OK (deberia usar helper mysql)

        else

            DB_NAME=$(wp --allow-root --path=${SITES}/${FOLDER_NAME} eval 'echo DB_NAME;')

            local DB_FILE="${DB_NAME}.sql"

            wpcli_export_db "${SITES}/${FOLDER_NAME}" "${BK_FOLDER}${DB_FILE}"

        fi

        echo -e ${PURPLE}" > DB_NAME=${DB_NAME}"${ENDCOLOR}
        echo " > DB_NAME=${DB_NAME}" >>$LOG

        BK_TYPE="database"
        local OLD_BK_DB_FILE="${DB_NAME}_${BK_TYPE}_${ONEWEEKAGO}.tar.bz2"
        local BK_DB_FILE="${DB_NAME}_${BK_TYPE}_${NOW}.tar.bz2"

        echo -e ${CYAN}" > Making TAR.BZ2 for database: ${DB_FILE} ..."${ENDCOLOR}
        echo " > Making TAR.BZ2 for database: ${DB_FILE} ..." >>$LOG

        echo " > tar -cf - --directory=${BK_FOLDER} ${DB_FILE} | pv -s $(du -sb ${BAKWP}/${NOW}/${DB_FILE} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_DB_FILE}" >>$LOG
        tar -cf - --directory=${BK_FOLDER} ${DB_FILE} | pv -s $(du -sb ${BAKWP}/${NOW}/${DB_FILE} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_DB_FILE}

        # Test backup file
        lbzip2 -t ${BAKWP}/${NOW}/${BK_DB_FILE}

        # TODO: control de lbzip2 ok

        # TODO: backup nginx

        echo -e ${CYAN}" > Trying to create folder in Dropbox ..."${ENDCOLOR}
        echo " > Trying to create folders in Dropbox ..." >>$LOG

        ${DPU_F}/dropbox_uploader.sh -q mkdir /${SITES_F}

        # New folder structure with date
        ${DPU_F}/dropbox_uploader.sh -q mkdir /${SITES_F}/${FOLDER_NAME}
        ${DPU_F}/dropbox_uploader.sh -q mkdir /${SITES_F}/${FOLDER_NAME}/${NOW}

        echo -e ${CYAN}" > Uploading file backup ${BK_FILE} to Dropbox ..."${ENDCOLOR}
        echo " > Uploading file backup ${BK_FILE} to Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/${BK_FILE} $DROPBOX_FOLDER/${SITES_F}/${FOLDER_NAME}/${NOW}

        echo -e ${CYAN}" > Uploading database backup ${BK_DB_FILE} to Dropbox ..."${ENDCOLOR}
        echo " > Uploading database backup ${BK_DB_FILE} to Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh upload ${BAKWP}/${NOW}/${BK_DB_FILE} ${DROPBOX_FOLDER}/${SITES_F}/${FOLDER_NAME}/${NOW}

        echo -e ${CYAN}" > Trying to delete old backup from Dropbox with date ${ONEWEEKAGO} ..."${ENDCOLOR}
        echo " > Trying to delete old backup from Dropbox with date ${ONEWEEKAGO} ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh delete ${DROPBOX_FOLDER}/${SITES_F}/${FOLDER_NAME}/${ONEWEEKAGO}
        #${DPU_F}/dropbox_uploader.sh remove ${DROPBOX_FOLDER}/${SITES_F}/${FOLDER_NAME}/${OLD_BK_DB_FILE}

        echo " > Deleting backup from server ..." >>$LOG
        rm -r ${BAKWP}/${NOW}/${BK_FILE}

        echo -e ${GREEN}" > DONE"${ENDCOLOR}

    else
        ERROR=true
        ERROR_TYPE="ERROR: Making backup ${BAKWP}/${NOW}/${BK_FILE}"
        echo ${ERROR_TYPE} >>$LOG

    fi

}