#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.38
################################################################################

### Main dir check
SFOLDER=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SFOLDER=$(cd "$(dirname "${SFOLDER}")" && pwd)
if [[ -z "${SFOLDER}" ]]; then
  exit 1 # error; the path is not accessible
fi

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

# Script Initialization
script_init

log_event "info" "Running backups_tasks.sh" "false"

# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"
# shellcheck source=${SFOLDER}/libs/telegram_notification_helper.sh
source "${SFOLDER}/libs/telegram_notification_helper.sh"
# shellcheck source=${SFOLDER}/libs/wordpress_helper.sh
source "${SFOLDER}/libs/wordpress_helper.sh"
# shellcheck source=${SFOLDER}/libs/wpcli_helper.sh
source "${SFOLDER}/libs/wpcli_helper.sh"

# Get all directories
all_sites="$(get_all_directories "${SITES}")"

## Get length of $all_sites
count_all_sites="$(find "${SITES}" -maxdepth 1 -type d -printf '.' | wc -c)"
count_all_sites=$((count_all_sites - 1))

# Log
log_event "info" "Found ${count_all_sites} directories" "false"
display --indent 2 --text "- Directories found" --result "${count_all_sites}" --color YELLOW

# GLOBALS
whitelisted_wp_files="readme.html,license.txt,wp-config-sample.php"
file_index=0

k=0

for site in ${all_sites}; do

  log_event "info" "Processing [${site}] ..."

  if [[ "$k" -gt 0 ]]; then

    project_name="$(basename "${site}")"

    log_event "info" "Project name: ${project_name}" "false"

    if [[ ${SITES_BL} != *"${project_name}"* ]]; then

      # If is wp
      is_wp="$(is_wp_project "${site}")"

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
          send_notification "⛔ ${VPSNAME}" "WordPress checksum failed for site ${project_name}: ${notification_text}"

        else

          log_event "info" "WordPress Checksum OK!" "false"

        fi

      fi

    else
      log_event "info" "Omitting ${project_name} project (blacklisted) ..."

    fi

    file_index=$((file_index + 1))

    log_event "info" "Processed ${file_index} of ${count_all_sites} projects"

  fi

  log_break

  k=$k+1

done
