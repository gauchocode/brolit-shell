#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.6
#############################################################################

function test_certbot_proxmox_functions() {

    test_certbot_get_challenge_type_openresty
    test_certbot_certificates_output_helper
    test_certbot_reload_openresty_function

}

function test_certbot_get_challenge_type_openresty() {

    log_subsection "Test: certbot_get_challenge_type (OpenResty mode)"

    # Mock openresty_is_installed so the test does not depend on a real VM
    function openresty_is_installed() { return 0; }

    # Save current state
    local old_proxmox_mode="${PROXMOX_MODE}"
    local old_openresty_vm_ip="${OPENRESTY_VM_IP}"

    # Simulate Proxmox mode without Cloudflare
    PROXMOX_MODE="enabled"
    OPENRESTY_VM_IP="127.0.0.1"
    SUPPORT_CLOUDFLARE_STATUS="disabled"

    local challenge_type
    challenge_type="$(certbot_get_challenge_type "example.com")"

    if [[ "${challenge_type}" == "webroot" ]]; then
        display --indent 6 --text "- certbot_get_challenge_type returns webroot" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- certbot_get_challenge_type expected webroot, got '${challenge_type}'" --result "FAIL" --color RED
    fi

    # Restore state
    PROXMOX_MODE="${old_proxmox_mode}"
    OPENRESTY_VM_IP="${old_openresty_vm_ip}"
    unset -f openresty_is_installed 2>/dev/null || true

}

function test_certbot_certificates_output_helper() {

    log_subsection "Test: certbot_certificates_output helper exists"

    if type certbot_certificates_output &>/dev/null; then
        display --indent 6 --text "- certbot_certificates_output function exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- certbot_certificates_output function exists" --result "FAIL" --color RED
    fi

}

function test_certbot_reload_openresty_function() {

    log_subsection "Test: certbot_reload_openresty function exists"

    if type certbot_reload_openresty &>/dev/null; then
        display --indent 6 --text "- certbot_reload_openresty function exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- certbot_reload_openresty function exists" --result "FAIL" --color RED
    fi

}
