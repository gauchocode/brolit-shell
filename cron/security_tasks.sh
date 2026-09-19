#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
################################################################################
#
# Ref: https://github.com/wordfence/wordfence-cli
#

if [[ -z "${BROLIT_MAIN_DIR:-}" ]]; then
  BROLIT_MAIN_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd -P)"
fi
if [[ -z "${BROLIT_RUNTIME_STATE_DIR:-}" ]]; then
  if [[ "${BROLIT_MAIN_DIR}" == */brolit-shell/releases/* || "${BROLIT_MAIN_DIR}" == */brolit-shell/current* ]]; then
    BROLIT_RUNTIME_STATE_DIR="${BROLIT_STATE_DIR:-/var/lib/brolit}"
  else
    BROLIT_RUNTIME_STATE_DIR="${BROLIT_MAIN_DIR}"
  fi
  export BROLIT_RUNTIME_STATE_DIR
fi
if [[ -L "${BROLIT_RUNTIME_STATE_DIR}" || -L "${BROLIT_RUNTIME_STATE_DIR}/tmp" ]]; then
  echo "Brolit runtime state path must not be a symlink" >&2
  exit 1
fi
if [[ "${BROLIT_RUNTIME_STATE_DIR}" != "${BROLIT_MAIN_DIR}" ]]; then umask 077; fi
mkdir -p "${BROLIT_RUNTIME_STATE_DIR}/tmp" || { echo "Unable to create Brolit runtime state" >&2; exit 1; }
chmod 700 "${BROLIT_RUNTIME_STATE_DIR}" "${BROLIT_RUNTIME_STATE_DIR}/tmp" || { echo "Unable to secure Brolit runtime state" >&2; exit 1; }

write_state_file() {
  local path="${1}"
  local content="${2}"
  local temp_path="${path}.tmp.$$"
  [[ ! -L "${path}" && ( ! -e "${path}" || -f "${path}" ) && ! -L "${temp_path}" && ! -e "${temp_path}" ]] || return 1
  printf '%s\n' "${content}" >"${temp_path}" || return 1
  chmod 600 "${temp_path}" || return 1
  mv -Tf "${temp_path}" "${path}" || return 1
  [[ ! -L "${path}" ]] && chmod 600 "${path}"
}

LAST_SCAN_DATE_FILE="${BROLIT_RUNTIME_STATE_DIR}/tmp/last_scan_date.txt"

SCAN_STATUS_FILE="${BROLIT_RUNTIME_STATE_DIR}/tmp/scan_status.txt"

write_state_file "${SCAN_STATUS_FILE}" "In Progress" || { echo "Unable to write secure Brolit scan state" >&2; exit 1; }

_security_tasks() {

  log_section "Security Tasks"

  SCAN_STATUS="No Issues"
  local scan_failed="false"

  for project_dir in "${PROJECTS_PATH}"/*; do

    if [[ -d "$project_dir" ]]; then

      if [[ -d "$project_dir/wordpress" || (-f "$project_dir/index.php" && -d "$project_dir/wp-content") ]]; then

        # Wordfence-cli Scan
        if ! wordfencecli_scan_result="$(wordfencecli_malware_scan "${project_dir}" "true")"; then
          log_event "error" "Wordfence-cli scan failed for ${project_dir}; result is not authoritative" "false"
          scan_failed="true"
          continue
        fi

        if [[ ${wordfencecli_scan_result} == "true" ]]; then

          log_event "info" "Wordfence-cli found malware files in ${project_dir}! Please check result file." "false"
          send_notification "${SERVER_NAME}" "Wordfence-cli found malware files in ${project_dir}! Please check result file on server." "alert"

          SCAN_STATUS="Found Issues"

        else

          log_event "info" "Wordfence-cli has not found malware files in ${project_dir}" "false"
          #send_notification "${SERVER_NAME}" "Wordfence-cli did not find any malware files in ${project_dir}. No action needed." "info"

        fi

      fi

    fi

  done

  # Clamav Scan
  if ! clamscan_result="$(security_clamav_scan "${PROJECTS_PATH}")"; then
    log_event "error" "ClamAV scan failed; result is not authoritative" "false"
    scan_failed="true"
    clamscan_result="error"
  fi

  if [[ ${clamscan_result} == "true" ]]; then

    log_event "info" "Clamav found malware files! Please check result file." "false"
    send_notification "${SERVER_NAME}" "Clamav found malware files! Please check result file on server." "alert"

    SCAN_STATUS="Found Issues"

  else

    log_event "info" "Clamav has not found malware files" "false"
    #send_notification "${SERVER_NAME}" "Clamav has not found malware files on server. No action needed." "info"

  fi

  # Process Malware Scanner
  if ! process_scanner_result="$(security_process_scanner)"; then
    log_event "error" "Process malware scan failed; result is not authoritative" "false"
    scan_failed="true"
    process_scanner_result="error"
  fi

  if [[ ${process_scanner_result} == "true" ]]; then

    log_event "warning" "Process scanner found suspicious activity! Please check result file." "false"
    send_notification "${SERVER_NAME}" "Process malware scanner detected suspicious processes! Possible cryptominer or malware running. Check server immediately." "alert"

    SCAN_STATUS="Found Issues"

  else

    log_event "info" "Process scanner has not found suspicious activity" "false"

  fi

  write_state_file "${LAST_SCAN_DATE_FILE}" "$(date "+%Y-%m-%d %H:%M:%S")" || { echo "Unable to write secure Brolit scan date" >&2; return 1; }

  if [[ "${scan_failed}" == "true" ]]; then
    SCAN_STATUS="Error"
  fi
  write_state_file "${SCAN_STATUS_FILE}" "${SCAN_STATUS}" || { echo "Unable to write secure Brolit scan state" >&2; return 1; }

  log_event "info" "Scan completed with status: ${SCAN_STATUS}" "false"

  [[ "${scan_failed}" == "true" ]] && return 2

  ## Commented this, if scand finds too many false positives

  # Custom Scan
  #custom_scan_result="$(security_custom_scan "${PROJECTS_PATH}")"
  #if [[ ${custom_scan_result} != "" ]]; then
  #
  #    send_notification "${SERVER_NAME}" "Custom scan result: ${custom_scan_result}" "alert"
  #
  #fi

}

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

log_event "info" "Running security_tasks.sh ..." "false"

# If NETDATA is installed, disable alarms
[[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]] && netdata_alerts_disable

# Check needed packages
if ! package_install_security_utils; then
  log_event "error" "Required security packages could not be installed" "false"
  exit 1
fi

# Call main function
if ! _security_tasks; then
  log_event "error" "Security tasks failed to persist final state" "false"
  exit 1
fi

# If NETDATA is installed, enable alarms
[[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]] && netdata_alerts_enable

# Log End
log_event "info" "Exiting script ..." "false" "1"

# Script cleanup
cleanup
