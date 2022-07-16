#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc10
################################################################################
#
# Netdata Installer
#
#   Refs:
#       https://github.com/audioscavenger/nginx-server-config
#       https://github.com/A5hleyRich/wordpress-nginx
#       https://github.com/pothi/wordpress-nginx
#       https://www.digitalocean.com/community/questions/how-can-i-improve-the-ttfb
#       https://haydenjames.io/nginx-tuning-tips-tls-ssl-https-ttfb-latency/
#
################################################################################

################################################################################
# Nginx installer
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function nginx_installer() {

    local nginx_version="${1}"

    nginx_bin="$(package_is_installed "nginx")"

    exitstatus=$?
    if [ ${exitstatus} -eq 0 ]; then

        log_event "info" "Nginx is already installed" "false"

        return 1

    else

        log_subsection "Nginx Installer"

        if [[ -z "${nginx_version}" || ${nginx_version} == "default" ]]; then

            package_install_if_not "nginx"

        else

            display --indent 6 --text "- Nginx custom installation"

            add_ppa "nginx/stable"

            apt-get update -qq >/dev/null

            # Install
            apt-get --yes install nginx -qq >/dev/null

            # Log
            clear_previous_lines
            display --indent 6 --text "- Nginx custom installation" --result "DONE" --color GREEN

        fi

    fi

}

################################################################################
# Nginx webp installer
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function nginx_webp_installer() {

    # Install
    package_install_if_not "webp"
    package_install_if_not "imagemagick"

}

################################################################################
# Check nginx installed version
#
# Arguments:
#  none
#
# Outputs:
#  nginx version
################################################################################

function nginx_check_installed_version() {

    nginx --version | awk '{ print $5 }' | awk -F\, '{ print $1 }'

}

################################################################################
# Nginx installer menu
#
# Arguments:
#  none
#
# Outputs:
#  nothing
################################################################################

function nginx_installer_menu() {

    local nginx_installer_options
    local chosen_nginx_installer_option

    nginx_bin="$(package_is_installed "nginx")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 1 ]]; then

        nginx_installer_options=(
            "01)" "INSTALL NGINX STANDARD"
            "02)" "INSTALL NGINX LAST STABLE"
        )

        chosen_nginx_installer_option="$(whiptail --title "NGINX INSTALLER" --menu "Choose a Nginx version to install" 20 78 10 "${nginx_installer_options[@]}" 3>&1 1>&2 2>&3)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_nginx_installer_option} == *"01"* ]]; then
                log_subsection "Nginx Installer"
                nginx_installer "default"
                nginx_reconfigure
            fi

            if [[ ${chosen_nginx_installer_option} == *"02"* ]]; then
                log_subsection "Nginx Installer"
                nginx_installer ""
                nginx_reconfigure
            fi

        fi

    else

        nginx_installer_options=(
            "01)" "UNINSTALL NGINX"
            "02)" "RECONFIGURE NGINX"
        )
        chosen_nginx_installer_option="$(whiptail --title "NGINX INSTALLER" --menu "Choose a Nginx version to install" 20 78 10 "${nginx_installer_options[@]}" 3>&1 1>&2 2>&3)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_nginx_installer_option} == *"01"* ]]; then
                log_subsection "Nginx Installer"
                package_purge "nginx"
            fi

            if [[ ${chosen_nginx_installer_option} == *"02"* ]]; then
                log_subsection "Nginx Installer"
                nginx_delete_default_directory
                nginx_new_default_server
                nginx_create_globals_config
                nginx_reconfigure
            fi

        fi

    fi
}
