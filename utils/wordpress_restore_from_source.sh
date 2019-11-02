#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 3.0
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/mysql_helper.sh
source ${SFOLDER}/libs/mail_notification_helper.sh
source ${SFOLDER}/libs/packages_helper.sh
source ${SFOLDER}/libs/wpcli_helper.sh

################################################################################

wp_migration_source() {

  WP_MIGRATION_SOURCE="URL DIRECTORY"
  WP_MIGRATION_SOURCE=$(whiptail --title "WP Migration Source" --menu "Choose the source of the WP to restore/migrate:" 20 78 10 $(for x in ${WP_MIGRATION_SOURCE}; do echo "$x [X]"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    echo -e ${YELLOW}"WP_MIGRATION_SOURCE: ${WP_MIGRATION_SOURCE} ..."${ENDCOLOR}

    if [ ${WP_MIGRATION_SOURCE} = "DIRECTORY" ]; then

      SOURCE_DIR=$(whiptail --title "Source Directory" --inputbox "Please insert the directory where backup is stored (Files and DB)." 10 60 "/root/backups" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        echo "SOURCE_DIR="${SOURCE_DIR} >>$LOG

      else
        exit 1

      fi

    else

      SOURCE_FILES_URL=$(whiptail --title "Source File URL" --inputbox "Please insert the URL where backup files are stored." 10 60 "http://example.com/backup-files.zip" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        echo "SOURCE_FILES_URL="${SOURCE_FILES_URL} >>$LOG

        SOURCE_DB_URL=$(whiptail --title "Source DB URL" --inputbox "Please insert the URL where backup db is stored." 10 60 "http://example.com/backup-db.sql.gz" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus = 0 ]; then
          echo "SOURCE_DB_URL="${SOURCE_DB_URL} >>$LOG

        else
          exit 0
        fi

      else
        exit 0
      fi

    fi

  else

    exit 1

  fi
}

#############################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/mysql_helper.sh

### Log Start
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PATH_LOG="${SFOLDER}/logs"
if [ ! -d "${SFOLDER}/logs" ]; then
  echo " > Folder ${SFOLDER}/logs doesn't exist. Creating now ..."
  mkdir ${SFOLDER}/logs
  echo " > Folder ${SFOLDER}/logs created ..."
fi
LOG_NAME="log_server_migration_${TIMESTAMP}.log"
LOG=$PATH_LOG/$LOG_NAME

echo "Server Migration:: Script Start -- $(date +%Y%m%d_%H%M)" >>$LOG
START_TIME=$(date +%s)

if test -f /root/.broobe-utils-options; then
  source /root/.broobe-utils-options
fi

# Project details
ask_project_domain

POSSIBLE_ROOT_DOMAIN=${PROJECT_DOMAIN#[[:alpha:]]*.}
ask_rootdomain_to_cloudflare_config "${POSSIBLE_ROOT_DOMAIN}"

ask_project_name

ask_project_state

wp_migration_source

# Database Backup details
BK_DB_FILE=${SOURCE_DB_URL##*/}
echo -e ${MAGENTA}" > BK_DB_FILE= ${BK_DB_FILE} ..."${ENDCOLOR}

# File Backup details
BK_F_FILE=${SOURCE_FILES_URL##*/}
echo -e ${MAGENTA}" > BK_F_FILE= ${BK_F_FILE} ..."${ENDCOLOR}

ask_folder_to_install_sites

echo " > CREATING TMP DIRECTORY ..."
mkdir ${SFOLDER}/tmp
mkdir ${SFOLDER}/tmp/${PROJECT_DOMAIN}
cd ${SFOLDER}/tmp/${PROJECT_DOMAIN}

if [ ${WP_MIGRATION_SOURCE} = "DIRECTORY" ]; then

  unzip \*.zip \* -d ${SFOLDER}/tmp/${PROJECT_DOMAIN}
  # TODO: acá habría que checkear si la instalación es un WP
  # y si está en la raiz o dentro de una carpeta del zip

  # TODO: habria que levantar el seleccionador de archivos para que busque el backup de la BD

  # DB
  mysql_database_import "${PROJECT_NAME}_${PROJECT_STATE}" "${WP_MIGRATION_SOURCE}/${BK_DB_FILE}"

  cd ${FOLDER_TO_INSTALL}

  #mkdir ${PROJECT_DOMAIN}

  cp -r ${SFOLDER}/tmp/${PROJECT_DOMAIN} ${FOLDER_TO_INSTALL}/${PROJECT_DOMAIN}

else

  # Download File Backup
  echo -e ${CYAN}" > Downloading file backup ..."${ENDCOLOR}
  wget ${SOURCE_FILES_URL} >>$LOG

  # Uncompressing
  echo -e ${CYAN}" > Uncompressing file backup ..."${ENDCOLOR}
  unzip ${BK_F_FILE}

  # Download Database Backup
  echo -e ${CYAN}" > Downloading database backup ..."${ENDCOLOR} >>$LOG
  wget ${SOURCE_DB_URL} >>$LOG

  # Create database and user
  wp_database_creation "${PROJECT_NAME}" "${PROJECT_STATE}"

  # Importing dump file
  gunzip -c ${BK_DB_FILE} > "${PROJECT_NAME}.sql"
  mysql_database_import "${PROJECT_NAME}_${PROJECT_STATE}" "${PROJECT_NAME}.sql"

  # Remove downloaded files
  echo -e ${CYAN}" > Removing downloaded files ..."${ENDCOLOR}
  rm ${SFOLDER}/tmp/${PROJECT_DOMAIN}/${BK_F_FILE}
  rm ${SFOLDER}/tmp/${PROJECT_DOMAIN}/${BK_DB_FILE}

  # Move to ${FOLDER_TO_INSTALL}
  echo -e ${CYAN}" > Moving ${PROJECT_DOMAIN} to ${FOLDER_TO_INSTALL} ..."${ENDCOLOR}
  mv ${SFOLDER}/tmp/${PROJECT_DOMAIN} ${FOLDER_TO_INSTALL}/${PROJECT_DOMAIN}

fi

chown -R www-data:www-data ${FOLDER_TO_INSTALL}/${PROJECT_DOMAIN}

# Change wp-config.php database parameters
PROJECT_DIR="${FOLDER_TO_INSTALL}/${PROJECT_DOMAIN}"
if [[ -z "${DB_PASS}" ]]; then
  wp_update_wpconfig "${PROJECT_DIR}" "${PROJECT_NAME}" "${PROJECT_STATE}" ""
  
else
  wp_update_wpconfig "${PROJECT_DIR}" "${PROJECT_NAME}" "${PROJECT_STATE}" "${DB_PASS}"
  
fi

# Create nginx config files for site
echo -e "\nCreating nginx configuration file...\n" >>$LOG
sudo cp ${SFOLDER}/confs/nginx/sites-available/default /etc/nginx/sites-available/${PROJECT_DOMAIN}
ln -s /etc/nginx/sites-available/${PROJECT_DOMAIN} /etc/nginx/sites-enabled/${PROJECT_DOMAIN}

# Replace string to match domain name

#sudo replace "domain.com" "$DOMAIN" -- /etc/nginx/sites-available/default
sudo sed -i "s#dominio.com#${PROJECT_DOMAIN}#" /etc/nginx/sites-available/${PROJECT_DOMAIN}
#es necesario correrlo dos veces para reemplazarlo dos veces en una misma linea
sudo sed -i "s#dominio.com#${PROJECT_DOMAIN}#" /etc/nginx/sites-available/${PROJECT_DOMAIN}

# Reload webserver
service nginx reload

# Get server IP
IP=$(dig +short myip.opendns.com @resolver1.opendns.com) 2>/dev/null

# Ask for Cloudflare Root Domain
ROOT_DOMAIN=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  echo "Setting ROOT_DOMAIN="${ROOT_DOMAIN}

  # Cloudflare API to change DNS records
  echo "Trying to access Cloudflare API and change record ${PROJECT_DOMAIN} ..." >>$LOG
  echo -e ${YELLOW}"Trying to access Cloudflare API and change record ${PROJECT_DOMAIN} ..."${ENDCOLOR}

  zone_name=${ROOT_DOMAIN}
  record_name=${PROJECT_DOMAIN}
  export zone_name record_name
  ${SFOLDER}/utils/cloudflare_update_IP.sh

fi

# HTTPS with Certbot
${SFOLDER}/utils/certbot_manager.sh
#certbot_certificate_install "${MAILA}" "${DOMAIN}"

# TODO: run url_replace script

# Log End
END_TIME=$(date +%s)
ELAPSED_TIME=$(expr $END_TIME - $START_TIME)

echo "Backup :: Script End -- $(date +%Y%m%d_%H%M)" >>$LOG

HTMLOPEN='<html><body>'
BODY_SRV_MIG='Migración finalizada en '${ELAPSED_TIME}'<br/>'
BODY_DB='Database: '${PROJECT_NAME}'_'${PROJECT_STATE}'<br/>Database User: '${PROJECT_NAME}'_user <br/>Database User Pass: '${DB_PASS}'<br/>'
#BODY_CLF='Ya podes cambiar la IP en CloudFlare: '${IP}'<br/>'
HTMLCLOSE='</body></html>'

sendEmail -f ${SMTP_U} -t "${MAILA}" -u "${VPSNAME} - Migration Complete: ${PROJECT_NAME}" -o message-content-type=html -m "$HTMLOPEN $BODY_SRV_MIG $BODY_DB $BODY_CLF $HTMLCLOSE" -s ${SMTP_SERVER}:${SMTP_PORT} -o tls=${SMTP_TLS} -xu ${SMTP_U} -xp ${SMTP_P}
