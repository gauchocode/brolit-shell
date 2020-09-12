#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.1
################################################################################
#
# Refs: https://www.tecmint.com/scan-linux-for-malware-and-rootkits/
#

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

security_install() {

  apt-get install clamav lynis

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
  log_event "info" "Running: clamscan -r --infected ${directory}" "true"
  clamscan -r --infected "${directory}"

}

security_system_audit() {

  lynis audit system

}