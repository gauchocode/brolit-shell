#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
#############################################################################

function test_npm_migration_functions() {

    test_npm_generate_nginx_config

}

function test_npm_generate_nginx_config() {

    log_subsection "Test: test_npm_generate_nginx_config"

    local config
    config="$(npm_generate_nginx_config "test.example.com" "127.0.0.1" "3000" "false" "true" "")"

    if [[ -n "${config}" ]]; then
        # Check domain was replaced
        if echo "${config}" | grep -q "test.example.com"; then
            display --indent 6 --text "- test_npm_generate_nginx_config: domain replaced" --result "PASS" --color WHITE
        else
            display --indent 6 --text "- test_npm_generate_nginx_config: domain not replaced" --result "FAIL" --color RED
        fi

        # Check port was replaced
        if echo "${config}" | grep -q "3000"; then
            display --indent 6 --text "- test_npm_generate_nginx_config: port replaced" --result "PASS" --color WHITE
        else
            display --indent 6 --text "- test_npm_generate_nginx_config: port not replaced" --result "FAIL" --color RED
        fi

        # Check WebSocket headers present
        if echo "${config}" | grep -q "Upgrade"; then
            display --indent 6 --text "- test_npm_generate_nginx_config: websocket headers" --result "PASS" --color WHITE
        else
            display --indent 6 --text "- test_npm_generate_nginx_config: websocket headers missing" --result "FAIL" --color RED
        fi
    else
        display --indent 6 --text "- test_npm_generate_nginx_config: empty output" --result "FAIL" --color RED
    fi

}
