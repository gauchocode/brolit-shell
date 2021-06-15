#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.38
################################################################################

function server_setup() {

    log_section "Server Setup"

    # Configuring packages
    timezone_configuration

    # Installing basic packages
    basic_packages_installation

    # Ask for server role
    # Options: webserver, database, webapp, cache, replica, other
    server_roles="$(settings_set_server_role)"

    # TODO: loop server_roles
    case ${server_roles} in

    webserver)
        # Nginx Installer
        nginx_installer_menu
        # PHP Installer
        php_installer_menu
        ;;

    database)
        # MySQL Installer
        mysql_installer_menu
        ;;

    webapp)
        echo "ERR"
        ;;

    cache)
        echo "ERR"
        ;;

    replica)
        echo "ERR"
        ;;

    esac

    # Script config
    script_configuration_wizard "initial"

    selected_package_installation

    log_event "info" "************* SERVER SETUP COMPLETED *************" "true"

}
