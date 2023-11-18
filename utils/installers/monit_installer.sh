#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.7
################################################################################
#
# Monit Installer
#
#   Ref: https://www.mmonit.com/monit/documentation
#
################################################################################

################################################################################
# Monit package install
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function monit_installer() {

  log_subsection "Monit Installer"

  package_install_if_not "monit"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    PACKAGES_MONIT_STATUS="enabled"

    json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.monit[].status" "${PACKAGES_MONIT_STATUS}"

    # new global value ("enabled")
    export PACKAGES_MONIT_STATUS

    return 0

  else

    return 1

  fi

}

################################################################################
# Monit package purge
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function monit_purge() {

  log_subsection "Monit Installer"

  package_purge "monit"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    PACKAGES_MONIT_STATUS="disabled"

    json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.monit[].status" "${PACKAGES_MONIT_STATUS}"

    # new global value ("disabled")
    export PACKAGES_MONIT_STATUS

    return 0

  else

    return 1

  fi

}

################################################################################
# Configure Monit service
#
# Arguments:
#   none
#
# Outputs:
#   0 if monit were installed, 1 on error.
################################################################################

function monit_configure() {

  # Copy monitrc file
  cat "${BROLIT_MAIN_DIR}/config/monit/monitrc" >"/etc/monit/monitrc"

  if [[ ${PACKAGES_MONIT_CONFIG_HTTPD_STATUS} == "enabled" ]]; then

    # Replace httpd user
    local monit_user="${PACKAGES_MONIT_CONFIG_HTTPD_USER}"
    sed -i "s#MONIT_USER#${monit_user}#" "/etc/monit/monitrc"

    # Replace httpd password
    local monit_pass="${PACKAGES_MONIT_CONFIG_HTTPD_PASS}"
    sed -i "s#MONIT_PASSWORD#${monit_pass}#" "/etc/monit/monitrc"

    [[ ${SECURITY_STATUS} == "enabled" ]] && firewall_allow "2812"

  fi

  if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" && -d "${NETDATA_INSTALL_DIR}" ]]; then
    # Replace monit httpd user
    sed -i "s#MONIT_USER#${monit_user}#" "${NETDATA_INSTALL_DIR}/python.d/monit.conf"
    # Replace monit httpd  password
    sed -i "s#MONIT_PASSWORD#${monit_pass}#" "${NETDATA_INSTALL_DIR}/python.d/monit.conf"
  fi

  # Get all listed apps
  services_list="${MONIT_CONFIG_SERVICES}"

  # Get keys
  services_list_keys="$(jq -r 'keys[]' <<<"${services_list}" | sed ':a; N; $!ba; s/\n/ /g')"

  # String to array
  IFS=' ' read -r -a services_list_keys_array <<<"$services_list_keys"

  # Loop through all apps keys
  for services_list_key in "${services_list_keys_array[@]}"; do

    services_list_value="$(jq -r ."${services_list_key}" <<<"${services_list}")"

    if [[ ${services_list_value} == "enabled" ]]; then

      # Configuring monit
      cat "${BROLIT_MAIN_DIR}/config/monit/${services_list_key}" >"/etc/monit/conf.d/${services_list_key}"

      if [[ ${services_list_key} == "system" ]]; then

        if [[ ${NOTIFICATION_EMAIL_STATUS} == "enabled" ]]; then

          # Set Hostname
          sed -i "s#HOSTNAME#${SERVER_NAME}#" "/etc/monit/conf.d/${services_list_key}"

          # Set SMTP vars
          ## Run two times to cober all var appearance
          sed -i "s#NOTIFICATION_EMAIL_SMTP_SERVER#${NOTIFICATION_EMAIL_SMTP_SERVER}#" "/etc/monit/conf.d/${services_list_key}"
          sed -i "s#NOTIFICATION_EMAIL_SMTP_PORT#${NOTIFICATION_EMAIL_SMTP_PORT}#" "/etc/monit/conf.d/${services_list_key}"
          ## Run two times to cober all var appearance
          sed -i "s#NOTIFICATION_EMAIL_SMTP_USER#${NOTIFICATION_EMAIL_SMTP_USER}#" "/etc/monit/conf.d/${services_list_key}"
          sed -i "s#NOTIFICATION_EMAIL_SMTP_USER#${NOTIFICATION_EMAIL_SMTP_USER}#" "/etc/monit/conf.d/${services_list_key}"
          sed -i "s#NOTIFICATION_EMAIL_SMTP_UPASS#${NOTIFICATION_EMAIL_SMTP_UPASS}#" "/etc/monit/conf.d/${services_list_key}"

          # Email to send monit notifications
          sed -i "s#NOTIFICATION_EMAIL_MAILA#${PACKAGES_MONIT_CONFIG_MAILA}#" "/etc/monit/conf.d/${services_list_key}"

          # Log
          log_event "info" "Configuring ${services_list_key} on monit" "false"
          display --indent 6 --text "- Configuring ${services_list_key}" --result "DONE" --color GREEN

        else

          # Remove system email config
          rm -f "/etc/monit/conf.d/${services_list_key}"

          # Log
          display --indent 6 --text "- Configuring ${services_list_key}" --result "SKIPPED" --color YELLOW
          display --indent 8 --text "Email notifications not enabled"
          log_event "warning" "Configuring ${services_list_key} on monit failed. Email notifications not enabled." "false"

        fi

      else

        if [[ ! -x "${PHP_V}" && ${services_list_key} == "phpfpm" ]]; then
          PHP_V=$(php -r "echo PHP_VERSION;")
          PHP_V=${PHP_V:0:3} #get only first 3 chars (ex. 8.1)
          # Set PHP_V
          php_set_version_on_config "${PHP_V}" "/etc/monit/conf.d/${services_list_key}"
          # Service restart
          systemctl restart "php${PHP_V}-fpm"
        fi

        # Log
        log_event "info" "Configuring ${services_list_key} on monit" "false"
        display --indent 6 --text "- Configuring ${services_list_key}" --result "DONE" --color GREEN

      fi

    fi

  done

  log_event "info" "Restarting services ..." "false"

  # Service restart
  systemctl restart nginx.service
  service monit restart

  # Log
  display --indent 6 --text "- Restarting services" --result "DONE" --color GREEN

  log_event "info" "Monit configured" "false"
  display --indent 6 --text "- Monit configuration" --result "DONE" --color GREEN

}
