#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.13
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/packages_helper.sh
source "${SFOLDER}/libs/packages_helper.sh"
# shellcheck source=${SFOLDER}/utils/installers/php_installer.sh
source "${SFOLDER}/utils/installers/php_installer.sh"
# shellcheck source=${SFOLDER}/utils/installers/mysql_installer.sh
source "${SFOLDER}/utils/installers/mysql_installer.sh"

################################################################################

log_section "LEMP setup"

check_scripts_permissions

# Configuring packages
timezone_configuration

# Installing basic packages
basic_packages_installation

# MySQL Installer
mysql_installer_menu

# Nginx Installer
nginx_installer_menu

# PHP Installer
php_installer_menu

script_configuration_wizard "initial"

selected_package_installation

log_event "success" "************* LEMP SETUP COMPLETED *************" "true"