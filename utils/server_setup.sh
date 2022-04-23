#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc3
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
    system_unnatended_upgrades

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

        if [[ ${PACKAGES_NGINX_STATUS} == "enabled" ]]; then
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

        if [[ ${PACKAGES_PHP_STATUS} == "enabled" ]]; then
            # PHP Installer
            php_installer "${PACKAGES_PHP_VERSION}"
            # Mail utils packages
            mail_utils_installer
            # Reconfigure
            php_reconfigure "${PACKAGES_PHP_VERSION}"

            # If PACKAGES_PHP_EXTENSIONS_WPCLI is enabled, install wp-cli
            if [[ ${PACKAGES_PHP_EXTENSIONS_WPCLI} == "enabled" ]]; then
                wpcli_install_if_not_installed
            fi
            # If PACKAGES_PHP_EXTENSIONS_REDIS is enabled, install wp-cli
            if [[ ${PACKAGES_PHP_EXTENSIONS_REDIS} == "enabled" ]]; then
                php_redis_installer
            fi
            # If PACKAGES_PHP_EXTENSIONS_COMPOSER is enabled, install wp-cli
            if [[ ${PACKAGES_PHP_EXTENSIONS_COMPOSER} == "enabled" ]]; then
                php_composer_installer
            fi

        else
            php_composer_remove
            wpcli_uninstall
            package_purge "php"
        fi

        ;;

    "mysql")

        if [[ ${PACKAGES_MYSQL_STATUS} == "enabled" ]]; then
            mysql_default_installer
            mysql_initial_config
        else
            package_purge "mysql-server"
        fi

        ;;

    "mariadb")

        if [[ ${PACKAGES_MARIADB_STATUS} == "enabled" ]]; then
            mysql_mariadb_default_installer
            mysql_initial_config
        else
            package_purge "mariadb-server"
        fi

        ;;

    "postgres")

        if [[ ${PACKAGES_POSTGRES_STATUS} == "enabled" ]]; then
            postgres_default_installer
        else
            package_purge "postgresql"
        fi

        ;;

    "redis")

        if [[ ${PACKAGES_REDIS_STATUS} == "enabled" ]]; then

            redis_installer
            if [[ ${PACKAGES_PHP_STATUS} == "enabled" ]]; then
                php_redis_installer
            fi

        else
            package_purge "redis"
            package_purge "redis-server"
            package_purge "redis-tools"
        fi

        ;;

    "nodejs")

        if [[ ${PACKAGES_NODEJS_STATUS} == "enabled" ]]; then
            nodejs_installer ""
        else
            nodejs_purge
        fi

        ;;

    "monit")

        if [[ ${PACKAGES_MONIT_STATUS} == "enabled" ]]; then
            log_subsection "Monit Installer"
            package_install_if_not "monit"
            monit_configure
        else
            monit_purge
        fi

        ;;

    "certbot")

        if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then
            certbot_installer
        else
            certbot_purge
        fi

        ;;

    "netdata")

        if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
            netdata_installer
            netdata_configuration
        else
            netdata_uninstaller
        fi

        ;;

    "grafana")

        if [[ ${PACKAGES_GRAFANA_STATUS} == "enabled" ]]; then
            grafana_installer
        else
            grafana_purge
        fi

        ;;

    "cockpit")

        if [[ ${PACKAGES_COCKPIT_STATUS} == "enabled" ]]; then
            cockpit_installer
        else
            package_purge "cockpit"
        fi

        ;;

    "portainer")

        if [[ ${PACKAGES_PORTAINER_STATUS} == "enabled" ]]; then
            portainer_installer
            portainer_configure
        else
            portainer_purge
        fi

        ;;

    "teleport")

        if [[ ${PACKAGES_TELEPORT_STATUS} == "enabled" ]]; then

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

        if [[ ${PACKAGES_NGINX_STATUS} == "enabled" ]]; then

            # Nginx Installer
            nginx_installer "default"
            nginx_reconfigure

        fi

        if [[ ${PACKAGES_PHP_STATUS} == "enabled" ]]; then

            # PHP Installer
            php_installer "${PACKAGES_PHP_VERSION}"

            # Mail utils packages
            mail_utils_installer

            # Reconfigure
            php_reconfigure "${PACKAGES_PHP_VERSION}"

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
        if [[ ${PACKAGES_MARIADB_STATUS} == "enabled" ]]; then
            mysql_mariadb_default_installer
            mysql_initial_config

        fi

        if [[ ${PACKAGES_MYSQL_STATUS} == "enabled" ]]; then
            mysql_default_installer
            mysql_initial_config

        fi

        display --indent 6 --text "- Server role 'database'" --result "ENABLED" --color WHITE

    else

        display --indent 6 --text "- Server role 'database'" --result "DISABLED" --color WHITE

    fi

    # Check aditional packages to install
    if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then
        certbot_installer
    fi

    if [[ ${PACKAGES_REDIS_STATUS} == "enabled" ]]; then

        redis_installer

        if [[ ${PACKAGES_PHP_STATUS} == "enabled" ]]; then
            php_redis_installer
        fi

    fi

    if [[ ${PACKAGES_MONIT_STATUS} == "enabled" ]]; then
        package_install_if_not "monit"
        monit_configure
    fi

    if [[ ${PACKAGES_NETDATA_CONFIG_STATUS} == "enabled" ]]; then
        netdata_installer
    fi

    if [[ ${PACKAGES_COCKPIT_STATUS} == "enabled" ]]; then
        cockpit_installer
    fi

    # Log
    #log_event "info" "SERVER SETUP COMPLETED" "false"
    #display --indent 6 --text "- Server setup" --result "DONE" --color GREEN
    #display --indent 8 --text "Now you can run the script again." --tcolor YELLOW

}
