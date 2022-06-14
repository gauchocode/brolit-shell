#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc8
################################################################################

### Main dir check
BROLIT_MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BROLIT_MAIN_DIR=$(cd "$(dirname "${BROLIT_MAIN_DIR}")" && pwd)
if [[ -z ${BROLIT_MAIN_DIR} ]]; then
    exit 1 # error; the path is not accessible
fi

# shellcheck source=${BROLIT_MAIN_DIR}/brolit_lite.sh
source "${BROLIT_MAIN_DIR}/brolit_lite.sh"

################################################################################

show_server_data "true"
dropbox_get_sites_backups "true"
firewall_get_apps_details "true"
list_packages_to_upgrade "true"