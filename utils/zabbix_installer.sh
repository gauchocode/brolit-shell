#!/bin/bash
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9.8
################################################################################
#
# TODO: Seguir https://zabbixtech.info/es/zabbix-es/como-instalar-zabbix-con-nginx-en-ubuntu-linux/

zabbix_create_database() {

    #CREATE DATABASE zabbix CHARACTER SET UTF8 COLLATE UTF8_BIN;
    #CREATE USER 'zabbix'@'%' IDENTIFIED BY 'kamisama123';
    #GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'%';
    #quit;

}

zabbix_prepare_database() {

    # tar -zxvf zabbix-4.0.3.tar.gz
    # cd zabbix-4.0.3/database/mysql/
    # mysql -u zabbix -p zabbix < schema.sql
    # mysql -u zabbix -p zabbix < images.sql
    # mysql -u zabbix -p zabbix < data.sql

}

zabbix_download_installer() {

    mkdir /downloads
    cd /downloads
    wget https://ufpr.dl.sourceforge.net/project/zabbix/ZABBIX%20Latest%20Stable/4.0.3/zabbix-4.0.3.tar.gz

}

zabbix_installer() {
    # groupadd zabbix
    # useradd -g zabbix -s /bin/bash zabbix

    # apt-get install build-essential libmysqlclient-dev libssl-dev libsnmp-dev libevent-dev
    # apt-get install libopenipmi-dev libcurl4-openssl-dev libxml2-dev libssh2-1-dev libpcre3-dev
    # apt-get install libldap2-dev libiksemel-dev libcurl4-openssl-dev libgnutls28-dev

    # cd /downloads/zabbix-4.0.3/
    # ./configure --enable-server --enable-agent --with-mysql --with-openssl --with-net-snmp --with-openipmi --with-libcurl --with-libxml2 --with-ssh2 --with-ldap
    # make
    # make install

    # updatedb
    # locate zabbix_server.conf
    # cp ${SFOLDER}/zabbix/zabbix_server.conf /usr/local/etc/zabbix_server.conf

    # cd /downloads/zabbix-4.0.3/
    # cp misc/init.d/debian/* /etc/init.d/

    #/etc/init.d/zabbix-server start

    # TODO: pensar bien como configuramos nginx

    # cd /downloads/zabbix-4.0.3/frontends
    # mv php /var/www/html/zabbix
    # chown www-data.www-data /var/www/html/zabbix/* -R

    # service nginx stop
    # service nginx start

    # http://DOMINIO.COM/zabbix

}
