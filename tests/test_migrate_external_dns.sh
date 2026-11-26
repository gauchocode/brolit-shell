#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.15
#############################################################################
#
# With --dns-mode external the caller (brolit-admin) owns the domain's DNS:
#   1. `migrate` stops after the destination is verified and never touches DNS.
#   2. The destination must run a shell that has `project finalize-certificate`.
#   3. The `certificate` stage of project_update_domain_config only requests the
#      certificate: no web server config, no DNS record.
#   4. certbot_certificate_install_auto writes no Cloudflare record when
#      BROLIT_DNS_WRITES=disabled.
# Everything remote or external is faked.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1091
source "${TEST_LOADER_DIR}/../libs/commons.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/project_helper.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/site_migration_helper.sh" >/dev/null 2>&1

CALLS=""
function tme_reset() { CALLS=""; }
function tme_called() { [[ " ${CALLS} " == *" ${1} "* ]]; }
function tme_check() {
    local label="${1}" ok="${2}"
    if [[ ${ok} == "yes" ]]; then echo "PASS: ${label}"; else echo "FAIL: ${label} (calls: ${CALLS})"; TME_FAILED=1; fi
}
function tme_reload() {
    # shellcheck disable=SC1090
    source "${TEST_LOADER_DIR}/../libs/local/project_helper.sh" >/dev/null 2>&1
    # shellcheck disable=SC1090
    source "${TEST_LOADER_DIR}/../libs/local/site_migration_helper.sh" >/dev/null 2>&1
}
function tme_quiet() {
    function log_event() { :; }
    function display() { :; }
    function log_subsection() { :; }
    function log_section() { :; }
    function clear_previous_lines() { :; }
    function brolit_progress() { :; }
    function sleep() { :; }
}

function tme_certificate_stage() {
    tme_reload; tme_quiet
    function domain_get_root() { local d="${1}"; local n; n="$(awk -F. '{print NF}' <<<"${d}")"; if ((n > 2)); then cut -d. -f2- <<<"${d}"; else echo "${d}"; fi; }
    function nginx_server_create() { CALLS+=" nginx"; }
    function cloudflare_delete_record() { CALLS+=" dns"; return 0; }
    function cloudflare_set_record() { CALLS+=" dns"; return 0; }
    function wait_for_dns_propagation() { return 0; }
    function certbot_certificate_install_auto() { CALLS+=" cert:${BROLIT_DNS_WRITES:-enabled}"; return 0; }
    function nginx_server_add_http2_support() { return 0; }
    SUPPORT_CLOUDFLARE_STATUS="enabled"; PACKAGES_CERTBOT_STATUS="enabled"; PACKAGES_CERTBOT_CONFIG_MAILA="ops@example.com"; SERVER_IP="203.0.113.7"
    local domain
    for domain in "example.com" "www.example.com" "app.example.com"; do
        tme_reset
        BROLIT_DOMAIN_CONFIG_STAGE=certificate project_update_domain_config "${domain}" "proxy" "proxy" "8081" >/dev/null
        [[ "${CALLS}" == " cert:disabled" ]] && tme_check "${domain}: certificate only, with DNS writes disabled" yes || tme_check "${domain}: certificate stage did '${CALLS}'" no
    done
    tme_reset
    BROLIT_DOMAIN_CONFIG_STAGE=all project_update_domain_config "example.com" "proxy" "proxy" "8081" >/dev/null
    tme_called "cert:enabled" && tme_check "the default stage still lets the certificate step write DNS" yes || tme_check "all stage changed" no
}

function tme_certbot_guard() {
    tme_reload; tme_quiet
    # Static check on the real function body: every Cloudflare write is behind the guard.
    local body
    body="$(declare -f certbot_certificate_install_auto 2>/dev/null)"
    [[ -z "${body}" ]] && source "${TEST_LOADER_DIR}/../libs/apps/certbot_helper.sh" >/dev/null 2>&1 && body="$(declare -f certbot_certificate_install_auto)"
    [[ "${body}" == *'BROLIT_DNS_WRITES:-enabled'* ]] && tme_check "certbot install honours BROLIT_DNS_WRITES" yes || tme_check "no BROLIT_DNS_WRITES guard in certbot_certificate_install_auto" no
    local writes guarded
    writes="$(grep -c 'cloudflare_update_record\|cloudflare_set_ssl_mode' "${TEST_LOADER_DIR}/../libs/apps/certbot_helper.sh")"
    guarded="$(grep -c 'BROLIT_DNS_WRITES' "${TEST_LOADER_DIR}/../libs/apps/certbot_helper.sh")"
    [[ ${guarded} -ge 3 ]] && tme_check "each Cloudflare write path is guarded (${guarded} guards, ${writes} writes)" yes || tme_check "unguarded writes" no
}

function tme_orchestration() {
    tme_reload; tme_quiet
    local step
    for step in migrate_check_docker_project migrate_check_ssh_connectivity migrate_check_dest_docker migrate_check_dest_brolit \
        migrate_check_dest_dns_ssl_config migrate_check_dest_path_collision migrate_capture_source migrate_transfer_artifact \
        migrate_trigger_remote_restore migrate_verify_destination migrate_switch_dns migrate_decommission_source; do
        eval "function ${step}() { CALLS+=\" ${step#migrate_}\"; return \${TME_RESULT_${step}:-0}; }"
    done
    function migrate_check_dest_defer_support() { CALLS+=" defer_support"; return 0; }
    function migrate_get_dest_server_name() { echo "dest"; }
    function migrate_resolve_dest_path() { echo "/var/www/${1}"; }

    tme_reset
    MIGRATE_DNS_MODE=external _migrate_site_run "shop.example.com" "203.0.113.9" "root" "22" "/tmp/key" "false" "false" "false" "false" "" "local"
    [[ $? -eq 0 && "${CALLS}" == *"verify_destination"* ]] && ! tme_called switch_dns && tme_check "external: verified, DNS never switched by the shell" yes || tme_check "external order" no

    tme_reset
    MIGRATE_DNS_MODE=external TME_RESULT_migrate_verify_destination=1 _migrate_site_run "shop.example.com" "203.0.113.9" "root" "22" "/tmp/key" "false" "false" "false" "false" "" "local"
    [[ $? -ne 0 ]] && tme_check "external: a failed verification still fails the migration" yes || tme_check "external hid a failed verification" no

    tme_reset
    _migrate_site_run "shop.example.com" "203.0.113.9" "root" "22" "/tmp/key" "false" "false" "false" "false" "" "local"
    tme_called switch_dns && tme_check "shell mode (default) still switches the DNS" yes || tme_check "default mode lost the switch" no
}

function tme_version_gate() {
    tme_reload; tme_quiet
    local tmp; tmp="$(mktemp -d)"; mkdir -p "${tmp}/release"
    MIGRATE_DEST_BROLIT_DIR="${tmp}"
    function _migrate_ssh() { bash -c "${5}"; }
    local pair version want mode rc
    for pair in "3.15.9:shell:ok" "3.15.9:external:fail" "3.15.11:external:fail" "3.15.12:external:ok" "3.16.0:external:ok"; do
        IFS=: read -r version mode want <<<"${pair}"
        printf 'BROLIT_RELEASE_VERSION="%s"\nBROLIT_REPORT_PROTOCOL_VERSION="1"\n' "${version}" > "${tmp}/release/version.env"
        MIGRATE_DNS_MODE="${mode}" migrate_check_dest_defer_support "root" "h" "22" "/k"; rc=$?
        { [[ ${want} == ok && ${rc} -eq 0 ]] || [[ ${want} == fail && ${rc} -ne 0 ]]; } && tme_check "destination ${version}, ${mode} mode -> ${want}" yes || tme_check "destination ${version}, ${mode} should ${want}, rc=${rc}" no
    done
    rm -rf "${tmp}"
}

function test_migrate_external_dns() {
    TME_FAILED=0
    echo "-- certificate stage"; tme_certificate_stage
    echo "-- certbot guard"; tme_certbot_guard
    echo "-- migrate order"; tme_orchestration
    echo "-- destination version"; tme_version_gate
    return ${TME_FAILED}
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "========================================="
    echo "migrate --dns-mode external leaves the DNS to the caller"
    echo "========================================="
    test_migrate_external_dns || exit 1
    echo "All tests completed"
fi
