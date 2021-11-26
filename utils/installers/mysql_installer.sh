#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.5-beta
#############################################################################

function mysql_default_installer() {

  package_is_installed "mysql-server"

  exitstatus=$?
  if [ ${exitstatus} -eq 0 ]; then

    log_event "info" "MySQL is already installed" "false"

    return 1

  else

    log_subsection "MySQL Installer"

    log_event "info" "Running MySQL default installer" "false"

    apt-get --yes install mysql-server -qq >/dev/null

    display --indent 6 --text "- MySQL default installation" --result "DONE" --color GREEN

    return 0

  fi

}

function mariadb_default_installer() {

  package_is_installed "mariadb-server"

  exitstatus=$?
  if [ ${exitstatus} -eq 0 ]; then

    log_event "info" "MariaDB is already installed" "false"

    return 1

  else

    log_subsection "MariaDB Installer"

    log_event "info" "Running MariaDB default installer" "false"

    apt-get --yes install mariadb-server mariadb-client -qq >/dev/null

    display --indent 6 --text "- MariaDB default installation" --result "DONE" --color GREEN

    return 0

  fi

}

function mysql_purge_installation() {

  # Log
  log_event "warning" "Purging mysql-* packages ..." "false"
  display --indent 6 --text "- Purging MySQL packages"

  apt-get --yes purge mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* -qq >/dev/null
  rm --recursive --force /etc/mysql /var/lib/mysql
  apt-get autoremove -qq >/dev/null
  apt-get autoclean -qq >/dev/null

  # Log
  clear_previous_lines "1"
  log_event "info" "mysql-* packages purged!" "false"
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

