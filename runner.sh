#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Script Name: BROLIT Shell
# Version: 3.0.47
################################################################################

### Environment checks
[ "${BASH_VERSINFO:-0}" -lt 4 ] && {
  echo "At least Bash version 4 is required. Aborting..." >&2
  exit 2
}

### Main dir check
SFOLDER=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
if [[ -z "${SFOLDER}" ]]; then
  exit 1 # error; the path is not accessible
fi

### Load Main library
chmod +x "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/commons.sh"

### Init #######################################################################

# Script initialization
script_init "${1}" "${2}"

if [[ $# -eq 0 ]]; then

  # RUNNING MAIN MENU
  menu_main_options

else

  # RUNNING WITH FLAGS
  # With "$#" we can check the number of arguments received when the script is runned
  # Check if there were no arguments provided
  flags_handler "$#" "$*" #"$*" stores all arguments received when the script is runned

fi

# Script cleanup
cleanup

# Log End
log_event "info" "BROLIT SCRIPT End -- $(date +%Y%m%d_%H%M)"
