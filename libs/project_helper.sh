#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.10
################################################################################

# shellcheck source=${SFOLDER}/libs/wordpress_installer.sh
source "${SFOLDER}/libs/wordpress_installer.sh"

#
# TODO: check when add www.DOMAIN.com and then select other stage != prod
#

project_create_config() {

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

project_get_configured_database() {

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

project_get_configured_database_user() {

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

project_get_configured_database_userpassw() {

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

project_install() {

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

      #display --indent 6 --text "- WordPress Installer Selected" -tcolor GREEN
      wordpress_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"

      ;;

    laravel)
      #display --indent 6 --text "Laravel installer should be implemented soon, aborting ..." --tcolor RED
      log_event "error" "Laravel installer should be implemented soon, aborting ..."
      ;;

    php)

        if [ -d "${project_path}" ]; then
              
          # Create project directory
          mkdir "${project_path}"

          # Create index.php
          echo "<?php phpinfo(); ?>" > "${project_path}/index.php"

        else

          log_event "error" "Destination folder '${project_path}' already exist, aborting ..."
          return 1

        fi

      ;;

    *)
      log_event "error" "Project Type ${project_type} unkwnown, aborting ..."
      ;;

  esac

  # Change ownership
  #change_ownership "www-data" "www-data" "${project_path}"

  # TODO: ask if we want create a database

  # Create database and user
  #db_project_name=$(mysql_name_sanitize "${project_name}")
  #database_name="${db_project_name}_${project_state}" 
  #database_user="${db_project_name}_user"
  #database_user_passw=$(openssl rand -hex 12)

  #mysql_database_create "${database_name}"
  #mysql_user_create "${database_user}" "${database_user_passw}"
  #mysql_user_grant_privileges "${database_user}" "${database_name}"

  # Cloudflare API to change DNS records
  #cloudflare_change_a_record "${root_domain}" "${project_domain}"

  # New site Nginx configuration
  #nginx_server_create "${project_domain}" "wordpress" "single" ""

  # HTTPS with Certbot
  #certbot_certificate_install "${MAILA}" "${project_domain}"

  log_event "success" "PROJECT INSTALLATION FINISHED!"

}

project_delete_files() {

  # $1 = ${project_domain}

  local project_domain=$1

  local dropbox_output

  # Trying to know project type
  project_type=$(get_project_type "${SITES}/${project_domain}")

  # TODO: if project_type = wordpress, get database credentials from wp-config.php
  #project_db_name=$(get_project_db_name "${project_type}")
  #project_db_user=$(get_project_db_user "${project_type}")

  log_event "info" "Project Type: ${project_type}"

  BK_TYPE="site"

  # Making a backup of project files
  make_files_backup "${BK_TYPE}" "${SITES}" "${project_domain}"
  output="$?"
  if [[ ${output} -eq 0 ]]; then

    # Creating new folder structure for old projects
    dropbox_output=$(${DROPBOX_UPLOADER} -q mkdir "/${VPSNAME}/offline-site" 2>&1)

    # Moving deleted project backups to another dropbox directory
    log_event "info" "${DROPBOX_UPLOADER} move ${VPSNAME}/${BK_TYPE}/${project_domain} /${VPSNAME}/offline-site" "false"
    dropbox_output=$(${DROPBOX_UPLOADER} move "/${VPSNAME}/${BK_TYPE}/${project_domain}" "/${VPSNAME}/offline-site" 2>&1)
    # TODO: if destination folder already exists, it fails
    display --indent 2 --text "- Moving to offline projects on Dropbox" --result "DONE" --color GREEN

    # Delete project files
    rm -R "${filepath}/${project_domain}"
    log_event "info" "Project files deleted for ${project_domain}" "false"
    display --indent 2 --text "- Deleting project files on server" --result "DONE" --color GREEN


    # Make a copy of nginx configuration file
    cp -r "/etc/nginx/sites-available/${project_domain}" "${SFOLDER}/tmp-backup"

    # TODO: make a copy of letsencrypt files?

    # TODO: upload to dropbox config_file ??

    # Delete nginx configuration file
    nginx_server_delete "${project_domain}"
    display --indent 2 --text "- Deleting nginx server configuration" --result "DONE" --color GREEN

    # Cloudflare Manager
    project_domain=$(whiptail --title "CLOUDFLARE MANAGER" --inputbox "Do you want to delete the Cloudflare entries for the followings subdomains?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)
    exitstatus="$?"
    if [[ ${exitstatus} -eq 0 ]]; then
    
        # Delete Cloudflare entries
        cloudflare_delete_a_record "${project_domain}"

    else

        log_event "info" "Cloudflare entries not deleted. Skipped by user." "false"

    fi

    telegram_send_message "⚠️ ${VPSNAME}: Project files deleted for: ${project_domain}"

    # TODO: Maybe return database name? extracted from wp-config or something?

  else

    return 1

  fi

}

project_delete_database() {

    # $1 = {database}

    local database=$1

    local DBS
    local CHOSEN_DB

    # TODO: if project_db_name, project_db_user and project_db_pass are defined 
    #       and can connect to db, only ask for delete confirmation

    # List databases
    DBS=$("${MYSQL}" -u "${MUSER}" -p"${MPASS}" -Bse 'show databases')
    CHOSEN_DB=$(whiptail --title "MYSQL DATABASES" --menu "Choose a Database to delete" 20 78 10 $(for x in ${DBS}; do echo "$x [DB]"; done) --default-item "${database}" 3>&1 1>&2 2>&3)
    exitstatus="$?"
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        log_subsection "Delete Database"

        BK_TYPE="database"

        # TO-FIX: 
        #
        # With deb04_broobe_prod this DB_NAME, fails to extract suffix:
        # - Deleting deb04_broobe_prod_user user in MySQL             [ FAIL ]

        # Remove DB suffix to get project_name
        suffix="$(cut -d'_' -f2 <<<"${CHOSEN_DB}")"
        project_name=${CHOSEN_DB%"_$suffix"}
        user_db="${project_name}_user"

        # Make a database Backup
        make_database_backup "${BK_TYPE}" "${CHOSEN_DB}"

        # Moving deleted project backups to another dropbox directory
        log_event "info" "Running: dropbox_uploader.sh move ${VPSNAME}/${BK_TYPE}/${CHOSEN_DB} /${VPSNAME}/offline-site"
        dropbox_output=$(${DROPBOX_UPLOADER} move "/${VPSNAME}/${BK_TYPE}/${CHOSEN_DB}" "/${VPSNAME}/offline-site" 1>&2)

        display --indent 62 --text "- Moving dropbox backup to offline directory" --result "DONE" --color GREEN

        # Delete project database
        mysql_database_drop "${CHOSEN_DB}"

        # Delete mysql user
        while true; do

            echo -e "${YELLOW}${ITALIC} > Do you want to remove database user? Maybe is used by another project.${ENDCOLOR}"
            read -p "Please type 'y' or 'n'" yn

            case $yn in
                [Yy]* )
                
                mysql_user_delete "${user_db}"
                break;;
                
                [Nn]* )

                log_event "warning" "Aborting MySQL user deletion ..."
                break;;

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

project_delete() {

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
  if [ ! -d "${SFOLDER}/tmp-backup" ]; then
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

}