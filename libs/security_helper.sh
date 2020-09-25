#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.2
################################################################################
#
# Refs: https://www.tecmint.com/scan-linux-for-malware-and-rootkits/
#
################################################################################

security_install() {

  log_event "info" "Installing clamav and lynis" "false"
  display --indent 2 --text "- Installing clamav and lynis"

  apt-get --yes install clamav lynis -qq > /dev/null

  #clear_last_line
  display --indent 2 --text "- Installing clamav and lynis" --result "DONE" --color GREEN

}

security_clamav_scan() {

  # $1 = ${directory}

  local directory=$1

  # Stop service
  systemctl stop clamav-freshclam.service

  # Update clamav database
  freshclam

  # Run on specific directory with parameters:
  # -r recursive (Scan subdirectories recursively)
  # --infected (Only print infected files)
  log_event "info" "Running: clamscan -r --infected ${directory}" "false"
  clamscan -r --infected "${directory}"

}

security_system_audit() {

  lynis audit system

}

security_custom_scan() {

  # $1 = ${directory}

  local directory=$1

  log_event "info" "Running custom malware scanner" "false"
  display --indent 2 --text "- Running custom malware scanner"

  display --indent 2 --text "Result for base64_decode:"
  grep -lr --include=*.php "eval(base64_decode" "${directory}"

  display --indent 2 --text "Result for gzinflate:"
  grep -lr --include=*.php "gzinflate(" "${directory}"
  grep -lr --include=*.php "gzinflate (" "${directory}"

  display --indent 2 --text "Result for shell_exec:"
  grep -lr --include=*.php "shell_exec(" "${directory}"
  grep -lr --include=*.php "shell_exec (" "${directory}"

  display --indent 2 --text "- Custom malware scanner" --result "DONE" --color GREEN

}