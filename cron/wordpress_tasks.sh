#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.3.0-beta
################################################################################

_wordpress_cronned_tasks() {

  local project_name
  local wp_install_type
  local all_sites
  local count_all_sites
  local notification_text
  local wpcli_core_verify_result

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
        [[ ${wp_install_type} == "docker" ]] && site="${site}/wordpress"

        log_subsection "Site: ${site}"

        # VERIFY_WP
        mapfile -t wpcli_core_verify_results < <(wpcli_core_verify "${site}" "${wp_install_type}")
        
        for wpcli_core_verify_result in "${wpcli_core_verify_results[@]}"; do

          # Ommit empty elements created by spaces on mapfile
          if [[ -n "${wpcli_core_verify_result}" ]]; then

            # Check results
            wpcli_core_verify_result_file="$(echo "${wpcli_core_verify_result}" | grep "File doesn't" | cut -d ":" -f3)"

            # Remove white space
            wpcli_core_verify_result_file=${wpcli_core_verify_result_file//[[:blank:]]/}

            # Log
            log_event "info" "${wpcli_core_verify_result_file}" "false"

            # Telegram text
            notification_text+="${wpcli_core_verify_result_file}\n"

          fi

        done

        if [[ -n ${notification_text} ]]; then

          log_event "error" "WordPress Checksum failed!" "false"

          # Send notification
          send_notification "⛔ ${SERVER_NAME}" "WordPress checksum failed for site ${project_name}:\n\n${notification_text}" ""

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
