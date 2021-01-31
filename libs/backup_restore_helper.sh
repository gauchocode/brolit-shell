#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.12
################################################################################

#
#################################################################################
#
# * Private Funtions
#
#################################################################################
#

# This is executed if we want to restore a file backup on directory with the same name
function _make_temp_files_backup() {

  # $1 = Folder to backup

  local folder_to_backup=$1

  display --indent 6 --text "- Creating backup on temp directory"

  # Moving project files to temp directory
  mkdir "${SFOLDER}/tmp/old_backup"
  mv "${folder_to_backup}" "${SFOLDER}/tmp/old_backup"

  # Log
  log_event "info" "Temp backup completed and stored here: ${SFOLDER}/tmp/old_backup"
  clear_last_line
  display --indent 6 --text "- Creating backup on temp directory" --result "DONE" --color GREEN

}

#
#################################################################################
#
# * Public Funtions
#
#################################################################################
#

function restore_backup_menu () {

  local -n restore_options          # whiptail array options
  local chosen_restore_options      # whiptail var

  restore_options=(
    "01)" "RESTORE FROM DROPBOX" 
    "02)" "RESTORE FROM URL (BETA)"
    "03)" "RESTORE FROM FILE"
    )
  chosen_restore_options=$(whiptail --title "RESTORE TYPE" --menu " " 20 78 10 "${restore_options[@]}" 3>&1 1>&2 2>&3)
  exitstatus="$?"
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_restore_options} == *"01"* ]]; then
      restore_backup_server_selection

    fi
    if [[ ${chosen_restore_options} == *"02"* ]]; then
      # shellcheck source=${SFOLDER}/utils/wordpress_restore_from_source.sh
      source "${SFOLDER}/utils/wordpress_restore_from_source.sh"

    fi
    if [[ ${chosen_restore_options} == *"03"* ]]; then
      restore_backup_from_file

    fi

  fi

  menu_main_options

}

function restore_backup_from_file() {

  local -n restore_type       # whiptail array options
  local chosen_restore_type

  restore_type=(
    "01)" "RESTORE FILES" 
    "02)" "RESTORE DATABASE"
    )
  chosen_restore_type=$(whiptail --title "RESTORE TYPE" --menu " " 20 78 10 "${restore_type[@]}" 3>&1 1>&2 2>&3)
  exitstatus="$?"
  if [[ ${exitstatus} -eq 0 ]]; then
    
    if [[ ${chosen_restore_type} == *"01"* ]]; then

      # RESTORE FILES
      log_subsection "Restore from file"
      
      # Folder where sites are hosted: $SITES
      menu_title="SELECT BACKUP FILE TO RESTORE"
      file_browser "${menu_title}" "${SITES}"

      # Directory_broser returns: " $filepath"/"$filename
      if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

        log_event "info" "Operation cancelled!"

        # Return
        #return 1
      
      else

        log_event "info" "File to restore: ${filename}"
        #restore_site_files

        # TODO: i need to do a refactor of restore_site_files to accept
        # domain, path_to_restore, backup_file

        # TODO: restore_type_selection_from_dropbox needs a refactor too

        # TODO: make a function with: 
        # pv --width 70 "${chosen_backup_to_restore}" | tar xp -C "${SFOLDER}/tmp/" --use-compress-program=lbzip2


      fi

    fi
    if [[ ${chosen_restore_type} == *"02"* ]]; then

      #RESTORE DATABASE

      # Folder where sites are hosted: $SITES
      menu_title="SELECT BACKUP FILE TO RESTORE"
      file_browser "${menu_title}" "${SITES}"

      # Directory_broser returns: " $filepath"/"$filename
      if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

        log_event "info" "Operation cancelled!"

        # Return
        #return 1
      
      else

        log_event "info" "File to restore: ${filename}"

        project_name="$(ask_project_name "")"
        project_state="$(ask_project_state "")"
      
        restore_database_backup "${project_name}" "${project_state}" "${filename}"
      
      fi

    fi

  fi

}

function restore_backup_server_selection () {

  SITES_F="site"
  CONFIG_F="configs"
  DBS_F="database"

  local dropbox_server_list   # list servers directories on dropbox
  local chosen_server         # whiptail var
  
  # Select SERVER
  dropbox_server_list=$("${DROPBOX_UPLOADER}" -hq list "/")
  chosen_server=$(whiptail --title "RESTORE BACKUP" --menu "Choose Server to work with" 20 78 10 $(for x in ${dropbox_server_list}; do echo "${x} [D]"; done) 3>&1 1>&2 2>&3)
  exitstatus="$?"
  if [[ ${exitstatus} -eq 0 ]]; then

    dropbox_type_list="$(${DROPBOX_UPLOADER} -hq list "${chosen_server}")"
    dropbox_type_list='project '${dropbox_type_list}

    # Select backup type
    restore_type_selection_from_dropbox "${chosen_server}" "${dropbox_type_list}"

  else
    restore_backup_menu
    
  fi

  restore_backup_menu

}

function restore_database_backup() {

  #$1 = ${project_name}
  #$2 = ${project_state}
  #$3 = ${project_backup}

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
  db_exists="$?"
  if [[ ${db_exists} -eq 1 ]]; then  
    # Create database
    mysql_database_create "${db_name}"

  else
    # Make backup of actual database
    log_event "info" "MySQL database ${db_name} already exists"
    mysql_database_export "${db_name}" "${db_name}_bk_before_restore.sql"

  fi

  # Restore database
  project_backup="${project_backup%%.*}.sql"
  mysql_database_import "${project_name}_${project_state}" "${project_backup}"
  
  # Deleting temp files
  rm -f "${project_backup%%.*}.tar.bz2"
  rm -f "${project_backup}"
  display --indent 6 --text "- Cleanning temp files" --result "DONE" --color GREEN
  log_event "info" "Temp files cleanned"

}

function restore_config_files_from_dropbox(){

  #$1 = ${dropbox_chosen_type_path}
  #$2 = ${dropbox_project_list}

  local dropbox_chosen_type_path=$1
  local dropbox_project_list=$2

  local chosen_config_type            # whiptail var
  local dropbox_bk_list               # dropbox backup list
  local chosen_config_bk              # whiptail var

  log_subsection "Restore Server config Files"

  # Select config backup type
  chosen_config_type=$(whiptail --title "RESTORE CONFIGS BACKUPS" --menu "Choose a config backup type." 20 78 10 $(for x in ${dropbox_project_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)
  exitstatus="$?"
  if [[ ${exitstatus} -eq 0 ]]; then
    #Restore from Dropbox
    dropbox_bk_list="$(${DROPBOX_UPLOADER} -hq list "${dropbox_chosen_type_path}/${chosen_config_type}")"
  fi

  chosen_config_bk=$(whiptail --title "RESTORE CONFIGS BACKUPS" --menu "Choose a config backup file to restore." 20 78 10 "$(for x in ${dropbox_bk_list}; do echo "$x [F]"; done)" 3>&1 1>&2 2>&3)
  exitstatus="$?"
  if [[ ${exitstatus} -eq 0 ]]; then

    cd "${SFOLDER}/tmp"

    # Downloading Config Backup
    display --indent 6 --text "- Downloading config backup from dropbox"
    dropbox_output="$(${DROPBOX_UPLOADER} download "${dropbox_chosen_type_path}/${chosen_config_type}/${chosen_config_bk}" 1>&2)"
    clear_last_line
    display --indent 6 --text "- Downloading config backup from dropbox" --result "DONE" --color GREEN
    
    # Restore files
    mkdir "${chosen_config_type}"
    mv "${chosen_config_bk}" "${chosen_config_type}"
    cd "${chosen_config_type}"

    log_event "info" "Uncompressing ${chosen_config_bk} ..."
    
    pv --width 70 "${chosen_config_bk}" | tar xp -C "${SFOLDER}/tmp/${chosen_config_type}" --use-compress-program=lbzip2

    if [[ "${chosen_config_bk}" == *"nginx"* ]]; then

      restore_nginx_site_files

    fi
    if [[ "${CHOSEN_CONFIG}" == *"mysql"* ]]; then
      log_event "info" "MySQL Config backup downloaded and uncompressed on  ${SFOLDER}/tmp/${chosen_config_type}"
      whiptail_event "IMPORTANT!" "MySQL config files were downloaded on this temp directory: ${SFOLDER}/tmp/${chosen_config_type}."

    fi
    if [[ "${CHOSEN_CONFIG}" == *"php"* ]]; then
      log_event "info" "PHP config backup downloaded and uncompressed on  ${SFOLDER}/tmp/${chosen_config_type}"
      whiptail_event "IMPORTANT!" "PHP config files were downloaded on this temp directory: ${SFOLDER}/tmp/${chosen_config_type}."

    fi
    if [[ "${CHOSEN_CONFIG}" == *"letsencrypt"* ]]; then
      log_event "info" "Let's Encrypt config backup downloaded and uncompressed on  ${SFOLDER}/tmp/${chosen_config_type}"
      whiptail_event "IMPORTANT!" "Let's Encrypt config files were downloaded on this temp directory: ${SFOLDER}/tmp/${chosen_config_type}."

    fi

    # TODO: ask for remove tmp files
    #echo " > Removing ${SFOLDER}/tmp/${chosen_type} ..." >>$LOG
    #echo -e ${GREEN}" > Removing ${SFOLDER}/tmp/${chosen_type} ..."${ENDCOLOR}
    #rm -R ${SFOLDER}/tmp/${chosen_type}

  fi

}

function restore_nginx_site_files() {

  # $1 = ${domain} optional
  # $2 = ${date} optional

  local domain=$1
  local date=$2

  local bk_file 
  local bk_to_download 
  local filename 
  local to_restore 
  local dropbox_output          # var for dropbox output

  bk_file="nginx-configs-files-${date}.tar.bz2"
  bk_to_download="${chosen_server}/configs/nginx/${bk_file}"

  # Subsection
  log_subsection "Nginx Server Configuration Restore"

  # Downloading Config Backup
  log_event "info" "Downloading nginx backup from dropbox" "false"
  display --indent 6 --text "- Downloading nginx backup from dropbox"
  dropbox_output="$(${DROPBOX_UPLOADER} download "${bk_to_download}" 1>&2)"
  clear_last_line
  display --indent 6 --text "- Downloading nginx backup from dropbox" --result "DONE" --color GREEN

  # Extract tar.bz2 with lbzip2
  mkdir "${SFOLDER}/tmp/nginx"
  extract "${bk_file}" "${SFOLDER}/tmp/nginx" "lbzip2"

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

function restore_letsencrypt_site_files() {

  # $1 = ${domain}
  # $2 = ${date}

  local domain=$1
  local date=$2

  local bk_file 
  local bk_to_download

  bk_file="letsencrypt-configs-files-${date}.tar.bz2"
  bk_to_download="${chosen_server}/configs/letsencrypt/${bk_file}"

  log_event "info" "Running dropbox_uploader.sh download ${bk_to_download}" "false"
  
  dropbox_output=$(${DROPBOX_UPLOADER} download "${bk_to_download}" 1>&2)

  # Extract tar.bz2 with lbzip2
  log_event "info" "Extracting ${bk_file} on ${SFOLDER}/tmp/" "false"

  mkdir "${SFOLDER}/tmp/letsencrypt"
  extract "${bk_file}" "${SFOLDER}/tmp/letsencrypt" "lbzip2"

  # Creating directories
  mkdir "/etc/letsencrypt/archive/"
  mkdir "/etc/letsencrypt/live/"
  mkdir "/etc/letsencrypt/archive/${domain}"
  mkdir "/etc/letsencrypt/live/${domain}"

  # Check if file exist
  if [ ! -f "/etc/letsencrypt/options-ssl-nginx.conf" ]; then
    cp -r "${SFOLDER}/tmp/letsencrypt/options-ssl-nginx.conf" "/etc/letsencrypt/"

  fi
  if [ ! -f "/etc/letsencrypt/ssl-dhparams.pem" ]; then
    cp -r "${SFOLDER}/tmp/letsencrypt/ssl-dhparams.pem" "/etc/letsencrypt/"
    
  fi

  # TODO: check www.${domain} too
  cp -r "${SFOLDER}/tmp/letsencrypt/archive/${domain}" "/etc/letsencrypt/archive/"
  cp -r "${SFOLDER}/tmp/letsencrypt/live/${domain}" "/etc/letsencrypt/live/"

  display --indent 6 --text "- Restoring letsencrypt config files" --result "DONE" --color GREEN

}

function restore_site_files() {

  # $1 = ${chosen_domain} Here, should match with PROJECT_DOMAIN

  local domain=$1

  local actual_folder 
  local folder_to_install 
  local chosen_domain

  log_subsection "Restore Files Backup"

  chosen_domain=$(whiptail --title "Project Domain" --inputbox "Want to change the project's domain? Default:" 10 60 "${domain}" 3>&1 1>&2 2>&3)
  exitstatus="$?"
  if [[ ${exitstatus} -eq 0 ]]; then

    # Log
    log_subsection "Site Files Restore"
    log_event "info" "Setting chosen_domain=${chosen_domain}"
    display --indent 6 --text "- Selecting project domain" --result "DONE" --color GREEN

    # New tmp folder
    project_tmp_folder="${SFOLDER}/tmp/${chosen_domain}"

    # Renaming
    mv "${SFOLDER}/tmp/${domain}" "${project_tmp_folder}"
      
    # Ask folder to install
    folder_to_install=$(ask_folder_to_install_sites "${SITES}")

    # New destination directory
    actual_folder="${folder_to_install}/${chosen_domain}"

    # Check if destination folder exist
    if [ -d "${actual_folder}" ]; then

      # Make backup
      _make_temp_files_backup "${actual_folder}"

    fi

    # Restore files
    log_event "info" "Restoring backup files on ${folder_to_install} ..."
    display --indent 6 --text "- Restoring backup files"
    
    mv "${project_tmp_folder}" "${folder_to_install}"

    clear_last_line
    display --indent 6 --text "- Restoring backup files" --result "DONE" --color GREEN
    
    # TODO: we need another aproach for other kind of projects
    # Search wp-config.php (to find wp installation on sub-folders)
    install_path=$(search_wp_config "${actual_folder}")

    log_event "info" "install_path=${install_path}"
    display --indent 8 --text "Restored on: ${install_path}"

    if [ -d "${install_path}" ]; then

      log_event "info" "Wordpress intallation found on: ${install_path}"
      log_event "info" "Files backup restored on: ${install_path}"

      wp_change_permissions "${install_path}" 

      # Return
      echo "${chosen_domain}"
    
    fi

  else

    return 1

  fi

}

function restore_type_selection_from_dropbox() {
  
  # TODO: check project type (WP? Laravel? other?)
  # ask for directory_browser if apply
  # add credentials on external txt and send email

  # $1 = chosen_server
  # $2 = dropbox_type_list

  local chosen_server=$1
  local dropbox_type_list=$2

  local chosen_type                     # whiptail var
  local chosen_backup_to_restore        # whiptail var
  local dropbox_chosen_type_path        # whiptail var
  local dropbox_project_list            # list of projects on dropbox directory
  local dropbox_chosen_backup_path      # whiptail var
  local dropbox_backup_list             # dropbox listing directories
  local domain                          # extracted domain
  local db_project_name                 # extracted db name
  local bk_to_dowload                   # backup to download
  local folder_to_install               # directory to install project
  local project_site                    # project site

  chosen_type=$(whiptail --title "RESTORE FROM BACKUP" --menu "Choose a backup type. You can choose restore an entire project or only site files, database or config." 20 78 10 $(for x in ${dropbox_type_list}; do echo "${x} [D]"; done) 3>&1 1>&2 2>&3)
  exitstatus="$?"
  if [[ ${exitstatus} -eq 0 ]]; then

    dropbox_chosen_type_path="${chosen_server}/${chosen_type}"

    if [[ "${chosen_type}" == "project" ]]; then

      restore_project "${chosen_server}"

    elif [[ "${chosen_type}" != "project" ]]; then

      #log_subsection "Restore ${chosen_type} Backup"

      dropbox_project_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_chosen_type_path}")"
      
      if [[ "${chosen_type}" == *"configs"* ]]; then

        restore_config_files_from_dropbox "${dropbox_chosen_type_path}" "${dropbox_project_list}"

      else # DB or SITE

        # Select Project
        chosen_project=$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup Project" 20 78 10 $(for x in ${dropbox_project_list}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)
        exitstatus="$?"
        if [[ ${exitstatus} -eq 0 ]]; then
          dropbox_chosen_backup_path="${dropbox_chosen_type_path}/${chosen_project}"
          dropbox_backup_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_chosen_backup_path}")"

        fi
        # Select Backup File
        chosen_backup_to_restore=$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup to Download" 20 78 10 $(for x in ${dropbox_backup_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)
        exitstatus="$?"
        if [[ ${exitstatus} -eq 0 ]]; then

          cd "${SFOLDER}/tmp"

          bk_to_dowload="${chosen_server}/${chosen_type}/${chosen_project}/${chosen_backup_to_restore}"

          # Downloading Backup
          log_event "info" "Downloading backup from dropbox"
          display --indent 6 --text "- Downloading backup from dropbox"
          dropbox_output="$("${DROPBOX_UPLOADER}" download "${bk_to_dowload}" 1>&2)"
          clear_last_line
          display --indent 6 --text "- Downloading backup from dropbox" --result "DONE" --color GREEN

          # Uncompressing
          log_event "info" "Uncompressing ${chosen_backup_to_restore}"
          display --indent 6 --text "- Uncompressing backup"
          pv --width 70 "${chosen_backup_to_restore}" | tar xp -C "${SFOLDER}/tmp/" --use-compress-program=lbzip2
          clear_last_line
          clear_last_line
          display --indent 6 --text "- Uncompressing backup" --result "DONE" --color GREEN

          if [[ ${chosen_type} == *"${DBS_F}"* ]]; then

            # Asking project state with suggested actual state
            suffix="$(cut -d'_' -f2 <<<"${chosen_project}")"
            project_state=$(ask_project_state "${suffix}")

            # Extract project_name (its removes last part of db name with "_" char)
            project_name=${chosen_project%"_$suffix"}

            project_name=$(whiptail --title "Project Name" --inputbox "Want to change the project name?" 10 60 "${project_name}" 3>&1 1>&2 2>&3)
            exitstatus="$?"
            if [[ ${exitstatus} -eq 0 ]]; then
              log_event "info" "Setting project_name=${project_name}"

            else
              return 1

            fi

            # Running mysql_name_sanitize $for project_name
            db_project_name=$(mysql_name_sanitize "${project_name}")
            
            # Restore database
            restore_database_backup "${db_project_name}" "${project_state}" "${chosen_backup_to_restore}"

            db_user="${db_project_name}_user"

            # Check if user database already exists
            mysql_user_exists "${db_user}"
            user_db_exists="$?"
            if [[ ${user_db_exists} -eq 0 ]]; then

              # Passw generator
              db_pass="$(openssl rand -hex 12)"

              # Create database user with autogenerated pass
              mysql_user_create "${db_user}" "${db_pass}"

            else

              # User already exists
              log_event "warning" "MySQL user ${db_user} already exists"
              whiptail_event "WARNING" "MySQL user ${db_user} already exists. Please after the script ends, check project configuration files."

            fi

            # Grant privileges to database user
            mysql_user_grant_privileges "${db_user}" "${db_name}"

            # TODO: ask if want to change project db parameters and make cloudflare changes

            # TODO: check project type (WP, Laravel, etc)

            folder_to_install="$(ask_folder_to_install_sites "${SITES}")"
            folder_to_install_result="$?"
            if [[ ${folder_to_install_result} -eq 1 ]]; then

              return 0

            fi

            startdir="${folder_to_install}"
            menutitle="Site Selection Menu"
            directory_browser "${menutitle}" "${startdir}"
            directory_browser_result="$?"
            if [[ ${directory_browser_result} -eq 1 ]]; then

              return 0

            fi

            project_site=$filepath"/"$filename

            install_path="$(search_wp_config "${folder_to_install}/${filename}")"

            # TODO: search_wp_config could be an array of dir paths, need to check that
            if [[ "${install_path}" != "" ]]; then

              log_event "info" "WordPress installation found: ${project_site}/${install_path}"

              # Change wp-config.php database parameters
              wp_update_wpconfig "${install_path}" "${project_name}" "${project_state}" "${db_pass}"

              # Change Salts
              wpcli_set_salts "${install_path}"

            else

              log_event "error" "WordPress installation not found"

            fi


          else # site

            # Here, for convention, chosen_project should be CHOSEN_DOMAIN... 
            # Only for better code reading, i assign this new var:
            chosen_domain="${chosen_project}"
            restore_site_files "${chosen_domain}"

          fi
        
        fi

      fi

    fi

  fi

}

function restore_project() {

  # $1 = ${chosen_server}

  local chosen_server=$1

  local dropbox_project_list 
  local chosen_project 
  local dropbox_chosen_backup_path 
  local dropbox_backup_list 
  local bk_to_dowload 
  local chosen_backup_to_restore 
  local db_to_download

  log_subsection "Restore Project Backup"

  dropbox_project_list="$(${DROPBOX_UPLOADER} -hq list "${chosen_server}/site")"

  # Select Project
  chosen_project=$(whiptail --title "RESTORE PROJECT BACKUP" --menu "Choose Backup Project" 20 78 10 $(for x in ${dropbox_project_list}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)
  exitstatus="$?"
  if [[ ${exitstatus} -eq 0 ]]; then
    dropbox_chosen_backup_path="${chosen_server}/site/${chosen_project}"
    dropbox_backup_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_chosen_backup_path}")"
  
  else

    display --indent 6 --text "- Restore project backup" --result "SKIPPED" --color YELLOW

    return 1

  fi

  # Select Backup File
  chosen_backup_to_restore=$(whiptail --title "RESTORE PROJECT BACKUP" --menu "Choose Backup to Download" 20 78 10 $(for x in ${dropbox_backup_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)
  exitstatus="$?"
  if [[ ${exitstatus} -eq 0 ]]; then

    display --indent 6 --text "- Selecting project backup" --result "DONE" --color GREEN
    display --indent 8 --text "Backup selected: ${chosen_backup_to_restore}"

    cd "${SFOLDER}/tmp"

    # Download backup
    bk_to_dowload="${chosen_server}/site/${chosen_project}/${chosen_backup_to_restore}"

    log_event "info" "Downloading backup from dropbox: ${bk_to_dowload}"
    display --indent 6 --text "- Downloading backup from dropbox"

    dropbox_output=$("${DROPBOX_UPLOADER}" download "${bk_to_dowload}" 1>&2)

    clear_last_line
    display --indent 6 --text "- Downloading backup from dropbox" --result "DONE" --color GREEN

    # Uncompress backup file    
    pv --width 70 "${chosen_backup_to_restore}" | ${TAR} xp -C "${SFOLDER}/tmp/" --use-compress-program=lbzip2

    clear_last_line
    display --indent 6 --text "- Uncompressing backup file" --result "DONE" --color GREEN
    log_event "info" "Backup file ${chosen_backup_to_restore} uncompressed"

    # Project Type
    project_type=$(get_project_type "${SFOLDER}/tmp/${chosen_project}")

    log_event "debug" "Project Type: ${project_type}"

    # Here, for convention, chosen_project should be CHOSEN_DOMAIN... 
    # Only for better code reading, i assign this new var:
    chosen_domain="${chosen_project}"

    case ${project_type} in

      wordpress)
        display --indent 8 --text "Project Type WordPress" --tcolor GREEN

        # Reading config file
        db_name=$(project_get_configured_database "${SFOLDER}/tmp/${chosen_project}" "wordpress")
        db_user=$(project_get_configured_database_user "${SFOLDER}/tmp/${chosen_project}" "wordpress")
        db_pass=$(project_get_configured_database_userpassw "${SFOLDER}/tmp/${chosen_project}" "wordpress")

        # Restore site files
        new_project_domain="$(restore_site_files "${chosen_domain}")"
      ;;

      laravel)
        display --indent 8 --text "Project Type Laravel" --tcolor RED
      ;;

      yii)
        display --indent 8 --text "Project Type Yii" --tcolor RED
      ;;

      *)
        display --indent 8 --text "Project Type Unknown" --tcolor RED
        return 1
      ;;

    esac

    project_path="${SITES}/${new_project_domain}"

    # Database Backup
    backup_date="$(echo "${chosen_backup_to_restore}" |grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}')"
    db_to_download="${chosen_server}/database/${db_name}/${db_name}_database_${backup_date}.tar.bz2"

    # Extracting project_state from   
    project_state="$(cut -d'_' -f2 <<< ${db_name})"

    log_event "" "*************** Project Config ***************"
    log_event "" "project_path: ${project_path}"
    log_event "" "chosen_project: ${chosen_project}"
    log_event "" "project_state: ${project_state}"
    log_event "" "backup_date: ${backup_date}"
    log_event "" "db_name: ${db_name}"
    log_event "" "db_user: ${db_user}"
    log_event "" "db_pass: ${db_pass}"
    log_event "" "*****************************************************"

    # Downloading Database Backup
    display --indent 6 --text "- Downloading backup from dropbox"
    display --indent 8 --text "${chosen_server}/database/${db_name}/${db_name}_database_${backup_date}.tar.bz2"
    log_event "info" "Trying to download ${chosen_server}/database/${db_name}/${db_name}_database_${backup_date}.tar.bz2"
    dropbox_output="$("${DROPBOX_UPLOADER}" download "${db_to_download}" 1>&2)"

    exitstatus="$?"
    if [[ ${exitstatus} -eq 1 ]]; then

      clear_last_line
      clear_last_line
      display --indent 6 --text "- Downloading backup from dropbox" --result "FAIL" --color RED

      # TODO: maybe ask to download manually calling restore_database_backup

      return 1

    fi

    clear_last_line
    clear_last_line
    display --indent 6 --text "- Downloading backup from dropbox" --result "DONE" --color GREEN

    # Uncompress backup file
    log_event "info" "Uncompressing ${db_to_download}"
    pv --width 70 "${db_name}_database_${backup_date}.tar.bz2" | tar xp -C "${SFOLDER}/tmp/" --use-compress-program=lbzip2
    clear_last_line
    clear_last_line
    display --indent 6 --text "- Uncompressing backup file" --result "DONE" --color GREEN

    # Trying to extract project name from domain
    #chosen_project="$(cut -d'.' -f1 <<< ${chosen_project})"
    chosen_project="$(extract_domain_extension "${chosen_project}")"

    # Asking project state with suggested actual state
    suffix="$(cut -d'_' -f2 <<< ${chosen_project})"
    project_state=$(ask_project_state "${suffix}")

    # Extract project_name (its removes last part of db name with "_" char)
    project_name=${chosen_project%"_$suffix"}

    # TODO: extract to function
    # Extract reserved substrings
    #project_name=$(echo "${project_name}" | sed s/"_org"// | sed s/"_ar"// | sed s/"_com"// | sed s/"_net"// | sed s/"_edu"//)

    project_name=$(whiptail --title "Project Name" --inputbox "Want to change the project name?" 10 60 "${project_name}" 3>&1 1>&2 2>&3)
    exitstatus="$?"
    if [[ ${exitstatus} -eq 0 ]]; then
      log_event "info" "Setting project_name=${project_name}"

    else
      return 1

    fi

    # Sanitize ${project_name}
    db_project_name=$(mysql_name_sanitize "${project_name}")

    # Restore database function
    restore_database_backup "${db_project_name}" "${project_state}" "${db_name}_database_${backup_date}.tar.bz2"

    db_name="${db_project_name}_${project_state}"
    db_user="${db_project_name}_user"

    # Check if user database already exists
    mysql_user_exists "${db_user}"
    user_db_exists="$?"
    if [[ ${user_db_exists} -eq 0 ]]; then

      db_pass=$(openssl rand -hex 12)
      mysql_user_create "${db_user}" "${db_pass}"

    else

      log_event "warning" "MySQL user ${db_user} already exists"
      display --indent 6 --text "- Creating ${db_user} user in MySQL" --result "FAIL" --color RED
      display --indent 8 --text "MySQL user ${db_user} already exists."

      whiptail_event "WARNING" "MySQL user ${db_user} already exists. Please after the script ends, check project configuration files."

    fi

    # Grant privileges to database user
    mysql_user_grant_privileges "${db_user}" "${db_name}"

    # Change wp-config.php database parameters
    wp_update_wpconfig "${project_path}" "${db_project_name}" "${project_state}" "${db_pass}"

    if [[ "${new_project_domain}" = "${chosen_domain}" ]]; then

      letsencrypt_opt_text="\n Do you want to restore let's encrypt certificates or generate a new ones?"
      letsencrypt_opt=("01)" "RESTORE CERTIFICATES" "02)" "GENERATE NEW CERTIFICATES")
      letsencrypt_chosen_opt=$(whiptail --title "Let's Encrypt Certificates" --menu "${letsencrypt_opt_text}" 20 78 10 "${letsencrypt_opt[@]}" 3>&1 1>&2 2>&3)

      exitstatus="$?"
      if [[ ${exitstatus} -eq 0 ]]; then
        
        if [[ ${letsencrypt_chosen_opt} == *"01"* ]]; then
          
          restore_letsencrypt_site_files "${chosen_domain}" "${backup_date}"

          # If choose restore config, need to restore nginx config and run cerbot
          restore_nginx_site_files "${chosen_domain}" "${backup_date}"

          # Cloudflare API
          possible_root_domain="$(get_root_domain "${chosen_domain}")"
          root_domain=$(cloudflare_ask_root_domain "${possible_root_domain}")
          cloudflare_change_a_record "${root_domain}" "${new_project_domain}"

        fi
        if [[ ${letsencrypt_chosen_opt} == *"02"* ]]; then

          # TODO: need to remove hardcoded parameters "wordpress" and "single"
          nginx_server_create "${new_project_domain}" "wordpress" "single"
          
          # Cloudflare API
          possible_root_domain="$(get_root_domain "${new_project_domain}")"
          root_domain=$(cloudflare_ask_root_domain "${possible_root_domain}")
          cloudflare_change_a_record "${root_domain}" "${new_project_domain}"
          
          certbot_certificate_install "${MAILA}" "${chosen_domain}"

        fi
      #else

      fi

    else

      # Need to create new configs
      
      # TODO: remove hardcoded parameters "wordpress" and "single"
      nginx_server_create "${new_project_domain}" "wordpress" "single"
      
      # Cloudflare API
      possible_root_domain="$(get_root_domain "${chosen_domain}")"
      root_domain=$(cloudflare_ask_root_domain "${possible_root_domain}")
      cloudflare_change_a_record "${root_domain}" "${new_project_domain}"

      certbot_certificate_install "${MAILA}" "${new_project_domain}"

      # TODO: check if is a WP project

      # Change urls on database
      wpcli_search_and_replace "${project_path}" "${chosen_domain}" "${new_project_domain}"

      # Shuffle salts
      wpcli_set_salts "${project_path}"

      # Changing wordpress visibility
      wpcli_change_wp_seo_visibility "${project_path}" "0"

    fi
        
    telegram_send_message "✅ ${VPSNAME}: Project ${new_project_domain} restored"

  fi

}