#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc03
#############################################################################

source "${SFOLDER}/libs/commons.sh"

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
  cp ../confs/mysql/override.conf /etc/systemd/system/mysqld.service.d/override.conf
  cp ../confs/mysql/mysql /etc/init.d/mysql
  chmod +x /etc/init.d/mysql
  systemctl daemon-reload
  systemctl unmask mysql.service
  systemctl restart mysql

}

mariadb_default_installer() {
  echo " > LEMP installation with MariaDB ..." >>$LOG
  apt --yes install mariadb-server mariadb-client
}

#mariadb_official_installer() {
#  # TODO: https://www.linuxbabe.com/mariadb/install-mariadb-ubuntu-18-04-18-10
#
#}

mysql_purge_installation() {
  echo " > Removing MySQL ..." >>$LOG
  apt --yes purge mysql-server

}

mysql_check_if_installed() {

  MYSQL="$(which mysql)"
  if [ ! -x "${MYSQL}" ]; then
    mysql_installed="false"
  fi

}

mysql_check_installed_version() {
  mysql --version | awk '{ print $5 }' | awk -F\, '{ print $1 }'

}

################################################################################

mysql_installed="true"
mysql_check_if_installed

if [ ${mysql_installed} == "false" ]; then

  MYSQL_INSTALLER_OPTIONS="01 MYSQL_STANDARD 02 MYSQL_8 03 MARIADB_STANDARD"
  CHOSEN_MYSQL_INSTALLER_OPTION=$(whiptail --title "MySQL INSTALLER" --menu "Choose a MySQL version to install" 20 78 10 $(for x in ${MYSQL_INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
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

    # Secure mysql installation
    # TODO: Unattended
    # https://gist.github.com/coderua/5592d95970038944d099
    # https://gist.github.com/Mins/4602864
    # https://stackoverflow.com/questions/24270733/automate-mysql-secure-installation-with-echo-command-via-a-shell-script
    mysql_secure_installation

  else
    echo -e ${CYAN}" > Operation cancelled ..."${ENDCOLOR}
    exit 1

  fi

else

  echo -e ${MAGENTA}" > Mysql already installed ..."${ENDCOLOR}

fi
