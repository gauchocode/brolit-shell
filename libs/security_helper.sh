#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc07
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

  # Update clamav database
  freshclam
  # Run on specific directory
  clamscan -r -i "${directory}"

}

security_system_audit() {

  lynis audit system

}