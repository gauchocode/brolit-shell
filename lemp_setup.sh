#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9
################################################################################

#TODO: esto deberia deprecarse y calcularse con el hardware del server
SERVER_MODEL=""                                                                 # Options: cx11, cx21, cx31

NETDATA="true"
MONIT="true"
COMPOSER="false"
WP="false"
MARIADB="false"                                                                 # If true MariaDB will be installed instead MySQL
PHP_V="7.2"                                                                     # Ubuntu 18.04 LTS Default

### Checking some things...
if [ $USER != root ]; then
  echo -e ${RED}"Error: must be root! Exiting..."${ENDCOLOR}
  exit 0
fi
if [[ -z "${SERVER_MODEL}" ]]; then
  echo -e ${RED}"Error: SERVER_MODEL must be set! Exiting..."${ENDCOLOR}
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

if [[ -z "${DOMAIN}" ]]; then
  DOMAIN=$(whiptail --title "Main Domain for LEMP Installation" --inputbox "Please insert the VPS main domain:" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    #TODO: testear el password antes de guardarlo
    echo "DOMAIN="${DOMAIN} >>$LOG
  else
    exit 1
  fi
fi

# Updating packages
echo " > Adding repos and updating package lists ..." >>$LOG
apt --yes install software-properties-common
add-apt-repository ppa:certbot/certbot
apt --yes update

echo " > Upgrading packages before installation ..." >>$LOG
apt --yes dist-upgrade

# Installing packages
if [ "${MARIADB}" = false ] ; then
  echo " > LEMP installation with MySQL ..." >>$LOG
  apt --yes install nginx mysql-server php${PHP_V}-fpm php${PHP_V}-mysql php-xml php${PHP_V}-curl php${PHP_V}-mbstring php${PHP_V}-gd php-imagick php${PHP_V}-zip php${PHP_V}-bz2 php-bcmath php${PHP_V}-soap php${PHP_V}-dev php-pear zip clamav ncdu jpegoptim optipng python-certbot-nginx sendemail libio-socket-ssl-perl dnsutils

else
  echo " > LEMP installation with MariaDB ..." >>$LOG
  apt --yes install nginx mariadb-server mariadb-client php${PHP_V}-fpm php${PHP_V}-mysql php-xml php${PHP_V}-curl php${PHP_V}-mbstring php${PHP_V}-gd php-imagick php${PHP_V}-zip php${PHP_V}-bz2 php-bcmath php${PHP_V}-soap php${PHP_V}-dev php-pear zip clamav ncdu jpegoptim optipng python-certbot-nginx sendemail libio-socket-ssl-perl dnsutils

fi

pear install mail mail_mime net_smtp

# Configuring packages
configure timezone
dpkg-reconfigure tzdata

# Secure mysql installation
# TODO: Unattended
# https://gist.github.com/coderua/5592d95970038944d099
# https://gist.github.com/Mins/4602864
# https://stackoverflow.com/questions/24270733/automate-mysql-secure-installation-with-echo-command-via-a-shell-script
sudo mysql_secure_installation

# Remove html default nginx folders
rm -r /var/www/html

# nginx conf file
echo " > Moving nginx configuration files ..." >>$LOG
# Empty default site configuration
echo " " >> /etc/nginx/sites-available/default

################################ OPTIMIZATIONS #################################

# Getting server info
#CPUS=$(grep -c "processor" /proc/cpuinfo)
#RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}' | xargs -I {} echo "scale=0; {}/1024^2" | bc)

# nginx.conf broobe standard configuration
cat confs/nginx.conf > /etc/nginx/nginx.conf


# TODO: reemplazar lo de abajo por el nuevo script
# source utils/php_optimizations.sh

# php.ini broobe standard configuration
echo " > Moving php configuration file ..." >>$LOG
cat confs/php.ini > /etc/php/${PHP_V}/fpm/php.ini

# fpm broobe standard configuration
echo " > Moving fpm configuration file ..." >>$LOG
cat confs/${SERVER_MODEL}/www.conf > /etc/php/${PHP_V}/fpm/pool.d/www.conf

################################################################################

################################## INSTALLERS ##################################
if [ "${WP}" = true ] ; then
  ${SFOLDER}/utils/wordpress_installer.sh

fi
if [ "${COMPOSER}" = true ] ; then
  ${SFOLDER}/utils/composer_installer.sh

fi
if [ "${MONIT}" = true ] ; then
  ${SFOLDER}/utils/monit_installer.sh

fi
if [ "${NETDATA}" = true ] ; then
  ${SFOLDER}/utils/netdata_installer.sh

fi
################################################################################

echo -e ${GREEN}" > DONE ..."${ENDCOLOR}

echo "Backup: Script End -- $(date +%Y%m%d_%H%M)" >> $LOG
