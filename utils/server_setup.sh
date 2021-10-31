#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.70-beta
################################################################################
#
# Server Setup: Perform server setup actions.
#
################################################################################

################################################################################
# Server Setup
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function server_setup() {

    log_section "Server Setup"

    # Configuring packages
    timezone_configuration

    # Installing basic packages
    package_install_utils

    # Ask for server role. Options: webserver, database
    _brolit_configuration_load_server_roles

    # Configuring server roles

    if [[ ${SERVER_ROLE_WEBSERVER} == "enabled" ]]; then

        # Nginx Installer
        nginx_installer_menu

        # PHP Installer
        php_installer_menu

    fi

    if [[ ${SERVER_ROLE_DATABASE} == "enabled" ]]; then

        # MySQL Installer
        mysql_installer_menu

    fi

    # Install required packages
    package_check_required

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
