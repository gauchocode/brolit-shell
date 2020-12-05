#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.8
################################################################################
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

project_install() {

  # $1 = ${dir_path}
  # $2 = ${project_type}

  local dir_path=$1
  local project_type=$2

  folder_to_install=$(ask_folder_to_install_sites "${dir_path}")

  log_event "info" "Starting project installer ..."
  log_subsection "Project Installer"
  
  project_domain=$(ask_project_domain)

  possible_root_domain="$(get_root_domain "${project_domain}")"
  root_domain=$(ask_rootdomain_for_cloudflare_config "${possible_root_domain}")

  project_name=$(ask_project_name "${project_domain}")

  project_state=$(ask_project_state "")

  case ${project_type} in

    wordpress)
      log_event "error" "WordPress installer should be implemented soon, aborting ..."
      ;;

    laravel)
      log_event "error" "Laravel installer should be implemented soon, aborting ..."
      ;;

    php)

        project_dir=$(check_if_folder_exists "${folder_to_install}" "${project_domain}")

        if [ "${project_dir}" != 'ERROR' ]; then
          
          # Create project directory
          mkdir "${folder_to_install}/${project_domain}"

          # Create index.php
          echo "<?php phpinfo(); ?>" > "${folder_to_install}/${project_domain}/index.php"

        else

          log_event "error" "Destination folder '${folder_to_install}/${project_domain}' already exist, aborting ..."
          return 1

        fi

      ;;

    *)
      log_event "error" "Project Type ${project_type} unkwnown, aborting ..."
      ;;
  esac

  # Change ownership
  change_ownership "www-data" "www-data" "${project_dir}"

  # TODO: ask if we want create a database

  # Create database and user
  db_project_name=$(mysql_name_sanitize "${project_name}")
  database_name="${db_project_name}_${project_state}" 
  database_user="${db_project_name}_user"
  database_user_passw=$(openssl rand -hex 12)

  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}"
  mysql_user_grant_privileges "${database_user}" "${database_name}"

  # Cloudflare API to change DNS records
  cloudflare_change_a_record "${root_domain}" "${project_domain}"

  # New site Nginx configuration
  nginx_server_create "${project_domain}" "wordpress" "single" ""

  # HTTPS with Certbot
  certbot_certificate_install "${MAILA}" "${project_domain}"

  log_event "success" "INSTALLATION FINISHED!"

}