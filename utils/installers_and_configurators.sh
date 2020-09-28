#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.3
################################################################################

installers_and_configurators() {

  local installer_options
  local installer_type

  installer_options=("01)" "PHP-FPM" "02)" "MYSQL/MARIADB" "03)" "NGINX" "04)" "PHPMYADMIN" "05)" "NETDATA" "06)" "MONIT" "07)" "COCKPIT" "08)" "CERTBOT" "09)" "WP-CLI")
  installer_type=$(whiptail --title "INSTALLERS AND CONFIGURATORS" --menu "\nPlease select the utility or programs you want to install or config: \n" 20 78 10 "${installer_options[@]}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${installer_type} == *"01"* ]]; then
      "${SFOLDER}/utils/installers/php_installer.sh"

    fi
    if [[ ${installer_type} == *"02"* ]]; then
      "${SFOLDER}/utils/installers/mysql_installer.sh"

    fi
    if [[ ${installer_type} == *"03"* ]]; then
      "${SFOLDER}/utils/installers/nginx_installer.sh"

    fi
    if [[ ${installer_type} == *"04"* ]]; then
      "${SFOLDER}/utils/installers/phpmyadmin_installer.sh"

    fi
    if [[ ${installer_type} == *"05"* ]]; then
      "${SFOLDER}/utils/installers/netdata_installer.sh"

    fi
    if [[ ${installer_type} == *"06"* ]]; then
      "${SFOLDER}/utils/installers/monit_installer.sh"

    fi
    if [[ ${installer_type} == *"07"* ]]; then
      "${SFOLDER}/utils/installers/cockpit_installer.sh"

    fi
    if [[ ${installer_type} == *"08"* ]]; then
      "${SFOLDER}/utils/installers/certbot_installer.sh"

    fi
    if [[ ${installer_type} == *"09"* ]]; then
      "${SFOLDER}/utils/installers/wpcli_installer.sh"

    fi

    installers_and_configurators

  fi

  main_menu

}

################################################################################

installers_and_configurators