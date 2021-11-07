#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.70-beta
################################################################################
#
# Packages Helper: Perform apt actions.
#
################################################################################

################################################################################
# Add PPA
#
# Arguments:
#   $@ - list of ppas
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function add_ppa() {

  # Log
  log_event "info" "Adding repos and updating package lists ..." "false"
  display --indent 6 --text "- Adding repos and updating package lists"

  # It provides some useful scripts for adding and removing PPA
  apt-get --yes install software-properties-common >/dev/null

  # Updating packages lists
  apt-get --yes update -qq >/dev/null

  for i in "$@"; do

    grep -h "^deb.*$i" /etc/apt/sources.list.d/* >/dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -ne 0 ]]; then

      log_event "info" "Adding ppa:$i" "false"

      add-apt-repository -y ppa:"${i}"

    else

      log_event "info" "ppa:${i} already installed" "false"

    fi

  done

}

################################################################################
# Updating packages list.
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function package_update() {

  # Log
  log_event "info" "Updating packages list ..." "false"
  display --indent 6 --text "- Updating packages list"

  # Update packages
  apt-get --yes update -qq >/dev/null

  exitstatus=$?
  if [[ $exitstatus -eq 0 ]]; then

    # Log
    clear_last_line
    display --indent 6 --text "- Updating packages list" --result "DONE" --color GREEN

    return 0

  else

    # Log
    clear_last_line
    display --indent 6 --text "- Updating packages list" --result "FAIL" --color RED

    return 1

  fi

}

################################################################################
# Check if package is installed. Ex: package_is_installed "mysql-server"
#
# Arguments:
#   $1 = ${package}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function package_is_installed() {

  local package=$1

  if [[ "$(dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -c "ok installed")" == "1" ]]; then

    log_event "info" "${package} is installed" "false"

    # Return
    return 0

  else

    log_event "info" "${package} is not installed" "false"

    # Return
    return 1

  fi

}

function package_install() {

  # Log
  log_event "info" "Installing ${package} ..." "false"
  display --indent 2 --text "- Installing ${package}"

  # apt command
  apt-get --yes install "${package}" -qq >/dev/null

  exitstatus=$?
  if [[ $exitstatus -eq 0 ]]; then

    # Log
    clear_last_line
    log_event "info" "Package ${package} installed" "false"
    display --indent 2 --text "- Installing ${package}" --result "DONE" --color GREEN

    return 0

  else

    # Log
    clear_last_line
    log_event "error" "Installing ${package}. Package is already installed." "false"
    display --indent 2 --text "- Installing ${package}" --result "WARNING" --color YELLOW
    display --indent 4 --text "Package is already installed."

    return 1

  fi
}

################################################################################
# Install package if not.
#
# Arguments:
#   $1 = ${package}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function package_install_if_not() {

  local package=$1

  # Check if package is installed
  package_is_installed "${package}"

  exitstatus=$?
  if [[ ${exitstatus} -eq 1 ]]; then

    package_install "${package}"

  fi

}

################################################################################
# Check package required (and install it)
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# TODO: need a refactor
function package_check_required() {

  #log_section "Script Package Manager"

  log_event "info" "Checking required packages ..." "false"

  # Globals
  declare -g TAR
  declare -g FIND

  # Install packages if not
  package_install_if_not "pv"
  package_install_if_not "bc"
  package_install_if_not "jq"
  package_install_if_not "lbzip2"
  package_install_if_not "zip"
  package_install_if_not "unzip"
  package_install_if_not "git"
  package_install_if_not "vim"
  package_install_if_not "dnsutils"
  package_install_if_not "net-tools"
  package_install_if_not "sendemail"
  package_install_if_not "libio-socket-ssl-perl"
  package_install_if_not "bat"
  package_install_if_not "ncdu"
  package_install_if_not "ppa-purge"

  # TAR
  TAR="$(command -v tar)"

  # FIND
  FIND="$(command -v find)"

  # Log
  display --indent 2 --text "- Checking script dependencies" --result "DONE" --color GREEN
  log_event "info" "All required packages are installed" "false"

}

function package_check_optionals() {

  # Globals
  declare -g MYSQL
  declare -g MYSQLDUMP
  declare -g PHP
  declare -g CERTBOT

  # CERTBOT
  CERTBOT="$(command -v certbot)"

  if [[ ! -x "${CERTBOT}" ]]; then

    certbot_installer

    #display --indent 2 --text "- Checking CERTBOT installation" --result "WARNING" --color YELLOW
    #display --indent 4 --text "CERTBOT not found" --tcolor YELLOW

    #return 1

  fi

  # MySQL
  MYSQL="$(command -v mysql)"

  if [[ ! -x ${MYSQL} && "${SERVER_ROLE_DATABASE}" == "enabled" ]]; then

    display --indent 2 --text "- Checking MySQL installation" --result "WARNING" --color YELLOW
    display --indent 4 --text "MySQL not found" --tcolor RED

  else

    MYSQLDUMP="$(command -v mysqldump)"

    if [[ -f ${MYSQL_CONF} ]]; then
      # Append login parameters to command
      MYSQL_ROOT="${MYSQL} --defaults-file=${MYSQL_CONF}"
      MYSQLDUMP_ROOT="${MYSQLDUMP} --defaults-file=${MYSQL_CONF}"

    fi

  fi

  # PHP
  PHP="$(command -v php)"

  if [[ ! -x "${PHP}" && "${SERVER_ROLE_WEBSERVER}" == "enabled" ]]; then

    # Log
    display --indent 2 --text "- Checking PHP installation" --result "WARNING" --color YELLOW
    display --indent 4 --text "PHP not found" --tcolor RED

  fi

}

################################################################################
# Timezone configuration
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# TODO: move to system_helper.sh ?
function timezone_configuration() {

  # Configure timezone
  local configured_timezone

  configured_timezone="$(cat /etc/timezone)"

  if [[ "${configured_timezone}" != "${SERVER_TIMEZONE}" ]]; then

    echo "${SERVER_TIMEZONE}" | tee /etc/timezone
    dpkg-reconfigure --frontend noninteractive tzdata

    # Log
    clear_last_line
    log_event "info" "Setting Timezone: ${SERVER_TIMEZONE}" "false"
    display --indent 6 --text "- Timezone configuration" --result "DONE" --color GREEN
    display --indent 8 --text "${SERVER_TIMEZONE}"

  fi

}

################################################################################
# Remove old packages
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function remove_old_packages() {

  # Log
  log_event "info" "Cleanning old system packages ..." "false"
  display --indent 6 --text "- Cleanning old system packages"

  # apt commands
  apt-get --yes clean -qq >/dev/null
  apt-get --yes autoremove -qq >/dev/null
  apt-get --yes autoclean -qq >/dev/null

  # Log
  clear_last_line
  log_event "info" "Old system packages cleaned" "false"
  display --indent 6 --text "- Cleanning old system packages" --result "DONE" --color GREEN

}

################################################################################
# Install packages for image and pdf optimization
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function package_install_optimization_utils() {

  package_install_if_not "jpegoptim"
  package_install_if_not "optipng"
  package_install_if_not "pngquant"
  package_install_if_not "webp"
  package_install_if_not "gifsicle"
  package_install_if_not "ghostscript"
  package_install_if_not "mogrify"
  package_install_if_not "imagemagick-*"

}

################################################################################
# Installs security utils: clamav and lynis
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function package_install_security_utils() {

  package_install_if_not "clamav"
  package_install_if_not "clamav-freshclam"
  package_install_if_not "lynis"

}

################################################################################
# List packages that need to be upgraded
#
# Arguments:
#   none
#
# Outputs:
#   list of packages.
################################################################################

function packages_need_upgrade() {

  # Log
  log_event "debug" "Running: apt list --upgradable" "false"
  display --indent 6 --text "- Checking upgradable packages"

  # apt commands
  pkgs="$(apt list --upgradable 2>/dev/null | awk -F/ "{print \$1}" | sed -e '1,/.../ d')"

  echo "${pkgs}"

}

################################################################################
# Upgrade system packages
#
# Arguments:
#   none
#
# Outputs:
#   none
################################################################################

function package_upgrade_all() {

  # Log
  log_event "info" "Upgrading packages ..." "false"
  display --indent 6 --text "- Upgrading packages"

  # apt commands
  apt-get --yes upgrade -qq >/dev/null

  # Log
  clear_last_line
  display --indent 6 --text "- Upgrading packages" --result "DONE" --color GREEN

}

################################################################################
# Purge package
#
# Arguments:
#   $1 = ${package}
#
# Outputs:
#   none
################################################################################

function package_purge() {

  # Log
  log_event "info" "Uninstalling ${package} ..." "false"
  display --indent 6 --text "- Uninstalling ${package}"

  # Uninstalling packages
  apt-get --yes purge "${package}" -qq >/dev/null

  # Log
  clear_last_line
  display --indent 6 --text "- Uninstalling ${package}" --result "DONE" --color GREEN

}
