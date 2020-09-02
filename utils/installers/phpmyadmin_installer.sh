#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc10
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

phpmyadmin_installer () {

  local project_domain possible_root_domain root_domain

  log_event "info" "Running phpmyadmin installer" "true"

  project_domain=$(whiptail --title "Domain" --inputbox "Insert the domain for PhpMyAdmin. Example: sql.domain.com" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    log_event "info" "Setting project_domain=${project_domain}" "true"

    possible_root_domain=${project_domain#[[:alpha:]]*.}
    root_domain=$(ask_rootdomain_for_cloudflare_config "${possible_root_domain}")

  else
    return 1

  fi

  # Download phpMyAdmin
  cd "${SITES}"
  wget "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip"
  unzip "phpMyAdmin-latest-all-languages.zip"

  rm "phpMyAdmin-latest-all-languages.zip"

  mv phpMyAdmin-* "${project_domain}"

  # New site Nginx configuration
  nginx_server_create "${project_domain}" "phpmyadmin" "single"

  # Cloudflare API to change DNS records
  cloudflare_change_a_record "${root_domain}" "${project_domain}"

  # HTTPS with Certbot
  certbot_helper_installer_menu "${MAILA}" "${project_domain}"

  log_event "info" "phpmyadmin installer finished!" "true"

}

################################################################################

phpmyadmin_installer
