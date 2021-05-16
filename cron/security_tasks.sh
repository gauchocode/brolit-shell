#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.25
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

if [[ -t 1 ]]; then

    # Running from terminal
    echo " > Error: The script can only be runned by cron. Exiting ..."
    exit 1

else

    # Script Initialization
    script_init

    # Running from cron
    log_event "info" "Running security_tasks.sh from cron ..."

    log_section "Security Tasks"

    # Clamav Scan
    log_event "info" "Starting clamav scan on: ${SITES}" "false"
    clamscan_result="$(security_clamav_scan "${SITES}")"

    send_notification "Clamav scan result" "${clamscan_result}" ""

    # Custom Scan
    log_event "info" "Starting custom scan on: ${SITES}" "false"
    custom_scan_result="$(security_custom_scan "${SITES}")"

    send_notification "Custom scan result" "${custom_scan_result}" ""

    # Script cleanup
    cleanup

    # Log End
    log_event "info" "LEMP UTILS SCRIPT End -- $(date +%Y%m%d_%H%M)"

fi
