#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Ref: https://github.com/wordfence/wordfence-cli
#

################################################################################
# Worfence-cli installer (docker)
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function wordfencecli_installer () {

  # Check if the pinned Wordfence image exists
  if ! docker image inspect "${WORDFENCECLI_IMAGE}" > /dev/null 2>&1; then

    # Dependencies
    package_install_if_not "git"
    package_install_if_not "docker"

    log_subsection "Wordfence-cli Installer"

    if ! build_wordfencecli_docker_image; then
      display --indent 6 --text "- Installing Wordfence-cli" --result "ERROR" --color RED
      return 1
    fi

    clear_previous_lines "2"

    # Log
    log_event "info" "Wordfence-cli installer finished" "false"
    display --indent 6 --text "- Installing Wordfence-cli" --result "DONE" --color GREEN
    
    # Ask for license
    read -r -p "Enter Wordfence-cli license key: " wordfencecli_license_key
    wordfencecli_write_license "${wordfencecli_license_key}" || return 1


  else

    # Update
    wordfencecli_updater

  fi

}

################################################################################
# Worfence-cli updater (docker)
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function wordfencecli_updater () {

  log_subsection "Wordfence-cli"

  display --indent 6 --text "- Updating Wordfence-cli"
  if ! build_wordfencecli_docker_image; then
    display --indent 6 --text "- Updating Wordfence-cli" --result "ERROR" --color RED
    return 1
  fi

  # Log
  clear_previous_lines "2"
  log_event "info" "Wordfence-cli update finished" "false"
  display --indent 6 --text "- Updating Wordfence-cli" --result "DONE" --color GREEN

}

################################################################################
# Worfence-cli uninstaller (docker)
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function wordfencecli_uninstall() {
  
    log_subsection "Wordfence-cli Uninstaller"
  
    # Check if the Wordfence image exists
    if docker image inspect "${WORDFENCECLI_IMAGE}" > /dev/null 2>&1 || docker image inspect wordfence-cli:latest > /dev/null 2>&1; then
  
      # Remove wordfence-cli
      display --indent 6 --text "- Removing Wordfence-cli"
      log_event "debug" "Removing Wordfence CLI image tags" "false"
      docker image rm "${WORDFENCECLI_IMAGE}" wordfence-cli:latest || return 1
      
      clear_previous_lines "2"
      display --indent 6 --text "- Removing Wordfence-cli" --result "DONE" --color GREEN
  
      # Log
      log_event "info" "Wordfence-cli uninstaller finished" "false"
      display --indent 6 --text "- Uninstalling Wordfence-cli" --result "DONE" --color GREEN
  
    else
  
      # Log
      log_event "error" "Wordfence-cli not installed" "false"
      display --indent 6 --text "- Wordfence-cli not installed" --result "ERROR" --color RED

      return 1
  
    fi
    
}
