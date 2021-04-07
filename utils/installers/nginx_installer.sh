#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.22
################################################################################
#
# Nginx best practices
# https://github.com/audioscavenger/nginx-server-config
# https://github.com/A5hleyRich/wordpress-nginx
# https://github.com/pothi/wordpress-nginx
# https://www.digitalocean.com/community/questions/how-can-i-improve-the-ttfb
# https://haydenjames.io/nginx-tuning-tips-tls-ssl-https-ttfb-latency/
#
# Brotli compression only supports the HTTPS site
#
################################################################################

function nginx_default_installer() {

    apt-get --yes install nginx -qq >/dev/null

    display --indent 6 --text "- Nginx default installation" --result "DONE" --color GREEN

}

function nginx_custom_installer() {

    #curl -L https://nginx.org/keys/nginx_signing.key | sudo apt-key add -
    #cp ${SFOLDER}/assets/nginx.list /etc/apt/sources.list.d/nginx.list

    add_ppa "nginx/stable"

    apt-get update -qq >/dev/null

    apt-get --yes install nginx -qq >/dev/null

    display --indent 6 --text "- Nginx custom installation" --result "DONE" --color GREEN

}

function nginx_webp_installer() {

    display --indent 6 --text "- Installing imagemagick and webp package"

    apt-get --yes install imagemagick webp -qq >/dev/null

    clear_last_line
    display --indent 6 --text "- Installing imagemagick and webp package" --result "DONE" --color GREEN

}

function nginx_purge_installation() {

    display --indent 6 --text "- Purgin nginx from system"

    apt-get --yes purge nginx -qq >/dev/null

    clear_last_line
    display --indent 6 --text "- Purgin nginx from system" --result "DONE" --color GREEN

}

function nginx_check_if_installed() {

    nginx_installed="true"

    NGINX="$(which nginx)"
    if [[ ! -x "${NGINX}" ]]; then
        nginx_installed="false"
    fi

    # Return
    echo "${nginx_installed}"

}

function nginx_check_installed_version() {

    nginx --version | awk '{ print $5 }' | awk -F\, '{ print $1 }'

}

function nginx_installer_menu() {

    #nginx_installed="true"
    nginx_check_if_installed

    if [[ ${nginx_installed} == "false" ]]; then

        NGINX_INSTALLER_OPTIONS=(
            "01)" "NGINX STANDARD"
            "02)" "NGINX LAST STABLE"
        )

    else

        NGINX_INSTALLER_OPTIONS=(
            "01)" "NGINX STANDARD"
            "02)" "NGINX LAST STABLE"
            "03)" "NGINX RECONFIGURE"
        )

    fi

    CHOSEN_NGINX_INSTALLER_OPTION=$(whiptail --title "NGINX INSTALLER" --menu "Choose a Nginx version to install" 20 78 10 "${NGINX_INSTALLER_OPTIONS[@]}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        if [[ ${CHOSEN_NGINX_INSTALLER_OPTION} == *"01"* ]]; then

            log_subsection "Nginx Installer"
            nginx_default_installer

        fi
        if [[ ${CHOSEN_NGINX_INSTALLER_OPTION} == *"02"* ]]; then

            log_subsection "Nginx Installer"
            nginx_custom_installer

        fi
        if [[ ${CHOSEN_NGINX_INSTALLER_OPTION} == *"03"* ]]; then

            log_subsection "Nginx Installer"

            nginx_delete_default_directory

            nginx_reconfigure

            nginx_new_default_server

            nginx_create_globals_config

        fi

    fi

}
