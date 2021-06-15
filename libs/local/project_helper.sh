#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.36
################################################################################

#
# TODO: check when add www.DOMAIN.com and then select other stage != prod
#

function project_get_name_from_domain() {

  # $1 = ${project_domain}

  local project_domain=$1

  local root_domain
  local possible_project_name

  # Trying to extract project name from domain
  root_domain="$(get_root_domain "${project_domain}")"
  possible_project_name="$(extract_domain_extension "${root_domain}")"

  # Replace '-' and '.' chars
  possible_project_name="$(echo "${possible_project_name}" | sed -r 's/[.-]+/_/g')"

  # Return
  echo "${possible_project_name}"

}

function project_get_stage_from_domain() {

  # $1 = ${project_domain}

  local project_domain=$1

  local project_stages
  local possible_project_stage

  project_stages="dev,test,stage,demo"

  # Trying to extract project state from domain
  possible_project_stage="$(get_subdomain_part "${project_domain}" | cut -d "." -f 1)"

  if [[ ${project_stages} != *"${possible_project_stage}"* ]]; then

    possible_project_stage="prod"

  fi

  # Return
  echo "${possible_project_stage}"

}

function project_create_config() {

  # $1 = ${project_path}
  # $2 = ${project_name}
  # $3 = ${project_stage}
  # $4 = ${project_type}
  # $5 = ${project_db_name}
  # $6 = ${project_db_host}
  # $7 = ${project_domain}
  # $8 = ${project_nginx_conf}

  local project_path=$1
  local project_name=$2
  local project_stage=$3
  local project_type=$4
  local project_db_name=$5
  local project_db_host=$6
  local project_domain=$7
  local project_nginx_conf=$8

  local project_config_file

  # Project config file
  project_config_file="${DEVOPS_CONFIG_PATH}/${project_name}-devops.conf"

  if [[ -e ${project_config_file} ]]; then

    # Log
    display --indent 6 --text "- Project config file already exists" --result WARNING --color YELLOW
    display --indent 8 --text "Updating config file ..." --result WARNING --color YELLOW --tstyle ITALIC

  else

    # Copy empty config file
    cp "${SFOLDER}/config/devops.conf" "${project_config_file}"

  fi

  # If only receive project_path
  #project_domain="$(basename "${project_path}")"
  #project_name="$(project_get_name_from_domain "${project_domain}")"
  #project_stage="$(project_get_stage_from_domain "${project_domain}")"
  #project_type="$(project_get_type "${project_path}")"

  # Write config file
  ## Doc: https://stackoverflow.com/a/61049639/2267761

  ## project_path
  content_ppath="$(jq ".project_path = \"${project_path}\"" "${project_config_file}")" && echo "${content_ppath}" >"${project_config_file}"

  ## project_name
  content_pname="$(jq ".project_name = \"${project_name}\"" "${project_config_file}")" && echo "${content_pname}" >"${project_config_file}"

  ## project_stage
  content_pstage="$(jq ".project_stage = \"${project_stage}\"" "${project_config_file}")" && echo "${content_pstage}" >"${project_config_file}"

  ## project_db_name
  content_pdbn="$(jq ".project_db_name = \"${project_db_name}\"" "${project_config_file}")" && echo "${content_pdbn}" >"${project_config_file}"

  ## project_db_host
  content_pdbh="$(jq ".project_db_host = \"${project_db_host}\"" "${project_config_file}")" && echo "${content_pdbh}" >"${project_config_file}"

  ## project_type
  content_ptype="$(jq ".project_type = \"${project_type}\"" "${project_config_file}")" && echo "${content_ptype}" >"${project_config_file}"

  ## project_subdomain
  content_psubd="$(jq ".project_subdomain = \"${project_domain}\"" "${project_config_file}")" && echo "${content_psubd}" >"${project_config_file}"

  ## project_nginx_conf
  content_pnginx="$(jq ".project_nginx_conf = \"${project_nginx_conf}\"" "${project_config_file}")" && echo "${content_pnginx}" >"${project_config_file}"

  # Log
  display --indent 6 --text "- Creating project config file" --result DONE --color GREEN

}

function project_generate_config() {

  # $1 = ${project_path}

  local project_path=$1

  local project_config_file

  log_event "info" "Trying to generate a new config for '${project_path}'..."

  # Trying to extract project data
  project_domain="$(basename "${project_path}")"
  project_name="$(project_get_name_from_domain "${project_domain}")"
  project_stage="$(project_get_stage_from_domain "${project_domain}")"
  project_type="$(project_get_type "${project_path}")"

  # TODO: should check this data
  ## Check if database exists
  project_db="${project_name}_${project_stage}"
  ## Check if file exists
  project_nginx_conf="/etc/nginx/sites-available/${project_domain}"

  # Write config file
  project_create_config "${project_path}" "${project_name}" "${project_stage}" "${project_type}" "${project_db}" "${project_domain}" "${project_nginx_conf}"

}

function project_update_config() {

  # $1 = ${project_path}
  # $2 = ${config_field}
  # $3 = ${config_value}

  local project_path=$1
  local config_field=$2
  local config_value=$3

  local project_domain
  local project_name
  local project_config_file

  project_domain="$(basename "${project_path}")"

  project_name="$(project_get_name_from_domain "${project_domain}")"

  # Project config file
  project_config_file="${DEVOPS_CONFIG_PATH}/${project_name}-devops.conf"

  if [[ -e ${project_config_file} ]]; then

    # Write config file
    ## Doc: https://stackoverflow.com/a/61049639/2267761

    ## project_name
    content="$(jq ".${config_field} = \"${config_value}\"" "${project_config_file}")" && echo "${content}" >"${project_config_file}"

    # Log
    display --indent 6 --text "- Updating project config file" --result DONE --color GREEN

  else

    # Log
    display --indent 6 --text "- Project config file dont exists" --result WARNING --color YELLOW

  fi

}

function project_get_config() {

  # $1 = ${project_path}
  # $2 = ${config_field}

  local project_path=$1
  local config_field=$2

  local config_value
  local project_domain
  local project_name
  local project_config_file

  project_domain="$(basename "${project_path}")"

  project_name="$(project_get_name_from_domain "${project_domain}")"

  project_config_file="${DEVOPS_CONFIG_PATH}/${project_name}-devops.conf"

  if [[ -e ${project_config_file} ]]; then

    config_value="$(cat ${project_config_file} | jq -r ".${config_field}")"

    # Return
    echo "${config_value}"

  else

    # Return
    echo "false"

  fi

}

function project_get_configured_database() {

  # $1 = ${project_path}
  # $2 = ${project_type}

  local project_path=$1
  local project_type=$2

  local wpconfig_path

  case ${project_type} in

  wordpress)

    wpconfig_path=$(wp_config_path "${project_path}")

    db_name=$(cat "${wpconfig_path}/wp-config.php" | grep DB_NAME | cut -d \' -f 4)

    # Return
    echo "${db_name}"

    ;;

  laravel)
    display --indent 8 --text "Project Type Laravel" --tcolor RED
    return 1
    ;;

  node-js)
    display --indent 8 --text "Project Type NodeJS" --tcolor RED
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

  node-js)
    display --indent 8 --text "Project Type NodeJS" --tcolor RED
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

  php)
    display --indent 8 --text "Project Type Laravel" --tcolor RED
    return 1
    ;;

  node-js)
    display --indent 8 --text "Project Type NodeJS" --tcolor RED
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

  if [[ ${project_type} == '' ]]; then
    project_type="$(ask_project_type)"
  fi

  log_section "Project Installer (${project_type})"

  if [[ ${project_domain} == '' ]]; then
    project_domain="$(ask_project_domain)"
  fi

  folder_to_install="$(ask_folder_to_install_sites "${dir_path}")"
  project_path="${folder_to_install}/${project_domain}"

  possible_root_domain="$(get_root_domain "${project_domain}")"
  root_domain="$(ask_rootdomain_for_cloudflare_config "${possible_root_domain}")"

  if [[ ${project_name} == '' ]]; then
    possible_project_name="$(extract_domain_extension "${project_domain}")"
    project_name="$(ask_project_name "${possible_project_name}")"
  fi

  # TODO: check when add www.DOMAIN.com and then select other stage != prod
  if [[ ${project_state} == '' ]]; then

    suggested_state="$(get_subdomain_part "${project_domain}")"

    project_state="$(ask_project_state "${suggested_state}")"

  fi

  case ${project_type} in

  wordpress)

    # Execute function
    wordpress_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"

    ;;

  laravel)
    # Execute function
    # laravel_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"
    log_event "warning" "Laravel installer should be implemented soon, trying to install like pure php project ..."
    php_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"

    ;;

  php)

    php_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"

    ;;

  node-js)

    display --indent 8 --text "Project Type NodeJS" --tcolor RED
    nodejs_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"

    return 1
    ;;

  *)
    log_event "error" "Project Type ${project_type} unkwnown, aborting ..."
    ;;

  esac

  log_event "info" "PROJECT INSTALLATION FINISHED!"

}

function project_delete_files() {

  # $1 = ${project_domain}

  local project_domain=$1

  local dropbox_output

  # Log
  log_subsection "Delete Files"

  # Trying to know project type
  project_type=$(project_get_type "${SITES}/${project_domain}")

  # TODO: if project_type = wordpress, get database credentials from wp-config.php
  #project_db_name=$(get_project_db_name "${project_type}")
  #project_db_user=$(get_project_db_user "${project_type}")

  log_event "info" "Project Type: ${project_type}"

  BK_TYPE="site"

  # Making a backup of project files
  make_files_backup "${BK_TYPE}" "${SITES}" "${project_domain}"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Creating new folder structure for old projects
    dropbox_output="$(${DROPBOX_UPLOADER} -q mkdir "/${VPSNAME}/offline-site" 2>&1)"

    # Moving deleted project backups to another dropbox directory
    log_event "info" "${DROPBOX_UPLOADER} move ${VPSNAME}/${BK_TYPE}/${project_domain} /${VPSNAME}/offline-site"

    dropbox_output="$(${DROPBOX_UPLOADER} move "/${VPSNAME}/${BK_TYPE}/${project_domain}" "/${VPSNAME}/offline-site" 2>&1)"

    # TODO: if destination folder already exists, it will fail
    display --indent 6 --text "- Moving to offline projects on Dropbox" --result "DONE" --color GREEN

    # Delete project files
    rm --force --recursive "${SITES}/${project_domain}"

    # Log
    log_event "info" "Project files deleted for ${project_domain}"
    display --indent 6 --text "- Deleting project files on server" --result "DONE" --color GREEN

    # Make a copy of nginx configuration file
    cp --recursive "/etc/nginx/sites-available/${project_domain}" "${SFOLDER}/tmp-backup"

    # TODO: make a copy of letsencrypt files?
    # TODO: upload to dropbox config_file ??

    # Delete nginx configuration file
    nginx_server_delete "${project_domain}"

    # Send notification
    send_notification "⚠️ ${VPSNAME}" "Project files for '${project_domain}' deleted!"

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
  chosen_database="$(whiptail --title "MYSQL DATABASES" --menu "Choose a Database to delete" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) --default-item "${database}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Log
    log_subsection "Delete Database"

    BK_TYPE="database"

    # TO-FIX:
    #   With deb04_broobe_prod this DB_NAME, fails to extract suffix:
    #   - Deleting deb04_broobe_prod_user user in MySQL             [ FAIL ]

    # Remove DB suffix to get project_name
    suffix="$(cut -d'_' -f2 <<<${chosen_database})"
    project_name=${chosen_database%"_$suffix"}

    user_db="${project_name}_user"

    # Make a database Backup
    make_database_backup "${BK_TYPE}" "${chosen_database}"

    # Moving deleted project backups to another dropbox directory
    ${DROPBOX_UPLOADER} move "/${VPSNAME}/${BK_TYPE}/${chosen_database}" "/${VPSNAME}/offline-site" 1>&2

    # Log
    log_event "debug" "Running: dropbox_uploader.sh move ${VPSNAME}/${BK_TYPE}/${chosen_database} /${VPSNAME}/offline-site"
    display --indent 6 --text "- Moving dropbox backup to offline directory" --result "DONE" --color GREEN

    # Delete project database
    mysql_database_drop "${chosen_database}"

    # Send notification
    send_notification "⚠️ ${VPSNAME}" "Project database'${chosen_database}' deleted!"

    # Delete mysql user
    while true; do

      echo -e "${B_RED}${ITALIC} > Do you want to remove database user? Maybe is used by another project.${ENDCOLOR}"
      read -p "Please type 'y' or 'n'" yn

      case $yn in

      [Yy]*)

        # Log
        clear_last_line
        clear_last_line

        # User delete
        mysql_user_delete "${user_db}"

        break

        ;;

      [Nn]*)

        # Log
        log_event "warning" "Aborting MySQL user deletion ..."
        display --indent 6 --text "- Deleting MySQL user" --result "SKIPPED" --color YELLOW

        break

        ;;

      *) echo " > Please answer yes or no." ;;

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
  # $1 = ${delete_cf_entry} - optional (true or false)

  local project_domain=$1
  local delete_cf_entry=$2

  local files_skipped="false"

  log_section "Project Delete"

  if [[ ${project_domain} == "" ]]; then

    # Folder where sites are hosted: $SITES
    menu_title="PROJECT DIRECTORY TO DELETE"
    directory_browser "${menu_title}" "${SITES}"

    ### Creating temporary folders
    if [[ ! -d "${SFOLDER}/tmp-backup" ]]; then
      mkdir "${SFOLDER}/tmp-backup"
      log_event "info" "Temp files directory created: ${SFOLDER}/tmp-backup"
    fi

    # Directory_broser returns: " $filepath"/"$filename
    if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

      # Log
      display --indent 2 --text "- Selecting directory for deletion" --result "SKIPPED" --color YELLOW
      log_event "info" "Files deletion skipped ..."
      files_skipped="true"

    else

      # Removing last slash from string
      project_domain=${filename%/}

    fi

  fi

  if [[ ${files_skipped} == "false" ]]; then

    log_event "info" "Project to delete: ${project_domain}"
    display --indent 2 --text "- Selecting ${project_domain} for deletion" --result "DONE" --color GREEN

    # Delete Files
    project_delete_files "${project_domain}"

    if [[ ${delete_cf_entry} != "true" ]]; then

      # Cloudflare Manager
      project_domain="$(whiptail --title "CLOUDFLARE MANAGER" --inputbox "Do you want to delete the Cloudflare entries for the followings subdomains?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Delete Cloudflare entries
        cloudflare_delete_a_record "${project_domain}"

      else

        log_event "info" "Cloudflare entries not deleted. Skipped by user."

      fi

    else

      # Delete Cloudflare entries
      cloudflare_delete_a_record "${project_domain}"

    fi

  fi

  # Delete Database
  project_delete_database "${delete_files_result}"

  #TODO: ask for deleting tmp-backup folder?
  # Delete tmp backups
  #rm -R ${SFOLDER}/tmp-backup
  #display --indent 2 --text "Please, remove ${SFOLDER}/tmp-backup after check backup was uploaded ok" --tcolor YELLOW

}

function project_change_status() {

  #$1 = ${project_status}

  local project_status=$1

  local to_change

  startdir="${SITES}"
  directory_browser "${menutitle}" "${startdir}"

  to_change=${filename%/}

  nginx_server_change_status "${to_change}" "${project_status}"

}

function project_get_type() {

  # Parameters
  # $1 = ${dir_path}

  local dir_path=$1

  local project_type
  local is_wp

  if [[ ${dir_path} != "" ]]; then

    is_wp="$(wp_config_path "${dir_path}")"

    if [[ ${is_wp} != "" ]]; then

      project_type="wordpress"

    else

      laravel_v="$(php "${project_dir}/artisan" --version)"

      if [[ ${laravel_v} != "" ]]; then

        project_type="laravel"

      else
        # TODO: implements nodejs,pure php, and others
        project_type="project_type_unknown"

      fi

    fi

  fi

  # Return
  echo "${project_type}"

}

function check_laravel_version() {

  # $1 = ${project_dir} project directory

  local project_dir=$1

  # Return
  echo "${laravel_v}"

}

function php_project_installer() {

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

  if [[ ${project_root_domain} == '' ]]; then

    possible_root_domain="$(get_root_domain "${project_domain}")"
    project_root_domain="$(ask_rootdomain_for_cloudflare_config "${possible_root_domain}")"

  fi

  if [[ ! -d "${project_path}" ]]; then
    # Download WP
    mkdir "${project_path}"
    change_ownership "www-data" "www-data" "${project_path}"

    # Log
    #display --indent 6 --text "- Making a copy of the WordPress project" --result "DONE" --color GREEN

  else

    # Log
    display --indent 6 --text "- Creating WordPress project" --result "FAIL" --color RED
    display --indent 8 --text "Destination folder '${project_path}' already exist"
    log_event "error" "Destination folder '${project_path}' already exist, aborting ..."

    # Return
    return 1

  fi

  db_project_name=$(mysql_name_sanitize "${project_name}")
  database_name="${db_project_name}_${project_state}"
  database_user="${db_project_name}_user"
  database_user_passw="$(openssl rand -hex 12)"

  # Create database and user
  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}" ""
  mysql_user_grant_privileges "${database_user}" "${database_name}"

  # Create project directory
  mkdir "${project_path}"

  # Create index.php
  echo "<?php phpinfo(); ?>" >"${project_path}/index.php"

  # Change ownership
  change_ownership "www-data" "www-data" "${project_path}"

  # TODO: ask for Cloudflare support and check if root_domain is configured on the cf account

  # If domain contains www, should work without www too
  common_subdomain='www'
  if [[ ${project_domain} == *"${common_subdomain}"* ]]; then

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_root_domain}" "A"

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_domain}" "CNAME"

    # New site Nginx configuration
    nginx_server_create "${project_domain}" "php" "root_domain" "${project_root_domain}"

    # HTTPS with Certbot
    project_domain="$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain},${project_root_domain}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      certbot_certificate_install "${MAILA}" "${project_domain},${project_root_domain}"

    else

      # Log
      log_event "info" "HTTPS support for ${project_domain} skipped"
      display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

    fi

  else

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_domain}" "A"

    # New site Nginx configuration
    nginx_create_empty_nginx_conf "${project_path}"
    nginx_create_globals_config
    nginx_server_create "${project_domain}" "php" "single"

    # HTTPS with Certbot
    cert_project_domain="$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      certbot_certificate_install "${MAILA}" "${cert_project_domain}"

    else

      log_event "info" "HTTPS support for ${project_domain} skipped" "false"
      display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

    fi

  fi

  # Log
  log_event "info" "PHP project installation for domain ${project_domain} finished" "false"
  display --indent 6 --text "- PHP project installation for domain ${project_domain}" --result "DONE" --color GREEN

  # Send notification
  send_notification "${VPSNAME}" "PHP project installation for domain ${project_domain} finished!"

}

function nodejs_project_installer() {

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

  log_subsection "NodeJS Project Install"

  nodejs_installed="$(package_is_installed "nodejs")"

  if [[ ${nodejs_installed} == "false" ]]; then

    nodejs_installer

  fi

  if [[ ${project_root_domain} == '' ]]; then

    possible_root_domain="$(get_root_domain "${project_domain}")"
    project_root_domain="$(ask_rootdomain_for_cloudflare_config "${possible_root_domain}")"

  fi

  if [[ ! -d "${project_path}" ]]; then
    # Download WP
    mkdir "${project_path}"
    change_ownership "www-data" "www-data" "${project_path}"

  else

    # Log
    display --indent 6 --text "- Creating NodeJS project" --result "FAIL" --color RED
    display --indent 8 --text "Destination folder '${project_path}' already exist"
    log_event "error" "Destination folder '${project_path}' already exist, aborting ..."

    # Return
    return 1

  fi

  # DB
  db_project_name="$(mysql_name_sanitize "${project_name}")"
  database_name="${db_project_name}_${project_state}"
  database_user="${db_project_name}_user"
  database_user_passw="$(openssl rand -hex 12)"

  ## Create database and user
  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}" ""
  mysql_user_grant_privileges "${database_user}" "${database_name}"

  # Create project directory
  mkdir "${project_path}"

  # Create index.html
  echo "Please configure the project and remove this file." >"${project_path}/index.html"

  # Change ownership
  change_ownership "www-data" "www-data" "${project_path}"

  # TODO: ask for Cloudflare support and check if root_domain is configured on the cf account

  # If domain contains www, should work without www too
  common_subdomain='www'
  if [[ ${project_domain} == *"${common_subdomain}"* ]]; then

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_root_domain}" "A"

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_domain}" "CNAME"

    # New site Nginx configuration
    nginx_server_create "${project_domain}" "php" "root_domain" "${project_root_domain}"

    # HTTPS with Certbot
    project_domain="$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain},${project_root_domain}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      certbot_certificate_install "${MAILA}" "${project_domain},${project_root_domain}"

    else

      # Log
      log_event "info" "HTTPS support for ${project_domain} skipped"
      display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

    fi

  else

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_domain}" "A"

    # New site Nginx configuration
    nginx_create_empty_nginx_conf "${project_path}"
    nginx_create_globals_config
    nginx_server_create "${project_domain}" "nodejs" "single"

    # HTTPS with Certbot
    cert_project_domain="$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      certbot_certificate_install "${MAILA}" "${cert_project_domain}"

    else

      log_event "info" "HTTPS support for ${project_domain} skipped" "false"
      display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

    fi

  fi

  # Log
  log_event "info" "NodeJS project installation for domain ${project_domain} finished" "false"
  display --indent 6 --text "- NodeJS project installation for domain ${project_domain}" --result "DONE" --color GREEN

  # Send notification
  send_notification "${VPSNAME}" "NodeJS project installation for domain ${project_domain} finished!"

}
