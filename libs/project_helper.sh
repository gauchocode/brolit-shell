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

  local dir_path=$1
  local project_type=$2

  folder_to_install=$(ask_folder_to_install_sites "${dir_path}")

  log_section "Project Installer (${project_type})"
  
  project_domain=$(ask_project_domain)

  project_path="${folder_to_install}/${project_domain}"

  possible_root_domain="$(get_root_domain "${project_domain}")"
  root_domain=$(ask_rootdomain_for_cloudflare_config "${possible_root_domain}")

  possible_project_name="$(extract_domain_extension "${project_domain}")"
  project_name="$(ask_project_name "${possible_project_name}")"

  project_state=$(ask_project_state)

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
  change_ownership "www-data" "www-data" "${project_path}"

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

  log_event "success" "PROJECT INSTALLATION FINISHED!"

}