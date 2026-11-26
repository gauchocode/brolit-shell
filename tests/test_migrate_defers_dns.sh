#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.15
#############################################################################
#
# On 2026-11-26 `migrate` of jumpnetcorp.com.ar changed the domain's DNS inside
# the remote restore, before the destination was verified. The restore then
# failed, the DNS stayed on the destination's private address and the site, which
# was fine on the source, went offline.
#
# Pinned here:
#   1. project_update_domain_config has three stages: `all` (default, unchanged),
#      `defer` (web server config only: no DNS record, no certificate) and
#      `finalize` (DNS records and certificate only).
#   2. migrate restores with the defer stage, verifies, and only then switches
#      the DNS; a failed restore or verification never reaches the DNS.
#   3. The DNS switch records the previous A record and puts it back when the
#      switch fails or the site does not answer afterwards.
#   4. The destination must run a shell that honours the defer stage.
# Everything remote or external is faked: no servers, no Cloudflare.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1091
source "${TEST_LOADER_DIR}/../libs/commons.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/project_helper.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/site_migration_helper.sh" >/dev/null 2>&1

CALLS=""
function tmd_reset() { CALLS=""; }
function tmd_called() { [[ " ${CALLS} " == *" ${1} "* ]]; }
# Each section replaces functions with fakes: reload the real ones first.
function tmd_reload() {
    # shellcheck disable=SC1090
    source "${TEST_LOADER_DIR}/../libs/local/project_helper.sh" >/dev/null 2>&1
    # shellcheck disable=SC1090
    source "${TEST_LOADER_DIR}/../libs/local/site_migration_helper.sh" >/dev/null 2>&1
}

function tmd_quiet() {
    function log_event() { :; }
    function display() { :; }
    function log_subsection() { :; }
    function log_section() { :; }
    function clear_previous_lines() { :; }
    function brolit_progress() { :; }
    function sleep() { :; }
}

function tmd_check() {

    local label="${1}" ok="${2}"
    if [[ ${ok} == "yes" ]]; then echo "PASS: ${label}"; else echo "FAIL: ${label} (calls: ${CALLS})"; TMD_FAILED=1; fi

}

# 1. The stages of project_update_domain_config ------------------------------
function tmd_stages() {

    tmd_reload
    tmd_quiet
    function domain_get_root() { local d="${1}"; local n; n="$(awk -F. '{print NF}' <<<"${d}")"; if ((n > 2)); then cut -d. -f2- <<<"${d}"; else echo "${d}"; fi; }
    function nginx_server_create() { CALLS+=" nginx"; }
    function cloudflare_delete_record() { return 0; }
    function cloudflare_set_record() { CALLS+=" dns"; return ${TMD_CF_RESULT:-0}; }
    function wait_for_dns_propagation() { return 0; }
    function certbot_certificate_install_auto() { CALLS+=" cert"; return 0; }
    function nginx_server_add_http2_support() { return 0; }
    SUPPORT_CLOUDFLARE_STATUS="enabled"; PACKAGES_CERTBOT_STATUS="enabled"; PACKAGES_CERTBOT_CONFIG_MAILA="ops@example.com"; SERVER_IP="203.0.113.7"

    local domain stage expected
    for domain in "example.com" "www.example.com" "app.example.com"; do
        for stage in all defer finalize; do
            tmd_reset
            BROLIT_DOMAIN_CONFIG_STAGE="${stage}" project_update_domain_config "${domain}" "proxy" "proxy" "8081" >/dev/null
            case "${stage}" in
                all) expected="nginx dns cert" ;;
                defer) expected="nginx" ;;
                finalize) expected="dns cert" ;;
            esac
            local seen
            seen="$(echo "${CALLS}" | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ' | sed 's/ $//')"
            local want
            want="$(echo "${expected}" | tr ' ' '\n' | sort -u | tr '\n' ' ' | sed 's/ $//')"
            [[ "${seen}" == "${want}" ]] && tmd_check "${domain} / ${stage}: ${want}" yes || tmd_check "${domain} / ${stage}: wanted '${want}' saw '${seen}'" no
        done
    done

    # Without the variable it behaves as before (all)
    tmd_reset
    unset BROLIT_DOMAIN_CONFIG_STAGE
    project_update_domain_config "example.com" "proxy" "proxy" "8081" >/dev/null
    tmd_called nginx && tmd_called dns && tmd_called cert && tmd_check "default stage is all" yes || tmd_check "default stage is all" no

    # finalize reports a DNS failure, all keeps its old (silent) behaviour
    tmd_reset
    TMD_CF_RESULT=1 BROLIT_DOMAIN_CONFIG_STAGE=finalize project_update_domain_config "example.com" "proxy" "proxy" "8081" >/dev/null
    [[ $? -eq 1 ]] && tmd_check "finalize returns 1 when the DNS record fails" yes || tmd_check "finalize returns 1 when the DNS record fails" no

    BROLIT_DOMAIN_CONFIG_STAGE=bogus project_update_domain_config "example.com" "proxy" "proxy" "8081" >/dev/null
    [[ $? -eq 1 ]] && tmd_check "an unknown stage is refused" yes || tmd_check "an unknown stage is refused" no

}

# 2. The order of the steps of migrate ----------------------------------------
function tmd_orchestration() {

    tmd_reload
    tmd_quiet
    local step
    for step in migrate_check_docker_project migrate_check_ssh_connectivity migrate_check_dest_docker migrate_check_dest_brolit \
        migrate_check_dest_dns_ssl_config migrate_check_dest_path_collision migrate_capture_source migrate_transfer_artifact \
        migrate_trigger_remote_restore migrate_verify_destination migrate_switch_dns migrate_decommission_source; do
        eval "function ${step}() { CALLS+=\" ${step#migrate_}\"; return \${TMD_RESULT_${step}:-0}; }"
    done
    function migrate_check_dest_defer_support() { CALLS+=" defer_support"; return ${TMD_SUPPORT:-0}; }
    function migrate_get_dest_server_name() { echo "dest"; }
    function migrate_resolve_dest_path() { echo "/var/www/${1}"; }

    tmd_reset
    _migrate_site_run "shop.example.com" "203.0.113.9" "root" "22" "/tmp/key" "false" "false" "false" "false" "" "local"
    [[ $? -eq 0 && "${CALLS}" == *"trigger_remote_restore verify_destination switch_dns"* ]] \
        && tmd_check "success: restore, verify, then switch DNS" yes || tmd_check "success order" no

    tmd_reset; TMD_RESULT_migrate_verify_destination=1
    _migrate_site_run "shop.example.com" "203.0.113.9" "root" "22" "/tmp/key" "false" "false" "false" "false" "" "local"
    [[ $? -ne 0 ]] && ! tmd_called switch_dns && tmd_check "a failed verification never switches the DNS" yes || tmd_check "failed verification reached the DNS" no
    unset TMD_RESULT_migrate_verify_destination

    tmd_reset; TMD_RESULT_migrate_trigger_remote_restore=1
    _migrate_site_run "shop.example.com" "203.0.113.9" "root" "22" "/tmp/key" "false" "false" "false" "false" "" "local"
    [[ $? -ne 0 ]] && ! tmd_called verify_destination && ! tmd_called switch_dns && tmd_check "a failed restore reaches neither verification nor DNS" yes || tmd_check "failed restore went on" no
    unset TMD_RESULT_migrate_trigger_remote_restore

    tmd_reset; TMD_RESULT_migrate_switch_dns=1
    _migrate_site_run "shop.example.com" "203.0.113.9" "root" "22" "/tmp/key" "true" "false" "false" "false" "" "local"
    [[ $? -ne 0 ]] && tmd_called switch_dns && tmd_check "a failed DNS switch fails the migration" yes || tmd_check "failed switch was ignored" no
    unset TMD_RESULT_migrate_switch_dns

    tmd_reset; TMD_SUPPORT=1
    _migrate_site_run "shop.example.com" "203.0.113.9" "root" "22" "/tmp/key" "false" "false" "false" "false" "" "local"
    [[ $? -ne 0 ]] && ! tmd_called capture_source && tmd_check "an old destination is refused before anything is captured" yes || tmd_check "old destination was accepted" no
    unset TMD_SUPPORT

}

# 3. The restore command ------------------------------------------------------
function tmd_restore_command() {

    tmd_reload
    tmd_quiet
    function brolit_job_control_mark_noncancellable() { return 0; }
    local seen=""
    function _migrate_ssh() { seen="${5}"; return 0; }
    migrate_trigger_remote_restore "root" "203.0.113.9" "22" "/tmp/key" "shop.example.com" "local"
    [[ "${seen}" == *"BROLIT_DOMAIN_CONFIG_STAGE=defer ./runner.sh -t restore"* ]] \
        && tmd_check "the remote restore runs with the DNS and certificate steps deferred" yes || tmd_check "restore command: ${seen}" no

}

# 4. The destination version -------------------------------------------------
function tmd_version_gate() {

    tmd_reload
    tmd_quiet
    local tmp; tmp="$(mktemp -d)"; mkdir -p "${tmp}/release"
    MIGRATE_DEST_BROLIT_DIR="${tmp}"
    # Run the very command the shell would send, locally, against a version.env.
    function _migrate_ssh() { bash -c "${5}"; }

    local version want
    for pair in "3.15.8:fail" "3.15.9:ok" "3.15.10:ok" "3.16.0:ok" "3.9.0:fail" "3.14.31:fail"; do
        version="${pair%%:*}"; want="${pair##*:}"
        printf 'BROLIT_RELEASE_VERSION="%s"\nBROLIT_REPORT_PROTOCOL_VERSION="1"\n' "${version}" > "${tmp}/release/version.env"
        migrate_check_dest_defer_support "root" "h" "22" "/k"
        local rc=$?
        { [[ ${want} == "ok" && ${rc} -eq 0 ]] || [[ ${want} == "fail" && ${rc} -ne 0 ]]; } && tmd_check "destination ${version} -> ${want}" yes || tmd_check "destination ${version} should ${want}, rc=${rc}" no
    done
    rm -f "${tmp}/release/version.env"
    migrate_check_dest_defer_support "root" "h" "22" "/k"
    [[ $? -ne 0 ]] && tmd_check "a destination with no version is refused" yes || tmd_check "no version accepted" no
    rm -rf "${tmp}"
    MIGRATE_MIN_DEST_VERSION="3.15.9"

}

# 5. Verification fallback ----------------------------------------------------
function tmd_verification() {

    tmd_reload
    tmd_quiet
    function _migrate_probe_status() { if [[ "${1}" == "https" ]]; then echo "${TMD_HTTPS:-000}"; else echo "${TMD_HTTP:-301}"; fi; }
    local ssh_rc=0
    function _migrate_ssh() { return ${ssh_rc}; }

    TMD_HTTPS=000 TMD_HTTP=301; ssh_rc=0
    migrate_verify_destination "root" "203.0.113.9" "22" "/k" "shop.example.com"
    [[ $? -eq 0 ]] && tmd_check "behind a gateway (no cert, HTTP redirects) the local stack check passes it" yes || tmd_check "local stack check ignored" no

    ssh_rc=1
    migrate_verify_destination "root" "203.0.113.9" "22" "/k" "shop.example.com"
    [[ $? -ne 0 ]] && tmd_check "a stack that does not answer locally fails verification" yes || tmd_check "dead stack passed" no

    TMD_HTTPS=502; ssh_rc=0
    migrate_verify_destination "root" "203.0.113.9" "22" "/k" "shop.example.com"
    [[ $? -ne 0 ]] && tmd_check "an HTTPS 5xx still fails, whatever the local check says" yes || tmd_check "502 passed" no

    TMD_HTTPS=200
    migrate_verify_destination "root" "203.0.113.9" "22" "/k" "shop.example.com"
    [[ $? -eq 0 ]] && tmd_check "a healthy HTTPS answer passes" yes || tmd_check "200 failed" no
    unset TMD_HTTPS TMD_HTTP

}

# 6. The DNS switch and its rollback -----------------------------------------
function tmd_switch() {

    tmd_reload
    tmd_quiet
    function domain_get_root() { echo "example.com"; }
    SUPPORT_CLOUDFLARE_STATUS="enabled"
    local previous="5.161.255.48" finalize_rc=0 https="200" http="301"
    function cloudflare_get_record_details() { echo "${previous}"; }
    function cloudflare_set_record() { CALLS+=" rollback:${5}"; return 0; }
    function _migrate_ssh() { CALLS+=" finalize"; return ${finalize_rc}; }
    function _migrate_probe_status() { if [[ "${1}" == "https" ]]; then echo "${https}"; else echo "${http}"; fi; }

    tmd_reset
    migrate_switch_dns "root" "203.0.113.9" "22" "/k" "shop.example.com"
    [[ $? -eq 0 && "${CALLS}" == " finalize" ]] && tmd_check "switched and answering: no rollback" yes || tmd_check "happy path: ${CALLS}" no

    tmd_reset; finalize_rc=1
    migrate_switch_dns "root" "203.0.113.9" "22" "/k" "shop.example.com"
    [[ $? -ne 0 && "${CALLS}" == *"rollback:5.161.255.48"* ]] && tmd_check "a DNS step that keeps failing puts the previous address back" yes || tmd_check "no rollback after failed finalize: ${CALLS}" no
    [[ "$(echo "${CALLS}" | grep -o finalize | wc -l | tr -d ' ')" == "3" ]] && tmd_check "the DNS step is tried three times before giving up" yes || tmd_check "attempts: ${CALLS}" no
    finalize_rc=0

    # a transient failure that passes on its own does not fail the migration
    tmd_reset
    local tries=0
    function _migrate_ssh() { CALLS+=" finalize"; tries=$((tries + 1)); [[ ${tries} -ge 2 ]] && return 0; return 1; }
    migrate_switch_dns "root" "203.0.113.9" "22" "/k" "shop.example.com"
    [[ $? -eq 0 && "${CALLS}" != *"rollback"* && "$(echo "${CALLS}" | grep -o finalize | wc -l | tr -d ' ')" == "2" ]] \
        && tmd_check "a transient DNS provider error is retried and the switch goes through" yes || tmd_check "transient failure not retried: ${CALLS}" no
    function _migrate_ssh() { CALLS+=" finalize"; return ${finalize_rc}; }

    tmd_reset; https=502; http=301
    migrate_switch_dns "root" "203.0.113.9" "22" "/k" "shop.example.com"
    [[ $? -ne 0 && "${CALLS}" == *"rollback:5.161.255.48"* ]] && tmd_check "a site that does not answer after the switch is rolled back" yes || tmd_check "no rollback after a dead front door: ${CALLS}" no

    tmd_reset; https=000; http=200
    migrate_switch_dns "root" "203.0.113.9" "22" "/k" "shop.example.com"
    [[ $? -eq 0 && "${CALLS}" != *"rollback"* ]] && tmd_check "plain HTTP serving the site (certificate pending) is accepted" yes || tmd_check "HTTP-only rejected: ${CALLS}" no

    tmd_reset; https=502; http=301; previous="shop.example.net"
    migrate_switch_dns "root" "203.0.113.9" "22" "/k" "shop.example.com"
    [[ $? -ne 0 && "${CALLS}" != *"rollback:"* ]] && tmd_check "a previous value that is not an address is never rewritten blindly" yes || tmd_check "blind rollback: ${CALLS}" no

}

function test_migrate_defers_dns() {

    TMD_FAILED=0
    echo "-- stages of project_update_domain_config"; tmd_stages
    echo "-- order of the migrate steps"; tmd_orchestration
    echo "-- restore command"; tmd_restore_command
    echo "-- destination version gate"; tmd_version_gate
    echo "-- verification"; tmd_verification
    echo "-- DNS switch and rollback"; tmd_switch
    return ${TMD_FAILED}

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "========================================="
    echo "migrate switches the DNS only after verification"
    echo "========================================="
    test_migrate_defers_dns || exit 1
    echo "All tests completed"
fi
