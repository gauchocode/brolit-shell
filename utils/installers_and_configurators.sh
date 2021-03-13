#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.20
################################################################################

# Installers directory path
installers_path="${SFOLDER}/utils/installers"

# Source all installers
installers="$(find "${installers_path}" -maxdepth 1 -name '*.sh' -type f -print)"
for f in ${installers}; do source "${f}"; done

################################################################################

function installers_and_configurators() {

  local installer_options
  local installer_type

  installer_options=(
    "01)" "PHP-FPM" 
    "02)" "MYSQL/MARIADB" 
    "03)" "NGINX" 
    "04)" "PHPMYADMIN" 
    "05)" "NETDATA" 
    "06)" "MONIT" 
    "07)" "COCKPIT" 
    "08)" "CERTBOT" 
    "09)" "WP-CLI" 
    )
  
  installer_type=$(whiptail --title "INSTALLERS AND CONFIGURATORS" --menu "\nPlease select the utility or programs you want to install or config: \n" 20 78 10 "${installer_options[@]}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    log_section "Installers and Configurators"

    if [[ ${installer_type} == *"01"* ]]; then
      php_installer_menu

    fi
    if [[ ${installer_type} == *"02"* ]]; then
      mysql_installer_menu

    fi
    if [[ ${installer_type} == *"03"* ]]; then
      nginx_installer_menu

    fi
    if [[ ${installer_type} == *"04"* ]]; then
      phpmyadmin_installer

    fi
    if [[ ${installer_type} == *"05"* ]]; then
      netdata_installer_menu

    fi
    if [[ ${installer_type} == *"06"* ]]; then
      monit_installer_menu

    fi
    if [[ ${installer_type} == *"07"* ]]; then
      cockpit_installer

    fi
    if [[ ${installer_type} == *"08"* ]]; then
      certbot_installer

    fi
    if [[ ${installer_type} == *"09"* ]]; then
      wpcli_installer_menu

    fi

    prompt_return_or_finish
    installers_and_configurators

  fi

  menu_main_options

}
