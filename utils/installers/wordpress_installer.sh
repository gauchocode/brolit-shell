#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc03
################################################################################
#
# https://github.com/AbhishekGhosh/Ubuntu-16.04-Nginx-WordPress-Autoinstall-Bash-Script/
# https://alonganon.info/2018/11/17/make-a-super-fast-and-lightweight-wordpress-on-ubuntu-18-04-with-php-7-2-nginx-and-mariadb/
#
################################################################################
#
# TODO: check when add www.DOMINIO.com and then select other stage != prod
# TODO: add multisite support
#

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/mail_notification_helper.sh"
source "${SFOLDER}/libs/mysql_helper.sh"
source "${SFOLDER}/libs/wpcli_helper.sh"
source "${SFOLDER}/libs/wordpress_helper.sh"
source "${SFOLDER}/libs/nginx_helper.sh"
source "${SFOLDER}/libs/certbot_helper.sh"

################################################################################

################################################################################

# Installation types
INSTALLATION_TYPES="CLEAN_INSTALL COPY_FROM_PROJECT"

INSTALLATION_TYPE=$(whiptail --title "INSTALLATION TYPE" --menu "Choose an Installation Type" 20 78 10 $(for x in ${INSTALLATION_TYPES}; do echo "$x [X]"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  wpcli_install_if_not_installed

  FOLDER_TO_INSTALL=$(ask_folder_to_install_sites "${SITES}")

  if [[ ${INSTALLATION_TYPE} == *"COPY"* ]]; then

    startdir=${FOLDER_TO_INSTALL}
    menutitle="Site Selection Menu"
    directory_browser "$menutitle" "$startdir"
    COPY_PROJECT_PATH=$filepath"/"$filename
    echo "Setting COPY_PROJECT_PATH=${COPY_PROJECT_PATH}"

    COPY_PROJECT=$(basename $COPY_PROJECT_PATH)
    echo "Setting COPY_PROJECT=${COPY_PROJECT}"

    #ask_domain_to_install_site
    ask_project_domain

    POSSIBLE_ROOT_DOMAIN=${PROJECT_DOMAIN#[[:alpha:]]*.}
    ask_rootdomain_to_cloudflare_config "${POSSIBLE_ROOT_DOMAIN}"

    ask_project_name "${PROJECT_DOMAIN}"

    ask_project_state ""

    project_dir=$(check_if_folder_exists "${FOLDER_TO_INSTALL}" "${PROJECT_DOMAIN}")
    if [ "${project_dir}" != 'ERROR' ]; then
      # Make a copy of the existing project
      echo "Making a copy of ${COPY_PROJECT} ..." >>$LOG
      echo -e ${CYAN}"Making a copy of ${COPY_PROJECT} ..."${ENDCOLOR}

      cd "${FOLDER_TO_INSTALL}"
      cp -r "${FOLDER_TO_INSTALL}/${COPY_PROJECT}" "${project_dir}"

      echo "DONE" >>$LOG

    else
      echo -e ${B_RED}"ERROR: Destination folder '${project_dir}' already exist, aborting ..."${ENDCOLOR}
      echo "FAIL" >>$LOG
      exit 1

    fi

  else # Clean Install

    ask_project_domain

    POSSIBLE_ROOT_DOMAIN=${PROJECT_DOMAIN#[[:alpha:]]*.}
    ask_rootdomain_to_cloudflare_config "${POSSIBLE_ROOT_DOMAIN}"

    ask_project_name "${PROJECT_DOMAIN}"

    ask_project_state ""

    project_dir=$(check_if_folder_exists "${FOLDER_TO_INSTALL}" "${PROJECT_DOMAIN}")
    if [ "${project_dir}" != 'ERROR' ]; then
      # Download WP
      wp_download_wordpress "${FOLDER_TO_INSTALL}" "${PROJECT_DOMAIN}"
      echo "WordPress downloaded OK!" >>$LOG

    else
      echo -e ${B_RED}"ERROR: Destination folder '${project_dir}' already exist, aborting ..."${ENDCOLOR}
      echo "FAIL" >>$LOG
      exit 1

    fi

  fi

  wp_change_ownership "${project_dir}"

  # Create database and user
  wp_database_creation "${PROJECT_NAME}" "${PROJECT_STATE}"

  # Update wp-config.php
  if [[ -z "${DB_PASS}" ]]; then
    wp_update_wpconfig "${project_dir}" "${PROJECT_NAME}" "${PROJECT_STATE}" ""
  
  else
    wp_update_wpconfig "${project_dir}" "${PROJECT_NAME}" "${PROJECT_STATE}" "${DB_PASS}"
  
  fi
  
  # Set WP salts
  wp_set_salts

  if [[ ${INSTALLATION_TYPE} == *"COPY"* ]]; then

    echo " > Copying database ..." >>$LOG
    echo -e ${YELLOW}" > Copying database ..."${ENDCOLOR}

    # Create dump file
    BK_FOLDER=${SFOLDER}/tmp/

    # We get the database name from the copied wp-config.php
    SOURCE_WPCONFIG="${FOLDER_TO_INSTALL}/${COPY_PROJECT}"
    DB_TOCOPY=$(cat ${SOURCE_WPCONFIG}/wp-config.php | grep DB_NAME | cut -d \' -f 4)
    BK_FILE="db-${DB_TOCOPY}.sql"

    # Make a database Backup
    mysql_database_export "${DB_TOCOPY}" "${BK_FOLDER}${BK_FILE}"
    if [ "$?" -eq 0 ]; then

      echo " > mysqldump for ${DB_TOCOPY} OK ..." >>$LOG
      echo -e ${GREEN}" > mysqldump for ${DB_TOCOPY} OK ..."${ENDCOLOR}

      echo " > Trying to import database ..." >>$LOG
      echo -e ${YELLOW}" > Trying to import database ..."${ENDCOLOR}

      TARGET_DB="${PROJECT_NAME}_${PROJECT_STATE}"
      #$MYSQL -u ${MUSER} --password=${MPASS} ${NEW_PROJECT_DB} <${BK_FOLDER}${BK_FILE}

      # Importing dump file
      mysql_database_import "${TARGET_DB}" "${BK_FOLDER}${BK_FILE}"

      # Generate WP tables PREFIX
      TABLES_PREFIX=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 3 | head -n 1)
      # Change WP tables PREFIX
      wpcli_change_tables_prefix "${project_dir}" "${TABLES_PREFIX}"

      # Create tmp directory
      mkdir "${SFOLDER}/tmp-backup"

      # Make a database Backup before replace URLs
      mysql_database_export "${TARGET_DB}" "${SFOLDER}/tmp-backup/${TARGET_DB}_bk_before_replace_urls.sql"

      # WP Search and Replace URL
      ask_url_search_and_replace "${project_dir}"

    else
      echo " > mysqldump ERROR: $? ..." >>$LOG
      echo -e ${B_RED}" > mysqldump ERROR: $? ..."${ENDCOLOR}
      echo -e ${B_RED}" > Aborting ..."${ENDCOLOR}
      exit 1

    fi

  fi

  # Cloudflare API to change DNS records
  echo "Trying to access Cloudflare API and change record ${PROJECT_DOMAIN} ..." >>$LOG
  echo -e ${YELLOW}"Trying to access Cloudflare API and change record ${PROJECT_DOMAIN} ..."${ENDCOLOR}

  zone_name=${ROOT_DOMAIN}
  record_name=${PROJECT_DOMAIN}
  export zone_name record_name
  "${SFOLDER}/utils/cloudflare_update_IP.sh"

  # New site Nginx configuration
  create_nginx_server "${PROJECT_DOMAIN}" "wordpress"

  # HTTPS with Certbot
  certbot_certificate_install "${MAILA}" "${PROJECT_DOMAIN}"

  echo " > WORDPRESS INSTALLATION FINISHED!" >>$LOG
  echo -e ${B_GREEN}" > WORDPRESS INSTALLATION FINISHED!"${ENDCOLOR}

fi

main_menu
