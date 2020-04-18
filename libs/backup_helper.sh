#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-beta12
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/mysql_helper.sh"
source "${SFOLDER}/libs/mail_notification_helper.sh"

################################################################################
#
# IMPORTANT: Maybe a new backup directory structure:
#
# VPS_NAME -> SERVER_CONFIGS (PHP, MySQL, Custom Status Log)
#          -> PROYECTS -> ACTIVE
#                      -> INACTIVE
#                      -> ACTIVE/INACTIVE  -> DATABASE
#                                          -> FILES
#                                          -> CONFIGS (nginx, letsencrypt)
#          -> DATABASES
#          -> SITES_NO_DB
#

make_server_files_backup() {

  # TODO: need to implement error_type

  # TODO: BK_TYPE should be "archive, project, server_conf" ?
  #       BK_SUB_TYPE ?

  # $1 = Backup Type: configs, logs, data
  # $2 = Backup SubType: php, nginx, mysql
  # $3 = Path folder to Backup
  # $4 = Folder to Backup

  BK_TYPE=$1
  BK_SUB_TYPE=$2
  BK_PATH=$3
  BK_FOLDER=$4

  echo -e ${CYAN}"###################################################"${ENDCOLOR}

  if [ -n "${BK_PATH}" ]; then

    OLD_BK_FILE="${BK_SUB_TYPE}-${BK_TYPE}-files-${ONEWEEKAGO}.tar.bz2"
    BK_FILE="${BK_SUB_TYPE}-${BK_TYPE}-files-${NOW}.tar.bz2"

    # Here we use tar.bz2 with bzip2 compression method
    echo -e ${CYAN}" > Making TAR.BZ2 from: ${BK_PATH} ..."${ENDCOLOR}
    echo " > Making TAR.BZ2 from: ${BK_PATH} ..." >>$LOG

    #echo -e ${CYAN}" > Running: $TAR cjf "${BAKWP}/${NOW}/${BK_FILE}" --directory="${BK_PATH}" "${BK_FOLDER}" ..."${ENDCOLOR}
    $TAR cjf "${BAKWP}/${NOW}/${BK_FILE}" --directory="${BK_PATH}" "${BK_FOLDER}"

    # Test backup file
    echo -e ${CYAN}" > Testing backup file: ${BK_FILE} ..."${ENDCOLOR}
    echo " > Testing backup file: ${BK_FILE} ..." >>$LOG
    bzip2 -t "${BAKWP}/${NOW}/${BK_FILE}"

    if [ $? -eq 0 ]; then

      echo -e ${GREEN}" > ${BK_FILE} backup created OK!"${ENDCOLOR}
      echo " > ${BK_FILE} backup created OK!" >>$LOG

      BACKUPED_SCF_LIST[$BK_SCF_INDEX]=${BK_FILE}
      BACKUPED_SCF_FL=${BACKUPED_SCF_LIST[$BK_SCF_INDEX]}

      # Calculate backup size
      BK_SCF_SIZE=$(ls -lah ${BAKWP}/${NOW}/${BK_FILE} | awk '{ print $5}')
      BK_SCF_SIZES[$BK_SCF_ARRAY_INDEX]="${BK_SCF_SIZE}"

      # New folder with $VPSNAME
      output=$("${DPU_F}"/dropbox_uploader.sh -q mkdir "/${VPSNAME}" 2>&1)
      
      # New folder with $BK_TYPE
      output=$("${DPU_F}"/dropbox_uploader.sh -q mkdir "/${VPSNAME}/${BK_TYPE}" 2>&1)

      # New folder with $BK_SUB_TYPE (php, nginx, mysql)
      output=$("${DPU_F}"/dropbox_uploader.sh -q mkdir "/${VPSNAME}/${BK_TYPE}/${BK_SUB_TYPE}" 2>&1)

      DROPBOX_PATH="/${VPSNAME}/${BK_TYPE}/${BK_SUB_TYPE}"

      echo " > Uploading TAR to Dropbox ..." >>$LOG
      echo -e "${CYAN}"
      ${DPU_F}/dropbox_uploader.sh upload "${BAKWP}/${NOW}/${BK_FILE}" "${DROPBOX_FOLDER}/${DROPBOX_PATH}"
      echo -e "${ENDCOLOR}"

      echo " > Trying to delete old backup from Dropbox ..." >>$LOG
      echo -e "${CYAN}"
      ${DPU_F}/dropbox_uploader.sh remove "${DROPBOX_FOLDER}/${DROPBOX_PATH}/${OLD_BK_FILE}"
      echo -e "${ENDCOLOR}"

      echo -e ${B_GREEN}" > DONE"${ENDCOLOR}
      echo " > DONE" >>$LOG

      return 0

    else

      ERROR=true
      ERROR_TYPE="ERROR: No such directory or file ${BAKWP}/${NOW}/${BK_FILE}"

      echo -e ${B_RED}" > ERROR: Can't make the backup!"${ENDCOLOR}
      echo "${ERROR_TYPE}" >>$LOG

      return 1

    fi

  else

    echo -e ${B_RED}" > ERROR: Directory '${BK_PATH}' doesnt exists!"${ENDCOLOR}
    echo " > ERROR: Directory '${BK_PATH}' doesnt exists!" >>$LOG

    return 1

  fi

  echo -e ${CYAN}"###################################################"${ENDCOLOR}
  echo "###################################################" >>$LOG

}

make_mailcow_backup() {

  # $1 = Path folder to Backup

  BK_FOLDER=$1

  # VAR $BK_TYPE rewrited
  local BK_TYPE="mailcow"

  echo -e ${CYAN}"###################################################"${ENDCOLOR}

  if [ -n "${MAILCOW}" ]; then

    OLD_BK_FILE="${BK_TYPE}_files-${ONEWEEKAGO}.tar.bz2"
    BK_FILE="${BK_TYPE}_files-${NOW}.tar.bz2"

    echo -e ${CYAN}" > Trying to make a backup of ${MAILCOW} ..."${ENDCOLOR}
    echo " > Trying to make a backup of ${MAILCOW} ..." >>$LOG

    MAILCOW_BACKUP_LOCATION=${MAILCOW_TMP_BK} ${MAILCOW}/helper-scripts/backup_and_restore.sh backup all

    if [ $? -eq 0 ]; then

      # Con un pequeño truco vamos a obtener el nombre de la carpeta que crea mailcow
      cd ${MAILCOW_TMP_BK}
      cd mailcow-*
      MAILCOW_TMP_FOLDER=$(basename $PWD)
      cd ..

      echo -e ${CYAN}" > Making TAR.BZ2 from: ${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER} ..."${ENDCOLOR}
      echo " > Making TAR.BZ2 from: ${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER} ..." >>$LOG

      #echo -e ${CYAN}" > Runnning: (tar -cf - --directory=${MAILCOW_TMP_BK} ${MAILCOW_TMP_FOLDER} | pv -ns $(du -sb ${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER} | awk '{print $1}') | lbzip2 >${MAILCOW_TMP_BK}/${BK_FILE}) 2>&1 | dialog --gauge ' > Making tar.bz2 from: '${MAILCOW_TMP_FOLDER} 7 70"${ENDCOLOR}
      #echo -e ${CYAN}"###################################################"${ENDCOLOR}

      (tar -cf - --directory="${MAILCOW_TMP_BK}" "${MAILCOW_TMP_FOLDER}" | pv -ns $(du -sb "${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER}" | awk '{print $1}') | lbzip2 >${MAILCOW_TMP_BK}/${BK_FILE}) 2>&1 | dialog --gauge ' > Making tar.bz2 from: '${MAILCOW_TMP_FOLDER} 7 70

      # Test backup file
      echo -e ${CYAN}" > Testing backup file: ${BK_FILE} ..."${ENDCOLOR}
      echo " > Testing backup file: ${BK_FILE} ..." >>$LOG
      lbzip2 -t "${MAILCOW_TMP_BK}/${BK_FILE}"

      if [ $? -eq 0 ]; then

        echo -e ${GREEN}" > ${MAILCOW_TMP_BK}/${BK_FILE} backup created"${ENDCOLOR}
        echo " > ${MAILCOW_TMP_BK}/${BK_FILE} backup created" >>$LOG

        # New folder with $VPSNAME
        ${DPU_F}/dropbox_uploader.sh -q mkdir "/${VPSNAME}"
      
        # New folder with $BK_TYPE
        ${DPU_F}/dropbox_uploader.sh -q mkdir "/${VPSNAME}/${BK_TYPE}"

        DROPBOX_PATH="/${VPSNAME}/${BK_TYPE}"

        echo -e ${CYAN}" > Uploading Backup to Dropbox ..."${ENDCOLOR}
        echo " > Uploading Backup to Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh upload "${MAILCOW_TMP_BK}/${BK_FILE}" "${DROPBOX_FOLDER}/${DROPBOX_PATH}"

        echo -e ${CYAN}" > Trying to delete old backup from Dropbox ..."${ENDCOLOR}
        echo " > Trying to delete old backup from Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh remove "${DROPBOX_FOLDER}/${DROPBOX_PATH}/${BK_FILE}"

        rm -R "${MAILCOW_TMP_BK}"

        echo -e ${GREEN}" > DONE"${ENDCOLOR}
        echo " > DONE" >>$LOG

        return 0

      fi
  
    else

      ERROR=true
      ERROR_TYPE="ERROR: No such directory or file ${MAILCOW_TMP_BK}"

      echo -e ${B_RED}" > ERROR: Can't make the backup!"${ENDCOLOR}
      echo "$ERROR_TYPE" >>$LOG

      return 1

    fi

  else

    echo -e ${B_RED}" > ERROR: Directory '${MAILCOW}' doesnt exists!"${ENDCOLOR}
    echo " > ERROR: Directory '${MAILCOW}' doesnt exists!" >>$LOG

    return 1

  fi

  echo -e ${CYAN}"###################################################"${ENDCOLOR}
  echo "###################################################" >>$LOG

}

make_files_backup() {

  # $1 = Backup Type (site_configs or sites)
  # $2 = Path where directories to backup are stored
  # $3 = The specific folder/file to backup

  local BK_TYPE=$1
  local SITES=$2
  local F_NAME=$3

  local OLD_BK_FILE="${F_NAME}_${BK_TYPE}-files_${ONEWEEKAGO}.tar.bz2"
  local BK_FILE="${F_NAME}_${BK_TYPE}-files_${NOW}.tar.bz2"

  SHOW_BK_FILE_INDEX=$((BK_FILE_INDEX + 1))

  echo " > Making TAR.BZ2 with lbzip2 from: ${F_NAME} ..." >>$LOG
  (tar --exclude '.git' --exclude '*.log' -cf - --directory="${SITES}" "${F_NAME}" | pv -ns $(du -sb ${SITES}/${F_NAME} | awk '{print $1}') | lbzip2 >"${BAKWP}/${NOW}/${BK_FILE}") 2>&1 | dialog --gauge 'Processing '${SHOW_BK_FILE_INDEX}' of '${COUNT_TOTAL_SITES}' directories. Making tar.bz2 from: '${F_NAME} 7 70

  # Test backup file
  echo -e ${CYAN}" > Testing backup file: ${BK_FILE} ..."${ENDCOLOR}
  echo " > Testing backup file: ${BK_FILE} ..." >>$LOG
  lbzip2 -t "${BAKWP}/${NOW}/${BK_FILE}"

  if [ $? -eq 0 ]; then

    echo -e ${B_GREEN}" > ${BK_FILE} backup created OK!"${ENDCOLOR}
    echo " > ${BK_FILE} backup created OK!" >>$LOG

    BACKUPED_LIST[$BK_FILE_INDEX]=${BK_FILE}
    BACKUPED_FL=${BACKUPED_LIST[$BK_FILE_INDEX]}

    # Calculate backup size
    BK_FL_SIZE=$(ls -lah "${BAKWP}/${NOW}/${BK_FILE}" | awk '{ print $5}')

    if [[ ${BK_FL_SIZE} == *"ERROR"* ]]; then

      echo -e ${B_RED}" > ${BK_FL_SIZE}"${ENDCOLOR}
      echo " > ${BK_FL_SIZE}" >>$LOG

      BK_FL_SIZE="ERROR"
      ERROR=true

      return 1

    else

      BK_FL_SIZES[$BK_FL_ARRAY_INDEX]="${BK_FL_SIZE}"

      echo -e ${GREEN}" > Backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE} ..."${ENDCOLOR}
      echo " > Backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE} ..." >>$LOG

      echo -e ${CYAN}" > Creating folders in Dropbox ..."${ENDCOLOR}
      echo " > Creating folders in Dropbox ..." >>$LOG

      # New folder with $VPSNAME
      ${DPU_F}/dropbox_uploader.sh -q mkdir "/${VPSNAME}"
      
      # New folder with $BK_TYPE
      ${DPU_F}/dropbox_uploader.sh -q mkdir "/${VPSNAME}/${BK_TYPE}"

      # New folder with $F_NAME (project folder)
      ${DPU_F}/dropbox_uploader.sh -q mkdir "/${VPSNAME}/${BK_TYPE}/${F_NAME}"

      DROPBOX_PATH="/${VPSNAME}/${BK_TYPE}/${F_NAME}"

      echo -e ${CYAN}" > Uploading ${F_NAME} to Dropbox ..."${ENDCOLOR}
      echo " > Uploading ${F_NAME} to Dropbox ..." >>$LOG
      ${DPU_F}/dropbox_uploader.sh upload "${BAKWP}/${NOW}/${BK_FILE}" "${DROPBOX_FOLDER}/${DROPBOX_PATH}/"

      echo -e ${CYAN}" > Trying to delete old backup from Dropbox with date ${ONEWEEKAGO} ..."${ENDCOLOR}
      echo " > Trying to delete old backup from Dropbox with date ${ONEWEEKAGO} ..." >>$LOG
      ${DPU_F}/dropbox_uploader.sh remove "${DROPBOX_FOLDER}/${DROPBOX_PATH}/${OLD_BK_FILE}"

      echo " > Deleting backup from server ..." >>$LOG
      rm -r "${BAKWP}/${NOW}/${BK_FILE}"

      echo -e ${B_GREEN}" > DONE"${ENDCOLOR}

      return 0

    fi

  else
    ERROR=true
    ERROR_TYPE="ERROR: Making backup ${BAKWP}/${NOW}/${BK_FILE}"

    echo -e ${B_RED}" > ERROR! Please see the log file."${ENDCOLOR}
    echo ${ERROR_TYPE} >>$LOG

    return 1

  fi

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

  local BK_FOLDER="${BAKWP}/${NOW}/"
  local DB_FILE="${DATABASE}_${BK_TYPE}_${NOW}.sql"

  local OLD_BK_FILE="${DATABASE}_${BK_TYPE}_${ONEWEEKAGO}.tar.bz2"
  local BK_FILE="${DATABASE}_${BK_TYPE}_${NOW}.tar.bz2"

  echo -e ${CYAN}" > Creating new database backup of ${DATABASE} ..."${ENDCOLOR}
  echo " > Creating new database backup of ${DATABASE} ..." >>$LOG

  # Create dump file
  $MYSQLDUMP --max-allowed-packet=1073741824 -u ${MUSER} -h ${MHOST} -p${MPASS} ${DATABASE} >"${BK_FOLDER}${DB_FILE}"

  if [ "$?" -eq 0 ]; then

    echo -e ${GREEN}" > mysqldump OK!"${ENDCOLOR}
    echo " > mysqldump OK!" >>$LOG

    cd "${BAKWP}/${NOW}"

    echo -e ${CYAN}" > Making a tar.bz2 file of [${DB_FILE}] ..."${ENDCOLOR}
    echo " > Making a tar.bz2 file of [${DB_FILE}] ..." >>$LOG

    tar -cf - --directory="${BK_FOLDER}" "${DB_FILE}" | pv -s $(du -sb ${BAKWP}/${NOW}/${DB_FILE} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}

    # Test backup file
    echo -e ${CYAN}" > Testing backup file: ${DB_FILE} ..."${ENDCOLOR}
    echo " > Testing backup file: ${DB_FILE} ..." >>$LOG
    lbzip2 -t "${BAKWP}/${NOW}/${BK_FILE}"

    if [ $? -eq 0 ]; then

      echo -e ${GREEN}" > ${BK_FILE} OK!"${ENDCOLOR}
      echo " > ${BK_FILE} OK!" >>$LOG

      BACKUPED_DB_LIST[$BK_DB_INDEX]=${BK_FILE}

      # Calculate backup size
      BK_DB_SIZES[$BK_DB_INDEX]=$(ls -lah ${BK_FILE} | awk '{ print $5}')
      BK_DB_SIZE=${BK_DB_SIZES[$BK_DB_INDEX]}

      echo -e ${GREEN}" > Backup for ${DATABASE} created, final size: ${BK_DB_SIZE} ..."${ENDCOLOR}
      echo " > Backup for ${DATABASE} created, final size: ${BK_DB_SIZE} ..." >>$LOG

      echo -e ${CYAN}" > Creating folders in Dropbox ..."${ENDCOLOR}
      echo " > Creating folders in Dropbox ..." >>$LOG

      # New folder with $VPSNAME
      ${DPU_F}/dropbox_uploader.sh -q mkdir "/${VPSNAME}"
      
      # New folder with $BK_TYPE
      ${DPU_F}/dropbox_uploader.sh -q mkdir "/${VPSNAME}/${BK_TYPE}"

      # New folder with $DATABASE (project DB)
      ${DPU_F}/dropbox_uploader.sh -q mkdir "/${VPSNAME}/${BK_TYPE}/${DATABASE}"

      DROPBOX_PATH="/${VPSNAME}/${BK_TYPE}/${DATABASE}"

      # Upload to Dropbox
      echo -e ${CYAN}" > Uploading new database backup [${BK_FILE}] ..."${ENDCOLOR}
      ${DPU_F}/dropbox_uploader.sh upload "${BK_FILE}" "$DROPBOX_FOLDER/${DROPBOX_PATH}"

      # Delete old backups
      echo -e ${CYAN}" > Deleting old database backup [${OLD_BK_FILE}] ..."${ENDCOLOR}
      ${DPU_F}/dropbox_uploader.sh -q remove "$DROPBOX_FOLDER/${DROPBOX_PATH}/${OLD_BK_FILE}"

      echo -e ${CYAN}" > Deleting backup from server ..."${ENDCOLOR}
      echo " > Deleting backup from server ..." >>$LOG
      rm "${BAKWP}/${NOW}/${DB_FILE}"
      rm "${BAKWP}/${NOW}/${BK_FILE}"

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
    local F_NAME=$4

    local BK_FOLDER="${BAKWP}/${NOW}/"

    local OLD_BK_FILE="${F_NAME}_${BK_TYPE}-files_${ONEWEEKAGO}.tar.bz2"
    local BK_FILE="${F_NAME}_${BK_TYPE}-files_${NOW}.tar.bz2"

    echo -e ${CYAN}" > Making TAR.BZ2 from: ${F_NAME} ..."${ENDCOLOR}
    echo " > Making TAR.BZ2 from: ${F_NAME} ..." >>$LOG

    (tar --exclude '.git' --exclude '*.log' -cf - --directory=${SITES} ${F_NAME} | pv -ns $(du -sb ${SITES}/${F_NAME} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}) 2>&1 | dialog --gauge 'Processing '${BK_FILE_INDEX}' of '${COUNT_TOTAL_SITES}' directories. Making tar.bz2 from: '${F_NAME} 7 70

    # Test backup file
    echo -e ${CYAN}" > Testing backup file: ${BK_FILE} ..."${ENDCOLOR}
    echo " > Testing backup file: ${BK_FILE} ..." >>$LOG
    lbzip2 -t "${BAKWP}/${NOW}/${BK_FILE}"

    if [ $? -eq 0 ]; then

        echo -e ${GREEN}" > ${BK_FILE} OK!"${ENDCOLOR}
        echo " > ${BK_FILE} OK!" >>$LOG

        BACKUPED_LIST[$BK_FILE_INDEX]=${BK_FILE}
        BACKUPED_FL=${BACKUPED_LIST[$BK_FILE_INDEX]}

        echo -e ${B_ORANGE}" > BACKUPED_LIST: ${BACKUPED_LIST}"${ENDCOLOR}
        echo -e ${B_ORANGE}" > BACKUPED_FL: ${BACKUPED_FL}"${ENDCOLOR}

        # Calculate backup size
        BK_FL_SIZES[$BK_FL_ARRAY_INDEX]=$(ls -lah ${BAKWP}/${NOW}/${BK_FILE} | awk '{ print $5}')
        BK_FL_SIZE=${BK_FL_SIZES[$BK_FL_ARRAY_INDEX]}

        echo -e ${GREEN}" > File backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE} ..."${ENDCOLOR}
        echo " > File backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE} ..." >>$LOG

        # Checking whether WordPress is installed or not
        if ! $(wp core is-installed); then

            # Check Composer and Yii Projects

            # Yii Project
            echo -e ${CYAN}" > Trying to get database name from project ..."${ENDCOLOR}
            echo " > Trying to get database name from project ..." >>$LOG
            DB_NAME=$(grep 'dbname=' ${SITES}/${F_NAME}/common/config/main-local.php | tail -1 | sed 's/$dbname=//g;s/,//g' | cut -d "'" -f4 | cut -d "=" -f3)

            local DB_FILE="${DB_NAME}.sql"

            # Create dump file
            echo -e ${CYAN}" > Creating a dump file of: ${DB_NAME}"${ENDCOLOR}
            echo " > Creating a dump file of: ${DB_NAME}" >>$LOG

            # TODO: Need to control output of mysqldump 
            # TODO: Use mysql helper

            $MYSQLDUMP --max-allowed-packet=1073741824 -u ${MUSER} -h ${MHOST} -p${MPASS} ${DB_NAME} >${BK_FOLDER}${DB_FILE}            

        else

            DB_NAME=$(wp --allow-root --path=${SITES}/${F_NAME} eval 'echo DB_NAME;')

            local DB_FILE="${DB_NAME}.sql"

            wpcli_export_db "${SITES}/${F_NAME}" "${BK_FOLDER}${DB_FILE}"

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
        echo -e ${CYAN}" > Testing backup file: ${BK_DB_FILE} ..."${ENDCOLOR}
        echo " > Testing backup file: ${BK_DB_FILE} ..." >>$LOG
        lbzip2 -t "${BAKWP}/${NOW}/${BK_DB_FILE}"

        # TODO: control de lbzip2 ok

        # TODO: backup nginx

        echo -e ${CYAN}" > Trying to create folder in Dropbox ..."${ENDCOLOR}
        echo " > Trying to create folders in Dropbox ..." >>$LOG

        # New folder with $VPSNAME
        ${DPU_F}/dropbox_uploader.sh -q mkdir "/${VPSNAME}"
        ${DPU_F}/dropbox_uploader.sh -q mkdir "/${VPSNAME}/${BK_TYPE}"

        # New folder structure with date
        ${DPU_F}/dropbox_uploader.sh -q mkdir "/${VPSNAME}/${BK_TYPE}/${F_NAME}"
        #${DPU_F}/dropbox_uploader.sh -q mkdir "/${VPSNAME}/${BK_TYPE}/${F_NAME}/${NOW}"

        echo -e ${CYAN}" > Uploading file backup ${BK_FILE} to Dropbox ..."${ENDCOLOR}
        echo " > Uploading file backup ${BK_FILE} to Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh upload "${BAKWP}/${NOW}/${BK_FILE}" "${DROPBOX_FOLDER}/${VPSNAME}/${BK_TYPE}/${F_NAME}/${NOW}"

        echo -e ${CYAN}" > Uploading database backup ${BK_DB_FILE} to Dropbox ..."${ENDCOLOR}
        echo " > Uploading database backup ${BK_DB_FILE} to Dropbox ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh upload "${BAKWP}/${NOW}/${BK_DB_FILE}" "${DROPBOX_FOLDER}/${VPSNAME}/${BK_TYPE}/${F_NAME}/${NOW}"

        echo -e ${CYAN}" > Trying to delete old backup from Dropbox with date ${ONEWEEKAGO} ..."${ENDCOLOR}
        echo " > Trying to delete old backup from Dropbox with date ${ONEWEEKAGO} ..." >>$LOG
        ${DPU_F}/dropbox_uploader.sh delete "${DROPBOX_FOLDER}/${VPSNAME}/${BK_TYPE}/${F_NAME}/${ONEWEEKAGO}"
        #${DPU_F}/dropbox_uploader.sh remove ${DROPBOX_FOLDER}/${BK_TYPE}/${F_NAME}/${OLD_BK_DB_FILE}

        echo " > Deleting backup from server ..." >>$LOG
        rm -r "${BAKWP}/${NOW}/${BK_FILE}"

        echo -e ${B_GREEN}" > DONE"${ENDCOLOR}

    else
        ERROR=true
        ERROR_TYPE="ERROR: Making backup ${BAKWP}/${NOW}/${BK_FILE}"
        echo ${ERROR_TYPE} >>$LOG

    fi

}