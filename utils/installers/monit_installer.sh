#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.7
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

configure_monit(){

  if [ ! -x "${PHP_V}" ]; then
    PHP_V=$(php -r "echo PHP_VERSION;" | grep --only-matching --perl-regexp "7.\d+")
  
  fi

  # Configuring monit
  log_event "info" "Configuring monit ..." "false"

  # Using script template
  cat "${SFOLDER}/config/monit/lemp-services" > /etc/monit/conf.d/lemp-services
  cat "${SFOLDER}/config/monit/monitrc" > /etc/monit/monitrc
  display --indent 2 --text "- Copying monit config" --result "DONE" --color GREEN

  sed -i "s#HOSTNAME#${VPSNAME}#" /etc/monit/conf.d/lemp-services

  # Run five times to cober all var appearance
  sed -i "s#PHP_V#${PHP_V}#" /etc/monit/conf.d/lemp-services
  sed -i "s#PHP_V#${PHP_V}#" /etc/monit/conf.d/lemp-services
  sed -i "s#PHP_V#${PHP_V}#" /etc/monit/conf.d/lemp-services
  sed -i "s#PHP_V#${PHP_V}#" /etc/monit/conf.d/lemp-services
  sed -i "s#PHP_V#${PHP_V}#" /etc/monit/conf.d/lemp-services
  display --indent 2 --text "- Setting PHP version" --result "DONE" --color GREEN

  sed -i "s#SMTP_SERVER#${SMTP_SERVER}#" /etc/monit/conf.d/lemp-services
  sed -i "s#SMTP_PORT#${SMTP_PORT}#" /etc/monit/conf.d/lemp-services
    
  # Run two times to cober all var appearance
  sed -i "s#SMTP_U#${SMTP_U}#" /etc/monit/conf.d/lemp-services
  sed -i "s#SMTP_U#${SMTP_U}#" /etc/monit/conf.d/lemp-services

  sed -i "s#SMTP_P#${SMTP_P}#" /etc/monit/conf.d/lemp-services
  sed -i "s#MAILA#${MAILA}#" /etc/monit/conf.d/lemp-services
  display --indent 2 --text "- Configuring SMTP" --result "DONE" --color GREEN

  log_event "info" "Restarting services ..." "false"
  systemctl restart "php${PHP_V}-fpm"
  systemctl restart nginx.service
  service monit restart
  display --indent 2 --text "- Restarting services" --result "DONE" --color GREEN

  log_event "success" "Monit configured" "false"
  display --indent 2 --text "- Monit configuration" --result "DONE" --color GREEN

}

################################################################################

### Checking if Monit is installed
MONIT="$(which monit)"

if [ ! -x "${MONIT}" ]; then

  while true; do

      echo -e "${YELLOW}${ITALIC} > Do you really want to install monit?${ENDCOLOR}"
      read -p "Please type 'y' or 'n'" yn

      case $yn in
          [Yy]* )

            log_section "Monit Installer"

            log_event "info" "Updating packages before installation ..." "false"
            apt-get --yes update -qq > /dev/null

            # Installing packages
            log_event "info" "Installing monit ..." "false"
            apt-get --yes install monit -qq > /dev/null

            configure_monit

            break;;

          [Nn]* )

            log_event "warning" "Aborting monit installation script ..." "false"

            break;;

          * ) echo " > Please answer yes or no.";;

      esac
  done

else
  while true; do

      echo -e "${YELLOW}${ITALIC} > Monit is already installed. Do you want to reconfigure monit?${ENDCOLOR}"
      read -p "Please type 'y' or 'n'" yn

      case $yn in
          [Yy]* )

            log_section "Monit Configurator"

            configure_monit

            break;;

          [Nn]* )

            log_event "warning" "Aborting monit configuration script ..." "false"

            break;;

          * ) echo " > Please answer yes or no.";;

      esac

  done

  # Called twice to remove last messages
  clear_last_line
  clear_last_line

fi
