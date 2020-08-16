#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
################################################################################
#
# TODO: Nginx best practices
# https://github.com/audioscavenger/nginx-server-config
# https://github.com/A5hleyRich/wordpress-nginx
# https://github.com/pothi/wordpress-nginx
# https://www.digitalocean.com/community/questions/how-can-i-improve-the-ttfb
# https://haydenjames.io/nginx-tuning-tips-tls-ssl-https-ttfb-latency/
#
# Brotli compression only supports the HTTPS site
#

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
    echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
    exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/nginx_helper.sh
source "${SFOLDER}/libs/nginx_helper.sh"

################################################################################

nginx_default_installer() {

    apt --yes install nginx

}

nginx_custom_installer() {

    #curl -L https://nginx.org/keys/nginx_signing.key | sudo apt-key add -
    #cp ${SFOLDER}/assets/nginx.list /etc/apt/sources.list.d/nginx.list

    add_ppa "nginx/stable"

    apt-get update

    apt --yes install nginx
}

nginx_webp_installer() {

    apt -y install imagemagick webp
}

nginx_purge_installation() {
  echo " > Removing Nginx ..." >>$LOG
  apt --yes purge nginx

}

nginx_check_if_installed() {

  NGINX="$(which nginx)"
  if [ ! -x "${NGINX}" ]; then
    nginx_installed="false"
  fi

}

nginx_check_installed_version() {
  nginx --version | awk '{ print $5 }' | awk -F\, '{ print $1 }'

}

################################################################################

nginx_installed="true"
nginx_check_if_installed

if [ ${nginx_installed} == "false" ]; then

    NGINX_INSTALLER_OPTIONS="01 NGINX_STANDARD 02 NGINX_LAST_STABLE 03 NGINX_RECONFIGURE"
    CHOSEN_NGINX_INSTALLER_OPTION=$(whiptail --title "NGINX INSTALLER" --menu "Choose a Nginx version to install" 20 78 10 $(for x in ${NGINX_INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then

        if [[ ${CHOSEN_NGINX_INSTALLER_OPTION} == *"01"* ]]; then
            nginx_default_installer

        fi
        if [[ ${CHOSEN_NGINX_INSTALLER_OPTION} == *"02"* ]]; then
            nginx_custom_installer

        fi
        if [[ ${CHOSEN_NGINX_INSTALLER_OPTION} == *"03"* ]]; then

            nginx_delete_default_directory

            nginx_reconfigure

            nginx_new_default_server

            nginx_create_globals_config

        fi

    fi

else

    log_event "info" "Nginx is already installed" "true"

fi
