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

change_phpv_nginx_server() {

    #$1 = ${PROJECT_DOMAIN}
    #$2 = ${NEW_PHP_V}

    local PROJECT_DOMAIN=$1
    local NEW_PHP_V=$2

    # Updating nginx server file
    echo -e "\nUpdating nginx ${PROJECT_DOMAIN} server file...\n" >>$LOG

    # TODO: ask wich version of php want to work with

    # Replace string to match PHP version
    sudo sed -i "s#PHP_V#${NEW_PHP_V}#" "${WSERVER}/sites-available/${PROJECT_DOMAIN}"

    # Reload webserver
    service nginx reload

}

reconfigure_nginx() {

    # nginx.conf broobe standard configuration
    cat "${SFOLDER}/confs/nginx/nginx.conf" >"/etc/nginx/nginx.conf"

    # Reload webserver
    service nginx reload

}

reconfigure_nginx() {

    # nginx.conf broobe standard configuration
    cat "${SFOLDER}/confs/nginx/nginx.conf" >"/etc/nginx/nginx.conf"

    # Reload webserver
    service nginx reload

}

create_nginx_globals_confs() {

    # nginx.conf broobe standard configuration
    nginx_globals="/etc/nginx/globals/"
    if [ -d "${nginx_globals}" ]; then
        echo "Directory ${nginx_globals} already exists ..." >>$LOG
        echo -e ${CYAN}" > Directory ${nginx_globals} already exists ..."${ENDCOLOR}
        exit 1

    else
        mkdir ${nginx_globals}

    fi

    cp "${SFOLDER}/confs/nginx/globals/security.conf /etc/nginx/globals/security.conf"
    cp "${SFOLDER}/confs/nginx/globals/wordpress_sec.conf" "/etc/nginx/globals/wordpress_sec.conf"
    cp "${SFOLDER}/confs/nginx/globals/wordpress_seo.conf" "/etc/nginx/globals/wordpress_seo.conf"

    # Replace string to match PHP version
    sudo sed -i "s#PHP_V#${PHP_V}#" "/etc/nginx/globals/wordpress_sec.conf"

    # Change ownership
    chown -R www-data:www-data "/etc/nginx/globals/"

    # Reload webserver
    service nginx reload

}