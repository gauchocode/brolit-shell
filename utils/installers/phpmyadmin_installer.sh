#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc03
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/nginx_helper.sh"
source "${SFOLDER}/libs/cloudflare_helper.sh"
source "${SFOLDER}/libs/mail_notification_helper.sh"

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
cd "/var/www"
wget "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip"
unzip "phpMyAdmin-latest-all-languages.zip"

rm "phpMyAdmin-latest-all-languages.zip"

mv phpMyAdmin-* "${DOMAIN}"

# Cloudflare API to change DNS records
cloudflare_change_a_record "${ROOT_DOMAIN}" "${DOMAIN}"

# New site Nginx configuration
create_nginx_server "${PROJECT_DOMAIN}" "phpmyadmin"

# HTTPS with Certbot
certbot_helper_installer_menu "${DOMAIN}"

main_menu
