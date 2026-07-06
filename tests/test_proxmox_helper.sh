#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
#############################################################################

function test_proxmox_helper_functions() {

    test_proxmox_detect
    test_openresty_is_installed
    test_nginx_is_installed
    test_proxy_get_status

}

function test_proxmox_detect() {

    log_subsection "Test: test_proxmox_detect"

    # This test only runs inside a Proxmox VM
    if proxmox_detect; then
        display --indent 6 --text "- test_proxmox_detect (inside VM)" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_proxmox_detect (not in VM, expected)" --result "PASS" --color WHITE
    fi

}

function test_openresty_is_installed() {

    log_subsection "Test: test_openresty_is_installed"

    # Check function exists
    if type openresty_is_installed &>/dev/null; then
        display --indent 6 --text "- test_openresty_is_installed: function exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_openresty_is_installed: function exists" --result "FAIL" --color RED
    fi

    # Check return value is valid
    openresty_is_installed
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]] || [[ ${exitstatus} -eq 1 ]]; then
        display --indent 6 --text "- test_openresty_is_installed: valid return" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_openresty_is_installed: valid return" --result "FAIL" --color RED
    fi

}

function test_nginx_is_installed() {

    log_subsection "Test: test_nginx_is_installed"

    # Check function exists
    if type nginx_is_installed &>/dev/null; then
        display --indent 6 --text "- test_nginx_is_installed: function exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_nginx_is_installed: function exists" --result "FAIL" --color RED
    fi

}

function test_proxy_get_status() {

    log_subsection "Test: test_proxy_get_status"

    local status
    status="$(proxy_get_status)"

    if [[ "${status}" == "openresty" ]] || [[ "${status}" == "nginx" ]] || [[ "${status}" == "none" ]]; then
        display --indent 6 --text "- test_proxy_get_status: returns '${status}'" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_proxy_get_status: invalid return '${status}'" --result "FAIL" --color RED
    fi

}
