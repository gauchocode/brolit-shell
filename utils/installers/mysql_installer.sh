#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc10
#############################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

mysql_default_installer() {

  log_section "MySQL Installer"

  log_event "info" "Running MySQL default installer" "false"

  apt --yes install mysql-server
  
  display --indent 2 --text "- MySQL default installation" --result "DONE" --color GREEN

}

mariadb_default_installer() {
  
  log_section "MySQL Installer"

  log_event "info" "Running MariaDB default installer" "false"

  apt --yes install mariadb-server mariadb-client -qq

  display --indent 2 --text "- MariaDB default installation" --result "DONE" --color GREEN

}

mysql_purge_installation() {

  log_event "warning" "Purging mysql-* packages ..." "true"

  apt --yes purge mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-*
  rm -rf /etc/mysql /var/lib/mysql
  apt-get autoremove
  apt-get autoclean

  log_event "info" "mysql-* packages purged!" "true"

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

  MYSQL_INSTALLER_OPTIONS="01 INSTALL_MYSQL 02 INSTALL_MARIADB"
  CHOSEN_MYSQL_INSTALLER_OPTION=$(whiptail --title "MySQL INSTALLER" --menu "Choose a MySQL version to install" 20 78 10 $(for x in ${MYSQL_INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${CHOSEN_MYSQL_INSTALLER_OPTION} == *"01"* ]]; then
      mysql_default_installer

    fi
    if [[ ${CHOSEN_MYSQL_INSTALLER_OPTION} == *"02"* ]]; then
      mariadb_default_installer

    fi

    # Secure mysql installation
    mysql_secure_installation

  else
    log_event "warning" "Operation cancelled" "true"
    return 1

  fi

else

  while true; do

      echo -e ${YELLOW}" > MySQL already installed, do you want to remove it?"${ENDCOLOR}
      read -p "Please type 'y' or 'n'" yn

      case $yn in
          [Yy]* )
          mysql_purge_installation
          break;;
                 
          [Nn]* )
          log_event "warning" "Operation cancelled" "true"
          break;;
          * ) echo " > Please answer yes or no.";;
      esac
  done


fi
