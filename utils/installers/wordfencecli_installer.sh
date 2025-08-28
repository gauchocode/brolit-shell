#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.12
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

  # Check if wordfence-cli:latest not exists
  if [[ "$(docker images -q wordfence-cli:latest 2> /dev/null)" == "" ]]; then

    # Dependencies
    package_install_if_not "git"
    package_install_if_not "docker"

    log_subsection "Wordfence-cli Installer"

    # Log
    display --indent 6 --text "- Downloading Wordfence-cli"
    log_event "debug" "Running: git clone https://github.com/wordfence/wordfence-cli.git /root/wordfence-cli" "false"
    
    # Download wordfence-cli
    git clone https://github.com/wordfence/wordfence-cli.git /root/wordfence-cli > /dev/null 2>&1
    
    clear_previous_lines "2"
    display --indent 6 --text "- Downloading Wordfence-cli" --result "DONE" --color GREEN

    # Docker build (silent mode)
    docker build -t wordfence-cli:latest /root/wordfence-cli > /dev/null 2>&1

    # Log
    log_event "info" "Wordfence-cli installer finished" "false"
    display --indent 6 --text "- Installing Wordfence-cli" --result "DONE" --color GREEN
    
    # Ask for license
    read -p "Enter Wordfence-cli license key: " wordfencecli_license_key
    wordfencecli_write_license "${wordfencecli_license_key}"


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

  log_subsection "Wordfence-cli Updater"

  # Download wordfence-cli
  display --indent 6 --text "- Updating Wordfence-cli"
  log_event "debug" "Running: (cd /root/wordfence-cli && git pull)" "false"
  
  (cd /root/wordfence-cli && git pull)

  # Docker build (silent mode)
  docker build -t wordfence-cli:latest /root/wordfence-cli > /dev/null 2>&1

  # Log
  clear_previous_lines "1"
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
  
    # Check if wordfence-cli:latest exists
    if [[ "$(docker images -q wordfence-cli:latest 2> /dev/null)" != "" ]]; then
  
      # Remove wordfence-cli
      display --indent 6 --text "- Removing Wordfence-cli"
      log_event "debug" "Running: docker rmi wordfence-cli:latest" "false"
      
      docker rmi wordfence-cli:latest
      
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