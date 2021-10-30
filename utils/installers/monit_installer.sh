#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.70-beta
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

    MONIT_CONFIG_STATUS="$(json_write_field "${BROLIT_CONFIG_FILE}" "SUPPORT.monit[].status" "enabled")"
    
    # new global value ("enabled")
    export MONIT_CONFIG_STATUS

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

    MONIT_CONFIG_STATUS="$(json_write_field "${BROLIT_CONFIG_FILE}" "SUPPORT.monit[].status" "disabled")"
    
    # new global value ("enabled")
    export MONIT_CONFIG_STATUS

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

  if [[ ! -x "${PHP_V}" ]]; then
    PHP_V=$(php -r "echo PHP_VERSION;" | grep --only-matching --perl-regexp "7.\d+")

  fi

  # Configuring monit
  log_event "info" "Configuring monit ..." "false"

  # Using script template
  #cat "${SFOLDER}/config/monit/lemp-services" >/etc/monit/conf.d/lemp-services
  #cat "${SFOLDER}/config/monit/monitrc" >/etc/monit/monitrc
  display --indent 6 --text "- Copying monit config" --result "DONE" --color GREEN

  # Set Hostname
  sed -i "s#HOSTNAME#${VPSNAME}#" /etc/monit/conf.d/lemp-services

  # Set PHP_V
  php_set_version_on_config "${PHP_V}" "/etc/monit/conf.d/lemp-services"
  display --indent 6 --text "- Setting PHP version" --result "DONE" --color GREEN

  # Set SMTP vars
  sed -i "s#NOTIFICATION_EMAIL_SMTP_SERVER#${NOTIFICATION_EMAIL_SMTP_SERVER}#" /etc/monit/conf.d/lemp-services
  sed -i "s#NOTIFICATION_EMAIL_SMTP_PORT#${NOTIFICATION_EMAIL_SMTP_PORT}#" /etc/monit/conf.d/lemp-services

  # Run two times to cober all var appearance
  sed -i "s#NOTIFICATION_EMAIL_SMTP_USER#${NOTIFICATION_EMAIL_SMTP_USER}#" /etc/monit/conf.d/lemp-services
  sed -i "s#NOTIFICATION_EMAIL_SMTP_USER#${NOTIFICATION_EMAIL_SMTP_USER}#" /etc/monit/conf.d/lemp-services

  sed -i "s#NOTIFICATION_EMAIL_SMTP_USER_PASS#${NOTIFICATION_EMAIL_SMTP_USER_PASS}#" /etc/monit/conf.d/lemp-services
  sed -i "s#NOTIFICATION_EMAIL_MAILA#${NOTIFICATION_EMAIL_MAILA}#" /etc/monit/conf.d/lemp-services
  display --indent 6 --text "- Configuring SMTP" --result "DONE" --color GREEN

  log_event "info" "Restarting services ..."

  # Service restart
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
    clear_last_line
    clear_last_line

  fi

}
