#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc6
################################################################################
#
# WordPress Installer: WordPress installer functions.
#
################################################################################

################################################################################
# Installer menu for a new WordPress Project
#
# Arguments:
#   $1 = ${project_path}
#   $2 = ${project_domain}
#   $3 = ${project_name}
#   $4 = ${project_stage}
#   $5 = ${project_root_domain}   # Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wordpress_project_installer() {

  local project_path="${1}"
  local project_domain="${2}"
  local project_name="${3}"
  local project_stage="${4}"
  local project_root_domain="${5}"

  local installation_types
  local installation_type

  # Installation types
  installation_types=(
    "01)" "CLEAN INSTALL"
    "02)" "COPY FROM PROJECT"
  )
  installation_type=$(whiptail --title "INSTALLATION TYPE" --menu "Choose an Installation Type" 20 78 10 "${installation_types[@]}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${installation_type} == *"COPY"* ]]; then

      wordpress_project_copy "${project_path}" "${project_domain}" "${project_name}" "${project_stage}" "${project_root_domain}"

    else # Clean Install

      wordpress_project_install "${project_path}" "${project_domain}" "${project_name}" "${project_stage}" "${project_root_domain}"

    fi

  fi

}

################################################################################
# New WordPress Project
#
# Arguments:
#   $1 = ${project_path}
#   $2 = ${project_domain}
#   $3 = ${project_name}
#   $4 = ${project_stage}
#   $5 = ${project_root_domain}   # Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wordpress_project_install() {

  local project_path="${1}"
  local project_domain="${2}"
  local project_name="${3}"
  local project_stage="${4}"
  local project_root_domain="${5}"

  log_subsection "WordPress Install"

  if [[ -z ${project_root_domain} ]]; then

    possible_root_domain="$(domain_get_root "${project_domain}")"
    project_root_domain="$(cloudflare_ask_rootdomain "${possible_root_domain}")"

  fi

  if [[ ! -d ${project_path} ]]; then

    # Create project directory
    mkdir "${project_path}"

    # Change directory owner
    change_ownership "www-data" "www-data" "${project_path}"

  else

    # Log
    display --indent 6 --text "- Creating WordPress project" --result "FAIL" --color RED
    display --indent 8 --text "Destination folder '${project_path}' already exist"
    log_event "error" "Destination folder '${project_path}' already exist, aborting ..." "false"

    # Return
    return 1

  fi

  wp_change_permissions "${project_path}"

  # Create database and user
  db_project_name="$(mysql_name_sanitize "${project_name}")"
  database_name="${db_project_name}_${project_stage}"
  database_user="${db_project_name}_user"
  database_user_passw=$(openssl rand -hex 12)

  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}" ""
  mysql_user_grant_privileges "${database_user}" "${database_name}" ""

  # Download WordPress
  wpcli_core_download "${project_path}" ""

  # Create wp-config.php
  wpcli_create_config "${project_path}" "${database_name}" "${database_user}" "${database_user_passw}" "es_ES"

  # Startup Script for WordPress installation

  # TODO: should pass https://$project_domain instead?
  wpcli_run_startup_script "${project_path}" "${project_domain}"

  # Set WP salts
  wpcli_set_salts "${project_path}"

  # TODO: ask for Cloudflare support and check if root_domain is configured on the cf account

  # If domain contains www, should work without www too
  common_subdomain='www'
  if [[ ${project_domain} == *"${common_subdomain}"* ]]; then

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_root_domain}" "A" "false" "${SERVER_IP}"

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_domain}" "CNAME" "false" "${project_root_domain}"

    # New site Nginx configuration
    nginx_server_create "${project_domain}" "wordpress" "root_domain" "${project_root_domain}"

    if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then

      # HTTPS with Certbot
      project_domain=$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain},${project_root_domain}" 3>&1 1>&2 2>&3)

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        certbot_certificate_install "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${project_domain},${project_root_domain}"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          nginx_server_add_http2_support "${project_domain}"

        fi

      else

        log_event "info" "HTTPS support for ${project_domain} skipped"
        display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

      fi

    fi

  else

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_domain}" "A" "false" "${SERVER_IP}"

    # New site Nginx configuration
    nginx_create_empty_nginx_conf "${project_path}"
    nginx_create_globals_config
    nginx_server_create "${project_domain}" "wordpress" "single" ""

    if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then

      # HTTPS with Certbot
      cert_project_domain=$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        certbot_certificate_install "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${cert_project_domain}"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          nginx_server_add_http2_support "${project_domain}"

          exitstatus=$?
          if [[ ${exitstatus} -eq 0 ]]; then

            http2_support="true"

          fi

        fi

      fi

    else

      log_event "info" "HTTPS support for ${project_domain} skipped" "false"
      display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

    fi

  fi

  # Create project config file
  cert_primary_domain="$(echo "${cert_project_domain}" | cut -d "," -f 1)"
  cert_path="/etc/letsencrypt/live/${cert_primary_domain}"
  if [[ ! -d ${cert_path} ]]; then
    cert_path=""
  fi

  # Create project config file

  # Arguments:
  #  $1 = ${project_path}
  #  $2 = ${project_name}
  #  $3 = ${project_stage}
  #  $4 = ${project_type}
  #  $5 = ${project_db_status}
  #  $6 = ${project_db_engine}
  #  $7 = ${project_db_name}
  #  $8 = ${project_db_host}
  #  $9 = ${project_db_user}
  #  $10 = ${project_db_pass}
  #  $11 = ${project_prymary_subdomain}
  #  $12 = ${project_secondary_subdomains}
  #  $13 = ${project_override_nginx_conf}
  #  $14 = ${project_use_http2}
  #  $15 = ${project_certbot_mode}

  project_update_brolit_config "${project_path}" "${project_name}" "${project_stage}" "wordpress" "enabled" "mysql" "${database_name}" "localhost" "${database_user}" "${database_user_passw}" "${project_domain}" "" "/etc/nginx/sites-available/${project_domain}" "${http2_support}" "${cert_path}"

  # Log
  log_event "info" "WordPress installation for domain ${project_domain} finished" "false"
  display --indent 6 --text "- WordPress installation" --result "DONE" --color GREEN
  display --indent 8 --text "for domain ${project_domain}"

  # Send notification
  send_notification "✅ ${SERVER_NAME}" "WordPress installation for domain ${project_domain} finished" ""

  return 0

}

################################################################################
# Copy a WordPress Project
#
# Arguments:
#   $1 = ${project_path}
#   $2 = ${project_domain}
#   $3 = ${project_name}
#   $4 = ${project_stage}
#   $5 = ${project_root_domain}   # Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# TODO: NEEDS REFACTOR

function wordpress_project_copy() {

  local project_path="${1}"
  local project_domain="${2}"
  local project_name="${3}"
  local project_stage="${4}"
  local project_root_domain="${5}"

  log_subsection "Copy From Project"

  startdir="${folder_to_install}"
  menutitle="Site Selection Menu"
  directory_browser "${menutitle}" "${startdir}"
  copy_project_path="${filepath}/${filename}"

  # Log
  display --indent 6 --text "- Preparing to copy project" --result "DONE" --color GREEN
  display --indent 8 --text "Path: ${copy_project_path}"
  log_event "info" "Setting copy_project_path=${copy_project_path}" "false"

  copy_project="$(basename "${copy_project_path}")"

  log_event "info" "Setting copy_project=${copy_project}" "false"

  # TODO: ask if want to exclude directory

  if [[ -d "${folder_to_install}/${project_domain}" ]]; then
    # Make a copy of the existing project
    log_event "info" "Making a copy of ${copy_project} on ${project_dir} ..." "false"

    #cd "${folder_to_install}"
    copy_files "${folder_to_install}/${copy_project}" "${project_dir}"

    # Logging
    display --indent 6 --text "- Making a copy of the WordPress project" --result "DONE" --color GREEN
    log_event "info" "WordPress files copied" "false"

  else
    # Logging
    display --indent 6 --text "- Making a copy of the WordPress project" --result "FAIL" --color RED
    display --indent 8 --text "Destination folder '${folder_to_install}/${project_domain}' already exist, aborting ..."
    log_event "error" "Destination folder '${folder_to_install}/${project_domain}' already exist, aborting ..." "false"

    # Return
    return 1

  fi

  wp_change_permissions "${project_dir}"

  # Create database and user
  db_project_name="$(mysql_name_sanitize "${project_name}")"
  database_name="${db_project_name}_${project_stage}"
  database_user="${db_project_name}_user"
  database_user_passw="$(openssl rand -hex 12)"

  log_event "info" "Creating database ${database_name}, and user ${database_user} with pass ${database_user_passw}"

  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}" ""
  mysql_user_grant_privileges "${database_user}" "${database_name}" ""

  log_event "info" "Copying database ${database_name} ..." "false"

  # Create dump file

  # We get the database name from the copied wp-config.php
  source_wpconfig="${folder_to_install}/${copy_project}"
  db_tocopy="$(cat ${source_wpconfig}/wp-config.php | grep DB_NAME | cut -d \' -f 4)"
  bk_file="db-${db_tocopy}.sql"

  # Make a database Backup
  mysql_database_export "${db_tocopy}" "${BROLIT_TMP_DIR}/${bk_file}"
  mysql_database_export_result=$?
  if [[ ${mysql_database_export_result} -eq 0 ]]; then

    # Target database
    target_db="${project_name}_${project_stage}"

    # Importing dump file
    mysql_database_import "${target_db}" "${BROLIT_TMP_DIR}/${bk_file}"

    # Generate WP tables PREFIX
    tables_prefix="$(cat /dev/urandom | tr -dc 'a-z' | fold -w 3 | head -n 1)"
    # Change WP tables PREFIX
    wpcli_db_change_tables_prefix "${project_dir}" "${tables_prefix}"

    # WP Search and Replace URL
    wp_ask_url_search_and_replace "${project_dir}"

  else

    return 1

  fi

  # Set WP salts
  wpcli_set_salts "${project_dir}"

  # TODO: ask for Cloudflare support and check if root_domain is configured on the cf account

  # If domain contains www, should work without www too
  common_subdomain='www'
  if [[ ${project_domain} == *"${common_subdomain}"* ]]; then

    # Cloudflare API to change DNS records
    cloudflare_set_record "${root_domain}" "${root_domain}" "A" "false" "${SERVER_IP}"

    # Cloudflare API to change DNS records
    cloudflare_set_record "${root_domain}" "${project_domain}" "CNAME" "false" "${root_domain}"

    # New site Nginx configuration
    nginx_server_create "${project_domain}" "wordpress" "root_domain" "${root_domain}"

    if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then

      # HTTPS with Certbot
      project_domain=$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain},${root_domain}" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        certbot_certificate_install "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${project_domain},${root_domain}"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          nginx_server_add_http2_support "${project_domain}"

        fi

      else

        log_event "info" "HTTPS support for ${project_domain} skipped"
        display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

      fi

    fi

  else

    # Cloudflare API to change DNS records
    cloudflare_set_record "${root_domain}" "${project_domain}" "A" "false" "${SERVER_IP}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # New site Nginx configuration
      nginx_create_empty_nginx_conf "${PROJECTS_PATH}/${project_domain}"
      nginx_create_globals_config
      nginx_server_create "${project_domain}" "wordpress" "single" ""

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then

          # HTTPS with Certbot
          cert_project_domain="$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)"
          exitstatus=$?
          if [[ ${exitstatus} -eq 0 ]]; then

            certbot_certificate_install "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${cert_project_domain}"

            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then

              nginx_server_add_http2_support "${project_domain}"

            fi

          else

            log_event "info" "HTTPS support for ${project_domain} skipped" "false"
            display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

          fi

        fi

      else

        display --indent 6 --text "- Configuring nginx for ${project_domain}" --result "ERROR" --color RED
        display --indent 8 --text "Please, fix nginx configuration, and run certbot manually to install a certificate"
        log_event "error" "Configuring nginx for ${project_domain}!" "false"

        return 1

      fi

    else

      display --indent 6 --text "- HTTPS support for ${project_domain}" --result "WARNING" --color YELLOW
      display --indent 8 --text "Can't update DNS record, please change it manually and run certbot to install certificate!"
      log_event "warning" "Can't update DNS record, please change it manually and run certbot to install certificate!" "false"

      return 1

    fi

  fi

  # Log
  log_event "info" "WordPress installation for domain ${project_domain} finished" "false"
  display --indent 6 --text "- WordPress installation" --result "DONE" --color GREEN
  display --indent 8 --text "for domain ${project_domain}"

  # Send notification
  send_notification "✅ ${SERVER_NAME}" "WordPress installation for domain ${project_domain} finished" ""

  return 0

}
