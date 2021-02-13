#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.13
#############################################################################

### Main dir check
SFOLDER=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
SFOLDER=$( cd "$( dirname "${SFOLDER}" )" && pwd )
if [[ -z ${SFOLDER} ]]; then
  exit 1  # error; the path is not accessible
fi

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

# Tests directory path
TESTS_PATH="${SFOLDER}/tests/"

# source all tests
tests_files="$(find "${TESTS_PATH}" -maxdepth 1 -name 'test_*.sh' -type f -print)"
for f in ${tests_files}; do source "${f}"; done

### Init
script_init

### Tests start

log_section "Running Tests Suite"

#test_display_functions

#test_common_funtions

test_mysql_helper

#test_php_helper_funtions

#test_cloudflare_funtions

#test_wordpress_helper_funtions

#test_mail_cert_section

#test_mail_package_section

#to_test="/var/www/goseries-master"
#is_wp_project "$to_test"

#nginx_server_change_phpv "domain.com" "7.4"

#startdir=${SITES}
#menutitle="Site Selection Menu"

#directory_browser "$menutitle" "$startdir"
#WP_SITE=$filepath"/"$filename

#echo -e ${B_GREEN}" > WP_SITE=${WP_SITE}"${ENDCOLOR}
#install_path=$(search_wp_config "${WP_SITE}")
#echo -e ${B_GREEN}" > install_path=${install_path}"${ENDCOLOR}

#wpcli_core_reinstall "${install_path}"

#wpcli_delete_not_core_files "${install_path}"

#mapfile -t wpcli_plugin_verify_results < <( wpcli_plugin_verify "${install_path}" )

#for wpcli_plugin_verify_result in "${wpcli_plugin_verify_results[@]}"
#do
#   echo " > ${wpcli_plugin_verify_result}"
#done

#wpcli_force_reinstall_plugins "${install_path}"

#install_crontab_script "${SFOLDER}/test.sh" "01" "00"

#telegram_send_message "LEMPT UTILS SCRIPT NOTIFICATION TEST"

# Log End
log_event "info" "LEMP UTILS Tests End -- $(date +%Y%m%d_%H%M)" "true"