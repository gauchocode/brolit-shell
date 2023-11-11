#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.6
#############################################################################
#
# Ref: https://certbot.eff.org/docs/using.html
#
#############################################################################

# Manager should only contains:
#   1- Menus functions
#   2- Sub-task handler function
#   3- User imput functions
#
# All other things should be on *_helper.sh

function certbot_manager_menu() {

  local domains
  local certbot_options
  local chosen_cb_options

  certbot_options=(
    "01)" "INSTALL CERTIFICATE"
    "02)" "EXPAND CERTIFICATE"
    "03)" "TEST RENEW ALL CERTIFICATES"
    "04)" "FORCE RENEW CERTIFICATE"
    "05)" "DELETE CERTIFICATE"
    "06)" "SHOW INSTALLED CERTIFICATES"
  )
  chosen_cb_options="$(whiptail --title "CERTBOT MANAGER" --menu " " 20 78 10 "${certbot_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_cb_options} == *"01"* ]]; then

      # INSTALL-CERTIFICATE
      domains="$(certbot_helper_ask_domains)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        certbot_helper_installer_menu "${NOTIFICATION_EMAIL_MAILA}" "${domains}"
      fi

    fi

    if [[ ${chosen_cb_options} == *"02"* ]]; then
      # EXPAND-CERTIFICATE
      domains="$(certbot_helper_ask_domains)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        certbot_certificate_expand "${NOTIFICATION_EMAIL_MAILA}" "${domains}"
      fi

    fi

    if [[ ${chosen_cb_options} == *"03"* ]]; then
      # TEST-RENEW-ALL-CERTIFICATES
      certbot_certificate_renew_test

    fi

    if [[ ${chosen_cb_options} == *"04"* ]]; then
      # FORCE-RENEW-CERTIFICATE
      domains="$(certbot_helper_ask_domains)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        certbot_certificate_force_renew "${domains}"
      fi

    fi

    if [[ ${chosen_cb_options} == *"05"* ]]; then
      # DELETE-CERTIFICATE
      certbot_certificate_delete "${domains}"

    fi

    if [[ ${chosen_cb_options} == *"06"* ]]; then
      # SHOW-INSTALLED-CERTIFICATES
      certbot_show_certificates_info

    fi

    prompt_return_or_finish
    certbot_manager_menu

  fi

  menu_main_options

}

function certbot_tasks_handler() {

    echo "TODO"

}