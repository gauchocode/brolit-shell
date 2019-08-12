#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9.7
################################################################################

INSTALLER_OPTIONS="01 LEMP_INSTALLER 02 NETDATA_INSTALLER 03 MONIT_INSTALLER 04 COCKPIT_INSTALLER 05 CERTBOT_INSTALLER"
INSTALLER_TYPE=$(whiptail --title "BROOBE UTILS SCRIPT" --menu "Choose an installer to Run" 20 78 10 $(for x in ${INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  if [[ ${INSTALLER_TYPE} == *"01"* ]]; then
    source ${SFOLDER}/lemp_setup.sh

  fi
  if [[ ${INSTALLER_TYPE} == *"02"* ]]; then
    source ${SFOLDER}/utils/netdata_installer.sh

  fi
  if [[ ${INSTALLER_TYPE} == *"03"* ]]; then
    source ${SFOLDER}/utils/monit_installer.sh

  fi
  if [[ ${INSTALLER_TYPE} == *"04"* ]]; then
    source ${SFOLDER}/utils/cockpit_installer.sh

  fi
  if [[ ${INSTALLER_TYPE} == *"05"* ]]; then
    source ${SFOLDER}/utils/certbot_installer.sh

  fi
fi
