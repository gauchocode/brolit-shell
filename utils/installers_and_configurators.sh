#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc10
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi

################################################################################

installers_and_configurators() {

  INSTALLER_OPTIONS="01 PHP_INSTALLER 02 MYSQL_INSTALLER 03 NGINX_INSTALLER 04 PHPMYADMIN_INSTALLER 05 NETDATA_INSTALLER 06 MONIT_INSTALLER 07 COCKPIT_INSTALLER 08 CERTBOT_INSTALLER 09 WPCLI_INSTALLER"
  INSTALLER_TYPE=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "\nThis script has been designed to easily install and configure the following utilities and programs: \n" 20 78 10 $(for x in ${INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${INSTALLER_TYPE} == *"01"* ]]; then
      "${SFOLDER}/utils/installers/php_installer.sh"

    fi
    if [[ ${INSTALLER_TYPE} == *"02"* ]]; then
      "${SFOLDER}/utils/installers/mysql_installer.sh"

    fi
    if [[ ${INSTALLER_TYPE} == *"03"* ]]; then
      "${SFOLDER}/utils/installers/nginx_installer.sh"

    fi
    if [[ ${INSTALLER_TYPE} == *"04"* ]]; then
      "${SFOLDER}/utils/installers/phpmyadmin_installer.sh"

    fi
    if [[ ${INSTALLER_TYPE} == *"05"* ]]; then
      "${SFOLDER}/utils/installers/netdata_installer.sh"

    fi
    if [[ ${INSTALLER_TYPE} == *"06"* ]]; then
      "${SFOLDER}/utils/installers/monit_installer.sh"

    fi
    if [[ ${INSTALLER_TYPE} == *"07"* ]]; then
      "${SFOLDER}/utils/installers/cockpit_installer.sh"

    fi
    if [[ ${INSTALLER_TYPE} == *"08"* ]]; then
      "${SFOLDER}/utils/installers/certbot_installer.sh"

    fi
    if [[ ${INSTALLER_TYPE} == *"09"* ]]; then
      "${SFOLDER}/utils/installers/wpcli_installer.sh"

    fi

    installers_and_configurators

  fi

  main_menu

}

################################################################################

installers_and_configurators