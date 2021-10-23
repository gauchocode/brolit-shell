#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.68-beta
################################################################################

### Main dir check
SFOLDER=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SFOLDER=$(cd "$(dirname "${SFOLDER}")" && pwd)
if [[ -z "${SFOLDER}" ]]; then
    exit 1 # error; the path is not accessible
fi

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

# Script Initialization
script_init

# Check needed packages
packages_install_security_utils

# Running from cron
log_event "info" "Running security_tasks.sh ..." "false"

log_section "Security Tasks"

# Clamav Scan
clamscan_result="$(security_clamav_scan "${PROJECTS_PATH}")"

if [[ ${clamscan_result} == "true" ]]; then

    send_notification "⚠️ ${VPSNAME}" "Clamav found malware files! Please check result file on server." ""

fi

## Commented this, too many false positives

# Custom Scan
#custom_scan_result="$(security_custom_scan "${PROJECTS_PATH}")"
#if [[ ${custom_scan_result} != "" ]]; then
#
#    send_notification "⚠️ ${VPSNAME}" "Custom scan result: ${custom_scan_result}" ""
#
#fi

# Script cleanup
cleanup

# Log End
log_event "info" "SECURITY TASKS SCRIPT End -- $(date +%Y%m%d_%H%M)" "false"
