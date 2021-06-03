#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.29
################################################################################

function lemp_setup() {

    log_section "LEMP setup"

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

    # Script config
    script_configuration_wizard "initial"

    selected_package_installation

    log_event "info" "************* LEMP SETUP COMPLETED *************" "true"

}
