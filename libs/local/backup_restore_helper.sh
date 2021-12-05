#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.6
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
#   $1 = ${folder_to_backup}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _make_temp_files_backup() {

  local folder_to_backup=$1

  display --indent 6 --text "- Creating backup on temp directory"

  # Moving project files to temp directory
  mkdir "${SFOLDER}/tmp/old_backups"
  mv "${folder_to_backup}" "${SFOLDER}/tmp/old_backups"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Log
    clear_previous_lines "1"
    log_event "info" "Temp backup completed and stored here: ${SFOLDER}/tmp/old_backups" "false"
    display --indent 6 --text "- Creating backup on temp directory" --result "DONE" --color GREEN

    return 0

  else

    # Log
    display --indent 6 --text "-- ERROR: Could not move project files to temp directory"

    return 1

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
# Restore backup from local file
#
# Arguments:
#   $1 = ${folder_to_backup}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_backup_from_local_file() {

  local -n restore_type # whiptail array options
  local chosen_restore_type

  restore_type=(
    "01)" "RESTORE FILES"
    "02)" "RESTORE DATABASE"
  )
  chosen_restore_type="$(whiptail --title "RESTORE FROM LOCAL" --menu " " 20 78 10 "${restore_type[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_restore_type} == *"01"* ]]; then

      # RESTORE FILES
      log_subsection "Restore files from local"

      # Folder where sites are hosted: $PROJECTS_PATH
      menu_title="SELECT BACKUP FILE TO RESTORE"
      file_browser "${menu_title}" "${PROJECTS_PATH}"

      # Directory_broser returns: " $filepath"/"$filename
      if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

        log_event "info" "Operation cancelled!" "false"

        # Return
        #return 1

      else

        log_event "info" "File to restore: ${filename}" "false"

        # Check if file is compressed
        is_compressed="$(file "${filename}" | grep "compressed")"

        if [[ ${is_compressed} != "" ]]; then

          # Decompress backup
          decompress "${chosen_backup_to_restore}" "${SFOLDER}/tmp/" "lbzip2"

          # TODO: search for .sql or sql.gz files

          # We don't have a domain yet so let "restore_site_files" ask
          restore_site_files ""

        # TODO: i need to do a refactor of restore_site_files to accept
        # domain, path_to_restore, backup_file

        # TODO: restore_type_selection_from_dropbox needs a refactor too

        else

          # Log
          log_event "error" "File selected is not a backup file!" "false"
          display --indent 6 --text "- Backup selection" --result "FAIL" --color RED
          display --indent 8 --text "File selected is not a backup file!"

        fi

      fi

    fi

    if [[ ${chosen_restore_type} == *"02"* ]]; then

      #RESTORE DATABASE
      log_subsection "Restore database from file"

      # Folder where sites are hosted: $PROJECTS_PATH
      menu_title="SELECT BACKUP FILE TO RESTORE"
      file_browser "${menu_title}" "${PROJECTS_PATH}"

      # Directory_broser returns: " $filepath"/"$filename
      if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

        log_event "info" "Operation cancelled!" "false"

        # Return
        #return 1

      else

        log_event "info" "File to restore: ${filepath}/${filename}" "false"

        # Copy to tmp dir
        cp "${filepath}/${filename}" "${TMP_DIR}"

        project_name="$(ask_project_name "")"
        project_state="$(ask_project_state "")"

        restore_database_backup "${project_name}" "${project_state}" "${filename}"

      fi

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
    log_subsection "Restore files from ftp"

    # Ask project state
    project_state="$(ask_project_state "prod")"

    # Ask project domain
    project_domain="$(ask_project_domain "")"

    possible_project_domain="$(project_get_name_from_domain "${project_domain}")"

    # Ask project name
    project_name="$(ask_project_name "${possible_project_domain}")"

    # FTP
    ftp_domain="$(whiptail_imput "FTP SERVER IP/DOMAIN" "Please insert de FTP server IP/DOMAIN. Ex: ftp.domain.com")"
    ftp_path="$(whiptail_imput "FTP SERVER PATH" "Please insert de FTP server path. Ex: /htdocs/website")"
    ftp_user="$(whiptail_imput "FTP SERVER USER" "Please insert de FTP user.")"
    ftp_pass="$(whiptail_imput "FTP SERVER PASS" "Please insert de FTP password.")"

    ## Download files from ftp
    ftp_download "${ftp_domain}" "${ftp_path}" "${ftp_user}" "${ftp_pass}" "${TMP_DIR}/${project_domain}"

    # Search for .sql or sql.gz files
    local find_result

    # Find backups from downloaded ftp files
    find_result="$({
      find "${TMP_DIR}/${project_domain}" -name "*.sql"
      find "${TMP_DIR}/${project_domain}" -name "*.sql.gz"
    })"

    if [[ ${find_result} != "" ]]; then

      log_event "info" "Database backups found on downloaded files" "false"

      array_to_checklist "${find_result}"

      # Backup file selection
      chosen_database_backup="$(whiptail --title "DATABASE TO RESTORE" --checklist "Select the database backup you want to restore." 20 78 15 "${checklist_array[@]}" 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Restore database
        restore_database_backup "${project_name}" "${project_state}" "${chosen_database_backup}"

      else

        log_event "info" "Database backup selection skipped" "false"
        display --indent 6 --text "- Database backup selection" --result "SKIPPED" --color YELLOW

      fi

    fi

    # Restore files
    move_files "${TMP_DIR}/${project_domain}" "${PROJECTS_PATH}"

  fi

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

  local dropbox_server_list # list servers directories on dropbox
  local chosen_server       # whiptail var

  # Select SERVER
  dropbox_server_list="$("${DROPBOX_UPLOADER}" -hq list "/" | awk '{print $2;}')"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Show dropbox output
    chosen_server="$(whiptail --title "RESTORE BACKUP" --menu "Choose Server to work with" 20 78 10 $(for x in ${dropbox_server_list}; do echo "${x} [D]"; done) 3>&1 1>&2 2>&3)"

    log_event "debug" "chosen_server: ${chosen_server}" "false"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # List dropbox directories
      dropbox_type_list="$(${DROPBOX_UPLOADER} -hq list "${chosen_server}" | awk '{print $2;}')"
      dropbox_type_list='project '${dropbox_type_list}

      # Select backup type
      restore_type_selection_from_dropbox "${chosen_server}" "${dropbox_type_list}"

    else

      restore_manager_menu

    fi

  else

    log_event "error" "Dropbox uploader failed. Output: ${dropbox_server_list}. Exit status: ${exitstatus}" "false"

  fi

  restore_manager_menu

}

################################################################################
# Restore database backup
#
# Arguments:
#   $1 = ${project_name}
#   $2 = ${project_state}
#   $3 = ${project_backup} - The backup file must be in ${TMP_DIR}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_database_backup() {

  local project_name=$1
  local project_state=$2
  local project_backup=$3

  local db_name
  local db_exists
  local user_db_exists
  local db_pass

  log_subsection "Restore Database Backup"

  db_name="${project_name}_${project_state}"

  # Check if database already exists
  mysql_database_exists "${db_name}"
  db_exists=$?
  if [[ ${db_exists} -eq 1 ]]; then
    # Create database
    mysql_database_create "${db_name}"

  else

    # Create temporary folder for backups
    if [[ ! -d "${TMP_DIR}/backups" ]]; then
      mkdir "${TMP_DIR}/backups"
      log_event "info" "Temp files directory created: ${TMP_DIR}/backups" "false"
    fi

    # Make backup of actual database
    log_event "info" "MySQL database ${db_name} already exists" "false"
    mysql_database_export "${db_name}" "${TMP_DIR}/backups/${db_name}_bk_before_restore.sql"

  fi

  # Restore database
  project_backup="${project_backup%%.*}.sql"
  mysql_database_import "${project_name}_${project_state}" "${TMP_DIR}/${project_backup}"

  if [[ ${exitstatus} -eq 0 ]]; then
    # Deleting temp files
    rm --force "${project_backup%%.*}.tar.bz2"
    rm --force "${project_backup}"

    # Log
    log_event "info" "Temp files cleanned" "false"
    display --indent 6 --text "- Cleanning temp files" --result "DONE" --color GREEN

    return 0

  else

    return 1

  fi

}

################################################################################
# Restore database backup
#
# Arguments:
#   $1 = ${dropbox_chosen_type_path}
#   $2 = ${dropbox_project_list}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_config_files_from_dropbox() {

  local dropbox_chosen_type_path=$1
  local dropbox_project_list=$2

  local chosen_config_type # whiptail var
  local dropbox_bk_list    # dropbox backup list
  local chosen_config_bk   # whiptail var

  log_subsection "Restore Server config Files"

  # Select config backup type
  chosen_config_type="$(whiptail --title "RESTORE CONFIGS BACKUPS" --menu "Choose a config backup type." 20 78 10 $(for x in ${dropbox_project_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    #Restore from Dropbox
    dropbox_bk_list="$(${DROPBOX_UPLOADER} -hq list "${dropbox_chosen_type_path}/${chosen_config_type}" | awk '{print $2;}')"
  fi

  chosen_config_bk="$(whiptail --title "RESTORE CONFIGS BACKUPS" --menu "Choose a config backup file to restore." 20 78 10 $(for x in ${dropbox_bk_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    cd "${SFOLDER}/tmp"

    # Downloading Config Backup
    display --indent 6 --text "- Downloading config backup from dropbox"

    dropbox_output="$(${DROPBOX_UPLOADER} download "${dropbox_chosen_type_path}/${chosen_config_type}/${chosen_config_bk}" 1>&2)"

    clear_previous_lines "1"
    display --indent 6 --text "- Downloading config backup from dropbox" --result "DONE" --color GREEN

    # Restore files
    mkdir "${chosen_config_type}"
    mv "${chosen_config_bk}" "${chosen_config_type}"
    cd "${chosen_config_type}"

    # Decompress
    decompress "${chosen_config_bk}" "${SFOLDER}/tmp/${chosen_config_type}" "lbzip2"

    if [[ "${chosen_config_bk}" == *"nginx"* ]]; then

      restore_nginx_site_files "" ""

    fi
    if [[ "${CHOSEN_CONFIG}" == *"mysql"* ]]; then
      log_event "info" "MySQL Config backup downloaded and uncompressed on  ${SFOLDER}/tmp/${chosen_config_type}"
      whiptail_message "IMPORTANT!" "MySQL config files were downloaded on this temp directory: ${SFOLDER}/tmp/${chosen_config_type}."

    fi
    if [[ "${CHOSEN_CONFIG}" == *"php"* ]]; then
      log_event "info" "PHP config backup downloaded and uncompressed on  ${SFOLDER}/tmp/${chosen_config_type}"
      whiptail_message "IMPORTANT!" "PHP config files were downloaded on this temp directory: ${SFOLDER}/tmp/${chosen_config_type}."

    fi
    if [[ "${CHOSEN_CONFIG}" == *"letsencrypt"* ]]; then
      log_event "info" "Let's Encrypt config backup downloaded and uncompressed on  ${SFOLDER}/tmp/${chosen_config_type}"
      whiptail_message "IMPORTANT!" "Let's Encrypt config files were downloaded on this temp directory: ${SFOLDER}/tmp/${chosen_config_type}."

    fi

    # TODO: ask for remove tmp files
    #echo " > Removing ${SFOLDER}/tmp/${chosen_type} ..." >>$LOG
    #echo -e ${GREEN}" > Removing ${SFOLDER}/tmp/${chosen_type} ..."${ENDCOLOR}
    #rm -R ${SFOLDER}/tmp/${chosen_type}

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

  local domain=$1
  local date=$2

  local bk_file
  local bk_to_download
  local filename
  local to_restore
  local dropbox_output # var for dropbox output

  bk_file="nginx-configs-files-${date}.tar.bz2"
  bk_to_download="${chosen_server}/configs/nginx/${bk_file}"

  # Subsection
  log_subsection "Nginx Server Configuration Restore"

  # Downloading Config Backup
  log_event "info" "Downloading nginx backup from dropbox" "false"
  display --indent 6 --text "- Downloading nginx backup from dropbox"

  dropbox_output="$(${DROPBOX_UPLOADER} download "${bk_to_download}" 1>&2)"

  clear_previous_lines "1"
  display --indent 6 --text "- Downloading nginx backup from dropbox" --result "DONE" --color GREEN

  # Extract tar.bz2 with lbzip2
  mkdir "${SFOLDER}/tmp/nginx"
  decompress "${bk_file}" "${SFOLDER}/tmp/nginx" "lbzip2"

  # TODO: if nginx is installed, ask if nginx.conf must be replace

  # Checking if default nginx folder exists
  if [[ -n "${WSERVER}" ]]; then

    log_event "info" "Folder ${WSERVER} exists ... OK"

    if [[ -z "${domain}" ]]; then

      startdir="${SFOLDER}/tmp/nginx/sites-available"
      file_browser "$menutitle" "$startdir"

      to_restore=${filepath}"/"${filename}
      log_event "info" "File to restore: ${to_restore} ..."

    else

      to_restore="${SFOLDER}/tmp/nginx/sites-available/${domain}"
      filename=${domain}

      log_event "info" "File to restore: ${to_restore} ..."

    fi

    if [[ -f "${WSERVER}/sites-available/${filename}" ]]; then

      log_event "info" "File ${WSERVER}/sites-available/${filename} already exists. Making a backup file ..."
      mv "${WSERVER}/sites-available/${filename}" "${WSERVER}/sites-available/${filename}_bk"

      display --indent 6 --text "- Making backup of existing config" --result "DONE" --color GREEN

    fi

    log_event "info" "Restoring nginx configuration from backup: ${filename}"

    # Copy files
    cp "${to_restore}" "${WSERVER}/sites-available/${filename}"

    # Creating symbolic link
    ln -s "${WSERVER}/sites-available/${filename}" "${WSERVER}/sites-enabled/${filename}"

    #display --indent 6 --text "- Restoring Nginx server config" --result "DONE" --color GREEN
    #nginx_server_change_domain "${WSERVER}/sites-enabled/${filename}" "${domain}" "${domain}"

    nginx_configuration_test

  else

    log_event "error" "/etc/nginx/sites-available NOT exist... Skipping!"
    #echo "ERROR: nginx main dir is not present!"

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

  local domain=$1
  local date=$2

  local bk_file
  local bk_to_download

  bk_file="letsencrypt-configs-files-${date}.tar.bz2"
  bk_to_download="${chosen_server}/configs/letsencrypt/${bk_file}"

  log_event "debug" "Running: ${DROPBOX_UPLOADER} download ${bk_to_download}"

  dropbox_output=$(${DROPBOX_UPLOADER} download "${bk_to_download}" 1>&2)

  # Extract tar.bz2 with lbzip2
  log_event "info" "Extracting ${bk_file} on ${SFOLDER}/tmp/"

  mkdir "${SFOLDER}/tmp/letsencrypt"
  decompress "${bk_file}" "${SFOLDER}/tmp/letsencrypt" "lbzip2"

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
    cp -r "${SFOLDER}/tmp/letsencrypt/options-ssl-nginx.conf" "/etc/letsencrypt/"

  fi
  if [[ ! -f "/etc/letsencrypt/ssl-dhparams.pem" ]]; then
    cp -r "${SFOLDER}/tmp/letsencrypt/ssl-dhparams.pem" "/etc/letsencrypt/"

  fi

  # TODO: Restore main files (checking non-www and www domains)
  if [[ ! -f "${SFOLDER}/tmp/letsencrypt/archive/${domain}" ]]; then
    cp -r "${SFOLDER}/tmp/letsencrypt/archive/${domain}" "/etc/letsencrypt/archive/"

  fi
  if [[ ! -f "${SFOLDER}/tmp/letsencrypt/live/${domain}" ]]; then
    cp -r "${SFOLDER}/tmp/letsencrypt/live/${domain}" "/etc/letsencrypt/live/"

  fi

  display --indent 6 --text "- Restoring letsencrypt config files" --result "DONE" --color GREEN

}

################################################################################
# Restore site files
#
# Arguments:
#   $1 = ${chosen_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_site_files() {

  # $1 = ${chosen_domain} Here, should match with PROJECT_DOMAIN

  local domain=$1

  local actual_folder
  local folder_to_install
  local chosen_domain

  log_subsection "Restore Files Backup"

  chosen_domain="$(whiptail --title "Project Domain" --inputbox "Want to change the project's domain? Default:" 10 60 "${domain}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Log
    log_event "info" "Working with domain: ${chosen_domain}"
    display --indent 6 --text "- Selecting project domain" --result "DONE" --color GREEN
    display --indent 8 --text "${chosen_domain}" --tcolor YELLOW

    # If user change project domains, we need to do this
    project_tmp_old_folder="${SFOLDER}/tmp/${domain}"
    project_tmp_new_folder="${SFOLDER}/tmp/${chosen_domain}"

    # Renaming
    if [[ ${project_tmp_old_folder} != "${project_tmp_new_folder}" ]]; then
      mv "${project_tmp_old_folder}" "${project_tmp_new_folder}"
    fi

    # Ask folder to install
    folder_to_install="$(ask_folder_to_install_sites "${PROJECTS_PATH}")"

    # New destination directory
    actual_folder="${folder_to_install}/${chosen_domain}"

    # Check if destination folder exist
    if [[ -d ${actual_folder} ]]; then

      # If exists, make a backup
      _make_temp_files_backup "${actual_folder}"

    fi

    # Restore files
    move_files "${project_tmp_new_folder}" "${folder_to_install}"

    # TODO: we need another aproach for other kind of projects
    # Search wp-config.php (to find wp installation on sub-folders)
    install_path="$(wp_config_path "${actual_folder}")"

    log_event "info" "install_path=${install_path}" "false"

    display --indent 8 --text "Restored on: ${install_path}"

    if [[ -d "${install_path}" ]]; then

      log_event "info" "Wordpress intallation found on: ${install_path}" "false"
      log_event "info" "Files backup restored on: ${install_path}" "false"

      wp_change_permissions "${install_path}"

      # Return
      echo "${chosen_domain}"

    fi

  else

    return 1

  fi

}

################################################################################
# Restore type selection from dropbox
#
# Arguments:
#   $1 = ${chosen_server}
#   $2 = ${dropbox_type_list}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_type_selection_from_dropbox() {

  # TODO: check project type (WP? Laravel? other?)
  # ask for directory_browser if apply
  # add credentials on external txt and send email

  local chosen_server=$1
  local dropbox_type_list=$2

  local chosen_type                # whiptail var
  local chosen_backup_to_restore   # whiptail var
  local dropbox_chosen_type_path   # whiptail var
  local dropbox_project_list       # list of projects on dropbox directory
  local dropbox_chosen_backup_path # whiptail var
  local dropbox_backup_list        # dropbox listing directories
  local domain                     # extracted domain
  local db_project_name            # extracted db name
  local bk_to_dowload              # backup to download
  local folder_to_install          # directory to install project
  local project_site               # project site

  chosen_type="$(whiptail --title "RESTORE FROM BACKUP" --menu "Choose a backup type. You can choose restore an entire project or only site files, database or config." 20 78 10 $(for x in ${dropbox_type_list}; do echo "${x} [D]"; done) 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    dropbox_chosen_type_path="${chosen_server}/${chosen_type}"

    if [[ ${chosen_type} == "project" ]]; then

      restore_project "${chosen_server}"

    elif [[ ${chosen_type} != "project" ]]; then

      log_subsection "Restore ${chosen_type} Backup"

      dropbox_project_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_chosen_type_path}" | awk '{print $2;}')"

      if [[ ${chosen_type} == *"configs"* ]]; then

        restore_config_files_from_dropbox "${dropbox_chosen_type_path}" "${dropbox_project_list}"

      else # DB or SITE

        # Select Project
        chosen_project="$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup Project" 20 78 10 $(for x in ${dropbox_project_list}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
          dropbox_chosen_backup_path="${dropbox_chosen_type_path}/${chosen_project}"
          dropbox_backup_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_chosen_backup_path}" | awk '{print $3;}')"

        fi
        # Select Backup File
        chosen_backup_to_restore="$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup to Download" 20 78 10 $(for x in ${dropbox_backup_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          bk_to_dowload="${chosen_server}/${chosen_type}/${chosen_project}/${chosen_backup_to_restore}"

          # Downloading Backup
          dropbox_download "${bk_to_dowload}" "${TMP_DIR}"

          # Decompress
          decompress "${TMP_DIR}/${chosen_backup_to_restore}" "${TMP_DIR}" "lbzip2"

          if [[ ${chosen_type} == *"database"* ]]; then

            # Asking project state with suggested actual state
            suffix=${chosen_project%_*} ## strip the tail
            project_state="$(ask_project_state "${suffix}")"

            # Extract project_name (it will remove last part of db name with "_" char)
            possible_project_name=${chosen_project%"_$suffix"}
            project_name="$(ask_project_name "${possible_project_name}")"

            # Running mysql_name_sanitize $for project_name
            db_project_name="$(mysql_name_sanitize "${project_name}")"

            # Restore database
            restore_database_backup "${db_project_name}" "${project_state}" "${chosen_backup_to_restore}"

            db_user="${db_project_name}_user"

            # Check if user database already exists
            mysql_user_exists "${db_user}"
            user_db_exists=$?
            if [[ ${user_db_exists} -eq 0 ]]; then

              # Passw generator
              db_pass="$(openssl rand -hex 12)"

              # Create database user with autogenerated pass
              mysql_user_create "${db_user}" "${db_pass}" ""

            else

              # User already exists

              # Log
              display --indent 6 --text "- Create MySQL user" --result "FAIL" --color RED
              display --indent 8 --text "MySQL user ${db_user} already exists" --tcolor YELLOW --tstyle ITALIC
              display --indent 8 --text "After the script ends, check project configuration files" --tcolor YELLOW --tstyle ITALIC

              log_event "warning" "MySQL user ${db_user} already exists. Please after the script ends, check project configuration files." "false"

            fi

            # Grant privileges to database user
            mysql_user_grant_privileges "${db_user}" "${db_project_name}_${project_state}" ""

            # TODO: ask if want to change project db parameters and make cloudflare changes

            # TODO: check project type (WP, Laravel, etc)

            folder_to_install="$(ask_folder_to_install_sites "${PROJECTS_PATH}")"
            folder_to_install_result=$?
            if [[ ${folder_to_install_result} -eq 1 ]]; then

              return 0

            fi

            startdir="${folder_to_install}"
            menutitle="Site Selection Menu"
            directory_browser "${menutitle}" "${startdir}"

            directory_browser_result=$?
            if [[ ${directory_browser_result} -eq 1 ]]; then

              return 0

            fi

            project_site=$filepath"/"$filename
            install_path="$(wp_config_path "${folder_to_install}/${filename}")"

            if [[ "${install_path}" != "" ]]; then

              # Select wordpress installation to work with
              project_path="$(wordpress_select_project_to_work_with "${install_path}")"

              log_event "info" "WordPress installation found: ${project_path}" "false"

              # Change wp-config.php database parameters
              wp_update_wpconfig "${project_path}" "${project_name}" "${project_state}" "${db_pass}"

              # Change Salts
              wpcli_set_salts "${project_path}"

              # Change URLs
              wp_ask_url_search_and_replace "${project_path}"
              #wpcli_search_and_replace "${project_path}" "${chosen_domain}" "${new_project_domain}"

              # Changing wordpress visibility
              if [[ ${project_state} == "prod" ]]; then

                wpcli_change_wp_seo_visibility "${project_path}" "1"

              else

                wpcli_change_wp_seo_visibility "${project_path}" "0"

              fi

            else

              log_event "error" "WordPress installation not found" "false"

            fi

          else
            # site

            # At this point chosen_project is the new project domain
            restore_site_files "${chosen_project}"

          fi

        fi

      fi

    fi

  fi

}

################################################################################
# Restore project
#
# Arguments:
#   $1 = ${chosen_server}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function restore_project() {

  local chosen_server=$1

  local dropbox_project_list
  local chosen_project
  local dropbox_chosen_backup_path
  local dropbox_backup_list
  local bk_to_dowload
  local chosen_backup_to_restore
  local db_to_download

  log_section "Restore Project Backup"

  # Get dropbox folders list
  dropbox_project_list="$(${DROPBOX_UPLOADER} -hq list "${chosen_server}/site" | awk '{print $2;}')"

  # Select Project
  chosen_project="$(whiptail --title "RESTORE PROJECT BACKUP" --menu "Choose Backup Project" 20 78 10 $(for x in ${dropbox_project_list}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Get dropbox backup list
    dropbox_chosen_backup_path="${chosen_server}/site/${chosen_project}"
    dropbox_backup_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_chosen_backup_path}" | awk '{print $3;}')"

  else

    display --indent 2 --text "- Restore project backup" --result "SKIPPED" --color YELLOW

    return 1

  fi

  # Select Backup File
  chosen_backup_to_restore="$(whiptail --title "RESTORE PROJECT BACKUP" --menu "Choose Backup to Download" 20 78 10 $(for x in ${dropbox_backup_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    display --indent 6 --text "- Selecting project backup" --result "DONE" --color GREEN
    display --indent 8 --text "${chosen_backup_to_restore}" --tcolor YELLOW

    # Download backup
    bk_to_dowload="${chosen_server}/site/${chosen_project}/${chosen_backup_to_restore}"
    dropbox_download "${bk_to_dowload}" "${TMP_DIR}"

    # Decompress
    decompress "${TMP_DIR}/${chosen_backup_to_restore}" "${TMP_DIR}" "lbzip2"

    # Project Type
    project_type="$(project_get_type "${TMP_DIR}/${chosen_project}")"

    log_event "debug" "Project Type: ${project_type}" "false"

    # Here, for convention, chosen_project should be CHOSEN_DOMAIN...
    # Only for better code reading, i assign this new var:
    chosen_domain="${chosen_project}"

    # TODO: Read from /etc/brolit/${project_name}_conf.json if not present call a function to do this:
    case ${project_type} in

    wordpress)

      display --indent 6 --text "Project Type WordPress" --tcolor GREEN

      # Reading config file
      db_name="$(project_get_configured_database "${TMP_DIR}/${chosen_project}" "${project_type}")"
      db_user="$(project_get_configured_database_user "${TMP_DIR}/${chosen_project}" "${project_type}")"
      db_pass="$(project_get_configured_database_userpassw "${TMP_DIR}/${chosen_project}" "${project_type}")"

      # Restore site files
      new_project_domain="$(restore_site_files "${chosen_domain}")"

      project_path="${PROJECTS_PATH}/${new_project_domain}"
      install_path="$(wp_config_path "${project_path}")"

      # TODO: wp_config_path could be an array of dir paths, need to check that
      if [[ ${install_path} != "" ]]; then

        log_event "info" "WordPress installation found: ${project_site}/${install_path}" "false"

      else

        log_event "error" "WordPress installation not found" "false"

        return 1

      fi

      ;;

    laravel)

      display --indent 6 --text "Project Type Laravel" --tcolor RED
      ;;

    *)

      display --indent 6 --text "Project Type Unknown" --tcolor RED

      return 1
      ;;

    esac

    # Database Backup
    backup_date="$(echo "${chosen_backup_to_restore}" | grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}')"
    db_to_download="${chosen_server}/database/${db_name}/${db_name}_database_${backup_date}.tar.bz2"

    # Log
    log_event "debug" "Project database selected: ${chosen_project}" "false"
    log_event "debug" "Backup date: ${backup_date}" "false"

    if [[ ${db_name} != "" ]]; then

      # Downloading Database Backup
      dropbox_download "${db_to_download}" "${TMP_DIR}"

      exitstatus=$?
      if [[ ${exitstatus} -eq 1 ]]; then

        # TODO: ask to download manually calling restore_database_backup or skip database restore part

        return 1

      fi

    else

      # TODO: ask to download manually calling restore_database_backup or skip database restore part

      return 1

    fi

    # Decompress
    decompress "${TMP_DIR}/${db_name}_database_${backup_date}.tar.bz2" "${TMP_DIR}" "lbzip2"

    # Extract project name from domain
    possible_project_name="$(project_get_name_from_domain "${new_project_domain}")"

    # Asking project state with suggested actual state
    suffix=${chosen_project%_*} ## strip the tail
    project_state="$(ask_project_state "${suffix}")"

    # Asking project name
    project_name="$(ask_project_name "${possible_project_name}")"

    # Sanitize ${project_name}
    db_project_name="$(mysql_name_sanitize "${project_name}")"

    # Restore database function
    restore_database_backup "${db_project_name}" "${project_state}" "${db_name}_database_${backup_date}.tar.bz2"

    # Database parameters
    db_name="${db_project_name}_${project_state}"
    db_user="${db_project_name}_user"

    # Check if user database already exists
    mysql_user_exists "${db_user}"
    user_db_exists=$?
    if [[ ${user_db_exists} -eq 0 ]]; then

      # Create MySQL user
      db_pass="$(openssl rand -hex 12)"
      mysql_user_create "${db_user}" "${db_pass}" ""

    else

      # Log
      log_event "warning" "MySQL user ${db_user} already exists" "false"
      display --indent 6 --text "- Creating ${db_user} user in MySQL" --result "FAIL" --color RED
      display --indent 8 --text "MySQL user ${db_user} already exists."

      whiptail_message "WARNING" "MySQL user ${db_user} already exists. Please after the script ends, check project configuration files."

    fi

    # Grant privileges to database user
    mysql_user_grant_privileges "${db_user}" "${db_name}" ""

    possible_root_domain="$(get_root_domain "${new_project_domain}")"
    root_domain="$(ask_root_domain "${possible_root_domain}")"

    # TODO: if ${new_project_domain} == ${chosen_domain}, maybe ask if want to restore nginx and let's encrypt config files
    # restore_letsencrypt_site_files "${chosen_domain}" "${backup_date}"
    # restore_nginx_site_files "${chosen_domain}" "${backup_date}"

    if [[ ${new_project_domain} == "${root_domain}" || ${new_project_domain} == "www.${root_domain}" ]]; then

      # Nginx config
      nginx_server_create "www.${root_domain}" "${project_type}" "root_domain" "${root_domain}"

      # Cloudflare API
      # TODO: must check for CNAME with www
      cloudflare_set_record "${root_domain}" "${root_domain}" "A"

      # Let's Encrypt
      certbot_certificate_install "${NOTIFICATION_EMAIL_MAILA}" "${root_domain},www.${root_domain}"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        nginx_server_add_http2_support "${root_domain}"

      fi

    else

      # TODO: remove hardcoded parameters "wordpress" and "single"

      # Nginx config
      nginx_server_create "${new_project_domain}" "${project_type}" "single"

      # Cloudflare API
      cloudflare_set_record "${root_domain}" "${new_project_domain}" "A"

      # Let's Encrypt
      certbot_certificate_install "${NOTIFICATION_EMAIL_MAILA}" "${new_project_domain}"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        nginx_server_add_http2_support "${new_project_domain}"

      fi

    fi

    # Check if is a WP project

    if [[ ${project_type} == "wordpress" ]]; then

      # Change wp-config.php database parameters
      wp_update_wpconfig "${install_path}" "${db_project_name}" "${project_state}" "${db_pass}"

      # Change urls on database
      # TODO: non protocol before domains (need to check if http or https before)?
      if [[ ${chosen_domain} != "${new_project_domain}" ]]; then

        # Change urls on database
        wpcli_search_and_replace "${install_path}" "${chosen_domain}" "${new_project_domain}"

      fi

      # Shuffle salts
      wpcli_set_salts "${install_path}"

      # Changing wordpress visibility
      if [[ ${project_state} == "prod" ]]; then
        wpcli_change_wp_seo_visibility "${install_path}" "1"

      else
        wpcli_change_wp_seo_visibility "${install_path}" "0"

      fi

    fi

    # Send notification
    send_notification "✅ ${VPSNAME}" "Project ${new_project_domain} restored!"

  fi

}
