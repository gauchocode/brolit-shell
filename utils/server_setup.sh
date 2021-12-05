#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.6
################################################################################
#
# Server Setup: Perform server setup actions.
#
################################################################################

function server_prepare() {

    log_subsection "Preparing server"

    # Configuring packages
    system_timezone_configuration

    # Unattended upgrades
    system_enable_unnatended_upgrades

    # Packages update
    package_update

    # Packages upgrade
    package_upgrade_all

    # Change global
    SERVER_PREPARED="true"

    export SERVER_PREPARED

}

function server_app_setup() {

    local app_setup="${1}"

    case "${app_setup}" in

    "nginx")

        if [[ ${PACKAGES_NGINX_CONFIG_STATUS} == "enabled" ]]; then
            # Nginx Installer
            nginx_installer "${PACKAGES_NGINX_CONFIG_VERSION}"
            # Reconfigure
            nginx_reconfigure
            nginx_new_default_server
            nginx_create_globals_config
            #nginx_delete_default_directory
        else
            package_purge "nginx"
        fi

        ;;

    "php")

        if [[ ${PACKAGES_PHP_CONFIG_STATUS} == "enabled" ]]; then
            # PHP Installer
            php_installer "${PACKAGES_PHP_CONFIG_VERSION}"
            # Mail utils packages
            mail_utils_installer
            # Redis
            #php_redis_installer #TODO: only if redis is enabled
            # Reconfigure
            php_reconfigure "${PACKAGES_PHP_CONFIG_VERSION}"
        else
            package_purge "php"
        fi

        ;;

    "mysql")

        if [[ ${PACKAGES_MYSQL_CONFIG_STATUS} == "enabled" ]]; then
            mysql_default_installer
            mysql_initial_config
        else
            package_purge "mariadb"
        fi

        ;;

    "mariadb")

        if [[ ${PACKAGES_MARIADB_CONFIG_STATUS} == "enabled" ]]; then
            mariadb_default_installer
            mysql_initial_config
        else
            package_purge "mariadb"
        fi

        ;;

    "redis")

        if [[ ${PACKAGES_REDIS_CONFIG_STATUS} == "enabled" ]]; then

            redis_installer
            if [[ ${PACKAGES_PHP_CONFIG_STATUS} == "enabled" ]]; then
                php_redis_installer
            fi
            
        else
            package_purge "redis"
        fi

        ;;

    "nodejs")

        if [[ ${PACKAGES_NODEJS_CONFIG_STATUS} == "enabled" ]]; then
            nodejs_installer ""
        else
            nodejs_purge
        fi

        ;;

    "monit")

        if [[ ${PACKAGES_MONIT_CONFIG_STATUS} == "enabled" ]]; then
            log_subsection "Monit Installer"
            package_install_if_not "monit"
            monit_configure
        else
            monit_purge
        fi

        ;;

    "certbot")

        if [[ ${PACKAGES_CERTBOT_CONFIG_STATUS} == "enabled" ]]; then
            certbot_installer
        else
            certbot_purge
        fi

        ;;

    "netdata")

        if [[ ${PACKAGES_NETDATA_CONFIG_STATUS} == "enabled" ]]; then
            netdata_installer
        else
            netdata_uninstaller
        fi

        ;;

    "grafana")

        if [[ ${PACKAGES_GRAFANA_CONFIG_STATUS} == "enabled" ]]; then
            grafana_installer
        else
            grafana_purge
        fi

        ;;

    "cockpit")

        if [[ ${PACKAGES_COCKPIT_CONFIG_STATUS} == "enabled" ]]; then
            cockpit_installer
        else
            package_purge "cockpit"
        fi

        ;;

    "teleport")

        if [[ ${PACKAGES_TELEPORT_CONFIG_STATUS} == "enabled" ]]; then

            teleport_installer

            if [[ "${PACKAGES_TELEPORT_CONFIG_IS_SERVER}" == "true" ]]; then
                teleport_configure "server"
            else
                teleport_configure "client"
            fi

        else
            package_purge "teleport"
        fi

        ;;

    *)
        echo "App not supported yet."
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
