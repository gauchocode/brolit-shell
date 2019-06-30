#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.5
#############################################################################

#conf vars

#TODO: esto deberia deprecarse y calcularse con el hardware del server
SERVER_MODEL=""                               # Options: cx11, cx21, cx31

#TODO: todo esto debe preguntarse en los installers con whiptail
DOMAIN=""
COMPOSER="false"
WP="false"
MARIADB="false"                               # If true MariaDB will be installed instead MySQL
PHP_V="7.2"                                   # Ubuntu 18.04 LTS Default

### Checking some things...
if [ $USER != root ]; then
  echo -e ${RED}"Error: must be root! Exiting..."${ENDCOLOR}
  exit 0
fi
if [[ -z "${SERVER_MODEL}" || -z "${MPASS}" ]]; then
  echo -e ${RED}"Error: SERVER_MODEL and MPASS must be set! Exiting..."${ENDCOLOR}
  exit 0
fi

### Log Start
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

### EXPORT VARS
export LOG

# Updating packages
echo " > Adding repos and updating package lists ..." >>$LOG
apt --yes install software-properties-common
add-apt-repository ppa:certbot/certbot
apt --yes update

echo " > Upgrading packages before installation ..." >>$LOG
apt --yes dist-upgrade

if [ "${MARIADB}" = false ] ; then
  echo " > LEMP installation with MySQL ..." >>$LOG
  apt --yes install nginx mysql-server php${PHP_V}-fpm php${PHP_V}-mysql php-xml php${PHP_V}-curl php${PHP_V}-mbstring php${PHP_V}-gd php-imagick php${PHP_V}-zip php${PHP_V}-bz2 php-bcmath php${PHP_V}-soap php${PHP_V}-dev php-pear zip clamav ncdu jpegoptim optipng python-certbot-nginx monit sendemail libio-socket-ssl-perl dnsutils

else
  echo " > LEMP installation with MariaDB ..." >>$LOG
  apt --yes install nginx mariadb-server mariadb-client php${PHP_V}-fpm php${PHP_V}-mysql php-xml php${PHP_V}-curl php${PHP_V}-mbstring php${PHP_V}-gd php-imagick php${PHP_V}-zip php${PHP_V}-bz2 php-bcmath php${PHP_V}-soap php${PHP_V}-dev php-pear zip clamav ncdu jpegoptim optipng python-certbot-nginx monit sendemail libio-socket-ssl-perl dnsutils

fi

pear install mail mail_mime net_smtp

configure timezone
dpkg-reconfigure tzdata

# Secure mysql installation
sudo mysql_secure_installation

# Getting server info
CPUS=$(grep -c "processor" /proc/cpuinfo)
RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}' | xargs -I {} echo "scale=0; {}/1024^2" | bc)

# php.ini broobe standard configuration
echo " > Moving php configuration file ..." >>$LOG
cat confs/php.ini > /etc/php/${PHP_V}/fpm/php.ini

# fpm broobe standard configuration
echo " > Moving fpm configuration file ..." >>$LOG
cat confs/${SERVER_MODEL}/www.conf > /etc/php/${PHP_V}/fpm/pool.d/www.conf

# Remove html default nginx folders
rm -r /var/www/html

# nginx.conf broobe standard configuration
cat confs/nginx.conf > /etc/nginx/nginx.conf

# nginx conf file
echo " > Moving nginx configuration files ..." >>$LOG
# Empty default site configuration
echo " " >> /etc/nginx/sites-available/default

if [ "${WP}" = true ] ; then
  ${SFOLDER}/utils/wordpress_installer.sh
  
fi

if [ "${COMPOSER}" = true ] ; then
  ${SFOLDER}/utils/composer_installer.sh

fi

# Configure monit
cat confs/monit/lemp-services > /etc/monit/conf.d/lemp-services
cat confs/monit/monitrc > /etc/monit/monitrc

echo -e ${YELLOW}" > Restarting services ..."${ENDCOLOR}
systemctl restart php${PHP_V}-fpm
systemctl restart nginx.service
service monit restart

${SFOLDER}/utils/netdata_installer.sh

echo -e ${GREEN}" > DONE ..."${ENDCOLOR}

echo "Backup: Script End -- $(date +%Y%m%d_%H%M)" >> $LOG
