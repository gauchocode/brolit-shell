#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.67
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

function certbot_installer() {

  log_subsection "Certbot Installer"

  # Updating Repos
  display --indent 6 --text "- Updating repositories"
  apt-get --yes update -qq >/dev/null
  clear_last_line
  display --indent 6 --text "- Updating repositories" --result "DONE" --color GREEN

  # Installing Certbot
  display --indent 6 --text "- Installing certbot and dependencies"
  log_event "info" "Installing python3-certbot-dns-cloudflare and python3-certbot-nginx" "false"

  # apt command
  apt-get --yes install python3-certbot python3-certbot-dns-cloudflare python3-certbot-nginx -qq >/dev/null

  # Log
  clear_last_line
  display --indent 6 --text "- Installing certbot and dependencies" --result "DONE" --color GREEN
  log_event "info" "certbot installation finished" "false"

}

function certbot_purge() {

  log_subsection "Certbot Installer"

  # Log
  display --indent 6 --text "- Removing certbot and libraries"
  log_event "info" "Removing certbot and libraries..." "false"

  # apt command
  apt-get --yes purge python3-certbot python3-certbot-dns-cloudflare python3-certbot-nginx -qq >/dev/null

  # Log
  clear_last_line
  display --indent 6 --text "- Removing certbot and libraries" --result "DONE" --color GREEN
  log_event "info" "certbot removed" "false"

}

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
