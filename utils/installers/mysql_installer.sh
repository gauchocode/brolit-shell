#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc7
################################################################################

################################################################################
# MySQL installer
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function mysql_default_installer() {

  log_subsection "MySQL Installer"

  package_install "mysql-server"

}

################################################################################
# MySQL installer
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function mysql_mariadb_default_installer() {

  log_subsection "MariaDB Installer"

  package_install "mariadb-server"

}

################################################################################
# MySQL purge/remove installation
#
# Arguments:
#   none
#
# Outputs:
#   none
################################################################################

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

################################################################################
# MySQL check if is installed
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function mysql_check_if_installed() {

  MYSQL="$(which mysql)"

  if [[ ! -x ${MYSQL} ]]; then

    echo "false"
    return 1

  else

    echo "true"
    return 0

  fi

}

################################################################################
# MySQL check installed version
#
# Arguments:
#   none
#
# Outputs:
#   mysql version string
################################################################################

function mysql_check_installed_version() {

  mysql --version | awk '{ print $5 }' | awk -F\, '{ print $1 }'

}

################################################################################
# MySQL initial config
#
# Arguments:
#   $1 = ${project_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function mysql_initial_config() {

  local query_1
  local query_2
  local query_3
  local query_4
  local query_5
  local query_6
  local root_pass

  # Log
  log_event "info" "Running mysql_initial_config" "false"
  display --indent 6 --text "- MySQL initial configuration"

  # Ask new root password
  root_pass="$(mysql_ask_root_psw)"

  # Queries
  ## -- set root password
  #query_1="UPDATE mysql.user SET Password=PASSWORD('${root_pass}') WHERE User='root';"
  query_1="SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${root_pass}');"
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

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- MySQL initial configuration" --result "DONE" --color GREEN

    return 0

  else

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- MySQL initial configuration" --result "FAIL" --color RED

    return 1

  fi

}
