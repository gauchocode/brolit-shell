#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Script Name: BROLIT Shell
# Version: 3.5
################################################################################

### Environment checks
[ "${BASH_VERSINFO:-0}" -lt 4 ] && {
  echo "At least BASH version 4 is required. Aborting..." >&2
  exit 2
}

### Main dir check
BROLIT_MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
if [[ -z "${BROLIT_MAIN_DIR}" ]]; then
  exit 1 # error; the path is not accessible
fi

### Load Main library
chmod +x "${BROLIT_MAIN_DIR}/libs/commons.sh"
# shellcheck source=/root/brolit-shell/libs/commons.sh
source "${BROLIT_MAIN_DIR}/libs/commons.sh"

### Init #######################################################################

if [[ $# -eq 0 ]]; then

  # Script initialization
  script_init "true"

  # RUNNING MAIN MENU
  menu_main_options

else

  # RUNNING WITH FLAGS
  flags_handler $* #$* stores all arguments received when the script is runned

fi

# Script cleanup
cleanup

# Log End
log_event "info" "Exiting script ..." "false" "1"