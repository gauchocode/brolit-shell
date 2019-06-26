#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9
#############################################################################

VPSNAME="$HOSTNAME"

### File Backup details
BK_F_URL=""
BK_F_FILE=""
BK_F_EXT=""

### Database Backup details
BK_DB_URL=""
BK_DB_FILE=""
BK_F_EXT="gz"

### Project details
PROJECT_NAME=""
PROJECT_DOM=""
SFOLDER="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"  #Backup Scripts folder. Recomended: /root/broobe-utils-scripts
SITES="/var/www"                                                      #Where sites are stored

### SENDEMAIL CONFIG
MAILA="servidores@broobe.com"                                         #Notification Email
SMTP_SERVER="mail.bmailing.com.ar"                                    #SMTP Server
SMTP_PORT="587"                                                       #SMTP Port
SMTP_TLS="yes"                                                        #TLS: yes or no
SMTP_U="no-reply@envios.broobe.com"                                   #SMTP User

### Setup Colours ###
BLACK='\E[30;40m'
RED='\E[31;40m'
GREEN='\E[32;40m'
YELLOW='\E[33;40m'
BLUE='\E[34;40m'
MAGENTA='\E[35;40m'
CYAN='\E[36;40m'
WHITE='\E[37;40m'

if [[ -z "${BK_DB_URL}" || -z "${PROJECT_NAME}" || -z "${PROJECT_DOM}" ]]; then
  echo -e ${RED}" > Error: BK_DB_URL, PROJECT_NAME and PROJECT_DOM must be set! Exiting..."${ENDCOLOR}
  exit 0
fi

### Log Start ###
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PATH_LOG="${SFOLDER}/logs"
if [ ! -d "${SFOLDER}/logs" ]
then
    echo " > Folder ${SFOLDER}/logs doesn't exist. Creating now ..."
    mkdir ${SFOLDER}/logs
    echo " > Folder ${SFOLDER}/logs created ..."
fi
LOG_NAME="log_server_migration_${TIMESTAMP}.log"
LOG=$PATH_LOG/$LOG_NAME

echo "Server Migration:: Script Start -- $(date +%Y%m%d_%H%M)" >> $LOG
START_TIME=$(date +%s)

if test -f /root/.broobe-utils-options ; then
  source /root/.broobe-utils-options
fi

# Display dialog to imput MySQL root pass and then store it into a hidden file
if [[ -z "${MPASS}" ]]; then
  MPASS=$(whiptail --title "MySQL root password" --inputbox "Please insert the MySQL root Password" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
          #TODO: testear el password antes de guardarlo
          echo "MPASS="${MPASS} >> /root/.broobe-utils-options
  fi
fi

if [[ -z "${SMTP_P}" ]]; then
  SMTP_P=$(whiptail --title "SMTP Password" --inputbox "Please insert the SMTP user password" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
          echo "SMTP_P="${SMTP_P} >> /root/.broobe-utils-options
  fi
fi

cd ${SITES} >> $LOG
mkdir tmp >> $LOG
cd tmp >> $LOG
echo -e ${YELLOW}" > Downloading file backup ..."${ENDCOLOR} >> $LOG
wget $BK_F_URL >> $LOG

#si BK_EXT es un zip
echo -e ${YELLOW}" > Uncompressing file backup ..."${ENDCOLOR} >> $LOG
unzip $BK_F_FILE
#si BK_EXT es un tar.bz2
#tar xvjf $BK_F_FILE

rm ${BK_F_FILE} >> $LOG
cd .. >> $LOG
mv tmp ${PROJECT_DOM} >> $LOG
chown -R www-data:www-data ${PROJECT_DOM} >> $LOG

if ! echo "SELECT COUNT(*) FROM mysql.user WHERE user = '${PROJECT_NAME}_user';" | mysql -u root --password=${MPASS} | grep 1 &> /dev/null; then
  DB_PASS=$(openssl rand -hex 12)
  ### Vamos a crear el usuario y la base siguiendo el nuevo estandard de broobe
  SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_prod;"
  SQL2="CREATE USER '${PROJECT_NAME}_user'@'localhost' IDENTIFIED BY '${DB_PASS}';"
  SQL3="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_prod . * TO '${PROJECT_NAME}_user'@'localhost';"
  SQL4="FLUSH PRIVILEGES;"

  echo -e ${YELLOW}" > Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and user ${PROJECT_NAME}_user with pass ${DB_PASS} ..."${ENDCOLOR} >> $LOG

  mysql -u root -p${MPASS} -e "${SQL1}${SQL2}${SQL3}${SQL4}" >> $LOG

  echo -e ${GREEN}" > DONE"${ENDCOLOR}

else
  echo " > User: ${PROJECT_NAME}_user already exist. Continue ..." >> $LOG

  ### Vamos a crear el usuario y la base siguiendo el nuevo estandard de broobe
  SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_prod;"
  SQL2="CREATE USER '${PROJECT_NAME}_user'@'localhost' IDENTIFIED BY '${DB_PASS}';"
  SQL3="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_prod . * TO '${PROJECT_NAME}_user'@'localhost';"
  SQL4="FLUSH PRIVILEGES;"

  echo -e ${YELLOW}" > Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and granting privileges to user: ${PROJECT_NAME}_user ..."${ENDCOLOR} >> $LOG

  mysql -u root -p${MPASS} -e "${SQL1}${SQL2}${SQL3}${SQL4}" >> $LOG

  echo -e ${GREEN}" > DONE"${ENDCOLOR}

fi

### Download Database Backup
echo -e ${YELLOW}" > Downloading database backup ..."${ENDCOLOR} >> $LOG
wget $BK_DB_URL >> $LOG

echo " > Importing dump file into database ..." >> $LOG
gunzip < $BK_DB_FILE | mysql -u root -p${MPASS} ${PROJECT_NAME}_prod

#change wp-config.php database parameters
echo " > Changing wp-config.php database parameters ..." >> $LOG
sed -i "/DB_HOST/s/'[^']*'/'localhost'/2" ${PROJECT_DOM}/wp-config.php >> $LOG
sed -i "/DB_NAME/s/'[^']*'/'${PROJECT_NAME}_prod'/2" ${PROJECT_DOM}/wp-config.php >> $LOG
sed -i "/DB_USER/s/'[^']*'/'${PROJECT_NAME}_user'/2" ${PROJECT_DOM}/wp-config.php >> $LOG
sed -i "/DB_PASSWORD/s/'[^']*'/'${DB_PASS}'/2" ${PROJECT_DOM}/wp-config.php >> $LOG

#rm $BK_DB_FILE

#create nginx config files for site
echo -e "\nCreating nginx configuration file...\n" >>$LOG
sudo cp ${SFOLDER}/confs/default /etc/nginx/sites-available/${PROJECT_DOM}
ln -s /etc/nginx/sites-available/${PROJECT_DOM} /etc/nginx/sites-enabled/${PROJECT_DOM}

#replacing string to match domain name
#sudo replace "domain.com" "$DOMAIN" -- /etc/nginx/sites-available/default
sudo sed -i "s#dominio.com#${PROJECT_DOM}#" /etc/nginx/sites-available/${PROJECT_DOM}
#es necesario correrlo dos veces para reemplazarlo dos veces en una misma linea
sudo sed -i "s#dominio.com#${PROJECT_DOM}#" /etc/nginx/sites-available/${PROJECT_DOM}

#reload webserver
service nginx reload

### Get server IPs ###
DIG="$(which dig)"
if [ ! -x "${DIG}" ]; then
	apt-get install dnsutils
fi
IP=`dig +short myip.opendns.com @resolver1.opendns.com	` 2> /dev/null

### Log End ###
END_TIME=$(date +%s)
ELAPSED_TIME=$(expr $END_TIME - $START_TIME)

echo "Backup :: Script End -- $(date +%Y%m%d_%H%M)" >> $LOG

HTMLOPEN='<html><body>'
BODY_SRV_MIG='Migración finalizada en '${ELAPSED_TIME}'<br/>'
BODY_DB='Database: '${PROJECT_NAME}'_prod <br/>Database User: '${PROJECT_NAME}'_user <br/>Database User Pass: '${DB_PASS}'<br/>'
BODY_CLF='Ya podes cambiar la IP en CloudFlare: '${IP}'<br/>'
HTMLCLOSE='</body></html>'

sendEmail -f ${SMTP_U} -t "${MAILA}" -u "${VPSNAME} - Migration Complete: ${PROJECT_NAME}" -o message-content-type=html -m "$HTMLOPEN $BODY_SRV_MIG $BODY_DB $BODY_CLF $HTMLCLOSE" -s ${SMTP_SERVER}:${SMTP_PORT} -o tls=${SMTP_TLS} -xu ${SMTP_U} -xp ${SMTP_P};
