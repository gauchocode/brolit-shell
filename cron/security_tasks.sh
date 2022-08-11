#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc13
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

# If NETDATA is installed, disable alarms
if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
  netdata_alerts_disable
fi

# Check needed packages
package_install_security_utils

# Running from cron
log_event "info" "Running security_tasks.sh ..." "false"

log_section "Security Tasks"

# Clamav Scan
clamscan_result="$(security_clamav_scan "${PROJECTS_PATH}")"

if [[ ${clamscan_result} == "true" ]]; then

    send_notification "⚠️ ${SERVER_NAME}" "Clamav found malware files! Please check result file on server." ""

fi

## Commented this, too many false positives

# Custom Scan
#custom_scan_result="$(security_custom_scan "${PROJECTS_PATH}")"
#if [[ ${custom_scan_result} != "" ]]; then
#
#    send_notification "⚠️ ${SERVER_NAME}" "Custom scan result: ${custom_scan_result}" ""
#
#fi

# Script cleanup
cleanup

# If NETDATA is installed, enable alarms
if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
  netdata_alerts_enable
fi

# Log End
log_event "info" "SECURITY TASKS SCRIPT End -- $(date +%Y%m%d_%H%M)" "false"
