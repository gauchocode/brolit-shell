#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.7
################################################################################
#
# Server Setup: Perform server setup actions.
#
################################################################################

function server_prepare() {

    log_subsection "Preparing server"

    # Configuring packages
    system_timezone_configuration

    # Unattended upgrades (disabled by default)
    #system_unnatended_upgrades

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
            nginx_installer
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
            # If PACKAGES_PHP_EXTENSIONS_MEMCACHED is enabled, install wp-cli
            if [[ ${PACKAGES_PHP_EXTENSIONS_MEMCACHED} == "enabled" ]]; then
                php_memcached_installer
            fi
            # If PACKAGES_PHP_EXTENSIONS_COMPOSER is enabled, install wp-cli
            if [[ ${PACKAGES_PHP_EXTENSIONS_COMPOSER} == "enabled" ]]; then
                php_composer_installer
            fi

        else
            php_composer_remove
            wpcli_uninstall
            php_purge_installation
        fi

        ;;

    "mysql")

        if [[ ${PACKAGES_MYSQL_STATUS} == "enabled" ]]; then
            mysql_default_installer
            mysql_initial_config
        else
            mysql_purge_installation
        fi

        ;;

    "mariadb")

        if [[ ${PACKAGES_MARIADB_STATUS} == "enabled" ]]; then
            mysql_mariadb_default_installer
            mysql_initial_config
        else
            package_purge "mariadb-server"
            package_purge "mariadb-server-core-*"
            package_purge "mariadb-common"
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
            redis_configure
            if [[ ${PACKAGES_PHP_STATUS} == "enabled" ]]; then
                php_redis_installer
            fi

        else
            redis_purge
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
            monit_installer
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

    "borg")

        if [[ ${PACKAGES_BORG_STATUS} == "enabled" ]]; then
            borg_installer
        else
            borg_purge
        fi

        ;;

    "docker")

        if [[ ${PACKAGES_DOCKER_STATUS} == "enabled" ]]; then
            # Check if docker package are installed
            package_is_installed "docker-ce"
            docker_installed="$?"
            if [[ ${docker_installed} -eq 1 ]]; then
                # Remove old docker packages
                docker_purge
                # Install docker
                docker_installer
                # Restart docker service
                service docker restart
            fi
        else
            # Purge docker packages
            docker_purge
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

    "portainer_agent")

        if [[ ${PACKAGES_PORTAINER_AGENT_STATUS} == "enabled" ]]; then
            portainer_agent_installer
            portainer_agent_configure
        else
            portainer_agent_purge
        fi

        ;;

    "promtail")

        if [[ ${PACKAGES_PROMTAIL_STATUS} == "enabled" ]]; then
            promtail_installer
        else
            promtail_purge
        fi

        ;;

    "loki")

        if [[ ${PACKAGES_LOKI_STATUS} == "enabled" ]]; then
            #loki_installer
            echo "Loki installer not implemented yet"
        else
            #loki_purge
            echo "Loki purge not implemented yet"
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

    "cockpit")

        if [[ ${PACKAGES_COCKPIT_STATUS} == "enabled" ]]; then
            cockpit_installer
        else
            cockpit_purge
        fi

        ;;

    "zabbix")

        if [[ ${PACKAGES_ZABBIX_STATUS} == "enabled" ]]; then
            zabbix_installer
        else
            zabbix_purge
        fi

        ;;

    *)
        log_event "warning" "App ${app_setup} is not supported yet" "true"
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

function server_setup() {

    log_section "Server Setup"

    server_prepare

    # Configuring server roles
    if [[ ${SERVER_ROLE_WEBSERVER} == "enabled" ]]; then

        if [[ ${PACKAGES_NGINX_STATUS} == "enabled" ]]; then

            # Nginx Installer
            nginx_installer
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
        redis_configure

        if [[ ${PACKAGES_PHP_STATUS} == "enabled" ]]; then
            php_redis_installer
        fi

    fi

    if [[ ${PACKAGES_MONIT_STATUS} == "enabled" ]]; then
        package_install_if_not "monit"
        monit_configure
    fi

    if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
        netdata_installer
    fi

    if [[ ${PACKAGES_COCKPIT_STATUS} == "enabled" ]]; then
        cockpit_installer
    fi

    # Log
    log_event "info" "Server setup completed" "false"
    #display --indent 6 --text "- Server setup" --result "DONE" --color GREEN
    #display --indent 8 --text "Now you can run the script again." --tcolor YELLOW

}
