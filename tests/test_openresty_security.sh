#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.6
#############################################################################

function test_openresty_security_functions() {

    test_routes_lua_token_auth
    test_routes_lua_domain_validation
    test_routes_lua_upstream_validation

}

function test_routes_lua_token_auth() {

    log_subsection "Test: routes.lua token auth logic"

    local routes_file="${BROLIT_MAIN_DIR}/config/openresty/api/routes.lua"

    if [[ ! -f "${routes_file}" ]]; then
        display --indent 6 --text "- routes.lua token auth: file not found" --result "FAIL" --color RED
        return 1
    fi

    local pass=0

    if grep -q "get_api_token" "${routes_file}"; then
        display --indent 6 --text "- routes.lua: token reader exists" --result "PASS" --color WHITE
        pass=$((pass + 1))
    else
        display --indent 6 --text "- routes.lua: token reader missing" --result "FAIL" --color RED
    fi

    if grep -q "check_auth" "${routes_file}"; then
        display --indent 6 --text "- routes.lua: auth check exists" --result "PASS" --color WHITE
        pass=$((pass + 1))
    else
        display --indent 6 --text "- routes.lua: auth check missing" --result "FAIL" --color RED
    fi

    if grep -q "Unauthorized" "${routes_file}"; then
        display --indent 6 --text "- routes.lua: unauthorized response exists" --result "PASS" --color WHITE
        pass=$((pass + 1))
    else
        display --indent 6 --text "- routes.lua: unauthorized response missing" --result "FAIL" --color RED
    fi

}

function test_routes_lua_domain_validation() {

    log_subsection "Test: routes.lua domain validation"

    local routes_file="${BROLIT_MAIN_DIR}/config/openresty/api/routes.lua"

    if [[ ! -f "${routes_file}" ]]; then
        display --indent 6 --text "- routes.lua domain validation: file not found" --result "FAIL" --color RED
        return 1
    fi

    local pass=0

    if grep -q "is_valid_domain" "${routes_file}"; then
        display --indent 6 --text "- routes.lua: domain validator exists" --result "PASS" --color WHITE
        pass=$((pass + 1))
    else
        display --indent 6 --text "- routes.lua: domain validator missing" --result "FAIL" --color RED
    fi

    if grep -q "Invalid domain" "${routes_file}"; then
        display --indent 6 --text "- routes.lua: invalid domain error exists" --result "PASS" --color WHITE
        pass=$((pass + 1))
    else
        display --indent 6 --text "- routes.lua: invalid domain error missing" --result "FAIL" --color RED
    fi

}

function test_routes_lua_upstream_validation() {

    log_subsection "Test: routes.lua upstream validation"

    local routes_file="${BROLIT_MAIN_DIR}/config/openresty/api/routes.lua"

    if [[ ! -f "${routes_file}" ]]; then
        display --indent 6 --text "- routes.lua upstream validation: file not found" --result "FAIL" --color RED
        return 1
    fi

    local pass=0

    if grep -q "is_valid_upstream_url" "${routes_file}"; then
        display --indent 6 --text "- routes.lua: upstream validator exists" --result "PASS" --color WHITE
        pass=$((pass + 1))
    else
        display --indent 6 --text "- routes.lua: upstream validator missing" --result "FAIL" --color RED
    fi

    if grep -q "shell_escape" "${routes_file}"; then
        display --indent 6 --text "- routes.lua: shell escaping exists" --result "PASS" --color WHITE
        pass=$((pass + 1))
    else
        display --indent 6 --text "- routes.lua: shell escaping missing" --result "FAIL" --color RED
    fi

}
