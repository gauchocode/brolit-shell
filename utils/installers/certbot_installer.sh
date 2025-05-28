#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.10
################################################################################
#
# Certbot Installer: certbot installer functions.
#
################################################################################

################################################################################
# Check if certbot is installed.
#
# Arguments:
#   none
#
# Outputs:
#   0 if certbot was installed, 1 on error.
################################################################################

function certbot_check_if_installed() {

  local certbot_installed
  local certbot

  certbot="$(command -v certbot)"
  if [[ ! -x "${certbot}" ]]; then
    certbot_installed="false"

  else
    certbot_installed="true"

  fi

  log_event "debug" "certbot_installed=${certbot_installed}" "false"

  # Return
  echo "${certbot_installed}"

}

################################################################################
# Certbot Installer.
#
# Arguments:
#   none
#
# Outputs:
#   0 if certbot was installed, 1 on error.
################################################################################

function certbot_installer() {

  log_subsection "Certbot Installer"

  display --indent 6 --text "- Updating repositories"

  # Update repositories
  package_update

  clear_previous_lines "1"
  display --indent 6 --text "- Updating repositories" --result "DONE" --color GREEN

  # Installing Certbot
  display --indent 6 --text "- Installing certbot and dependencies"

  package_install "python3-certbot"
  package_install "python3-certbot-dns-cloudflare"
  package_install "python3-certbot-nginx"

  exitstatus=$?
  if [[ ${exitstatus} -ne 0 ]]; then

    # Log
    clear_previous_lines "2"
    display --indent 6 --text "- Installing certbot and dependencies" --result "FAILED" --color RED
    log_event "error" "Installing python3-certbot-dns-cloudflare and python3-certbot-nginx" "false"

    return 1

  else

    # Log
    clear_previous_lines "2"
    display --indent 6 --text "- Installing certbot and dependencies" --result "DONE" --color GREEN
    log_event "info" "Certbot installation finished" "false"

    return 0

  fi

}

################################################################################
# Uninstall Certbot.
#
# Arguments:
#   none
#
# Outputs:
#   0 if certbot was installed, 1 on error.
################################################################################

function certbot_purge() {

  log_subsection "Certbot Installer"

  # apt command
  package_purge "python3-certbot python3-certbot-dns-cloudflare python3-certbot-nginx"

  return $?

}

################################################################################
# Certbot installer menu.
#
# Arguments:
#   none
#
# Outputs:
#   0 if certbot was installed, 1 on error.
################################################################################

function certbot_installer_menu() {

  local certbot_is_installed

  certbot_is_installed="$(certbot_check_if_installed)"

  if [[ ${certbot_is_installed} == "false" ]]; then

    certbot_installer_title="CERTBOT INSTALLER"
    certbot_installer_message="Choose an option to run:"
    certbot_installer_options=(
      "01)" "INSTALL CERTBOT"
    )

    chosen_certbot_installer_options="$(whiptail --title "${certbot_installer_title}" --menu "${certbot_installer_message}" 20 78 10 "${certbot_installer_options[@]}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${chosen_certbot_installer_options} == *"01"* ]]; then

        certbot_installer

      fi

    fi

  else

    certbot_installer_title="CERTBOT INSTALLER"
    certbot_installer_message="Choose an option to run:"
    certbot_installer_options=(
      "01)" "UNINSTALL CERTBOT"
    )

    chosen_certbot_installer_options="$(whiptail --title "${certbot_installer_title}" --menu "${certbot_installer_message}" 20 78 10 "${certbot_installer_options[@]}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${chosen_certbot_installer_options} == *"01"* ]]; then

        certbot_purge

      fi

    fi

  fi

}
