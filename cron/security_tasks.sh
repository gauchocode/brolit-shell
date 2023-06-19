#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.2-beta
################################################################################

_security_tasks() {

  log_section "Security Tasks"

  # Clamav Scan
  clamscan_result="$(security_clamav_scan "${PROJECTS_PATH}")"

  if [[ ${clamscan_result} == "true" ]]; then

    log_event "info" "Clamav found malware files! Please check result file." "false"

    send_notification "⚠️ ${SERVER_NAME}" "Clamav found malware files! Please check result file on server." ""

  else

    log_event "info" "Clamav has not found malware files" "false"

  fi

  ## Commented this, if scand finds too many false positives

  # Custom Scan
  #custom_scan_result="$(security_custom_scan "${PROJECTS_PATH}")"
  #if [[ ${custom_scan_result} != "" ]]; then
  #
  #    send_notification "⚠️ ${SERVER_NAME}" "Custom scan result: ${custom_scan_result}" ""
  #
  #fi

}

################################################################################

### Main dir check
BROLIT_MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BROLIT_MAIN_DIR=$(cd "$(dirname "${BROLIT_MAIN_DIR}")" && pwd)
if [[ -z "${BROLIT_MAIN_DIR}" ]]; then
  exit 1 # error; the path is not accessible
fi

# shellcheck source=${BROLIT_MAIN_DIR}/libs/commons.sh
source "${BROLIT_MAIN_DIR}/libs/commons.sh"

################################################################################

# Script Initialization
script_init "true"

log_event "info" "Running security_tasks.sh ..." "false"

# If NETDATA is installed, disable alarms
[[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]] && netdata_alerts_disable

# Check needed packages
package_install_security_utils

# Call main function
_security_tasks

# If NETDATA is installed, enable alarms
[[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]] && netdata_alerts_enable

# Log End
log_event "info" "Exiting script ..." "false" "1"

# Script cleanup
cleanup
