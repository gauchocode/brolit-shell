#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.15
################################################################################
#
# Seguir:
#       https://zabbixtech.info/es/zabbix-es/como-instalar-zabbix-con-nginx-en-ubuntu-linux/
#       https://linuxize.com/post/how-to-install-and-configure-zabbix-on-ubuntu-18-04/
#       https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-zabbix-to-securely-monitor-remote-servers-on-ubuntu-18-04
#
# Web Monitoring:
#       https://www.zabbix.com/documentation/4.2/manual/web_monitoring
#
################################################################################

function zabbix_prepare_database() {

    SQL1="CREATE DATABASE zabbix CHARACTER SET UTF8 COLLATE UTF8_BIN;"
    SQL2="CREATE USER 'zabbix'@'%' IDENTIFIED BY 'zabbix2020*';"
    SQL3="GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'%';"

    mysql -u ${MUSER} -p${MPASS} -e "${SQL1}${SQL2}${SQL3}"

    cd "/usr/share/doc/zabbix-server-mysql/"

    zcat "create.sql.gz" | mysql -u${MUSER} zabbix -p${MPASS}

}

function zabbix_prepare_database() {

    tar -zxvf "zabbix-4.0.3.tar.gz"
    cd "zabbix-4.0.3/database/mysql/"
    mysql -u zabbix -p zabbix < schema.sql
    mysql -u zabbix -p zabbix < images.sql
    mysql -u zabbix -p zabbix < data.sql

}

# Zabbix 4.2
function zabbix_download_installer() {

    cd "${SFOLDER}/tmp/"
    wget "http://repo.zabbix.com/zabbix/4.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_4.2-1%2Bbionic_all.deb"

}

function zabbix_server_installer() {

    zabbix_download_installer

    # groupadd zabbix
    # useradd -g zabbix -s /bin/bash zabbix

    # apt-get install build-essential libmysqlclient-dev libssl-dev libsnmp-dev libevent-dev
    # apt-get install libopenipmi-dev libcurl4-openssl-dev libxml2-dev libssh2-1-dev libpcre3-dev
    # apt-get install libldap2-dev libiksemel-dev libcurl4-openssl-dev libgnutls28-dev

    cd "${SFOLDER}/tmp/"
    dpkg -i zabbix-release_4.2-1+bionic_all.deb

    apt update

    apt-get --yes install zabbix-server-mysql zabbix-frontend-php -qq > /dev/null

    # TODO: ASK FOR SUBDOMAIN
    ln -s "/usr/share/zabbix/" "/var/www/${SUBDOMAIN}"

    cp "${SFOLDER}/config/nginx/sites-available/zabbix" "/etc/nginx/sites-available/${SUBDOMAIN}"

    # TODO: REPLACE DOMAIN WITH SED

    ln -s "/etc/nginx/sites-available/${SUBDOMAIN}" "/etc/nginx/sites-enabled/${SUBDOMAIN}"

    cd "/var/www"
    chown -R www-data:www-data *

    # ./configure --enable-server --enable-agent --with-mysql --with-openssl --with-net-snmp --with-openipmi --with-libcurl --with-libxml2 --with-ssh2 --with-ldap
    # make
    # make install

    # updatedb
    # locate zabbix_server.conf
    # cp ${SFOLDER}/zabbix/zabbix_server.conf /usr/local/etc/zabbix_server.conf

    # cd /downloads/zabbix-4.0.3/
    # cp misc/init.d/debian/* /etc/init.d/

    #/etc/init.d/zabbix-server start

    # TODO: configure with nginx

    # cd /downloads/zabbix-4.0.3/frontends
    # mv php /var/www/html/zabbix
    # chown www-data.www-data /var/www/html/zabbix/* -R

    # service nginx stop
    # service nginx start

    # http://DOMAIN.COM/zabbix

}

function zabbix_agent_installer() {

    cd "${SFOLDER}/tmp/"
    dpkg -i zabbix-release_4.2-1+bionic_all.deb

    apt update

    apt-get --yes install zabbix-agent

}
