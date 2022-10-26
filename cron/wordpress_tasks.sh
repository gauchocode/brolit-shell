#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.5
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

# If NETDATA is installed, disable alarms
if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
  netdata_alerts_disable
fi

log_event "info" "Running backups_tasks.sh" "false"

# Get all directories
all_sites="$(get_all_directories "${PROJECTS_PATH}")"

## Get length of $all_sites
count_all_sites="$(find "${PROJECTS_PATH}" -maxdepth 1 -type d -printf '.' | wc -c)"
count_all_sites=$((count_all_sites - 1))

# Log
log_event "info" "Found ${count_all_sites} directories" "false"
display --indent 2 --text "- Directories found" --result "${count_all_sites}" --color YELLOW

# GLOBALS
whitelisted_wp_files="readme.html,license.txt,wp-config-sample.php"
file_index=0

for site in ${all_sites}; do

  log_event "info" "Processing [${site}] ..."

  project_name="$(basename "${site}")"

  log_event "info" "Project name: ${project_name}" "false"

  if [[ ${IGNORED_PROJECTS_LIST} != *"${project_name}"* ]]; then

    # If is wp
    is_wp="$(wp_is_project "${site}")"

    if [[ ${is_wp} == "true" ]]; then

      notification_text=""

      # VERIFY_WP
      mapfile -t wpcli_core_verify_results < <(wpcli_core_verify "${site}")
      for wpcli_core_verify_result in "${wpcli_core_verify_results[@]}"; do

        # Ommit empty elements created by spaces on mapfile
        if [[ "${wpcli_core_verify_result}" != "" ]]; then

          # Check results
          wpcli_core_verify_result_file="$(echo "${wpcli_core_verify_result}" | grep "File doesn't" | cut -d ":" -f3)"

          # Remove white space
          wpcli_core_verify_result_file=${wpcli_core_verify_result_file//[[:blank:]]/}

          # Ommit empty elements
          if [[ ${wpcli_core_verify_result_file} != "" ]] && [[ ${whitelisted_wp_files} != *"${wpcli_core_verify_result_file}"* ]]; then

            log_event "info" "${wpcli_core_verify_result_file}" "false"

            # Telegram text
            notification_text+="${wpcli_core_verify_result} "

          fi

        fi

      done

      if [[ ${notification_text} != "" ]]; then

        log_event "error" "WordPress Checksum failed!" "false"

        # Send notification
        send_notification "⛔ ${SERVER_NAME}" "WordPress checksum failed for site ${project_name}: ${notification_text}"

      else

        log_event "info" "WordPress Checksum OK!" "false"

      fi

    fi

  else
    log_event "info" "Omitting ${project_name} project (blacklisted) ..."

  fi

  file_index=$((file_index + 1))

  log_event "info" "Processed ${file_index} of ${count_all_sites} projects"

  log_break

done

# If NETDATA is installed, enable alarms
if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
  netdata_alerts_enable
fi
