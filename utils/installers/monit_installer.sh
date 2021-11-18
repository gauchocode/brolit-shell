#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1
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

  if [[ $? -eq 0 ]]; then

    PACKAGES_MONIT_CONFIG_STATUS="enabled"

    json_write_field "${BROLIT_CONFIG_FILE}" "SUPPORT.monit[].status" "${PACKAGES_MONIT_CONFIG_STATUS}"

    # new global value ("enabled")
    export PACKAGES_MONIT_CONFIG_STATUS

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

  if [[ $? -eq 0 ]]; then

    PACKAGES_MONIT_CONFIG_STATUS="disabled"

    json_write_field "${BROLIT_CONFIG_FILE}" "SUPPORT.monit[].status" "${PACKAGES_MONIT_CONFIG_STATUS}"

    # new global value ("enabled")
    export PACKAGES_MONIT_CONFIG_STATUS

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
#   0 if it utils were installed, 1 on error.
################################################################################

function monit_configure() {

  cat "${SFOLDER}/config/monit/monitrc" >"/etc/monit/monitrc"

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
      ## Using script template
      cat "${SFOLDER}/config/monit/${services_list_key}" >"/etc/monit/conf.d/${services_list_key}"

      # Log
      log_event "info" "Configuring ${services_list_key} on monit" "false"
      display --indent 6 --text "- Configuring ${services_list_key}" --result "DONE" --color GREEN

      if [[ ! -x "${PHP_V}" && ${services_list_key} == "phpfpm" ]]; then
        PHP_V=$(php -r "echo PHP_VERSION;" | grep --only-matching --perl-regexp "7.\d+")
        # Set PHP_V
        php_set_version_on_config "${PHP_V}" "/etc/monit/conf.d/${services_list_key}"
      fi

      if [[ ! -x "${PHP_V}" && ${services_list_key} == "system" ]]; then
        # Set Hostname
        sed -i "s#HOSTNAME#${VPSNAME}#" "/etc/monit/conf.d/${services_list_key}"

        # Set SMTP vars
        sed -i "s#NOTIFICATION_EMAIL_SMTP_SERVER#${NOTIFICATION_EMAIL_SMTP_SERVER}#" "/etc/monit/conf.d/${services_list_key}"
        sed -i "s#NOTIFICATION_EMAIL_SMTP_PORT#${NOTIFICATION_EMAIL_SMTP_PORT}#" "/etc/monit/conf.d/${services_list_key}"

        # Run two times to cober all var appearance
        sed -i "s#NOTIFICATION_EMAIL_SMTP_USER#${NOTIFICATION_EMAIL_SMTP_USER}#" "/etc/monit/conf.d/${services_list_key}"
        sed -i "s#NOTIFICATION_EMAIL_SMTP_USER#${NOTIFICATION_EMAIL_SMTP_USER}#" "/etc/monit/conf.d/${services_list_key}"

        sed -i "s#NOTIFICATION_EMAIL_SMTP_UPASS#${NOTIFICATION_EMAIL_SMTP_UPASS}#" "/etc/monit/conf.d/${services_list_key}"
        sed -i "s#NOTIFICATION_EMAIL_MAILA#${NOTIFICATION_EMAIL_MAILA}#" "/etc/monit/conf.d/${services_list_key}"

      fi

    fi

  done

  log_event "info" "Restarting services ..."

  # Service restart
  ## TODO: need a refactor
  systemctl restart "php${PHP_V}-fpm"
  systemctl restart nginx.service
  service monit restart

  # Log
  display --indent 6 --text "- Restarting services" --result "DONE" --color GREEN

  log_event "info" "Monit configured" "false"
  display --indent 6 --text "- Monit configuration" --result "DONE" --color GREEN

}

################################################################################
# Monit installer menu
#
# Arguments:
#   none
#
# Outputs:
#   none
################################################################################

function monit_installer_menu() {

  # TODO: Add a menu to reconfigure or uninstall if monit is installed

  # Check if Monit is installed
  MONIT="$(command -v monit)"

  if [[ ! -x "${MONIT}" ]]; then

    monit_installer
    monit_configure

  else

    while true; do

      echo -e "${YELLOW}${ITALIC} > Monit is already installed. Do you want to reconfigure monit?${ENDCOLOR}"
      read -p "Please type 'y' or 'n'" yn

      case $yn in

      [Yy]*)

        log_subsection "Monit Configurator"

        monit_configure

        break
        ;;

      [Nn]*)

        log_event "warning" "Aborting monit configuration script ..." "false"

        break
        ;;

      *) echo " > Please answer yes or no." ;;

      esac

    done

    # Called twice to remove last messages
    clear_previous_lines "2"

  fi

}
