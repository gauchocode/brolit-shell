#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9
################################################################################

# TODO: permitir instalar multiples versiones de PHP
#
#add-apt-repository ppa:ondrej/php && apt-get update
#
#apt-get install -y php5.6 php5.6-fpm php5.6-mcrypt php5.6-mbstring php5.6-curl php5.6-cli php5.6-mysql php5.6-gd php5.6-intl php5.6-xsl php5.6-zip libapache2-mod-php5.6
#apt-get install -y php7.3 php7.3-fpm php7.3-mcrypt php7.3-mbstring php7.3-curl php7.3-cli php7.3-mysql php7.3-gd php7.3-intl php7.3-xsl php7.3-zip libapache2-mod-php7.3

#
# fastcgi_pass unix:/var/run/php/php5.6-fpm.sock;
# fastcgi_pass unix:/var/run/php/php7.3-fpm.sock;
#
#
# TODO: permitir actualizar nginx
#add-apt-repository ppa:ondrej/nginx && apt-get update
#
# TODO: los installers de PHP-FPM, NGINX y MySQL/MariaDB deberian estar en otro script para poder ejecutarlos de manera individual

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# TODO: esto deberia deprecarse y calcularse con el hardware del server
SERVER_MODEL="cx11"                                                             # Options: cx11, cx21, cx31

CERTBOT="false"
NETDATA="false"
MONIT="false"
COMPOSER="false"
WP="false"
MARIADB="false"                                                                 # If true MariaDB will be installed instead MySQL
MYSQL8="false"
PHP_V="7.2"                                                                     # Ubuntu 18.04 LTS Default

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
    # TODO: para que lo usamos?
    echo "DOMAIN="${DOMAIN} >>$LOG
  else
    exit 1
  fi
fi

# Updating packages
echo " > Adding repos and updating package lists ..." >>$LOG
apt --yes install software-properties-common
apt --yes update
echo " > Upgrading packages before installation ..." >>$LOG
apt --yes dist-upgrade

echo " > Installing basic packages ..." >>$LOG
apt --yes install unzip zip clamav ncdu jpegoptim optipng sendemail libio-socket-ssl-perl dnsutils ghostscript pv

# Installing packages
if [ "${MARIADB}" =  "true" ] ; then

  echo " > LEMP installation with MariaDB ..." >>$LOG
  apt --yes install mariadb-server mariadb-client

else
  if [ "${MYSQL8}" = "true" ] ; then

    echo " > LEMP installation with MySQL 8 ..." >>$LOG
    wget -c https://dev.mysql.com/get/mysql-apt-config_0.8.10-1_all.deb
    sudo dpkg -i mysql-apt-config_0.8.10-1_all.deb

    sudo apt-key adv --keyserver keys.gnupg.net --recv-keys 5072E1F5

    apt --yes update
    apt --yes install mysql-server

    mkdir -pv /etc/systemd/system/mysqld.service.d
    cp ${SFOLDER}/confs/mysql/override.conf /etc/systemd/system/mysqld.service.d/override.conf
    cp ${SFOLDER}/confs/mysql/mysql /etc/init.d/mysql
    chmod +x /etc/init.d/mysql
    systemctl daemon-reload
    systemctl unmask mysql.service
    systemctl restart mysql

  else

    echo " > LEMP installation with MySQL ..." >>$LOG
    apt --yes install mysql-server

  fi

fi

apt --yes install nginx php${PHP_V}-fpm php${PHP_V}-mysql php-xml php${PHP_V}-curl php${PHP_V}-mbstring php${PHP_V}-gd php-imagick php${PHP_V}-zip php${PHP_V}-bz2 php-bcmath php${PHP_V}-soap php${PHP_V}-dev php-pear

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
cat ${SFOLDER}/confs/nginx/nginx.conf > /etc/nginx/nginx.conf

# TODO: reemplazar lo de abajo por el nuevo script
# source utils/php_optimizations.sh

# php.ini broobe standard configuration
echo " > Moving php configuration file ..." >>$LOG
cat ${SFOLDER}/confs/php/php.ini > /etc/php/${PHP_V}/fpm/php.ini

# fpm broobe standard configuration
echo " > Moving fpm configuration file ..." >>$LOG
cat ${SFOLDER}/confs/php/${SERVER_MODEL}/www.conf > /etc/php/${PHP_V}/fpm/pool.d/www.conf

################################## INSTALLERS ##################################

if [ "${CERTBOT}" = true ] ; then
  ${SFOLDER}/utils/certbot_installer.sh

fi
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
