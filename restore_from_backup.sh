#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-beta11
################################################################################

# TO-FIX: mysql restore fail when cant create mysql user
# TO-FIX: sometimes GRANT PRIVILEGES fails, use mysql_helper.sh

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/mysql_helper.sh"
source "${SFOLDER}/libs/wpcli_helper.sh"
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

  if [ -d /var/lib/mysql/${CHOSEN_PROJECT} ]; then
    echo -e ${YELLOW}" > Executing mysqldump (will work if database exists) ..."${ENDCOLOR}
    mysqldump -u ${MUSER} --password=${MPASS} ${CHOSEN_PROJECT} >${CHOSEN_PROJECT}_bk_before_restore.sql

  fi

}

restore_database_backup() {

  echo " > Trying to restore ${CHOSEN_BACKUP} DB" >>$LOG
  echo -e ${YELLOW}" > Trying to restore ${CHOSEN_BACKUP} DB"${ENDCOLOR}

  # TODO: extract real db sufix, and ask if we want to change it
  ask_project_state

  suffix="$(cut -d'_' -f2 <<<"${CHOSEN_PROJECT}")"
  #suffix="_${PROJECT_STATE}"

  # Extract PROJECT_NAME
  PROJECT_NAME=${CHOSEN_PROJECT%"_$suffix"}

  PROJECT_NAME=$(whiptail --title "Project Name" --inputbox "Want to change the project name?" 10 60 "${PROJECT_NAME}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "Setting PROJECT_NAME="${PROJECT_NAME} >>$LOG
  else
    exit 1
  fi

  DB_USER="${PROJECT_NAME}_user"
  DB_NAME="${PROJECT_NAME}_${PROJECT_STATE}"

  echo -e ${CYAN}" > Creating '${DB_NAME}' database in MySQL ..."${ENDCOLOR}
  echo "Creating '${DB_NAME}' database in MySQL ..." >>$LOG
  mysql_database_create "${DB_NAME}"

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

  mysql_user_grant_privileges "${DB_USER}" "${DB_NAME}"

  # Trying to restore Database
  CHOSEN_BACKUP="${CHOSEN_BACKUP%%.*}.sql"
  mysql_database_import "${PROJECT_NAME}_${PROJECT_STATE}" "${CHOSEN_BACKUP}"

  echo -e ${CYAN}" > Cleanning temp files ..."${ENDCOLOR}
  rm ${CHOSEN_BACKUP%%.*}.sql
  rm "${CHOSEN_BACKUP}"
  echo -e ${B_GREEN}" > DONE"${ENDCOLOR}

  ask_folder_to_install_sites

  startdir=${FOLDER_TO_INSTALL}
  menutitle="Site Selection Menu"
  directory_browser "$menutitle" "$startdir"
  WP_SITE=$filepath"/"$filename
  echo "Setting WP_SITE="${WP_SITE}

  #FOLDER_NAME=$(basename $WP_SITE)

  # Change wp-config.php database parameters
  wp_update_wpconfig "${WP_SITE}" "${PROJECT_NAME}" "${PROJECT_STATE}" "${DB_PASS}"

  # TODO: change the secret encryption keys

  echo -e ${B_GREEN}" > DONE"${B_ENDCOLOR}

}

################################################################################

SITES_F="site"
CONFIG_F="configs"
DBS_F="database"
#RESTORE_TYPES="${SITES_F} ${CONFIG_F} ${DBS_F}"

DROPBOX_SERVER_LIST=$(${DPU_F}/dropbox_uploader.sh -hq list "/")
# Select SERVER
CHOSEN_SERVER=$(whiptail --title "RESTORE BACKUP" --menu "Choose Server to work with" 20 78 10 $(for x in ${DROPBOX_SERVER_LIST}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
  DROPBOX_TYPE_LIST=$(${DPU_F}/dropbox_uploader.sh -hq list "${CHOSEN_SERVER}")

fi

# Display choose dialog with available backups
CHOSEN_TYPE=$(whiptail --title "RESTORE BACKUP" --menu "Choose a backup type. If you want to restore an entire site, first restore the site files, then the config, and last the database." 20 78 10 $(for x in ${DROPBOX_TYPE_LIST}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
  #Restore from Dropbox
  DROPBOX_PROJECT_LIST=$(${DPU_F}/dropbox_uploader.sh -hq list "${CHOSEN_SERVER}/${CHOSEN_TYPE}")
fi

#echo -e ${B_RED}" > CHOSEN_TYPE: ${CHOSEN_TYPE}"${ENDCOLOR}
if [[ ${CHOSEN_TYPE} == *"$CONFIG_F"* ]]; then
  CHOSEN_CONFIG=$(whiptail --title "RESTORE CONFIGS BACKUPS" --menu "Chose Configs Backup" 20 78 10 $(for x in ${DROPBOX_PROJECT_LIST}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?

  if [ $exitstatus = 0 ]; then

    cd "${SFOLDER}/tmp"

    echo " > Downloading from Dropbox ${CHOSEN_SERVER}/${CHOSEN_TYPE}/${CHOSEN_CONFIG} ..." >>$LOG
    echo -e ${YELLOW}" > Trying to run dropbox_uploader.sh download ${CHOSEN_SERVER}/${CHOSEN_TYPE}/${CHOSEN_CONFIG}"${ENDCOLOR}
    ${DPU_F}/dropbox_uploader.sh download "${CHOSEN_SERVER}/${CHOSEN_TYPE}/${CHOSEN_CONFIG}"

    # Restore files
    mkdir "${CHOSEN_TYPE}"
    mv "${CHOSEN_CONFIG}" "${CHOSEN_TYPE}"
    cd "${CHOSEN_TYPE}"

    echo -e ${YELLOW} " > Uncompressing ${CHOSEN_CONFIG}" ${ENDCOLOR}
    echo " > Uncompressing ${CHOSEN_CONFIG}" >>$LOG
    
    pv "${CHOSEN_CONFIG}" | tar xp -C "${SFOLDER}/tmp/${CHOSEN_TYPE}" --use-compress-program=lbzip2

    if [[ "${CHOSEN_CONFIG}" == *"webserver"* ]]; then

      # TODO: if nginx is installed, ask if nginx.conf must be replace

      # Checking that default webserver folder exists
      if [[ -n "${WSERVER}" ]]; then

        echo -e ${GREEN} " > Folder ${WSERVER} exists ... OK" ${ENDCOLOR}

        startdir="${SFOLDER}/tmp/${CHOSEN_TYPE}/sites-available"
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
          cp $to_restore ${WSERVER}/sites-available/$filename
          ln -s ${WSERVER}/sites-available/$filename ${WSERVER}/sites-enabled/$filename

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
else
  
  # Select Project
  CHOSEN_PROJECT=$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup Project" 20 78 10 $(for x in ${DROPBOX_PROJECT_LIST}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    DROPBOX_BACKUP_LIST=$(${DPU_F}/dropbox_uploader.sh -hq list "${CHOSEN_SERVER}/${CHOSEN_TYPE}/${CHOSEN_PROJECT}")

  fi
  # Select Backup File
  CHOSEN_BACKUP=$(whiptail --title "RESTORE BACKUP" --menu "Choose Backup to Download" 20 78 10 $(for x in ${DROPBOX_BACKUP_LIST}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    cd "${SFOLDER}/tmp"

    #echo " > Downloading from Dropbox ${CHOSEN_TYPE}/${CHOSEN_CONFIG} ..." >>$LOG
    BK_TO_DOWNLOAD="${CHOSEN_SERVER}/${CHOSEN_TYPE}/${CHOSEN_PROJECT}/${CHOSEN_BACKUP}"
    echo -e ${YELLOW}" > Trying to run dropbox_uploader.sh download ${BK_TO_DOWNLOAD}"${ENDCOLOR}
    ${DPU_F}/dropbox_uploader.sh download "${BK_TO_DOWNLOAD}"

    echo -e ${CYAN}" > Uncompressing ${CHOSEN_BACKUP}"${ENDCOLOR}
    echo " > Uncompressing ${CHOSEN_BACKUP}" >>$LOG

    pv "${CHOSEN_BACKUP}" | tar xp -C "${SFOLDER}/tmp/" --use-compress-program=lbzip2

    # Site Restore
    if [[ ${CHOSEN_TYPE} == *"$SITES_F"* ]]; then

      ask_folder_to_install_sites

      ACTUAL_FOLDER="${FOLDER_TO_INSTALL}/${CHOSEN_PROJECT}"

      if [ -n "${ACTUAL_FOLDER}" ]; then

        echo " > ${ACTUAL_FOLDER} exist. Let's make a Backup ..." >>$LOG
        echo -e ${YELLOW}" > ${ACTUAL_FOLDER} exist. Let's make a Backup ..."${ENDCOLOR}

        make_temp_files_backup "${ACTUAL_FOLDER}"

      fi

      # Restore files
      echo "Trying to restore ${CHOSEN_BACKUP} files ..." >>$LOG
      echo -e ${YELLOW} "Trying to restore ${CHOSEN_BACKUP} files ..."${ENDCOLOR}

      #echo "Executing: mv ${SFOLDER}/tmp/${CHOSEN_PROJECT} ${FOLDER_TO_INSTALL} ..."
      mv "${SFOLDER}/tmp/${CHOSEN_PROJECT}" "${FOLDER_TO_INSTALL}"

      wp_change_ownership "${FOLDER_TO_INSTALL}/${CHOSEN_PROJECT}"

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

    else
      if [[ ${CHOSEN_TYPE} == *"$DBS_F"* ]]; then

        # TODO: checkear si la BD es de una instalación de WP
        # si lo es, preguntar a que carpeta de WP pertenece (directory_browser)
        # si no selecciona no continuar.
        # Si no es una BD de WP, crear BD, usuario y dejar datos en .txt

        # Si es una BD
        # TODO: contemplar 2 opciones: base existente y base inexistente (habría que crear el usuario)

        make_temp_db_backup

        restore_database_backup

        # Ask for Cloudflare Root Domain
        ROOT_DOMAIN=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus = 0 ]; then

          echo "Setting ROOT_DOMAIN="${ROOT_DOMAIN}

          # Cloudflare API to change DNS records
          echo "Trying to access Cloudflare API and change record ${DOMAIN} ..." >>$LOG
          echo -e ${YELLOW}"Trying to access Cloudflare API and change record ${DOMAIN} ..."${ENDCOLOR}

          zone_name=${ROOT_DOMAIN}
          record_name=${DOMAIN}
          export zone_name record_name
          ${SFOLDER}/utils/cloudflare_update_IP.sh

        fi

        #TODO: ask for Certbot
        
        # HTTPS with Certbot
        ${SFOLDER}/utils/certbot_manager.sh
        #certbot_certificate_install "${MAILA}" "${DOMAIN}"

      fi
    fi

  fi
fi
