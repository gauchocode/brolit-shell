#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.5
#############################################################################

#conf vars

#TODO: esto deberia deprecarse y calcularse con el hardware del server
SERVER_MODEL=""                               # Options: cx11, cx21, cx31

#TODO: el dominio debe preguntarse en los installers con whiptail
DOMAIN=""
#TODO: el pass de MySQL debe sacarse de una config
MySQL_ROOT_PASS=""

COMPOSER="false"
WP="false"

MARIADB="false"                               # If true MariaDB will be installed instead MySQL
PHP_V="7.2"                                   # Ubuntu 18.04 LTS Default

### Setup Colours ###
BLACK='\E[30;40m'
RED='\E[31;40m'
GREEN='\E[32;40m'
YELLOW='\E[33;40m'
BLUE='\E[34;40m'
MAGENTA='\E[35;40m'
CYAN='\E[36;40m'
WHITE='\E[37;40m'

### Checking some things... ###
if [ $USER != root ]; then
  echo -e ${RED}"Error: must be root! Exiting..."${ENDCOLOR}
  exit 0
fi
if [[ -z "${SERVER_MODEL}" || -z "${MySQL_ROOT_PASS}" ]]; then
  echo -e ${RED}"Error: SERVER_MODEL and MySQL_ROOT_PASS must be set! Exiting..."${ENDCOLOR}
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

LOG_NAME=log_lemp_${TIMESTAMP}.log
LOG=${PATH_LOG}/${LOG_NAME}

### EXPORT VARS ###
export LOG

#updating packages
echo -e "\nAdding repos and updating package lists ...\n" >>$LOG
apt --yes install software-properties-common
add-apt-repository ppa:certbot/certbot
apt --yes update

echo -e "\nUpgrading packages before installation ...\n" >>$LOG
apt --yes dist-upgrade

if [ "${MARIADB}" = false ] ; then
  echo -e "\nLEMP installation with MySQL ...\n" >>$LOG
  apt --yes install nginx mysql-server php${PHP_V}-fpm php${PHP_V}-mysql php-xml php${PHP_V}-curl php${PHP_V}-mbstring php${PHP_V}-gd php-imagick php${PHP_V}-zip php${PHP_V}-bz2 php-bcmath php${PHP_V}-soap php${PHP_V}-dev php-pear zip clamav ncdu jpegoptim optipng python-certbot-nginx monit sendemail libio-socket-ssl-perl dnsutils

else
  echo -e "\nLEMP installation with MariaDB ...\n" >>$LOG
  apt --yes install nginx mariadb-server mariadb-client php${PHP_V}-fpm php${PHP_V}-mysql php-xml php${PHP_V}-curl php${PHP_V}-mbstring php${PHP_V}-gd php-imagick php${PHP_V}-zip php${PHP_V}-bz2 php-bcmath php${PHP_V}-soap php${PHP_V}-dev php-pear zip clamav ncdu jpegoptim optipng python-certbot-nginx monit sendemail libio-socket-ssl-perl dnsutils

fi

pear install mail mail_mime net_smtp

configure timezone
dpkg-reconfigure tzdata

#secure mysql installation
sudo mysql_secure_installation

#getting server info
CPUS=$(grep -c "processor" /proc/cpuinfo)
RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}' | xargs -I {} echo "scale=0; {}/1024^2" | bc)

#php.ini broobe standard configuration
echo -e "\nMoving php configuration file...\n" >>$LOG
cat confs/php.ini > /etc/php/${PHP_V}/fpm/php.ini

#fpm broobe standard configuration
echo -e "\nMoving fpm configuration file...\n" >>$LOG
cat confs/${SERVER_MODEL}/www.conf > /etc/php/${PHP_V}/fpm/pool.d/www.conf

#remove html default nginx folders
rm -r /var/www/html

#nginx.conf broobe standard configuration
cat confs/nginx.conf > /etc/nginx/nginx.conf

#nginx conf file
echo -e "\nMoving nginx configuration files...\n" >>$LOG
#empty default site configuration
echo " " >> /etc/nginx/sites-available/default

if [ "${WP}" = true ] ; then
  ${SFOLDER}/utils/wordpress_installer.sh
fi

if [ "${COMPOSER}" = true ] ; then
  ${SFOLDER}/utils/composer_installer.sh
fi

#configure monit
cat confs/monit/lemp-services > /etc/monit/conf.d/lemp-services
cat confs/monit/monitrc > /etc/monit/monitrc

echo -e "\nRestarting services...\n"
systemctl restart php${PHP_V}-fpm
systemctl restart nginx.service
service monit restart

${SFOLDER}/utils/netdata_installer.sh

echo "Backup: Script End -- $(date +%Y%m%d_%H%M)" >> $LOG
