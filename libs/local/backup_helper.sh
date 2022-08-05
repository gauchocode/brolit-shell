#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc12
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

function backup_get_date() {

  local backup_file="${1}"

  local backup_date

  backup_date="$(echo "${backup_file}" | grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}')"

  # Return
  echo "${backup_date}"

}

################################################################################
# Make server files Backup
#
# Arguments:
#  $1 = ${backup_type} - Backup Type: configs, logs, data
#  $2 = ${bk_sup_type} - Backup SubType: php, nginx, mysql
#  $3 = ${backup_path} - Path folder to Backup
#  $4 = ${directory_to_backup} - Folder to Backup
#
# Outputs:
#   0 if ok, 1 if error
################################################################################

function backup_server_config() {

  # TODO: need to implement error_type

  local backup_type="${1}"
  local bk_sup_type="${2}"
  local backup_path="${3}"
  local directory_to_backup="${4}"

  local got_error
  local backup_file
  local old_backup_file
  local daysago
  local remote_path
  local backup_keep_daily

  got_error=0

  if [[ -n ${backup_path} ]]; then

    # Backups file names
    if [[ ${MONTH_DAY} -eq 1 && ${BACKUP_RETENTION_KEEP_MONTHLY} -gt 0 ]]; then
      ## On first month day do
      backup_file="${bk_sup_type}-${backup_type}-files-${NOW}-monthly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
      old_backup_file="${bk_sup_type}-${backup_type}-files-${MONTHSAGO}-monthly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
    else
      ## On saturdays do
      if [[ ${WEEK_DAY} -eq 6 && ${BACKUP_RETENTION_KEEP_WEEKLY} -gt 0 ]]; then
        backup_file="${bk_sup_type}-${backup_type}-files-${NOW}-weekly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
        old_backup_file="${bk_sup_type}-${backup_type}-files-${WEEKSAGO}-weekly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
      else
        if [[ ${WEEK_DAY} -eq 7 && ${BACKUP_RETENTION_KEEP_WEEKLY} -gt 0 ||
          ${MONTH_DAY} -eq 2 && ${BACKUP_RETENTION_KEEP_MONTHLY} -gt 0 ]]; then
          ## The day after a week day or month day
          backup_keep_daily=$((BACKUP_RETENTION_KEEP_DAILY - 1))
          daysago="$(date --date="${backup_keep_daily} days ago" +"%Y-%m-%d")"
          backup_file="${bk_sup_type}-${backup_type}-files-${NOW}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
          old_backup_file="${bk_sup_type}-${backup_type}-files-${daysago}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
        else
          ## On any regular day do
          backup_file="${bk_sup_type}-${backup_type}-files-${NOW}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
          old_backup_file="${bk_sup_type}-${backup_type}-files-${DAYSAGO}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
        fi
      fi
    fi

    # Log
    display --indent 6 --text "- Files backup for ${YELLOW}${bk_sup_type}${ENDCOLOR}"
    log_event "info" "Files backup for: ${bk_sup_type}" "false"

    # Compress backup
    backup_file_size="$(compress "${backup_path}" "${directory_to_backup}" "${BROLIT_TMP_DIR}/${NOW}/${backup_file}" "")"

    # Check test result
    compress_result=$?
    if [[ ${compress_result} -eq 0 ]]; then

      # Log
      clear_previous_lines "1"
      display --indent 6 --text "- Files backup for ${YELLOW}${bk_sup_type}${ENDCOLOR}" --result "DONE" --color GREEN
      display --indent 8 --text "Final backup size: ${YELLOW}${backup_file_size}${ENDCOLOR}"

      # Remote Path
      remote_path="${SERVER_NAME}/server-config/${bk_sup_type}"

      # Create folder structure
      storage_create_dir "${SERVER_NAME}"
      storage_create_dir "${SERVER_NAME}/server-config"
      storage_create_dir "${SERVER_NAME}/server-config/${bk_sup_type}"

      # Uploading backup files
      storage_upload_backup "${BROLIT_TMP_DIR}/${NOW}/${backup_file}" "${remote_path}"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Deleting old backup file
        storage_delete_backup "${remote_path}/${old_backup_file}"

        # Deleting tmp backup file
        rm --force "${BROLIT_TMP_DIR}/${NOW}/${backup_file}"

        # Return
        echo "${backup_file_size}"

      fi

    else

      # Log
      clear_previous_lines "1"
      display --indent 6 --text "- Files backup for ${YELLOW}${bk_sup_type}${ENDCOLOR}" --result "FAIL" --color RED

      error_msg="Something went wrong making a backup of ${directory_to_backup}."
      error_type=""
      got_error=1

      # Return
      echo "${got_error}"

    fi

  else

    log_event "error" "Directory ${backup_path} doesn't exists." "false"

    display --indent 6 --text "- Creating backup file" --result "FAIL" --color RED
    display --indent 8 --text "Result: Directory '${backup_path}' doesn't exists" --tcolor RED

    error_msg="Directory ${backup_path} doesn't exists."
    error_type=""
    got_error=1

    # Return
    echo "${got_error}"

  fi

  log_break "true"

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

function backup_all_server_configs() {

  #local -n backuped_config_list
  #local -n backuped_config_sizes_list

  local backuped_config_index=0

  log_subsection "Backup Server Config"

  # TAR Webserver Config Files
  if [[ ! -d ${WSERVER} ]]; then
    log_event "warning" "WSERVER is not defined! Skipping webserver config files backup ..." "false"

  else
    nginx_files_backup_result="$(backup_server_config "configs" "nginx" "${WSERVER}" ".")"

    backuped_config_list[$backuped_config_index]="${WSERVER}"
    backuped_config_sizes_list+=("${nginx_files_backup_result}")

    backuped_config_index=$((backuped_config_index + 1))

  fi

  # TAR PHP Config Files
  if [[ ! -d ${PHP_CONF_DIR} ]]; then
    log_event "warning" "PHP_CONF_DIR is not defined! Skipping PHP config files backup ..." "false"

  else

    php_files_backup_result="$(backup_server_config "configs" "php" "${PHP_CONF_DIR}" ".")"

    backuped_config_list[$backuped_config_index]="${PHP_CONF_DIR}"
    backuped_config_sizes_list+=("${php_files_backup_result}")

    backuped_config_index=$((backuped_config_index + 1))

  fi

  # TAR MySQL Config Files
  if [[ ! -d ${MYSQL_CONF_DIR} ]]; then
    log_event "warning" "MYSQL_CONF_DIR is not defined! Skipping MySQL config files backup ..." "false"

  else

    mysql_files_backup_result="$(backup_server_config "configs" "mysql" "${MYSQL_CONF_DIR}" ".")"

    backuped_config_list[$backuped_config_index]="${MYSQL_CONF_DIR}"
    backuped_config_sizes_list+=("${mysql_files_backup_result}")

    backuped_config_index=$((backuped_config_index + 1))

  fi

  # TAR Let's Encrypt Config Files
  if [[ ! -d ${LENCRYPT_CONF_DIR} ]]; then
    log_event "warning" "LENCRYPT_CONF_DIR is not defined! Skipping Letsencrypt config files backup ..." "false"

  else

    le_files_backup_result="$(backup_server_config "configs" "letsencrypt" "${LENCRYPT_CONF_DIR}" ".")"

    backuped_config_list[$backuped_config_index]="${LENCRYPT_CONF_DIR}"
    backuped_config_sizes_list+=("${le_files_backup_result}")

    backuped_config_index=$((backuped_config_index + 1))

  fi

  # TAR Devops Config Files
  if [[ ! -d ${BROLIT_CONFIG_PATH} ]]; then
    log_event "warning" "BROLIT_CONFIG_PATH is not defined! Skipping DevOps config files backup ..." "false"

  else

    brolit_files_backup_result="$(backup_server_config "configs" "brolit" "${BROLIT_CONFIG_PATH}" ".")"

    backuped_config_list[$backuped_config_index]="${BROLIT_CONFIG_PATH}"
    backuped_config_sizes_list+=("${brolit_files_backup_result}")

    backuped_config_index=$((backuped_config_index + 1))

  fi

  # Configure Files Backup Section for Email Notification
  mail_config_backup_section "${ERROR}" "${ERROR_MSG}" "${backuped_config_list[@]}" "${backuped_config_sizes_list[@]}"

  # Return
  echo "${ERROR}"

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

function backup_mailcow() {

  local directory_to_backup="${1}"

  # VAR $backup_type rewrited
  local backup_type="mailcow"
  local mailcow_backup_result
  local storage_path

  log_subsection "Mailcow Backup"

  if [[ -n ${MAILCOW_DIR} ]]; then

    # Backups file names
    if [[ ${MONTH_DAY} -eq 1 && ${BACKUP_RETENTION_KEEP_MONTHLY} -gt 0 ]]; then
      ## On first month day do
      backup_file="${backup_type}_files-${NOW}-monthly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
      old_backup_file="${backup_type}_files-${MONTHSAGO}-monthly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
    else
      ## On saturdays do
      if [[ ${WEEK_DAY} -eq 6 && ${BACKUP_RETENTION_KEEP_WEEKLY} -gt 0 ]]; then
        backup_file="${backup_type}_files-${NOW}-weekly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
        old_backup_file="${backup_type}_files-${WEEKSAGO}-weekly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
      else
        ## On any regular day do
        backup_file="${backup_type}_files-${NOW}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
        old_backup_file="${backup_type}_files-${DAYSAGO}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
      fi
    fi

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

      log_event "info" "Making ${BACKUP_CONFIG_COMPRESSION_EXTENSION} from: ${MAILCOW_DIR}/${MAILCOW_BACKUP_LOCATION} ..." "false"

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

        # New folder with $SERVER_NAME
        storage_create_dir "${SERVER_NAME}"
        storage_create_dir "${SERVER_NAME}/${backup_type}"

        storage_path="/${SERVER_NAME}/projects-online/${backup_type}"

        # Upload new backup
        storage_upload_backup "${MAILCOW_TMP_BK}/${backup_file}" "${storage_path}"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          # Remove old backup
          storage_delete_backup "${storage_path}/${old_backup_file}" "false"

          # Remove old backups from server
          rm --recursive --force "${MAILCOW_DIR}/${MAILCOW_BACKUP_LOCATION:?}"
          rm --recursive --force "${MAILCOW_TMP_BK}/${backup_file:?}"

          log_event "info" "Mailcow backup finished" "false"

        fi

      fi

    else

      log_event "error" "Can't make the backup!" "false"

      return 1

    fi

  else

    log_event "error" "Directory '${MAILCOW_DIR}' doesnt exists!" "false"

    return 1

  fi

  log_break "true"

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

function backup_all_projects_files() {

  local backup_file_size
  local directory_name
  local working_sites_directories

  local backuped_files_index=0
  local backuped_directory_index=0

  log_subsection "Backup Sites Files"

  # Get all directories
  working_sites_directories="$(get_all_directories "${PROJECTS_PATH}")"

  # Get length of ${working_sites_directories}
  COUNT_TOTAL_SITES="$(find "${PROJECTS_PATH}" -maxdepth 1 -type d -printf '.' | wc -c)"
  COUNT_TOTAL_SITES="$((COUNT_TOTAL_SITES - 1))"

  # Log
  display --indent 6 --text "- Directories found" --result "${COUNT_TOTAL_SITES}" --color WHITE
  log_event "info" "Found ${COUNT_TOTAL_SITES} directories" "false"
  log_break "true"

  for j in ${working_sites_directories}; do

    directory_name="$(basename "${j}")"

    log_event "info" "Processing [${directory_name}] ..." "false"

    project_is_ignored "${directory_name}"

    result=$?
    if [[ ${result} -eq 0 ]]; then

      backup_file_size="$(backup_project_files "site" "${PROJECTS_PATH}" "${directory_name}")"

      if [[ -n ${backup_file_size} ]]; then

        backuped_files_list[$backuped_files_index]="${directory_name}"
        backuped_files_sizes_list+=("${backup_file_size}")
        backuped_files_index=$((backuped_files_index + 1))

      else

        ERROR=true
        ERROR_MSG="Error creating backup file for site: ${directory_name}"
        #log_event "error" "${ERROR_MSG}" "false"

      fi

    else

      # Log
      log_event "info" "Omitting ${directory_name} (blacklisted) ..." "false"
      display --indent 6 --text "- Ommiting excluded directory" --result "DONE" --color WHITE
      display --indent 8 --text "${directory_name}" --tcolor WHITE

    fi

    log_break "true"

    backuped_directory_index=$((backuped_directory_index + 1))

    log_event "info" "Processed ${backuped_directory_index} of ${COUNT_TOTAL_SITES} directories" "false"

  done

  # Deleting old backup files
  rm --recursive --force "${BROLIT_TMP_DIR:?}/${NOW}"

  # DUPLICITY
  backup_duplicity

  # Configure Files Backup Section for Email Notification
  mail_files_backup_section "${ERROR}" "${ERROR_MSG}" "${backuped_files_list[@]}" "${backuped_files_sizes_list[@]}"

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

function backup_all_files() {

  ## MAILCOW FILES
  if [[ ${MAILCOW_BK} == true ]]; then

    if [[ ! -d ${MAILCOW_TMP_BK} ]]; then

      log_event "info" "Folder ${MAILCOW_TMP_BK} doesn't exist. Creating now ..." "false"

      mkdir -p "${MAILCOW_TMP_BK}"

    fi

    backup_mailcow "${MAILCOW}"

  fi

  ## SERVER CONFIG FILES
  backup_all_server_configs

  ## PROJECTS_PATH FILES
  backup_all_projects_files

}

################################################################################
# Make files Backup
#
# Arguments:
#  $1 = ${backup_type} - Backup Type (site_configs or sites)
#  $2 = ${backup_path} - Path where directories to backup are stored
#  $3 = ${directory_to_backup} - The specific folder/file to backup
#
# Outputs:
#  0 if ok, 1 if error
################################################################################

function backup_project_files() {

  local backup_type="${1}"
  local backup_path="${2}"
  local directory_to_backup="${3}"

  local backup_file
  local old_backup_file
  local storage_path
  local exclude_parameters

  # Backups file names
  if [[ ${MONTH_DAY} -eq 1 && ${BACKUP_RETENTION_KEEP_MONTHLY} -gt 0 ]]; then
    ## On first month day do
    backup_file="${directory_to_backup}_${backup_type}-files_${NOW}-monthly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
    old_backup_file="${directory_to_backup}_${backup_type}-files_${MONTHSAGO}-monthly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
  else
    ## On saturdays do
    if [[ ${WEEK_DAY} -eq 6 && ${BACKUP_RETENTION_KEEP_WEEKLY} -gt 0 ]]; then
      backup_file="${directory_to_backup}_${backup_type}-files_${NOW}-weekly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
      old_backup_file="${directory_to_backup}_${backup_type}-files_${WEEKSAGO}-weekly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
    else
      ## On any regular day do
      backup_file="${directory_to_backup}_${backup_type}-files_${NOW}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
      old_backup_file="${directory_to_backup}_${backup_type}-files_${DAYSAGO}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
    fi
  fi

  # Create directory structure
  storage_create_dir "${SERVER_NAME}"
  storage_create_dir "${SERVER_NAME}/projects-online"
  storage_create_dir "${SERVER_NAME}/projects-online/${backup_type}"
  storage_create_dir "${SERVER_NAME}/projects-online/${backup_type}/${directory_to_backup}"

  remote_path="${SERVER_NAME}/projects-online/${backup_type}/${directory_to_backup}"

  if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" || ${BACKUP_SFTP_STATUS} == "enabled" ]]; then

    # Log
    display --indent 6 --text "- Files backup for ${YELLOW}${directory_to_backup}${ENDCOLOR}"
    log_event "info" "Files backup for : ${directory_to_backup}" "false"

    # Excluding files/directories from TAR
    exclude_parameters=""
    # String to Array
    excluded_files_list="$(string_remove_spaces "${EXCLUDED_FILES_LIST}")"
    excluded_files_list="$(echo "${excluded_files_list}" | tr '\n' ',')"
    IFS="," read -a excluded_array <<<"${excluded_files_list}"
    for i in "${excluded_array[@]}"; do
      :
      exclude_parameters="${exclude_parameters} --exclude='${i}'"
    done

    # Compress backup
    backup_file_size="$(compress "${backup_path}" "${directory_to_backup}" "${BROLIT_TMP_DIR}/${NOW}/${backup_file}" "${exclude_parameters}")"

    # Check test result
    compress_result=$?
    if [[ ${compress_result} -eq 0 ]]; then

      # Log
      clear_previous_lines "1"
      display --indent 6 --text "- Files backup for ${YELLOW}${directory_to_backup}${ENDCOLOR}" --result "DONE" --color GREEN
      display --indent 8 --text "Final backup size: ${YELLOW}${backup_file_size}${ENDCOLOR}"

      log_event "info" "Backup ${BROLIT_TMP_DIR}/${NOW}/${backup_file} created, final size: ${backup_file_size}" "false"

      # Upload backup
      storage_upload_backup "${BROLIT_TMP_DIR}/${NOW}/${backup_file}" "${remote_path}"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Delete old backup from Dropbox
        storage_delete_backup "${remote_path}/${old_backup_file}"

        # Delete temp backup
        rm --force "${BROLIT_TMP_DIR}/${NOW}/${backup_file}"

        # Log
        log_event "info" "Temp backup deleted from server" "false"

        # Return
        echo "${backup_file_size}"

      fi

    else

      # Log
      clear_previous_lines "1"
      display --indent 6 --text "- Files backup for ${directory_to_backup}" --result "FAIL" --color RED

      return 1

    fi

  fi

  if [[ ${BACKUP_LOCAL_STATUS} == "enabled" ]]; then

    storage_upload_backup "${backup_path}/${directory_to_backup}" "${remote_path}"

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

function backup_duplicity() {

  if [[ ${BACKUP_DUPLICITY_STATUS} == "enabled" ]]; then

    log_event "warning" "duplicity backup is in BETA state" "true"

    # Check if DUPLICITY is installed
    package_install_if_not "duplicity"

    # Get all directories
    all_sites="$(get_all_directories "${PROJECTS_PATH}")"

    # Loop in to Directories
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

function backup_all_databases() {

  local got_error
  local error_msg
  local error_type
  local database_backup_index

  # Starting Messages
  log_subsection "Backup Databases"

  if [[ ${PACKAGES_MARIADB_STATUS} != "enabled" ]] && [[ ${PACKAGES_MYSQL_STATUS} != "enabled" ]] && [[ ${PACKAGES_POSTGRES_STATUS} != "enabled" ]]; then

    display --indent 6 --text "- Initializing database backup script" --result "SKIPPED" --color YELLOW
    display --indent 8 --text "No database engine present on server" --tcolor YELLOW
    return 1

  fi

  display --indent 6 --text "- Initializing database backup script" --result "DONE" --color GREEN

  if [[ ${PACKAGES_MARIADB_STATUS} == "enabled" ]] || [[ ${PACKAGES_MYSQL_STATUS} == "enabled" ]]; then

    # Get MySQL DBS
    mysql_databases="$(mysql_list_databases "all")"

    # Count MySQL databases
    databases_count="$(mysql_count_databases "${mysql_databases}")"

    # Log
    display --indent 6 --text "- MySql databases found" --result "${databases_count}" --color WHITE
    log_event "info" "MySql databases found: ${databases_count}" "false"
    log_break "true"

    # Loop in to MySQL Databases and make backup
    backup_databases "${mysql_databases}" "mysql"

    backup_databases_status=$?
    if [[ ${backup_databases_status} -eq 1 ]]; then

      got_error="true"
      error_msg="${error_msg}${error_msg:+\n}MySQL backup failed"
      error_type="${error_type}${error_type:+\n}MySQL"

    fi

  fi

  if [[ ${PACKAGES_POSTGRES_STATUS} == "enabled" ]]; then

    # Get PostgreSQL DBS
    psql_databases="$(postgres_list_databases "all")"

    # Count PostgreSQL databases
    databases_count="$(postgres_count_databases "${psql_databases}")"

    # Log
    display --indent 6 --text "- PSql databases found" --result "${databases_count}" --color WHITE
    log_event "info" "PSql databases found: ${databases_count}" "false"
    log_break "true"

    # Loop in to PostgreSQL Databases and make backup
    backup_databases "${psql_databases}" "psql"

    backup_databases_status=$?
    if [[ ${backup_databases_status} -eq 1 ]]; then

      got_error="true"
      error_msg="${error_msg}${error_msg:+\n}PostgreSQL backup failed"
      error_type="${error_type}${error_type:+\n}PostgreSQL"

    fi

  fi

  return 0

}

################################################################################
# Make databases backup
#
# Arguments:
#  $1 = ${databases}
#  $2 = ${db_engine}
#
# Outputs:
#  0 if ok, 1 if error
################################################################################

function backup_databases() {

  local databases="${1}"
  local db_engine="${2}"

  local got_error=0
  local database_backup_index=0

  for database in ${databases}; do

    if [[ ${EXCLUDED_DATABASES_LIST} != *"${database}"* ]]; then

      log_event "info" "Processing [${database}] ..." "false"

      # Make database backup
      backup_file="$(backup_project_database "${database}" "${db_engine}")"

      if [[ ${backup_file} != "" ]]; then

        # Extract parameters from ${backup_file}
        database_backup_path="$(echo "${backup_file}" | cut -d ";" -f 1)"
        database_backup_size="$(echo "${backup_file}" | cut -d ";" -f 2)"

        database_backup_file="$(basename "${database_backup_path}")"

        backuped_databases_list[$database_backup_index]="${database_backup_file}"
        backuped_databases_sizes_list+=("${database_backup_size}")

        database_backup_index=$((database_backup_index + 1))

        log_event "info" "Backup ${database_backup_index} of ${databases_count} done" "false"

      else

        #error_type=""
        got_error=1

        log_event "error" "Something went wrong making a backup of ${database}." "false"

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
  return ${got_error}

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

function backup_project_database() {

  local database="${1}"
  local db_engine="${2}"

  local export_result

  local dump_file
  local backup_file

  log_event "info" "Creating new database backup of '${database}'" "false"

  # Backups file names
  if [[ ${MONTH_DAY} -eq 1 && ${BACKUP_RETENTION_KEEP_MONTHLY} -gt 0 ]]; then
    ## On first month day do
    dump_file="${database}_database_${NOW}-monthly.sql"
    backup_file="${database}_database_${NOW}-monthly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
    old_backup_file="${database}_database_${MONTHSAGO}-monthly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
  else
    ## On saturdays do
    if [[ ${WEEK_DAY} -eq 6 && ${BACKUP_RETENTION_KEEP_WEEKLY} -gt 0 ]]; then
      dump_file="${database}_database_${NOW}-weekly.sql"
      backup_file="${database}_database_${NOW}-weekly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
      old_backup_file="${database}_database_${WEEKSAGO}-weekly.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
    else
      ## On any regular day do
      dump_file="${database}_database_${NOW}.sql"
      backup_file="${database}_database_${NOW}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
      old_backup_file="${database}_database_${DAYSAGO}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
    fi
  fi

  # Database engine
  if [[ ${db_engine} == "mysql" ]]; then
    ## Create dump file
    mysql_database_export "${database}" "${BROLIT_TMP_DIR}/${NOW}/${dump_file}"
  else

    if [[ ${db_engine} == "psql" ]]; then
      ## Create dump file
      postgres_database_export "${database}" "${BROLIT_TMP_DIR}/${NOW}/${dump_file}"
    fi

  fi

  export_result=$?
  if [[ ${export_result} -eq 0 ]]; then

    # Compress backup
    backup_file_size="$(compress "${BROLIT_TMP_DIR}/${NOW}/" "${dump_file}" "${BROLIT_TMP_DIR}/${NOW}/${backup_file}" "")"

    # Check test result
    compress_result=$?
    if [[ ${compress_result} -eq 0 ]]; then

      # Log
      display --indent 8 --text "Final backup size: ${YELLOW}${backup_file_size}${ENDCOLOR}"

      # Create dir structure
      storage_create_dir "/${SERVER_NAME}/projects-online"
      storage_create_dir "/${SERVER_NAME}/projects-online/database"
      storage_create_dir "/${SERVER_NAME}/projects-online/database/${database}"

      # Upload database backup
      storage_upload_backup "${BROLIT_TMP_DIR}/${NOW}/${backup_file}" "/${SERVER_NAME}/projects-online/database/${database}"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Delete old backup from storage
        storage_delete_backup "/${SERVER_NAME}/projects-online/database/${database}/${old_backup_file}"

        # Delete local temp files
        rm --force "${BROLIT_TMP_DIR}/${NOW}/${dump_file}"
        rm --force "${BROLIT_TMP_DIR}/${NOW}/${backup_file}"

        # Return
        ## output format: backupfile backup_file_size
        #echo "${BROLIT_TMP_DIR}/${NOW}/${backup_file};${backup_file_size}"
        echo "${backup_file};${backup_file_size}"

        return 0

      fi

    else

      return 1

    fi

  else

    ERROR=true
    ERROR_MSG="Error creating dump file for database: ${database}"
    log_event "error" "${ERROR_MSG}" "false"

    return 1

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

function backup_project() {

  local project_domain="${1}"
  local backup_type="${2}"

  local project_name
  local project_config_file

  # Backup files
  backup_file_size="$(backup_project_files "site" "${PROJECTS_PATH}" "${project_domain}")"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # TODO: Check others project types

    log_event "info" "Trying to get database name from project ..." "false"

    project_name="$(project_get_name_from_domain "${project_domain}")"

    project_config_file="${BROLIT_CONFIG_PATH}/${project_name}_conf.json"

    if [[ -f "${project_config_file}" ]]; then

      project_type="$(project_get_brolit_config_var "${project_config_file}" "project[].type")"
      db_name="$(project_get_configured_database "${BROLIT_TMP_DIR}/${project_name}" "${project_type}")"
      db_engine="$(project_get_configured_database_engine "${BROLIT_TMP_DIR}/${project_name}" "${project_type}")"

    else

      #db_engine="$(project_get_configured_database_engine "${BROLIT_TMP_DIR}/${project_name}" "${project_type}")"
      db_stage="$(project_get_stage_from_domain "${project_domain}")"
      db_name="$(project_get_name_from_domain "${project_domain}")"
      db_name="${db_name}_${db_stage}"

    fi

    # TODO: check database engine
    mysql_database_exists "${db_name}"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Backup database
      backup_project_database "${db_name}" "mysql"

    else

      # Log
      log_event "info" "Database ${db_name} not found" "false"
      display --indent 6 --text "Database backup" --result "SKIPPED" --color YELLOW
      display --indent 8 --text "Database ${db_name} not found" --tcolor YELLOW

    fi

    # Delete backup from server
    rm --recursive --force "${BROLIT_TMP_DIR}/${NOW}/${backup_type:?}"

    # Log
    #log_event "info" "Deleting backup from server ..." "false"
    log_event "info" "Project backup done" "false"

  else

    ERROR=true
    log_event "error" "Something went wrong making a project backup" "false"

  fi

}
