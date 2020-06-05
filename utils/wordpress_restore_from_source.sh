#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc04
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/mysql_helper.sh
source "${SFOLDER}/libs/mysql_helper.sh"
# shellcheck source=${SFOLDER}/libs/packages_helper.sh
source "${SFOLDER}/libs/packages_helper.sh"
# shellcheck source=${SFOLDER}/libs/wordpress_helper.sh
source "${SFOLDER}/libs/wordpress_helper.sh"
# shellcheck source=${SFOLDER}/libs/wpcli_helper.sh
source "${SFOLDER}/libs/wpcli_helper.sh"
# shellcheck source=${SFOLDER}/libs/nginx_helper.sh
source "${SFOLDER}/libs/nginx_helper.sh"
# shellcheck source=${SFOLDER}/libs/cloudflare_helper.sh
source "${SFOLDER}/libs/cloudflare_helper.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"

################################################################################

ask_migration_source_type() {

  local migration_source_type="URL DIRECTORY"
  
  migration_source_type=$(whiptail --title "Migration Source" --menu "Choose the source of the project to restore/migrate:" 20 78 10 $(for x in ${migration_source_type}; do echo "$x [X]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    echo "${migration_source_type}"

  else

    exit 1

  fi
}

ask_migration_source_file() {

  # $1 = ${source_type}

  local source_type=$1
  local source_files_dir source_files_url

  if [ "${source_type}" = "DIRECTORY" ]; then

  source_files_dir=$(whiptail --title "Source Directory" --inputbox "Please insert the directory where files backup are stored." 10 60 "/root/backups/backup.zip" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "${source_files_dir}"

  else
    exit 1

  fi

else

  source_files_url=$(whiptail --title "Source File URL" --inputbox "Please insert the URL where backup files are stored." 10 60 "http://example.com/backup-files.zip" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "${source_files_url}"

  else
    exit 0
  fi

fi

}

ask_migration_source_db() {

  # $1 = ${source_type}

  local source_type=$1
  local source_db_dir source_db_url

  if [ "${source_type}" = "DIRECTORY" ]; then

  source_db_dir=$(whiptail --title "Source Directory" --inputbox "Please insert the directory where database backup is stored." 10 60 "/root/backups/db.sql.gz" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "${source_db_dir}"

  else
    exit 1

  fi

else

  source_db_url=$(whiptail --title "Source DB URL" --inputbox "Please insert the URL where database backup is stored." 10 60 "http://example.com/backup-db.sql.gz" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "${source_db_url}"

  else
    exit 0
  fi

fi

}

#############################################################################

### Log Start
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PATH_LOG="${SFOLDER}/logs"
if [ ! -d "${SFOLDER}/logs" ]; then
  echo " > Folder ${SFOLDER}/logs doesn't exist. Creating now ..."
  mkdir "${SFOLDER}/logs"
  echo " > Folder ${SFOLDER}/logs created ..."
fi
LOG_NAME="log_server_migration_${TIMESTAMP}.log"
LOG="$PATH_LOG/$LOG_NAME"

echo "Server Migration:: Script Start -- $(date +%Y%m%d_%H%M)" >>$LOG
START_TIME=$(date +%s)

if test -f /root/.broobe-utils-options; then
  source "/root/.broobe-utils-options"
fi

# Project details
project_domain=$(ask_project_domain)

possible_root_domain=${PROJECT_DOMAIN#[[:alpha:]]*.}

root_domain=$(ask_rootdomain_to_cloudflare_config "${possible_root_domain}")

project_name=$(ask_project_name "${project_domain}")

project_state=$(ask_project_state "")

source_type=$(ask_migration_source_type)

source_files=$(ask_migration_source_file "$source_type")

source_database=$(ask_migration_source_db "$source_type")

folder_to_install=$(ask_folder_to_install_sites "${SITES}")

echo " > CREATING TMP DIRECTORY ..."
mkdir "${SFOLDER}/tmp"
mkdir "${SFOLDER}/tmp/${project_domain}"
cd "${SFOLDER}/tmp/${project_domain}"

if [ "${source_type}" = "DIRECTORY" ]; then

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
  echo -e ${MAGENTA}" > bk_db_file= ${bk_db_file} ..."${ENDCOLOR}

  # File Backup details
  bk_f_file=${source_files##*/}
  echo -e ${MAGENTA}" > bk_f_file= ${bk_f_file} ..."${ENDCOLOR}

  # Download File Backup
  echo -e ${CYAN}" > Downloading file backup ${source_files} ..."${ENDCOLOR}
  wget "${source_files}" >>$LOG

  # Uncompressing
  echo -e ${CYAN}" > Uncompressing file backup ..."${ENDCOLOR}
  #unzip "${bk_f_file}"
  extract "${bk_f_file}"

  # Download Database Backup
  echo -e ${CYAN}" > Downloading database backup ${source_database}..."${ENDCOLOR} >>$LOG
  wget "${source_database}" >>$LOG

  # Create database and user
  wp_database_creation "${project_name}" "${project_state}"

  # Extract
  gunzip -c "${bk_db_file}" > "${project_name}.sql"
  #extract "${bk_db_file}"

  # Import dump file
  mysql_database_import "${project_name}_${project_state}" "${project_name}.sql"

  # Remove downloaded files
  echo -e ${CYAN}" > Removing downloaded files ..."${ENDCOLOR}
  rm "${SFOLDER}/tmp/${project_domain}/${bk_f_file}"
  rm "${SFOLDER}/tmp/${project_domain}/${bk_db_file}"

  # Move to ${folder_to_install}
  echo -e ${CYAN}" > Moving ${project_domain} to ${folder_to_install} ..."${ENDCOLOR}
  mv "${SFOLDER}/tmp/${project_domain}" "${folder_to_install}/${project_domain}"

fi

change_ownership "www-data" "www-data" "${folder_to_install}/${project_domain}"

actual_folder="${folder_to_install}/${project_domain}"

install_path=$(search_wp_config "${actual_folder}")
if [ -z "${install_path}" ]; then

    echo -e ${B_GREEN}" > WORDPRESS INSTALLATION FOUND"${ENDCOLOR}

    # Change file and dir permissions
    wp_change_ownership "${actual_folder}/${install_path}"

    # Change wp-config.php database parameters
    if [[ -z "${DB_PASS}" ]]; then
      wp_update_wpconfig "${actual_folder}/${install_path}" "${project_name}" "${project_state}" ""
      
    else
      wp_update_wpconfig "${actual_folder}/${install_path}" "${project_name}" "${project_state}" "${DB_PASS}"
      
    fi

  fi

# Create nginx config files for site
create_nginx_server "${project_domain}" "wordpress"

# Get server IP
#IP=$(dig +short myip.opendns.com @resolver1.opendns.com) 2>/dev/null

# TODO: Ask for subdomains to change in Cloudflare (root domain asked before)
# SUGGEST "${project_domain}" and "www${project_domain}"

# Cloudflare API to change DNS records
cloudflare_change_a_record "${root_domain}" "${project_domain}"

# HTTPS with Certbot
certbot_helper_installer_menu "${MAILA}" "${project_domain}"

# WP Search and Replace URL
ask_url_search_and_replace

# Log End
END_TIME=$(date +%s)
ELAPSED_TIME=$(expr "${END_TIME}" - "${START_TIME}")

echo "Backup :: Script End -- $(date +%Y%m%d_%H%M)" >>$LOG

HTMLOPEN='<html><body>'
BODY_SRV_MIG='Migración finalizada en '${ELAPSED_TIME}'<br/>'
BODY_DB='Database: '${project_name}'_'${project_state}'<br/>Database User: '${project_name}'_user <br/>Database User Pass: '${DB_PASS}'<br/>'
#BODY_CLF='Ya podes cambiar la IP en CloudFlare: '${IP}'<br/>'
HTMLCLOSE='</body></html>'

sendEmail -f ${SMTP_U} -t "${MAILA}" -u "${VPSNAME} - Migration Complete: ${project_name}" -o message-content-type=html -m "$HTMLOPEN $BODY_SRV_MIG $BODY_DB $BODY_CLF $HTMLCLOSE" -s ${SMTP_SERVER}:${SMTP_PORT} -o tls=${SMTP_TLS} -xu ${SMTP_U} -xp ${SMTP_P}
