#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.27
#############################################################################

function mysql_default_installer() {

  log_subsection "MySQL Installer"

  log_event "info" "Running MySQL default installer" "false"

  apt-get --yes install mysql-server -qq > /dev/null
  
  display --indent 6 --text "- MySQL default installation" --result "DONE" --color GREEN

}

function mariadb_default_installer() {
  
  log_subsection "MySQL Installer"

  log_event "info" "Running MariaDB default installer" "false"

  apt-get --yes install mariadb-server mariadb-client -qq > /dev/null

  display --indent 6 --text "- MariaDB default installation" --result "DONE" --color GREEN

}

function mysql_purge_installation() {

  log_event "warning" "Purging mysql-* packages ..." "false"
  display --indent 6 --text "- Purging MySQL packages"

  apt-get --yes purge mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* -qq > /dev/null
  rm -rf /etc/mysql /var/lib/mysql
  apt-get autoremove -qq > /dev/null
  apt-get autoclean -qq > /dev/null

  log_event "info" "mysql-* packages purged!" "false"
  clear_last_line
  display --indent 6 --text "- Purging MySQL packages" --result "DONE" --color GREEN

}

function mysql_check_if_installed() {

  MYSQL="$(which mysql)"
  if [[ ! -x "${MYSQL}" ]]; then
    mysql_installed="false"
  fi

}

function mysql_check_installed_version() {
  
  mysql --version | awk '{ print $5 }' | awk -F\, '{ print $1 }'

}

function mysql_installer_menu() {

  mysql_installed="true"
  mysql_check_if_installed

  if [[ ${mysql_installed} == "false" ]]; then

    MYSQL_INSTALLER_OPTIONS=(
      "01)" "INSTALL MARIADB" 
      "02)" "INSTALL MYSQL"
    )
    CHOSEN_MYSQL_INSTALLER_OPTION=$(whiptail --title "MySQL INSTALLER" --menu "Choose a MySQL version to install" 20 78 10 "${MYSQL_INSTALLER_OPTIONS[@]}" 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${CHOSEN_MYSQL_INSTALLER_OPTION} == *"01"* ]]; then
        mariadb_default_installer

      fi
      if [[ ${CHOSEN_MYSQL_INSTALLER_OPTION} == *"02"* ]]; then
        mysql_default_installer

      fi

      # Secure mysql installation
      mysql_secure_installation

    else
      log_event "warning" "Operation cancelled" "false"
      return 1

    fi

  else

    while true; do

        echo -e "${YELLOW}${ITALIC} > MySQL already installed, do you want to remove it?${ENDCOLOR}"
        read -p "Please type 'y' or 'n'" yn

        case $yn in
            [Yy]* )
              clear_last_line
              clear_last_line
              mysql_purge_installation
            break;;
                  
            [Nn]* )
              clear_last_line
              clear_last_line
              log_event "warning" "Operation cancelled" "false"
            break;;
            
            * ) echo " > Please answer yes or no.";;
        esac

    done

  fi

}