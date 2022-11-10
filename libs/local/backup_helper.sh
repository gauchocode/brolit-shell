#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.6
#############################################################################
#
# Backup Helper: Perform backup actions.
#
################################################################################

################################################################################
# Get Backup filename
#
# Arguments:
#  $1 = ${backup_prefix_name}
#
# Outputs:
#   ${backup_filename}
################################################################################

function backup_get_filename() {

  local backup_prefix_name="${1}"
  local backup_date="${2}"
  local backup_extension="${3}"

  local daysago
  local backup_file
  local backup_file_old
  local backup_keep_daily
  local daysago

  # Backups file names
  if [[ $((10#$MONTH_DAY)) -eq 1 && $((10#$BACKUP_RETENTION_KEEP_MONTHLY)) -gt 0 ]]; then
    ## On first month day do
    backup_file="${backup_prefix_name}_${NOW}-monthly.${backup_extension}"
    backup_file_old="${backup_prefix_name}_${MONTHSAGO}-monthly.${backup_extension}"
  else
    ## On saturdays do
    if [[ $((10#$WEEK_DAY)) -eq 6 && $((10#$BACKUP_RETENTION_KEEP_WEEKLY)) -gt 0 ]]; then
      backup_file="${backup_prefix_name}_${NOW}-weekly.${backup_extension}"
      backup_file_old="${backup_prefix_name}_${WEEKSAGO}-weekly.${backup_extension}"
    else
      if [[ $((10#$WEEK_DAY)) -eq 7 && $((10#$BACKUP_RETENTION_KEEP_WEEKLY)) -gt 0 ||
        $((10#$MONTH_DAY)) -eq 2 && $((10#$BACKUP_RETENTION_KEEP_MONTHLY)) -gt 0 ]]; then
        ## The day after a week day or month day
        backup_keep_daily=$((BACKUP_RETENTION_KEEP_DAILY - 1))
        daysago="$(date --date="${backup_keep_daily} days ago" +"%Y-%m-%d")"
        backup_file="${backup_prefix_name}_${NOW}.${backup_extension}"
        backup_file_old="${backup_prefix_name}_${daysago}.${backup_extension}"
      else
        ## On any regular day do
        backup_file="${backup_prefix_name}_${NOW}.${backup_extension}"
        backup_file_old="${backup_prefix_name}_${DAYSAGO}.${backup_extension}"
      fi
    fi
  fi

  log_event "debug" "backup_get_filename: backup_file=${backup_file}" "false"
  log_event "debug" "backup_get_filename: backup_file_old=${backup_file_old}" "false"

  # Return
  if [[ ${backup_date} == "old" ]]; then
    echo "${backup_file_old}"
  else
    echo "${backup_file}"
  fi

}

################################################################################
# Get backup Date
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
# Get backup rotation type (daily, weekly, monthtly)
#
# Arguments:
#  $1 = ${backup_file}
#
# Outputs:
#   ${backup_rotation_type}
################################################################################

function backup_get_rotation_type() {

  local backup_file="${1}"

  local backup_weekly
  local backup_monthly

  backup_weekly="$(echo "${backup_file}" | grep 'weekly')"
  [[ -n ${backup_weekly} ]] && echo "weekly" && return 0

  backup_monthly="$(echo "${backup_file}" | grep 'monthly')"
  [[ -n ${backup_monthly} ]] && echo "monthly" && return 0

  # Or daily
  echo "daily" && return 0

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

  local backup_type="${1}"
  local bk_sup_type="${2}"
  local backup_path="${3}"
  local directory_to_backup="${4}"

  local backup_file
  local backup_file_old
  local daysago
  local remote_path
  local backup_keep_daily
  local upload_result

  if [[ -n ${backup_path} ]]; then

    backup_prefix_name="${bk_sup_type}-${backup_type}-files"
    backup_file="$(backup_get_filename "${backup_prefix_name}" "actual" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")"
    backup_file_old="$(backup_get_filename "${backup_prefix_name}" "old" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")"

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
      upload_result="$(storage_upload_backup "${BROLIT_TMP_DIR}/${NOW}/${backup_file}" "${remote_path}")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Deleting old backup file
        storage_delete_backup "${remote_path}/${backup_file_old}"

        # Deleting tmp backup file
        rm --force "${BROLIT_TMP_DIR}/${NOW}/${backup_file}"

        # Return
        echo "${backup_file_size}" && return 0

      else

        # Log
        log_event "debug" "storage_upload_backup return: ${upload_result}" "false"

        # Error
        #got_error=1
        error_type="upload_error"
        error_msg="Error running storage upload backup on: ${upload_result}."

        # Return
        echo "${error_type};${error_msg}" && return 1

      fi

    else

      # Log
      clear_previous_lines "1"
      display --indent 6 --text "- Files backup for ${YELLOW}${bk_sup_type}${ENDCOLOR}" --result "FAIL" --color RED

      # Error
      #got_error=1
      error_type="compress_error"
      error_msg="Something went wrong making a backup of ${directory_to_backup}."

      # Return
      echo "${error_type};${error_msg}" && return 1

    fi

  else

    log_event "error" "Directory ${backup_path} doesn't exists." "false"

    display --indent 6 --text "- Creating backup file" --result "FAIL" --color RED
    display --indent 8 --text "Result: Directory '${backup_path}' doesn't exists" --tcolor RED

    # Error
    #got_error=1
    error_type="directory_error"
    error_msg="Directory ${backup_path} doesn't exists."

    # Return
    echo "${error_type};${error_msg}" && return 1

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
# TODO: needs refactor
function backup_all_server_configs() {

  #local -n backuped_config_list

  local directory_name
  local directory_path

  local backuped_config_index=0

  local got_error=0
  local error_msg="none"
  local error_type="none"

  log_subsection "Backup Server Config"

  # TAR Webserver config files
  if [[ -d ${WSERVER} ]]; then

    directory_name="$(basename "${WSERVER}")"
    directory_path="$(dirname "${WSERVER}")"

    nginx_files_backup_result="$(backup_server_config "configs" "nginx" "${directory_path}" "${directory_name}")"

    backuped_config_list[$backuped_config_index]="${WSERVER};${nginx_files_backup_result}"
    backuped_config_index=$((backuped_config_index + 1))

  fi

  # TAR PHP config files
  if [[ -d ${PHP_CONF_DIR} ]]; then

    log_break "true"

    directory_name="$(basename "${PHP_CONF_DIR}")"
    directory_path="$(dirname "${PHP_CONF_DIR}")"

    php_files_backup_result="$(backup_server_config "configs" "php" "${directory_path}" "${directory_name}")"

    backuped_config_list[$backuped_config_index]="${PHP_CONF_DIR};${php_files_backup_result}"
    backuped_config_index=$((backuped_config_index + 1))

  fi

  # TAR MySQL config files
  if [[ -d ${MYSQL_CONF_DIR} ]]; then

    log_break "true"

    directory_name="$(basename "${MYSQL_CONF_DIR}")"
    directory_path="$(dirname "${MYSQL_CONF_DIR}")"

    mysql_files_backup_result="$(backup_server_config "configs" "mysql" "${directory_path}" "${directory_name}")"

    backuped_config_list[$backuped_config_index]="${MYSQL_CONF_DIR};${mysql_files_backup_result}"
    backuped_config_index=$((backuped_config_index + 1))

  fi

  # TAR Let's Encrypt config files
  if [[ -d ${LENCRYPT_CONF_DIR} ]]; then

    log_break "true"

    directory_name="$(basename "${LENCRYPT_CONF_DIR}")"
    directory_path="$(dirname "${LENCRYPT_CONF_DIR}")"

    le_files_backup_result="$(backup_server_config "configs" "letsencrypt" "${directory_path}" "${directory_name}")"

    backuped_config_list[$backuped_config_index]="${LENCRYPT_CONF_DIR};${le_files_backup_result}"
    backuped_config_index=$((backuped_config_index + 1))

  fi

  # TAR Brolit config files
  if [[ -d ${BROLIT_CONFIG_PATH} ]]; then

    log_break "true"

    directory_name="$(basename "${BROLIT_CONFIG_PATH}")"
    directory_path="$(dirname "${BROLIT_CONFIG_PATH}")"

    brolit_files_backup_result="$(backup_server_config "configs" "brolit" "${directory_path}" "${directory_name}")"

    #exitstatus=$?
    #if [[ ${exitstatus} -eq 0 ]]; then
    backuped_config_list[$backuped_config_index]="${BROLIT_CONFIG_PATH};${brolit_files_backup_result}"
    backuped_config_index=$((backuped_config_index + 1))
    #else
    #  error_type="$(echo "${brolit_files_backup_result}" | cut -d ";" -f 1)"
    #  error_msg="$(echo "${brolit_files_backup_result}" | cut -d ";" -f 2)"
    #fi

  fi

  # Configure Files Backup Section for Email Notification
  mail_backup_section "${error_msg}" "${error_type}" "configuration" "${backuped_config_list[@]}"

  # Return
  echo "${ERROR}" && return ${got_error}

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
  local backup_prefix_name
  local backup_file
  local backup_file_old

  log_subsection "Mailcow Backup"

  if [[ -n ${MAILCOW_DIR} ]]; then

    backup_prefix_name="${backup_type}-files"
    backup_file="$(backup_get_filename "${backup_prefix_name}" "actual" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")"
    backup_file_old="$(backup_get_filename "${backup_prefix_name}" "old" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")"

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

        # New folder with ${SERVER_NAME}
        storage_create_dir "${SERVER_NAME}"
        storage_create_dir "${SERVER_NAME}/${backup_type}"

        storage_path="/${SERVER_NAME}/projects-online/${backup_type}"

        # Upload new backup
        upload_result="$(storage_upload_backup "${MAILCOW_TMP_BK}/${backup_file}" "${storage_path}")"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          # Remove old backup
          storage_delete_backup "${storage_path}/${backup_file_old}" "false"

          # Remove old backups from server
          rm --recursive --force "${MAILCOW_DIR}/${MAILCOW_BACKUP_LOCATION:?}"
          rm --recursive --force "${MAILCOW_TMP_BK}/${backup_file:?}"

          log_event "info" "Mailcow backup finished" "false"

        fi

      fi

    else

      log_event "error" "Can't make the backup!" "false" &&
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

  local got_error=0
  local error_msg="none"
  local error_type="none"

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

    if [[ "$(project_is_ignored "${directory_name}")" == "false" ]]; then

      backup_file_size="$(backup_project_files "site" "${PROJECTS_PATH}" "${directory_name}")"

      if [[ -n ${backup_file_size} ]]; then

        # I'm using only an array, because passing two arrays to a function could be a problem (bash)
        backuped_files_list[$backuped_files_index]="${directory_name};${backup_file_size}"
        backuped_files_index=$((backuped_files_index + 1))

      else

        got_error=1
        error_type="files_backup"
        error_msg="Error creating backup file for site: ${directory_name}"

      fi

    else

      # Log
      log_event "info" "Omitting ${directory_name} (blacklisted) ..." "false"
      display --indent 6 --text "- Ommiting excluded directory" --result "DONE" --color WHITE
      display --indent 8 --text "${directory_name}" --tcolor WHITE

    fi

    # Log
    log_break "true"
    log_event "info" "Processed ${backuped_directory_index} of ${COUNT_TOTAL_SITES} directories" "false"

    backuped_directory_index=$((backuped_directory_index + 1))

  done

  # Deleting old backup files
  rm --recursive --force "${BROLIT_TMP_DIR:?}/${NOW}"

  # DUPLICITY
  backup_duplicity

  # Configure Files Backup Section for Email Notification
  mail_backup_section "${error_msg}" "${error_type}" "files" "${backuped_files_list[@]}"

  return ${got_error}

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

  ## SERVER CONFIG FILES
  backup_all_server_configs

  ## PROJECTS FILES
  backup_all_projects_files

  ## ADDITIONAL DIRS
  backup_additional_dirs

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
  local backup_file_old
  local backup_prefix_name
  local storage_path
  local exclude_parameters

  # Backups file names
  backup_prefix_name="${directory_to_backup}_${backup_type}-files"
  backup_file="$(backup_get_filename "${backup_prefix_name}" "actual" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")"
  backup_file_old="$(backup_get_filename "${backup_prefix_name}" "old" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")"

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
      upload_result="$(storage_upload_backup "${BROLIT_TMP_DIR}/${NOW}/${backup_file}" "${remote_path}")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Delete old backup from Dropbox
        storage_delete_backup "${remote_path}/${backup_file_old}"

        # Delete temp backup
        rm --force "${BROLIT_TMP_DIR}/${NOW}/${backup_file}"

        # Log
        log_event "info" "Temp backup deleted from server" "false"

        # Return
        echo "${backup_file_size}" && return 0

      fi

    else

      # Log
      clear_previous_lines "1"
      display --indent 6 --text "- Files backup for ${directory_to_backup}" --result "FAIL" --color RED

      return 1

    fi

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

  # Mysql backup
  if [[ ${PACKAGES_MARIADB_STATUS} == "enabled" ]] || [[ ${PACKAGES_MYSQL_STATUS} == "enabled" ]]; then

    # Get MySQL databases
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

      error_type="${error_type}${error_type:+\n}MySQL"
      error_msg="${error_msg}${error_msg:+\n}MySQL backup failed"

    fi

  fi

  # Postgres backup
  if [[ ${PACKAGES_POSTGRES_STATUS} == "enabled" ]]; then

    # Get PostgreSQL databases
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

      error_type="${error_type}${error_type:+\n}PostgreSQL"
      error_msg="${error_msg}${error_msg:+\n}PostgreSQL backup failed"

    fi

  fi

  [[ -n ${error_type} ]] && echo "${error_type}" && return 1

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

  local database_backup_index=0

  local got_error=0
  local error_msg="none"
  local error_type="none"

  for database in ${databases}; do

    if [[ ${EXCLUDED_DATABASES_LIST} != *"${database}"* ]]; then

      log_event "info" "Processing [${database}] ..." "false"

      # Make database backup
      backup_project_database_output="$(backup_project_database "${database}" "${db_engine}")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Extract parameters from ${backup_project_database_output}
        database_backup_path="$(echo "${backup_project_database_output}" | cut -d ";" -f 1)"
        database_backup_size="$(echo "${backup_project_database_output}" | cut -d ";" -f 2)"

        database_backup_file="$(basename "${database_backup_path}")"

        backuped_databases_list[$database_backup_index]="${database_backup_file};${database_backup_size}"

        database_backup_index=$((database_backup_index + 1))

        log_event "info" "Backup ${database_backup_index} of ${databases_count} done" "false"

      else

        got_error=1
        error_type="database_backup"

        log_event "error" "Something went wrong making a backup of ${database}." "false"
        log_event "debug" "backup_project_database result: ${backup_project_database_output}." "false"

      fi

    else

      display --indent 6 --text "- Ommiting database ${database}" --result "DONE" --color WHITE
      log_event "info" "Ommiting blacklisted database: ${database}" "false"

    fi

    log_break "true"

  done

  # Configure Email
  mail_backup_section "${error_msg}" "${error_type}" "databases" "${backuped_databases_list[@]}"

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
  local backup_file_old

  local error_type
  local error_msg

  log_event "info" "Creating new database backup of '${database}'" "false"

  # Backups file names
  backup_prefix_name="${database}_database"
  dump_file="$(backup_get_filename "${backup_prefix_name}" "actual" "sql")"
  backup_file="$(backup_get_filename "${backup_prefix_name}" "actual" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")"
  backup_file_old="$(backup_get_filename "${backup_prefix_name}" "old" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")"

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
      remote_path="/${SERVER_NAME}/projects-online/database/${database}"
      upload_result="$(storage_upload_backup "${BROLIT_TMP_DIR}/${NOW}/${backup_file}" "${remote_path}")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Delete old backup from storage
        storage_delete_backup "/${SERVER_NAME}/projects-online/database/${database}/${backup_file_old}"

        # Delete local temp files
        rm --force "${BROLIT_TMP_DIR}/${NOW}/${dump_file}"
        rm --force "${BROLIT_TMP_DIR}/${NOW}/${backup_file}"

        # Return
        echo "${backup_file};${backup_file_size}" && return 0

      else

        error_type="upload_backup"
        error_msg="Error uploading file: ${backup_file}. Upload result: ${upload_result}"

        log_event "error" "${error_msg}" "false"

        # Return
        echo "${backup_file};${error_type};${error_msg}" && return 1

      fi

    else

      error_type="compress_backup"
      error_msg="Error compressing file: ${dump_file}"

      # Return
      echo "${backup_file};${error_type};${error_msg}" && return 1

    fi

  else

    error_type="export_database"
    error_msg="Error creating dump file for database: ${database}"

    # Return
    echo "${backup_file};${error_type};${error_msg}" && return 1

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

  local got_error=0

  local db_stage
  local db_name
  local db_engine
  local backup_file
  local project_type

  # Backup files
  log_subsection "Backup Project Files"
  backup_file_size="$(backup_project_files "site" "${PROJECTS_PATH}" "${project_domain}")"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Project Type
    project_type="$(project_get_type "${PROJECTS_PATH}/${project_domain}")"

    # Project install type
    project_install_type="$(project_get_install_type "${PROJECTS_PATH}/${project_domain}")"

    # If ${project_install_type} == docker -> docker_mysql_database_backup ?
    # Should consider the case where a project is dockerized but uses an external database?
    if [[ ${project_install_type} == "default" && ${project_type} != "html" ]]; then

      log_event "info" "Trying to get database name from project config file..." "false"

      db_name="$(project_get_configured_database "${PROJECTS_PATH}/${project_domain}" "${project_type}" "${project_install_type}")"
      db_engine="$(project_get_configured_database_engine "${PROJECTS_PATH}/${project_domain}" "${project_type}" "${project_install_type}")"

      if [[ -z "${db_name}" ]]; then

        log_event "warning" "Trying to get database name from convention name..." "false"

        db_stage="$(project_get_stage_from_domain "${project_domain}")"
        db_name="$(project_get_name_from_domain "${project_domain}")"
        db_name="${db_name}_${db_stage}"

      fi

      if [[ -z "${db_engine}" ]]; then

        # Check on Mysql
        [[ $(mysql_database_exists "${db_name}") -eq 0 ]] && db_engine="mysql"
        # Check on Postgres
        [[ $(postgres_database_exists "${db_name}") -eq 0 ]] && db_engine="postgres"

      fi

      if [[ "${db_engine}" == "mysql" ]]; then

        # Backup database
        log_subsection "Backup Project Database"
        backup_file="$(backup_project_database "${db_name}" "mysql")"
        got_error=$?

      else

        if [[ "${db_engine}" == "postgres" ]]; then

          # Backup database
          log_subsection "Backup Project Database"
          backup_file="$(backup_project_database "${db_name}" "postgres")"
          got_error=$?

        fi

      fi

    fi

    log_break

    # Delete backup from server
    rm --recursive --force "${BROLIT_TMP_DIR}/${NOW}/${backup_type:?}"
    #log_event "info" "Deleting backup from server ..." "false"

    # Log
    log_event "info" "Project Backup done" "false"
    display --indent 6 --text " - Project Backup" --result "DONE" --color GREEN

    return ${got_error}

  else

    # Log
    log_event "error" "Something went wrong making the files backup" "false"
    display --indent 6 --text " - Project Backup" --result "FAIL" --color RED
    display --indent 8 --text "Something went wrong making the files backup" --tcolor RED

    return 1

  fi

}

################################################################################
# Make additional directories Backup
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 if error
################################################################################

function backup_additional_dirs() {

  local backup_file_size
  local directory_name
  local directory_path
  local working_sites_directories

  local count_total_dirs=0
  local backuped_files_index=0
  local backuped_directory_index=0

  local got_error=0
  local error_msg="none"
  local error_type="none"

  log_subsection "Backup Additional Directories"

  # Get all directories
  working_sites_directories="${BACKUP_CONFIG_ADDITIONAL_DIRS}"

  # Get length of ${working_sites_directories}
  count_total_dirs="$(wc -w <<<"$working_sites_directories")"

  # Log
  display --indent 6 --text "- Directories found" --result "${count_total_dirs}" --color WHITE
  log_event "info" "Found ${count_total_dirs} directories" "false"
  log_break "true"

  # Creating tmp dir
  mkdir -p "${BROLIT_TMP_DIR}/${NOW}"

  for j in ${working_sites_directories}; do

    directory_name="$(basename "${j}")"
    directory_path="$(dirname "${j}")"

    log_event "info" "Processing [${directory_name}] ..." "false"

    backup_file_size="$(backup_project_files "other" "${directory_path}" "${directory_name}")"

    if [[ -n ${backup_file_size} ]]; then

      backuped_files_list[$backuped_files_index]="${directory_name};${backup_file_size}"
      backuped_files_index=$((backuped_files_index + 1))

    else

      got_error=1
      error_type="files_backup"
      error_msg="Error creating backup file for site: ${directory_name}"

    fi

    log_break "true"
    log_event "info" "Processed ${backuped_directory_index} of ${count_total_dirs} directories" "false"

    backuped_directory_index=$((backuped_directory_index + 1))

  done

  # Deleting old backup files
  rm --recursive --force "${BROLIT_TMP_DIR:?}/${NOW}"

  # Configure Files Backup Section for Email Notification
  mail_backup_section "${error_msg}" "${error_type}" "files" "${backuped_files_list[@]}"

  return ${got_error}

}
