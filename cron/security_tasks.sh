#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.27
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
    clamscan_result="$(security_clamav_scan "${SITES}")"

    clamscan_infected="$(echo "${clamscan_result}" | grep -w "Infected files")"

    if [[ ${clamscan_result} == *""* ]]; then

        send_notification "✅ ${VPSNAME} - Clamav scan result" "${clamscan_result}" ""

    else

        send_notification "✅ ${VPSNAME} - Clamav scan result" "${clamscan_result}" ""

    fi

    # Custom Scan
    custom_scan_result="$(security_custom_scan "${SITES}")"

    send_notification "Custom scan result" "${custom_scan_result}" ""

    # Script cleanup
    cleanup

    # Log End
    log_event "info" "LEMP UTILS SCRIPT End -- $(date +%Y%m%d_%H%M)"

fi


#clamscan_infected="$(echo "----------- SCAN SUMMARY -----------Known viruses: 8530089 Engine version: 0.103.2 Scanned directories: 24391 Scanned files: 189125 Infected files: 0 Data scanned: 5420.92 MB Data read: 5399.94 MB (ratio 1.00:1) Time: 1400.847 sec (23 m 20 s) Start Date: 2021:05:17 04:45:04 End Date:   2021:05:17 05:08:25" | grep -w "Infected files" )";echo $clamscan_infected