#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc06
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi

################################################################################

INSTALLER_OPTIONS="01 PHP_INSTALLER 02 MYSQL_INSTALLER 03 NGINX_INSTALLER 04 PHPMYADMIN_INSTALLER 05 NETDATA_INSTALLER 06 MONIT_INSTALLER 07 COCKPIT_INSTALLER 08 CERTBOT_INSTALLER 09 WPCLI_INSTALLER"
#INSTALLER_OPTIONS="01 PHP_INSTALLER 02 MYSQL_INSTALLER 03 NGINX_INSTALLER 04 PHPMYADMIN_INSTALLER 05 NETDATA_INSTALLER 06 MONIT_INSTALLER 07 COCKPIT_INSTALLER 08 CERTBOT_INSTALLER 09 WPCLI_INSTALLER 10 JELLYFIN_INSTALLER"
INSTALLER_TYPE=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose an installer to Run" 20 78 10 $(for x in ${INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  if [[ ${INSTALLER_TYPE} == *"01"* ]]; then
    #source "${SFOLDER}/lemp_setup.sh"
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
#  if [[ ${INSTALLER_TYPE} == *"10"* ]]; then
#    "${SFOLDER}/utils/installers/jellyfin_installer.sh"
#
#  fi

fi

main_menu