#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.5
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

# Running from cron
log_event "info" "Running disk_cleanup_tasks.sh from cron ..." "false"

# If NETDATA is installed, disable alarms
if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
  netdata_alerts_disable
fi

# Running cleanup tasks
clean_disk_apt

clean_disk_journal

# If NETDATA is installed, enable alarms
if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
  netdata_alerts_enable
fi
