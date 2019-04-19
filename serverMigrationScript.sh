#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.1
#############################################################################

### File Backup details ###
BK_F_URL=""
BK_F_FILE=""
BK_F_EXT=""

### Database Backup details ###
BK_DB_URL=""
BK_DB_FILE=""
BK_F_EXT="gz"

### Project details ###
PROJECT_NAME=""
PROJECT_DOM=""
MySQL_ROOT_PASS=""          										        #MySQL root User Pass
SFOLDER="/root/broobe-utils-scripts"					          #Backup Scripts folder

### SENDEMAIL CONFIG ###
MAILA="servidores@broobe.com"     						          #Notification Email
SMTP_SERVER="mx.bmailing.com.ar:587"				            #SMTP Server and Port
SMTP_TLS="yes"															            #TLS: yes or no
SMTP_U="no-reply@send.broobe.com"						            #SMTP User
SMTP_P=""																		            #SMTP Password

VPSNAME="$HOSTNAME"               					            #Or choose a name

DB_PASS=$(openssl rand -base64 10)

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

echo "Backup:: Script Start -- $(date +%Y%m%d_%H%M)" >> $LOG
START_TIME=$(date +%s)

cd /var/www >> $LOG
mkdir tmp >> $LOG
cd tmp >> $LOG
wget $BK_F_URL >> $LOG

#si BK_EXT es un zip
echo "uncompressing backup files" >> $LOG
unzip $BK_F_FILE
#si BK_EXT es un tar.bz2
#tar xvjf $BK_F_FILE

rm $BK_F_FILE >> $LOG
cd .. >> $LOG
mv tmp $PROJECT_DOM >> $LOG
chown -R www-data:www-data $PROJECT_DOM >> $LOG

### Download Database Backup
wget $BK_DB_URL >> $LOG

### Vamos a crear el usuario y la base siguiendo el nuevo estandard de broobe
SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_prod;"
SQL2="CREATE USER '${PROJECT_NAME}_user'@'localhost' IDENTIFIED BY '${DB_PASS}';"
SQL3="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_prod . * TO '${PROJECT_NAME}_user'@'localhost';"
SQL4="FLUSH PRIVILEGES;"

echo "Creating database, and user ..." >> $LOG
mysql -u root -p${MySQL_ROOT_PASS} -e "${SQL1}${SQL2}${SQL3}${SQL4}" >> $LOG

echo "Importing dump file into database ..." >> $LOG
gunzip < $BK_DB_FILE | mysql -u root -p${MySQL_ROOT_PASS} ${PROJECT_NAME}_prod

#change wp-config.php database parameters
echo "Changing wp-config.php database parameters ..." >> $LOG
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
echo "Elapsed Time ::  $(date -d 00:00:${ELAPSED_TIME} +%Hh:%Mm:%Ss) "  >> $LOG

HTMLOPEN='<html><body>'
BODY_SRV_MIG='Migración finalizada en '${ELAPSED_TIME}'<br/>'
BODY_DB='Database: '${PROJECT_NAME}'_prod <br/>Database User: '${PROJECT_NAME}'_user <br/>Database User Pass: '${DB_PASS}'<br/>'
BODY_CLF='Ya podes cambiar la IP en CloudFlare: '${IP}'<br/>'
HTMLCLOSE='</body></html>'

sendEmail -f ${SMTP_U} -t "${MAILA}" -u "${VPSNAME} - Migration Complete: ${PROJECT_NAME}" -o message-content-type=html -m "$HTMLOPEN $BODY_SRV_MIG $BODY_DB $BODY_CLF $HTMLCLOSE" -s ${SMTP_SERVER} -o tls=${SMTP_TLS} -xu ${SMTP_U} -xp ${SMTP_P};
