#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.9
#############################################################################

function is_laravel_project() {

  # $1 = ${project_dir} project directory

  local project_dir=$1

  local is_laravel="false"

  # Check if user is root
  if [[ -f "${project_dir}/artisan" ]]; then
    is_laravel="true"

  fi

  # Return
  echo "${is_laravel}"

}

function check_laravel_version() {

  # $1 = ${project_dir} project directory

  local project_dir=$1
  laravel_v=$(php "${project_dir}/artisan" --version)

  # Return
  echo "${laravel_v}"

}

function menu_backup_options() {

  local backup_options 
  local chosen_backup_type

  backup_options=("01)" "BACKUP DATABASES" "02)" "BACKUP FILES" "03)" "BACKUP ALL" "04)" "BACKUP PROJECT")
  chosen_backup_type=$(whiptail --title "SELECT BACKUP TYPE" --menu " " 20 78 10 "${backup_options[@]}" 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_backup_type} == *"01"* ]]; then

      # DATABASE_BACKUP

      log_section "Databases Backup"

      # Preparing Mail Notifications Template
      HTMLOPEN="$(mail_html_start)"
      BODY_SRV="$(mail_server_status_section "${SERVER_IP}")"

      # shellcheck source=${SFOLDER}/mysql_backup.sh
      source "${SFOLDER}/utils/mysql_backup.sh"

      DB_MAIL="${BAKWP}/db-bk-${NOW}.mail"
      DB_MAIL_VAR=$(<"${DB_MAIL}")

      log_event "info" "Sending Email to ${MAILA} ..." "false"

      EMAIL_SUBJECT="${STATUS_ICON_D} ${VPSNAME} - Database Backup - [${NOWDISPLAY}]"
      EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${DB_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

    fi
    if [[ ${chosen_backup_type} == *"02"* ]]; then

      # FILES_BACKUP

      log_section "Files Backup"

      # Preparing Mail Notifications Template
      HTMLOPEN=$(mail_html_start)
      BODY_SRV=$(mail_server_status_section "${SERVER_IP}")

      # shellcheck source=${SFOLDER}/files_backup.sh
      source "${SFOLDER}/utils/files_backup.sh"

      CONFIG_MAIL="${BAKWP}/config-bk-${NOW}.mail"
      CONFIG_MAIL_VAR=$(<"${CONFIG_MAIL}")

      FILE_MAIL="${BAKWP}/file-bk-${NOW}.mail"
      FILE_MAIL_VAR=$(<"${FILE_MAIL}")

      log_event "info" "Sending Email to ${MAILA} ..." "false"

      EMAIL_SUBJECT="${STATUS_ICON_F} ${VPSNAME} - Files Backup - [${NOWDISPLAY}]"
      EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${CERT_MAIL_VAR} ${CONFIG_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

    fi
    if [[ ${chosen_backup_type} == *"03"* ]]; then

      # BACKUP_ALL

      log_section "Backup All"

      # Preparing Mail Notifications Template
      HTMLOPEN="$(mail_html_start)"
      BODY_SRV="$(mail_server_status_section "${SERVER_IP}")"

      # Running scripts
      
      # shellcheck source=${SFOLDER}/utils/mysql_backup.sh
      "${SFOLDER}/utils/mysql_backup.sh"
      # shellcheck source=${SFOLDER}/utils/files_backup.sh
      "${SFOLDER}/utils/files_backup.sh"

      # Mail section for Database Backup
      DB_MAIL="${BAKWP}/db-bk-${NOW}.mail"
      DB_MAIL_VAR=$(<"${DB_MAIL}")

      # Mail section for Server Config Backup
      CONFIG_MAIL="${BAKWP}/config-bk-${NOW}.mail"
      CONFIG_MAIL_VAR=$(<"${CONFIG_MAIL}")

      # Mail section for Files Backup
      FILE_MAIL="${BAKWP}/file-bk-${NOW}.mail"
      FILE_MAIL_VAR=$(<"${FILE_MAIL}")

      MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

      # Checking result status for mail subject
      EMAIL_STATUS="$(mail_subject_status "${STATUS_BACKUP_DBS}" "${STATUS_BACKUP_FILES}" "${STATUS_SERVER}" "${OUTDATED_PACKAGES}")"

      log_event "info" "Sending Email to ${MAILA} ..." "false"

      EMAIL_SUBJECT="${EMAIL_STATUS} on ${VPSNAME} Running Complete Backup - [${NOWDISPLAY}]"
      EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${BODY_PKG} ${DB_MAIL_VAR} ${CONFIG_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

      remove_mail_notifications_files

    fi

    if [[ ${chosen_backup_type} == *"04"* ]]; then

      # PROJECT_BACKUP

      # Running project_backup script
      "${SFOLDER}/utils/project_backup.sh"

    fi

  fi

  menu_main_options

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

function make_server_files_backup() {

  # TODO: need to implement error_type

  # TODO: bk_type should be "archive, project, server_conf" ?
  #       bk_sup_type ?

  # $1 = Backup Type: configs, logs, data
  # $2 = Backup SubType: php, nginx, mysql
  # $3 = Path folder to Backup
  # $4 = Folder to Backup

  local bk_type=$1
  local bk_sup_type=$2
  local bk_path=$3
  local directory_to_backup=$4

  local bk_file 
  local old_bk_file

  #log_break

  if [[ -n ${bk_path} ]]; then

    old_bk_file="${bk_sup_type}-${bk_type}-files-${ONEWEEKAGO}.tar.bz2"
    bk_file="${bk_sup_type}-${bk_type}-files-${NOW}.tar.bz2"

    # Here we use tar.bz2 with bzip2 compression method
    log_event "info" "Making backup of ${bk_path}"
    log_event "debug" "Running: ${TAR} cjf ${BAKWP}/${NOW}/${bk_file} --directory=${bk_path} ${directory_to_backup}"
    
    (${TAR} cjf "${BAKWP}/${NOW}/${bk_file}" --directory="${bk_path}" "${directory_to_backup}")

    display --indent 6 --text "- Making ${bk_sup_type} backup" --result "DONE" --color GREEN
    display --indent 6 --text "- Compressing directory ${bk_path}" --result "DONE" --color GREEN

    # Test backup file
    log_event "info" "Testing backup file: ${bk_file} ..."
    bzip2 -t "${BAKWP}/${NOW}/${bk_file}"
    bzip2_result="$?"
    if [[ ${bzip2_result} -eq 0 ]]; then

      log_event "success" "Backup ${bk_file} created"
      
      #BACKUPED_SCF_LIST[$BK_SCF_INDEX]="$(string_remove_special_chars "${bk_file}")"
      BACKUPED_SCF_LIST[$BK_SCF_INDEX]="${bk_file}"
      #BACKUPED_SCF_LIST+=("${bk_file}")

      # Calculate backup size
      BK_SCF_SIZE="$(find . -name "${bk_file}" -exec ls -l --human-readable --block-size=K {} \; | awk '{ print $5 }')"
      BK_SCF_SIZES[$BK_SCF_INDEX]="${BK_SCF_SIZE}"

      display --indent 6 --text "- Testing compressed backup file" --result "DONE" --color GREEN

      # New folder with $VPSNAME
      output="$("${DROPBOX_UPLOADER}" -q mkdir "/${VPSNAME}" 2>&1)"
      
      # New folder with $bk_type
      output="$("${DROPBOX_UPLOADER}" -q mkdir "/${VPSNAME}/${bk_type}" 2>&1)"

      # New folder with $bk_sup_type (php, nginx, mysql)
      output="$("${DROPBOX_UPLOADER}" -q mkdir "/${VPSNAME}/${bk_type}/${bk_sup_type}" 2>&1)"

      DROPBOX_PATH="/${VPSNAME}/${bk_type}/${bk_sup_type}"

      # Uploading backup files
      log_event "info" "Uploading backup to Dropbox ..."
      display --indent 6 --text "- Uploading backup file to Dropbox"

      output="$("${DROPBOX_UPLOADER}" upload "${BAKWP}/${NOW}/${bk_file}" "${DROPBOX_FOLDER}/${DROPBOX_PATH}" 2>&1)"

      clear_last_line
      display --indent 6 --text "- Uploading backup file to Dropbox" --result "DONE" --color GREEN

      # Deleting old backup files
      log_event "info" "Trying to delete old backup from Dropbox ..."

      output="$("${DROPBOX_UPLOADER}" remove "${DROPBOX_FOLDER}/${DROPBOX_PATH}/${old_bk_file}" 2>&1)"
      dropbox_remove_result="$?"
      if [[ ${dropbox_remove_result} -eq 0 ]]; then

        log_event "success" "Server files backup finished"
        display --indent 6 --text "- Deleting old backup from Dropbox" --result "DONE" --color GREEN

      else

        display --indent 6 --text "- Deleting old backup from Dropbox" --result "WARNING" --color YELLOW
        display --indent 8 --text "Maybe backup file doesn't exists" --tcolor YELLOW

        log_event "warning" "Can't remove ${DROPBOX_FOLDER}/${DROPBOX_PATH}/${old_bk_file} from dropbox. Maybe backup file doesn't exists." "false"
        log_event "warning" "Last command executed: ${DROPBOX_UPLOADER} remove ${DROPBOX_FOLDER}/${DROPBOX_PATH}/${old_bk_file}"

      fi

    else

      bzip2_error="No such directory or file ${BAKWP}/${NOW}/${bk_file}"

      log_event "critical" "Can't make the backup. No such directory or file ${BAKWP}/${NOW}/${bk_file}"

      display --indent 6 --text "- Testing backup file" --result "FAIL" --color RED
      display --indent 8 --text "Result: ${bzip2_error}"

      return 1

    fi

  else

    log_event "error" "Directory ${bk_path} doesn't exists!"

    display --indent 6 --text "- Creating backup file" --result "FAIL" --color RED
    display --indent 8 --text "Result: Directory '${bk_path}' doesn't exists" --tcolor RED

    return 1

  fi

  log_break "true"
  
}

function make_mailcow_backup() {

  # $1 = Path folder to Backup

  local directory_to_backup=$1

  # VAR $bk_type rewrited
  local bk_type="mailcow"
  local mailcow_backup_result

  log_break

  log_subsection "Mailcow Backup"

  if [[ -n "${MAILCOW}" ]]; then

    old_bk_file="${bk_type}_files-${ONEWEEKAGO}.tar.bz2"
    bk_file="${bk_type}_files-${NOW}.tar.bz2"

    log_event "info" "Trying to make a backup of ${MAILCOW} ..."
    display --indent 6 --text "- Making ${MAILCOW} backup" --result "DONE" --color GREEN

    "${MAILCOW}/helper-scripts/backup_and_restore.sh" backup all
    mailcow_backup_result="$?"
    if [[ "${mailcow_backup_result}" -eq 0 ]]; then

      # Con un pequeño truco vamos a obtener el nombre de la carpeta que crea mailcow
      cd "${MAILCOW_TMP_BK}"
      cd mailcow-*
      MAILCOW_TMP_FOLDER="$(basename $PWD)"
      cd ..

      log_event "info" "Making TAR.BZ2 from: ${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER} ..."

      ${TAR} -cf - --directory="${MAILCOW_TMP_BK}" "${MAILCOW_TMP_FOLDER}" | pv --width 70 -ns "$(du -sb "${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER}" | awk '{print $1}')" | lbzip2 >"${MAILCOW_TMP_BK}/${bk_file}"

      # Clear pipe output
      clear_last_line

      # Test backup file
      log_event "info" "Testing backup file: ${bk_file} ..."
      lbzip2 -t "${MAILCOW_TMP_BK}/${bk_file}"
      lbzip2_result="$?"
      if [[ ${lbzip2_result} -eq 0 ]]; then

        log_event "success" "${MAILCOW_TMP_BK}/${bk_file} backup created"

        # New folder with $VPSNAME
        output="$(${DROPBOX_UPLOADER} -q mkdir "/${VPSNAME}" 2>&1)"
      
        # New folder with $bk_type
        output="$(${DROPBOX_UPLOADER} -q mkdir "/${VPSNAME}/${bk_type}" 2>&1)"

        DROPBOX_PATH="/${VPSNAME}/${bk_type}"

        log_event "info" "Uploading Backup to Dropbox ..."
        display --indent 6 --text "- Uploading backup file to Dropbox"

        output=$(${DROPBOX_UPLOADER} upload "${MAILCOW_TMP_BK}/${bk_file}" "${DROPBOX_FOLDER}/${DROPBOX_PATH}" 2>&1)
        clear_last_line
        display --indent 6 --text "- Uploading backup file to Dropbox" --result "DONE" --color GREEN

        log_event "info" "Deleting old backup from Dropbox ..."
        output=$(${DROPBOX_UPLOADER} remove "${DROPBOX_FOLDER}/${DROPBOX_PATH}/${bk_file}" 2>&1)

        rm -R "${MAILCOW_TMP_BK}"

        log_event "info" "Mailcow backup finished"

      fi
  
    else

      ERROR=true
      ERROR_TYPE="ERROR: No such directory or file ${MAILCOW_TMP_BK}"

      log_event "error" "Can't make the backup!"

      return 1

    fi

  else

    log_event "error" "Directory '${MAILCOW}' doesnt exists!"

    return 1

  fi

  log_break

}

function make_all_server_config_backup() {

  log_subsection "Backup Server Config"

  # SERVER CONFIG FILES GLOBALS
  declare -i BK_SCF_INDEX=0
  declare -n BACKUPED_SCF_LIST
  declare -n BK_SCF_SIZES

  # TAR Webserver Config Files
  if [[ ! -d ${WSERVER} ]]; then
    log_event "warning" "WSERVER var not defined! Skipping webserver config files backup ..."

  else
    make_server_files_backup "configs" "nginx" "${WSERVER}" "."

  fi

  # TAR PHP Config Files
  if [[ ! -d ${PHP_CF} ]]; then
    log_event "warning" "PHP_CF var not defined! Skipping PHP config files backup ..."

  else
    BK_SCF_INDEX=$((BK_SCF_INDEX + 1))
    make_server_files_backup "configs" "php" "${PHP_CF}" "."

  fi

  # TAR MySQL Config Files
  if [[ ! -d ${MySQL_CF} ]]; then
    log_event "warning" "MySQL_CF var not defined! Skipping MySQL config files backup ..."

  else
    BK_SCF_INDEX=$((BK_SCF_INDEX + 1))
    make_server_files_backup "configs" "mysql" "${MySQL_CF}" "."

  fi

  # TAR Let's Encrypt Config Files
  if [[ ! -d ${LENCRYPT_CF} ]]; then
    log_event "warning" "LENCRYPT_CF var not defined! Skipping Letsencrypt config files backup ..."

  else
    BK_SCF_INDEX=$((BK_SCF_INDEX + 1))
    make_server_files_backup "configs" "letsencrypt" "${LENCRYPT_CF}" "."

  fi

  # Configure Files Backup Section for Email Notification

  echo "BACKUPED_SCF_LIST[@]:" "${BACKUPED_SCF_LIST[@]}"
  echo "BK_SCF_SIZES[@]:" "${BK_SCF_SIZES[@]}"

  mail_configbackup_section "${BACKUPED_SCF_LIST[@]}" "${BK_SCF_SIZES[@]}" "${ERROR}" "${ERROR_TYPE}"

}

function make_all_files_backup() {

  log_subsection "Backup Sites Files"

  # Get all directories
  TOTAL_SITES=$(get_all_directories "${SITES}")

  ## Get length of $TOTAL_SITES
  COUNT_TOTAL_SITES="$(find "${SITES}" -maxdepth 1 -type d -printf '.' | wc -c)"
  COUNT_TOTAL_SITES="$((COUNT_TOTAL_SITES - 1))"

  log_event "info" "Found ${COUNT_TOTAL_SITES} directories"
  display --indent 6 --text "- Directories found" --result "${COUNT_TOTAL_SITES}" --color WHITE

  # FILES BACKUP GLOBALS
  declare -i BK_FILE_INDEX=0
  declare -i BK_FL_ARRAY_INDEX=0
  declare BACKUPED_LIST
  declare BK_FL_SIZES

  declare directory_name=""

  k=0

  for j in ${TOTAL_SITES}; do

    log_event "info" "Processing [${j}] ..."

    if [[ "$k" -gt 0 ]]; then

      directory_name=$(basename "${j}")

      if [[ ${SITES_BL} != *"${directory_name}"* ]]; then

        make_files_backup "site" "${SITES}" "${directory_name}"
        BK_FL_ARRAY_INDEX="$((BK_FL_ARRAY_INDEX + 1))"

        log_break "true"

      else
        log_event "info" "Omitting ${directory_name} (blacklisted) ..."

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

}

function make_files_backup() {

  # $1 = Backup Type (site_configs or sites)
  # $2 = Path where directories to backup are stored
  # $3 = The specific folder/file to backup

  local bk_type=$1
  local bk_path=$2
  local directory_to_backup=$3

  local old_bk_file="${directory_to_backup}_${bk_type}-files_${ONEWEEKAGO}.tar.bz2"
  local bk_file="${directory_to_backup}_${bk_type}-files_${NOW}.tar.bz2"

  log_event "info" "Making backup file from: ${directory_to_backup} ..."
  display --indent 6 --text "- Making ${directory_to_backup} backup" --result "DONE" --color GREEN

  (${TAR} --exclude '.git' --exclude '*.log' -cf - --directory="${bk_path}" "${directory_to_backup}" | pv --width 70 --size "$(du -sb "${bk_path}/${directory_to_backup}" | awk '{print $1}')" | lbzip2 >"${BAKWP}/${NOW}/${bk_file}")2>&1
  
  # Clear pipe output
  clear_last_line

  # Test backup file
  log_event "info" "Testing backup file: ${bk_file} ..."
  display --indent 6 --text "- Testing backup file" --result "DONE" --color GREEN
  lbzip2 -t "${BAKWP}/${NOW}/${bk_file}"
  lbzip2_result="$?"
  if [[ "${lbzip2_result}" -eq 0 ]]; then

    log_event "success" "${bk_file} backup created"
    
    BACKUPED_LIST[$BK_FILE_INDEX]=${bk_file}
    BACKUPED_FL=${BACKUPED_LIST[${BK_FILE_INDEX}]}

    # Calculate backup size
    #BK_FL_SIZE="$(ls -la --human-readable "${BAKWP}/${NOW}/${bk_file}" | awk '{ print $5}')"
    BK_FL_SIZE="$(find . -name "${bk_file}" -exec ls -l --human-readable --block-size=M {} \; |  awk '{ print $5 }')"
    BK_FL_SIZES[$BK_FL_ARRAY_INDEX]=${BK_FL_SIZE}

    log_event "success" "Backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE}"
    display --indent 6 --text "- Backup creation" --result "DONE" --color GREEN
    display --indent 8 --text "Final backup file size: ${BK_FL_SIZE}"

    log_event "info" "Creating folders in Dropbox ..."

    # New folder with $VPSNAME
    output="$("${DROPBOX_UPLOADER}" -q mkdir "/${VPSNAME}" 2>&1)"
    
    # New folder with $bk_type
    output="$("${DROPBOX_UPLOADER}" -q mkdir "/${VPSNAME}/${bk_type}" 2>&1)"

    # New folder with $directory_to_backup (project folder)
    output="$("${DROPBOX_UPLOADER}" -q mkdir "/${VPSNAME}/${bk_type}/${directory_to_backup}" 2>&1)"

    DROPBOX_PATH="/${VPSNAME}/${bk_type}/${directory_to_backup}"

    log_event "info" "Uploading ${directory_to_backup} to Dropbox"
    display --indent 6 --text "- Uploading backup to dropbox"
    output="$("${DROPBOX_UPLOADER}" upload "${BAKWP}/${NOW}/${bk_file}" "${DROPBOX_FOLDER}/${DROPBOX_PATH}/" 2>&1)"
    log_event "success" "${directory_to_backup} uploaded to Dropbox"
    clear_last_line
    display --indent 6 --text "- Uploading backup to dropbox" --result "DONE" --color GREEN

    # Delete old backup from Dropbox
    output="$("${DROPBOX_UPLOADER}" remove "${DROPBOX_FOLDER}/${DROPBOX_PATH}/${old_bk_file}" 2>&1)"
    log_event "info" "Old backup from Dropbox with date ${ONEWEEKAGO} deleted"
    display --indent 6 --text "- Deleting old dropbox backup" --result "DONE" --color GREEN

    # Delete temp backup
    rm "${BAKWP}/${NOW}/${bk_file}"

    log_event "info" "Temp backup deleted from server"
    display --indent 6 --text "- Deleting temp files" --result "DONE" --color GREEN

    log_event "success" "Backup uploaded"

  else
    ERROR=true
    ERROR_TYPE="ERROR: Making backup ${BAKWP}/${NOW}/${bk_file}"

    log_event "error" "Something went wrong making backup file: ${BAKWP}/${NOW}/${bk_file}"
    display --indent 6 --text "- Backup creation" --result "FAIL" --color RED
    display --indent 8 --text "Something went wrong making backup file: ${bk_file}" --tcolor RED

    return 1

  fi

}

function duplicity_backup() {

  if [[ ${DUP_BK} = true ]]; then

    # Check if DUPLICITY is installed
    DUPLICITY="$(which duplicity)"
    if [[ ! -x ${DUPLICITY} ]]; then
      apt-get install duplicity
    fi

    # Loop in to Directories
    for i in $(echo "${DUP_FOLDERS}" | sed "s/,/ /g"); do
      duplicity --full-if-older-than "${DUP_BK_FULL_FREQ}" -v4 --no-encryption" ${DUP_SRC_BK}""${i}" file://"${DUP_ROOT}""${i}"
      RETVAL="$?"

      # TODO: solo deberia borrar lo viejo si $RETVAL -eq 0
      duplicity remove-older-than "${DUP_BK_FULL_LIFE}" --force "${DUP_ROOT}"/"${i}"

    done

    [ $RETVAL -eq 0 ] && echo "*** DUPLICITY SUCCESS ***" >>"${LOG}"
    [ $RETVAL -ne 0 ] && echo "*** DUPLICITY ERROR ***" >>"${LOG}"

  fi

}

function make_database_backup() {

  # $1 = ${bk_type}
  # $2 = ${database}

  local bk_type=$1 #configs,sites,databases
  local database=$2

  local mysql_export_result

  local directory_to_backup="${BAKWP}/${NOW}/"
  local db_file="${database}_${bk_type}_${NOW}.sql"

  local old_bk_file="${database}_${bk_type}_${ONEWEEKAGO}.tar.bz2"
  local bk_file="${database}_${bk_type}_${NOW}.tar.bz2"

  log_event "info" "Creating new database backup of ${database} ..."

  # Create dump file 
  mysql_database_export "${database}" "${directory_to_backup}${db_file}"
  mysql_export_result="$?"
  if [[ ${mysql_export_result} -eq 0 ]]; then

    #cd "${BAKWP}/${NOW}"
    log_event "info" "Making a tar.bz2 file of ${db_file} ..."
    display --indent 6 --text "- Compressing database backup"

    # TAR
    (${TAR} -cf - --directory="${directory_to_backup}" "${db_file}" | pv --width 70 -s "$(du -sb "${BAKWP}/${NOW}/${db_file}" | awk '{print $1}')" | lbzip2 >"${BAKWP}/${NOW}/${bk_file}")

    # Test backup file
    log_event "info" "Testing backup file: ${db_file} ..."
    lbzip2 -t "${BAKWP}/${NOW}/${bk_file}"
    lbzip2_result="$?"
    if [[ ${lbzip2_result} -eq 0 ]]; then

      log_event "success" "Backup file ${bk_file}"

      clear_last_line
      clear_last_line
      display --indent 6 --text "- Compressing database backup" --result "DONE" --color GREEN

      # Changing global
      BACKUPED_DB_LIST[$BK_DB_INDEX]="${bk_file}"

      # Calculate backup size
      BK_DB_SIZE="$(find . -name "${bk_file}" -exec ls -l --human-readable --block-size=M {} \; | awk '{ print $5 }')"
      BK_DB_SIZES+=("${BK_DB_SIZE}")

      log_event "success" "Backup for ${database} created, final size: ${BK_DB_SIZE}"
      display --indent 8 --text "Backup final size: ${BK_DB_SIZE}"

      log_event "info" "Creating folders in Dropbox ..."

      # New folder with $VPSNAME
      output="$("${DROPBOX_UPLOADER}" -q mkdir "${VPSNAME}" 2>&1)"
      log_event "info" "Creating dropbox directory ${VPSNAME}"

      # New folder with $bk_type
      output="$("${DROPBOX_UPLOADER}" -q mkdir "/${VPSNAME}/${bk_type}" 2>&1)"
      log_event "info" "Creating dropbox directory ${VPSNAME}/${bk_type}"

      # New folder with $database (project DB)
      output="$("${DROPBOX_UPLOADER}" -q mkdir "/${VPSNAME}/${bk_type}/${database}" 2>&1)"
      log_event "info" "Creating dropbox directory ${VPSNAME}/${bk_type}/${database}"

      display --indent 6 --text "- Creating dropbox directories" --result "DONE" --color GREEN

      DROPBOX_PATH="/${VPSNAME}/${bk_type}/${database}"

      # Upload to Dropbox
      log_event "info" "Uploading new database backup ${bk_file} to dropbox folder ${DROPBOX_FOLDER}${DROPBOX_PATH}"
      output="$(${DROPBOX_UPLOADER} upload "${BAKWP}/${NOW}/${bk_file}" "${DROPBOX_FOLDER}${DROPBOX_PATH}" 2>&1)"
      dropbox_result="$?"
      log_event "info" "dropbox_result: $dropbox_result"

      if [[ ${dropbox_result} -eq 0 ]]; then
      
        display --indent 6 --text "- Uploading new database backup to dropbox" --result "DONE" --color GREEN

        # Delete old backups
        log_event "info" "Deleting old database backup ${old_bk_file} from dropbox"
        output="$(${DROPBOX_UPLOADER} -q remove "${DROPBOX_FOLDER}${DROPBOX_PATH}/${old_bk_file}" 2>&1)"
        display --indent 6 --text "- Delete old database backup" --result "DONE" --color GREEN

        log_event "info" "Deleting old database backup ${old_bk_file} from server"
        rm "${BAKWP}/${NOW}/${db_file}"
        rm "${BAKWP}/${NOW}/${bk_file}"
        display --indent 6 --text "- Delete old database backup from server" --result "DONE" --color GREEN

      else

        display --indent 6 --text "- Uploading new database backup to dropbox" --result "FAIL" --color RED

        log_event "ERROR" "Uploading new database backup to dropbox fail. Command executed: ${DROPBOX_UPLOADER} upload ${BAKWP}/${NOW}/${bk_file} ${DROPBOX_FOLDER}${DROPBOX_PATH}"

        return 1

      fi

    fi

  else

    ERROR=true
    ERROR_TYPE="mysqldump error with ${database}"

  fi

}

function make_project_backup() {

    #TODO: DOES NOT WORK, NEED REFACTOR ASAP!!!

    # $1 = Backup Type
    # $2 = Backup SubType
    # $3 = Path folder to Backup
    # $4 = Folder to Backup

    local bk_type=$1        #configs,sites,databases
    local bk_sup_type=$2    #config_name,site_domain,database_name
    local bk_path=$3
    local directory_to_backup=$4

    local dropbox_output
    local db_file

    local directory_to_backup="${BAKWP}/${NOW}/"

    local old_bk_file="${directory_to_backup}_${bk_type}-files_${ONEWEEKAGO}.tar.bz2"
    local bk_file="${directory_to_backup}_${bk_type}-files_${NOW}.tar.bz2"

    log_event "info" "Making TAR.BZ2 from: ${directory_to_backup} ..."

    (${TAR} --exclude '.git' --exclude '*.log' -cf - --directory="${bk_path}" "${directory_to_backup}" | pv -ns "$(du -sb "${bk_path}/${directory_to_backup}" | awk '{print $1}')" | lbzip2 >"${BAKWP}/${NOW}/${bk_file}") 2>&1

    # Test backup file
    log_event "info" "Testing backup file: ${bk_file}"
    lbzip2 -t "${BAKWP}/${NOW}/${bk_file}"
    lbzip2_result="$?"
    if [[ ${lbzip2_result} -eq 0 ]]; then

        BACKUPED_LIST[$BK_FILE_INDEX]=${bk_file}
        BACKUPED_FL=${BACKUPED_LIST[$BK_FILE_INDEX]}

        # Calculate backup size
        BK_FL_SIZES[$BK_FL_ARRAY_INDEX]="$(find . -name "${bk_file}" -exec ls -l --human-readable --block-size=M {} \; |  awk '{ print $5 }')"
        BK_FL_SIZE=${BK_FL_SIZES[$BK_FL_ARRAY_INDEX]}

        log_event "success" "File backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE}"

        # Checking whether WordPress is installed or not
        if ! $(wp core is-installed); then

            # TODO: Check Composer and Yii Projects

            # Yii Project
            log_event "info" "Trying to get database name from project ..."

            DB_NAME=$(grep 'dbname=' "${bk_path}/${directory_to_backup}/common/config/main-local.php" | tail -1 | sed 's/$dbname=//g;s/,//g' | cut -d "'" -f4 | cut -d "=" -f3)

            db_file="${DB_NAME}.sql"

            # Create dump file
            mysql_database_export "${DB_NAME}" "${directory_to_backup}${db_file}"

        else

            DB_NAME="$(wp --allow-root --path="${bk_path}/${directory_to_backup}" eval 'echo DB_NAME;')"

            db_file="${DB_NAME}.sql"

            wpcli_export_database "${bk_path}/${directory_to_backup}" "${directory_to_backup}${db_file}"

        fi

        log_event "info" "Working with DB_NAME=${DB_NAME}"

        bk_type="database"
        local OLD_BK_DB_FILE="${DB_NAME}_${bk_type}_${ONEWEEKAGO}.tar.bz2"
        local BK_DB_FILE="${DB_NAME}_${bk_type}_${NOW}.tar.bz2"

        log_event "info" "Compressing database backup: ${db_file}"

        # TAR
        (${TAR} -cf - --directory="${directory_to_backup}" "${db_file}" | pv --width 70 -s "$(du -sb "${BAKWP}/${NOW}/${db_file}" | awk '{print $1}')" | lbzip2 >"${BAKWP}/${NOW}/${BK_DB_FILE}")

        # Test backup file
        log_event "info" "Testing backup file: ${BK_DB_FILE}"
        lbzip2 -t "${BAKWP}/${NOW}/${BK_DB_FILE}"

        log_event "info" "Trying to create folders in Dropbox"

        # New folder with $VPSNAME
        dropbox_output=$(${DROPBOX_UPLOADER} -q mkdir "/${VPSNAME}" 2>&1)
        
        # New folder with $bk_type
        dropbox_output=$(${DROPBOX_UPLOADER} -q mkdir "/${VPSNAME}/${bk_type}" 2>&1)

        # New folder with $directory_to_backup
        dropbox_output=$(${DROPBOX_UPLOADER} -q mkdir "/${VPSNAME}/${bk_type}/${directory_to_backup}" 2>&1)

        log_event "info" "Uploading file backup ${bk_file} to Dropbox ..."
        dropbox_output=$(${DROPBOX_UPLOADER} upload "${BAKWP}/${NOW}/${bk_file}" "${DROPBOX_FOLDER}/${VPSNAME}/${bk_type}/${directory_to_backup}/${NOW}" 2>&1)

        log_event "info" "Uploading database backup ${BK_DB_FILE} to Dropbox ..."
        dropbox_output=$(${DROPBOX_UPLOADER} upload "${BAKWP}/${NOW}/${BK_DB_FILE}" "${DROPBOX_FOLDER}/${VPSNAME}/${bk_type}/${directory_to_backup}/${NOW}" 2>&1)

        log_event "info" "Trying to delete old backup from Dropbox with date ${ONEWEEKAGO} ..."
        dropbox_output=$(${DROPBOX_UPLOADER} delete "${DROPBOX_FOLDER}/${VPSNAME}/${bk_type}/${directory_to_backup}/${ONEWEEKAGO}" 2>&1)

        log_event "info" "Deleting backup from server ..."
        rm -r "${BAKWP}/${NOW}/${bk_file}"

        log_event "success" "Project backup ok!"

    else
        ERROR=true
        ERROR_TYPE=" > ERROR: Making backup ${BAKWP}/${NOW}/${bk_file}"
        #echo "${ERROR_TYPE}" >>"${LOG}"

    fi

}