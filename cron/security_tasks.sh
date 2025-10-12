#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.4
################################################################################
#
# Ref: https://github.com/wordfence/wordfence-cli
#

LAST_SCAN_DATE_FILE="/root/brolit-shell/tmp/last_scan_date.txt"

SCAN_STATUS_FILE="/root/brolit-shell/tmp/scan_status.txt"

echo "In Progress" >$SCAN_STATUS_FILE

_security_tasks() {

  log_section "Security Tasks"

  SCAN_STATUS="No Issues"

  for project_dir in "${PROJECTS_PATH}"/*; do

    if [[ -d "$project_dir" ]]; then

      if [[ -d "$project_dir/wordpress" || (-f "$project_dir/index.php" && -d "$project_dir/wp-content") ]]; then

        # Wordfence-cli Scan
        wordfencecli_scan_result="$(wordfencecli_malware_scan "${project_dir}" "true")"

        if [[ ${wordfencecli_scan_result} == "true" ]]; then

          log_event "info" "Wordfence-cli found malware files in ${project_dir}! Please check result file." "false"
          send_notification "${SERVER_NAME}" "Wordfence-cli found malware files in ${project_dir}! Please check result file on server." "alert"

          SCAN_STATUS="Found Issues"

        else

          log_event "info" "Wordfence-cli has not found malware files in ${project_dir}" "false"
          #send_notification "${SERVER_NAME}" "Wordfence-cli did not find any malware files in ${project_dir}. No action needed." "info"

        fi

      fi

    fi

  done

  # Clamav Scan
  clamscan_result="$(security_clamav_scan "${PROJECTS_PATH}")"

  if [[ ${clamscan_result} == "true" ]]; then

    log_event "info" "Clamav found malware files! Please check result file." "false"
    send_notification "${SERVER_NAME}" "Clamav found malware files! Please check result file on server." "alert"

    SCAN_STATUS="Found Issues"

  else

    log_event "info" "Clamav has not found malware files" "false"
    #send_notification "${SERVER_NAME}" "Clamav has not found malware files on server. No action needed." "info"

  fi

  date "+%Y-%m-%d %H:%M:%S" >$LAST_SCAN_DATE_FILE

  echo "${SCAN_STATUS}" >$SCAN_STATUS_FILE

  log_event "info" "Scan completed with status: ${SCAN_STATUS}" "false"

  ## Commented this, if scand finds too many false positives

  # Custom Scan
  #custom_scan_result="$(security_custom_scan "${PROJECTS_PATH}")"
  #if [[ ${custom_scan_result} != "" ]]; then
  #
  #    send_notification "${SERVER_NAME}" "Custom scan result: ${custom_scan_result}" "alert"
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
