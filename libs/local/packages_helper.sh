#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc5
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
  display --indent 6 --text "- Adding repos and updating package lists"
  log_event "info" "Adding repos and updating package lists ..." "false"

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
    clear_previous_lines "1"
    display --indent 6 --text "- Updating packages list" --result "DONE" --color GREEN

    return 0

  else

    # Log
    clear_previous_lines "1"
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

  local package="${1}"

  local bin_path

  if [[ "$(dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -c "ok installed")" == "1" ]]; then

    bin_path="$(command -v "${package}" 2>/dev/null)"

    log_event "debug" "${package} is installed on: ${bin_path}" "false"

    # Return
    echo "${bin_path}"

    return 0

  else

    log_event "info" "${package} is not installed" "false"

    # Return
    return 1

  fi

}

################################################################################
# Install package with apt.
#
# Arguments:
#   $1 = ${package}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function package_install() {

  local package="${1}"

  # Log
  display --indent 6 --text "- Installing ${package}"
  log_event "info" "Installing ${package} ..." "false"

  # Will remove all apt-get command output
  # sudo DEBIAN_FRONTEND=noninteractive apt-get install PACKAGE -y -qq < /dev/null > /dev/null

  # apt command
  sudo DEBIAN_FRONTEND=noninteractive apt-get --yes install "${package}" -qq < /dev/null > /dev/null

  exitstatus=$?
  if [[ $exitstatus -eq 0 ]]; then

    # Log
    clear_previous_lines "1"
    log_event "info" "Package ${package} installed" "false"
    display --indent 6 --text "- Installing ${package}" --result "DONE" --color GREEN

    return 0

  else

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Installing ${package}" --result "WARNING" --color YELLOW
    display --indent 8 --text "Package is already installed."
    log_event "error" "Installing ${package}. Package is already installed." "false"

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

  local package="${1}"

  local pkg_bin

  # Check if package is installed
  pkg_bin="$(package_is_installed "${package}")"

  exitstatus=$?
  if [[ ${exitstatus} -eq 1 ]]; then

    package_install "${package}"

  else

    log_event "debug" "${package} is already installed. Package binary on: ${pkg_bin}" "false"

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

function package_check_required() {

  log_subsection "Package Manager"

  log_event "info" "Checking required packages ..." "false"

  # Install packages if not
  package_install_if_not "pv"
  package_install_if_not "bc"
  package_install_if_not "lbzip2"
  package_install_if_not "zip"
  package_install_if_not "unzip"
  package_install_if_not "git"
  package_install_if_not "whois"
  package_install_if_not "dnsutils"
  package_install_if_not "net-tools"
  package_install_if_not "sendemail"
  package_install_if_not "libio-socket-ssl-perl"
  package_install_if_not "ncdu"
  package_install_if_not "ppa-purge"

  # Log
  display --indent 6 --text "- Checking script dependencies" --result "DONE" --color GREEN
  log_event "info" "All required packages are installed" "false"

  # Break and space
  log_break "true"
  echo ""

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

function packages_remove_old() {

  # Log
  display --indent 6 --text "- Cleanning old system packages"
  log_event "info" "Cleanning old system packages ..." "false"

  # apt commands
  apt-get --yes clean -qq >/dev/null
  apt-get --yes autoremove -qq >/dev/null
  apt-get --yes autoclean -qq >/dev/null

  # Log
  clear_previous_lines "1"
  display --indent 6 --text "- Cleanning old system packages" --result "DONE" --color GREEN
  log_event "info" "Old system packages cleaned" "false"

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

  log_subsection "Package Manager"

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

  log_subsection "Package Manager"

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
  clear_previous_lines "1"
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

  local package="${1}"

  # Log
  log_event "info" "Uninstalling ${package} ..." "false"
  display --indent 6 --text "- Uninstalling ${package}"

  # Uninstalling packages
  apt-get --yes purge "${package}" -qq >/dev/null

  # Log
  clear_previous_lines "1"
  display --indent 6 --text "- Uninstalling ${package}" --result "DONE" --color GREEN

}
