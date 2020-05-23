#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc03
################################################################################

# TO-FIX: mysql restore fail when cant create mysql user
# TO-FIX: sometimes GRANT PRIVILEGES fails, use mysql_helper.sh

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/mysql_helper.sh"
source "${SFOLDER}/libs/wpcli_helper.sh"
source "${SFOLDER}/libs/wordpress_helper.sh"
source "${SFOLDER}/libs/mail_notification_helper.sh"

################################################################################

make_temp_files_backup() {

  # $1 = Folder to backup

  FOLDER_TO_BACKUP=$1

  mkdir "${SFOLDER}/tmp/old_backup"
  mv "${FOLDER_TO_BACKUP}" "${SFOLDER}/tmp/old_backup"

  echo " > Backup completed and stored here: ${SFOLDER}/tmp/old_backup ..." >>$LOG
  echo -e ${GREEN}" > Backup completed and stored here: ${SFOLDER}/tmp/old_backup ..."${ENDCOLOR}

}

make_temp_db_backup() {

  if [ -d "/var/lib/mysql/${CHOSEN_PROJECT}" ]; then
    echo -e ${YELLOW}" > Executing mysqldump (will work if database exists) ..."${ENDCOLOR}
    mysqldump -u "${MUSER}" --password="${MPASS}" "${CHOSEN_PROJECT}" >"${CHOSEN_PROJECT}_bk_before_restore.sql"

  fi

}

restore_database_backup() {

  #$1 = ${CHOSEN_PROJECT}
  #$2 = ${CHOSEN_BACKUP}

  CHOSEN_PROJECT=$1
  CHOSEN_BACKUP=$2

  echo " > Running restore_database_backup for ${CHOSEN_BACKUP} DB" >>$LOG
  echo -e "${CYAN} > Running restore_database_backup for ${CHOSEN_BACKUP} DB ${ENDCOLOR}"

  # Asking project state with suggested actual state
  suffix="$(cut -d'_' -f2 <<<"${CHOSEN_PROJECT}")"
  ask_project_state "${suffix}"

  # Extract PROJECT_NAME (its removes last part of db name with "_" char)

  PROJECT_NAME=${CHOSEN_PROJECT%"_$suffix"}

  PROJECT_NAME=$(whiptail --title "Project Name" --inputbox "Want to change the project name?" 10 60 "${PROJECT_NAME}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "Setting PROJECT_NAME=${PROJECT_NAME}" >>$LOG
  else
    exit 1
  fi

  DB_USER="${PROJECT_NAME}_user"
  DB_NAME="${PROJECT_NAME}_${PROJECT_STATE}"

  # Check if database already exists
  DB_EXISTS=$(mysql_database_exists "${DB_NAME}")
  if [[ ${DB_EXISTS} -eq 1 ]]; then  
    echo -e ${CYAN}" > Creating '${DB_NAME}' database in MySQL ..."${ENDCOLOR}
    echo "Creating '${DB_NAME}' database in MySQL ..." >>$LOG
    mysql_database_create "${DB_NAME}"

  else
    echo -e ${B_GREEN}" > MySQL DB ${MYSQL_DB_TO_TEST} already exists"${ENDCOLOR}

    #TODO: ask what to do, if continue make a database backup

  fi

  # Check if user database already exists
  USER_DB_EXISTS=$(mysql_user_exists "${DB_USER}")
  if [[ ${USER_DB_EXISTS} -eq 0 ]]; then

    DB_PASS=$(openssl rand -hex 12)

    echo -e ${B_CYAN}" > Creating '${DB_USER}' user in MySQL with pass: ${DB_PASS}"${B_ENDCOLOR}
    echo " > Creating ${DB_USER} user in MySQL with pass: ${DB_PASS}" >>$LOG

    mysql_user_create "${DB_USER}" "${DB_PASS}"

  else
    echo -e ${B_GREEN}" > User ${DB_USER} already exists"${B_ENDCOLOR}
    echo " > User ${DB_USER} already exists"${ENDCOLOR} >>$LOG

  fi

  # Grant privileges to database user
  mysql_user_grant_privileges "${DB_USER}" "${DB_NAME}"

  # Trying to restore Database
  CHOSEN_BACKUP="${CHOSEN_BACKUP%%.*}.sql"
  mysql_database_import "${PROJECT_NAME}_${PROJECT_STATE}" "${CHOSEN_BACKUP}"

  echo -e ${CYAN}" > Cleanning temp files ..."${ENDCOLOR}
  rm ${CHOSEN_BACKUP%%.*}.sql
  rm "${CHOSEN_BACKUP}"
  echo -e ${B_GREEN}" > DONE"${ENDCOLOR}

}

select_and_restore_config_from_dropbox(){

  #$1 = ${DROPBOX_CHOSEN_TYPE_PATH}
  #$2 = ${DROPBOX_PROJECT_LIST}

  DROPBOX_CHOSEN_TYPE_PATH=$1
  DROPBOX_PROJECT_LIST=$2

  # Select config backup type
  CHOSEN_CONFIG_TYPE=$(whiptail --title "RESTORE CONFIGS BACKUPS" --menu "Choose a config backup type." 20 78 10 $(for x in ${DROPBOX_PROJECT_LIST}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    #Restore from Dropbox
    DROPBOX_BK_LIST=$($DROPBOX_UPLOADER -hq list "${DROPBOX_CHOSEN_TYPE_PATH}/${CHOSEN_CONFIG_TYPE}")
  fi

  CHOSEN_CONFIG_BK=$(whiptail --title "RESTORE CONFIGS BACKUPS" --menu "Choose a config backup file to restore." 20 78 10 $(for x in ${DROPBOX_BK_LIST}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?

  if [ $exitstatus = 0 ]; then

    cd "${SFOLDER}/tmp"

    echo " > Downloading from Dropbox ${DROPBOX_CHOSEN_TYPE_PATH}/${CHOSEN_CONFIG_TYPE}/${CHOSEN_CONFIG_BK} ..." >>$LOG
    $DROPBOX_UPLOADER download "${DROPBOX_CHOSEN_TYPE_PATH}/${CHOSEN_CONFIG_TYPE}/${CHOSEN_CONFIG_BK}"

    # Restore files
    mkdir "${CHOSEN_CONFIG_TYPE}"
    mv "${CHOSEN_CONFIG_BK}" "${CHOSEN_CONFIG_TYPE}"
    cd "${CHOSEN_CONFIG_TYPE}"

    echo -e ${YELLOW} " > Uncompressing ${CHOSEN_CONFIG_BK}" ${ENDCOLOR}
    echo " > Uncompressing ${CHOSEN_CONFIG_BK}" >>$LOG
    
    pv "${CHOSEN_CONFIG_BK}" | tar xp -C "${SFOLDER}/tmp/${CHOSEN_CONFIG_TYPE}" --use-compress-program=lbzip2

    if [[ "${CHOSEN_CONFIG_BK}" == *"nginx"* ]]; then

      # TODO: if nginx is installed, ask if nginx.conf must be replace

      # Checking if default nginx folder exists
      if [[ -n "${WSERVER}" ]]; then

        echo -e ${GREEN}" > Folder ${WSERVER} exists ... OK"${ENDCOLOR}

        startdir="${SFOLDER}/tmp/${CHOSEN_CONFIG_TYPE}/sites-available"
        file_browser "$menutitle" "$startdir"

        to_restore=$filepath"/"$filename
        echo -e ${YELLOW}" > File to restore: ${to_restore} ..."${ENDCOLOR}

        if [[ -f "${WSERVER}/sites-available/${filename}" ]]; then

          echo " > File ${WSERVER}/sites-available/${filename} already exists. Making a backup file ..." >>$LOG
          echo -e ${YELLOW}" > File ${WSERVER}/sites-available/${filename} already exists. Making a backup file ..."${ENDCOLOR}
          mv "${WSERVER}/sites-available/${filename}" "${WSERVER}/sites-available/${filename}_bk"

          echo " > Restoring backup: ${filename} ..." >>$LOG
          echo -e ${YELLOW}" > Restoring backup: ${filename} ..."${ENDCOLOR}
          cp "$to_restore" "${WSERVER}/sites-available/$filename"

          echo " > Reloading webserver ..." >>$LOG
          echo -e ${YELLOW}" > Reloading webserver ..."${ENDCOLOR}
          service nginx reload

        else
          echo -e ${GREEN}" > File ${WSERVER}/sites-available/${filename} does NOT exists ..."${ENDCOLOR}

          echo " > Restoring backup: ${filename} ..." >>$LOG
          echo -e ${YELLOW}" > Restoring backup: ${filename} ..."${ENDCOLOR}
          cp "$to_restore" "${WSERVER}/sites-available/$filename"
          ln -s "${WSERVER}/sites-available/$filename" "${WSERVER}/sites-enabled/$filename"

          echo " > Reloading webserver ..." >>$LOG
          echo -e ${YELLOW}" > Reloading webserver ..."${ENDCOLOR}
          service nginx reload

        fi

      else

        echo -e ${RED} " /etc/nginx/sites-available NOT exist... Skipping!" ${ENDCOLOR}

      fi

    fi
    if [[ "${CHOSEN_CONFIG}" == *"mysql"* ]]; then
      echo -e ${B_RED}" > TODO: RESTORE MYSQL CONFIG ..."${ENDCOLOR}

    fi
    if [[ "${CHOSEN_CONFIG}" == *"php"* ]]; then
      echo -e ${B_RED}" > TODO: RESTORE PHP CONFIG ..."${ENDCOLOR}

    fi
    if [[ "${CHOSEN_CONFIG}" == *"letsencrypt"* ]]; then
      echo -e ${B_RED}" > TODO: RESTORE LETSENCRYPT CONFIG ..."${ENDCOLOR}

    fi

    # TODO: ask for remove tmp files
    #echo " > Removing ${SFOLDER}/tmp/${CHOSEN_TYPE} ..." >>$LOG
    #echo -e ${GREEN}" > Removing ${SFOLDER}/tmp/${CHOSEN_TYPE} ..."${ENDCOLOR}
    #rm -R ${SFOLDER}/tmp/${CHOSEN_TYPE}

    echo " > DONE ..." >>$LOG
    echo -e ${B_GREEN}" > DONE ..."${ENDCOLOR}

  fi

}

select_and_restore_site_from_dropbox(){

  #TODO: is this ok? or copy from project instead?

  # $1 = CHOSEN_PROJECT

  CHOSEN_PROJECT=$1

  PROJECT_TMP_FOLDER="${SFOLDER}/tmp/${CHOSEN_PROJECT}"

  CHOSEN_PROJECT=$(whiptail --title "Project Name" --inputbox "Want to change the project name?" 10 60 "${CHOSEN_PROJECT}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    
    echo "Setting CHOSEN_PROJECT=${CHOSEN_PROJECT}" >>$LOG
    echo -e ${CYAN}" > Renaming ${PROJECT_TMP_FOLDER} to ${FOLDER_TO_INSTALL}/${CHOSEN_PROJECT}..."${ENDCOLOR}    
    
    mv "${PROJECT_TMP_FOLDER}" "${FOLDER_TO_INSTALL}/${CHOSEN_PROJECT}"
    PROJECT_TMP_FOLDER="${FOLDER_TO_INSTALL}/${CHOSEN_PROJECT}"

  else
    exit 1
  fi

  FOLDER_TO_INSTALL=$(ask_folder_to_install_sites "${SITES}")

  ACTUAL_FOLDER="${FOLDER_TO_INSTALL}/${CHOSEN_PROJECT}"

  if [ -d "${ACTUAL_FOLDER}" ]; then

    echo " > ${ACTUAL_FOLDER} exist. Let's make a Backup ..." >>$LOG
    echo -e ${YELLOW}" > ${ACTUAL_FOLDER} exist. Let's make a Backup ..."${ENDCOLOR}

    make_temp_files_backup "${ACTUAL_FOLDER}"

  fi

  # Restore files
  echo "Executing: mv ${SFOLDER}/tmp/${CHOSEN_PROJECT} ${FOLDER_TO_INSTALL} ..." >>$LOG
  echo -e ${CYAN}"Executing: mv ${SFOLDER}/tmp/${CHOSEN_PROJECT} ${FOLDER_TO_INSTALL} ..."${ENDCOLOR}
  
  mv "${PROJECT_TMP_FOLDER}" "${FOLDER_TO_INSTALL}"

  install_path=$(search_wp_config "${ACTUAL_FOLDER}")

  if [ -z "${install_path}" ]; then

    echo -e ${B_GREEN}" > WORDPRESS INSTALLATION FOUND ON PATH: ${ACTUAL_FOLDER}/${install_path}"${ENDCOLOR}
    wp_change_ownership "${ACTUAL_FOLDER}/${install_path}"

  fi

  # TODO: ask to choose between regenerate nginx config or restore backup
  # If choose restore config and has https, need to restore letsencrypt config and run cerbot

  #echo "Trying to restore nginx config for ${CHOSEN_PROJECT} ..."
  # New site configuration
  #cp ${SFOLDER}/confs/default /etc/nginx/sites-available/${CHOSEN_PROJECT}
  #ln -s /etc/nginx/sites-available/${CHOSEN_PROJECT} /etc/nginx/sites-enabled/${CHOSEN_PROJECT}
  # Replacing string to match domain name
  #sed -i "s#dominio.com#${CHOSEN_PROJECT}#" /etc/nginx/sites-available/${CHOSEN_PROJECT}
  # Need to be run twice
  #sed -i "s#dominio.com#${CHOSEN_PROJECT}#" /etc/nginx/sites-available/${CHOSEN_PROJECT}
  #service nginx reload

  echo -e ${B_GREEN}" > DONE"${ENDCOLOR}

}

select_and_restore_database_from_dropbox(){
  
  # TODO: check project type (WP? Laravel? other?)
  # ask for directory_browser if apply
  # add credentials on external txt and send email

  # $1 = CHOSEN_PROJECT
  # $2 = CHOSEN_BACKUP_TO_RESTORE

  CHOSEN_PROJECT=$1
  CHOSEN_BACKUP_TO_RESTORE=$2

  make_temp_db_backup

  restore_database_backup "${CHOSEN_PROJECT}" "${CHOSEN_BACKUP_TO_RESTORE}"

  FOLDER_TO_INSTALL=$(ask_folder_to_install_sites "${SITES}")

  startdir=${FOLDER_TO_INSTALL}
  menutitle="Site Selection Menu"
  directory_browser "$menutitle" "$startdir"
  PROJECT_SITE=$filepath"/"$filename
  #echo "Setting PROJECT_SITE=${PROJECT_SITE}"

  install_path=$(search_wp_config "${filepath}")

  if [ -z "${install_path}" ]; then

    echo -e ${B_GREEN}" > WORDPRESS INSTALLATION FOUND ON PATH: ${PROJECT_SITE}/${install_path}"${ENDCOLOR}

    # Change wp-config.php database parameters
    wp_update_wpconfig "${PROJECT_SITE}/${install_path}" "${PROJECT_NAME}" "${PROJECT_STATE}" "${DB_PASS}"

    # TODO: change the secret encryption keys

  fi

  # Ask for Cloudflare Root Domain
  ROOT_DOMAIN=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    # Cloudflare API to change DNS records
    echo "Trying to access Cloudflare API and change record ${DOMAIN} ..." >>$LOG
    echo -e ${YELLOW}"Trying to access Cloudflare API and change record ${DOMAIN} ..."${ENDCOLOR}

    zone_name=${ROOT_DOMAIN}
    record_name=${DOMAIN}
    export zone_name record_name
    "${SFOLDER}/utils/cloudflare_update_IP.sh"

  fi
  
  # HTTPS with Certbot
  certbot_helper_installer_menu "${DOMAIN}"

}

################################################################################

SITES_F="site"
CONFIG_F="configs"
DBS_F="database"

DROPBOX_SERVER_LIST=$($DROPBOX_UPLOADER -hq list "/")

# Select SERVER
CHOSEN_SERVER=$(whiptail --title "RESTORE BACKUP" --menu "Choose Server to work with" 20 78 10 $(for x in ${DROPBOX_SERVER_LIST}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  DROPBOX_TYPE_LIST=$($DROPBOX_UPLOADER -hq list "${CHOSEN_SERVER}")

  # Select backup type
  CHOSEN_TYPE=$(whiptail --title "RESTORE BACKUP" --menu "Choose a backup type. If you want to restore an entire site, first restore the site files, then the config, and last the database." 20 78 10 $(for x in ${DROPBOX_TYPE_LIST}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    DROPBOX_CHOSEN_TYPE_PATH="${CHOSEN_SERVER}/${CHOSEN_TYPE}"
    DROPBOX_PROJECT_LIST=$($DROPBOX_UPLOADER -hq list "${DROPBOX_CHOSEN_TYPE_PATH}")
    
    if [[ ${CHOSEN_TYPE} == *"$CONFIG_F"* ]]; then

      select_and_restore_config_from_dropbox "${DROPBOX_CHOSEN_TYPE_PATH}" "${DROPBOX_PROJECT_LIST}"

    else # DB or SITE

      # Select Project
      CHOSEN_PROJECT=$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup Project" 20 78 10 $(for x in ${DROPBOX_PROJECT_LIST}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        DROPBOX_CHOSEN_BACKUP_PATH="${DROPBOX_CHOSEN_TYPE_PATH}/${CHOSEN_PROJECT}"
        DROPBOX_BACKUP_LIST=$($DROPBOX_UPLOADER -hq list "${DROPBOX_CHOSEN_BACKUP_PATH}")

      fi
      # Select Backup File
      CHOSEN_BACKUP_TO_RESTORE=$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup to Download" 20 78 10 $(for x in ${DROPBOX_BACKUP_LIST}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then

        cd "${SFOLDER}/tmp"

        BK_TO_DOWNLOAD="${CHOSEN_SERVER}/${CHOSEN_TYPE}/${CHOSEN_PROJECT}/${CHOSEN_BACKUP_TO_RESTORE}"

        echo " > Running dropbox_uploader.sh download ${BK_TO_DOWNLOAD}" >>$LOG

        $DROPBOX_UPLOADER download "${BK_TO_DOWNLOAD}"

        echo -e ${CYAN}" > Uncompressing ${CHOSEN_BACKUP_TO_RESTORE}"${ENDCOLOR}
        echo " > Uncompressing ${CHOSEN_BACKUP_TO_RESTORE}" >>$LOG

        pv "${CHOSEN_BACKUP_TO_RESTORE}" | tar xp -C "${SFOLDER}/tmp/" --use-compress-program=lbzip2

        if [[ ${CHOSEN_TYPE} == *"$DBS_F"* ]]; then

          select_and_restore_database_from_dropbox "${CHOSEN_PROJECT}" "${CHOSEN_BACKUP_TO_RESTORE}"

        else # site

          select_and_restore_site_from_dropbox "${CHOSEN_PROJECT}"

        fi
      
      fi

    fi

  fi

else
  exit 0
  # TODO: return to backup menu?
fi