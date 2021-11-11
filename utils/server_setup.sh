#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.71
################################################################################
#
# Server Setup: Perform server setup actions.
#
################################################################################

function server_prepare() {

    log_subsection "Preparing server"

    # Configuring packages
    timezone_configuration

    # Packages update
    package_update

    # Packages upgrade
    package_upgrade_all

    # Change global
    SERVER_PREPARED="true"

}

function server_app_setup() {

    local app_setup="${1}"

    case "${app_setup}" in

    "nginx")
        # Nginx Installer
        nginx_installer "default"
        nginx_reconfigure
        ;;

    "php")

        # PHP Installer
        php_installer "${PACKAGES_PHP_CONFIG_VERSION}"

        # Mail utils packages
        mail_utils_installer

        # Reconfigure
        php_reconfigure "${PACKAGES_PHP_CONFIG_VERSION}"

        ;;

    "mysql")
        mysql_default_installer
        mysql_initial_config

        ;;

    "mariadb")
        mariadb_default_installer
        mysql_initial_config

        ;;

    "redis")
        redis_installer
        if [[ ${PACKAGES_PHP_CONFIG_STATUS} == "enabled" ]]; then
            php_redis_installer
        fi

        ;;

    "monit")
        log_subsection "Monit Installer"
        package_install_if_not "monit"
        monit_configure
        ;;

    "certbot")
        certbot_installer
        ;;

    "netdata")
        netdata_installer
        ;;

    "cockpit")
        cockpit_installer
        ;;

    *)
        echo "Please answer yes or no."
        ;;

    esac

}
################################################################################
# Server Setup
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# TODO: maybe only use when runned by flags.

function server_setup() {

    log_section "Server Setup"

    server_prepare

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

        else

            log_event "error" "PHP not enabled" "false"
            display --indent 6 --text "PHP not enabled" --tcolor YELLOW

        fi

        log_break "true"

        display --indent 6 --text "- Server role 'webserver'" --result "ENABLED" --color WHITE

    else

        display --indent 6 --text "- Server role 'webserver'" --result "DISABLED" --color WHITE

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

        display --indent 6 --text "- Server role 'database'" --result "ENABLED" --color WHITE

    else

        display --indent 6 --text "- Server role 'database'" --result "DISABLED" --color WHITE

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
    #log_event "info" "SERVER SETUP COMPLETED" "false"
    #display --indent 6 --text "- Server setup" --result "DONE" --color GREEN
    #display --indent 8 --text "Now you can run the script again." --tcolor YELLOW

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
