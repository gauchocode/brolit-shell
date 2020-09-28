#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.3
#############################################################################

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

  log_event "info" "Running phpmyadmin installer"

  project_domain=$(whiptail --title "Domain" --inputbox "Insert the domain for PhpMyAdmin. Example: sql.domain.com" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    log_event "info" "Setting project_domain=${project_domain}"

    possible_root_domain=${project_domain#[[:alpha:]]*.}
    root_domain=$(ask_rootdomain_for_cloudflare_config "${possible_root_domain}")

  else
    return 1

  fi

  # Download phpMyAdmin
  display --indent 2 --text " - Downloading phpMyAdmin"
  wget –-quiet "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip" -P "${SITES}"
  clear_last_line
  display --indent 2 --text " - Downloading phpMyAdmin" --result "DONE" --color GREEN

  # Uncompress
  display --indent 2 --text " - Uncompressing phpMyAdmin"
  unzip -qq "phpMyAdmin-latest-all-languages.zip"
  clear_last_line
  display --indent 2 --text " - Uncompressing phpMyAdmin" --result "DONE" --color GREEN

  # Delete downloaded file
  rm "phpMyAdmin-latest-all-languages.zip"

  # Change directory name
  mv phpMyAdmin-* "${project_domain}"
  display --indent 2 --text " - Changing directory name" --result "DONE" --color GREEN

  # New site Nginx configuration
  nginx_server_create "${project_domain}" "phpmyadmin" "tool"

  # Cloudflare API to change DNS records
  cloudflare_change_a_record "${root_domain}" "${project_domain}"

  # HTTPS with Certbot
  certbot_helper_installer_menu "${MAILA}" "${project_domain}"

  log_event "info" "phpmyadmin installer finished!"
  display --indent 2 --text " - Installing phpMyAdmin" --result "DONE" --color GREEN

}

################################################################################

phpmyadmin_installer
