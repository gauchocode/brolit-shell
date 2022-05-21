#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc5
#############################################################################
#
# Zabbix Installer
#
#   Refs:
#       https://www.zabbix.com/download?zabbix=6.0&os_distribution=ubuntu&os_version=20.04_focal&db=mysql&ws=nginx
#
################################################################################

################################################################################
# Zabbix installer
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function zabbix_installer() {

    local zabbix_bin
    local ubuntu_release_number

    zabbix_bin="$(package_is_installed "zabbix-frontend-php")"

    if [[ -n ${zabbix_bin} ]]; then

        log_event "info" "Zabbix is already installed" "false"

        return 0

    else

        log_subsection "Zabbix Installer"

        # TODO: check if mysql is installed, Zabbix needs a Mysql database

        # Get actual Ubuntu release number
        ubuntu_release_number="$(lsb_release -r | awk -F' ' '{print $2}')"

        # Install Zabbix Repository
        wget "https://repo.zabbix.com/zabbix/6.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.0-1+ubuntu${ubuntu_release_number}_all.deb"
        dpkg -i "zabbix-release_6.0-1+ubuntu${ubuntu_release_number}_all.deb"

        # Package update
        package_update

        # Install zabbix and dependencies
        package_install "zabbix-server-mysql"
        package_install "zabbix-frontend-php"
        package_install "zabbix-nginx-conf"
        package_install "zabbix-sql-scripts"
        package_install "zabbix-agent"

        # Create Mysql Database
        mysql_database_create "zabbix"
        mysql_user_create "zabbix" "zabbix" "localhost"
        mysql_user_grant_privileges "zabbix" "zabbix" "localhost"

        #On Zabbix server host import initial schema and data. You will be prompted to enter your newly created password.
        zcat /usr/share/doc/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -p zabbix

        # Add mysql database user password on Zabbix config file
        sed_output="$(sed -i "s/^DBPassword\=.*/DBPassword=\"zabbix\"/" "/etc/zabbix/zabbix_server.conf")"
        
        if [[ ${PACKAGES_NGINX_STATUS} == "enabled" ]]; then

            # Ref: https://github.com/cockpit-project/cockpit/wiki/Proxying-Cockpit-over-NGINX
            nginx_server_create "${PACKAGES_ZABBIX_CONFIG_SUBDOMAIN}" "zabbix" "single" "" ""

            # To let agent to connect to zabbix server
            # Add this line at the end of nginx.conf file
            echo 'stream {
                upstream zabbixagent {
                    server zabbix.broobe.net:10050;
                }
                server {
                    listen 10051;
                    proxy_pass zabbixagent;
                }
            }' >>"/etc/nginx/nginx.conf"

            if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

                # Extract root domain
                root_domain="$(domain_get_root "${PACKAGES_ZABBIX_CONFIG_SUBDOMAIN}")"

                cloudflare_set_record "${root_domain}" "${PACKAGES_ZABBIX_CONFIG_SUBDOMAIN}" "A" "false" "${SERVER_IP}"

                if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then
                    certbot_certificate_install "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${PACKAGES_ZABBIX_CONFIG_SUBDOMAIN}"
                fi

            fi

        fi

        # Firewall config
        firewall_allow "10050" # Zabbix agent port
        firewall_allow "10051" # Zabbix server port

        # Log
        log_event "info" "Zabbix installed" "false"
        display --indent 6 --text "Zabbix installation" --result "DONE" --color GREEN
        display --indent 8 --text "Please visit ${PACKAGES_ZABBIX_CONFIG_SUBDOMAIN} to finish the setup" --tcolor YELLOW

    fi

}

################################################################################
# Zabbix purge
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function zabbix_purge() {

    log_subsection "Zabbix Installer"

    # Log
    display --indent 6 --text "- Removing zabbix and dependencies"
    log_event "info" "Removing zabbix and dependencies ..." "false"

    # Remove zabbix and dependencies
    package_purge "zabbix-release"
    package_purge "zabbix-server-mysql"
    package_purge "zabbix-frontend-php"
    package_purge "zabbix-nginx-conf"
    package_purge "zabbix-proxy-mysql"
    package_purge "zabbix-sql-scripts"
    package_purge "zabbix-agent"
    package_purge "zabbix-agent2"

    # TODO: delete nginx and letsencrypt config and cloudflare entry

    # Log
    clear_previous_lines "1"

}
