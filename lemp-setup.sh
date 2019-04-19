#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.1
#############################################################################

#conf vars
SERVER_MODEL=""                               #Options: cx11, cx21, cx31
DOMAIN="DOMAIN_NAME"
MySQL_ROOT_PASS=""          									#MySQL root User Pass
COMPOSER="false"
WP="false"

### Log Start ###
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PATH_LOG="$SFOLDER/logs"
if [ ! -d "$SFOLDER/logs" ]
then
    echo " > Folder $SFOLDER/logs doesn't exist. Creating now ..."
    mkdir $SFOLDER/logs
    echo " > Folder $SFOLDER/logs created ..."
fi

LOG_NAME=log_lemp_$TIMESTAMP.log
LOG=$PATH_LOG/$LOG_NAME

### EXPORT VARS ###
export DOMAIN LOG

#updating packages
echo -e "\nUpdating package lists..\n" >>$LOG

apt --yes install software-properties-common
add-apt-repository ppa:certbot/certbot
apt --yes update
apt --yes dist-upgrade

apt --yes install nginx mysql-server php7.2-fpm php7.2-mysql php-xml php7.2-curl php7.2-mbstring php7.2-gd php-imagick php7.2-zip php7.2-bz2 php-bcmath php7.2-soap php7.2-dev php-pear zip clamav ncdu jpegoptim optipng python-certbot-nginx monit

configure timezone
dpkg-reconfigure tzdata

#secure mysql installation
sudo mysql_secure_installation

#php.ini broobe standard configuration
echo -e "\nMoving php configuration file...\n" >>$LOG
cat confs/php.ini > /etc/php/7.2/fpm/php.ini

#fpm broobe standard configuration
echo -e "\nMoving fpm configuration file...\n" >>$LOG
cat confs/$SERVER_MODEL/www.conf > /etc/php/7.2/fpm/pool.d/www.conf

#remove html default nginx folders
rm -r /var/www/html

#nginx.conf broobe standard configuration
cat confs/nginx.conf > /etc/nginx/nginx.conf

#nginx conf file
echo -e "\nMoving nginx configuration files...\n" >>$LOG
#empty default site configuration
echo " " >> /etc/nginx/sites-available/default
#netdata proxy configuration
cp confs/monitor /etc/nginx/sites-available

#new site configuration
cp confs/default /etc/nginx/sites-available/$DOMAIN
ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN

if [ "$WP" = true ] ; then
  sh wordpress.sh
fi

if [ "$COMPOSER" = true ] ; then
  EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"
  if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]
  then
      >&2 echo 'ERROR: Invalid installer signature' >>$LOG
      rm composer-setup.php
      exit 1
  fi
  php composer-setup.php --quiet
  RESULT=$?
  rm composer-setup.php
  exit $RESULT
fi

#replacing string to match domain name
#sudo replace "domain.com" "$DOMAIN" -- /etc/nginx/sites-available/default
sed -i "s#dominio.com#$DOMAIN#" /etc/nginx/sites-available/default
#es necesario correrlo dos veces para reemplazarlo dos veces en una misma linea
sed -i "s#dominio.com#$DOMAIN#" /etc/nginx/sites-available/default

sed -i "s#dominio.com#$DOMAIN#" /etc/nginx/sites-available/monitor
#sudo sed -i "s#dominio.com#$DOMAIN#" /etc/nginx/sites-available/phpmyadmin

ln -s /etc/nginx/sites-available/monitor /etc/nginx/sites-enabled/monitor
#ln -s /etc/nginx/sites-available/phpmyadmin /etc/nginx/sites-enabled/phpmyadmin

#configure monit
cp confs/monit/lemp-services /etc/monit/conf.d/lemp-services
rm /etc/monit/monitrc
cp confs/monit/monitrc /etc/monit/monitrc

echo -e "\nRestarting services...\n"
systemctl restart php7.2-fpm
systemctl restart nginx.service
service monit restart

#TODO: ya dejar configurada las extensiones
echo -e "\nInstalling Netdata...\n"
apt --yes install zlib1g-dev uuid-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config curl python-mysqldb
git clone https://github.com/firehol/netdata.git --depth=1
cd netdata && ./netdata-installer.sh --dont-wait
killall netdata && cp system/netdata.service /etc/systemd/system/

#TODO: Agregar otras confs y la config de las notificaciones
#
cat confs/netdata/python.d/mysql.conf > /usr/lib/netdata/conf.d/python.d/mysql.conf
cat confs/netdata/python.d/monit.conf > /usr/lib/netdata/conf.d/python.d/monit.conf

SQL1="CREATE USER 'netdata'@'localhost';"
SQL2="GRANT USAGE on *.* to 'netdata'@'localhost';"
SQL3="FLUSH PRIVILEGES;"

echo "Creating netdata user ..." >> $LOG
mysql -u root -p${MySQL_ROOT_PASS} -e "${SQL1}${SQL2}${SQL3}" >> $LOG

systemctl daemon-reload && systemctl enable netdata && service netdata start

echo "Backup :: Script End -- $(date +%Y%m%d_%H%M)" >> $LOG
