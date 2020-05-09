#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc02
################################################################################

source "${SFOLDER}/libs/commons.sh"

################################################################################

create_nginx_server() {

    #$1 = ${PROJECT_DOMAIN}
    #$2 = ${SERVER_TYPE} (default, wordpress, symphony, phpmyadmin, zabbix, netdata, jellyfin)

    local PROJECT_DOMAIN=$1
    local SERVER_TYPE=$2

    # Create nginx config files for site
    echo -e "\nCreating nginx configuration file...\n" >>$LOG
    sudo cp "${SFOLDER}/confs/nginx/sites-available/${SERVER_TYPE}" "${WSERVER}/sites-available/${PROJECT_DOMAIN}"
    ln -s "${WSERVER}/sites-available/${PROJECT_DOMAIN}" "${WSERVER}/sites-enabled/${PROJECT_DOMAIN}"

    # Replace string to match domain name
    sudo sed -i "s#dominio.com#${PROJECT_DOMAIN}#" "${WSERVER}/sites-available/${PROJECT_DOMAIN}"
    # need to run twice
    sudo sed -i "s#dominio.com#${PROJECT_DOMAIN}#" "${WSERVER}/sites-available/${PROJECT_DOMAIN}"

    # TODO: ask wich version of php want to work with

    # Replace string to match PHP version
    sudo sed -i "s#PHP_V#${PHP_V}#" "${WSERVER}/sites-available/${PROJECT_DOMAIN}"

    # Reload webserver
    service nginx reload

}