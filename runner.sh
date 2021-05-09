#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Script Name: LEMP Utils Script
# Version: 3.0.22
################################################################################

### Exit immediately if a command exits with a non-zero status
#set -e

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

### Log
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
PATH_LOG="${SFOLDER}/log"
if [[ ! -d "${SFOLDER}/log" ]]; then
  mkdir "${SFOLDER}/log"
fi

# Define log name
declare -g LOG
declare -g LOG_NAME

# Check if the script receives first parameter "--sl"
if [[ ${1} == *"sl" ]];then         
  # And add second parameter to the log name
  LOG_NAME="log_lemp_utils_${2}.log"
else
  # Default log name
  LOG_NAME="log_lemp_utils_${TIMESTAMP}.log"
fi

LOG="${PATH_LOG}/${LOG_NAME}"

export LOG

### Load Main library
chmod +x "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/commons.sh"

### Init #######################################################################

script_init # Script initialization

if [[ $# -eq 0 ]]; then

  # RUNNING GRAPHIC MENU
  menu_main_options

else

  # RUNNING FROM FLAGS
  # With "$#" we can check the number of arguments received when the script is runned
  # Check if there were no arguments provided
  flags_handler "$#" "$*" #"$*" stores all arguments received when the script is runned

fi

# Script cleanup
cleanup

# Log End
log_event "info" "LEMP UTILS SCRIPT End -- $(date +%Y%m%d_%H%M)"
