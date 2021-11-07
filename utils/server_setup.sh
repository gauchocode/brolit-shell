#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.71
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

    # Packages update
    package_update

    # Packages upgrade
    package_upgrade_all

    # Configuring server roles

    if [[ ${SERVER_ROLE_WEBSERVER} == "enabled" ]]; then

        if [[ ${PACKAGES_NGINX_CONFIG_STATUS} == "enabled" ]]; then

            # Nginx Installer
            nginx_installer "default"
            nginx_reconfigure

        fi

        if [[ ${PACKAGES_PHP_CONFIG_STATUS} == "enabled" ]]; then

            # PHP Installer
            php_installer "${PACKAGES_PHP_CONFIG_VERSION}"

            # Mail utils packages
            mail_utils_installer

            # Reconfigure
            php_reconfigure "${PACKAGES_PHP_CONFIG_VERSION}"

            # Opcache
            if [[ ${PACKAGES_PHP_CONFIG_OPCODE} == "enabled" ]]; then
                php_opcode_config "enable"
            fi

        fi

    fi

    if [[ ${SERVER_ROLE_DATABASE} == "enabled" ]]; then

        # MySQL Installer
        if [[ ${PACKAGES_MARIADB_CONFIG_STATUS} == "enabled" ]]; then
            mariadb_default_installer
            mysql_initial_config

        fi
        if [[ ${PACKAGES_MYSQL_CONFIG_STATUS} == "enabled" ]]; then
            mysql_default_installer
            mysql_initial_config

        fi

    fi

    # Check aditional packages to install
    if [[ ${PACKAGES_CERTBOT_CONFIG_STATUS} == "enabled" ]]; then
        certbot_installer
    fi

    if [[ ${PACKAGES_REDIS_CONFIG_STATUS} == "enabled" ]]; then

        redis_installer

        if [[ ${PACKAGES_PHP_CONFIG_STATUS} == "enabled" ]]; then
            php_redis_installer
        fi

    fi

    if [[ ${PACKAGES_MONIT_CONFIG_STATUS} == "enabled" ]]; then
        package_install_if_not "monit"
        monit_configure
    fi

    if [[ ${PACKAGES_NETDATA_CONFIG_STATUS} == "enabled" ]]; then
        netdata_installer
    fi

    if [[ ${PACKAGES_COCKPIT_CONFIG_STATUS} == "enabled" ]]; then
        cockpit_installer
    fi

    # Log
    log_event "info" "SERVER SETUP COMPLETED" "false"
    display --indent 6 --text "- Server setup" --result "DONE" --color GREEN
    display --indent 8 --text "Now you can run the script again." --tcolor YELLOW

}

### WORK IN PROGRESS

function server_setup_tasks_handler() {

    local subtask=$1

    log_subsection "Server Setup Manager"

    case ${subtask} in

    lemp-install)

        #brolit_configuration_load "${BROLIT_CONFIG_FILE}"

        server_setup "${DATABASE_ROOT_PSW}"

        exit
        ;;

        #lamp-install)
        #
        #  server_setup "${DATABASE_ROOT_PSW}"
        #
        # exit
        # ;;

    *)

        log_event "error" "INVALID SUBTASK: ${subtask}" "true"

        exit
        ;;

    esac

}
