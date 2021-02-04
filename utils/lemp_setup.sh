#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.13
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/packages_helper.sh
source "${SFOLDER}/libs/packages_helper.sh"

################################################################################

log_section "LEMP SETUP"

check_scripts_permissions

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

script_configuration_wizard "initial"

selected_package_installation

log_event "success" "************* LEMP SETUP COMPLETED *************" "true"