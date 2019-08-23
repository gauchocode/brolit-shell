#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
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
        exit 0
      fi

    else

      SOURCE_FILES_URL=$(whiptail --title "Source File URL" --inputbox "Please insert the URL where backup files are stored." 10 60 "http://example.com/backup-files.zip" 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ $exitstatus = 0 ]; then
        echo "SOURCE_FILES_URL="${SOURCE_FILES_URL} >>$LOG

        SOURCE_DB_URL=$(whiptail --title "Source DB URL" --inputbox "Please insert the URL where backup db is stored." 10 60 "http://example.com/backup-db.zip" 3>&1 1>&2 2>&3)
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

# TODO: Pedir estos datos con whiptail

### Database Backup details
#BK_DB_URL=""
BK_DB_FILE="adlerDB-2.sql"
#BK_F_EXT="gz"

### Project details
PROJECT_NAME="adler"
PROJECT_DOM="adler.broobe.com"
PROJECT_STATE="dev"


wp_migration_source

ask_folder_to_install_sites

echo " > CREATING TMP DIRECTORY ..."
cd ${SOURCE_DIR}
mkdir tmp

if [ ${WP_MIGRATION_SOURCE} = "DIRECTORY" ]; then

  unzip \*.zip \* -d ${SOURCE_DIR}/tmp
  # TODO: acá habría que checkear si la instalación es un WP 
  # y si está en la raiz o dentro de una carpeta del zip

  cd ${FOLDER_TO_INSTALL}

  mkdir ${PROJECT_DOM}

  cp -r ${SOURCE_DIR}/tmp ${FOLDER_TO_INSTALL}/${PROJECT_DOM}

  # TODO: ask to remove backup files

else

  echo -e ${YELLOW}" > Downloading file backup ..."${ENDCOLOR}
  wget $BK_F_URL >>$LOG

  #si BK_EXT es un zip
  echo -e ${YELLOW}" > Uncompressing file backup ..."${ENDCOLOR}
  unzip $BK_F_FILE

  #si BK_EXT es un tar.bz2
  #tar xvjf $BK_F_FILE

  ### Download Database Backup
  echo -e ${YELLOW}" > Downloading database backup ..."${ENDCOLOR} >>$LOG
  wget $BK_DB_URL >>$LOG

  echo " > Importing dump file into database ..." >>$LOG
  gunzip <$BK_DB_FILE | mysql -u root -p${MPASS} ${PROJECT_NAME}_${PROJECT_STATE}

  # TODO: ask to remove backup files

fi

chown -R www-data:www-data ${FOLDER_TO_INSTALL}/${PROJECT_DOM}

if ! echo "SELECT COUNT(*) FROM mysql.user WHERE user = '${PROJECT_NAME}_user';" | mysql -u root --password=${MPASS} | grep 1 &>/dev/null; then

  DB_PASS=$(openssl rand -hex 12)

  ### Vamos a crear el usuario y la base siguiendo el nuevo estandard de broobe
  SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_${PROJECT_STATE};"
  SQL2="CREATE USER '${PROJECT_NAME}_user'@'localhost' IDENTIFIED BY '${DB_PASS}';"
  SQL3="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_${PROJECT_STATE} . * TO '${PROJECT_NAME}_user'@'localhost';"
  SQL4="FLUSH PRIVILEGES;"

  echo -e ${YELLOW}" > Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and user ${PROJECT_NAME}_user with pass ${DB_PASS} ..."${ENDCOLOR} >>$LOG

  mysql -u root -p${MPASS} -e "${SQL1}${SQL2}${SQL3}${SQL4}" >>$LOG

  echo -e ${GREEN}" > DONE"${ENDCOLOR}

else
  echo " > User: ${PROJECT_NAME}_user already exist. Continue ..." >>$LOG

  ### Vamos a crear el usuario y la base siguiendo el nuevo estandard de broobe
  SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_${PROJECT_STATE};"
  SQL2="CREATE USER '${PROJECT_NAME}_user'@'localhost' IDENTIFIED BY '${DB_PASS}';"
  SQL3="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_${PROJECT_STATE} . * TO '${PROJECT_NAME}_user'@'localhost';"
  SQL4="FLUSH PRIVILEGES;"

  echo -e ${YELLOW}" > Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and granting privileges to user: ${PROJECT_NAME}_user ..."${ENDCOLOR} >>$LOG

  mysql -u root -p${MPASS} -e "${SQL1}${SQL2}${SQL3}${SQL4}" >>$LOG

  echo -e ${GREEN}" > DONE"${ENDCOLOR}

fi

# DB
mysql_database_import "${PROJECT_NAME}_${PROJECT_STATE}" "${BK_F_FILE}"
#mysql -u root -p${MPASS} ${PROJECT_NAME}_${PROJECT_STATE} < ${BK_F_FILE}

#change wp-config.php database parameters
echo " > Changing wp-config.php database parameters ..." >>$LOG
sed -i "/DB_HOST/s/'[^']*'/'localhost'/2" ${FOLDER_TO_INSTALL}/${PROJECT_DOM}/wp-config.php >>$LOG
sed -i "/DB_NAME/s/'[^']*'/'${PROJECT_NAME}_${PROJECT_STATE}'/2" ${FOLDER_TO_INSTALL}/${PROJECT_DOM}/wp-config.php >>$LOG
sed -i "/DB_USER/s/'[^']*'/'${PROJECT_NAME}_user'/2" ${FOLDER_TO_INSTALL}/${PROJECT_DOM}/wp-config.php >>$LOG
sed -i "/DB_PASSWORD/s/'[^']*'/'${DB_PASS}'/2" ${FOLDER_TO_INSTALL}/${PROJECT_DOM}/wp-config.php >>$LOG

#rm $BK_DB_FILE

#create nginx config files for site
echo -e "\nCreating nginx configuration file...\n" >>$LOG
sudo cp ${SFOLDER}/confs/nginx/sites-available/default /etc/nginx/sites-available/${PROJECT_DOM}
ln -s /etc/nginx/sites-available/${PROJECT_DOM} /etc/nginx/sites-enabled/${PROJECT_DOM}

#replacing string to match domain name
#sudo replace "domain.com" "$DOMAIN" -- /etc/nginx/sites-available/default
sudo sed -i "s#dominio.com#${PROJECT_DOM}#" /etc/nginx/sites-available/${PROJECT_DOM}
#es necesario correrlo dos veces para reemplazarlo dos veces en una misma linea
sudo sed -i "s#dominio.com#${PROJECT_DOM}#" /etc/nginx/sites-available/${PROJECT_DOM}

#reload webserver
service nginx reload

### Get server IPs ###
IP=$(dig +short myip.opendns.com @resolver1.opendns.com) 2>/dev/null

# TODO: run cloudflare script
# TODO: run certbot script
# TODO: run url_replace script

### Log End ###
END_TIME=$(date +%s)
ELAPSED_TIME=$(expr $END_TIME - $START_TIME)

echo "Backup :: Script End -- $(date +%Y%m%d_%H%M)" >>$LOG

HTMLOPEN='<html><body>'
BODY_SRV_MIG='Migración finalizada en '${ELAPSED_TIME}'<br/>'
BODY_DB='Database: '${PROJECT_NAME}'_prod <br/>Database User: '${PROJECT_NAME}'_user <br/>Database User Pass: '${DB_PASS}'<br/>'
BODY_CLF='Ya podes cambiar la IP en CloudFlare: '${IP}'<br/>'
HTMLCLOSE='</body></html>'

sendEmail -f ${SMTP_U} -t "${MAILA}" -u "${VPSNAME} - Migration Complete: ${PROJECT_NAME}" -o message-content-type=html -m "$HTMLOPEN $BODY_SRV_MIG $BODY_DB $BODY_CLF $HTMLCLOSE" -s ${SMTP_SERVER}:${SMTP_PORT} -o tls=${SMTP_TLS} -xu ${SMTP_U} -xp ${SMTP_P}
