#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.55
#############################################################################

function mysql_default_installer() {

  log_subsection "MySQL Installer"

  log_event "info" "Running MySQL default installer" "false"

  apt-get --yes install mysql-server -qq >/dev/null

  display --indent 6 --text "- MySQL default installation" --result "DONE" --color GREEN

}

function mariadb_default_installer() {

  log_subsection "MySQL Installer"

  log_event "info" "Running MariaDB default installer" "false"

  apt-get --yes install mariadb-server mariadb-client -qq >/dev/null

  display --indent 6 --text "- MariaDB default installation" --result "DONE" --color GREEN

}

function mysql_purge_installation() {

  log_event "warning" "Purging mysql-* packages ..." "false"
  display --indent 6 --text "- Purging MySQL packages"

  apt-get --yes purge mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* -qq >/dev/null
  rm --recursive --force /etc/mysql /var/lib/mysql
  apt-get autoremove -qq >/dev/null
  apt-get autoclean -qq >/dev/null

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

function mysql_initial_config() {

    local query_1
    local query_2
    local query_3
    local query_4
    local query_5
    local query_6
    local root_pass
    
    log_event "info" "Running mysql_initial_config" "false"

    root_pass="$(mysql_ask_root_psw)"

    # Queries
    ## -- set root password
    query_1="UPDATE mysql.user SET Password=PASSWORD('${root_pass}') WHERE User='root';"
    ## -- delete anonymous users
    query_2="DELETE FROM mysql.user WHERE User='';"
    # -- delete remote root capabilities
    query_3="DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    # -- drop database 'test'
    query_4="DROP DATABASE IF EXISTS test;"
    # -- also make sure there are lingering permissions to it
    query_5="DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    # -- make changes immediately
    query_6="FLUSH PRIVILEGES;"

    # Execute command
    mysql -sfu root -e "${query_1}${query_2}${query_3}${query_4}${query_5}${query_6}"

}

function mysql_installer_menu() {

  local mysql_installed
  local mysql_installer_options
  local chosen_mysql_installer_option

  mysql_installed="true"

  mysql_check_if_installed

  if [[ ${mysql_installed} == "false" ]]; then

    mysql_installer_options=(
      "01)" "INSTALL MARIADB"
      "02)" "INSTALL MYSQL"
    )

    chosen_mysql_installer_option="$(whiptail --title "MySQL INSTALLER" --menu "Choose a MySQL version to install" 20 78 10 "${mysql_installer_options[@]}" 3>&1 1>&2 2>&3)"
    
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${chosen_mysql_installer_option} == *"01"* ]]; then
        mariadb_default_installer

      fi
      if [[ ${chosen_mysql_installer_option} == *"02"* ]]; then
        mysql_default_installer

      fi

      # Secure mysql installation
      # mysql_secure_installation
      mysql_initial_config

    else
      log_event "warning" "Operation cancelled" "false"
      return 1

    fi

  else

    while true; do

      echo -e "${YELLOW}${ITALIC} > MySQL already installed, do you want to remove it?${ENDCOLOR}"
      read -p "Please type 'y' or 'n'" yn

      case $yn in
      [Yy]*)
        clear_last_line
        clear_last_line
        mysql_purge_installation
        break
        ;;

      [Nn]*)
        clear_last_line
        clear_last_line
        log_event "warning" "Operation cancelled" "false"
        break
        ;;

      *) echo " > Please answer yes or no." ;;
      esac

    done

  fi

}
