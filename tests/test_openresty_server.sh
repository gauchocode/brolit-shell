#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
#############################################################################

function test_openresty_server_functions() {

    test_openresty_server_create
    test_openresty_server_delete

}

function test_openresty_server_create() {

    log_subsection "Test: test_openresty_server_create"

    if openresty_is_installed; then
        local test_domain="test-openresty-$(date +%s).local"

        openresty_server_create "${test_domain}" "proxy" "" "" "8080"
        exitstatus=$?

        if [[ ${exitstatus} -eq 0 ]]; then
            # Verify config was created
            local conf_dir
            conf_dir="$(openresty_get_conf_dir)"
            if [[ -f "${conf_dir}/sites-available/${test_domain}" ]]; then
                display --indent 6 --text "- test_openresty_server_create" --result "PASS" --color WHITE
                # Cleanup
                openresty_server_delete "${test_domain}"
            else
                display --indent 6 --text "- test_openresty_server_create: config not created" --result "FAIL" --color RED
            fi
        else
            display --indent 6 --text "- test_openresty_server_create" --result "FAIL" --color RED
        fi
    else
        display --indent 6 --text "- test_openresty_server_create (skipped, not installed)" --result "SKIP" --color YELLOW
    fi

}

function test_openresty_server_delete() {

    log_subsection "Test: test_openresty_server_delete"

    if openresty_is_installed; then
        local test_domain="test-delete-$(date +%s).local"
        local conf_dir
        conf_dir="$(openresty_get_conf_dir)"

        # Create config first
        echo "server { listen 80; server_name ${test_domain}; }" > "${conf_dir}/sites-available/${test_domain}"
        ln -sf "${conf_dir}/sites-available/${test_domain}" "${conf_dir}/sites-enabled/${test_domain}"

        # Delete
        openresty_server_delete "${test_domain}"
        exitstatus=$?

        if [[ ${exitstatus} -eq 0 ]]; then
            if [[ ! -L "${conf_dir}/sites-enabled/${test_domain}" ]]; then
                display --indent 6 --text "- test_openresty_server_delete" --result "PASS" --color WHITE
            else
                display --indent 6 --text "- test_openresty_server_delete: symlink still exists" --result "FAIL" --color RED
            fi
        else
            display --indent 6 --text "- test_openresty_server_delete" --result "FAIL" --color RED
        fi
    else
        display --indent 6 --text "- test_openresty_server_delete (skipped, not installed)" --result "SKIP" --color YELLOW
    fi

}
