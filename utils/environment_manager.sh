#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.6
################################################################################
#
# Environment Manager: Main menu for managing host and Docker environments.
#
################################################################################

################################################################################
# Environment Manager Main Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function environment_manager_menu() {

  local env_manager_options
  local chosen_env_manager_option

  log_section "Environment Manager"

  env_manager_options=(
    "01)" "HOST ENVIRONMENT"
    "02)" "DOCKER CONTAINERS"
  )

  chosen_env_manager_option="$(whiptail --title "ENVIRONMENT MANAGER" --menu "\nSelect environment to manage:\n" 20 78 10 "${env_manager_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # HOST ENVIRONMENT
    if [[ ${chosen_env_manager_option} == *"01"* ]]; then
      # shellcheck source=${BROLIT_MAIN_DIR}/utils/environment_manager_host.sh
      source "${BROLIT_MAIN_DIR}/utils/environment_manager_host.sh"
      environment_manager_host_menu
    fi

    # DOCKER CONTAINERS
    if [[ ${chosen_env_manager_option} == *"02"* ]]; then
      # shellcheck source=${BROLIT_MAIN_DIR}/utils/environment_manager_docker.sh
      source "${BROLIT_MAIN_DIR}/utils/environment_manager_docker.sh"
      environment_manager_docker_menu
    fi

    # Return to this menu
    prompt_return_or_finish
    environment_manager_menu

  fi

  # Return to main menu
  menu_main_options

}
