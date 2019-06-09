#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.5
#############################################################################
#
# https://github.com/AbhishekGhosh/Ubuntu-16.04-Nginx-WordPress-Autoinstall-Bash-Script/
# https://alonganon.info/2018/11/17/make-a-super-fast-and-lightweight-wordpress-on-ubuntu-18-04-with-php-7-2-nginx-and-mariadb/
#
#############################################################################
SCRIPT_V="2.5"

### TO EDIT ###
DOMAIN="test.caeme.org.ar"
ROOT_DOMAIN="caeme.org.ar"
PROJECT_NAME="caeme"
PROJECT_STATE="test"                                    # OPTIONS: prod, test or dev
FOLDER_TO_INSTALL="/var/www"
SFOLDER="/root/broobe-utils-scripts"					          #Backup Scripts folder

### Setup Colours ###
BLACK='\E[30;40m'
RED='\E[31;40m'
GREEN='\E[32;40m'
YELLOW='\E[33;40m'
BLUE='\E[34;40m'
MAGENTA='\E[35;40m'
CYAN='\E[36;40m'
WHITE='\E[37;40m'

echo -n " > Creating site on nginx..."

cd ${FOLDER_TO_INSTALL}
curl -O https://wordpress.org/latest.tar.gz
tar -xzxf latest.tar.gz
rm latest.tar.gz
mv wordpress ${DOMAIN}
cd ${DOMAIN}
cp wp-config-sample.php ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-config.php
rm ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-config-sample.php

chown -R www-data:www-data ${FOLDER_TO_INSTALL}/${DOMAIN}
find ${FOLDER_TO_INSTALL}/${DOMAIN} -type d -exec chmod g+s {} \;
chmod g+w ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-content
chmod -R g+w ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-content/themes
chmod -R g+w ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-content/plugins

# wp-cli
#curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
#chmod +x wp-cli.phar
#move it to /usr/local/bin so that it can be run directly
#sudo mv wp-cli.phar /usr/local/bin/wp
#sudo -u www-data wp plugin install wordpress-seo

echo -e ${GREEN}" > DONE"

echo " > Trying to generate nginx config for ${DOMAIN} ..."
#new site configuration
cp ${SFOLDER}/confs/default /etc/nginx/sites-available/${DOMAIN}
ln -s /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/${DOMAIN}
#replacing string to match domain name
sed -i "s#dominio.com#${DOMAIN}#" /etc/nginx/sites-available/${DOMAIN}
#es necesario correrlo dos veces para reemplazarlo dos veces en una misma linea
sed -i "s#dominio.com#${DOMAIN}#" /etc/nginx/sites-available/${DOMAIN}
service nginx reload

echo " > Trying to execute certbot for ${CHOSEN_PROJECT} ..."
# TODO: certbot --nginx -d ${CHOSEN_PROJECT} -d www.${CHOSEN_PROJECT}
certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}

### TODO: ojo que me cambia el pass en el wp-config.php por más que el usuario exista, CORREGIR!!!
DB_PASS=$(openssl rand -hex 12)

#para cambiar pass de un user existente
#ALTER USER '_user'@'localhost' IDENTIFIED BY 'dadsada=';
SQL1="CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME}_${PROJECT_STATE};"
SQL2="CREATE USER IF NOT EXISTS '${PROJECT_NAME}_user'@'localhost' IDENTIFIED BY '${DB_PASS}';"
SQL3="GRANT ALL PRIVILEGES ON ${PROJECT_NAME}_${PROJECT_STATE} . * TO '${PROJECT_NAME}_user'@'localhost';"
SQL4="FLUSH PRIVILEGES;"

echo " > Creating database ${PROJECT_NAME}_${PROJECT_STATE}, and user ${PROJECT_NAME}_user with pass ${DB_PASS} if they not exist ..."
mysql -u root --password=${MySQL_ROOT_PASS} -e "${SQL1}${SQL2}${SQL3}${SQL4}"


echo " > Changing wp-config.php database parameters ..."
sed -i "/DB_HOST/s/'[^']*'/'localhost'/2" ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-config.php
sed -i "/DB_NAME/s/'[^']*'/'${PROJECT_NAME}_${PROJECT_STATE}'/2" ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-config.php
sed -i "/DB_USER/s/'[^']*'/'${PROJECT_NAME}_user'/2" ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-config.php
sed -i "/DB_PASSWORD/s/'[^']*'/'${DB_PASS}'/2" ${FOLDER_TO_INSTALL}/${DOMAIN}/wp-config.php

#set WP salts
perl -i -pe'
  BEGIN {
    @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
    push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
    sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
  }
  s/put your unique phrase here/salt()/ge
' wp-config.php

#TODO: usar cloudflare API para modificar o agregar el registro de DNS sobre el dominio en cuestión
echo -e ${YELLOW}"Trying to access Cloudflare API and change record ${DOMAIN} ..."  >> $LOG
zone_name=${ROOT_DOMAIN}
record_name=${DOMAIN}
export zone_name record_name
${SFOLDER}/utils/cloudflare_update_IP.sh
