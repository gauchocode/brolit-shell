#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.3
#############################################################################

function test_nginx_helper_functions() {

    test_nginx_server_change_phpv

}

function test_nginx_server_change_phpv() {

    local nginx_server_file

    log_subsection "Test: test_nginx_server_change_phpv"

    nginx_server_file="wordpress_single.conf"

    cp "${BROLIT_MAIN_DIR}/config/nginx/sites-available/wordpress_single" "${BROLIT_MAIN_DIR}/tmp/${nginx_server_file}"

    # First, we need to set a PHPV on file
    php_set_version_on_config "7.2" "${BROLIT_MAIN_DIR}/tmp/${nginx_server_file}"

    # Function to test
    nginx_server_change_phpv "${BROLIT_MAIN_DIR}/tmp/${nginx_server_file}" "7.4"

    # Get php version
    current_php_v=$(nginx_server_get_current_phpv "${BROLIT_MAIN_DIR}/tmp/${nginx_server_file}")
    if [[ ${current_php_v} == "7.4" ]]; then
        display --indent 6 --text "- test_nginx_server_change_phpv" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_nginx_server_change_phpv" --result "FAIL" --color RED
    fi

}