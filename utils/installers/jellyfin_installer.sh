#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc02
################################################################################
#
# Ref: https://jellyfin.org/docs/general/administration/installing.html#ubuntu
#

source "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/nginx_helper.sh"

################################################################################

install_jellyfin(){

    apt install apt-transport-https

    # Installing dependencies
    add-apt-repository universe
    wget -O - https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key | sudo apt-key add -
    echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/ubuntu $( lsb_release -c -s ) main" | sudo tee /etc/apt/sources.list.d/jellyfin.list
    apt update
    
    # Installing jellyfin
    apt install jellyfin

    # Ask project domain
    ask_project_domain
    
    # Configuring nginx for jellyfin
    create_nginx_server "${PROJECT_DOMAIN}" "jellyfin"

    # Extra configuration for proxy
    SERVER_IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
    # Replace string to match domain name
    sudo sed -i "s#SERVER_IP_ADDRESS#${SERVER_IP}#" "${WSERVER}/sites-available/${PROJECT_DOMAIN}"
    # need to run twice
    sudo sed -i "s#SERVER_IP_ADDRESS#${SERVER_IP}#" "${WSERVER}/sites-available/${PROJECT_DOMAIN}"

    # Reload webserver
    service nginx reload
    
    # Ask for Cloudflare Root Domain
    ROOT_DOMAIN=$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the Project (Only for Cloudflare API). Example: broobe.com" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then
        # Cloudflare API to change DNS records
        echo "Trying to access Cloudflare API and change record ${PROJECT_DOMAIN} ..." >>$LOG
        echo -e ${YELLOW}"Trying to access Cloudflare API and change record ${PROJECT_DOMAIN} ..."${ENDCOLOR}

        zone_name=${ROOT_DOMAIN}
        record_name=${PROJECT_DOMAIN}
        export zone_name record_name
        "${SFOLDER}/utils/cloudflare_update_IP.sh"

    fi
    
    # HTTPS with Certbot
    certbot_helper_installer_menu "${PROJECT_DOMAIN}"

    echo -" > DONE">>$LOG
    echo -e ${GREEN}" > DONE"${ENDCOLOR}

}

################################################################################

# TODO: menu with options (install and remove)

install_jellyfin