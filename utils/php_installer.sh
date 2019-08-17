#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9.7
################################################################################
# TODO: permitir instalar multiples versiones de PHP
#
# add-apt-repository ppa:ondrej/php && apt-get update
#
# apt-get install -y php5.6 php5.6-fpm php5.6-mcrypt php5.6-mbstring php5.6-curl php5.6-cli php5.6-mysql php5.6-gd php5.6-intl php5.6-xsl php5.6-zip libapache2-mod-php5.6
# apt-get install -y php7.3 php7.3-fpm php7.3-mcrypt php7.3-mbstring php7.3-curl php7.3-cli php7.3-mysql php7.3-gd php7.3-intl php7.3-xsl php7.3-zip libapache2-mod-php7.3
#
#

php_installation() {
    apt --yes install php${PHP_V}-fpm php${PHP_V}-mysql php-xml php${PHP_V}-curl php${PHP_V}-mbstring php${PHP_V}-gd php-imagick php${PHP_V}-zip php${PHP_V}-bz2 php-bcmath php${PHP_V}-soap php${PHP_V}-dev php-pear

}

mail_utils_installation(){
    pear install mail mail_mime net_smtp
}

################################################################################

# TODO: esto deberia deprecarse y calcularse con el hardware del server
SERVER_MODEL="cx11" # Options: cx11, cx21, cx31

if [[ -z "${SERVER_MODEL}" ]]; then
  echo -e ${RED}"Error: SERVER_MODEL must be set! Exiting..."${ENDCOLOR}
  exit 0
fi

# Installing packages
php_installation
mail_utils_installation


# TODO: acá simplemente habria que cambiar max_upload_size y el max_post_size en vez de pizar el php.ini
# php.ini broobe standard configuration
echo " > Moving php configuration file ..." >>$LOG
cat ${SFOLDER}/confs/php/php.ini > /etc/php/${PHP_V}/fpm/php.ini

# TODO: DEPRECAR, USAR php_optimizations.sh
#${SFOLDER}/utils/php_optimizations.sh
echo " > Moving fpm configuration file ..." >>$LOG
cat ${SFOLDER}/confs/php/${SERVER_MODEL}/www.conf > /etc/php/${PHP_V}/fpm/pool.d/www.conf

# TODO: en caso de instalar una nueva version de PHP, dar opcion de reconfigurar los sites de nginx
# reconfigure_nginx_sites()
# fastcgi_pass unix:/var/run/php/php5.6-fpm.sock;
# fastcgi_pass unix:/var/run/php/php7.3-fpm.sock;