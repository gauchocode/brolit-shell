#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.6
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"
# shellcheck source=${SFOLDER}/libs/telegram_notification_helper.sh
source "${SFOLDER}/libs/telegram_notification_helper.sh"
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

wordpress_installer () {

  local installation_types
  local installation_type
  local folder_to_install

  # Installation types
  installation_types=("01)" "CLEAN INSTALL" "02)" "COPY FROM PROJECT")

  installation_type=$(whiptail --title "INSTALLATION TYPE" --menu "Choose an Installation Type" 20 78 10 "${installation_types[@]}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    log_section "WordPress Installer"

    wpcli_install_if_not_installed

    folder_to_install=$(ask_folder_to_install_sites "${SITES}")

    if [[ ${installation_type} == *"COPY"* ]]; then

      startdir=${folder_to_install}
      menutitle="Site Selection Menu"
      directory_browser "${menutitle}" "${startdir}"
      copy_project_path=$filepath"/"$filename

      log_event "info" "Setting copy_project_path=${copy_project_path}"

      copy_project="$(basename "${copy_project_path}")"

      log_event "info" "Setting copy_project=${copy_project}"

      #ask_domain_to_install_site
      project_domain=$(ask_project_domain)

      possible_root_domain=${project_domain#[[:alpha:]]*.}
      root_domain=$(ask_rootdomain_for_cloudflare_config "${possible_root_domain}")

      project_name=$(ask_project_name "${project_domain}")

      project_state=$(ask_project_state "")

      # TODO: ask if want to exclude directory

      project_dir=$(check_if_folder_exists "${folder_to_install}" "${project_domain}")

      if [ "${project_dir}" != 'ERROR' ]; then
        # Make a copy of the existing project
        log_event "info" "Making a copy of ${copy_project} on ${project_dir} ..."

        #cd "${folder_to_install}"
        copy_project_files "${folder_to_install}/${copy_project}" "${project_dir}"

        log_event "success" "WordPress files copied"

      else
        log_event "error" "Destination folder '${folder_to_install}/${project_domain}' already exist, aborting ..." "true"
        return 1

      fi

    else # Clean Install

      project_domain="$(ask_project_domain)"
      possible_root_domain=$(get_root_domain "${project_domain}")
      root_domain="$(ask_rootdomain_for_cloudflare_config "${possible_root_domain}")"

      possible_project_name="$(extract_domain_extension "${project_domain}")"
      project_name="$(ask_project_name "${possible_project_name}")"

      project_state="$(ask_project_state)"

      project_dir="$(check_if_folder_exists "${folder_to_install}" "${project_domain}")"

      if [ "${project_dir}" != 'ERROR' ]; then
        # Download WP
        mkdir "${folder_to_install}/${project_domain}"
        change_ownership "www-data" "www-data" "${folder_to_install}/${project_domain}"
        wpcli_core_install "${folder_to_install}/${project_domain}"

        

      else
        log_event "error" "Destination folder '${folder_to_install}/${project_domain}' already exist, aborting ..." "true"
        return 1

      fi

    fi

    wp_change_permissions "${project_dir}"

    # Create database and user
    db_project_name=$(mysql_name_sanitize "${project_name}")
    database_name="${db_project_name}_${project_state}" 
    database_user="${db_project_name}_user"
    database_user_passw=$(openssl rand -hex 12)

    #log_break "true"
    log_event "info" "Creating database ${database_name}, and user ${database_user} with pass ${database_user_passw}" "false"
    #log_break "true"

    mysql_database_create "${database_name}"
    mysql_user_create "${database_user}" "${database_user_passw}"
    mysql_user_grant_privileges "${database_user}" "${database_name}"

    wpcli_create_config "${project_dir}" "${database_name}" "${database_user}" "${database_user_passw}" "es_ES"
    
    # Set WP salts
    wpcli_set_salts "${project_dir}"

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
      mysql_database_export_result=$?
      if [ "${mysql_database_export_result}" -eq 0 ]; then

        # Target database
        target_db="${project_name}_${project_state}"

        log_event "info" "Trying to import database: ${target_db}" "true"

        # Importing dump file
        mysql_database_import "${target_db}" "${bk_folder}${bk_file}"

        # Generate WP tables PREFIX
        tables_prefix=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 3 | head -n 1)
        # Change WP tables PREFIX
        wpcli_change_tables_prefix "${project_dir}" "${tables_prefix}"

        # WP Search and Replace URL
        wp_ask_url_search_and_replace "${project_dir}"

      else
        log_event "error" "mysqldump message: $?" "true"
        return 1

      fi

    fi

    # TODO: ask for Cloudflare support and check if root_domain is configured on the cf account

    # If domain contains www, should work without www too
    common_subdomain='www'
    if [[ ${project_domain} == *"${common_subdomain}"* ]]; then

      # Cloudflare API to change DNS records
      cloudflare_change_a_record "${root_domain}" "${project_domain}" "false"

      # Cloudflare API to change DNS records
      cloudflare_change_a_record "${root_domain}" "${root_domain}" "false"

      # New site Nginx configuration
      nginx_server_create "${project_domain}" "wordpress" "root_domain" "${root_domain}"

      # HTTPS with Certbot
      project_domain=$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain},${root_domain}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        certbot_certificate_install "${MAILA}" "${project_domain},${root_domain}"

      else

        log_event "info" "HTTPS support for ${project_domain} skipped" "false"
        display --indent 2 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

      fi  

    else

      # Cloudflare API to change DNS records
      cloudflare_change_a_record "${root_domain}" "${project_domain}" "false"

      # New site Nginx configuration
      nginx_create_empty_nginx_conf "${SITES}/${project_domain}"
      nginx_server_create "${project_domain}" "wordpress" "single" ""

      # HTTPS with Certbot
      cert_project_domain=$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        
        certbot_certificate_install "${MAILA}" "${cert_project_domain}"

      else

        log_event "info" "HTTPS support for ${project_domain} skipped" "false"
        display --indent 2 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

      fi
      
    fi

    log_event "success" "WordPress installation for domain ${project_domain} finished" "false"
    display --indent 2 --text "- WordPress installation for domain ${project_domain}" --result "DONE" --color GREEN

    telegram_send_message "${VPSNAME}: WordPress installation for domain ${project_domain} finished"

  fi

}

################################################################################

wordpress_installer
