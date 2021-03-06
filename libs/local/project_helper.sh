#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.18
################################################################################

# shellcheck source=${SFOLDER}/libs/wordpress_installer.sh
# source "${SFOLDER}/libs/wordpress_installer.sh"

#
# TODO: check when add www.DOMAIN.com and then select other stage != prod
#

function project_create_config() {

  # $1 = ${project_path}
  # $2 = ${project_name}
  # $3 = ${project_type}          / Wordpress, Laravel, PHP
  # $4 = ${project_subtype}       / ? check if it's necessary
  # $5 = ${project_domain}

  local project_path=$1
  local project_name=$2
  local project_type=$3
  local project_subtype=$4
  local project_domain=$5

  local project_config_file

  # Project config file
  project_config_file="${project_path}/.project.conf"
  if [[ -e ${project_config_file} ]]; then
    # Logging
    display --indent 6 --text "- Project config file already exists" --result WARNING --color YELLOW

  else

    # Write config file
    echo "project_name=${project_name}" >>"${project_config_file}"
    echo "project_type=${project_type}" >>"${project_config_file}"
    echo "project_type=${project_subtype}" >>"${project_config_file}"
    echo "project_type=${project_domain}" >>"${project_config_file}"

  fi

}

function project_get_configured_database() {

  # $1 = ${project_path}
  # $2 = ${project_type}

  local project_path=$1
  local project_type=$2

  case $project_type in

    wordpress)

      db_name=$(cat "${project_path}"/wp-config.php | grep DB_NAME | cut -d \' -f 4)

      # Return
      echo "${db_name}"
      
    ;;

    laravel)
      display --indent 8 --text "Project Type Laravel" --tcolor RED
      return 1
    ;;

    yii)
      display --indent 8 --text "Project Type Yii" --tcolor RED
      return 1
    ;;

    *)
      display --indent 8 --text "Project Type Unknown" --tcolor RED
      return 1
    ;;

  esac

}

function project_get_configured_database_user() {

  # $1 = ${project_path}
  # $2 = ${project_type}

  local project_path=$1
  local project_type=$2

  case $project_type in

      wordpress)

        db_user=$(cat "${project_path}"/wp-config.php | grep DB_USER | cut -d \' -f 4)

        # Return
        echo "${db_user}"
        
      ;;

      laravel)
        display --indent 8 --text "Project Type Laravel" --tcolor RED
        return 1
      ;;

      yii)
        display --indent 8 --text "Project Type Yii" --tcolor RED
        return 1
      ;;

      *)
        display --indent 8 --text "Project Type Unknown" --tcolor RED
        return 1
      ;;

    esac

}

function project_get_configured_database_userpassw() {

  # $1 = ${project_path}
  # $2 = ${project_type}

  local project_path=$1
  local project_type=$2

  case $project_type in

      wordpress)
        db_pass=$(cat "${project_path}"/wp-config.php | grep DB_PASSWORD | cut -d \' -f 4)
        
        # Return
        echo "${db_pass}"

      ;;

      laravel)
        display --indent 8 --text "Project Type Laravel" --tcolor RED
        return 1
      ;;

      yii)
        display --indent 8 --text "Project Type Yii" --tcolor RED
        return 1
      ;;

      *)
        display --indent 8 --text "Project Type Unknown" --tcolor RED
        return 1
      ;;

    esac

}

function project_install() {

  # $1 = ${dir_path}
  # $2 = ${project_type}
  # $3 = ${project_domain}
  # $4 = ${project_name}
  # $5 = ${project_state}
  # $6 = ${project_root_domain}   # Optional

  local dir_path=$1
  local project_type=$2
  local project_domain=$3
  local project_name=$4
  local project_state=$5

  log_section "Project Installer (${project_type})"

  if [[ "${project_domain}" = '' ]]; then
    project_domain=$(ask_project_domain)
  fi
  
  if [[ "${project_domain}" = '' ]]; then
    project_domain=$(ask_project_domain)
  fi

  folder_to_install=$(ask_folder_to_install_sites "${dir_path}")
  project_path="${folder_to_install}/${project_domain}"

  possible_root_domain="$(get_root_domain "${project_domain}")"
  root_domain=$(ask_rootdomain_for_cloudflare_config "${possible_root_domain}")

  if [[ "${project_name}" = '' ]]; then
    possible_project_name="$(extract_domain_extension "${project_domain}")"
    project_name="$(ask_project_name "${possible_project_name}")"
  fi

  if [[ "${project_state}" = '' ]]; then
    project_state=$(ask_project_state)
  fi

  case ${project_type} in

    wordpress)

      # Execute function
      wordpress_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"

      ;;

    laravel)
      # Execute function
      # laravel_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"
      log_event "error" "Laravel installer should be implemented soon, aborting ..."
      ;;

    php)

      php_project_install "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"

      ;;

    *)
      log_event "error" "Project Type ${project_type} unkwnown, aborting ..."
      ;;

  esac

  log_event "success" "PROJECT INSTALLATION FINISHED!"

}

function project_delete_files() {

  # $1 = ${project_domain}

  local project_domain=$1

  local dropbox_output

  # Log
  log_subsection "Delete Files"

  # Trying to know project type
  project_type=$(get_project_type "${SITES}/${project_domain}")

  # TODO: if project_type = wordpress, get database credentials from wp-config.php
  #project_db_name=$(get_project_db_name "${project_type}")
  #project_db_user=$(get_project_db_user "${project_type}")

  log_event "info" "Project Type: ${project_type}"

  BK_TYPE="site"

  # Making a backup of project files
  make_files_backup "${BK_TYPE}" "${SITES}" "${project_domain}"
  output=$?
  if [[ ${output} -eq 0 ]]; then

    # Creating new folder structure for old projects
    dropbox_output=$(${DROPBOX_UPLOADER} -q mkdir "/${VPSNAME}/offline-site" 2>&1)

    # Moving deleted project backups to another dropbox directory
    log_event "info" "${DROPBOX_UPLOADER} move ${VPSNAME}/${BK_TYPE}/${project_domain} /${VPSNAME}/offline-site" "false"
    dropbox_output=$(${DROPBOX_UPLOADER} move "/${VPSNAME}/${BK_TYPE}/${project_domain}" "/${VPSNAME}/offline-site" 2>&1)
    # TODO: if destination folder already exists, it fails
    display --indent 6 --text "- Moving to offline projects on Dropbox" --result "DONE" --color GREEN

    # Delete project files
    rm --force --recursive "${filepath}/${project_domain}"

    log_event "info" "Project files deleted for ${project_domain}" "false"
    display --indent 6 --text "- Deleting project files on server" --result "DONE" --color GREEN

    # Make a copy of nginx configuration file
    cp -r "/etc/nginx/sites-available/${project_domain}" "${SFOLDER}/tmp-backup"

    # TODO: make a copy of letsencrypt files?

    # TODO: upload to dropbox config_file ??

    # Delete nginx configuration file
    nginx_server_delete "${project_domain}"

    # Cloudflare Manager
    project_domain=$(whiptail --title "CLOUDFLARE MANAGER" --inputbox "Do you want to delete the Cloudflare entries for the followings subdomains?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
    
        # Delete Cloudflare entries
        cloudflare_delete_a_record "${project_domain}"

    else

        log_event "info" "Cloudflare entries not deleted. Skipped by user."

    fi

    # TODO: Maybe return database name? extracted from wp-config or something?

  else

    return 1

  fi

}

function project_delete_database() {

    # $1 = {database}

    local database=$1

    local databases
    local chosen_database

    # TODO: if project_db_name, project_db_user and project_db_pass are defined 
    #       and can connect to db, only ask for delete confirmation

    # List databases
    databases="$(mysql_list_databases)"
    chosen_database=$(whiptail --title "MYSQL DATABASES" --menu "Choose a Database to delete" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) --default-item "${database}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        log_subsection "Delete Database"

        BK_TYPE="database"

        # TO-FIX: 
        #   With deb04_broobe_prod this DB_NAME, fails to extract suffix:
        #   - Deleting deb04_broobe_prod_user user in MySQL             [ FAIL ]

        # Remove DB suffix to get project_name
        suffix="$(cut -d'_' -f2 <<<"${chosen_database}")"
        project_name=${chosen_database%"_$suffix"}
        user_db="${project_name}_user"

        # Make a database Backup
        make_database_backup "${BK_TYPE}" "${chosen_database}"

        # Moving deleted project backups to another dropbox directory
        log_event "debug" "Running: dropbox_uploader.sh move ${VPSNAME}/${BK_TYPE}/${chosen_database} /${VPSNAME}/offline-site"
        dropbox_output=$(${DROPBOX_UPLOADER} move "/${VPSNAME}/${BK_TYPE}/${chosen_database}" "/${VPSNAME}/offline-site" 1>&2)

        display --indent 6 --text "- Moving dropbox backup to offline directory" --result "DONE" --color GREEN

        # Delete project database
        mysql_database_drop "${chosen_database}"

        # Delete mysql user
        while true; do

            echo -e "${B_RED}${ITALIC} > Do you want to remove database user? Maybe is used by another project.${ENDCOLOR}"
            read -p "Please type 'y' or 'n'" yn

            case $yn in

                [Yy]* )

                  clear_last_line
                  clear_last_line
                  mysql_user_delete "${user_db}"
                  break

                ;;
                
                [Nn]* )

                  log_event "warning" "Aborting MySQL user deletion ..."
                  display --indent 6 --text "- Deleting MySQL user" --result "SKIPPED" --color YELLOW
                  break

                ;;

                * ) echo " > Please answer yes or no.";;

            esac

        done

    else
        # Return
        echo "error"

    fi

}

# TODO: NEED REFACTOR
# 1- Files backup with file_backups functions, checking if site is WP or what.
# 2- Ask for confirm delete temp files.
# 3- Ask what to do with letsencrypt and nginx server config files
#
# Symphony, config BD on /var/www/PROJECT/app/config/parameters.yml
#

function project_delete() {

  # $1 = ${project_domain}

  local project_domain=$1

  log_event "info" "Performing Action: Project Delete"

  log_section "Project Delete"

  if [[ "${project_domain}" = '' ]]; then

    # Folder where sites are hosted: $SITES
    menu_title="PROJECT TO DELETE"
    directory_browser "${menu_title}" "${SITES}"

    # Directory_broser returns: " $filepath"/"$filename
    if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

      log_event "info" "Operation 'Project Delete' cancelled!"

      # Return
      return 1
    
    else

      # Removing last slash from string
      project_domain=${filename%/}

    fi

  fi

  ### Creating temporary folders
  if [[ ! -d "${SFOLDER}/tmp-backup" ]]; then
      mkdir "${SFOLDER}/tmp-backup"
      log_event "info" "Temp files directory created: ${SFOLDER}/tmp-backup"
  fi

  log_event "info" "Project to delete: ${project_domain}"
  display --indent 2 --text "- Selecting ${project_domain} for deletion" --result "DONE" --color GREEN

  # Delete Files
  project_delete_files "${project_domain}"

  # Delete Database
  project_delete_database "${delete_files_result}"

  #TODO: ask for deleting tmp-backup folder
  # Delete tmp backups
  #rm -R ${SFOLDER}/tmp-backup

  telegram_send_message "⚠️ ${VPSNAME}: Project files deleted for: ${project_domain}"

}

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

function php_project_install () {

  # $1 = ${project_path}
  # $2 = ${project_domain}
  # $3 = ${project_name}
  # $4 = ${project_state}
  # $5 = ${project_root_domain}   # Optional

  local project_path=$1
  local project_domain=$2
  local project_name=$3
  local project_state=$4
  local project_root_domain=$5

  log_subsection "PHP Project Install"

  if [[ "${project_root_domain}" == '' ]]; then
    
    possible_root_domain="$(get_root_domain "${project_domain}")"
    project_root_domain="$(ask_rootdomain_for_cloudflare_config "${possible_root_domain}")"

  fi

  if [ ! -d "${project_path}" ]; then
    # Download WP
    mkdir "${project_path}"
    change_ownership "www-data" "www-data" "${project_path}"
    
    # Logging
    #display --indent 6 --text "- Making a copy of the WordPress project" --result "DONE" --color GREEN

  else

    # Logging
    display --indent 6 --text "- Creating WordPress project" --result "FAIL" --color RED
    display --indent 8 --text "Destination folder '${project_path}' already exist"
    log_event "error" "Destination folder '${project_path}' already exist, aborting ..."

    # Return
    return 1

  fi

  # Create database and user
  db_project_name=$(mysql_name_sanitize "${project_name}")
  database_name="${db_project_name}_${project_state}" 
  database_user="${db_project_name}_user"
  database_user_passw=$(openssl rand -hex 12)

  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}"
  mysql_user_grant_privileges "${database_user}" "${database_name}"

    
  # Create project directory
  mkdir "${project_path}"

  # Create index.php
  echo "<?php phpinfo(); ?>" > "${project_path}/index.php"

  # Change ownership
  change_ownership "www-data" "www-data" "${project_path}"

  # TODO: ask for Cloudflare support and check if root_domain is configured on the cf account

  # If domain contains www, should work without www too
  common_subdomain='www'
  if [[ ${project_domain} == *"${common_subdomain}"* ]]; then

    # Cloudflare API to change DNS records
    cloudflare_change_a_record "${project_root_domain}" "${project_domain}"

    # Cloudflare API to change DNS records
    cloudflare_change_a_record "${project_root_domain}" "${project_root_domain}"

    # New site Nginx configuration
    nginx_server_create "${project_domain}" "php" "root_domain" "${project_root_domain}"

    # HTTPS with Certbot
    project_domain=$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain},${project_root_domain}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      certbot_certificate_install "${MAILA}" "${project_domain},${project_root_domain}"

    else

      log_event "info" "HTTPS support for ${project_domain} skipped"
      display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

    fi  

  else

    # Cloudflare API to change DNS records
    cloudflare_change_a_record "${project_root_domain}" "${project_domain}"

    # New site Nginx configuration
    nginx_create_empty_nginx_conf "${project_path}"
    nginx_create_globals_config
    nginx_server_create "${project_domain}" "php" "single"

    # HTTPS with Certbot
    cert_project_domain=$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      
      certbot_certificate_install "${MAILA}" "${cert_project_domain}"

    else

      log_event "info" "HTTPS support for ${project_domain} skipped" "false"
      display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

    fi
    
  fi

  log_event "success" "PHP project installation for domain ${project_domain} finished" "false"
  display --indent 6 --text "- PHP project installation for domain ${project_domain}" --result "DONE" --color GREEN

  telegram_send_message "${VPSNAME}: PHP project installation for domain ${project_domain} finished"

}