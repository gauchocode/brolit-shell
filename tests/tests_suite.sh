#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.5-beta
#############################################################################

function tests_suite_menu() {

  local tests_options        # whiptail array options
  local chosen_tests_options # whiptail var

  tests_options=(
    "01)" "RUN ALL TESTS"
    "02)" "RUN JSON HELPER TESTS"
    "03)" "RUN MYSQL TESTS"
    "04)" "RUN PHP TESTS"
    "05)" "RUN NGINX TESTS"
    "06)" "RUN WORDPRESS TESTS"
    "07)" "RUN CLOUDFLARE TESTS"
    "08)" "RUN PROJECT TESTS"
    "09)" "RUN OTHER TESTS"
    "10)" "RUN DISPLAY TESTS"
  )

  chosen_tests_options=$(whiptail --title "TESTS SUITE" --menu " " 20 78 10 "${tests_options[@]}" 3>&1 1>&2 2>&3)
  
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_tests_options} == *"01"* ]]; then
      test_display_functions
      test_mysql_helper
      test_php_helper_funtions
      test_nginx_helper_functions
      test_wordpress_helper_funtions
      test_cloudflare_funtions
      test_common_funtions

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

  else

    exit 0

  fi

  prompt_return_or_finish
  tests_suite_menu

}

#############################################################################

### Main dir check
SFOLDER=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SFOLDER=$(cd "$(dirname "${SFOLDER}")" && pwd)
if [[ -z ${SFOLDER} ]]; then
  exit 1 # error; the path is not accessible
fi

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

# Tests directory path
TESTS_PATH="${SFOLDER}/tests/"

# source all tests
tests_files="$(find "${TESTS_PATH}" -maxdepth 1 -name 'test_*.sh' -type f -print)"
for f in ${tests_files}; do source "${f}"; done

### Init
script_init "" "" ""

### Menu

log_section "Running Tests Suite"

tests_suite_menu

# Log End
log_event "info" "BROLIT Tests End -- $(date +%Y%m%d_%H%M)" "true"
