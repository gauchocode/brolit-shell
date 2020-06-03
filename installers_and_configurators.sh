#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc04
################################################################################

INSTALLER_OPTIONS="01 LEMP_INSTALLER 02 PHPMYADMIN_INSTALLER 03 NETDATA_INSTALLER 04 MONIT_INSTALLER 05 COCKPIT_INSTALLER 06 CERTBOT_INSTALLER 07 WPCLI_INSTALLER 08 JELLYFIN_INSTALLER"
INSTALLER_TYPE=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose an installer to Run" 20 78 10 $(for x in ${INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  if [[ ${INSTALLER_TYPE} == *"01"* ]]; then
    source "${SFOLDER}/lemp_setup.sh"

  fi
  if [[ ${INSTALLER_TYPE} == *"02"* ]]; then
    source "${SFOLDER}/utils/installers/phpmyadmin_installer.sh"

  fi
  if [[ ${INSTALLER_TYPE} == *"03"* ]]; then
    source "${SFOLDER}/utils/installers/netdata_installer.sh"

  fi
  if [[ ${INSTALLER_TYPE} == *"04"* ]]; then
    source "${SFOLDER}/utils/installers/monit_installer.sh"

  fi
  if [[ ${INSTALLER_TYPE} == *"05"* ]]; then
    source "${SFOLDER}/utils/installers/cockpit_installer.sh"

  fi
  if [[ ${INSTALLER_TYPE} == *"06"* ]]; then
    source "${SFOLDER}/utils/installers/certbot_installer.sh"

  fi
  if [[ ${INSTALLER_TYPE} == *"07"* ]]; then
    source "${SFOLDER}/utils/installers/wpcli_installer.sh"

  fi
  if [[ ${INSTALLER_TYPE} == *"08"* ]]; then
    source "${SFOLDER}/utils/installers/jellyfin_installer.sh"

  fi

fi

main_menu