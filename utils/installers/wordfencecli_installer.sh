#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.4
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

  log_subsection "Wordfence-cli Installer"

  # Dependencies
  package_install_if_not "git"
  package_install_if_not "docker"

  # Download wordfence-cli
  display --indent 6 --text "- Downloading Wordfence-cli"
  log_event "debug" "Running: git clone git@github.com:wordfence/wordfence-cli.git /root/wordfence-cli" "false"
  
  git clone git@github.com:wordfence/wordfence-cli.git /root/wordfence-cli
  
  clear_previous_lines "2"
  display --indent 6 --text "- Downloading Wordfence-cli" --result "DONE" --color GREEN

  # Docker build
  docker build -t wordfence-cli:latest /root/wordfence-cli

  # Log
  log_event "info" "Wordfence-cli installer finished" "false"
  display --indent 6 --text "- Installing Wordfence-cli" --result "DONE" --color GREEN
  #log_break

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
  
  clear_previous_lines "2"
  display --indent 6 --text "- Updating Wordfence-cli" --result "DONE" --color GREEN

  # Docker build
  docker build -t wordfence-cli:latest /root/wordfence-cli

  # Log
  log_event "info" "Wordfence-cli update finished" "false"
  display --indent 6 --text "- Updating Wordfence-cli" --result "DONE" --color GREEN
  #log_break

}