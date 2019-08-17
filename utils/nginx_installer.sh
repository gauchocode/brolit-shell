#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9.7
################################################################################
#
# Brotli compression only supports the HTTPS site
#
# Para quitar repo de nginx de ondrej: add-apt-repository --remove ppa:ondrej/nginx && apt-get update
# Luego lo ideal es hacer un apt purge nginx && apt install -f y luego volver a instalarlo
#

SCRIPT_V="2.9.7"

nginx_installer(){
    curl -L https://nginx.org/keys/nginx_signing.key | sudo apt-key add -

    #vim /etc/apt/sources.list.d/nginx.list

    #deb [arch=amd64] http://nginx.org/packages/ubuntu/ bionic nginx
    #deb-src http://nginx.org/packages/ubuntu/ bionic nginx

    apt-get update

}

nginx_webp_installer(){
    apt -y install imagemagick webp
}

nginx_brotli_installer(){

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
    cd /etc/nginx/
    vim nginx.conf
    # brotli on;
    # brotli_comp_level 6;
    # brotli_static on;
    # brotli_types text/plain text/css application/javascript application/x-javascript text/xml application/xml application/xml+rss text/javascript image/x-icon image/vnd.microsoft.icon image/bmp image/svg+xml;

    # Testing ...
    nginx -t
}