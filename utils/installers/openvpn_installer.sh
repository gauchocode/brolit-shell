#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.72
################################################################################
#
# OpenVPN Installer
#
#   Ref: https://tecadmin.net/install-openvpn-client-on-ubuntu/
#
################################################################################

################################################################################
# Check if openvpn is installed
#
# Arguments:
#   none
#
# Outputs:
#   true or false
################################################################################

function openvpn_check_if_installed() {

  local openvpn_installed
  local openvpn

  openvpn="$(command -v openvpn)"
  if [[ ! -x "${openvpn}" ]]; then
    openvpn_installed="false"

  else
    openvpn_installed="true"

  fi

  log_event "debug" "openvpn_installed=${openvpn_installed}" "false"

  # Return
  echo "${openvpn_installed}"

}

################################################################################
# OpenVPN installer
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function openvpn_installer() {

    log_subsection "OpenVPN Installer"

    # Updating Repos
    display --indent 6 --text "- Updating repositories"
    apt-get --yes update -qq >/dev/null
    clear_last_line
    display --indent 6 --text "- Updating repositories" --result "DONE" --color GREEN

    # Installing OpenVPN
    display --indent 6 --text "- Installing OpenVPN"
    log_event "info" "Installing openvpn" "false"

    # apt command
    apt-get --yes install openvpn -qq >/dev/null

    # Log
    clear_last_line
    display --indent 6 --text "- Installing OpenVPN" --result "DONE" --color GREEN
    log_event "info" "OpenVPN installation finished" "false"

}

################################################################################
# Purge OpenVPN packages
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function openvpn_purge() {

  log_subsection "OpenVPN Installer"

  # Log
  display --indent 6 --text "- Removing OpenVPN"
  log_event "info" "Removing OpenVPN ..." "false"

  # apt command
  apt-get --yes purge openvpn -qq >/dev/null

  # Log
  clear_last_line
  display --indent 6 --text "- Removing OpenVPN" --result "DONE" --color GREEN
  log_event "info" "openvpn removed" "false"

}

################################################################################
# OpenVPN installer menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function openvpn_installer_menu() {

  local openvpn_is_installed

  openvpn_is_installed="$(openvpn_check_if_installed)"

  if [[ ${openvpn_is_installed} == "false" ]]; then

    openvpn_installer_title="OPENVPN INSTALLER"
    openvpn_installer_message="Choose an option to run:"
    openvpn_installer_options=(
      "01)" "INSTALL OPENVPN"
    )

    chosen_openvpn_installer_options="$(whiptail --title "${openvpn_installer_title}" --menu "${openvpn_installer_message}" 20 78 10 "${openvpn_installer_options[@]}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${chosen_openvpn_installer_options} == *"01"* ]]; then

        openvpn_installer

      fi

    fi

  else

    openvpn_installer_title="OPENVPN INSTALLER"
    openvpn_installer_message="Choose an option to run:"
    openvpn_installer_options=(
      "01)" "UNINSTALL OPENVPN"
    )

    chosen_openvpn_installer_options="$(whiptail --title "${openvpn_installer_title}" --menu "${openvpn_installer_message}" 20 78 10 "${openvpn_installer_options[@]}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${chosen_openvpn_installer_options} == *"01"* ]]; then

        openvpn_purge

      fi

    fi

  fi

}
