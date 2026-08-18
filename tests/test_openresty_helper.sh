#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.12
#############################################################################

function test_openresty_helper_functions() {

    test_openresty_get_conf_dir
    test_openresty_get_ssh_key
    test_openresty_vm_ssh_key_is_configured
    test_openresty_configuration_test
    test_openresty_list_routes
    test_openresty_api_status

}

function test_openresty_get_ssh_key() {

    log_subsection "Test: test_openresty_get_ssh_key"

    local ssh_key
    ssh_key="$(openresty_get_ssh_key)"

    if [[ "${ssh_key}" == "${HOME}/.ssh/brolit_openresty_vm" ]]; then
        display --indent 6 --text "- test_openresty_get_ssh_key" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_openresty_get_ssh_key: got '${ssh_key}'" --result "FAIL" --color RED
    fi

}

function test_openresty_vm_ssh_key_is_configured() {

    log_subsection "Test: test_openresty_vm_ssh_key_is_configured"

    # In non-Proxmox mode should return 1 (no VM configured)
    if [[ "${PROXMOX_MODE}" != "enabled" ]] || [[ -z "${OPENRESTY_VM_IP}" ]]; then
        openresty_vm_ssh_key_is_configured
        exitstatus=$?
        if [[ ${exitstatus} -eq 1 ]]; then
            display --indent 6 --text "- test_openresty_vm_ssh_key_is_configured (not in proxmox mode)" --result "PASS" --color WHITE
        else
            display --indent 6 --text "- test_openresty_vm_ssh_key_is_configured: expected 1, got ${exitstatus}" --result "FAIL" --color RED
        fi
    else
        display --indent 6 --text "- test_openresty_vm_ssh_key_is_configured (skipped in proxmox mode)" --result "SKIP" --color YELLOW
    fi

}

function test_openresty_get_conf_dir() {

    log_subsection "Test: test_openresty_get_conf_dir"

    local conf_dir
    conf_dir="$(openresty_get_conf_dir)"

    if [[ "${conf_dir}" == "/usr/local/openresty/nginx/conf" ]]; then
        display --indent 6 --text "- test_openresty_get_conf_dir" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_openresty_get_conf_dir: got '${conf_dir}'" --result "FAIL" --color RED
    fi

}

function test_openresty_configuration_test() {

    log_subsection "Test: test_openresty_configuration_test"

    if openresty_is_installed; then
        openresty_configuration_test
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
            display --indent 6 --text "- test_openresty_configuration_test" --result "PASS" --color WHITE
        else
            display --indent 6 --text "- test_openresty_configuration_test" --result "FAIL" --color RED
        fi
    else
        display --indent 6 --text "- test_openresty_configuration_test (skipped, not installed)" --result "SKIP" --color YELLOW
    fi

}

function test_openresty_list_routes() {

    log_subsection "Test: test_openresty_list_routes"

    if openresty_is_installed; then
        local result
        result="$(openresty_list_routes)"
        if echo "${result}" | jq . &>/dev/null; then
            display --indent 6 --text "- test_openresty_list_routes" --result "PASS" --color WHITE
        else
            display --indent 6 --text "- test_openresty_list_routes: invalid JSON" --result "FAIL" --color RED
        fi
    else
        display --indent 6 --text "- test_openresty_list_routes (skipped, not installed)" --result "SKIP" --color YELLOW
    fi

}

function test_openresty_api_status() {

    log_subsection "Test: test_openresty_api_status"

    if openresty_is_installed; then
        local result
        result="$(openresty_api_status)"
        if echo "${result}" | jq . &>/dev/null; then
            display --indent 6 --text "- test_openresty_api_status" --result "PASS" --color WHITE
        else
            display --indent 6 --text "- test_openresty_api_status: invalid JSON" --result "FAIL" --color RED
        fi
    else
        display --indent 6 --text "- test_openresty_api_status (skipped, not installed)" --result "SKIP" --color YELLOW
    fi

}
