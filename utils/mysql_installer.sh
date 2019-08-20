#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9.9
################################################################################

mysql_default_installer() {
    echo " > LEMP installation with MySQL ..." >>$LOG
    apt --yes install mysql-server

}

mysql8_official_installer() {
    echo " > LEMP installation with MySQL 8 ..." >>$LOG
    wget -c https://dev.mysql.com/get/mysql-apt-config_0.8.10-1_all.deb
    sudo dpkg -i mysql-apt-config_0.8.10-1_all.deb

    sudo apt-key adv --keyserver keys.gnupg.net --recv-keys 5072E1F5

    apt --yes update
    apt --yes install mysql-server

    mkdir -pv /etc/systemd/system/mysqld.service.d
    cp ${SFOLDER}/confs/mysql/override.conf /etc/systemd/system/mysqld.service.d/override.conf
    cp ${SFOLDER}/confs/mysql/mysql /etc/init.d/mysql
    chmod +x /etc/init.d/mysql
    systemctl daemon-reload
    systemctl unmask mysql.service
    systemctl restart mysql

}

mariadb_default_installer() {
    echo " > LEMP installation with MariaDB ..." >>$LOG
    apt --yes install mariadb-server mariadb-client
}

mariadb_official_installer() {
  # TODO: https://www.linuxbabe.com/mariadb/install-mariadb-ubuntu-18-04-18-10

}

mysql_purge_installation() {
    echo " > Removing MySQL ..." >>$LOG
    apt --yes purge mysql-server

}

################################################################################

# TODO: checkear si hay algo instalado y preguntar con whiptail que instalar

#MARIADB="false"
#MYSQL8="false"

MYSQL_INSTALLER_OPTIONS="01 MYSQL_STANDARD 02 MYSQL_8 03 MARIADB_STANDARD"
CHOSEN_MYSQL_INSTALLER_OPTION=$(whiptail --title "MySQL INSTALLER" --menu "Choose a MySQL version to install" 20 78 10 `for x in ${MYSQL_INSTALLER_OPTIONS}; do echo "$x"; done` 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then

  if [[ ${CHOSEN_MYSQL_INSTALLER_OPTION} == *"01"* ]]; then
    mysql_default_installer
    
  fi
  if [[ ${CHOSEN_MYSQL_INSTALLER_OPTION} == *"02"* ]]; then
    mysql8_official_installer
    
  fi
  if [[ ${CHOSEN_MYSQL_INSTALLER_OPTION} == *"03"* ]]; then
    mariadb_default_installer
    
  fi

else
  echo " > Exiting ..."
  exit 1

fi

# Secure mysql installation
# TODO: Unattended
# https://gist.github.com/coderua/5592d95970038944d099
# https://gist.github.com/Mins/4602864
# https://stackoverflow.com/questions/24270733/automate-mysql-secure-installation-with-echo-command-via-a-shell-script
sudo mysql_secure_installation