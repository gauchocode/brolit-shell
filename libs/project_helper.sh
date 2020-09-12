#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.1
################################################################################
#
# TODO: check when add www.DOMAIN.com and then select other stage != prod
#

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"
# shellcheck source=${SFOLDER}/libs/mysql_helper.sh
source "${SFOLDER}/libs/mysql_helper.sh"
# shellcheck source=${SFOLDER}/libs/nginx_helper.sh
source "${SFOLDER}/libs/nginx_helper.sh"
# shellcheck source=${SFOLDER}/libs/certbot_helper.sh
source "${SFOLDER}/libs/certbot_helper.sh"
# shellcheck source=${SFOLDER}/libs/cloudflare_helper.sh
source "${SFOLDER}/libs/cloudflare_helper.sh"

################################################################################

project_install() {

  # $1 = ${dir_path}
  # $2 = ${project_type}

  local dir_path=$1
  local project_type=$2

  folder_to_install=$(ask_folder_to_install_sites "${dir_path}")

  log_event "info" "Starting project installer ..." "true"
  
  project_domain=$(ask_project_domain)

  possible_root_domain=${project_domain#[[:alpha:]]*.}
  root_domain=$(ask_rootdomain_for_cloudflare_config "${possible_root_domain}")

  project_name=$(ask_project_name "${project_domain}")

  project_state=$(ask_project_state "")

  case $project_type in

    wordpress)
      log_event "error" "WordPress installer should be implemented soon, aborting ..." "true"
      ;;

    laravel)
      log_event "error" "Laravel installer should be implemented soon, aborting ..." "true"
      ;;

    php)

        project_dir=$(check_if_folder_exists "${folder_to_install}" "${project_domain}")

        if [ "${project_dir}" != 'ERROR' ]; then
          
          # Create project directory
          mkdir "${folder_to_install}/${project_domain}"

          # Create index.php
          echo "<?php phpinfo(); ?>" > "${folder_to_install}/${project_domain}/index.php"

        else

          log_event "error" "Destination folder '${folder_to_install}/${project_domain}' already exist, aborting ..." "true"
          return 1

        fi

      ;;

    *)
      log_event "error" "Project Type ${project_type} unkwnown, aborting ..." "true"
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

  log_event "info" "******************************************************************************************" "true"
  log_event "info" "Creating database ${database_name}, and user ${database_user} with pass ${database_user_passw}" "true"
  log_event "info" "******************************************************************************************" "true"

  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}"
  mysql_user_grant_privileges "${database_user}" "${database_name}"

  # Cloudflare API to change DNS records
  cloudflare_change_a_record "${root_domain}" "${project_domain}"

  # New site Nginx configuration
  nginx_server_create "${project_domain}" "wordpress" "single" ""

  # HTTPS with Certbot
  certbot_certificate_install "${MAILA}" "${project_domain}"

  log_event "success" "INSTALLATION FINISHED!" "true"

}