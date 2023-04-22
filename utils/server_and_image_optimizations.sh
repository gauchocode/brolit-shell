#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.0-beta
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
    "01)" "IMAGE OPTIMIZATION"
    "02)" "DELETE OLD LOGS"
    "03)" "REMOVE OLD PACKAGES"
    "04)" "REDUCE RAM USAGE"
    #"05)" "PDF OPTIMIZATION"
  )
  chosen_server_optimizations_options=$(whiptail --title "SERVER OPTIMIZATIONS" --menu "\n" 20 78 10 "${server_optimizations_options[@]}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    [[ ${chosen_server_optimizations_options} == *"01"* ]] && optimize_images_complete

    [[ ${chosen_server_optimizations_options} == *"02"* ]] && delete_old_logs

    [[ ${chosen_server_optimizations_options} == *"03"* ]] && packages_remove_old

    [[ ${chosen_server_optimizations_options} == *"04"* ]] && optimize_ram_usage

    if [[ ${chosen_server_optimizations_options} == *"05"* ]]; then
      # TODO: pdf optimization
      # Ref: https://github.com/or-yarok/reducepdf

      optimize_pdfs

    fi

  fi

}
