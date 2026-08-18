#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.13
################################################################################
#
# Proxmox Manager: Menu for Proxmox VE node-only tasks. Only reachable from
# the main menu when brolit-shell is running directly on a Proxmox VE
# hypervisor (proxmox_node_detect), not inside a guest VM.
#
################################################################################

function proxmox_manager_menu() {

  local proxmox_options
  local chosen_proxmox_option

  log_section "Proxmox Manager"

  proxmox_options=(
    "01)" "PROVISION OPENRESTY GATEWAY VM"
  )

  chosen_proxmox_option="$(whiptail --title "PROXMOX TOOLS" --menu "Choose an option" 20 78 10 "${proxmox_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # PROVISION OPENRESTY GATEWAY VM
    if [[ ${chosen_proxmox_option} == *"01"* ]]; then

      local vm_name
      vm_name="$(whiptail --title "PROVISION OPENRESTY GATEWAY VM" --inputbox "Insert a name for the new VM:" 10 60 "brolit-openresty" 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        [[ -z "${vm_name}" ]] && vm_name="brolit-openresty"
        proxmox_provision_openresty_vm "${vm_name}"
      fi

    fi

    prompt_return_or_finish
    proxmox_manager_menu

  fi

  menu_main_options

}
