#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.5
################################################################################
#
# Nginx Helper: Perform nginx actions.
#
################################################################################

################################################################################
# Create nginx server config
#
# Arguments:
#   ${1} = ${project_domain}
#   ${2} = ${project_type} (default, wordpress, symphony, phpmyadmin, netdata, proxy)
#   ${3} = ${server_type} (single, root_domain, multi_domain)
#   ${4} = ${redirect_domains} (list of domains or subdomains that will be redirect to project_domain) - Optional
#   ${5} = ${proxy_port} (only if project_type==proxy) - Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_server_create() {

    local project_domain="${1}"
    local project_type="${2}"
    local server_type="${3}"
    local redirect_domains="${4}"
    local proxy_port="${5}"

    # Log
    log_event "debug" "Project type: ${project_type}" "false"
    log_event "debug" "Server type: ${server_type}" "false"
    log_event "debug" "Proxy port: ${proxy_port}" "false"
    log_event "info" "Creating nginx configuration file for domain: ${project_domain}" "false"
    log_event "info" "List of domains or subdomains that will be redirect to project_domain: ${redirect_domains}" "false"

    # Check if nginx config file already exists
    if [[ -f "${WSERVER}/sites-available/${project_domain}" ]]; then

        # Backup actual config
        mv "${WSERVER}/sites-available/${project_domain}" "${WSERVER}/sites-available/${project_domain}_backup"
        # Remove symbolic link
        rm "${WSERVER}/sites-enabled/${project_domain}"

        # Log
        display --indent 6 --text "- Backup old nginx server config" --result DONE --color GREEN
        display --indent 8 --text "${WSERVER}/sites-available/${project_domain}_backup" --tcolor YELLOW
        log_event "info" "Backup old nginx server config: ${WSERVER}/sites-available/${project_domain}_backup" "false"

    fi

    case ${server_type} in

    single)

        # Config file path
        nginx_server_file="${WSERVER}/sites-available/${project_domain}"

        # Copy config from template file
        cp "${BROLIT_MAIN_DIR}/config/nginx/sites-available/${project_type}_${server_type}" "${nginx_server_file}"

        # Symbolic link
        ln -s "${nginx_server_file}" "${WSERVER}/sites-enabled/${project_domain}"

        # Search and replace domain.com string with ${project_domain}
        sed -i "s/domain.com/${project_domain}/g" "${nginx_server_file}"

        # If proxy_port is not empty
        if [[ -n "${proxy_port}" ]]; then

            # Search and replace PROXY_PORT string with ${proxy_port}
            sed -i "s/PROXY_PORT/${proxy_port}/g" "${nginx_server_file}"

        fi

        # Log
        display --indent 6 --text "- Creating nginx server config" --result DONE --color GREEN
        log_event "info" "Creating nginx server config: ${nginx_server_file}" "false"
        log_event "debug" "Using '${BROLIT_MAIN_DIR}/config/nginx/sites-available/${project_type}_${server_type}' template" "false"

        ;;

    root_domain)

        # Here $redirect_domains == $root_domain

        # Config file path
        nginx_server_file="${WSERVER}/sites-available/${redirect_domains}"
        nginx_server_file_link="${WSERVER}/sites-enabled/${redirect_domains}"

        # Copy config from template file
        cp "${BROLIT_MAIN_DIR}/config/nginx/sites-available/${project_type}_${server_type}" "${nginx_server_file}"

        # -L returns true if the "file" exists and is a symbolic link
        ## Remove previous symbolic link
        [[ -L ${nginx_server_file_link} ]] && rm "${nginx_server_file_link}"

        # Creating symbolic link
        ln -s "${nginx_server_file}" "${nginx_server_file_link}"

        # Search and replace root_domain.com string with correct redirect_domains (must be root_domain here)
        sed -i "s/root_domain.com/${redirect_domains}/g" "${nginx_server_file}"

        # Search and replace domain.com string with correct project_domain
        sed -i "s/domain.com/${project_domain}/g" "${nginx_server_file}"

        # Search and replace PROXY_PORT string with ${proxy_port}
        sed -i "s/PROXY_PORT/${proxy_port}/g" "${nginx_server_file}"

        # Log
        display --indent 6 --text "- Creating nginx server config" --result DONE --color GREEN
        log_event "info" "Creating nginx server config: ${nginx_server_file}" "false"
        log_event "debug" "Using '${BROLIT_MAIN_DIR}/config/nginx/sites-available/${project_type}_${server_type}' template" "false"

        ;;

    multi_domain)

        log_event "info" "TODO: implements multidomain support" "false"
        display --indent 6 --text "- Creating nginx server config" --result FAIL --color RED
        #display --indent 8 --text "Using '${project_type}_${server_type}' template"
        display --indent 8 --text "TODO: implements multidomain support"

        ;;

    *)

        log_event "error" "Nginx server config creation fail! Nginx server type '${project_type}_${server_type}' unknow." "false"
        display --indent 6 --text "- Nginx server config creation" --result FAIL --color RED
        #display --indent 8 --text "Nginx server type '${project_type}_${server_type}' unknow!"

        return 1

        ;;

    esac

    # Set/Change PHP version if needed
    php_set_version_on_config "" "${nginx_server_file}"

    #Test the validity of the nginx configuration
    nginx_configuration_test

}

################################################################################
# Delete nginx server config
#
# Arguments:
#   ${1} = ${filename}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_server_delete() {

    local filename="${1}"

    if [[ -n "${filename}" ]]; then

        # Remove files
        rm --force "/etc/nginx/sites-available/${filename}"
        rm --force "/etc/nginx/sites-enabled/${filename}"

        ## Delete broken symbolic links on sites-enabled
        find -L "/etc/nginx/sites-enabled/" -type l -exec rm {} +

        # Logs
        log_event "info" "Nginx config files for ${filename} deleted!" "false"
        display --indent 6 --text "- Deleting nginx files" --result "DONE" --color GREEN

        # Test the validity of the nginx configuration
        nginx_configuration_test

    fi

}

################################################################################
# Change nginx server status (online or offline)
#
# Arguments:
#   ${1} = ${project_domain}
#   ${2} = ${project_status} (online,offline)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_server_change_status() {

    # File test operators
    # -d FILE - True if the FILE exists and is a directory.
    # -f FILE - True if the FILE exists and is a regular file (not a directory or device).
    # -h FILE - True if the FILE exists and is a symbolic link.

    local project_domain="${1}"
    local project_status="${2}"

    local result
    local debug

    case ${project_status} in

    online)

        log_event "info" "New project status: ${project_status}" "false"

        if [[ -f "${WSERVER}/sites-available/${project_domain}" ]]; then
            # Creating symbolic link
            ln -s "${WSERVER}/sites-available/${project_domain}" "${WSERVER}/sites-enabled/${project_domain}"
            # Log
            log_event "info" "Project config added to ${WSERVER}/sites-enabled/${project_domain}" "false"
            display --indent 6 --text "- Changing project status to ONLINE" --result "DONE" --color GREEN

        else
            # Log
            log_event "error" "${WSERVER}/sites-available/${project_domain} does not exist" "false"
            display --indent 6 --text "- Changing project status to ONLINE" --result "FAIL" --color RED
            display --indent 8 --text "${WSERVER}/sites-available/${project_domain} does not exist" --tcolor RED

        fi
        ;;

    offline)

        log_event "info" "New project status: ${project_status}" "false"

        if [[ -L "${WSERVER}/sites-enabled/${project_domain}" ]]; then

            # Deleting config
            rm "${WSERVER}/sites-enabled/${project_domain}"

            # Logging
            log_event "info" "Project config deleted from ${WSERVER}/sites-enabled/${project_domain}" "false"
            display --indent 6 --text "- Changing project status to OFFLINE" --result "DONE" --color GREEN

        else
            # Logging
            log_event "error" "${WSERVER}/sites-enabled/${project_domain} does not exist" "false"
            display --indent 6 --text "- Changing project status to OFFLINE" --result "FAIL" --color RED
            display --indent 8 --text "${WSERVER}/sites-available/${project_domain} does not exist" --tcolor RED

        fi
        ;;

    *)
        log_event "info" "New project status: Unknown" "false"
        return 1
        ;;

    esac

    #Test the validity of the nginx configuration
    nginx_configuration_test

}

################################################################################
# Set nginx server domain
#
# Arguments:
#   ${1} = ${nginx_server_file} / ${tool} or ${project_domain}
#   ${2} = ${domain_name}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_server_set_domain() {

    local nginx_server_file="${1}"
    local domain_name="${2}"

    # Search and replace domain.com string with correct project_domain
    sed -i "s/domain.com/${domain_name}/g" "${WSERVER}/sites-available/${nginx_server_file}"

}

################################################################################
# Change domain on nginx server configuration
#
# Arguments:
#  ${1} = ${nginx_server_file} / ${tool} or ${project_domain}
#  ${2} = ${domain_name_old}
#  ${3} = ${domain_name_new}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_server_change_domain() {

    local nginx_server_file="${1}"
    local domain_name_old="${2}"
    local domain_name_new="${3}"

    # Search and replace domain.com string with correct project_domain
    sed -i "s/${domain_name_old}/${domain_name_new}/g" "${WSERVER}/sites-available/${nginx_server_file}"

}

################################################################################
# Get configured PHP version on nginx server
#
# Arguments:
#  ${1} = ${nginx_server_file} - Entire path
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_server_get_current_phpv() {

    local nginx_server_file="${1}"

    # Replace string to match PHP version
    current_php_v_string=$(cat "${nginx_server_file}" | grep fastcgi_pass | cut -d '/' -f 4 | cut -d '-' -f 1)
    current_php_v=${current_php_v_string#"php"}

    # Log
    log_event "debug" "Get php version from nginx server: ${nginx_server_file}" "false"
    log_event "debug" "Current php version: ${current_php_v}" "false"

    # Return
    echo "${current_php_v}"

}

################################################################################
# Change PHP version on nginx server configuration
#
# Arguments:
#  ${1} = ${nginx_server_file} - Entire path
#  ${2} = ${new_php_v} optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_server_change_phpv() {

    local nginx_server_file="${1}"
    local new_php_v="${2}"

    # TODO: if ${new_php_v} is not set, must ask wich PHP_V
    if [[ -z ${new_php_v} ]]; then
        new_php_v="$(php_check_activated_version)"
        [[ $? -eq 1 ]] && return 1
    fi

    # Updating nginx server file
    log_event "info" "Changing PHP version on nginx server file" "false"
    display --indent 6 --text "- Changing PHP version on nginx server file"

    # Get current php version
    current_php_v="$(nginx_server_get_current_phpv "${nginx_server_file}")"

    # Replace string to match PHP version
    sed -i "s#${current_php_v}#${new_php_v}#" "${nginx_server_file}"

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Changing PHP version on nginx server file" --result "DONE" --color GREEN
    display --indent 8 --text "PHP version changed to ${new_php_v}"
    log_event "info" "PHP version for ${nginx_server_file} changed from ${current_php_v} to ${new_php_v}" "false"

    # Test nginx configuration
    nginx_configuration_test

}

################################################################################
# Reconfigure nginx
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_reconfigure() {

    # nginx.conf gauchocode standard configuration
    cat "${BROLIT_MAIN_DIR}/config/nginx/nginx.conf" >"/etc/nginx/nginx.conf"
    display --indent 6 --text "- Updating nginx.conf" --result "DONE" --color GREEN

    # mime.types
    cat "${BROLIT_MAIN_DIR}/config/nginx/mime.types" >"/etc/nginx/mime.types"
    display --indent 6 --text "- Updating mime.types" --result "DONE" --color GREEN

    #Test the validity of the nginx configuration
    nginx_configuration_test

}

################################################################################
# Test nginx configuration
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_configuration_test() {

    local result

    #Test the validity of the nginx configuration
    result="$(nginx -t 2>&1 | grep -w "test" | cut -d"." -f2 | cut -d" " -f4)"

    if [[ ${result} == "successful" ]]; then

        # Reload webserver
        service nginx reload

        # Log
        log_event "info" "Nginx configuration changed!" "false"
        display --indent 6 --text "- Testing nginx configuration" --result "DONE" --color GREEN

        return 0

    else

        debug="$(nginx -t 2>&1)"
        whiptail_message "WARNING" "Something went wrong changing Nginx configuration. Please check manually nginx config files."

        # Log
        log_event "error" "Problem changing Nginx configuration. Debug: ${debug}"
        display --indent 6 --text "- Testing nginx configuration" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Create nginx default server
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_new_default_server() {

    # New default nginx configuration
    cat "${BROLIT_MAIN_DIR}/config/nginx/sites-available/default" >"/etc/nginx/sites-available/default"

    # Log
    log_event "info" "Creating default nginx server..." "false"
    display --indent 6 --text "- Creating default nginx server" --result "DONE" --color GREEN

}

################################################################################
# Delete nginx default directory for sites
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_delete_default_directory() {

    local nginx_default_dir

    # Remove html default nginx folders
    nginx_default_dir="/var/www/html"
    if [[ -d "${nginx_default_dir}" ]]; then

        # Delete
        rm --recursive --force "${nginx_default_dir}"

        # Log
        log_event "info" "Directory ${nginx_default_dir} deleted" "false"
        display --indent 6 --text "- Removing nginx default directory" --result "DONE" --color GREEN

    fi

}

################################################################################
# Create globals config files for nginx server configuration
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_create_globals_config() {

    local nginx_globals

    # nginx.conf gauchocode standard configuration
    nginx_globals="/etc/nginx/globals/"

    if [[ -d ${nginx_globals} ]]; then
        log_event "warning" "Directory ${nginx_globals} already exists ..." "false"
        return 1

    else
        log_event "info" "Creating directory ${nginx_globals} exists ..." "false"
        mkdir -p "${nginx_globals}"

    fi

    # Copy files
    cp "${BROLIT_MAIN_DIR}/config/nginx/globals/security.conf" "/etc/nginx/globals/security.conf"

    display --indent 6 --text "- Creating nginx globals config" --result "DONE" --color GREEN

    # Replace string to match PHP version
    if [[ ${PACKAGES_PHP_STATUS} == "enabled" ]]; then

        cp "${BROLIT_MAIN_DIR}/config/nginx/globals/wordpress_sec.conf" "/etc/nginx/globals/wordpress_sec.conf"
        php_set_version_on_config "${PHP_V}" "/etc/nginx/globals/wordpress_sec.conf"

        display --indent 6 --text "- Configuring globals for phpfpm-${PHP_V}" --result "DONE" --color GREEN
    fi

    # Change ownership
    change_ownership "www-data" "www-data" "/etc/nginx/globals/"

    #Test the validity of the nginx configuration
    nginx_configuration_test

}

################################################################################
# Create empty nginx.conf file
#
# Arguments:
#   ${1} = ${path}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_create_empty_nginx_conf() {

    local path="${1}"

    if [[ -d "${path}" && ! -f "${path}/nginx.conf" ]]; then

        # Create empty file
        touch "${path}/nginx.conf" && return 0

    else

        return 1

    fi

}

################################################################################
# Generate nginx auth config
#
# Arguments:
#   ${1} = ${user}
#   ${2} = ${psw}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_generate_encrypted_auth() {

    local user="${1}"
    local psw="${2}"

    local encrypted_psw

    log_event "info" "Creating nginx encrypted authentication" "false"

    [[ -n ${psw} ]] && encrypted_psw="$(mkpasswd -m sha-512 "${psw}")"

    # Log
    log_event "info" "User: ${user}" "false"
    log_event "info" "Pass: ${psw}" "false"
    log_event "info" "Encrypted Pass: ${encrypted_psw}" "false"
    log_event "info" "Saving auth data on: /etc/nginx/.passwords" "false"

    printf "${user}:${encrypted_psw}" >"/etc/nginx/.passwords"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        chmod 640 "/etc/nginx/.passwords"
        chown www-data:www-data "/etc/nginx/.passwords"

    else

        log_event "error" "Something went wrong writing: /etc/nginx/.passwords" "false"
        return 1

    fi

}

################################################################################
# Add http2 support to nginx server configuration
#
# Arguments:
#   ${1} = ${nginx_server_file}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nginx_server_add_http2_support() {

    local nginx_server_file="${1}"

    # Check if the file exists
    nginx_server_file="/etc/nginx/sites-available/${nginx_server_file}"

    # Return error if file doesn't exist
    [[ ! -f "${nginx_server_file}" ]] && log_event "error" "File ${nginx_server_file} not found" "false" && return 1

    # Add http2 to ports
    sed -i "s/listen 443 ssl;/listen 443 ssl http2;/g" "${nginx_server_file}"
    sed -i "s/listen [::]:443 ssl;/listen [::]:443 ssl http2;/g" "${nginx_server_file}"

    # Log
    log_event "info" "Adding http2 support to ${nginx_server_file}" "false"
    display --indent 6 --text "- Adding http2 support" --result "DONE" --color GREEN

    return 0

}
