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
#
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

nginx_installer(){
    curl -L https://nginx.org/keys/nginx_signing.key | sudo apt-key add -

    cp ${SFOLDER}/assets/nginx.list /etc/apt/sources.list.d/nginx.list

    apt-get update

    apt --yes install nginx
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

################################################################################

# TODO: usar las funciones de arriba a través de un menú con whiptail
apt --yes install nginx

# Remove html default nginx folders
rm -r /var/www/html

# nginx.conf broobe standard configuration
cat ${SFOLDER}/confs/nginx/nginx.conf > /etc/nginx/nginx.conf

# nginx conf file
echo " > Moving nginx configuration files ..." >>$LOG
# New default nginx configuration
cat ${SFOLDER}/confs/nginx/sites-available/default > /etc/nginx/sites-available/default

mkdir /etc/nginx/globals/

cp ${SFOLDER}/confs/nginx/globals/logs.conf > /etc/nginx/globals/logs.conf
cp ${SFOLDER}/confs/nginx/globals/security.conf > /etc/nginx/globals/security.conf
cp ${SFOLDER}/confs/nginx/globals/wordpress_mu_subdirectory.conf > /etc/nginx/globals/wordpress_mu_subdirectory.conf
cp ${SFOLDER}/confs/nginx/globals/wordpress_mu_subdomain.conf > /etc/nginx/globals/wordpress_mu_subdomain.conf
cp ${SFOLDER}/confs/nginx/globals/wordpress_sec.conf > /etc/nginx/globals/wordpress_sec.conf
cp ${SFOLDER}/confs/nginx/globals/wordpress_seo.conf > /etc/nginx/globals/wordpress_seo.conf

#chown ??
#sed para reemplazar los domain.com
#si es network con subdominios hay que usar *.domain.com