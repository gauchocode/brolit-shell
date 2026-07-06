#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
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
    "04)" "DISK CLEANUP"
  )
  chosen_server_optimizations_options=$(whiptail --title "SERVER OPTIMIZATIONS" --menu "\n" 20 78 10 "${server_optimizations_options[@]}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    [[ ${chosen_server_optimizations_options} == *"01"* ]] && delete_old_logs

    [[ ${chosen_server_optimizations_options} == *"02"* ]] && packages_remove_old

    [[ ${chosen_server_optimizations_options} == *"03"* ]] && optimize_ram_usage

    [[ ${chosen_server_optimizations_options} == *"04"* ]] && menu_disk_cleanup

  fi

}

################################################################################
# Menu for disk cleanup
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function menu_disk_cleanup() {

  local disk_cleanup_options
  local chosen_options

  disk_cleanup_options=(
    "01)" "APT CACHE" OFF
    "02)" "JOURNAL LOGS" OFF
    "03)" "DOCKER PRUNE" OFF
    "04)" "ALL (full cleanup)" OFF
  )

  chosen_options=$(whiptail --title "DISK CLEANUP" --checklist "Select items to clean" 20 78 10 "${disk_cleanup_options[@]}" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]] && [[ -n "${chosen_options}" ]]; then

    # Ask for dry-run
    if whiptail --title "DRY RUN" --yesno "Do you want to preview what would be freed first?" 10 60 3>&1 1>&2 2>&3; then
      DRY_RUN="true"
    else
      DRY_RUN="false"
    fi
    export DRY_RUN

    if [[ ${chosen_options} == *"01"* ]]; then
      clean_disk_apt
    fi
    if [[ ${chosen_options} == *"02"* ]]; then
      clean_disk_journal
    fi
    if [[ ${chosen_options} == *"03"* ]]; then
      clean_disk_docker
    fi
    if [[ ${chosen_options} == *"04"* ]]; then
      clean_disk_all
    fi

    # Reset dry-run
    DRY_RUN="false"

  fi

}
