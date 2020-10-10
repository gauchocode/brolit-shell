#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.5
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/packages_helper.sh
source "${SFOLDER}/libs/packages_helper.sh"

################################################################################

log_section "LEMP SETUP"

checking_scripts_permissions

# Configuring packages
timezone_configuration

# Installing basic packages
basic_packages_installation

# MySQL Installer
"${SFOLDER}/utils/installers/mysql_installer.sh"

# Nginx Installer
"${SFOLDER}/utils/installers/nginx_installer.sh"

# PHP Installer
"${SFOLDER}/utils/installers/php_installer.sh"

log_event "success" "************* LEMP SETUP COMPLETED *************" "true"

script_configuration_wizard "initial"

selected_package_installation