#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
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

    #$1 = ${project_domain}
    #$2 = ${server_type} (default, wordpress, symphony, phpmyadmin, zabbix, netdata, jellyfin)

    local domain=$1
    local server_type=$2

    local result debug

    # Create nginx config files for site
    log_event "info" "Creating nginx configuration file ..." "true"

    cp "${SFOLDER}/config/nginx/sites-available/${server_type}" "${WSERVER}/sites-available/${domain}"
    ln -s "${WSERVER}/sites-available/${domain}" "${WSERVER}/sites-enabled/${domain}"

    # Search and Replace sed command
    sed -i "s/domain.com/${domain}/g" "${WSERVER}/sites-available/${domain}"

    # TODO: ask wich version of php want to work with

    # Replace string to match PHP version
    sed -i "s#PHP_V#${PHP_V}#" "${WSERVER}/sites-available/${domain}"

    #Test the validity of the nginx configuration
    result=$(nginx -t 2>&1 | grep -w "test" | cut -d"." -f2 | cut -d" " -f4)

    if [ "${result}" = "successful" ];then
        
        # Reload webserver
        service nginx reload

        log_event "success" "nginx configuration created" "true"

    else
        debug=$(nginx -t 2>&1)
        log_event "error" "nginx configuration fail: $debug" "true"
    fi

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

change_status_nginx_server() {

    # File test operators
    # -d FILE - True if the FILE exists and is a directory.
    # -f FILE - True if the FILE exists and is a regular file (not a directory or device).
    # -h FILE - True if the FILE exists and is a symbolic link.

    #$1 = ${project_domain}
    #$2 = ${project_status} (online,offline)

    local project_domain=$1
    local project_status=$2

    local result debug

    case ${project_status} in

    online)
        log_event "info" "New project status: ${project_status}" "true"
        if [ -f "${WSERVER}/sites-available/${project_domain}" ]; then
            ln -s "${WSERVER}/sites-available/${project_domain}" "${WSERVER}/sites-enabled/${project_domain}"
            log_event "info" "Project config added to ${WSERVER}/sites-enabled/${project_domain}" "true"
        else
            log_event "error" "${WSERVER}/sites-available/${project_domain} does not exist" "true"
        fi
        ;;

      offline)
        log_event "info" "New project status: ${project_status}" "true"
        if [ -h "${WSERVER}/sites-enabled/${project_domain}" ]; then
            rm "${WSERVER}/sites-enabled/${project_domain}"
            log_event "info" "Project config deleted from ${WSERVER}/sites-enabled/${project_domain}" "true"
        else
            log_event "error" "${WSERVER}/sites-enabled/${project_domain} does not exist" "true"
        fi
        ;;

      *)
        log_event "info" "New project status: Unknown" "true"
        return 1
        ;;
    esac

    #Test the validity of the nginx configuration
    result=$(nginx -t 2>&1 | grep -w "test" | cut -d"." -f2 | cut -d" " -f4)

    if [ "${result}" = "successful" ];then
        
        # Reload webserver
        service nginx reload

        log_event "success" "Project configuration status changed to ${project_status} for ${project_domain}" "true"

    else
        debug=$(nginx -t 2>&1)
        log_event "error" "Problem changing project status for ${project_domain}: ${debug}" "true"
    fi

}

change_phpv_nginx_server() {

    #$1 = ${project_domain}
    #$2 = ${new_php_v} optional

    local project_domain=$1
    local new_php_v=$2

    # TODO: if $new_php_v is not set, must ask wich PHP_V

    if [[ ${new_php_v} = "" ]]; then
        new_php_v=$(check_default_php_version)

    fi

    # Updating nginx server file
    log_event "info" "Updating nginx ${project_domain} server file ..." "true"

    # TODO: ask wich version of php want to work with

    # Replace string to match PHP version
    current_php_v_string=$(cat ${WSERVER}/sites-available/${project_domain} | grep fastcgi_pass | cut -d '/' -f 4 | cut -d '-' -f 1)
    current_php_v=${current_php_v_string#"php"}
    
    sed -i "s#${current_php_v}#${new_php_v}#" "${WSERVER}/sites-available/${project_domain}"

    log_event "info" "PHP version for ${project_domain} changed from ${current_php_v} to ${new_php_v}" "true"

    #Test the validity of the nginx configuration
    result=$(nginx -t 2>&1 | grep -w "test" | cut -d"." -f2 | cut -d" " -f4)

    if [ "${result}" = "successful" ];then

        # Reload webserver
        service nginx reload

        log_event "success" "Nginx configuration changed!" "true"

    else
        debug=$(nginx -t 2>&1)
        whiptail_event "WARNING" "Something went wrong changing Nginx configuration. Please check manually nginx config files."
        log_event "error" "Problem changing Nginx configuration. Debug: ${debug}" "true"

    fi

}

reconfigure_nginx() {

    # nginx.conf broobe standard configuration
    cat "${SFOLDER}/config/nginx/nginx.conf" >"/etc/nginx/nginx.conf"

    # Reload webserver
    service nginx reload

}

create_nginx_globals_config() {

    # nginx.conf broobe standard configuration
    nginx_globals="/etc/nginx/globals/"

    if [ -d "${nginx_globals}" ]; then
        log_event "warning" "Directory ${nginx_globals} already exists ..." "true"
        return 1

    else
        log_event "info" "Creating directory ${nginx_globals} exists ..." "true"
        mkdir "${nginx_globals}"

    fi

    cp "${SFOLDER}/config/nginx/globals/security.conf /etc/nginx/globals/security.conf"
    cp "${SFOLDER}/config/nginx/globals/wordpress_sec.conf" "/etc/nginx/globals/wordpress_sec.conf"
    cp "${SFOLDER}/config/nginx/globals/wordpress_seo.conf" "/etc/nginx/globals/wordpress_seo.conf"

    # Replace string to match PHP version
    sudo sed -i "s#PHP_V#${PHP_V}#" "/etc/nginx/globals/wordpress_sec.conf"

    # Change ownership
    change_ownership "www-data" "www-data" "/etc/nginx/globals/"

    #Test the validity of the nginx configuration
    result=$(nginx -t 2>&1 | grep -w "test" | cut -d"." -f2 | cut -d" " -f4)

    if [ "${result}" = "successful" ];then
        
        # Reload webserver
        service nginx reload

        log_event "success" "Nginx configuration changed!" "true"

    else
        debug=$(nginx -t 2>&1)
        whiptail_event "WARNING" "Something went wrong changing Nginx configuration. Please check manually nginx config files."
        log_event "error" "Problem changing Nginx configuration. Debug: ${debug}" "true"

    fi

}