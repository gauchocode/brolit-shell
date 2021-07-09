#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.43
################################################################################

function fail2ban_check_if_installed() {

  local fail2ban_installed
  local fail2ban

  fail2ban="$(command -v fail2ban)"
  if [[ ! -x "${fail2ban}" ]]; then
    fail2ban_installed="false"

  else
    fail2ban_installed="true"

  fi

  log_event "debug" "fail2ban_installed=${fail2ban_installed}"

  # Return
  echo "${fail2ban_installed}"

}

function fail2ban_installer() {

  log_subsection "Fail2ban Installer"

  # Updating Repos
  display --indent 6 --text "- Updating repositories"
  apt-get --yes update -qq >/dev/null
  clear_last_line
  display --indent 6 --text "- Updating repositories" --result "DONE" --color GREEN

  # Installing fail2ban
  display --indent 6 --text "- Installing fail2ban and dependencies"
  log_event "info" "Installing fail2ban"

  # apt command
  apt-get --yes install fail2ban -qq >/dev/null

  # Log
  clear_last_line
  display --indent 6 --text "- Installing fail2ban and dependencies" --result "DONE" --color GREEN
  log_event "info" "fail2ban installation finished"

}

function fail2ban_purge() {

  log_subsection "Fail2ban Installer"

  # Log
  display --indent 6 --text "- Removing fail2ban and libraries"
  log_event "info" "Removing fail2ban and libraries ..."

  # apt command
  apt-get --yes purge fail2ban -qq >/dev/null

  # Log
  clear_last_line
  display --indent 6 --text "- Removing fail2ban and libraries" --result "DONE" --color GREEN
  log_event "info" "fail2ban removed"

}

function fail2ban_installer_menu() {

  local fail2ban_is_installed

  fail2ban_is_installed="$(fail2ban_check_if_installed)"

  if [[ ${fail2ban_is_installed} == "false" ]]; then

    fail2ban_installer_title="FAIL2BAN INSTALLER"
    fail2ban_installer_message="Choose an option to run:"
    fail2ban_installer_options=(
      "01)" "INSTALL FAIL2BAN"
    )

    chosen_fail2ban_installer_options="$(whiptail --title "${fail2ban_installer_title}" --menu "${fail2ban_installer_message}" 20 78 10 "${fail2ban_installer_options[@]}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${chosen_fail2ban_installer_options} == *"01"* ]]; then

        fail2ban_installer

      fi

    fi

  else

    fail2ban_installer_title="FAIL2BAN INSTALLER"
    fail2ban_installer_message="Choose an option to run:"
    fail2ban_installer_options=(
      "01)" "UNINSTALL FAIL2BAN"
    )

    chosen_fail2ban_installer_options="$(whiptail --title "${fail2ban_installer_title}" --menu "${fail2ban_installer_message}" 20 78 10 "${fail2ban_installer_options[@]}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${chosen_fail2ban_installer_options} == *"01"* ]]; then

        fail2ban_purge

      fi

    fi

  fi

}
