#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc07
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/mysql_helper.sh
source "${SFOLDER}/libs/mysql_helper.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"

################################################################################

is_wp_project() {

  # $1 = project directory

  local project_dir=$1
  is_wp="false"

  # Check if user is root
  if [[ -f "${project_dir}/wp-config.php" ]]; then
    is_wp="true"

  fi

  echo "${is_wp}"

}

is_laravel_project() {

  # $1 = project directory

  local project_dir=$1
  is_laravel="false"

  # Check if user is root
  if [[ -f "${project_dir}/artisan" ]]; then
    is_laravel="true"

  fi

  echo "${is_laravel}"

}

check_laravel_version() {

  # $1 = project directory

  local project_dir=$1
  laravel_v=$(php "${project_dir}/artisan" --version)

  echo "${laravel_v}"

}

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

  # TODO: bk_type should be "archive, project, server_conf" ?
  #       bk_sup_type ?

  # $1 = Backup Type: configs, logs, data
  # $2 = Backup SubType: php, nginx, mysql
  # $3 = Path folder to Backup
  # $4 = Folder to Backup

  local bk_type=$1
  local bk_sup_type=$2
  local BK_PATH=$3
  local directory_to_backup=$4

  echo -e ${CYAN}"###################################################"${ENDCOLOR} >&2

  if [ -n "${BK_PATH}" ]; then

    OLD_BK_FILE="${bk_sup_type}-${bk_type}-files-${ONEWEEKAGO}.tar.bz2"
    BK_FILE="${bk_sup_type}-${bk_type}-files-${NOW}.tar.bz2"

    # Here we use tar.bz2 with bzip2 compression method
    echo -e ${CYAN}" > Making TAR.BZ2 from: ${BK_PATH} ..."${ENDCOLOR} >&2
    echo " > Making TAR.BZ2 from: ${BK_PATH} ..." >>$LOG

    #echo -e ${CYAN}" > Running: $TAR cjf "${BAKWP}/${NOW}/${BK_FILE}" --directory="${BK_PATH}" "${directory_to_backup}" ..."${ENDCOLOR}
    $TAR cjf "${BAKWP}/${NOW}/${BK_FILE}" --directory="${BK_PATH}" "${directory_to_backup}"

    # Test backup file
    echo -e ${CYAN}" > Testing backup file: ${BK_FILE} ..."${ENDCOLOR}
    echo " > Testing backup file: ${BK_FILE} ..." >>$LOG
    bzip2 -t "${BAKWP}/${NOW}/${BK_FILE}"

    if [ $? -eq 0 ]; then

      echo -e ${GREEN}" > ${BK_FILE} backup created OK!"${ENDCOLOR} >&2
      echo " > ${BK_FILE} backup created OK!" >>$LOG

      BACKUPED_SCF_LIST[$BK_SCF_INDEX]=${BK_FILE}
      BACKUPED_SCF_FL=${BACKUPED_SCF_LIST[$BK_SCF_INDEX]}

      # Calculate backup size
      BK_SCF_SIZE=$(ls -lah "${BAKWP}/${NOW}/${BK_FILE}" | awk '{ print $5}')
      BK_SCF_SIZES[$BK_SCF_ARRAY_INDEX]="${BK_SCF_SIZE}"

      # New folder with $VPSNAME
      output=$($DROPBOX_UPLOADER -q mkdir "/${VPSNAME}" 2>&1)
      
      # New folder with $bk_type
      output=$($DROPBOX_UPLOADER -q mkdir "/${VPSNAME}/${bk_type}" 2>&1)

      # New folder with $bk_sup_type (php, nginx, mysql)
      output=$($DROPBOX_UPLOADER -q mkdir "/${VPSNAME}/${bk_type}/${bk_sup_type}" 2>&1)

      DROPBOX_PATH="/${VPSNAME}/${bk_type}/${bk_sup_type}"

      echo " > Uploading TAR to Dropbox ..." >>$LOG
      echo -e "${CYAN}" >&2
      $DROPBOX_UPLOADER upload "${BAKWP}/${NOW}/${BK_FILE}" "${DROPBOX_FOLDER}/${DROPBOX_PATH}"
      echo -e "${ENDCOLOR}" >&2

      echo " > Trying to delete old backup from Dropbox ..." >>$LOG
      echo -e "${CYAN}"
      $DROPBOX_UPLOADER remove "${DROPBOX_FOLDER}/${DROPBOX_PATH}/${OLD_BK_FILE}"
      echo -e "${ENDCOLOR}"

      echo -e ${B_GREEN}" > DONE"${ENDCOLOR} >&2
      echo " > DONE" >>$LOG

      return 0

    else

      ERROR=true
      ERROR_TYPE="ERROR: No such directory or file ${BAKWP}/${NOW}/${BK_FILE}"

      echo -e ${B_RED}" > ERROR: Can't make the backup!"${ENDCOLOR} >&2
      echo "${ERROR_TYPE}" >>$LOG

      return 1

    fi

  else

    echo -e ${B_RED}" > ERROR: Directory '${BK_PATH}' doesnt exists!"${ENDCOLOR} >&2
    echo " > ERROR: Directory '${BK_PATH}' doesnt exists!" >>$LOG

    return 1

  fi

  echo -e ${CYAN}"###################################################"${ENDCOLOR} >&2
  echo "###################################################" >>$LOG

}

make_mailcow_backup() {

  # $1 = Path folder to Backup

  directory_to_backup=$1

  # VAR $bk_type rewrited
  local bk_type="mailcow"

  echo -e ${CYAN}"###################################################"${ENDCOLOR} >&2

  if [ -n "${MAILCOW}" ]; then

    OLD_BK_FILE="${bk_type}_files-${ONEWEEKAGO}.tar.bz2"
    BK_FILE="${bk_type}_files-${NOW}.tar.bz2"

    echo -e ${CYAN}" > Trying to make a backup of ${MAILCOW} ..."${ENDCOLOR}
    echo " > Trying to make a backup of ${MAILCOW} ..." >>$LOG

    MAILCOW_BACKUP_LOCATION=${MAILCOW_TMP_BK} ${MAILCOW}/helper-scripts/backup_and_restore.sh backup all

    if [ $? -eq 0 ]; then

      # Con un pequeño truco vamos a obtener el nombre de la carpeta que crea mailcow
      cd "${MAILCOW_TMP_BK}"
      cd mailcow-*
      MAILCOW_TMP_FOLDER=$(basename $PWD)
      cd ..

      echo -e ${CYAN}" > Making TAR.BZ2 from: ${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER} ..."${ENDCOLOR} >&2
      echo " > Making TAR.BZ2 from: ${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER} ..." >>$LOG

      #echo -e ${CYAN}" > Runnning: (tar -cf - --directory=${MAILCOW_TMP_BK} ${MAILCOW_TMP_FOLDER} | pv -ns $(du -sb ${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER} | awk '{print $1}') | lbzip2 >${MAILCOW_TMP_BK}/${BK_FILE}) 2>&1 | dialog --gauge ' > Making tar.bz2 from: '${MAILCOW_TMP_FOLDER} 7 70"${ENDCOLOR}
      #echo -e ${CYAN}"###################################################"${ENDCOLOR}

      (tar -cf - --directory="${MAILCOW_TMP_BK}" "${MAILCOW_TMP_FOLDER}" | pv -ns $(du -sb "${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER}" | awk '{print $1}') | lbzip2 >${MAILCOW_TMP_BK}/${BK_FILE}) 2>&1 | dialog --gauge ' > Making tar.bz2 from: '${MAILCOW_TMP_FOLDER} 7 70

      # Test backup file
      echo -e ${CYAN}" > Testing backup file: ${BK_FILE} ..."${ENDCOLOR} >&2
      echo " > Testing backup file: ${BK_FILE} ..." >>$LOG
      lbzip2 -t "${MAILCOW_TMP_BK}/${BK_FILE}"

      if [ $? -eq 0 ]; then

        echo -e ${GREEN}" > ${MAILCOW_TMP_BK}/${BK_FILE} backup created"${ENDCOLOR} >&2
        echo " > ${MAILCOW_TMP_BK}/${BK_FILE} backup created" >>$LOG

        # New folder with $VPSNAME
        output=$($DROPBOX_UPLOADER -q mkdir "/${VPSNAME}" 2>&1)
      
        # New folder with $bk_type
        output=$($DROPBOX_UPLOADER -q mkdir "/${VPSNAME}/${bk_type}" 2>&1)

        DROPBOX_PATH="/${VPSNAME}/${bk_type}"

        echo -e ${CYAN}" > Uploading Backup to Dropbox ..."${ENDCOLOR} >&2
        echo " > Uploading Backup to Dropbox ..." >>$LOG
        $DROPBOX_UPLOADER upload "${MAILCOW_TMP_BK}/${BK_FILE}" "${DROPBOX_FOLDER}/${DROPBOX_PATH}"

        echo -e ${CYAN}" > Trying to delete old backup from Dropbox ..."${ENDCOLOR} >&2
        echo " > Trying to delete old backup from Dropbox ..." >>$LOG
        $DROPBOX_UPLOADER remove "${DROPBOX_FOLDER}/${DROPBOX_PATH}/${BK_FILE}"

        rm -R "${MAILCOW_TMP_BK}"

        echo -e ${GREEN}" > DONE"${ENDCOLOR} >&2
        echo " > DONE" >>$LOG

        return 0

      fi
  
    else

      ERROR=true
      ERROR_TYPE="ERROR: No such directory or file ${MAILCOW_TMP_BK}"

      echo -e ${B_RED}" > ERROR: Can't make the backup!"${ENDCOLOR} >&2
      echo "$ERROR_TYPE" >>$LOG

      return 1

    fi

  else

    echo -e ${B_RED}" > ERROR: Directory '${MAILCOW}' doesnt exists!"${ENDCOLOR} >&2
    echo " > ERROR: Directory '${MAILCOW}' doesnt exists!" >>$LOG

    return 1

  fi

  echo -e ${CYAN}"###################################################"${ENDCOLOR} >&2
  echo "###################################################" >>$LOG

}

make_files_backup() {

  # $1 = Backup Type (site_configs or sites)
  # $2 = Path where directories to backup are stored
  # $3 = The specific folder/file to backup

  local bk_type=$1
  local SITES=$2
  local directory_to_backup=$3

  local OLD_BK_FILE="${directory_to_backup}_${bk_type}-files_${ONEWEEKAGO}.tar.bz2"
  local BK_FILE="${directory_to_backup}_${bk_type}-files_${NOW}.tar.bz2"

  SHOW_BK_FILE_INDEX=$((BK_FILE_INDEX + 1))

  echo " > Making TAR.BZ2 with lbzip2 from: ${directory_to_backup} ..." >>$LOG
  (tar --exclude '.git' --exclude '*.log' -cf - --directory="${SITES}" "${directory_to_backup}" | pv -ns $(du -sb ${SITES}/${directory_to_backup} | awk '{print $1}') | lbzip2 >"${BAKWP}/${NOW}/${BK_FILE}") 2>&1 | dialog --gauge 'Processing '${SHOW_BK_FILE_INDEX}' of '${COUNT_TOTAL_SITES}' directories. Making tar.bz2 from: '${directory_to_backup} 7 70

  # Test backup file
  echo -e ${CYAN}" > Testing backup file: ${BK_FILE} ..."${ENDCOLOR}
  echo " > Testing backup file: ${BK_FILE} ..." >>$LOG
  lbzip2 -t "${BAKWP}/${NOW}/${BK_FILE}"

  if [ $? -eq 0 ]; then

    log_event "success" "${BK_FILE} backup created" "true"

    BACKUPED_LIST[$BK_FILE_INDEX]=${BK_FILE}
    BACKUPED_FL=${BACKUPED_LIST[$BK_FILE_INDEX]}

    # Calculate backup size
    BK_FL_SIZE=$(ls -lah "${BAKWP}/${NOW}/${BK_FILE}" | awk '{ print $5}')

    if [[ ${BK_FL_SIZE} == *"ERROR"* ]]; then

      log_event "error" "${BK_FL_SIZE}" "true"

      BK_FL_SIZE="ERROR"
      ERROR=true

      return 1

    else

      BK_FL_SIZES[$BK_FL_ARRAY_INDEX]="${BK_FL_SIZE}"

      log_event "success" "Backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE}" "true"

      log_event "info" "Creating folders in Dropbox ..." "true"

      # New folder with $VPSNAME
      output=$("${DPU_F}"/dropbox_uploader.sh -q mkdir "/${VPSNAME}" 2>&1)
      
      # New folder with $bk_type
      output=$("${DPU_F}"/dropbox_uploader.sh -q mkdir "/${VPSNAME}/${bk_type}" 2>&1)

      # New folder with $directory_to_backup (project folder)
      output=$("${DPU_F}"/dropbox_uploader.sh -q mkdir "/${VPSNAME}/${bk_type}/${directory_to_backup}" 2>&1)

      DROPBOX_PATH="/${VPSNAME}/${bk_type}/${directory_to_backup}"

      log_event "info" "Uploading ${directory_to_backup} to Dropbox" "true"
      $DROPBOX_UPLOADER upload "${BAKWP}/${NOW}/${BK_FILE}" "${DROPBOX_FOLDER}/${DROPBOX_PATH}/"
      log_event "success" "${directory_to_backup} uploaded to Dropbox" "true"

      # Delete old backup from Dropbox
      $DROPBOX_UPLOADER remove "${DROPBOX_FOLDER}/${DROPBOX_PATH}/${OLD_BK_FILE}"
      log_event "info" "Old backup from Dropbox with date ${ONEWEEKAGO} deleted" "true"

      # Delete temp backup
      rm -r "${BAKWP}/${NOW}/${BK_FILE}"
      log_event "info" "Temp backup deleted from server" "true"

      log_event "success" "Backup uploaded" "true"

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
    for i in $(echo "${DUP_FOLDERS}" | sed "s/,/ /g"); do
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

  local bk_type=$1 #configs,sites,databases
  local DATABASE=$2

  local directory_to_backup="${BAKWP}/${NOW}/"
  local db_file="${DATABASE}_${bk_type}_${NOW}.sql"

  local OLD_BK_FILE="${DATABASE}_${bk_type}_${ONEWEEKAGO}.tar.bz2"
  local BK_FILE="${DATABASE}_${bk_type}_${NOW}.tar.bz2"

  echo -e ${CYAN}" > Creating new database backup of ${DATABASE} ..."${ENDCOLOR}
  echo " > Creating new database backup of ${DATABASE} ..." >>$LOG

  # Create dump file
  $MYSQLDUMP --max-allowed-packet=1073741824 -u "${MUSER}" -h "${MHOST}" -p"${MPASS}" "${DATABASE}" >"${directory_to_backup}${db_file}"

  if [ "$?" -eq 0 ]; then

    echo -e ${GREEN}" > mysqldump OK!"${ENDCOLOR}
    echo " > mysqldump OK!" >>$LOG

    cd "${BAKWP}/${NOW}"

    echo -e ${CYAN}" > Making a tar.bz2 file of [${db_file}] ..."${ENDCOLOR}
    echo " > Making a tar.bz2 file of [${db_file}] ..." >>$LOG

    tar -cf - --directory="${directory_to_backup}" "${db_file}" | pv -s $(du -sb ${BAKWP}/${NOW}/${db_file} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}

    # Test backup file
    echo -e ${CYAN}" > Testing backup file: ${db_file} ..."${ENDCOLOR}
    echo " > Testing backup file: ${db_file} ..." >>$LOG
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
      output=$($DROPBOX_UPLOADER -q mkdir "/${VPSNAME}" 2>&1)
      
      # New folder with $bk_type
      output=$($DROPBOX_UPLOADER -q mkdir "/${VPSNAME}/${bk_type}" 2>&1)

      # New folder with $DATABASE (project DB)
      output=$($DROPBOX_UPLOADER -q mkdir "/${VPSNAME}/${bk_type}/${DATABASE}" 2>&1)

      DROPBOX_PATH="/${VPSNAME}/${bk_type}/${DATABASE}"

      # Upload to Dropbox
      echo -e ${CYAN}" > Uploading new database backup [${BK_FILE}] ..."${ENDCOLOR} >&2
      $DROPBOX_UPLOADER upload "${BK_FILE}" "$DROPBOX_FOLDER/${DROPBOX_PATH}"

      # Delete old backups
      echo -e ${CYAN}" > Deleting old database backup [${OLD_BK_FILE}] ..."${ENDCOLOR}
      $DROPBOX_UPLOADER -q remove "$DROPBOX_FOLDER/${DROPBOX_PATH}/${OLD_BK_FILE}"

      echo -e ${CYAN}" > Deleting backup from server ..."${ENDCOLOR} >&2
      echo " > Deleting backup from server ..." >>$LOG
      rm "${BAKWP}/${NOW}/${db_file}"
      rm "${BAKWP}/${NOW}/${BK_FILE}"

    fi

  else

    echo " > mysqldump ERROR: $? ..." >>$LOG
    echo -e ${B_RED}" > mysqldump ERROR: $? ..."${ENDCOLOR} >&2
    ERROR=true
    ERROR_TYPE="mysqldump error with ${DATABASE}"

  fi

}

make_project_backup() {

    #TODO: DOES NOT WORK, NEED REFACTOR ASAP!!!

    # $1 = Backup Type
    # $2 = Backup SubType
    # $3 = Path folder to Backup
    # $4 = Folder to Backup

    local bk_type=$1     #configs,sites,databases
    local bk_sup_type=$2 #config_name,site_domain,database_name
    local SITES=$3
    local directory_to_backup=$4

    local directory_to_backup="${BAKWP}/${NOW}/"

    local OLD_BK_FILE="${directory_to_backup}_${bk_type}-files_${ONEWEEKAGO}.tar.bz2"
    local BK_FILE="${directory_to_backup}_${bk_type}-files_${NOW}.tar.bz2"

    log_event "info" "Making TAR.BZ2 from: ${directory_to_backup} ..." "true"

    (tar --exclude '.git' --exclude '*.log' -cf - --directory="${SITES}" "${directory_to_backup}" | pv -ns $(du -sb ${SITES}/${directory_to_backup} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_FILE}) 2>&1 | dialog --gauge 'Processing '${BK_FILE_INDEX}' of '${COUNT_TOTAL_SITES}' directories. Making tar.bz2 from: '${directory_to_backup} 7 70

    # Test backup file
    log_event "info" "Testing backup file: ${BK_FILE}" "true"
    lbzip2 -t "${BAKWP}/${NOW}/${BK_FILE}"

    if [ $? -eq 0 ]; then

        BACKUPED_LIST[$BK_FILE_INDEX]=${BK_FILE}
        BACKUPED_FL=${BACKUPED_LIST[$BK_FILE_INDEX]}

        # Calculate backup size
        BK_FL_SIZES[$BK_FL_ARRAY_INDEX]=$(ls -lah "${BAKWP}/${NOW}/${BK_FILE}" | awk '{ print $5}')
        BK_FL_SIZE=${BK_FL_SIZES[$BK_FL_ARRAY_INDEX]}

        log_event "success" "File backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE}" "true"

        # Checking whether WordPress is installed or not
        if ! $(wp core is-installed); then

            # TODO: Check Composer and Yii Projects

            # Yii Project
            log_event "info" "Trying to get database name from project ..." "true"

            DB_NAME=$(grep 'dbname=' "${SITES}/${directory_to_backup}/common/config/main-local.php" | tail -1 | sed 's/$dbname=//g;s/,//g' | cut -d "'" -f4 | cut -d "=" -f3)

            local db_file="${DB_NAME}.sql"

            # Create dump file
            mysql_database_export "${DB_NAME}" "${directory_to_backup}${db_file}"

        else

            DB_NAME=$(wp --allow-root --path="${SITES}/${directory_to_backup}" eval 'echo DB_NAME;')

            local db_file="${DB_NAME}.sql"

            wpcli_export_db "${SITES}/${directory_to_backup}" "${directory_to_backup}${db_file}"

        fi

        log_event "info" "Working with DB_NAME=${DB_NAME}" "true"

        bk_type="database"
        local OLD_BK_DB_FILE="${DB_NAME}_${bk_type}_${ONEWEEKAGO}.tar.bz2"
        local BK_DB_FILE="${DB_NAME}_${bk_type}_${NOW}.tar.bz2"

        echo -e ${CYAN}" > Making TAR.BZ2 for database: ${db_file} ..."${ENDCOLOR}
        echo " > Making TAR.BZ2 for database: ${db_file} ..." >>$LOG

        echo " > tar -cf - --directory=${directory_to_backup} ${db_file} | pv -s $(du -sb ${BAKWP}/${NOW}/${db_file} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_DB_FILE}" >>$LOG
        tar -cf - --directory="${directory_to_backup}" "${db_file}" | pv -s $(du -sb ${BAKWP}/${NOW}/${db_file} | awk '{print $1}') | lbzip2 >${BAKWP}/${NOW}/${BK_DB_FILE}

        # Test backup file
        echo -e ${CYAN}" > Testing backup file: ${BK_DB_FILE} ..."${ENDCOLOR}
        echo " > Testing backup file: ${BK_DB_FILE} ..." >>$LOG
        lbzip2 -t "${BAKWP}/${NOW}/${BK_DB_FILE}"

        echo -e ${CYAN}" > Trying to create folder in Dropbox ..."${ENDCOLOR} >&2
        echo " > Trying to create folders in Dropbox ..." >>$LOG

        # New folder with $VPSNAME
        output=$($DROPBOX_UPLOADER -q mkdir "/${VPSNAME}" 2>&1)
        
        # New folder with $bk_type
        output=$($DROPBOX_UPLOADER -q mkdir "/${VPSNAME}/${bk_type}" 2>&1)

        # New folder with $directory_to_backup
        output=$($DROPBOX_UPLOADER -q mkdir "/${VPSNAME}/${bk_type}/${directory_to_backup}" 2>&1)

        echo -e ${CYAN}" > Uploading file backup ${BK_FILE} to Dropbox ..."${ENDCOLOR} >&2
        echo " > Uploading file backup ${BK_FILE} to Dropbox ..." >>$LOG
        $DROPBOX_UPLOADER upload "${BAKWP}/${NOW}/${BK_FILE}" "${DROPBOX_FOLDER}/${VPSNAME}/${bk_type}/${directory_to_backup}/${NOW}"

        echo -e ${CYAN}" > Uploading database backup ${BK_DB_FILE} to Dropbox ..."${ENDCOLOR} >&2
        echo " > Uploading database backup ${BK_DB_FILE} to Dropbox ..." >>$LOG
        $DROPBOX_UPLOADER upload "${BAKWP}/${NOW}/${BK_DB_FILE}" "${DROPBOX_FOLDER}/${VPSNAME}/${bk_type}/${directory_to_backup}/${NOW}"

        echo -e ${CYAN}" > Trying to delete old backup from Dropbox with date ${ONEWEEKAGO} ..."${ENDCOLOR} >&2
        echo " > Trying to delete old backup from Dropbox with date ${ONEWEEKAGO} ..." >>$LOG
        $DROPBOX_UPLOADER delete "${DROPBOX_FOLDER}/${VPSNAME}/${bk_type}/${directory_to_backup}/${ONEWEEKAGO}"

        echo " > Deleting backup from server ..." >>$LOG
        rm -r "${BAKWP}/${NOW}/${BK_FILE}"

        echo -e ${B_GREEN}" > DONE"${ENDCOLOR} >&2

    else
        ERROR=true
        ERROR_TYPE=" > ERROR: Making backup ${BAKWP}/${NOW}/${BK_FILE}"
        echo "${ERROR_TYPE}" >>$LOG

    fi

}