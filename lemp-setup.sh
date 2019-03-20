#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 1.1
#############################################################################

#SERVER_MODEL OPTIONS= cx11, cx21, cx31
SERVER_MODEL=""
DOMAIN="DOMAIN_NAME"

#updating packages
echo -e "\nUpdating package lists..\n"

sudo apt --yes install software-properties-common
sudo add-apt-repository ppa:certbot/certbot
sudo apt --yes update
sudo apt --yes dist-upgrade

sudo apt --yes install nginx mysql-server php7.2-fpm php7.2-mysql php-xml php7.2-curl php7.2-mbstring php7.2-gd php-imagick php7.2-zip php7.2-bz2 php-bcmath php7.2-soap php7.2-dev php-pear zip clamav ncdu jpegoptim optipng python-certbot-nginx

configure timezone
sudo dpkg-reconfigure tzdata

#secure mysql installation
sudo mysql_secure_installation

#nginx conf file
echo -e "\nMoving nginx configuration files...\n"
#default site configuration
sudo mv confs/default /etc/nginx/sites-available
#netdata proxy configuration
sudo mv confs/monitor /etc/nginx/sites-available
#nginx.conf broobe standard configuration
cat confs/nginx.conf > /etc/nginx/nginx.conf

#php.ini broobe standard configuration
echo -e "\nMoving php configuration file...\n"
cat confs/php.ini > /etc/php/7.2/fpm/php.ini

#fpm broobe standard configuration
echo -e "\nMoving fpm configuration file...\n"
cat confs/$SERVER_MODEL/www.conf > /etc/php/7.2/fpm/pool.d/www.conf

#replacing string to match domain name
#sudo replace "domain.com" "$DOMAIN" -- /etc/nginx/sites-available/default
sudo sed -i "s#dominio.com#$DOMAIN#" /etc/nginx/sites-available/default
#es necesario correrlo dos veces para reemplazarlo dos veces en una misma linea
sudo sed -i "s#dominio.com#$DOMAIN#" /etc/nginx/sites-available/default

sudo sed -i "s#dominio.com#$DOMAIN#" /etc/nginx/sites-available/monitor
#sudo sed -i "s#dominio.com#$DOMAIN#" /etc/nginx/sites-available/phpmyadmin

ln -s /etc/nginx/sites-available/monitor /etc/nginx/sites-enabled/monitor
#ln -s /etc/nginx/sites-available/phpmyadmin /etc/nginx/sites-enabled/phpmyadmin

#fixing a bug?
mv /run/php/php7.0-fpm.sock /run/php/php7.2-fpm.sock

echo -e "\nRestarting services...\n"
sudo systemctl restart php7.2-fpm
sudo systemctl restart nginx.service

echo -e "\nInstalling Netdata...\n"
sudo apt --yes install zlib1g-dev uuid-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config curl python-mysqldb
git clone https://github.com/firehol/netdata.git --depth=1
cd netdata && ./netdata-installer.sh
killall netdata && cp system/netdata.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable netdata && service netdata start
