#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1
#############################################################################
#
# Backup Helper: Perform backup actions.
#
################################################################################

################################################################################
# Get Backup Date
#
# Arguments:
#  $1 = ${backup_file}
#
# Outputs:
#   ${backup_date}
################################################################################

function get_backup_date() {

  local backup_file=$1

  local backup_date

  backup_date="$(echo "${backup_file}" | grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}')"

  # Return
  echo "${backup_date}"

}

################################################################################
# Make server files Backup
#
# Arguments:
#  $1 = ${bk_type} - Backup Type: configs, logs, data
#  $2 = ${bk_sup_type} - Backup SubType: php, nginx, mysql
#  $3 = ${bk_path} - Path folder to Backup
#  $4 = ${directory_to_backup} - Folder to Backup
#
# Outputs:
#   0 if ok, 1 if error
################################################################################

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

  local bk_type=$1
  local bk_sup_type=$2
  local bk_path=$3
  local directory_to_backup=$4

  local got_error
  local backup_file
  local old_bk_file
  local dropbox_path

  got_error=0

  if [[ -n ${bk_path} ]]; then

    # Backups file names
    backup_file="${bk_sup_type}-${bk_type}-files-${NOW}.tar.bz2"
    old_bk_file="${bk_sup_type}-${bk_type}-files-${DAYSAGO}.tar.bz2"

    # Compress backup
    backup_file_size="$(compress "${bk_path}" "${directory_to_backup}" "${TMP_DIR}/${NOW}/${backup_file}")"

    # Check test result
    compress_result=$?
    if [[ ${compress_result} -eq 0 ]]; then

      # New folder with $VPSNAME
      dropbox_create_dir "${VPSNAME}"

      # New folder with $bk_type
      dropbox_create_dir "${VPSNAME}/${bk_type}"

      # New folder with $bk_sup_type (php, nginx, mysql)
      dropbox_create_dir "${VPSNAME}/${bk_type}/${bk_sup_type}"

      # Dropbox Path
      dropbox_path="${VPSNAME}/${bk_type}/${bk_sup_type}"

      # Uploading backup files
      dropbox_upload "${TMP_DIR}/${NOW}/${backup_file}" "${DROPBOX_FOLDER}/${dropbox_path}"

      # Deleting old backup files
      dropbox_delete "${DROPBOX_FOLDER}/${dropbox_path}/${old_bk_file}"

      # Return
      echo "${backup_file_size}"

    else

      error_msg="Something went wrong making a backup of ${directory_to_backup}."
      error_type=""
      got_error=1

      # Return
      echo "${got_error}"

    fi

  else

    log_event "error" "Directory ${bk_path} doesn't exists." "false"

    display --indent 6 --text "- Creating backup file" --result "FAIL" --color RED
    display --indent 8 --text "Result: Directory '${bk_path}' doesn't exists" --tcolor RED

    error_msg="Directory ${bk_path} doesn't exists."
    error_type=""
    got_error=1

    # Return
    echo "${got_error}"

  fi

  log_break "true"

}

################################################################################
# Make Mailcow Backup
#
# Arguments:
#  $1 = ${directory_to_backup} - Path folder to Backup
#
# Outputs:
#   0 if ok, 1 if error
################################################################################

function make_mailcow_backup() {

  local directory_to_backup=$1

  # VAR $bk_type rewrited
  local bk_type="mailcow"
  local mailcow_backup_result

  local dropbox_path

  log_subsection "Mailcow Backup"

  if [[ -n "${MAILCOW_DIR}" ]]; then

    old_bk_file="${bk_type}_files-${DAYSAGO}.tar.bz2"
    backup_file="${bk_type}_files-${NOW}.tar.bz2"

    log_event "info" "Trying to make a backup of ${MAILCOW_DIR} ..." "false"
    display --indent 6 --text "- Making ${YELLOW}${MAILCOW_DIR}${ENDCOLOR} backup" --result "DONE" --color GREEN

    # Small hack for pass backup directory to backup_and_restore.sh
    MAILCOW_BACKUP_LOCATION="${MAILCOW_DIR}"
    export MAILCOW_BACKUP_LOCATION

    # Run built-in script for backup Mailcow
    "${MAILCOW_DIR}/helper-scripts/backup_and_restore.sh" backup all
    mailcow_backup_result=$?
    if [[ ${mailcow_backup_result} -eq 0 ]]; then

      # Small trick to get Mailcow backup base dir
      cd "${MAILCOW_DIR}"
      cd mailcow-*

      # New MAILCOW_BACKUP_LOCATION
      MAILCOW_BACKUP_LOCATION="$(basename "${PWD}")"

      # Back
      cd ..

      log_event "info" "Making tar.bz2 from: ${MAILCOW_DIR}/${MAILCOW_BACKUP_LOCATION} ..." "false"

      # Tar file
      (${TAR} -cf - --directory="${MAILCOW_DIR}" "${MAILCOW_BACKUP_LOCATION}" | pv --width 70 -ns "$(du -sb "${MAILCOW_DIR}/${MAILCOW_BACKUP_LOCATION}" | awk '{print $1}')" | lbzip2 >"${MAILCOW_TMP_BK}/${backup_file}")

      # Log
      clear_previous_lines "1"
      log_event "info" "Testing backup file: ${backup_file} ..." "false"

      # Test backup file
      lbzip2 --test "${MAILCOW_TMP_BK}/${backup_file}"

      lbzip2_result=$?
      if [[ ${lbzip2_result} -eq 0 ]]; then

        log_event "info" "${MAILCOW_TMP_BK}/${backup_file} backup created" "false"

        # New folder with $VPSNAME
        dropbox_create_dir "${VPSNAME}"
        dropbox_create_dir "${VPSNAME}/${bk_type}"

        dropbox_path="/${VPSNAME}/${bk_type}"

        log_event "info" "Uploading Backup to Dropbox ..." "false"
        display --indent 6 --text "- Uploading backup file to Dropbox"

        # Upload new backup
        dropbox_upload "${MAILCOW_TMP_BK}/${backup_file}" "${DROPBOX_FOLDER}/${dropbox_path}"

        # Remove old backup
        dropbox_delete "${DROPBOX_FOLDER}/${dropbox_path}/${old_bk_file}"

        # Remove old backups from server
        rm --recursive --force "${MAILCOW_DIR}/${MAILCOW_BACKUP_LOCATION:?}"
        rm --recursive --force "${MAILCOW_TMP_BK}/${backup_file:?}"

        log_event "info" "Mailcow backup finished" "false"

      fi

    else

      log_event "error" "Can't make the backup!" "false"

      return 1

    fi

  else

    log_event "error" "Directory '${MAILCOW_DIR}' doesnt exists!" "false"

    return 1

  fi

  log_break

}

################################################################################
# Make all server configs Backup
#
# Arguments:
#  none
#
# Outputs:
#   0 if ok, 1 if error
################################################################################

function make_all_server_config_backup() {

  #local -n backuped_config_list
  #local -n backuped_config_sizes_list

  local backuped_config_index=0

  log_subsection "Backup Server Config"

  # TAR Webserver Config Files
  if [[ ! -d ${WSERVER} ]]; then
    log_event "warning" "WSERVER is not defined! Skipping webserver config files backup ..." "false"

  else
    nginx_files_backup_result="$(make_server_files_backup "configs" "nginx" "${WSERVER}" ".")"

    backuped_config_list[$backuped_config_index]="${WSERVER}"
    backuped_config_sizes_list+=("${nginx_files_backup_result}")

    backuped_config_index=$((backuped_config_index + 1))

  fi

  # TAR PHP Config Files
  if [[ ! -d ${PHP_CF} ]]; then
    log_event "warning" "PHP_CF is not defined! Skipping PHP config files backup ..." "false"

  else

    php_files_backup_result="$(make_server_files_backup "configs" "php" "${PHP_CF}" ".")"

    backuped_config_list[$backuped_config_index]="${PHP_CF}"
    backuped_config_sizes_list+=("${php_files_backup_result}")

    backuped_config_index=$((backuped_config_index + 1))

  fi

  # TAR MySQL Config Files
  if [[ ! -d ${MySQL_CF} ]]; then
    log_event "warning" "MySQL_CF is not defined! Skipping MySQL config files backup ..." "false"

  else

    mysql_files_backup_result="$(make_server_files_backup "configs" "mysql" "${MySQL_CF}" ".")"

    backuped_config_list[$backuped_config_index]="${MySQL_CF}"
    backuped_config_sizes_list+=("${mysql_files_backup_result}")

    backuped_config_index=$((backuped_config_index + 1))

  fi

  # TAR Let's Encrypt Config Files
  if [[ ! -d ${LENCRYPT_CF} ]]; then
    log_event "warning" "LENCRYPT_CF is not defined! Skipping Letsencrypt config files backup ..." "false"

  else

    le_files_backup_result="$(make_server_files_backup "configs" "letsencrypt" "${LENCRYPT_CF}" ".")"

    backuped_config_list[$backuped_config_index]="${LENCRYPT_CF}"
    backuped_config_sizes_list+=("${le_files_backup_result}")

    backuped_config_index=$((backuped_config_index + 1))

  fi

  # TAR Devops Config Files
  if [[ ! -d ${BROLIT_CONFIG_PATH} ]]; then
    log_event "warning" "BROLIT_CONFIG_PATH is not defined! Skipping DevOps config files backup ..." "false"

  else

    brolit_files_backup_result="$(make_server_files_backup "configs" "brolit" "${BROLIT_CONFIG_PATH}" ".")"

    backuped_config_list[$backuped_config_index]="${BROLIT_CONFIG_PATH}"
    backuped_config_sizes_list+=("${brolit_files_backup_result}")

    backuped_config_index=$((backuped_config_index + 1))

  fi

  # Configure Files Backup Section for Email Notification
  mail_config_backup_section "${ERROR}" "${ERROR_TYPE}" "${backuped_config_list[@]}" "${backuped_config_sizes_list[@]}"

  # Return
  echo "${ERROR}"

}

################################################################################
# Make sites files Backup
#
# Arguments:
#  none
#
# Outputs:
#   0 if ok, 1 if error
################################################################################

function make_sites_files_backup() {

  local backup_file_size

  local backuped_files_index=0
  local backuped_directory_index=0

  local directory_name=""

  local k=0

  log_subsection "Backup Sites Files"

  # Get all directories
  TOTAL_SITES="$(get_all_directories "${PROJECTS_PATH}")"

  # Get length of $TOTAL_SITES
  COUNT_TOTAL_SITES="$(find "${PROJECTS_PATH}" -maxdepth 1 -type d -printf '.' | wc -c)"
  COUNT_TOTAL_SITES="$((COUNT_TOTAL_SITES - 1))"

  # Log
  display --indent 6 --text "- Directories found" --result "${COUNT_TOTAL_SITES}" --color WHITE
  log_event "info" "Found ${COUNT_TOTAL_SITES} directories" "false"
  log_break "true"

  for j in ${TOTAL_SITES}; do

    log_event "info" "Processing [${j}] ..." "false"

    if [[ ${k} -gt 0 ]]; then

      directory_name="$(basename "${j}")"

      if [[ ${BLACKLISTED_SITES} != *"${directory_name}"* ]]; then

        backup_file_size="$(make_files_backup "site" "${PROJECTS_PATH}" "${directory_name}")"

        backuped_files_list[$backuped_files_index]="${directory_name}"
        backuped_files_sizes_list+=("${backup_file_size}")
        backuped_files_index=$((backuped_files_index + 1))

        log_break "true"

      else
        log_event "info" "Omitting ${directory_name} (blacklisted) ..." "false"

      fi

      backuped_directory_index=$((backuped_directory_index + 1))

      log_event "info" "Processed ${backuped_directory_index} of ${COUNT_TOTAL_SITES} directories" "false"

    fi

    k=$k+1

  done

  # Deleting old backup files
  rm --recursive --force "${TMP_DIR:?}/${NOW}"

  # DUPLICITY
  duplicity_backup

  # Configure Files Backup Section for Email Notification
  mail_files_backup_section "${ERROR}" "${ERROR_TYPE}" "${backuped_files_list[@]}" "${backuped_files_sizes_list[@]}"

}

################################################################################
# Make all files Backup
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 if error
################################################################################

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

  ## PROJECTS_PATH FILES
  make_sites_files_backup

}

################################################################################
# Make files Backup
#
# Arguments:
#  $1 = ${bk_type} - Backup Type (site_configs or sites)
#  $2 = ${bk_path} - Path where directories to backup are stored
#  $3 = ${directory_to_backup} - The specific folder/file to backup
#
# Outputs:
#  0 if ok, 1 if error
################################################################################

function make_files_backup() {

  local bk_type=$1
  local bk_path=$2
  local directory_to_backup=$3

  local old_bk_file="${directory_to_backup}_${bk_type}-files_${DAYSAGO}.tar.bz2"
  local backup_file="${directory_to_backup}_${bk_type}-files_${NOW}.tar.bz2"

  local dropbox_path

  # Compress backup
  backup_file_size="$(compress "${bk_path}" "${directory_to_backup}" "${TMP_DIR}/${NOW}/${backup_file}")"

  # Check test result
  compress_result=$?
  if [[ ${compress_result} -eq 0 ]]; then

    # New folder with $VPSNAME
    dropbox_create_dir "${VPSNAME}"

    # New folder with $bk_type
    dropbox_create_dir "${VPSNAME}/${bk_type}"

    # New folder with $directory_to_backup (project folder)
    dropbox_create_dir "${VPSNAME}/${bk_type}/${directory_to_backup}"

    dropbox_path="${VPSNAME}/${bk_type}/${directory_to_backup}"

    # Upload backup
    dropbox_upload "${TMP_DIR}/${NOW}/${backup_file}" "${DROPBOX_FOLDER}/${dropbox_path}"

    # Delete old backup from Dropbox
    dropbox_delete "${DROPBOX_FOLDER}/${dropbox_path}/${old_bk_file}"

    # Delete temp backup
    rm --force "${TMP_DIR}/${NOW}/${backup_file}"

    # Log
    log_event "info" "Temp backup deleted from server" "false"
    #display --indent 6 --text "- Deleting temp files" --result "DONE" --color GREEN

    # Return
    echo "${backup_file_size}"

  else

    return 1

  fi

}

################################################################################
# Duplicity Backup (BETA)
#
# Arguments:
#  none
#
# Outputs:
#   0 if ok, 1 if error
################################################################################

function duplicity_backup() {

  if [[ ${BACKUP_DUPLICITY_STATUS} == "enabled" ]]; then

    log_event "warning" "duplicity backup is in BETA state" "true"

    # Check if DUPLICITY is installed
    package_install_if_not "duplicity"

    # Get all directories
    all_sites="$(get_all_directories "${PROJECTS_PATH}")"

    # Loop in to Directories
    #for i in $(echo "${PROJECTS_PATH}" | sed "s/,/ /g"); do
    for i in ${all_sites}; do

      log_event "debug" "Running: duplicity --full-if-older-than \"${BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY}\" -v4 --no-encryption\" ${PROJECTS_PATH}\"\"${i}\" file://\"${BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH}\"\"${i}\"" "true"

      duplicity --full-if-older-than "${BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY}" -v4 --no-encryption" ${PROJECTS_PATH}""${i}" file://"${BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH}""${i}"
      exitstatus=$?

      log_event "debug" "exitstatus=$?" "false"

      # TODO: should only remove old entries only if ${exitstatus} -eq 0
      duplicity remove-older-than "${BACKUP_DUPLICITY_CONFIG_FULL_LIFE}" --force "${BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH}"/"${i}"

    done

    [ $exitstatus -eq 0 ] && echo "*** DUPLICITY SUCCESS ***" >>"${LOG}"
    [ $exitstatus -ne 0 ] && echo "*** DUPLICITY ERROR ***" >>"${LOG}"

  fi

}

################################################################################
# Make all databases Backup
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 if error
################################################################################

function make_all_databases_backup() {

  local got_error
  local error_msg
  local error_type
  local database_backup_index

  # Starting Messages
  log_subsection "Backup Databases"

  display --indent 6 --text "- Initializing database backup script" --result "DONE" --color GREEN

  # Get MySQL DBS
  databases="$(mysql_list_databases "all")"

  # Get all databases name
  total_databases="$(mysql_count_databases "${databases}")"

  # Log
  display --indent 6 --text "- Databases found" --result "${total_databases}" --color WHITE
  log_event "info" "Databases found: ${total_databases}" "false"
  log_break "true"

  got_error=0
  database_backup_index=0

  for database in ${databases}; do

    if [[ ${BLACKLISTED_DATABASES} != *"${database}"* ]]; then

      log_event "info" "Processing [${database}] ..." "false"

      # Make database backup
      backup_file="$(make_database_backup "${database}")"

      if [[ ${backup_file} != "" ]]; then

        # Extract parameters from ${backup_file}
        database_backup_path="$(echo "${backup_file}" | cut -d ";" -f 1)"
        database_backup_size="$(echo "${backup_file}" | cut -d ";" -f 2)"

        database_backup_file="$(basename "${database_backup_path}")"

        backuped_databases_list[$database_backup_index]="${database_backup_file}"
        backuped_databases_sizes_list+=("${database_backup_size}")

        # Upload backup
        upload_backup_to_dropbox "${database}" "database" "${database_backup_path}"

        database_backup_index=$((database_backup_index + 1))

        log_event "info" "Backup ${database_backup_index} of ${total_databases} done" "false"

      else

        log_event "error" "Creating backup file for database" "false"

        error_msg="Something went wrong making a backup of ${database}. ${error_msg}"
        error_type=""
        got_error=1

      fi

    else

      display --indent 6 --text "- Ommiting database ${database}" --result "DONE" --color WHITE
      log_event "info" "Ommiting blacklisted database: ${database}" "false"

    fi

    log_break "true"

  done

  # Configure Email
  mail_databases_backup_section "${error_msg}" "${error_type}" "${backuped_databases_list[@]}" "${backuped_databases_sizes_list[@]}"

  # Return
  echo "${got_error}"

}

################################################################################
# Make database Backup
#
# Arguments:
#  $1 = ${database}
#
# Outputs:
#  "backupfile backup_file_size" if ok, 1 if error
################################################################################

function make_database_backup() {

  local database=$1

  local mysql_export_result

  local directory_to_backup="${TMP_DIR}/${NOW}/"
  local db_file="${database}_database_${NOW}.sql"

  local backup_file="${database}_database_${NOW}.tar.bz2"

  local dropbox_path

  log_event "info" "Creating new database backup of '${database}'" "false"

  # Create dump file
  mysql_database_export "${database}" "${directory_to_backup}${db_file}"
  mysql_export_result=$?

  if [[ ${mysql_export_result} -eq 0 ]]; then

    # Compress backup
    backup_file_size="$(compress "${directory_to_backup}" "${db_file}" "${TMP_DIR}/${NOW}/${backup_file}")"

    # Check test result
    compress_result=$?
    if [[ ${compress_result} -eq 0 ]]; then

      # Return
      ## backupfile backup_file_size
      echo "${TMP_DIR}/${NOW}/${backup_file};${backup_file_size}"

    else

      return 1

    fi

  else

    ERROR=true
    ERROR_TYPE="mysqldump error with ${database}"

  fi

}

################################################################################
# Make project Backup
#
# Arguments:
#  $1 = ${project_domain}
#  $2 = ${backup_type} - (all,configs,sites,databases) - Default: all
#
# Outputs:
#   0 if ok, 1 if error
################################################################################

function make_project_backup() {

  local project_domain=$1
  local backup_type=$2

  local project_name
  local project_config_file

  # Backup files
  make_files_backup "site" "${PROJECTS_PATH}" "${project_domain}"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # TODO: Check others project types

    log_event "info" "Trying to get database name from project ..." "false"

    project_name="$(project_get_name_from_domain "${project_domain}")"

    project_config_file="${BROLIT_CONFIG_PATH}/${project_name}_conf.json"

    if [[ -f "${project_config_file}" ]]; then

      db_name="$(project_get_config "${PROJECTS_PATH}/${project_domain}" "project_db")"

    else

      db_stage="$(project_get_stage_from_domain "${project_domain}")"
      db_name="$(project_get_name_from_domain "${project_domain}")"
      db_name="${db_name}_${db_stage}"

    fi

    # Backup database
    make_database_backup "${db_name}"

    log_event "info" "Deleting backup from server ..." "false"

    rm --recursive --force "${TMP_DIR}/${NOW}/${backup_type}"

    log_event "info" "Project backup done" "false"

  else

    ERROR=true
    log_event "error" "Something went wrong making a project backup" "false"

  fi

}

function upload_backup_to_dropbox() {

  local project_name=$1
  local backup_type=$2
  local backup_file=$3

  #string_remove_special_chars "${project_name}"

  # New folder with $VPSNAME
  dropbox_create_dir "${VPSNAME}"

  # New folder with "project_name"
  dropbox_create_dir "${VPSNAME}/${backup_type}"

  # New folder with $project_name (project DB)
  dropbox_create_dir "${VPSNAME}/${backup_type}/${project_name}"

  # Dropbox Path
  dropbox_path="/${VPSNAME}/${backup_type}/${project_name}"

  # Upload to Dropbox
  dropbox_upload "${backup_file}" "${DROPBOX_FOLDER}${dropbox_path}"

  dropbox_result=$?
  if [[ ${dropbox_result} -eq 0 ]]; then

    # Old backup
    old_backup_file="${project_name}_${backup_type}_${DAYSAGO}.tar.bz2"

    # Delete
    dropbox_delete "${DROPBOX_FOLDER}${dropbox_path}/${old_backup_file}"

    log_event "info" "Deleting temp ${backup_type} backup ${old_backup_file} from server" "false"

    rm "${backup_file}"

  else

    return 1

  fi

}
