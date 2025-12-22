#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.5
################################################################################
#
# Server and image optimizations Manager.
#
################################################################################

################################################################################
# Menu for server optimizations
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function server_optimizations_menu() {

  local server_optimizations_options
  local chosen_server_optimizations_options

  server_optimizations_options=(
    "01)" "DELETE OLD LOGS"
    "02)" "REMOVE OLD PACKAGES"
    "03)" "REDUCE RAM USAGE"
  )
  chosen_server_optimizations_options=$(whiptail --title "SERVER OPTIMIZATIONS" --menu "\n" 20 78 10 "${server_optimizations_options[@]}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    [[ ${chosen_server_optimizations_options} == *"01"* ]] && delete_old_logs

    [[ ${chosen_server_optimizations_options} == *"02"* ]] && packages_remove_old

    [[ ${chosen_server_optimizations_options} == *"03"* ]] && optimize_ram_usage

  fi

}
