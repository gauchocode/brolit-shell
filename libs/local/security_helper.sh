#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.4
################################################################################
#
# Security Helper: Perform security actions.
#
#   Refs: https://www.tecmint.com/scan-linux-for-malware-and-rootkits/
#
################################################################################

################################################################################
# Clamav Scan: Update clamav database and performs a scan.
#
# Arguments:
#  ${1} = ${directory} - directory to scan
#
# Outputs:
#  Clamav result.
################################################################################

function security_clamav_scan() {

  local directory="${1}"

  local timestamp
  local report_file
  local clamscan_result

  timestamp="$(date +%Y%m%d_%H%M%S)"

  # Stop service
  systemctl stop clamav-freshclam.service

  # Update clamav database
  freshclam

  # Log
  log_subsection "Malware Scan"

  display --indent 6 --text "- Searching for malware"
  log_event "info" "Running clamscan on ${directory}" "false"

  report_file="${BROLIT_MAIN_DIR}/reports/clamav-results-${timestamp}.log"

  # Run on specific directory with parameters:
  # -r recursive (Scan subdirectories recursively)
  # --infected (Only print infected files)
  # --no-summary (Disable summary at end of scanning)

  log_event "debug" "Running: clamscan --recursive --infected --no-summary ${directory} | grep -i 'FOUND' >>${report_file}" "false"

  clamscan_result="$(clamscan --recursive --infected --no-summary "${directory}" | grep -i 'FOUND' >>"${report_file}")"

  # Check if file is empty
  if [[ -s ${report_file} ]]; then

    # The file is not-empty.
    clamscan_result="true"

    # Log
    display --indent 6 --text "- Searching for malware" --result "DONE" --color GREEN
    display --indent 8 --text "Malware found on ${directory}" --tcolor RED
    log_event "warning" "Malware found on ${directory}. Please check result file: ${report_file}" "false"

  else

    # The file is empty.
    rm --force "${report_file}"

    clamscan_result="false"

    # Log
    display --indent 6 --text "- Searching for malware" --result "DONE" --color GREEN
    display --indent 8 --text "No malware found on ${directory}"
    log_event "info" "No malware found on ${directory}" "false"

  fi

  # Return
  echo "${clamscan_result}"

}

################################################################################
# Custom Scan: Performs a custom scan.
#
# Arguments:
#  ${1} = ${directory} - directory to scan
#
# Outputs:
#  Scan result.
################################################################################

# IMPORTANT: Refactor before use this function, too many false positives

function security_custom_scan() {

  local directory="${1}"

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

################################################################################
# Lynis audit system
#
# Arguments:
#  none
#
# Outputs:
#  Audit result.
################################################################################

function menu_security_system_audit() {

  lynis audit system

}
