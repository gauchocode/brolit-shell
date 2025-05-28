#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.10
################################################################################

# Installers directory path
installers_path="${BROLIT_MAIN_DIR}/utils/installers"

# Source all installers
installers="$(find "${installers_path}" -maxdepth 1 -name '*.sh' -type f -print)"
for f in ${installers}; do source "${f}"; done

################################################################################

function installers_and_configurators() {

  local installer_options
  local installer_options_title
  local installer_type

  log_section "Installers and Configurators"

  installer_options_title="INSTALLERS AND CONFIGURATORS"

  installer_options=(
    "01)" "PHP-FPM"
    "02)" "NGINX"
    "03)" "MONIT"
  )

  installer_type="$(whiptail --title "${installer_options_title}" --menu "\nPlease select the utility or programs you want to install or config: \n" 20 78 10 "${installer_options[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${installer_type} == *"01"* ]]; then
      php_installer_menu

    fi
    if [[ ${installer_type} == *"02"* ]]; then
      nginx_installer_menu

    fi
    if [[ ${installer_type} == *"03"* ]]; then
      monit_installer_menu

    fi

    prompt_return_or_finish
    installers_and_configurators

  fi

  menu_main_options

}
