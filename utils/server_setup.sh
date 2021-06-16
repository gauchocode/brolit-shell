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

    for server_role in ${server_roles}; do

        case ${server_role} in

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
            echo "TODO"
            ;;

        cache)
            echo "TODO"
            ;;

        replica)
            echo "TODO"
            ;;

        esac

    done

    # Script config
    script_configuration_wizard "initial"

    # Select aditional packages to install
    selected_package_installation

    # Log
    display --indent 6 --text "- Server setup" --result "DONE" --color GREEN
    log_event "info" "************* SERVER SETUP COMPLETED *************" "false"

}
