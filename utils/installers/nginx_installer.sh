#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.5-beta
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

    local nginx_version=$1

    package_is_installed "nginx"

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
