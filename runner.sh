#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Script Name: BROLIT Shell
# Version: 3.6
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

### Early exit for help/version (no init needed) ###########################

for arg in "$@"; do
  case ${arg} in
    -h | --help | -\?)
      # shellcheck source=/root/brolit-shell/libs/task_runner.sh
      source "${BROLIT_MAIN_DIR}/libs/task_runner.sh"
      show_help
      exit 0
      ;;
    --version)
      echo "BROLIT Shell v3.6"
      exit 0
      ;;
  esac
done

### Load Main library
# shellcheck source=/root/brolit-shell/libs/commons.sh
source "${BROLIT_MAIN_DIR}/libs/commons.sh"

### Init #######################################################################

if [[ $# -eq 0 ]]; then
  # RUNNING INTERACTIVE MODE
  script_init "true" "interactive"
  menu_main_options
else
  # RUNNING CLI MODE
  script_init "true" "cli"
  flags_handler "$@"
fi

# Script cleanup
cleanup

# Log End
log_event "info" "Exiting script ..." "false" "1"