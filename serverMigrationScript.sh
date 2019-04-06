#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.1
#############################################################################
BK_F_URL="http://wildbrain.net/backup-wildbrain.zip"
BK_F_FILE="backup-wildbrain.zip"
BK_F_EXT="zip"
BK_DB_URL="http://wildbrain.net/wbrain_site.sql.gz"
BK_DB_FILE="wbrain_site.sql.gz"
BK_F_EXT="gz"
PROJECT_NAME="wildbrain"
PROJECT_DOM="wildbrain.net"
SFOLDER="/root/broobe-utils-scripts"					         #Backup Scripts folder

function generatePassword(){
    echo "$(openssl rand -base64 12)"
}

$DB_PASS= $(generatePassword)

### Log Start ###
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PATH_LOG="$SFOLDER/logs"
if [ ! -d "$SFOLDER/logs" ]
then
    echo " > Folder $SFOLDER/logs doesn't exist. Creating now ..."
    mkdir $SFOLDER/logs
    echo " > Folder $SFOLDER/logs created ..."
fi
LOG_NAME= log_server_migration_$TIMESTAMP.log
LOG=$PATH_LOG/$LOG_NAME

echo "Backup:: Script Start -- $(date +%Y%m%d_%H%M)" >> $LOG
START_TIME=$(date +%s)

cd /var/www >> $LOG
mkdir tmp >> $LOG
cd tmp >> $LOG
wget $BK_F_URL >> $LOG

#si BK_EXT es un zip
unzip $BK_F_FILE >> $LOG
#si BK_EXT es un tar.bz2
cd .. >> $LOG
mv tmp $PROJECT_NAME >> $LOG
chown -R www-data:www-data $PROJECT_NAME >> $LOG

### Download Database Backup
wget $BK_DB_URL >> $LOG
gunzip $BK_DB_FILE >> $LOG

### Vamos a crear el usuario y la base siguiendo el nuevo estandard de broobe
SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_prod;"
SQL2="CREATE USER '${PROJECT_NAME}_user'@'localhost' IDENTIFIED BY '${DB_PASS}';"
SQL3="GRANT ALL PRIVILEGES ON playnet_prod . * TO '${PROJECT_NAME}_user'@'localhost';"
SQL4="FLUSH PRIVILEGES;"

$BIN_MYSQL -h $DB_HOST -u root -p${rootPassword} -e "${SQL1}${SQL2}${SQL3}${SQL4}" >> $LOG
$BIN_MYSQL -h $DB_HOST -u root -p${rootPassword}  ${PROJECT_NAME}_prod < $BK_DB_FILE >> $LOG

#change wp-config.php database parameters
sed -i "/DB_HOST/s/'[^']*'/'localhost'/2" wp-config.php >> $LOG
sed -i "/DB_NAME/s/'[^']*'/'${PROJECT_NAME}_prod'/2" wp-config.php >> $LOG
sed -i "/DB_USER/s/'[^']*'/'${PROJECT_NAME}_user'/2" wp-config.php >> $LOG
sed -i "/DB_PASSWORD/s/'[^']*'/'DB_PASS'/2" wp-config.php >> $LOG

#create nginx config files for site
#ln -s /etc/nginx/sites-available/${PROJECT_DOM} /etc/nginx/sites-enabled/${PROJECT_DOM}
#service nginx reload >> $LOG


### Log End ###
END_TIME=$(date +%s)
ELAPSED_TIME=$(expr $END_TIME - $START_TIME)

echo "Backup :: Script End -- $(date +%Y%m%d_%H%M)" >> $LOG
echo "Elapsed Time ::  $(date -d 00:00:$ELAPSED_TIME +%Hh:%Mm:%Ss) "  >> $LOG
