#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.3
#############################################################################

function ask_migration_source_type() {

  local migration_source_type="URL DIRECTORY"

  migration_source_type=$(whiptail --title "Migration Source" --menu "Choose the source of the project to restore/migrate:" 20 78 10 "$(for x in ${migration_source_type}; do echo "$x [X]"; done)" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    echo "${migration_source_type}"

  else

    return 1

  fi
}

function ask_migration_source_file() {

  # $1 = ${source_type}

  local source_type=$1

  local source_files_dir
  local source_files_url

  if [[ ${source_type} = "DIRECTORY" ]]; then

    source_files_dir=$(whiptail --title "Source Directory" --inputbox "Please insert the directory where files backup are stored." 10 60 "/root/backups/backup.zip" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Return
      echo "${source_files_dir}"

    else
      return 1

    fi

  else

    source_files_url=$(whiptail --title "Source File URL" --inputbox "Please insert the URL where backup files are stored." 10 60 "http://example.com/backup-files.zip" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Return
      echo "${source_files_url}"

    else
      return 1

    fi

  fi

}

function ask_migration_source_db() {

  # $1 = ${source_type}

  local source_type=$1
  local source_db_dir source_db_url

  if [[ "${source_type}" = "DIRECTORY" ]]; then

    source_db_dir=$(whiptail --title "Source Directory" --inputbox "Please insert the directory where database backup is stored." 10 60 "/root/backups/db.sql.gz" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Return
      echo "${source_db_dir}"

    else
      return 1

    fi

  else

    source_db_url=$(whiptail --title "Source DB URL" --inputbox "Please insert the URL where database backup is stored." 10 60 "http://example.com/backup-db.sql.gz" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Return
      echo "${source_db_url}"

    else
      return 1

    fi

  fi

}

# TODO: need refactor
function wordpress_restore_from_source() {

  # Project details
  project_domain="$(ask_project_domain "")"

  possible_root_domain="$(get_root_domain "${project_domain}")"

  root_domain="$(cloudflare_ask_rootdomain "${possible_root_domain}")"

  project_name="$(ask_project_name "${project_domain}")"

  project_state="$(ask_project_state "")"

  source_type="$(ask_migration_source_type)"

  source_files="$(ask_migration_source_file "$source_type")"

  source_database="$(ask_migration_source_db "$source_type")"

  folder_to_install="$(ask_folder_to_install_sites "${PROJECTS_PATH}")"

  echo " > CREATING TMP DIRECTORY ..."
  mkdir "${SFOLDER}/tmp"
  mkdir "${SFOLDER}/tmp/${project_domain}"
  cd "${SFOLDER}/tmp/${project_domain}"

  if [[ "${source_type}" = "DIRECTORY" ]]; then

    # TODO: use extract function
    unzip \*.zip \* -d "${SFOLDER}/tmp/${project_domain}"

    # DB
    mysql_database_import "${project_name}_${project_state}" "${WP_MIGRATION_SOURCE}/${BK_DB_FILE}"

    cd "${folder_to_install}"

    #mkdir ${project_domain}

    cp -r "${SFOLDER}/tmp/${project_domain}" "${folder_to_install}/${project_domain}"

  else

    # Database Backup details
    bk_db_file=${source_database##*/}
    #echo -e ${MAGENTA}" > bk_db_file= ${bk_db_file} ..."${ENDCOLOR}

    # File Backup details
    bk_f_file=${source_files##*/}
    #echo -e ${MAGENTA}" > bk_f_file= ${bk_f_file} ..."${ENDCOLOR}

    # Download File Backup
    log_event "info" "Downloading file backup ${source_files}" "true"
    wget "${source_files}" >>${LOG}

    # Uncompressing
    log_event "info" "Uncompressing file backup: ${bk_f_file}" "true"
    decompress "${bk_f_file}"

    # Download Database Backup
    log_event "info" "Downloading database backup ${source_database}" "true"
    wget "${source_database}" >>${LOG}

    # Create database and user
    db_project_name=$(mysql_name_sanitize "${project_name}")
    database_name="${db_project_name}_${project_state}"
    database_user="${db_project_name}_user"
    database_user_passw=$(openssl rand -hex 12)

    mysql_database_create "${database_name}"
    mysql_user_create "${database_user}" "${database_user_passw}"
    mysql_user_grant_privileges "${database_user}" "${database_name}"

    # Extract
    gunzip -c "${bk_db_file}" >"${project_name}.sql"
    #decompress "${bk_db_file}"

    # Import dump file
    mysql_database_import "${database_name}" "${project_name}.sql"

    # Remove downloaded files
    log_event "info" "Removing downloaded files ..." "false"
    rm "${SFOLDER}/tmp/${project_domain}/${bk_f_file}"
    rm "${SFOLDER}/tmp/${project_domain}/${bk_db_file}"

    # Move to ${folder_to_install}
    log_event "info" "Moving ${project_domain} to ${folder_to_install} ..." "false"
    mv "${SFOLDER}/tmp/${project_domain}" "${folder_to_install}/${project_domain}"

  fi

  change_ownership "www-data" "www-data" "${folder_to_install}/${project_domain}"

  actual_folder="${folder_to_install}/${project_domain}"

  install_path="$(wp_config_path "${actual_folder}")"
  if [[ -z "${install_path}" ]]; then

    log_event "info" "WORDPRESS INSTALLATION FOUND!" "false"

    # Change file and dir permissions
    wp_change_permissions "${actual_folder}/${install_path}"

    # Change wp-config.php database parameters
    if [[ -z "${DB_PASS}" ]]; then
      wp_update_wpconfig "${actual_folder}/${install_path}" "${project_name}" "${project_state}" ""

    else
      wp_update_wpconfig "${actual_folder}/${install_path}" "${project_name}" "${project_state}" "${DB_PASS}"

    fi

  fi

  # Create nginx config files for site
  nginx_server_create "${project_domain}" "wordpress" "single"

  # Get server IP
  #IP=$(dig +short myip.opendns.com @resolver1.opendns.com) 2>/dev/null

  # TODO: Ask for subdomains to change in Cloudflare (root domain asked before)
  # SUGGEST "${project_domain}" and "www${project_domain}"

  # Cloudflare API to change DNS records
  cloudflare_set_record "${root_domain}" "${project_domain}" "A"

  # HTTPS with Certbot
  certbot_helper_installer_menu "${NOTIFICATION_EMAIL_MAILA}" "${project_domain}"

  # WP Search and Replace URL
  wp_ask_url_search_and_replace

  HTMLOPEN='<html><body>'
  BODY_SRV_MIG='Migración finalizada en '${ELAPSED_TIME}'<br/>'
  BODY_DB='Database: '${project_name}'_'${project_state}'<br/>Database User: '${project_name}'_user <br/>Database User Pass: '${DB_PASS}'<br/>'
  HTMLCLOSE='</body></html>'

  mail_send_notification "${VPSNAME} - Migration Complete: ${project_name}" "${HTMLOPEN} ${BODY_SRV_MIG} ${BODY_DB} ${BODY_CLF} ${HTMLCLOSE}"

}
