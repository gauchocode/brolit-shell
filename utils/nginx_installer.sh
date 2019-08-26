#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9.7
################################################################################
#
# TODO: Nginx mejores prácticas
# https://github.com/audioscavenger/nginx-server-config
# https://github.com/A5hleyRich/wordpress-nginx
# https://github.com/pothi/wordpress-nginx
# https://www.digitalocean.com/community/questions/how-can-i-improve-the-ttfb
# https://haydenjames.io/nginx-tuning-tips-tls-ssl-https-ttfb-latency/
#
# Brotli compression only supports the HTTPS site
#
# Para quitar repo de nginx de ondrej: add-apt-repository --remove ppa:ondrej/nginx && apt-get update
# Luego lo ideal es hacer un apt purge nginx && apt install -f y luego volver a instalarlo
#

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
    echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
    exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh

nginx_installer() {

    #curl -L https://nginx.org/keys/nginx_signing.key | sudo apt-key add -
    #cp ${SFOLDER}/assets/nginx.list /etc/apt/sources.list.d/nginx.list

    add_ppa "nginx/stable"

    apt-get update

    apt --yes install nginx
}

nginx_webp_installer() {

    apt -y install imagemagick webp
}

nginx_brotli_installer() {

    # TODO: https://www.howtoforge.com/tutorial/how-to-install-nginx-with-brotli-compression-on-ubuntu-1804/

    apt update
    apt -y install libpcre3 libpcre3-dev zlib1g zlib1g-dev openssl libssl-dev

    cd /usr/local/src

    apt source nginx

    sudo apt build-dep nginx -y

    git clone --recursive https://github.com/google/ngx_brotli.git
    cd /usr/local/src/nginx-*/

    vim debian/rules
    #Now you will get two build environments for 'config.env.nginx' and 'config.env.nginx_debug'.
    # Add the '--add-module=' option for ngx_brotli to both built environments.
    #--add-module=/usr/local/src/ngx_brotli

    dpkg-buildpackage -b -uc -us

    cd /usr/local/src/
    sudo dpkg -i *.deb

    # ACA AGREGAMOS CONFIG DE BROTLI
    #cd /etc/nginx/
    #vim nginx.conf
    #
    # TODO: quiza lo que haya que hacer es tenerlo en el nginx.conf y descomentarle las lineas con sed
    # sed -i '/<pattern>/s/^/#/g' file #comment
    # sed -i '/<pattern>/s/^#//g' file #uncomment
    # o la otra es agregar lo siguiente a un .conf y simplemente agregarle una linea con include
    #
    # brotli on;
    # brotli_comp_level 6;
    # brotli_static on;
    # brotli_types text/plain text/css application/javascript application/x-javascript text/xml application/xml application/xml+rss text/javascript image/x-icon image/vnd.microsoft.icon image/bmp image/svg+xml;

    # Testing ...
    nginx -t

    # Reloading Nginx ...
    service nginx reload

    # ponemos on hold el paquete
    apt-mark hold nginx

}

nginx_pagespeed_installer() {

    # TODO: https://www.linuxbabe.com/nginx/compile-the-latest-nginx-with-ngx_pagespeed-module-on-ubuntu

    apt update

    cd /usr/local/src/nginx/

    sudo apt install dpkg-dev

    sudo apt source nginx

    cd /usr/local/src

    sudo apt install git

    sudo git clone https://github.com/apache/incubator-pagespeed-ngx.git

    cd incubator-pagespeed-ngx/

    git checkout latest-stable

    # Compiling

    cd /usr/local/src/nginx/nginx-1.17.0

    # Install build dependencies for Nginx.

    sudo apt build-dep nginx
    sudo apt install uuid-dev

    sudo ./configure --with-compat --add-dynamic-module=/usr/local/src/incubator-pagespeed-ngx

    make modules

    cp objs/ngx_pagespeed.so /etc/nginx/modules/

    # Edit the main Nginx configuration file.
    sudo nano /etc/nginx/nginx.conf

    #Add the following line at the beginning of the file.
    load_module modules/ngx_pagespeed.so

    #Save and close the file. Then test Nginx configuration.
    sudo nginx -t
    sudo systemctl reload nginx

    sudo mkdir -p /var/ngx_pagespeed_cache

    sudo chown -R www-data:www-data /var/ngx_pagespeed_cache

    apt-mark hold nginx

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

    NGINX_INSTALLER_OPTIONS="01 NGINX_STANDARD 02 NGINX_LAST_STABLE"
    CHOSEN_NGINX_INSTALLER_OPTION=$(whiptail --title "NGINX INSTALLER" --menu "Choose a Nginx version to install" 20 78 10 $(for x in ${NGINX_INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then

        if [[ ${CHOSEN_NGINX_INSTALLER_OPTION} == *"01"* ]]; then
            apt --yes install nginx

        fi
        if [[ ${CHOSEN_NGINX_INSTALLER_OPTION} == *"02"* ]]; then
            nginx_installer

        fi

        # Remove html default nginx folders
        nginx_default_dir="/var/www/html"
        if [ -d "${nginx_default_dir}" ]; then
            rm -r $nginx_default_dir
            echo "Directory ${nginx_default_dir} deleted ..." >>$LOG
            echo -e ${CYAN}" > Directory ${nginx_default_dir} deleted ..."${ENDCOLOR}
        fi

        # nginx.conf broobe standard configuration
        cat ${SFOLDER}/confs/nginx/nginx.conf >/etc/nginx/nginx.conf

        # New default nginx configuration
        echo " > Moving nginx configuration files ..." >>$LOG
        cat ${SFOLDER}/confs/nginx/sites-available/default >/etc/nginx/sites-available/default

        nginx_globals="/etc/nginx/globals/"
        if [ -d "${nginx_globals}" ]; then
            echo "Directory ${nginx_globals} already exists ..." >>$LOG
            echo -e ${CYAN}" > Directory ${nginx_globals} already exists ..."${ENDCOLOR}
            exit 1

        else
            mkdir ${nginx_globals}

        fi

        cp ${SFOLDER}/confs/nginx/globals/logs.conf /etc/nginx/globals/logs.conf
        cp ${SFOLDER}/confs/nginx/globals/security.conf /etc/nginx/globals/security.conf
        cp ${SFOLDER}/confs/nginx/globals/wordpress_mu_subdirectory.conf /etc/nginx/globals/wordpress_mu_subdirectory.conf
        cp ${SFOLDER}/confs/nginx/globals/wordpress_mu_subdomain.conf /etc/nginx/globals/wordpress_mu_subdomain.conf
        cp ${SFOLDER}/confs/nginx/globals/wordpress_sec.conf /etc/nginx/globals/wordpress_sec.conf
        cp ${SFOLDER}/confs/nginx/globals/wordpress_seo.conf /etc/nginx/globals/wordpress_seo.conf

        #chown ??
        #sed para reemplazar los domain.com
        #si es network con subdominios hay que usar *.domain.com

    else
        echo -e ${CYAN}" > Operation cancelled ..."${ENDCOLOR}
        exit 1

    fi

else

    echo -e ${MAGENTA}" > Nginx already installed ..."${ENDCOLOR}

fi
