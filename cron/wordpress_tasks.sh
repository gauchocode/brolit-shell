#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.6
################################################################################

_wordpress_cronned_tasks() {

  local project_name
  local wp_install_type
  local all_sites
  local count_all_sites
  local notification_text
  local exitstatus

  log_section "Verifying WordPress Checksums"

  # Get all directories
  all_sites="$(get_all_directories "${PROJECTS_PATH}")"

  ## Get length of $all_sites
  count_all_sites="$(find "${PROJECTS_PATH}" -maxdepth 1 -type d -printf '.' | wc -c)"
  count_all_sites=$((count_all_sites - 1))

  # Log
  log_event "info" "Found ${count_all_sites} directories" "false"
  display --indent 6 --text "- Directories found" --result "${count_all_sites}" --color WHITE
  log_break "true"

  # GLOBALS
  file_index=0

  for site in ${all_sites}; do

    log_event "info" "Processing [${site}] ..." "false"

    project_name="$(basename "${site}")"

    log_event "info" "Project name: ${project_name}" "false"

    if [[ ${IGNORED_PROJECTS_LIST} != *"${project_name}"* ]]; then

      # If is wp
      wp_install_type="$(wp_project "${site}")"
      exitstatus=$?

      if [[ ${exitstatus} -eq 0 ]]; then

        notification_text=""
        [[ ${wp_install_type} == "docker"* ]] && site="${site}/wordpress"

        log_subsection "Site: ${site}"

        # Verify WordPress Checksums
        wpcli_core_verify_results="$(wpcli_core_verify "${site}" "${wp_install_type}")"

        # Check if there are suspicious files
        if [[ -n ${wpcli_core_verify_results} ]]; then

          while IFS=, read -ra path_array; do

            for wpcli_core_verify_result_file in "${path_array[@]}"; do

              # Increment counter
              count=$((count + 1))

              # Notification text
              notification_text+="<br/><em>${site}/${wpcli_core_verify_result_file//$'\r'/}</em>"

              # Log
              log_event "info" "Not core file detected: ${site}/${wpcli_core_verify_result_file}" "false"

            done

          done <"${wpcli_core_verify_results}"

          # Send notification
          send_notification "⛔ ${SERVER_NAME}" "WordPress checksum failed for site ${project_name}:\n\n${notification_text}" ""

          # Log
          log_event "error" "WordPress Checksum failed!" "false"
          log_event "info" "${count} unknown files detected!" "false"

        else

          log_event "info" "WordPress Checksum OK!" "false"

        fi

      fi

    else

      log_event "info" "Omitting ${project_name} project (blacklisted) ..."

    fi

    file_index=$((file_index + 1))

    # Log
    log_event "info" "Processed ${file_index} of ${count_all_sites} projects" "false"
    log_break "true"

  done
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

log_event "info" "Running backups_tasks.sh" "false"

# If NETDATA is installed, disable alarms
[[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]] && netdata_alerts_disable

# Call main function
_wordpress_cronned_tasks

# If NETDATA is installed, enable alarms
[[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]] && netdata_alerts_enable
