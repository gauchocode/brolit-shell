#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.64
################################################################################

function server_setup() {

    local server_roles

    log_section "Server Setup"

    # Configuring packages
    timezone_configuration

    # Installing basic packages
    packages_install_utils

    # Ask for server role
    # Options: webserver, database, webapp, cache, replica, other
    server_roles="$(settings_set_server_role)"

    # Transforming to array
    IFS=, read -ra server_roles_array <<< "$server_roles"

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

        webapp)
            log_event "info" "NEED IMPLEMENTATION" "true"
            ;;

        cache)
            log_event "info" "NEED IMPLEMENTATION" "true"
            ;;

        replica)
            log_event "info" "NEED IMPLEMENTATION" "true"
            ;;

        esac

    done

    # Install required packages
    packages_check_required

    # Script config
    script_configuration_wizard "initial"

    # Select aditional packages to install
    packages_install_selection

    # Log
    display --indent 6 --text "- Server setup" --result "DONE" --color GREEN
    log_event "info" "************* SERVER SETUP COMPLETED *************" "false"

}


### WORK IN PROGRESS

function server_setup_tasks_handler() {

  local subtask=$1

  log_subsection "WP-CLI Manager"

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
