#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.6
################################################################################
#
# Backup/Restore Helper: Backup and restore funtions.
#
################################################################################

################################################################################
# Make temp directory backup.
# This should be executed if we want to restore a file backup on directory
# with the same name.
#
# Arguments:
#   ${1} = ${folder_to_backup}
#   ${2} = ${operation} - (move or copy)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _create_tmp_copy() {

  local folder_to_backup="${1}"
  local operation="${2}"

  local timestamp

  display --indent 6 --text "- Creating backup on brolit tmp directory"

  # Moving project files to temp directory
  mkdir -p "${BROLIT_MAIN_DIR}/tmp/old_backups"

  # Check if directory already exists
  base_directory="$(basename "${BROLIT_MAIN_DIR}/tmp/old_backups/${folder_to_backup}")"

  if [[ -d "${BROLIT_MAIN_DIR}/tmp/old_backups/${base_directory}" ]]; then

    timestamp=$(date +"%s")
    # Rename it with a timestamp
    mv "${BROLIT_MAIN_DIR}/tmp/old_backups/${base_directory}" "${BROLIT_MAIN_DIR}/tmp/old_backups/${base_directory}_${timestamp}"

  fi

  if [[ "${operation}" == "move" ]]; then
    move_files "${folder_to_backup}" "${BROLIT_MAIN_DIR}/tmp/old_backups"
    return $? # Return move_files exit code

  else
    copy_files "${folder_to_backup}" "${BROLIT_MAIN_DIR}/tmp/old_backups"
    return $? # Return copy_files exit code
  fi

}

#
#################################################################################
#
# * Public Funtions
#
#################################################################################
#

################################################################################
# Restore backup from local files
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_backup_from_local() {

  local restore_type # whiptail array options
  local chosen_restore_type

  local destination_dir

  restore_type=(
    "01)" "RESTORE PROJECT (NOT IMPLEMENTED YET)"
    "02)" "RESTORE FILES"
    "03)" "RESTORE DATABASE"
  )
  chosen_restore_type="$(whiptail --title "RESTORE FROM LOCAL" --menu " " 20 78 10 "${restore_type[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_restore_type} == *"01"* ]]; then

      # RESTORE PROJECT
      log_subsection "Restore project from local"

      log_event "error" "Restore project from local should be implemented soon." "true"

    fi

    if [[ ${chosen_restore_type} == *"02"* ]]; then

      # RESTORE FILES
      log_subsection "Restore files from local"

      source_files=$(whiptail --title "Source File" --inputbox "Please insert project file's backup (full path):" 10 60 "/root/to_restore/backup.zip" 3>&1 1>&2 2>&3)

      if [[ -f ${source_files} ]]; then

        display --indent 6 --text "Selected source: ${YELLOW}${source_files}${ENDCOLOR}"

      else

        clear_previous_lines "1"
        display --indent 6 --text "Selected source: ${YELLOW}${source_files}${ENDCOLOR}" --result "ERROR" --color RED
        display --indent 6 --text "File not found" --tcolor RED
        return 1

      fi

      log_event "info" "File to restore: ${source_files}" "false"

      # Ask project domain
      project_domain="$(project_ask_domain "")"

      # Get basepath
      basepath="$(dirname "${source_files}")"

      # Decompress backup
      decompress "${source_files}" "${basepath}/${project_domain}" "${BACKUP_CONFIG_COMPRESSION_TYPE}"

      dir_count="$(count_directories_on_directory "${basepath}/${project_domain}")"
      if [[ ${dir_count} -eq 1 ]]; then
        # Move files one level up
        main_dir="$(ls -1 "${basepath}/${project_domain}")"
        mv "${basepath}/${project_domain}/${main_dir}/"{.,}* "${basepath}/${project_domain}" 2>/dev/null

      fi

      # Moving project files to brolit temp directory
      mv "${basepath}/${project_domain}" "${BROLIT_TMP_DIR}"

      # TODO: Project domain asked inside this function again (need a refactor)
      # Restore site files
      project_domain="$(restore_backup_files "${project_domain}")"

      destination_dir="${PROJECTS_PATH}/${project_domain}"

      # Get project install type
      project_install_type="$(project_get_install_type "${basepath}/${project_domain}")"

      if [[ ${project_install_type} != "proxy" && ${project_install_type} != "docker"* ]]; then
        # Change ownership
        change_ownership "www-data" "www-data" "${destination_dir}"
      fi

    fi

    if [[ ${chosen_restore_type} == *"03"* ]]; then

      #RESTORE DATABASE
      log_subsection "Restore database from file"

      source_files=$(whiptail --title "Source File" --inputbox "Please insert project database's backup (full path):" 10 60 "/root/to_restore/backup.sql" 3>&1 1>&2 2>&3)

      if [[ -f ${source_files} ]]; then

        display --indent 6 --text "Selected source: ${source_files}"

      else

        display --indent 6 --text "Selected source: ${source_files}" --result "ERROR" --color RED
        display --indent 6 --text "File not found" --tcolor RED
        return 1

      fi

      log_event "info" "File to restore: ${source_files}" "false"

      # Create tmp dir
      rand=$(openssl rand -hex 5)
      tmp_dir="${BROLIT_TMP_DIR}/${rand}"
      mkdir -p "${tmp_dir}"

      # Copy to tmp dir
      copy_files "${source_files}" "${tmp_dir}"

      filename="$(basename "${source_files}")"
      backup_file="${tmp_dir}/${filename}"

      # Decompress
      decompress "${tmp_dir}/${filename}" "${tmp_dir}" ""

      dump_file="$(find "${tmp_dir}" -maxdepth 1 -mindepth 1 -type f -not -path '*/.*')"

      project_stage="$(project_ask_stage "prod")"
      [[ $? -eq 1 ]] && return 1

      project_name="$(project_ask_name "")"
      [[ $? -eq 1 ]] && return 1

      database_user="${project_name}_user"
      database_user_passw=$(openssl rand -hex 12)

      # TODO: check if database has project files already deployed

      restore_backup_database "${db_engine}" "${project_stage}" "${project_name}_${project_stage}" "${database_user}" "${database_user_passw}" "${dump_file}"

      # TODO: asks if create nginx server config, run certbot and cloudflare update

    fi

  fi

}

################################################################################
# Restore backup from ftp/sftp server
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_backup_from_ftp() {

  whiptail_message_with_skip_option "RESTORE FROM FTP" "The script will prompt you for project details and the FTP credentials. Then it will download all files one by one. If a .sql or .sql.gz is present, it will ask you if you want to restore the database too."

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # RESTORE FILES
    log_subsection "Restore files from FTP"

    # Ask project stage
    project_stage="$(project_ask_stage "prod")"
    [[ $? -eq 1 ]] && return 1

    # Ask project domain
    project_domain="$(project_ask_domain "")"
    [[ $? -eq 1 ]] && return 1

    possible_project_name="$(project_get_name_from_domain "${project_domain}")"

    # Ask project name
    project_name="$(project_ask_name "${possible_project_name}")"
    [[ $? -eq 1 ]] && return 1

    # FTP
    ftp_domain="$(whiptail_input "FTP SERVER IP/DOMAIN" "Please insert de FTP server IP/DOMAIN. Ex: ftp.domain.com")"
    ftp_path="$(whiptail_input "FTP SERVER PATH" "Please insert de FTP server path. Ex: public_html")"
    ftp_user="$(whiptail_input "FTP SERVER USER" "Please insert de FTP user.")"
    ftp_pass="$(whiptail_input "FTP SERVER PASS" "Please insert de FTP password.")"

    ## Download files from ftp
    ftp_download "${ftp_domain}" "${ftp_path}" "${ftp_user}" "${ftp_pass}" "${BROLIT_TMP_DIR}/${project_domain}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 1 ]]; then
      # Log
      log_event "error" "FTP connection failed!" "false"
      display --indent 6 --text "- Restore project" --result "FAIL" --color RED
      return 1
    fi

    # Search for .sql or sql.gz files
    local find_result

    # Find backups from downloaded ftp files
    find_result="$({
      find "${BROLIT_TMP_DIR}/${project_domain}" -name "*.sql"
      find "${BROLIT_TMP_DIR}/${project_domain}" -name "*.sql.gz"
    })"

    if [[ ${find_result} != "" ]]; then

      log_event "info" "Database backups found on downloaded files" "false"

      array_to_checklist "${find_result}"

      # Backup file selection
      chosen_database_backup="$(whiptail --title "DATABASE TO RESTORE" --checklist "Select the database backup you want to restore." 20 78 15 "${checklist_array[@]}" 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Restore database

        ## Get project_type && project_install_type
        project_type="$(project_get_type "${project_name}")"
        project_install_type="$(project_get_install_type "${install_path}")"

        ## Get database information
        db_engine="$(project_get_configured_database_engine "${install_path}" "${project_type}" "${project_install_type}")"
        db_name="$(project_get_configured_database "${install_path}" "${project_type}" "${project_install_type}")"
        db_user="$(project_get_configured_database_user "${install_path}" "${project_type}" "${project_install_type}")"
        db_pass="$(project_get_configured_database_userpassw "${install_path}" "${project_type}" "${project_install_type}")"

        restore_backup_database "${db_engine}" "${project_stage}" "${project_name}_${project_stage}" "${db_user}" "${db_pass}" "${BROLIT_TMP_DIR}/${chosen_database_backup}"

      else

        log_event "info" "Database backup selection skipped" "false"
        display --indent 6 --text "- Database backup selection" --result "SKIPPED" --color YELLOW

      fi

    fi

    # Restore files
    move_files "${BROLIT_TMP_DIR}/${project_domain}" "${PROJECTS_PATH}"

  fi

}

################################################################################
# Restore backup from public url (ex: https://domain.com/backup.tar.gz)
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_backup_from_public_url() {

  local project_stage
  local project_domain
  local project_name
  local possible_project_name
  local root_domain

  # RESTORE FILES
  log_subsection "Restore files from public URL"

  # Ask project stage
  project_stage="$(project_ask_stage "prod")"
  [[ $? -eq 1 ]] && return 1

  # Project domain
  project_domain="$(project_ask_domain "")"
  [[ $? -eq 1 ]] && return 1

  # Cloudflare support
  if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then
    root_domain="$(domain_get_root "${project_domain}")"
    [[ $? -eq 1 ]] && return 1
  fi

  # Project name
  possible_project_name="$(project_get_name_from_domain "${project_domain}")"
  project_name="$(project_ask_name "${possible_project_name}")"
  [[ $? -eq 1 ]] && return 1

  source_files_url=$(whiptail --title "Source File URL" --inputbox "Please insert the URL where backup files are stored." 10 60 "https://domain.com/backup-files.zip" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    display --indent 6 --text "${source_files_url}"
  else
    return 1
  fi

  # File Backup details
  backup_file=${source_files_url##*/}

  # Create tmp dir structure
  mkdir -p "${BROLIT_TMP_DIR}"
  mkdir -p "${BROLIT_TMP_DIR}/${project_domain}"

  # Log
  display --indent 6 --text "- Downloading file backup"
  log_event "info" "Downloading file backup ${source_files_url}" "false"
  log_event "debug" "Running: ${CURL} ${source_files_url} >${BROLIT_TMP_DIR}/${project_domain}/${backup_file}" "false"

  # Download File Backup
  ${CURL} "${source_files_url}" >"${BROLIT_TMP_DIR}/${project_domain}/${backup_file}"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Downloading file backup" --result "DONE" --color GREEN

  else

    # Log
    clear_previous_lines "2"
    log_event "error" "Download failed!" "false"
    display --indent 6 --text "- Downloading file backup" --result "FAIL" --color RED

    return 1

  fi

  # Uncompressing
  decompress "${BROLIT_TMP_DIR}/${project_domain}/${backup_file}" "${BROLIT_TMP_DIR}" "${BACKUP_CONFIG_COMPRESSION_TYPE}"

  exitstatus=$?
  if [[ ${exitstatus} -eq 1 ]]; then

    # Log
    log_event "error" "Restore project aborted." "false"
    display --indent 8 --text "Restore project aborted"--tcolor RED

    return 1

  fi

  # Remove downloaded file
  rm --force "${BROLIT_TMP_DIR}/${project_domain}/${backup_file}"

  # Create database and user
  db_project_name=$(mysql_name_sanitize "${project_name}")

  database_name="${db_project_name}_${project_stage}"
  database_user="${db_project_name}_user"
  database_user_passw=$(openssl rand -hex 12)

  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}" "localhost"
  mysql_user_grant_privileges "${database_user}" "${database_name}" "localhost"

  # Search for .sql or sql.gz files
  local find_result

  # Find backups from downloaded ftp files
  find_result="$({
    find "${BROLIT_TMP_DIR}/${project_domain}" -name "*.sql"
    find "${BROLIT_TMP_DIR}/${project_domain}" -name "*.sql.gz"
  })"

  if [[ -n ${find_result} ]]; then

    log_event "info" "Database backups found on downloaded files" "false"

    array_to_checklist "${find_result}"

    # Backup file selection
    chosen_database_backup="$(whiptail --title "DATABASE TO RESTORE" --checklist "Select the database backup you want to restore." 20 78 15 "${checklist_array[@]}" 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Restore database

      ## Get project_type && project_install_type
      project_type="$(project_get_type "${project_name}")"
      project_install_type="$(project_get_install_type "${install_path}")"

      ## Get database information
      db_engine="$(project_get_configured_database_engine "${install_path}" "${project_type}" "${project_install_type}")"
      db_name="$(project_get_configured_database "${install_path}" "${project_type}" "${project_install_type}")"
      db_user="$(project_get_configured_database_user "${install_path}" "${project_type}" "${project_install_type}")"
      db_pass="$(project_get_configured_database_userpassw "${install_path}" "${project_type}" "${project_install_type}")"

      restore_backup_database "${db_engine}" "${project_stage}" "${project_name}_${project_stage}" "${db_user}" "${db_pass}" "${BROLIT_TMP_DIR}/${chosen_database_backup}"

    else

      log_event "info" "Database backup selection skipped" "false"
      display --indent 6 --text "- Database backup selection" --result "SKIPPED" --color YELLOW

    fi

  else

    log_event "info" "No database backups found on downloaded files" "false"

    source_db_url=$(whiptail --title "Database URL" --inputbox "Please insert the URL where the database backup is stored." 10 60 "https://domain.com/backup-db.zip" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Database Backup details
      backup_file=${source_db_url##*/}

      # Download database backup
      ${CURL} "${source_db_url}" >"${BROLIT_TMP_DIR}/${backup_file}"

      # Restore database

      ## Get project_type && project_install_type
      project_type="$(project_get_type "${project_name}")"
      project_install_type="$(project_get_install_type "${install_path}")"

      ## Get database information
      db_engine="$(project_get_configured_database_engine "${install_path}" "${project_type}" "${project_install_type}")"
      db_name="$(project_get_configured_database "${install_path}" "${project_type}" "${project_install_type}")"
      db_user="$(project_get_configured_database_user "${install_path}" "${project_type}" "${project_install_type}")"
      db_pass="$(project_get_configured_database_userpassw "${install_path}" "${project_type}" "${project_install_type}")"

      restore_backup_database "${db_engine}" "${project_stage}" "${project_name}_${project_stage}" "${db_user}" "${db_pass}" "${BROLIT_TMP_DIR}/${backup_file}"

    else

      return 1

    fi

  fi

  # Move to ${PROJECTS_PATH}
  log_event "info" "Moving ${project_domain} to ${PROJECTS_PATH} ..." "false"

  mv "${BROLIT_TMP_DIR}/${project_domain}" "${PROJECTS_PATH}/${project_domain}"

  #change_ownership "www-data" "www-data" "${PROJECTS_PATH}/${project_domain}"

  destination_dir="${PROJECTS_PATH}/${project_domain}"

  project_install_type="$(project_get_install_type "${destination_dir}")"

  if [[ ${project_install_type} == "default" ]]; then

    project_type="$(project_get_type "${destination_dir}")"

    # Project domain configuration (webserver+certbot+DNS)
    https_enable="$(project_update_domain_config "${project_domain}" "default" "${project_type}" "")"

    # Post-restore/install tasks
    # TODO: neet to get old domain for replace on database
    project_post_install_tasks "${install_path}" "${project_type}" "${project_name}" "${project_stage}" "${db_pass}" "${project_domain}" "${project_domain}"

  else

    # TODO: search available port

    # Project domain configuration (webserver+certbot+DNS)
    https_enable="$(project_update_domain_config "${project_domain}" "proxy" "${project_install_type}" "")"

  fi

  # Create brolit_config.json file
  project_update_brolit_config "${destination_dir}/${install_path}" "${project_name}" "${project_stage}" "${project_type}" "enabled" "mysql" "${database_name}" "localhost" "${database_user}" "${database_user_passw}" "${project_domain}" "" "" "true" ""

  # Remove tmp files
  log_event "info" "Removing temporary folders ..." "false"
  rm --force --recursive "${BROLIT_TMP_DIR}/${project_domain:?}"

  # Send notifications
  send_notification "✅ ${SERVER_NAME}" "Project ${project_name} restored!" ""

  HTMLOPEN='<html><body>'
  BODY_SRV_MIG='Project restore ended '${ELAPSED_TIME}'<br/>'
  BODY_DB='Database: '${project_name}'_'${project_stage}'<br/>Database User: '${project_name}'_user <br/>Database User Pass: '${database_user_passw}'<br/>'
  HTMLCLOSE='</body></html>'

  mail_send_notification "✅ ${SERVER_NAME} - Project ${project_name} restored!" "${HTMLOPEN} ${BODY_SRV_MIG} ${BODY_DB} ${BODY_CLF} ${HTMLCLOSE}"

}

################################################################################
# Restore backup from dropbox (server selection)
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_backup_server_selection() {

  local remote_server_list # list servers directories on dropbox
  local remote_type_list
  local chosen_server # whiptail var

  # Server selection
  remote_server_list="$(storage_list_dir "/")"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Show output
    chosen_server="$(whiptail --title "RESTORE BACKUP" --menu "Choose a server to work with" 20 78 10 $(for x in ${remote_server_list}; do echo "${x} [D]"; done) --default-item "${SERVER_NAME}" 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      log_event "debug" "chosen_server: ${chosen_server}" "false"

      # List options
      # TODO: need to implement "other"
      remote_type_list='project site database'

      # Select backup type
      restore_type_selection_from_storage "${chosen_server}" "${remote_type_list}"

    else

      restore_manager_menu

    fi

  else

    log_event "error" "Dropbox uploader failed. Output: ${remote_server_list}. Exit status: ${exitstatus}" "false"

    return 1

  fi

  restore_manager_menu

}

################################################################################
# Restore config files from dropbox
#
# Arguments:
#   $1 = ${chosen_type_path}
#   $2 = ${storage_project_list}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_config_files_from_storage() {

  local chosen_type_path="${1}"
  local storage_project_list="${2}"

  local chosen_config_type # whiptail var
  local storage_file_list  # backup list
  local chosen_config_bk   # whiptail var

  log_subsection "Restore Server config files"

  # Select config backup type
  chosen_config_type="$(whiptail --title "RESTORE CONFIGS BACKUPS" --menu "Choose a config backup type." 20 78 10 $(for x in ${storage_project_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    #Restore file list
    storage_file_list="$(storage_list_dir "${chosen_type_path}/${chosen_config_type}")"
  fi

  chosen_config_bk="$(whiptail --title "RESTORE CONFIGS BACKUPS" --menu "Choose a config backup file to restore." 20 78 10 $(for x in ${storage_file_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Downloading Config Backup
    display --indent 6 --text "- Downloading config backup from dropbox"

    #dropbox_download "${chosen_type_path}/${chosen_config_type}/${chosen_config_bk}" "${BROLIT_MAIN_DIR}/tmp"
    storage_download_backup "${chosen_type_path}/${chosen_config_type}/${chosen_config_bk}" "${BROLIT_MAIN_DIR}/tmp"

    #clear_previous_lines "1"
    #display --indent 6 --text "- Downloading config backup from dropbox" --result "DONE" --color GREEN

    # Restore files
    mkdir -p "${chosen_config_type}"
    mv "${chosen_config_bk}" "${chosen_config_type}"

    # Decompress
    decompress "${chosen_config_bk}" "${BROLIT_MAIN_DIR}/tmp/${chosen_config_type}" "${BACKUP_CONFIG_COMPRESSION_TYPE}"

    if [[ "${chosen_config_bk}" == *"nginx"* ]]; then

      restore_nginx_site_files "" ""

    fi

    log_event "info" "${CHOSEN_CONFIG} Config backup downloaded and uncompressed on  ${BROLIT_MAIN_DIR}/tmp/${chosen_config_type}"
    whiptail_message "IMPORTANT!" "${CHOSEN_CONFIG} config files were downloaded on this temp directory: ${BROLIT_MAIN_DIR}/tmp/${chosen_config_type}."

  fi

}

################################################################################
# Restore nginx site files
#
# Arguments:
#   $1 = ${domain}
#   $2 = ${date}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_nginx_site_files() {

  local domain="${1}"
  local date="${2}"

  local bk_file
  local bk_to_download
  local filename
  local to_restore
  local dropbox_output # var for dropbox output

  bk_file="nginx-configs-files-${date}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
  bk_to_download="${chosen_server}/configs/nginx/${bk_file}"

  # Subsection
  log_subsection "Nginx server configuration Restore"

  # Downloading Config Backup
  storage_download_backup "${bk_to_download}" "${BROLIT_TMP_DIR}"
  [[ $? -eq 1 ]] && return 1

  # Extract
  mkdir -p "${BROLIT_MAIN_DIR}/tmp/nginx"
  decompress "${bk_file}" "${BROLIT_MAIN_DIR}/tmp/nginx" "${BACKUP_CONFIG_COMPRESSION_TYPE}"

  # TODO: if nginx is installed, ask if nginx.conf must be replace

  # Checking if default nginx folder exists
  if [[ -n "${WSERVER}" ]]; then

    log_event "info" "Folder ${WSERVER} exists ... OK" "false"

    if [[ -z "${domain}" ]]; then

      startdir="${BROLIT_MAIN_DIR}/tmp/nginx/sites-available"
      file_browser "$menutitle" "$startdir"

      to_restore="${filepath}/${filename}"
      log_event "info" "File to restore: ${to_restore} ..." "false"

    else

      to_restore="${BROLIT_MAIN_DIR}/tmp/nginx/sites-available/${domain}"
      filename=${domain}

      log_event "info" "File to restore: ${to_restore} ..." "false"

    fi

    if [[ -f "${WSERVER}/sites-available/${filename}" ]]; then

      log_event "info" "File ${WSERVER}/sites-available/${filename} already exists. Making a backup file ..." "false"

      mv "${WSERVER}/sites-available/${filename}" "${WSERVER}/sites-available/${filename}_bk"

      display --indent 6 --text "- Making backup of existing config" --result "DONE" --color GREEN

    fi

    log_event "info" "Restoring nginx configuration from backup: ${filename}" "false"

    # Copy files
    cp "${to_restore}" "${WSERVER}/sites-available/${filename}"

    # Creating symbolic link
    ln -s "${WSERVER}/sites-available/${filename}" "${WSERVER}/sites-enabled/${filename}"

    #display --indent 6 --text "- Restoring Nginx server config" --result "DONE" --color GREEN
    #nginx_server_change_domain "${WSERVER}/sites-enabled/${filename}" "${domain}" "${domain}"

    nginx_configuration_test

  else

    log_event "error" "/etc/nginx/sites-available NOT exist... Skipping!" "false"
    #echo "ERROR: nginx main dir is not present!"
    return 1

  fi

}

################################################################################
# Restore letsencrypt files
#
# Arguments:
#   $1 = ${domain}
#   $2 = ${date}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_letsencrypt_site_files() {

  local domain="${1}"
  local date="${2}"

  local bk_file
  local bk_to_download

  bk_file="letsencrypt-configs-files-${date}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
  bk_to_download="${chosen_server}/configs/letsencrypt/${bk_file}"

  log_event "debug" "Running: ${DROPBOX_UPLOADER} download ${bk_to_download}"

  dropbox_output=$(${DROPBOX_UPLOADER} download "${bk_to_download}" 1>&2)

  # Extract
  mkdir "${BROLIT_MAIN_DIR}/tmp/letsencrypt"
  decompress "${bk_file}" "${BROLIT_MAIN_DIR}/tmp/letsencrypt" "${BACKUP_CONFIG_COMPRESSION_TYPE}"

  # Creating directories
  if [[ ! -d "/etc/letsencrypt/archive/" ]]; then
    mkdir "/etc/letsencrypt/archive/"

  fi
  if [[ ! -d "/etc/letsencrypt/live/" ]]; then
    mkdir "/etc/letsencrypt/live/"

  fi
  if [[ ! -d "/etc/letsencrypt/archive/${domain}" ]]; then
    mkdir "/etc/letsencrypt/archive/${domain}"

  fi
  if [[ ! -d "/etc/letsencrypt/live/${domain}" ]]; then
    mkdir "/etc/letsencrypt/live/${domain}"

  fi

  # Check if file exist
  if [[ ! -f "/etc/letsencrypt/options-ssl-nginx.conf" ]]; then
    cp -r "${BROLIT_MAIN_DIR}/tmp/letsencrypt/options-ssl-nginx.conf" "/etc/letsencrypt/"

  fi
  if [[ ! -f "/etc/letsencrypt/ssl-dhparams.pem" ]]; then
    cp -r "${BROLIT_MAIN_DIR}/tmp/letsencrypt/ssl-dhparams.pem" "/etc/letsencrypt/"

  fi

  # TODO: Restore main files (checking non-www and www domains)
  if [[ ! -f "${BROLIT_MAIN_DIR}/tmp/letsencrypt/archive/${domain}" ]]; then
    cp -r "${BROLIT_MAIN_DIR}/tmp/letsencrypt/archive/${domain}" "/etc/letsencrypt/archive/"

  fi
  if [[ ! -f "${BROLIT_MAIN_DIR}/tmp/letsencrypt/live/${domain}" ]]; then
    cp -r "${BROLIT_MAIN_DIR}/tmp/letsencrypt/live/${domain}" "/etc/letsencrypt/live/"

  fi

  display --indent 6 --text "- Restoring letsencrypt config files" --result "DONE" --color GREEN

}

################################################################################
# Restore site files
#
# Arguments:
#   $1 = ${domain}
#   $2 = ${backup_path}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# TODO: Refactor this function
#       Extract the option to change project domain outside of this function
#       Add an argument to change backup path

function restore_backup_files() {

  local domain="${1}"
  #local backup_path="${2}"

  local destination_dir
  local chosen_domain
  local project_tmp_dir_old
  local project_tmp_dir_new

  log_subsection "Restore Files Backup"

  chosen_domain="$(whiptail --title "Project Domain" --inputbox "Want to change the project's domain? Default:" 10 60 "${domain}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Log
    log_event "info" "Working with domain: ${chosen_domain}"
    display --indent 6 --text "- Selecting project domain" --result "DONE" --color GREEN
    display --indent 8 --text "${chosen_domain}" --tcolor YELLOW

    # If user change project domains, we need to do this
    project_tmp_dir_old="${BROLIT_TMP_DIR}/${domain}"
    project_tmp_dir_new="${BROLIT_TMP_DIR}/${chosen_domain}"

    # Rename tmp directory
    [[ ${project_tmp_dir_old} != "${project_tmp_dir_new}" ]] && move_files "${project_tmp_dir_old}" "${project_tmp_dir_new}"

    # New destination directory
    destination_dir="${PROJECTS_PATH}/${chosen_domain}"

    # If exists, make a backup
    if [[ -d ${destination_dir} ]]; then

      # Warning message
      whiptail --title "Warning" --yesno "The project directory already exist. Do you want to continue? A backup of current directory will be stored on BROLIT tmp folder." 10 60 3>&1 1>&2 2>&3

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Backup old project
        _create_tmp_copy "${destination_dir}" "move"
        got_error=$?
        [[ ${got_error} -eq 1 ]] && return 1

      else

        # Log
        log_event "info" "The project directory already exist. User skipped operation." "false"
        display --indent 6 --text "- Restore files" --result "SKIPPED" --color YELLOW

        return 1

      fi

    fi

    # Restore files
    move_files "${project_tmp_dir_new}" "${PROJECTS_PATH}"

    # Return
    echo "${chosen_domain}" && return 0

  else

    return 1

  fi

}

################################################################################
# Restore type selection from dropbox
#
# Arguments:
#   $1 = ${chosen_server}
#   $2 = ${remote_type_list}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_type_selection_from_storage() {

  local chosen_server="${1}"
  local remote_type_list="${2}"

  local project_status_list
  local chosen_restore_type        # whiptail var
  local chosen_backup_to_restore   # whiptail var
  local chosen_type_path           # whiptail var
  local storage_project_list       # list of projects on remote directory
  local storage_chosen_backup_path # whiptail var
  local storage_backup_list        # dropbox listing directories
  local domain                     # extracted domain
  local db_project_name            # extracted db name
  local backup_to_dowload          # backup to download
  #local folder_to_install          # directory to install project
  #local project_site
  local dump_file
  local possible_project_name
  local database_engine
  local database_name
  local database_user
  local database_user_pass

  chosen_restore_type="$(whiptail --title "RESTORE FROM BACKUP" --menu "Choose a backup type. You can choose restore an entire project or only site files, database or config." 20 78 10 $(for x in ${remote_type_list}; do echo "${x} [D]"; done) 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    log_section "Restore Backup"

    project_status_list="online offline"

    chosen_status="$(whiptail --title "RESTORE FROM BACKUP" --menu "Choose a backup status." 20 78 10 $(for x in ${project_status_list}; do echo "${x} [D]"; done) 3>&1 1>&2 2>&3)"

    chosen_type_path="${chosen_server}/projects-${chosen_status}/${chosen_restore_type}"
    storage_project_list="$(storage_list_dir "${chosen_type_path}")"

    ### NEW
    case ${chosen_restore_type} in

    project)

      restore_project "${chosen_server}" "${chosen_status}"

      ;;

    configs)

      restore_config_files_from_storage "${chosen_type_path}" "${storage_project_list}"

      ;;

    site)

      # Select Project
      chosen_project="$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup Project" 20 78 10 $(for x in ${storage_project_list}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        storage_chosen_backup_path="${chosen_type_path}/${chosen_project}"
        storage_backup_list="$(storage_list_dir "${storage_chosen_backup_path}")"
      fi
      # Select Backup File
      chosen_backup_to_restore="$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup to Download" 20 78 10 $(for x in ${storage_backup_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Asking project stage with suggested actual state
        suffix=${chosen_project%_*} ## strip the tail
        project_stage="$(project_ask_stage "${suffix}")"

        ## If chosen_project = project domain, we need to extract the domain extension
        possible_project_name="$(project_get_name_from_domain "${chosen_project}")"

        # Asking project name
        project_name="$(project_ask_name "${possible_project_name}")"

        # Sanitize ${project_name}
        db_project_name="$(mysql_name_sanitize "${project_name}")"

        project_backup_date="$(backup_get_date "${chosen_backup_to_restore}")"
        backup_to_dowload="${chosen_type_path}/${chosen_project}/${chosen_backup_to_restore}"

        # Downloading Backup
        storage_download_backup "${backup_to_dowload}" "${BROLIT_TMP_DIR}"

        # Decompress
        decompress "${BROLIT_TMP_DIR}/${chosen_backup_to_restore}" "${BROLIT_TMP_DIR}" "${BACKUP_CONFIG_COMPRESSION_TYPE}"

        chosen_type_path="${chosen_server}/projects-${chosen_status}/${chosen_restore_type}"
        storage_project_list="$(storage_list_dir "${chosen_type_path}")"

        # At this point chosen_project is the new project domain
        # TODO: Project domain asked inside this function again (need a refactor)
        # Restore site files
        project_domain="$(restore_backup_files "${chosen_project}")"

        # Get project install type
        project_install_type="$(project_get_install_type "${PROJECTS_PATH}/${project_domain}")"

        if [[ ${project_install_type} != "proxy" && ${project_install_type} != "docker"* ]]; then
          # Change ownership
          change_ownership "www-data" "www-data" "${PROJECTS_PATH}/${project_domain}"
        fi

      fi

      ;;

    database)

      # Select Project
      chosen_project="$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup Project" 20 78 10 $(for x in ${storage_project_list}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        storage_chosen_backup_path="${chosen_type_path}/${chosen_project}"
        storage_backup_list="$(storage_list_dir "${storage_chosen_backup_path}")"
      fi
      # Select Backup File
      chosen_backup_to_restore="$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup to Download" 20 78 10 $(for x in ${storage_backup_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Asking project stage with suggested actual state
        suffix=${chosen_project%_*} ## strip the tail
        project_stage="$(project_ask_stage "${suffix}")"

        # On site chosen_project = project domain, on database chosen_project = database name
        ## If chosen_project = database name, we need to extract the original project_stage
        possible_project_name=${chosen_project%$suffix} #Remove suffix

        # Asking project name
        project_name="$(project_ask_name "${possible_project_name}")"

        # Sanitize ${project_name}
        db_project_name="$(mysql_name_sanitize "${project_name}")"

        project_backup_date="$(backup_get_date "${chosen_backup_to_restore}")"
        backup_to_dowload="${chosen_type_path}/${chosen_project}/${chosen_backup_to_restore}"

        # Downloading Backup
        storage_download_backup "${backup_to_dowload}" "${BROLIT_TMP_DIR}"

        # Decompress
        decompress "${BROLIT_TMP_DIR}/${chosen_backup_to_restore}" "${BROLIT_TMP_DIR}" "${BACKUP_CONFIG_COMPRESSION_TYPE}"

        dump_file="${chosen_backup_to_restore%%.*}.sql"

        # Ask with whiptail if the database is associated to an existing project (yes or no)
        whiptail_message_with_skip_option "RESTORE BACKUP" "Is the database associated to an existing project?"

        # If yes select a project from ${PROJECTS_PATH} directory
        if [[ $? -eq 0 ]]; then
          # Select project to work with
          directory_browser "Select a project to work with" "${PROJECTS_PATH}" #return $filename

          # Check project_install_type (default or docker)
          project_install_type="$(project_get_install_type "${PROJECTS_PATH}/${filename}")"
          # Check project_type
          project_type="$(project_get_type "${PROJECTS_PATH}/${filename}")"

          if [[ ${project_install_type} == "docker-compose" ]]; then

            [[ ${PACKAGES_DOCKER_STATUS} != "enabled" ]] && log_event "error" "Docker is not enabled from brolit_conf.json" "true" && exit 1

            # Read MYSQL_DATABASE, MYSQL_USER and MYSQL_PASSWORD from docker .env file
            docker_env_file="/${PROJECTS_PATH}/${filename}/.env"
            if [[ -f "${docker_env_file}" ]]; then
              docker_project_name="$(grep PROJECT_NAME "${docker_env_file}" | cut -d '=' -f2)"
              docker_mysql_database="$(grep MYSQL_DATABASE "${docker_env_file}" | cut -d '=' -f2)"
              docker_mysql_user="$(grep MYSQL_USER "${docker_env_file}" | cut -d '=' -f2)"
              docker_mysql_user_pass="$(grep MYSQL_PASSWORD "${docker_env_file}" | cut -d '=' -f2)"
            fi

            # Restore database on docker container
            docker_mysql_database_import "${docker_project_name}_mysql" "${docker_mysql_user}" "${docker_mysql_user_pass}" "${docker_mysql_database}" "${BROLIT_TMP_DIR}/${dump_file}"

          else

            # Get ${database_engine} from project config
            database_engine="$(project_get_configured_database_engine "${PROJECTS_PATH}/${filename}" "${project_type}" "${project_install_type}")"
            # Get ${database_name} from project config
            database_name="$(project_get_configured_database "${PROJECTS_PATH}/${filename}" "${project_type}" "${project_install_type}")"
            # Get ${database_user} from project config
            database_user="$(project_get_configured_database_user "${PROJECTS_PATH}/${filename}" "${project_type}" "${project_install_type}")"
            # Get ${database_user_pass} from project config
            database_user_pass="$(project_get_configured_database_userpassw "${PROJECTS_PATH}/${filename}" "${project_type}" "${project_install_type}")"

            # If database_ vars are not empty, restore database
            if [[ -n "${database_engine}" ]] && [[ -n "${database_name}" ]] && [[ -n "${database_user}" ]] && [[ -n "${database_user_pass}" ]]; then

              # TODO: check if volume is created? check if container is running?

              # Restore Database Backup
              restore_backup_database "${database_engine}" "${project_stage}" "${database_name}" "${database_user}" "${database_user_pass}" "${BROLIT_TMP_DIR}/${chosen_backup_to_restore}"
              return 0

            else

              log_event "error" "Can't read database config from project file. Please, check project config." "true"
              return 1

            fi

          fi

        else

          # Get database backup type (mysql or postgres) from dump file
          database_engine="$(backup_get_database_type "${BROLIT_TMP_DIR}/${chosen_backup_to_restore}")"

          database_engine="mysql"
          database_name="${db_project_name}_${project_stage}"

          # TODO: check if database exists

          #if [[ -z ${db_user} ]]; then
          database_user="${db_project_name}_user"
          #fi
          #if [[ -z ${db_pass} ]]; then
          # Passw generator
          database_user_pass="$(openssl rand -hex 12)"
          #fi

          # Restore Database Backup
          restore_backup_database "${database_engine}" "${project_stage}" "${database_name}" "${database_user}" "${database_user_pass}" "${BROLIT_TMP_DIR}/${dump_file}"

          # TODO: ask if want to change project db parameters and make Cloudflare changes

          #folder_to_install="$(project_ask_folder_to_install "${PROJECTS_PATH}")"
          #folder_to_install_result=$?
          #[[ ${folder_to_install_result} -eq 1 ]] && return 1

          #directory_browser "Site Selection Menu" "${PROJECTS_PATH}"
          #directory_browser_result=$?
          #[[ ${directory_browser_result} -eq 1 ]] && return 1

          # TODO: check project type (WP, Laravel, etc)
          #project_type="$(project_get_type "${PROJECTS_PATH}/${filename}")"

          # Post-restore/install tasks
          # TODO: neet to get old domain for replace on database
          #project_post_install_tasks "${PROJECTS_PATH}/${filename}" "${project_type}" "${project_name}" "${project_stage}" "${db_pass}" "${project_domain}" "${project_domain}"
        fi

      fi

      ;;

    esac

  fi

}

################################################################################
# Restore project
#
# Arguments:
#   $1 = ${chosen_server}
#   $2 = ${chosen_status} - online or offline
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# TODO: what if project is not a site? Maybe is a database-only project.
function restore_project() {

  local chosen_server="${1}"
  local chosen_status="${2}"

  local storage_project_list
  local chosen_project
  local remote_backup_path
  local remote_backup_list
  local backup_to_dowload
  local chosen_backup_to_restore
  local db_to_download
  local project_db_status
  local project_type
  local db_engine
  local db_name
  local db_user
  local db_pass

  local installation_type

  log_subsection "Restore Project Backup"

  # Get dropbox folders list
  storage_project_list="$(storage_list_dir "${chosen_server}/projects-${chosen_status}/site")"

  # Select Project
  chosen_project="$(whiptail --title "RESTORE PROJECT BACKUP" --menu "Choose a project backup to restore:" 20 78 10 $(for x in ${storage_project_list}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    # Get backup list
    remote_backup_path="${chosen_server}/projects-${chosen_status}/site/${chosen_project}"
    remote_backup_list="$(storage_list_dir "${remote_backup_path}")"

  else

    display --indent 6 --text "- Restore project backup" --result "SKIPPED" --color YELLOW
    return 1

  fi

  # Select Backup File
  chosen_backup_to_restore="$(whiptail --title "RESTORE PROJECT BACKUP" --menu "Choose Backup to Download" 20 78 10 $(for x in ${remote_backup_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    display --indent 6 --text "- Selecting project backup" --result "DONE" --color GREEN
    display --indent 8 --text "${chosen_backup_to_restore}" --tcolor YELLOW

    # Download backup
    backup_to_dowload="${chosen_server}/projects-${chosen_status}/site/${chosen_project}/${chosen_backup_to_restore}"
    storage_download_backup "${backup_to_dowload}" "${BROLIT_TMP_DIR}"

    # Decompress
    decompress "${BROLIT_TMP_DIR}/${chosen_backup_to_restore}" "${BROLIT_TMP_DIR}" "${BACKUP_CONFIG_COMPRESSION_TYPE}"
    [[ $? -eq 1 ]] && return 1
    # TODO: implement error type

    # TODO: need to change this!
    # If a directory exists, get project type & installation type
    if [[ -d "${PROJECTS_PATH}/${chosen_project}" ]]; then
      project_type="$(project_get_type "${PROJECTS_PATH}/${chosen_project}")"
      project_install_type="$(project_get_install_type "${PROJECTS_PATH}/${chosen_project}")"
    fi

    # TODO: if project type==docker download, extract, move to /var/www, run docker commands, execute domain tasks
    # TODO: if project type!=wordpress then... needs implementation.

    if [[ ${PACKAGES_DOCKER_STATUS} == "enabled" && ${project_install_type} == "docker-compose" && ${project_type} == "wordpress" ]]; then

      if [[ -d "${PROJECTS_PATH}/${chosen_project}" ]]; then

        # Warning message
        whiptail --title "Warning" --yesno "A docker project already exist for this domain. Do you want to restore the current backup on this docker stack? A backup of current directory will be stored on BROLIT tmp folder." 10 60 3>&1 1>&2 2>&3

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          # Backup old project
          _create_tmp_copy "${PROJECTS_PATH}/${chosen_project}" "copy"
          got_error=$?
          [[ ${got_error} -eq 1 ]] && return 1

        else

          # Log
          log_event "info" "The project directory already exist. User skipped operation." "false"
          display --indent 6 --text "- Restore files" --result "SKIPPED" --color YELLOW

          return 1

        fi

        installation_type="docker"

        # Remove actual wordpress files
        #rm -R "${PROJECTS_PATH}/${chosen_project}/wordpress/wp-content"
        rm -R "${PROJECTS_PATH}/${chosen_project}/wordpress"

        #move_files "${BROLIT_TMP_DIR}/${chosen_project}/wp-content" "${PROJECTS_PATH}/${chosen_project}/wordpress"
        move_files "${BROLIT_TMP_DIR}/${chosen_project}" "${PROJECTS_PATH}/${chosen_project}/wordpress"

        display --indent 6 --text "- Import files into docker volume" --result "DONE" --color GREEN

        # TODO: update this to match monthly and weekly backups
        project_name="$(project_get_name_from_domain "${chosen_project}")"
        project_stage="$(project_get_stage_from_domain "${chosen_project}")"

        db_name="${project_name}_${project_stage}"
        new_project_domain="${chosen_project}"

        project_backup_date="$(backup_get_date "${chosen_backup_to_restore}")"

        db_to_download="${chosen_server}/projects-${chosen_status}/database/${db_name}/${db_name}_database_${project_backup_date}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
        db_to_restore="${db_name}_database_${project_backup_date}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
        project_backup="${db_to_restore%%.*}.sql"

        # Downloading Database Backup
        storage_download_backup "${db_to_download}" "${BROLIT_TMP_DIR}"

        # Decompress
        decompress "${BROLIT_TMP_DIR}/${db_to_restore}" "${BROLIT_TMP_DIR}" "${BACKUP_CONFIG_COMPRESSION_TYPE}"

        # Read wp-config to get WP DATABASE PREFIX and replace on docker .env file
        #database_prefix_to_restore="$(wp_config_get_option "${BROLIT_TMP_DIR}/${chosen_project}" "table_prefix")"
        database_prefix_to_restore="$(cat "${BROLIT_TMP_DIR}/${chosen_project}"/wp-config.php | grep "\$table_prefix" | cut -d \' -f 2)"
        database_prefix_actual="$(project_get_config_var "${PROJECTS_PATH}/${chosen_project}/.env" "WORDPRESS_TABLE_PREFIX")"
        if [[ ${database_prefix_to_restore} != "${database_prefix_actual}" ]]; then
          # Set new database prefix
          project_set_config_var "${PROJECTS_PATH}/${chosen_project}/.env" "WORDPRESS_TABLE_PREFIX" "${database_prefix_to_restore}" "double"
          # Rebuild docker image
          docker-compose -f "${PROJECTS_PATH}/${chosen_project}/docker-compose.yml" up --detach
          # Clear screen output
          clear_previous_lines "3"
        fi

        # TODO: update wp-config.php with .env docker stack credentials

        # Read .env to get mysql pass
        db_user_pass="$(project_get_config_var "${PROJECTS_PATH}/${chosen_project}/.env" "MYSQL_PASSWORD")"

        # Docker MySQL database import
        docker_mysql_database_import "${project_name}_mysql" "${project_name}_user" "${db_user_pass}" "${project_name}_prod" "${BROLIT_TMP_DIR}/${project_backup}"

        display --indent 6 --text "- Import database into docker volume" --result "DONE" --color GREEN

      else

        log_event "error" "Should implement restore without existing docker image!" "true"

        return 1

      fi

    else

      # Project Type
      project_type="$(project_get_type "${BROLIT_TMP_DIR}/${chosen_project}")"

      # Here, for convention, ${chosen_project} should be ${chosen_domain}... only for better code reading:
      chosen_domain="${chosen_project}"

      # Restore site files
      new_project_domain="$(restore_backup_files "${chosen_domain}")"

      # Project Install Type
      project_install_type="$(project_get_install_type "${PROJECTS_PATH}/${new_project_domain}")"

      if [[ ${project_install_type} != "proxy" && ${project_install_type} != "docker"* ]]; then
        # Change ownership
        change_ownership "www-data" "www-data" "${PROJECTS_PATH}/${new_project_domain}"
      fi

      # Extract project name from domain
      possible_project_name="$(project_get_name_from_domain "${new_project_domain}")"

      # Asking project stage with suggested actual state
      possible_project_stage=$(project_get_stage_from_domain "${new_project_domain}")
      project_stage="$(project_ask_stage "${possible_project_stage}")"
      [[ $? -eq 1 ]] && return 1

      # Asking project name
      project_name="$(project_ask_name "${possible_project_name}")"
      [[ $? -eq 1 ]] && return 1

      install_path="${PROJECTS_PATH}/${new_project_domain}"

      # DOCKER WAY (NEW)
      if [[ ${project_install_type} == "docker"* ]]; then

        # TODO: Check if docker and docker-compose are installed

        # TODO: Check ports on .env or docker-compose.yml
        project_port="$(project_ask_port "")"

        # Log
        log_event "info" "Trying to restore a docker project." "false"
        display --indent 6 --text "- Trying to restore a docker project ..." # --result "DONE" --color GREEN

        # Rebuild docker image
        docker-compose -f "${PROJECTS_PATH}/${chosen_project}/docker-compose.yml" up --detach

        # Clear screen output
        clear_previous_lines "3"

        # TODO: Check errors

      else

        project_port="default"

        # Create nginx.conf file if not exists
        touch "${PROJECTS_PATH}/${new_project_domain}/nginx.conf"

        # Reading config file

        ## Get project_type && project_install_type
        project_type="$(project_get_type "${install_path}")"
        project_install_type="$(project_get_install_type "${install_path}")"

        ## Get database information
        db_engine="$(project_get_configured_database_engine "${install_path}" "${project_type}" "${project_install_type}")"
        db_name="$(project_get_configured_database "${install_path}" "${project_type}" "${project_install_type}")"
        db_user="$(project_get_configured_database_user "${install_path}" "${project_type}" "${project_install_type}")"
        db_pass="$(project_get_configured_database_userpassw "${install_path}" "${project_type}" "${project_install_type}")"

        if [[ -n ${db_name} && ${db_name} != "no-database" ]]; then

          # Get backup rotation type (daily, weekly, monthly)
          backup_rotation_type="$(backup_get_rotation_type "${chosen_backup_to_restore}")"

          # Get backup date
          project_backup_date="$(backup_get_date "${chosen_backup_to_restore}")"

          # Download database backup
          if [[ ${backup_rotation_type} == "daily" ]]; then
            db_to_restore="${db_name}_database_${project_backup_date}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
          else
            db_to_restore="${db_name}_database_${project_backup_date}-${backup_rotation_type}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
          fi

          # Database backup full remote path
          db_to_download="${chosen_server}/projects-${chosen_status}/database/${db_name}/${db_to_restore}"

          # Downloading Database Backup
          storage_download_backup "${db_to_download}" "${BROLIT_TMP_DIR}"
          exitstatus=$?
          if [[ ${exitstatus} -eq 1 ]]; then

            # TODO: ask to download manually calling restore_database_backup or skip database restore part
            whiptail_message_with_skip_option "RESTORE BACKUP" "Database backup not found. Do you want to select manually the database backup to restore?"

            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then

              # Get dropbox backup list
              remote_backup_path="${chosen_server}/projects-${chosen_status}/database/${db_name}"
              remote_backup_list="$(storage_list_dir "${remote_backup_path}")"

              # Select Backup File
              chosen_backup_to_restore="$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup to Download" 20 78 10 $(for x in ${remote_backup_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)"
              exitstatus=$?
              if [[ ${exitstatus} -eq 1 ]]; then
                database_restore_skipped="true"
                display --indent 6 --text "- Restore project backup" --result "SKIPPED" --color YELLOW
              fi

            else
              database_restore_skipped="true"
              display --indent 6 --text "- Restore project backup" --result "SKIPPED" --color YELLOW

            fi

          fi

          if [[ ${database_restore_skipped} != "true" ]]; then
            # Decompress
            decompress "${BROLIT_TMP_DIR}/${db_to_restore}" "${BROLIT_TMP_DIR}" "${BACKUP_CONFIG_COMPRESSION_TYPE}"

            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then

              # Restore Database Backup
              [[ -z ${db_user} || "${db_user}" != "${project_name}_user" ]] && db_user="${project_name}_user"
              [[ -z ${db_pass} || "${db_user}" != "${project_name}_user" ]] && db_pass="$(openssl rand -hex 12)"

              # Restore Database Backup
              restore_backup_database "${db_engine}" "${project_stage}" "${project_name}_${project_stage}" "${db_user}" "${db_pass}" "${BROLIT_TMP_DIR}/${db_to_restore}"

              project_db_status="enabled"

            fi

          else

            return 1

          fi

        else
          # TODO: ask to download manually calling restore_database_backup or skip database restore part
          project_db_status="disabled"
        fi

      fi

    fi

    # TODO: if directory exist, it will overwrite the actual server conf.
    # Project domain configuration (webserver+certbot+DNS)
    https_enable="$(project_update_domain_config "${new_project_domain}" "${project_type}" "${project_install_type}" "${project_port}")"

    # TODO: refactor this
    if [[ ${installation_type} != "docker" || ${project_install_type} != "docker-compose" ]]; then

      # TODO: if and old project with same domain was found, ask what to do (delete old project or skip this step)

      # Post-restore/install tasks
      project_post_install_tasks "${install_path}" "${project_type}" "${project_name}" "${project_stage}" "${db_pass}" "${chosen_domain}" "${new_project_domain}"

    fi

    # Create/update brolit_project_conf.json file with project info
    project_update_brolit_config "${install_path}" "${project_name}" "${project_stage}" "${project_type}" "${project_db_status}" "${db_engine}" "${project_name}_${project_stage}" "localhost" "${db_user}" "${db_pass}" "${new_project_domain}" "" "" "" ""

    # Send notification
    send_notification "✅ ${SERVER_NAME}" "Project ${new_project_domain} restored!" "0"

  fi

}

# TODO: better name? should implement database engine option
function restore_backup_database() {

  local db_engine="${1}"
  local project_stage="${2}"
  local db_name="${3}"
  local db_user="${4}"
  local db_pass="${5}"
  local project_backup_file="${6}"

  local db_exists
  local user_db_exists

  # Log
  log_subsection "Restore Database Backup"

  # Check backup file
  project_backup="${project_backup_file%%.*}.sql"
  if [[ ! -f ${project_backup} ]]; then
    # Log
    log_event "error" "Backup file '${project_backup}' not found." "false"
    display --indent 6 --text "- Checking backup file" --result "ERROR" --color RED
    display --indent 8 --text "Backup ${project_backup} not found" --tcolor RED
    return 1
  fi

  log_event "info" "Backup file to import ${project_backup}" "false"
  #log_event "info" "Working with ${project_name}_${project_stage}" "false"

  # Check if database already exists
  mysql_database_exists "${db_name}"
  db_exists=$?
  if [[ ${db_exists} -eq 1 ]]; then
    # Create database
    mysql_database_create "${db_name}"

  else # Create temporary folder for backups

    if [[ ! -d "${BROLIT_TMP_DIR}/backups" ]]; then
      mkdir -p "${BROLIT_TMP_DIR}/backups"
      log_event "debug" "Temp files directory created: ${BROLIT_TMP_DIR}/backups" "false"
    fi

    # Make backup of actual database
    log_event "info" "MySQL database ${db_name} already exists" "false"
    mysql_database_export "${db_name}" "${BROLIT_TMP_DIR}/backups/${db_name}_bk_before_restore.sql"

  fi

  # Restore database
  mysql_database_import "${db_name}" "${project_backup}"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Deleting temp files
    rm --force "${project_backup%%.*}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}" && rm --force "${project_backup}"

    # Log
    log_event "debug" "Temp files cleanned" "false"
    display --indent 6 --text "- Cleanning temp files" --result "DONE" --color GREEN

  else
    return 1
  fi

  # Check if user database already exists
  mysql_user_exists "${db_user}"
  user_db_exists=$?
  if [[ ${user_db_exists} -eq 0 ]]; then
    # Create database user with autogenerated pass
    mysql_user_create "${db_user}" "${db_pass}" "localhost"

  else

    # Log
    log_event "warning" "MySQL user ${db_user} already exists" "false"
    display --indent 6 --text "- Creating ${db_user} user in MySQL" --result "FAIL" --color RED
    display --indent 8 --text "MySQL user already exists" --tcolor YELLOW

    whiptail_message "WARNING" "MySQL user ${db_user} already exists. Please after the script ends, check project configuration files."

  fi

  # Grant privileges to database user
  mysql_user_grant_privileges "${db_user}" "${db_name}" "localhost"

}
