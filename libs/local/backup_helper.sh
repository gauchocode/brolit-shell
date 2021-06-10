#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.35
#############################################################################

function menu_backup_options() {

  local backup_options
  local chosen_backup_type

  backup_options=(
    "01)" "BACKUP DATABASES"
    "02)" "BACKUP FILES"
    "03)" "BACKUP ALL"
    "04)" "BACKUP PROJECT"
  )

  chosen_backup_type="$(whiptail --title "SELECT BACKUP TYPE" --menu " " 20 78 10 "${backup_options[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_backup_type} == *"01"* ]]; then

      # DATABASE_BACKUP
      log_section "Databases Backup"

      # Preparing Mail Notifications Template
      HTMLOPEN="$(mail_html_start)"
      BODY_SRV="$(mail_server_status_section "${SERVER_IP}")"

      # Databases Backup
      make_all_databases_backup

      DB_MAIL="${TMP_DIR}/db-bk-${NOW}.mail"
      DB_MAIL_VAR=$(<"${DB_MAIL}")

      log_event "info" "Sending Email to ${MAILA} ..." "false"

      EMAIL_SUBJECT="${STATUS_ICON_D} [${NOWDISPLAY}] - Database Backup on ${VPSNAME}"
      EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${DB_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      mail_send_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

    fi
    if [[ ${chosen_backup_type} == *"02"* ]]; then

      # FILES_BACKUP

      log_section "Files Backup"

      # Preparing Mail Notifications Template
      HTMLOPEN="$(mail_html_start)"
      BODY_SRV="$(mail_server_status_section "${SERVER_IP}")"

      # Files Backup
      make_all_files_backup

      CONFIG_MAIL="${TMP_DIR}/config-bk-${NOW}.mail"
      CONFIG_MAIL_VAR=$(<"${CONFIG_MAIL}")

      FILE_MAIL="${TMP_DIR}/file-bk-${NOW}.mail"
      FILE_MAIL_VAR=$(<"${FILE_MAIL}")

      log_event "info" "Sending Email to ${MAILA} ..." "false"

      EMAIL_SUBJECT="${STATUS_ICON_F} [${NOWDISPLAY}] - Files Backup on ${VPSNAME}"
      EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${CERT_MAIL_VAR} ${CONFIG_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      mail_send_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

    fi
    if [[ ${chosen_backup_type} == *"03"* ]]; then

      # BACKUP_ALL
      log_section "Backup All"

      # Preparing Mail Notifications Template
      HTMLOPEN="$(mail_html_start)"
      BODY_SRV="$(mail_server_status_section "${SERVER_IP}")"

      # Databases Backup
      make_all_databases_backup

      # Files Backup
      make_all_files_backup

      # Mail section for Database Backup
      DB_MAIL="${TMP_DIR}/db-bk-${NOW}.mail"
      DB_MAIL_VAR=$(<"${DB_MAIL}")

      # Mail section for Server Config Backup
      CONFIG_MAIL="${TMP_DIR}/config-bk-${NOW}.mail"
      CONFIG_MAIL_VAR=$(<"${CONFIG_MAIL}")

      # Mail section for Files Backup
      FILE_MAIL="${TMP_DIR}/file-bk-${NOW}.mail"
      FILE_MAIL_VAR=$(<"${FILE_MAIL}")

      MAIL_FOOTER=$(mail_footer "${SCRIPT_V}")

      # Checking result status for mail subject
      EMAIL_STATUS="$(mail_subject_status "${STATUS_BACKUP_DBS}" "${STATUS_BACKUP_FILES}" "${STATUS_SERVER}" "${OUTDATED_PACKAGES}")"

      log_event "info" "Sending Email to ${MAILA} ..."

      EMAIL_SUBJECT="${EMAIL_STATUS} [${NOWDISPLAY}] - Complete Backup on ${VPSNAME}"
      EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${BODY_PKG} ${DB_MAIL_VAR} ${CONFIG_MAIL_VAR} ${FILE_MAIL_VAR} ${MAIL_FOOTER}"

      # Sending email notification
      mail_send_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

      remove_mail_notifications_files

    fi

    if [[ ${chosen_backup_type} == *"04"* ]]; then

      # PROJECT_BACKUP

      # Select project to work with
      directory_browser "Select a project to work with" "${SITES}" #return $filename

      # Directory_broser returns: $filepath and $filename
      if [[ ${filename} != "" && ${filepath} != "" ]]; then

        FOLDER_NAME=$(basename "$j")

        make_project_backup "site" "${FOLDER_NAME}" "${SITES}" "${FOLDER_NAME}"

        make_project_backup "${filepath}/${filename}"

      fi

    fi

  fi

  menu_main_options

}

function get_backup_date() {

  local backup_file=$1

  local backup_date

  backup_date="$(echo "${backup_file}" | grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}')"

  # Return
  echo "${backup_date}"

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
  local dropbox_path
  local bk_scf_size

  if [[ -n ${bk_path} ]]; then

    old_bk_file="${bk_sup_type}-${bk_type}-files-${ONEWEEKAGO}.tar.bz2"
    bk_file="${bk_sup_type}-${bk_type}-files-${NOW}.tar.bz2"

    # Here we use tar.bz2 with bzip2 compression method
    log_event "info" "Making backup of ${bk_path}"
    log_event "debug" "Running: ${TAR} cjf ${TMP_DIR}/${NOW}/${bk_file} --directory=${bk_path} ${directory_to_backup}"

    (${TAR} cjf "${TMP_DIR}/${NOW}/${bk_file}" --directory="${bk_path}" "${directory_to_backup}")

    display --indent 6 --text "- Making ${YELLOW}${bk_sup_type}${ENDCOLOR} backup" --result "DONE" --color GREEN
    display --indent 6 --text "- Compressing directory ${bk_path}" --result "DONE" --color GREEN

    # Test backup file
    log_event "info" "Testing backup file: ${bk_file} ..."
    lbzip2 --test "${TMP_DIR}/${NOW}/${bk_file}"

    # Check test result
    bzip2_result=$?
    if [[ ${bzip2_result} -eq 0 ]]; then

      log_event "info" "Backup ${bk_file} created"

      #BACKUPED_SCF_LIST[$BK_SCF_INDEX]="$(string_remove_special_chars "${bk_file}")"
      BACKUPED_SCF_LIST[$BK_SCF_INDEX]=${bk_file}

      # Calculate backup size
      bk_scf_size="$(find . -name "${bk_file}" -exec ls -l --human-readable --block-size=K {} \; | awk '{ print $5 }')"
      BK_SCF_SIZES[$BK_SCF_INDEX]="${bk_scf_size}"

      display --indent 6 --text "- Testing compressed backup file" --result "DONE" --color GREEN

      # New folder with $VPSNAME
      dropbox_create_dir "${VPSNAME}"

      # New folder with $bk_type
      dropbox_create_dir "${VPSNAME}/${bk_type}"

      # New folder with $bk_sup_type (php, nginx, mysql)
      dropbox_create_dir "${VPSNAME}/${bk_type}/${bk_sup_type}"

      # Dropbox Path
      dropbox_path="${VPSNAME}/${bk_type}/${bk_sup_type}"

      # Uploading backup files
      dropbox_upload "${TMP_DIR}/${NOW}/${bk_file}" "${DROPBOX_FOLDER}/${dropbox_path}"

      # Deleting old backup files
      dropbox_delete "${DROPBOX_FOLDER}/${dropbox_path}/${old_bk_file}"

    else

      bzip2_error="No such directory or file ${TMP_DIR}/${NOW}/${bk_file}"

      log_event "critical" "Can't make the backup. No such directory or file ${TMP_DIR}/${NOW}/${bk_file}"

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

  local dropbox_path

  log_subsection "Mailcow Backup"

  if [[ -n "${MAILCOW}" ]]; then

    old_bk_file="${bk_type}_files-${ONEWEEKAGO}.tar.bz2"
    bk_file="${bk_type}_files-${NOW}.tar.bz2"

    log_event "info" "Trying to make a backup of ${MAILCOW} ..."
    display --indent 6 --text "- Making ${YELLOW}${MAILCOW}${ENDCOLOR} backup" --result "DONE" --color GREEN

    "${MAILCOW}/helper-scripts/backup_and_restore.sh" backup all
    mailcow_backup_result=$?
    if [[ "${mailcow_backup_result}" -eq 0 ]]; then

      # Con un pequeño truco vamos a obtener el nombre de la carpeta que crea mailcow
      cd "${MAILCOW_TMP_BK}"
      cd mailcow-*
      MAILCOW_TMP_FOLDER="$(basename "${PWD}")"
      cd ..

      log_event "info" "Making tar.bz2 from: ${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER} ..."

      ${TAR} -cf - --directory="${MAILCOW_TMP_BK}" "${MAILCOW_TMP_FOLDER}" | pv --width 70 -ns "$(du -sb "${MAILCOW_TMP_BK}/${MAILCOW_TMP_FOLDER}" | awk '{print $1}')" | lbzip2 >"${MAILCOW_TMP_BK}/${bk_file}"

      # Clear pipe output
      clear_last_line

      # Test backup file
      log_event "info" "Testing backup file: ${bk_file} ..."
      lbzip2 --test "${MAILCOW_TMP_BK}/${bk_file}"

      lbzip2_result=$?
      if [[ ${lbzip2_result} -eq 0 ]]; then

        log_event "info" "${MAILCOW_TMP_BK}/${bk_file} backup created"

        # New folder with $VPSNAME
        output="$(${DROPBOX_UPLOADER} -q mkdir "/${VPSNAME}" 2>&1)"

        # New folder with $bk_type
        output="$(${DROPBOX_UPLOADER} -q mkdir "/${VPSNAME}/${bk_type}" 2>&1)"

        dropbox_path="/${VPSNAME}/${bk_type}"

        log_event "info" "Uploading Backup to Dropbox ..."
        display --indent 6 --text "- Uploading backup file to Dropbox"

        output=$(${DROPBOX_UPLOADER} upload "${MAILCOW_TMP_BK}/${bk_file}" "${DROPBOX_FOLDER}/${dropbox_path}" 2>&1)
        clear_last_line
        display --indent 6 --text "- Uploading backup file to Dropbox" --result "DONE" --color GREEN

        log_event "info" "Deleting old backup from Dropbox ..."
        output=$(${DROPBOX_UPLOADER} remove "${DROPBOX_FOLDER}/${dropbox_path}/${bk_file}" 2>&1)

        rm --recursive --force "${MAILCOW_TMP_BK}"

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
  declare -g BACKUPED_SCF_LIST
  declare -g BK_SCF_SIZES

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
  mail_config_backup_section "${ERROR}" "${ERROR_TYPE}"

}

function make_sites_files_backup() {

  log_subsection "Backup Sites Files"

  # Get all directories
  TOTAL_SITES=$(get_all_directories "${SITES}")

  # Get length of $TOTAL_SITES
  COUNT_TOTAL_SITES="$(find "${SITES}" -maxdepth 1 -type d -printf '.' | wc -c)"
  COUNT_TOTAL_SITES="$((COUNT_TOTAL_SITES - 1))"

  # Log
  log_event "info" "Found ${COUNT_TOTAL_SITES} directories"
  display --indent 6 --text "- Directories found" --result "${COUNT_TOTAL_SITES}" --color WHITE
  log_break "true"

  # FILES BACKUP GLOBALS
  declare -i BK_FILE_INDEX=0
  declare -i BK_FL_ARRAY_INDEX=0
  declare -g BACKUPED_LIST
  declare -g BK_FL_SIZES

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
  rm --recursive --force "${TMP_DIR:?}/${NOW}"

  # DUPLICITY
  duplicity_backup

  # Configure Files Backup Section for Email Notification
  mail_filesbackup_section "${ERROR}" "${ERROR_TYPE}"

}

function make_all_files_backup() {

  ## MAILCOW FILES
  if [[ ${MAILCOW_BK} == true ]]; then

    if [[ ! -d ${MAILCOW_TMP_BK} ]]; then

      log_event "info" "Folder ${MAILCOW_TMP_BK} doesn't exist. Creating now ..."

      mkdir "${MAILCOW_TMP_BK}"

    fi

    make_mailcow_backup "${MAILCOW}"

  fi

  # TODO: error_type needs refactoring

  ## SERVER CONFIG FILES
  make_all_server_config_backup

  ## SITES FILES
  make_sites_files_backup

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

  local dropbox_path

  log_event "info" "Making backup file from: ${directory_to_backup} ..."
  display --indent 6 --text "- Making ${YELLOW}${directory_to_backup}${ENDCOLOR} backup" --result "DONE" --color GREEN

  (${TAR} --exclude '.git' --exclude '*.log' -cf - --directory="${bk_path}" "${directory_to_backup}" | pv --width 70 --size "$(du -sb "${bk_path}/${directory_to_backup}" | awk '{print $1}')" | lbzip2 >"${TMP_DIR}/${NOW}/${bk_file}") 2>&1

  # Clear pipe output
  clear_last_line

  # Test backup file
  log_event "info" "Testing backup file: ${bk_file} ..."
  display --indent 6 --text "- Testing backup file"

  pv --width 70 "${TMP_DIR}/${NOW}/${bk_file}" | lbzip2 --test

  # Clear pipe output
  clear_last_line

  lbzip2_result=$?
  if [[ "${lbzip2_result}" -eq 0 ]]; then

    BACKUPED_LIST[$BK_FILE_INDEX]=${bk_file}
    BACKUPED_FL=${BACKUPED_LIST[${BK_FILE_INDEX}]}

    # Calculate backup size
    BK_FL_SIZE="$(find "${TMP_DIR}/${NOW}/" -name "${bk_file}" -exec ls -l --human-readable --block-size=M {} \; | awk '{ print $5 }')"
    BK_FL_SIZES[$BK_FL_ARRAY_INDEX]=${BK_FL_SIZE}

    # Log
    display --indent 6 --text "- Compressing backup" --result "DONE" --color GREEN
    display --indent 8 --text "Final backup size: ${YELLOW}${BOLD}${BK_FL_SIZE}${ENDCOLOR}"

    log_event "info" "Backup ${BACKUPED_FL} created, final size: ${BK_FL_SIZE}"
    log_event "info" "Creating folders in Dropbox ..."

    # New folder with $VPSNAME
    dropbox_create_dir "${VPSNAME}"

    # New folder with $bk_type
    dropbox_create_dir "${VPSNAME}/${bk_type}"

    # New folder with $directory_to_backup (project folder)
    dropbox_create_dir "${VPSNAME}/${bk_type}/${directory_to_backup}"

    dropbox_path="${VPSNAME}/${bk_type}/${directory_to_backup}"

    # Upload backup
    dropbox_upload "${TMP_DIR}/${NOW}/${bk_file}" "${DROPBOX_FOLDER}/${dropbox_path}"

    # Delete old backup from Dropbox
    dropbox_delete "${DROPBOX_FOLDER}/${dropbox_path}/${old_bk_file}"

    # Delete temp backup
    rm --force "${TMP_DIR}/${NOW}/${bk_file}"

    # Log
    log_event "info" "Temp backup deleted from server"
    #display --indent 6 --text "- Deleting temp files" --result "DONE" --color GREEN

  else
    ERROR=true
    ERROR_TYPE="ERROR: Making backup ${TMP_DIR}/${NOW}/${bk_file}"

    log_event "error" "Something went wrong making backup file: ${TMP_DIR}/${NOW}/${bk_file}"
    display --indent 6 --text "- Compressing backup" --result "FAIL" --color RED
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
      RETVAL=$?

      # TODO: solo deberia borrar lo viejo si $RETVAL -eq 0
      duplicity remove-older-than "${DUP_BK_FULL_LIFE}" --force "${DUP_ROOT}"/"${i}"

    done

    [ $RETVAL -eq 0 ] && echo "*** DUPLICITY SUCCESS ***" >>"${LOG}"
    [ $RETVAL -ne 0 ] && echo "*** DUPLICITY ERROR ***" >>"${LOG}"

  fi

}

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
  DBS="$(mysql_list_databases)"

  # Get all databases name
  TOTAL_DBS="$(mysql_count_dabases "${DBS}")"

  # Log
  display --indent 6 --text "- Databases found" --result "${TOTAL_DBS}" --color WHITE
  log_event "info" "Databases found: ${TOTAL_DBS}"
  log_break "true"

  # MORE GLOBALS
  declare -g BK_DB_INDEX=0

  for DATABASE in ${DBS}; do

    if [[ ${DB_BL} != *"${DATABASE}"* ]]; then

      log_event "info" "Processing [${DATABASE}] ..."

      make_database_backup "database" "${DATABASE}"

      BK_DB_INDEX=$((BK_DB_INDEX + 1))

      log_event "info" "Backup ${BK_DB_INDEX} of ${TOTAL_DBS} done"

      log_break "true"

    else
      log_event "debug" "Ommiting blacklisted database: [${DATABASE}]"

    fi

  done

  # Configure Email
  log_event "debug" "Preparing mail databases backup section ..."
  mail_mysqlbackup_section "${ERROR}" "${ERROR_TYPE}"

}

function make_database_backup() {

  # $1 = ${bk_type}
  # $2 = ${database}

  local bk_type=$1 #configs,sites,databases
  local database=$2

  local mysql_export_result

  local directory_to_backup="${TMP_DIR}/${NOW}/"
  local db_file="${database}_${bk_type}_${NOW}.sql"

  local old_bk_file="${database}_${bk_type}_${ONEWEEKAGO}.tar.bz2"
  local bk_file="${database}_${bk_type}_${NOW}.tar.bz2"

  local dropbox_path

  # DATABASE BACKUP GLOBALS
  declare -g BACKUPED_DB_LIST
  declare -g BK_DB_SIZES

  log_event "info" "Creating new database backup of ${database} ..."

  # Create dump file
  mysql_database_export "${database}" "${directory_to_backup}${db_file}"
  mysql_export_result=$?
  if [[ ${mysql_export_result} -eq 0 ]]; then

    log_event "info" "Making a tar.bz2 file of ${db_file} ..."
    display --indent 6 --text "- Compressing database backup"

    # TAR
    (${TAR} -cf - --directory="${directory_to_backup}" "${db_file}" | pv --width 70 -s "$(du -sb "${TMP_DIR}/${NOW}/${db_file}" | awk '{print $1}')" | lbzip2 >"${TMP_DIR}/${NOW}/${bk_file}")

    # Clear pipe output
    clear_last_line
    clear_last_line

    # Test backup file
    log_event "info" "Testing backup file: ${db_file} ..."
    display --indent 6 --text "- Testing backup file"

    pv --width 70 "${TMP_DIR}/${NOW}/${bk_file}" | lbzip2 --test

    # Clear pipe output
    clear_last_line
    clear_last_line

    lbzip2_result=$?
    if [[ ${lbzip2_result} -eq 0 ]]; then

      # Log
      log_event "info" "Backup file ${bk_file} created"
      display --indent 6 --text "- Compressing database backup" --result "DONE" --color GREEN

      # Changing global
      BACKUPED_DB_LIST[$BK_DB_INDEX]="${bk_file}"

      # Calculate backup size
      BK_DB_SIZE="$(find . -name "${bk_file}" -exec ls -l --human-readable --block-size=M {} \; | awk '{ print $5 }')"
      BK_DB_SIZES+=("${BK_DB_SIZE}")

      # Log
      log_event "info" "Backup for ${database} created, final size: ${BK_DB_SIZE}"
      display --indent 8 --text "Backup final size: ${YELLOW}${BOLD}${BK_DB_SIZE}${ENDCOLOR}"

      log_event "info" "Creating folders in Dropbox ..."

      # New folder with $VPSNAME
      dropbox_create_dir "${VPSNAME}"

      # New folder with $bk_type
      dropbox_create_dir "${VPSNAME}/${bk_type}"

      # New folder with $database (project DB)
      dropbox_create_dir "${VPSNAME}/${bk_type}/${database}"

      # Dropbox Path
      dropbox_path="/${VPSNAME}/${bk_type}/${database}"

      # Upload to Dropbox
      dropbox_upload "${TMP_DIR}/${NOW}/${bk_file}" "${DROPBOX_FOLDER}${dropbox_path}"
      dropbox_result=$?
      if [[ ${dropbox_result} -eq 0 ]]; then

        # Delete old backups
        dropbox_delete "${DROPBOX_FOLDER}${dropbox_path}/${old_bk_file}"

        log_event "info" "Deleting temp database backup ${old_bk_file} from server"
        rm "${TMP_DIR}/${NOW}/${db_file}"
        rm "${TMP_DIR}/${NOW}/${bk_file}"

      else

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

  # $1 = Project Domain
  # $2 = Backup Type (all,configs,sites,databases) - Default: all

  local project_domain=$1
  local bk_type=$2

  make_files_backup "site" "${SITES}" "${project_domain}"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # TODO: Check others project types

    log_event "info" "Trying to get database name from project ..." "false"

    if [[ -f "${SITES}/${project_domain}/devops.conf" ]]; then

      db_name="$(project_get_config "${SITES}/${project_domain}" "project_db")"

    fi

    make_database_backup "database" "${db_name}"

    log_event "info" "Deleting backup from server ..."

    rm --recursive --force "${TMP_DIR}/${NOW}/${bk_file}"

    log_event "info" "Project backup done" "false"

  else

    ERROR=true
    log_event "error" "Something went wrong making a project backup" "false"

  fi

}
