#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc9
#############################################################################

function phpmyadmin_installer () {

  local project_domain
  local possible_root_domain 
  local root_domain

  log_subsection "phpMyAdmin Installer"

  project_domain="$(whiptail --title "Domain" --inputbox "Insert the domain for PhpMyAdmin. Example: sql.domain.com" 10 60 3>&1 1>&2 2>&3)"
  
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    log_event "info" "Setting project_domain=${project_domain}" "false"

    possible_root_domain="$(domain_get_root "${project_domain}")"
    root_domain="$(cloudflare_ask_rootdomain "${possible_root_domain}")"

  else

    return 1

  fi

  # Download phpMyAdmin
  display --indent 6 --text "- Downloading phpMyAdmin"
  log_event "debug" "Running: ${CURL} https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip > ${PROJECTS_PATH}/phpMyAdmin-latest-all-languages.zip" "false"
  
  ${CURL} "https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip" > "${PROJECTS_PATH}/phpMyAdmin-latest-all-languages.zip"
  
  clear_previous_lines "1"
  display --indent 6 --text "- Downloading phpMyAdmin" --result "DONE" --color GREEN

  # Uncompress
  display --indent 6 --text "- Uncompressing phpMyAdmin"
  log_event "debug" "Running: unzip -qq ${PROJECTS_PATH}/phpMyAdmin-latest-all-languages.zip -d ${PROJECTS_PATH}/${project_domain}" "false"
  
  unzip -qq "${PROJECTS_PATH}/phpMyAdmin-latest-all-languages.zip" -d "${PROJECTS_PATH}"
  
  clear_previous_lines "1"
  display --indent 6 --text "- Uncompressing phpMyAdmin" --result "DONE" --color GREEN

  # Delete downloaded file
  rm "${PROJECTS_PATH}/phpMyAdmin-latest-all-languages.zip"
  
  display --indent 6 --text "- Deleting installer file" --result "DONE" --color GREEN

  # Change directory name
  log_event "debug" "Running: mv ${PROJECTS_PATH}/phpMyAdmin-* ${PROJECTS_PATH}/${project_domain}" "false"
  
  mv "${PROJECTS_PATH}"/phpMyAdmin-* "${PROJECTS_PATH}/${project_domain}"
  
  display --indent 6 --text "- Changing directory name" --result "DONE" --color GREEN

  # New site Nginx configuration
  nginx_server_create "${project_domain}" "phpmyadmin" "single" ""

  # Cloudflare API to change DNS records
  cloudflare_set_record "${root_domain}" "${project_domain}" "A" "${SERVER_IP}"

  # HTTPS with Certbot
  certbot_helper_installer_menu "${NOTIFICATION_EMAIL_MAILA}" "${project_domain}"

  # Log
  log_event "info" "phpMyAdmin installer finished" "false"
  display --indent 6 --text "- Installing phpMyAdmin" --result "DONE" --color GREEN
  #log_break

}