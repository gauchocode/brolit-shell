#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc07
################################################################################
#
# TODO: check when add www.DOMAIN.com and then select other stage != prod
# TODO: add multisite support
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
# shellcheck source=${SFOLDER}/libs/wpcli_helper.sh
source "${SFOLDER}/libs/wpcli_helper.sh"
# shellcheck source=${SFOLDER}/libs/wordpress_helper.sh
source "${SFOLDER}/libs/wordpress_helper.sh"
# shellcheck source=${SFOLDER}/libs/nginx_helper.sh
source "${SFOLDER}/libs/nginx_helper.sh"
# shellcheck source=${SFOLDER}/libs/certbot_helper.sh
source "${SFOLDER}/libs/certbot_helper.sh"
# shellcheck source=${SFOLDER}/libs/cloudflare_helper.sh
source "${SFOLDER}/libs/cloudflare_helper.sh"

################################################################################

# Installation types
installation_types="CLEAN_INSTALL COPY_FROM_PROJECT"

installation_type=$(whiptail --title "INSTALLATION TYPE" --menu "Choose an Installation Type" 20 78 10 $(for x in ${installation_types}; do echo "$x [X]"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  wpcli_install_if_not_installed

  folder_to_install=$(ask_folder_to_install_sites "${SITES}")

  if [[ ${installation_type} == *"COPY"* ]]; then

    startdir=${folder_to_install}
    menutitle="Site Selection Menu"
    directory_browser "$menutitle" "$startdir"
    copy_project_path=$filepath"/"$filename
    echo "Setting copy_project_path=${copy_project_path}"

    copy_project=$(basename $copy_project_path)
    echo "Setting copy_project=${copy_project}"

    #ask_domain_to_install_site
    project_domain=$(ask_project_domain)

    possible_root_domain=${project_domain#[[:alpha:]]*.}
    root_domain=$(ask_rootdomain_to_cloudflare_config "${possible_root_domain}")

    project_name=$(ask_project_name "${project_domain}")

    project_state=$(ask_project_state "")

    # TODO: maybe if project state != prod we want to disable some plugins and block search engines

    # TODO: ask if want to exclude directory

    project_dir=$(check_if_folder_exists "${folder_to_install}" "${project_domain}")

    if [ "${project_dir}" != 'ERROR' ]; then
      # Make a copy of the existing project
      echo "Making a copy of ${copy_project} on ${project_dir} ..." >>$LOG
      echo -e ${CYAN}"Making a copy of ${copy_project} on ${project_dir} ..."${ENDCOLOR}

      #cd "${folder_to_install}"
      copy_project_files "${folder_to_install}/${copy_project}" "${project_dir}"

      log_event "success" "WordPress files copied" "true"

    else
      log_event "error" "Destination folder '${folder_to_install}/${project_domain}' already exist, aborting ..." "true"
      return 1

    fi

  else # Clean Install

    project_domain=$(ask_project_domain)

    possible_root_domain=${project_domain#[[:alpha:]]*.}
    root_domain=$(ask_rootdomain_to_cloudflare_config "${possible_root_domain}")

    project_name=$(ask_project_name "${project_domain}")

    project_state=$(ask_project_state "")

    project_dir=$(check_if_folder_exists "${folder_to_install}" "${project_domain}")

    if [ "${project_dir}" != 'ERROR' ]; then
      # Download WP
      wp_download_wordpress "${folder_to_install}" "${project_domain}"
      echo -e ${B_GREEN}" > WordPress downloaded OK!"${ENDCOLOR}
      echo " > WordPress downloaded OK!" >>$LOG

    else
      echo -e ${B_RED}" > ERROR: Destination folder '${folder_to_install}/${project_domain}' already exist, aborting ..."${ENDCOLOR}
      echo " > ERROR: Destination folder '${folder_to_install}/${project_domain}' already exist, aborting ..." >>$LOG
      exit 1

    fi

  fi

  wp_change_ownership "${project_dir}"

  # Create database and user
  db_project_name=$(mysql_name_sanitize "${project_name}")
  database_name="${db_project_name}_${project_state}" 
  database_user="${db_project_name}_user"
  database_user_passw=$(openssl rand -hex 12)

  echo -e ${CYAN}"******************************************************************************************"${ENDCOLOR} >&2
  log_event "info" "Creating database ${database_name}, and user ${database_user} with pass ${database_user_passw}" "true"
  echo -e ${CYAN}"******************************************************************************************"${ENDCOLOR} >&2

  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}"
  mysql_user_grant_privileges "${database_user}" "${database_name}"

  wpcli_create_config "${project_dir}" "${database_name}" "${database_user}" "${DB_PASS}" "es_ES"
  
  # Set WP salts
  wp_set_salts "${project_dir}/wp-config.php"

  if [[ ${installation_type} == *"COPY"* ]]; then

    log_event "info" "Copying database ${database_name} ..." "true"

    # Create dump file
    bk_folder="${SFOLDER}/tmp/"

    # We get the database name from the copied wp-config.php
    source_wpconfig="${folder_to_install}/${copy_project}"
    db_tocopy=$(cat ${source_wpconfig}/wp-config.php | grep DB_NAME | cut -d \' -f 4)
    bk_file="db-${db_tocopy}.sql"

    # Make a database Backup
    mysql_database_export "${db_tocopy}" "${bk_folder}${bk_file}"
    if [ "$?" -eq 0 ]; then

      log_event "success" "mysqldump for ${db_tocopy} OK" "true"

      # Target database
      target_db="${project_name}_${project_state}"

      log_event "info" "Trying to import database: ${target_db}" "true"

      # Importing dump file
      mysql_database_import "${target_db}" "${bk_folder}${bk_file}"

      # Generate WP tables PREFIX
      tables_prefix=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 3 | head -n 1)
      # Change WP tables PREFIX
      wpcli_change_tables_prefix "${project_dir}" "${tables_prefix}"

      # Create tmp directory
      mkdir "${SFOLDER}/tmp-backup"

      # Make a database Backup before replace URLs
      mysql_database_export "${target_db}" "${SFOLDER}/tmp-backup/${target_db}_bk_before_replace_urls.sql"

      # WP Search and Replace URL
      ask_url_search_and_replace "${project_dir}"

    else
      log_event "error" "mysqldump message: $?" "true"
      return 1

    fi

  fi

  # TODO: ask for Cloudflare support

  # Cloudflare API to change DNS records
  cloudflare_change_a_record "${root_domain}" "${project_domain}" "false"

  # New site Nginx configuration
  create_nginx_server "${project_domain}" "wordpress"

  # HTTPS with Certbot
  certbot_certificate_install "${MAILA}" "${project_domain}"

  #cloudflare_change_a_record "${root_domain}" "${project_domain}" "true"

  log_event "success" "Wordpress installation finished!" "true"

fi

main_menu
