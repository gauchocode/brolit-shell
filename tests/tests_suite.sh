#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.11
#############################################################################

function tests_suite_menu() {

  local tests_options        # whiptail array options
  local chosen_tests_options # whiptail var

  tests_options=(
    "00)" "RUN ALL TESTS"
    "01)" "RUN BORG TESTS"
    "02)" "RUN JSON HELPER TESTS"
    "03)" "RUN MYSQL TESTS"
    "04)" "RUN PHP TESTS"
    "05)" "RUN NGINX TESTS"
    "06)" "RUN WORDPRESS TESTS"
    "07)" "RUN CLOUDFLARE TESTS"
    "08)" "RUN PROJECT TESTS"
    "09)" "RUN OTHER TESTS"
    "10)" "RUN DISPLAY TESTS"
    "11)" "RUN DOCKER TESTS"
    "12)" "RUN BROLIT NOTIFICATION TESTS"
  )

  chosen_tests_options=$(whiptail --title "TESTS SUITE" --menu " " 20 78 10 "${tests_options[@]}" 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_tests_options} == *"00"* ]]; then
      test_display_functions
      test_mysql_helper
      test_php_helper_funtions
      test_nginx_helper_functions
      test_wordpress_helper_funtions
      test_cloudflare_funtions
      test_common_funtions
      test_borg_helper_funtions
    fi
    if [[ ${chosen_tests_options} == *"01"* ]]; then
      borg_backup_database

    fi
    if [[ ${chosen_tests_options} == *"02"* ]]; then
      test_json_helper_funtions

    fi
    if [[ ${chosen_tests_options} == *"03"* ]]; then
      test_mysql_helper

    fi
    if [[ ${chosen_tests_options} == *"04"* ]]; then
      test_php_helper_funtions

    fi
    if [[ ${chosen_tests_options} == *"05"* ]]; then
      test_nginx_helper_functions

    fi
    if [[ ${chosen_tests_options} == *"06"* ]]; then
      test_wordpress_helper_funtions

    fi
    if [[ ${chosen_tests_options} == *"07"* ]]; then
      test_cloudflare_funtions

    fi
    if [[ ${chosen_tests_options} == *"08"* ]]; then
      test_project_helper_funtions

    fi

    if [[ ${chosen_tests_options} == *"09"* ]]; then
      test_common_funtions

    fi
    if [[ ${chosen_tests_options} == *"10"* ]]; then
      test_display_functions

    fi
    if [[ ${chosen_tests_options} == *"11"* ]]; then
      #test_docker_helper_functions
      #test_docker_database_backup
      test_project_delete_database_docker
    fi
    if [[ ${chosen_tests_options} == *"12"* ]]; then
      send_notification "${SERVER_NAME}" "This is a notification test message!" ""

    fi

  else

    exit 0

  fi

  prompt_return_or_finish
  tests_suite_menu

}

#############################################################################

### Main dir check
BROLIT_MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BROLIT_MAIN_DIR=$(cd "$(dirname "${BROLIT_MAIN_DIR}")" && pwd)
if [[ -z ${BROLIT_MAIN_DIR} ]]; then
  exit 1 # error; the path is not accessible
fi

# shellcheck source=${BROLIT_MAIN_DIR}/libs/commons.sh
source "${BROLIT_MAIN_DIR}/libs/commons.sh"

# Tests directory path
TESTS_PATH="${BROLIT_MAIN_DIR}/tests/"

# source all tests
tests_files="$(find "${TESTS_PATH}" -maxdepth 1 -name 'test_*.sh' -type f -print)"
for f in ${tests_files}; do source "${f}"; done

### Init
script_init "true"

### Menu

log_section "Running Tests Suite"

tests_suite_menu

# Log End
log_event "info" "Exiting script ..." "false" "1"
