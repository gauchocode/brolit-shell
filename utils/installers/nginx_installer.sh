#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.70-beta
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
# Nginx default installer
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function nginx_default_installer() {

    display --indent 6 --text "- Nginx default installation"

    # Install
    apt-get --yes install nginx -qq >/dev/null

    # Log
    clear_last_line
    display --indent 6 --text "- Nginx default installation" --result "DONE" --color GREEN

}

################################################################################
# Nginx custom installer (adding ppa)
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function nginx_custom_installer() {

    display --indent 6 --text "- Nginx default installation"

    add_ppa "nginx/stable"

    apt-get update -qq >/dev/null

    # Install
    apt-get --yes install nginx -qq >/dev/null

    # Log
    clear_last_line
    display --indent 6 --text "- Nginx custom installation" --result "DONE" --color GREEN

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

    display --indent 6 --text "- Installing imagemagick and webp package"

    # Install
    apt-get --yes install imagemagick webp -qq >/dev/null

    # Log
    clear_last_line
    display --indent 6 --text "- Installing imagemagick and webp package" --result "DONE" --color GREEN

}

################################################################################
# Nginx purge installation
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function nginx_purge_installation() {

    display --indent 6 --text "- Purgin nginx from system"

    # Purge
    apt-get --yes purge nginx -qq >/dev/null

    # Log
    clear_last_line
    display --indent 6 --text "- Purgin nginx from system" --result "DONE" --color GREEN

}

################################################################################
# Check if nginx is installed
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function nginx_check_if_installed() {

    local nginx_installed

    nginx_installed="true"

    NGINX="$(which nginx)"
    if [[ ! -x "${NGINX}" ]]; then

        nginx_installed="false"

    fi

    # Return
    echo "${nginx_installed}"

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

    nginx_check_if_installed

    if [[ ${nginx_installed} == "false" ]]; then

        nginx_installer_options=(
            "01)" "INSTALL NGINX STANDARD"
            "02)" "INSTALL NGINX LAST STABLE"
        )

        chosen_nginx_installer_option="$(whiptail --title "NGINX INSTALLER" --menu "Choose a Nginx version to install" 20 78 10 "${nginx_installer_options[@]}" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_nginx_installer_option} == *"01"* ]]; then

                log_subsection "Nginx Installer"
                nginx_default_installer

                nginx_reconfigure

            fi
            if [[ ${chosen_nginx_installer_option} == *"02"* ]]; then

                log_subsection "Nginx Installer"
                nginx_custom_installer

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
                
                nginx_purge_installation

            fi
            if [[ ${chosen_nginx_installer_option} == *"02"* ]]; then

                log_subsection "Nginx Installer"

                nginx_delete_default_directory

                nginx_reconfigure

                nginx_new_default_server

                nginx_create_globals_config

            fi

        fi

    fi

}
