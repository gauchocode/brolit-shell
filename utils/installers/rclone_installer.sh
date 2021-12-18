#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.7
################################################################################

# TODO: Implement this...

function rclone_check_if_installed() {

  local rclone_installed
  local rclone

  rclone="$(command -v rclone)"
  if [[ ! -x "${rclone}" ]]; then
    rclone_installed="false"

  else
    rclone_installed="true"

  fi

  log_event "debug" "rclone_installed=${rclone_installed}"

  # Return
  echo "${rclone_installed}"

}

function rclone_installer() {

  log_subsection "Certbot Installer"

  # Updating Repos
  display --indent 6 --text "- Updating repositories"

  apt-get --yes update -qq >/dev/null

  clear_previous_lines "1"
  display --indent 6 --text "- Updating repositories" --result "DONE" --color GREEN

  # Installing Certbot
  display --indent 6 --text "- Installing rclone"
  log_event "info" "Installing rclone" "false"

  # apt command
  apt-get --yes install rclone -qq >/dev/null

  # Log
  clear_previous_lines "1"
  display --indent 6 --text "- Installing rclone" --result "DONE" --color GREEN
  log_event "info" "rclone installation finished"

}

function rclone_purge() {

  log_subsection "Certbot Installer"

  # Log
  display --indent 6 --text "- Removing rclone"
  log_event "info" "Removing rclone ..."

  # apt command
  apt-get --yes purge rclone -qq >/dev/null

  # Log
  clear_previous_lines "1"
  display --indent 6 --text "- Removing rclone" --result "DONE" --color GREEN
  log_event "info" "rclone removed" "false"

}

function rclone_installer_menu() {

  local rclone_is_installed

  rclone_is_installed="$(rclone_check_if_installed)"

  if [[ ${rclone_is_installed} == "false" ]]; then

    rclone_installer_title="RCLONE INSTALLER"
    rclone_installer_message="Choose an option to run:"
    rclone_installer_options=(
      "01)" "INSTALL RCLONE"
    )

    chosen_rclone_installer_options="$(whiptail --title "${rclone_installer_title}" --menu "${rclone_installer_message}" 20 78 10 "${rclone_installer_options[@]}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${chosen_rclone_installer_options} == *"01"* ]]; then

        rclone_installer

      fi

    fi

  else

    rclone_installer_title="RCLONE INSTALLER"
    rclone_installer_message="Choose an option to run:"
    rclone_installer_options=(
      "01)" "UNINSTALL RCLONE"
    )

    chosen_rclone_installer_options="$(whiptail --title "${rclone_installer_title}" --menu "${rclone_installer_message}" 20 78 10 "${rclone_installer_options[@]}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${chosen_rclone_installer_options} == *"01"* ]]; then

        rclone_purge

      fi

    fi

  fi

}