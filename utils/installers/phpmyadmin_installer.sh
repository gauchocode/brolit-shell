#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/nginx_helper.sh
source "${SFOLDER}/libs/nginx_helper.sh"
# shellcheck source=${SFOLDER}/libs/cloudflare_helper.sh
source "${SFOLDER}/libs/cloudflare_helper.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"

################################################################################

log_event "info" "Running phpmyadmin installer" "true"

domain=$(whiptail --title "Domain" --inputbox "Insert the domain for PhpMyAdmin. Example: sql.domain.com" 10 60 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
  log_event "info" "Setting domain=${domain}" "true"

  root_domain=$(whiptail --title "Root Domain" --inputbox "Insert the root project's domain (Only for Cloudflare API). Example: domain.com" 10 60 3>&1 1>&2 2>&3)
  #exitstatus=$?

else
  return 1

fi

# Download phpMyAdmin
cd "${SITES}"
wget "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip"
unzip "phpMyAdmin-latest-all-languages.zip"

rm "phpMyAdmin-latest-all-languages.zip"

mv phpMyAdmin-* "${domain}"

# New site Nginx configuration
create_nginx_server "${domain}" "phpmyadmin"

# Cloudflare API to change DNS records
cloudflare_change_a_record "${root_domain}" "${domain}"

# HTTPS with Certbot
certbot_helper_installer_menu "${MAILA}" "${domain}"

log_event "info" "phpmyadmin installer finished" "true"

main_menu
