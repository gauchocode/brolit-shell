#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.70-beta
################################################################################

function server_setup() {

    local server_roles

    log_section "Server Setup"

    # Configuring packages
    timezone_configuration

    # Installing basic packages
    package_install_utils

    # Ask for server role
    # Options: webserver, database, webapp, cache, replica, other
    server_roles="$(settings_set_server_role)"

    # String to array
    IFS=',' read -r -a server_roles_array <<< "$server_roles"

    for server_role in "${server_roles_array[@]}"; do

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

        # TODO
        webapp)
            log_event "info" "NEED IMPLEMENTATION" "true"
            ;;

        # TODO
        cache)
            log_event "info" "NEED IMPLEMENTATION" "true"
            ;;

        # TODO
        replica)
            log_event "info" "NEED IMPLEMENTATION" "true"
            ;;

        esac

    done

    # Install required packages
    package_check_required

    # Script config
    script_configuration_wizard "initial"

    # Select aditional packages to install
    package_install_selection

    # Log
    display --indent 6 --text "- Server setup" --result "DONE" --color GREEN
    log_event "info" "************* SERVER SETUP COMPLETED *************" "false"

}


### WORK IN PROGRESS

function server_setup_tasks_handler() {

  local subtask=$1

  log_subsection "Server Setup Manager"

  case ${subtask} in

  lemp-install)

    server_setup "${DATABASE_ENGINE}" "${DATABASE_ROOT_PSW}" "${TIMEZONE}"

    exit
    ;;

    #lamp-install)
    #
    #  server_setup "${DATABASE_ENGINE}" "${DATABASE_ROOT_PSW}" "${TIMEZONE}"
    #
    # exit
    # ;;

  *)

    log_event "error" "INVALID SUBTASK: ${subtask}" "true"

    exit
    ;;

  esac

}
