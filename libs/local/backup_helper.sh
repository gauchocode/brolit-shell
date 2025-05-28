#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.10
#############################################################################
#
# Backup Helper: Perform backup actions.
#
################################################################################

################################################################################
# Get Backup filename
#
# Arguments:
#  ${1} = ${backup_prefix_name}
#
# Outputs:
#   ${backup_filename}
################################################################################

function backup_get_filename() {

  local backup_prefix_name="${1}"
  local backup_extension="${2}"

  local daysago
  local backup_file
  local backup_keep_daily
  local daysago

  # Backups file names
  if [[ $((10#$MONTH_DAY)) -eq 1 && $((10#$BACKUP_RETENTION_KEEP_MONTHLY)) -gt 0 ]]; then
    ## On first month day do
    backup_file="${backup_prefix_name}_${NOW}-monthly.${backup_extension}"
  else
    ## On saturdays do
    if [[ $((10#$WEEK_DAY)) -eq 6 && $((10#$BACKUP_RETENTION_KEEP_WEEKLY)) -gt 0 ]]; then
      backup_file="${backup_prefix_name}_${NOW}-weekly.${backup_extension}"
    else
      if [[ $((10#$WEEK_DAY)) -eq 7 && $((10#$BACKUP_RETENTION_KEEP_WEEKLY)) -gt 0 ||
        $((10#$MONTH_DAY)) -eq 2 && $((10#$BACKUP_RETENTION_KEEP_MONTHLY)) -gt 0 ]]; then
        ## The day after a week day or month day
        backup_keep_daily=$((BACKUP_RETENTION_KEEP_DAILY - 1))
        daysago="$(date --date="${backup_keep_daily} days ago" +"%Y-%m-%d")"
        backup_file="${backup_prefix_name}_${NOW}.${backup_extension}"
      else
        ## On any regular day do
        backup_file="${backup_prefix_name}_${NOW}.${backup_extension}"
      fi
    fi
  fi

  log_event "debug" "backup_get_filename: backup_file=${backup_file}" "false"

  # Return
  echo "${backup_file}"

}

################################################################################
# Get backup Date
#
# Arguments:
#  ${1} = ${backup_file}
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
#  ${1} = ${backup_file}
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
#  ${1} = ${backup_type} - Backup Type: configs, logs, data
#  ${2} = ${bk_sup_type} - Backup SubType: php, nginx, mysql
#  ${3} = ${backup_path} - Path folder to Backup
#  ${4} = ${directory_to_backup} - Folder to Backup
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
  local storage_path
  local backup_keep_daily
  local storage_result

  if [[ -n ${backup_path} ]]; then

    backup_prefix_name="${bk_sup_type}-${backup_type}-files"
    backup_file="$(backup_get_filename "${backup_prefix_name}" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")"

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
      storage_path="${SERVER_NAME}/server-config/${bk_sup_type}"

      # Create folder structure
      storage_create_dir "${SERVER_NAME}"
      storage_create_dir "${SERVER_NAME}/server-config"
      storage_create_dir "${SERVER_NAME}/server-config/${bk_sup_type}"

      # Uploading backup files
      storage_result="$(storage_upload_backup "${BROLIT_TMP_DIR}/${NOW}/${backup_file}" "${storage_path}" "${backup_file_size}")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Deleting old backup file
        storage_delete_old_backups "${storage_path}"

        # Deleting tmp backup file
        rm --force "${BROLIT_TMP_DIR}/${NOW}/${backup_file}"

        # Return
        echo "${backup_file_size}" && return 0

      else

        # Log
        log_event "debug" "storage_upload_backup return: ${storage_result}" "false"

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
# Make all files Backup with Borg
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 if error
################################################################################


function backup_all_files_with_borg() {

  if [[ ${BACKUP_BORG_STATUS} == "enabled" ]]; then
    # BACKUP ALL PROJECTS WITH BORG
    borgmatic --verbosity 1 --list --stats
  else
    log_event "error" "borg backup support is not enabled" "false"
    display --indent 6 --text "- backup with borg" --result "FAIL" --color RED
  fi

}

################################################################################
# Make files Backup with Borg
#
# Arguments:
#  ${1} = ${backup_type} - Backup Type (site_configs or sites)
#  ${2} = ${backup_path} - Path where directories to backup are stored
#  ${3} = ${directory_to_backup} - The specific folder/file to backup
#
# Outputs:
#  0 if ok, 1 if error
################################################################################
function backup_project_files_borg() {

  local group_name="${1}"
  local backup_type="${2}"
  local directory_to_backup="${3}" 

  storage_create_dir "/home/applications/${group_name}/${SERVER_NAME}/projects-online/${backup_type}/${directory_to_backup}"

}

################################################################################
# Make files Backup
#
# Arguments:
#  ${1} = ${backup_type} - Backup Type (site_configs or sites)
#  ${2} = ${backup_path} - Path where directories to backup are stored
#  ${3} = ${directory_to_backup} - The specific folder/file to backup
#
# Outputs:
#  0 if ok, 1 if error
################################################################################

function backup_project_files() {

  local backup_type="${1}"
  local backup_path="${2}"
  local directory_to_backup="${3}"

  local backup_file
  local backup_prefix_name
  local exclude_parameters
  local storage_path
  local storage_result

  # Backups file names
  backup_prefix_name="${directory_to_backup}_${backup_type}-files"
  backup_file="$(backup_get_filename "${backup_prefix_name}" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")"

  # Create directory structure
  storage_create_dir "${SERVER_NAME}"
  storage_create_dir "${SERVER_NAME}/projects-online"
  storage_create_dir "${SERVER_NAME}/projects-online/${backup_type}"
  storage_create_dir "${SERVER_NAME}/projects-online/${backup_type}/${directory_to_backup}"

  storage_path="${SERVER_NAME}/projects-online/${backup_type}/${directory_to_backup}"

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
      storage_result="$(storage_upload_backup "${BROLIT_TMP_DIR}/${NOW}/${backup_file}" "${storage_path}" "${backup_file_size}")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Delete old backups
        storage_delete_old_backups "${storage_path}"

        # Delete temp backup
        rm --force "${BROLIT_TMP_DIR}/${NOW}/${backup_file}"

        # Log
        log_event "info" "Temp backup deleted from server" "false"

        # Return
        echo "${backup_file_size}" && return 0

      else

        # Log
        log_event "debug" "storage_upload_backup return: ${storage_result}" "false"

        # Return
        echo "${error_type};${error_msg}" && return 1

      fi

    else

      # Log
      clear_previous_lines "1"
      display --indent 6 --text "- Files backup for ${directory_to_backup}" --result "FAIL" --color RED
      display --indent 8 --text "Please see the log file" --tcolor RED
      log_event "error" "Something went wrong making a backup of ${directory_to_backup}." "false"
      log_event "debug" "compress result: ${compress_result}" "false"

      return 1

    fi

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
    mysql_databases="$(mysql_list_databases "all" "")"

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
# Make all databases Backup
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 if error
################################################################################

function backup_all_databases_docker() {

    for project_domain in "${PROJECTS_PATH}"/*; do

        if [[ -d "${project_domain}" ]]; then

            project_name=$(basename "${project_domain}")

            echo "Backing up project: ${project_name}"

            backup_docker_project "${project_name}" "docker_backup"
 
            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then

                echo "Backup for ${project_name} completed successfully."

            else

                echo "Backup for ${project_name} failed."

            fi
        fi
        
    done
}



################################################################################
# Make databases backup
#
# Arguments:
#  ${1} = ${databases}
#  ${2} = ${db_engine}
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
#  ${1} = ${database}
#  ${2} = ${db_engine}
#  ${3} = ${container_name}
#
# Outputs:
#  "backupfile backup_file_size" if ok, 1 if error
################################################################################

function backup_project_database() {

  local database="${1}"
  local db_engine="${2}"
  local container_name="${3}"

  local export_result

  local dump_file
  local backup_file
  local storage_path
  local storage_result
  local error_type
  local error_msg

  log_event "info" "Creating new database backup of '${database}'" "false"

  # Backups file names
  backup_prefix_name="${database}_database"
  dump_file="$(backup_get_filename "${backup_prefix_name}" "sql")"
  backup_file="$(backup_get_filename "${backup_prefix_name}" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")"

  # Database engine
  if [[ ${db_engine} == "mysql" ]]; then
    ## Create dump file
    mysql_database_export "${database}" "${container_name}" "${BROLIT_TMP_DIR}/${NOW}/${dump_file}"
  else

    if [[ ${db_engine} == "psql" ]]; then
      ## Create dump file
      postgres_database_export "${database}" "${container_name}" "${BROLIT_TMP_DIR}/${NOW}/${dump_file}"
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
      storage_path="/${SERVER_NAME}/projects-online/database/${database}"
      storage_result="$(storage_upload_backup "${BROLIT_TMP_DIR}/${NOW}/${backup_file}" "${storage_path}" "${backup_file_size}")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Delete old backup from storage
        storage_delete_old_backups "${storage_path}"

        # Delete local temp files
        rm --force "${BROLIT_TMP_DIR}/${NOW}/${dump_file}"
        rm --force "${BROLIT_TMP_DIR}/${NOW}/${backup_file}"

        # Return
        echo "${backup_file};${backup_file_size}" && return 0

      else

        error_type="upload_backup"
        error_msg="Error uploading file: ${backup_file}. Upload result: ${storage_result}"

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
# Make project Backup with Borg
#
# Arguments:
#  ${1} = ${project_domain}
#
# Outputs:
#  "backupfile backup_file_size" if ok, 1 if error
################################################################################

function backup_project_with_borg() {

  local project_domain="${1}"
  #local backup_type="${2}"
  local config_directory="/etc/borgmatic.d/${project_domain}.yml"

  local got_error=0

  #local db_stage
  #local db_name
  #local db_engine
  #local backup_file
  #local project_type

  # Backup files
  log_subsection "Backup Project Files"
  #backup_file_size="$(backup_project_files "site" "${PROJECTS_PATH}" "${project_domain}")"

  project_install_type="$(project_get_install_type "${PROJECTS_PATH}/${project_domain}")"

  if [[ ${project_install_type} == "docker"* && ${project_type} != "html" ]]; then

    borg_backup_database "${project_domain}"
    # Esto ya hace backup de todo.
    borgmatic --verbosity 1 --config ${config_directory}

  fi
  ## Faltaria para los projectos no dockerizados o sea "default"

}

################################################################################
# Backup Database with Borg
#
# Arguments:
#  ${1} = ${project_domain}
#
################################################################################

function borg_backup_database() {

  local project_domain="${1}"

  local json_config_file="/root/.brolit_conf.json"

  source /root/brolit-shell/brolit_lite.sh

if [[ -f "${PROJECTS_PATH}/${project_domain}/.env" ]]; then

      # Detect if project is WordPress or Laravel, or skip database backup for other types
      if [[ -d "${PROJECTS_PATH}/${project_domain}/wordpress" || -f "${PROJECTS_PATH}/${project_domain}/application" ]]; then
          export $(grep -v '^#' "${PROJECTS_PATH}/${project_domain}/.env" | xargs)

          mysql_database="${MYSQL_DATABASE}"
          container_name="${PROJECT_NAME}_mysql"
          mysql_user="${MYSQL_USER}"
          mysql_password="${MYSQL_PASSWORD}"

      else
          echo "Skipping database backup: project ${project_domain} does not require a database backup."
          return 0
      fi

  else

      echo "Error: .env file not found in ${PROJECTS_PATH}/${project_domain}."
      return 1

  fi


  dump_file="${BROLIT_TMP_DIR}/${NOW}/${mysql_database}_database_${NOW}.sql"

  docker exec "$container_name" sh -c "mysqldump -u$mysql_user -p$mysql_password $mysql_database > /tmp/database_dump.sql"

  docker cp "$container_name:/tmp/database_dump.sql" "$dump_file"

  if [ -f "$dump_file" ]; then

      compressed_dump_file="${BROLIT_TMP_DIR}/${NOW}/${mysql_database}_database_${NOW}.tar.bz2"

      compress "${BROLIT_TMP_DIR}/${NOW}/" "${mysql_database}_database_${NOW}.sql" "${BROLIT_TMP_DIR}/${NOW}/${mysql_database}_database_${NOW}.tar.bz2"
      
      if [ $? -eq 0 ]; then

          num_borg_configs=$(_json_read_field "${json_config_file}" "BACKUPS.methods[].borg[].config | length")

          for ((i=0; i<num_borg_configs; i++)); do

            BACKUP_BORG_USER=$(_json_read_field "${json_config_file}" "BACKUPS.methods[].borg[].config[$i].user")
            BACKUP_BORG_SERVER=$(_json_read_field "${json_config_file}" "BACKUPS.methods[].borg[].config[$i].server")
            BACKUP_BORG_PORT=$(_json_read_field "${json_config_file}" "BACKUPS.methods[].borg[].config[$i].port")
            BACKUP_BORG_GROUP=$(_json_read_field "${json_config_file}" "BACKUPS.methods[].borg[].group")

            echo "Performing backup on ${BACKUP_BORG_SERVER} with user ${BACKUP_BORG_USER} on port ${BACKUP_BORG_PORT}"
          
            scp -P "${BACKUP_BORG_PORT}" "$compressed_dump_file" "${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}:/home/applications/${BACKUP_BORG_GROUP}/${HOSTNAME}/projects-online/database/${project_domain}"

            if [ $? -eq 0 ]; then

              echo "Backup successful on ${BACKUP_BORG_SERVER}"

            else

              echo "Backup failed for ${BACKUP_BORG_SERVER}"
              return 1

            fi

          done
              
          rm --recursive --force "${BROLIT_TMP_DIR}/${NOW}/${mysql_database}_database_${NOW}.tar.bz2"
          rm --recursive --force "${BROLIT_TMP_DIR}/${NOW}/${mysql_database}_database_${NOW}.sql"

      else
          echo "Error compressing the database dump."
          return 1

      fi

  else

      return 1

  fi
}

################################################################################
# Make project Backup
#
# Arguments:
#  ${1} = ${project_domain}
#  ${2} = ${backup_type} - (all,configs,sites,databases) - Default: all
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

    log_break "false"

    # Delete local backup
    rm --recursive --force "${BROLIT_TMP_DIR}/${NOW}/${backup_type:?}"
    #log_event "info" "Deleting backup from server ..." "false"

    # Log
    log_break "false"
    log_event "info" "Project backup finished!" "false"
    display --indent 6 --text "- Project Backup" --result "DONE" --color GREEN

    return ${got_error}

  else

    # Log
    log_break "false"
    log_event "error" "Something went wrong making the files backup" "false"
    display --indent 6 --text "- Project Backup" --result "FAIL" --color RED
    display --indent 8 --text "Something went wrong making the files backup" --tcolor RED

    return 1

  fi

}

################################################################################
# Make project Backup
#
# Arguments:
#  ${1} = ${project_domain}
#  ${2} = ${backup_type} - (all,configs,sites,databases) - Default: all
#
# Outputs:
#   0 if ok, 1 if error
################################################################################

function backup_docker_project() {

  local project_domain="${1}"
  local backup_type="${2}"

  local got_error=0

  local db_name
  local db_engine
  local backup_file
  local project_type
  local container_name

  # Read the .env file
  if [[ -f "${PROJECTS_PATH}/${project_domain}/.env" ]]; then

    export $(grep -v '^#' "${PROJECTS_PATH}/${project_domain}/.env" | xargs)
    db_name="${MYSQL_DATABASE}"
    container_name="${PROJECT_NAME}_mysql"
    db_engine="mysql"

  else

    echo "Error: .env file not found in ${PROJECTS_PATH}/${project_domain}/."

    return 1

  fi

  # Backup files
  log_subsection "Backup Project Files"
  backup_file_size="$(backup_project_files "site" "${PROJECTS_PATH}" "${project_domain}")"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Project Type
    project_type="$(project_get_type "${PROJECTS_PATH}/${project_domain}")"

    # Project install type
    project_install_type="$(project_get_install_type "${PROJECTS_PATH}/${project_domain}")"


    if [[ ${project_install_type} == "docker"* && ${project_type} != "html" ]]; then

        backup_project_database "${db_name}" "${db_engine}" "${container_name}"

    fi

    log_break "false"

    # Delete local backup
    rm --recursive --force "${BROLIT_TMP_DIR}/${NOW}/${backup_type:?}"
    #log_event "info" "Deleting backup from server ..." "false"

    # Log
    log_break "false"
    log_event "info" "Project backup finished!" "false"
    display --indent 6 --text "- Project Backup" --result "DONE" --color GREEN

    return ${got_error}

  else

    # Log
    log_break "false"
    log_event "error" "Something went wrong making the files backup" "false"
    display --indent 6 --text "- Project Backup" --result "FAIL" --color RED
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
