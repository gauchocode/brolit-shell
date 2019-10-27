#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 3.0
################################################################################
#
# https://github.com/AbhishekGhosh/Ubuntu-16.04-Nginx-WordPress-Autoinstall-Bash-Script/
# https://alonganon.info/2018/11/17/make-a-super-fast-and-lightweight-wordpress-on-ubuntu-18-04-with-php-7-2-nginx-and-mariadb/
#
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/mail_notification_helper.sh
#source ${SFOLDER}/libs/mysql_helper.sh

################################################################################

DOMAIN=$(whiptail --title "Domain" --inputbox "Insert the domain for PhpMyAdmin. Example: sql.broobe.com" 10 60 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
  echo "Setting DOMAIN="${DOMAIN}

  ROOT_DOMAIN=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?

else
  exit 1
fi

# Download phpMyAdmin
cd /var/www
wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip
unzip phpMyAdmin-latest-all-languages.zip

rm phpMyAdmin-latest-all-languages.zip

mv phpMyAdmin-* ${DOMAIN}


# Cloudflare API to change DNS records
echo "Trying to access Cloudflare API and change record ${DOMAIN} ..." >>$LOG
echo -e ${YELLOW}"Trying to access Cloudflare API and change record ${DOMAIN} ..."${ENDCOLOR}

zone_name=${ROOT_DOMAIN}
record_name=${DOMAIN}
export zone_name record_name
${SFOLDER}/utils/cloudflare_update_IP.sh

# New site Nginx configuration
echo " > Trying to generate nginx config for ${DOMAIN} ..." >>$LOG
echo -e ${YELLOW}" > Trying to generate nginx config for ${DOMAIN} ..."${ENDCOLOR}

cp ${SFOLDER}/confs/nginx/sites-available/default /etc/nginx/sites-available/${DOMAIN}
ln -s /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/${DOMAIN}

# Replacing string to match domain name
sed -i "s#dominio.com#${DOMAIN}#" /etc/nginx/sites-available/${DOMAIN}
# Need to run twice
sed -i "s#dominio.com#${DOMAIN}#" /etc/nginx/sites-available/${DOMAIN}

# Restart nginx service
service nginx reload

echo " > Nginx configuration loaded!" >>$LOG

# HTTPS with Certbot
${SFOLDER}/utils/certbot_manager.sh
#certbot_certificate_install "${MAILA}" "${DOMAIN}"

main_menu
