#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc07
#############################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

mysql_default_installer() {
  echo " > LEMP installation with MySQL ..." >>$LOG
  apt --yes install mysql-server

}

mariadb_default_installer() {
  echo " > LEMP installation with MariaDB ..." >>$LOG
  apt --yes install mariadb-server mariadb-client
}

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

  MYSQL_INSTALLER_OPTIONS="01 MYSQL_STANDARD 02 MARIADB_STANDARD"
  CHOSEN_MYSQL_INSTALLER_OPTION=$(whiptail --title "MySQL INSTALLER" --menu "Choose a MySQL version to install" 20 78 10 $(for x in ${MYSQL_INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${CHOSEN_MYSQL_INSTALLER_OPTION} == *"01"* ]]; then
      mysql_default_installer

    fi
    if [[ ${CHOSEN_MYSQL_INSTALLER_OPTION} == *"02"* ]]; then
      mariadb_default_installer

    fi

    # TODO: Unattended
    # https://gist.github.com/coderua/5592d95970038944d099
    # https://gist.github.com/Mins/4602864
    # https://stackoverflow.com/questions/24270733/automate-mysql-secure-installation-with-echo-command-via-a-shell-script
    
    # Secure mysql installation
    mysql_secure_installation

  else
    echo -e ${CYAN}" > Operation cancelled ..."${ENDCOLOR}
    exit 1

  fi

else

  while true; do

      echo -e ${YELLOW}" > MySQL already installed, do you want to remove it?"${ENDCOLOR}
      read -p "Please type 'y' or 'n'" yn

      case $yn in
          [Yy]* )

          echo " > Purging mysql-* packages ..." >>$LOG
          echo -e ${CYAN}" > Purging mysql-* packages ..."${ENDCOLOR}

          sudo apt-get purge mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
          sudo rm -rf /etc/mysql /var/lib/mysql
          sudo apt-get autoremove
          sudo apt-get autoclean

          break;;
          
          [Nn]* )
          echo -e ${B_RED}"Aborting monit installation script ..."${ENDCOLOR};
          break;;
          * ) echo " > Please answer yes or no.";;
      esac
  done


fi
