#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.43
################################################################################

function server_optimizations_menu() {

  local server_optimizations_options
  local chosen_server_optimizations_options

  server_optimizations_options=(
    "01)" "IMAGE OPTIMIZATION" 
    "02)" "PDF OPTIMIZATION" 
    "03)" "DELETE OLD LOGS" 
    "04)" "REMOVE OLD PACKAGES" 
    "05)" "REDUCE RAM USAGE"
  )
  chosen_server_optimizations_options=$(whiptail --title "SERVER OPTIMIZATIONS" --menu "\n" 20 78 10 "${server_optimizations_options[@]}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_server_optimizations_options} == *"01"* ]]; then

      optimize_images_complete

    fi
    if [[ ${chosen_server_optimizations_options} == *"02"* ]]; then
      # TODO: pdf optimization
      # Ref: https://github.com/or-yarok/reducepdf

      optimize_pdfs

    fi
    if [[ ${chosen_server_optimizations_options} == *"03"* ]]; then
      # Remove old log files from system
      delete_old_logs

    fi
    if [[ ${chosen_server_optimizations_options} == *"04"* ]]; then
      # Remove old packages from system
      remove_old_packages

    fi
    if [[ ${chosen_server_optimizations_options} == *"05"* ]]; then

      optimize_ram_usage

    fi

  fi

}
