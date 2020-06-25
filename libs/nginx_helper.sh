#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc05
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi

################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

create_nginx_server() {

    #$1 = ${PROJECT_DOMAIN}
    #$2 = ${SERVER_TYPE} (default, wordpress, symphony, phpmyadmin, zabbix, netdata, jellyfin)

    local domain=$1
    local server_type=$2

    # Create nginx config files for site
    echo -e "\nCreating nginx configuration file...\n" >>$LOG
    cp "${SFOLDER}/confs/nginx/sites-available/${server_type}" "${WSERVER}/sites-available/${domain}"
    ln -s "${WSERVER}/sites-available/${domain}" "${WSERVER}/sites-enabled/${domain}"

    # Replace string to match domain name
    #sed -i "s#domain.com#${domain}#" "${WSERVER}/sites-available/${domain}"
    # need to run twice
    #sed -i "s#domain.com#${domain}#" "${WSERVER}/sites-available/${domain}"

    # Search and Replace sed command
    sed -i "s/domain.com/${domain}/g" "${WSERVER}/sites-available/${domain}"

    # TODO: ask wich version of php want to work with

    # Replace string to match PHP version
    sed -i "s#PHP_V#${PHP_V}#" "${WSERVER}/sites-available/${domain}"

    # Reload webserver
    service nginx reload

}

delete_nginx_server() {

    #$1 = ${filename}

    local filename=$1

    if [ "${filename}" != "" ]; then

        # TODO: check if file exists
        rm "/etc/nginx/sites-available/${filename}"
        rm "/etc/nginx/sites-enabled/${filename}"

        # Reload webserver
        service nginx reload
    fi

}

change_phpv_nginx_server() {

    #$1 = ${project_domain}
    #$2 = ${new_php_v} optional

    local project_domain=$1
    local new_php_v=$2

    # TODO: if $new_php_v is not set, must ask wich PHP_V

    # Updating nginx server file
    echo -e "\nUpdating nginx ${project_domain} server file...\n" >>$LOG

    # TODO: ask wich version of php want to work with

    # Replace string to match PHP version
    sudo sed -i "s#PHP_V#${new_php_v}#" "${WSERVER}/sites-available/${project_domain}"

    # TODO: sed not only for generic server config, also an old config must be supported like:
    # sudo sed -i "s#7.0#${new_php_v}#" "${WSERVER}/sites-available/${project_domain}"
    # sudo sed -i "s#7.1#${new_php_v}#" "${WSERVER}/sites-available/${project_domain}"
    # sudo sed -i "s#7.2#${new_php_v}#" "${WSERVER}/sites-available/${project_domain}"
    # sudo sed -i "s#7.3#${new_php_v}#" "${WSERVER}/sites-available/${project_domain}"

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
        echo -e ${YELLOW}" > Directory ${nginx_globals} already exists ..."${ENDCOLOR}
        exit 1

    else
        echo "Creating directory ${nginx_globals} ..." >>$LOG
        echo -e ${CYAN}" > Creating directory ${nginx_globals} exists ..."${ENDCOLOR}
        mkdir "${nginx_globals}"

    fi

    cp "${SFOLDER}/confs/nginx/globals/security.conf /etc/nginx/globals/security.conf"
    cp "${SFOLDER}/confs/nginx/globals/wordpress_sec.conf" "/etc/nginx/globals/wordpress_sec.conf"
    cp "${SFOLDER}/confs/nginx/globals/wordpress_seo.conf" "/etc/nginx/globals/wordpress_seo.conf"

    # Replace string to match PHP version
    sudo sed -i "s#PHP_V#${PHP_V}#" "/etc/nginx/globals/wordpress_sec.conf"

    # Change ownership
    change_ownership "www-data" "www-data" "/etc/nginx/globals/"

    # Reload webserver
    service nginx reload

}