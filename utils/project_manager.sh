#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc06
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

# Installation types
installation_types="EMPTY_PROJECT"

installation_type=$(whiptail --title "INSTALLATION TYPE" --menu "Choose an Installation Type" 20 78 10 $(for x in ${installation_types}; do echo "$x [X]"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  folder_to_install=$(ask_folder_to_install_sites "${SITES}")

  if [[ ${installation_type} == *"EMPTY_PROJECT"* ]]; then

    project_domain=$(ask_project_domain)

    possible_root_domain=${project_domain#[[:alpha:]]*.}
    root_domain=$(ask_rootdomain_to_cloudflare_config "${possible_root_domain}")

    project_name=$(ask_project_name "${project_domain}")

    project_state=$(ask_project_state "")

    project_dir=$(check_if_folder_exists "${folder_to_install}" "${project_domain}")

    if [ "${project_dir}" != 'ERROR' ]; then
      
      # TODO: Create dir, and then index.php with echo
      
      echo -e ${B_GREEN}" > Project dir OK!"${ENDCOLOR}
      echo " > Project dir OK!" >>$LOG

    else
      echo -e ${B_RED}" > ERROR: Destination folder '${folder_to_install}/${project_domain}' already exist, aborting ..."${ENDCOLOR}
      echo " > ERROR: Destination folder '${folder_to_install}/${project_domain}' already exist, aborting ..." >>$LOG
      exit 1

    fi

  fi

  # Change ownership
  change_ownership "www-data" "www-data" "${project_dir}"

  # Create database and user
  db_project_name=$(mysql_name_sanitize "${project_name}")
  database_name="${db_project_name}_${project_state}" 
  database_user="${db_project_name}_user"
  database_user_passw=$(openssl rand -hex 12)

  echo -e ${CYAN}"******************************************************************************************"${ENDCOLOR} >&2
  echo -e ${CYAN}" > Creating database ${database_name}, and user ${database_user} with pass ${database_user_passw}"${ENDCOLOR} >&2
  echo -e ${CYAN}"******************************************************************************************"${ENDCOLOR} >&2

  echo " > Creating database ${database_name}, and user ${database_user} with pass ${database_user_passw}" >>$LOG

  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}"
  mysql_user_grant_privileges "${database_user}" "${database_name}"

  # Cloudflare API to change DNS records
  cloudflare_change_a_record "${root_domain}" "${project_domain}"

  # New site Nginx configuration
  create_nginx_server "${project_domain}" "wordpress"

  # HTTPS with Certbot
  certbot_certificate_install "${MAILA}" "${project_domain}"

  echo " > INSTALLATION FINISHED!" >>$LOG
  echo -e ${B_GREEN}" > INSTALLATION FINISHED!"${ENDCOLOR}

fi

main_menu
