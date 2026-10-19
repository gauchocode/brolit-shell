#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Regression tests for the Cloudflare DNS flow bugs found live on
# gaucho-dev02 (2026-10-16):
#   1. cloudflare_set_ssl_mode received the full subdomain and resolved a
#      ZONE with it (always missing), silently skipping the SSL mode change.
#   2. cloudflare_update_record demanded the exact record type (CNAME) while
#      the creation flow provisions A records: "record not found" plus the
#      proxy flag silently left off.
#   3. Debug logs embedded the Cloudflare API key in clear text.
#   4. Non-boolean proxy_status values shipped invalid JSON to the API.
#
# Drives the real functions with a PATH-faked curl and stubbed display/log
# helpers. No network, no credentials.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/log_and_display_helper.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/apps/cloudflare_helper.sh" >/dev/null 2>&1

TEST_TMP=""
EVENTS_FILE=""
CURL_LOG=""

function cf_dns_setup() {

    TEST_TMP="$(mktemp -d)"
    EVENTS_FILE="${TEST_TMP}/events.log"
    CURL_LOG="${TEST_TMP}/curl.log"
    : > "${EVENTS_FILE}"
    : > "${CURL_LOG}"
    # The fake curl runs as a child process: it needs the log path exported.
    export CURL_LOG

    function display() { echo "display $*" >> "${EVENTS_FILE}"; }
    function clear_previous_lines() { :; }
    function log_event() { echo "event $1: $2" >> "${EVENTS_FILE}"; }
    # Used by cloudflare_set_ssl_mode to derive the zone root; identity for
    # the fixture shape (the derivation function itself is out of scope).
    function domain_get_root() { echo "broobe.com"; }

    export SUPPORT_CLOUDFLARE_EMAIL="test@example.com"
    export SUPPORT_CLOUDFLARE_API_KEY="secretkey123"

    mkdir -p "${TEST_TMP}/bin"
    cat > "${TEST_TMP}/bin/curl" <<'FAKE_EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${CURL_LOG}"
case "${CURL_FAKE_MODE:-ok}" in
    ok)
        case "$*" in
            *"zones?"*)
                if [[ "$*" == *"name=dev.broobe.com"* ]]; then
                    printf '{"result":[],"success":true}'
                else
                    printf '{"result":[{"id":"zone111"}],"success":true}'
                fi
                ;;
            *"dns_records?name="*)
                if [[ "$*" == *"type=CNAME"* ]]; then
                    printf '{"result":[],"success":true}'
                else
                    printf '{"result":[{"id":"rec999","type":"A","name":"dev.broobe.com"}],"success":true}'
                fi
                ;;
            *"/settings/ssl"*)
                printf '{"result":{"value":"full"},"success":true}'
                ;;
            *"PATCH"*)
                printf '{"result":{"proxied":true},"success":true}'
                ;;
            *)
                printf '{"success":true}'
                ;;
        esac
        ;;
    norecord)
        # Zone resolves fine, but the record genuinely does not exist.
        case "$*" in
            *"zones?"*)
                printf '{"result":[{"id":"zone111"}],"success":true}'
                ;;
            *)
                printf '{"result":[],"success":true}'
                ;;
        esac
        ;;
    fail)
        printf '{"success":false,"errors":[]}'
        ;;
esac
exit 0
FAKE_EOF
    chmod +x "${TEST_TMP}/bin/curl"
    export PATH="${TEST_TMP}/bin:${PATH}"

}

function cf_dns_teardown() {

    rm -rf "${TEST_TMP}"

    # Drop the stubs and re-source the real helpers so later tests in the
    # interactive suite never inherit them (the domain_get_root stub is
    # hardwired to the fixture and MUST NOT leak).
    unset -f display log_event clear_previous_lines domain_get_root
    # shellcheck disable=SC1090
    source "${TEST_LOADER_DIR}/../libs/local/log_and_display_helper.sh" >/dev/null 2>&1
    # shellcheck disable=SC1090
    source "${TEST_LOADER_DIR}/../libs/local/domains_helper.sh" >/dev/null 2>&1

}

################################################################################
# Tests
################################################################################

function test_ssl_mode_uses_root_zone() {

    echo "=== Test: SSL mode derives the root zone from the site domain ==="

    cloudflare_set_ssl_mode "dev.broobe.com" "full"
    local rc=$?

    if [[ ${rc} -ne 0 ]]; then
        echo "FAILED: ssl mode must succeed for a subdomain input (rc ${rc})"
        return 1
    fi
    if grep -q "zones?name=dev.broobe.com" "${CURL_LOG}"; then
        echo "FAILED: zone lookup must use the root domain, not the subdomain"
        return 1
    fi
    if ! grep -q "zones?name=broobe.com" "${CURL_LOG}"; then
        echo "FAILED: expected a zone lookup for broobe.com"
        return 1
    fi
    if ! grep -q "settings/ssl" "${CURL_LOG}"; then
        echo "FAILED: expected the SSL settings PATCH"
        return 1
    fi

    echo "PASSED: SSL mode resolves the root zone"

}

function test_update_record_tolerates_other_type() {

    echo "=== Test: record update falls back to untyped lookup and patches proxy only ==="

    # Typed (CNAME) lookup misses; the A record must still be found and the
    # patch must carry ONLY the proxy flag (type/content untouched).
    : > "${CURL_LOG}"
    cloudflare_update_record "broobe.com" "dev.broobe.com" "CNAME" "true" "broobe.com"
    local rc=$?

    if [[ ${rc} -ne 0 ]]; then
        echo "FAILED: existing A record must be usable for the proxy update (rc ${rc})"
        return 1
    fi
    if ! grep -q 'dns_records/rec999' "${CURL_LOG}"; then
        echo "FAILED: expected a PATCH against the untyped-lookup record id"
        return 1
    fi
    if ! grep -q -- '--data {"proxied":true}' "${CURL_LOG}"; then
        echo "FAILED: expected a proxy-only patch payload"
        return 1
    fi

    echo "PASSED: untyped fallback patches the proxy flag"

}

function test_update_record_typed_hit_refreshes_content() {

    echo "=== Test: typed hit refreshes type/content alongside the proxy flag ==="

    # A-type lookup matches: the patch must be a full refresh (this is what
    # keeps an apex A record following a server IP migration).
    : > "${CURL_LOG}"
    cloudflare_update_record "broobe.com" "dev.broobe.com" "A" "true" "1.2.3.4"
    local rc=$?

    if [[ ${rc} -ne 0 ]]; then
        echo "FAILED: typed A lookup must succeed (rc ${rc})"
        return 1
    fi
    if ! grep -q -- '--data {"type":"A","name":"dev.broobe.com","content":"1.2.3.4","ttl":3600,"proxied":true}' "${CURL_LOG}"; then
        echo "FAILED: expected a full refresh payload on the typed path"
        return 1
    fi

    echo "PASSED: typed hit refreshes content"

}

function test_update_record_missing_is_an_error() {

    echo "=== Test: genuinely missing record keeps failing ==="

    # norecord: the zone resolves but no record is returned — the real
    # incident shape (a zone-miss would mask the record-miss path).
    CURL_FAKE_MODE="norecord" cloudflare_update_record "broobe.com" "ghost.broobe.com" "CNAME" "true" "broobe.com"
    local rc=$?

    if [[ ${rc} -eq 0 ]]; then
        echo "FAILED: missing record must not report success"
        return 1
    fi
    if ! grep -q "nothing to update" "${EVENTS_FILE}"; then
        echo "FAILED: expected the explicit not-found error event"
        return 1
    fi

    echo "PASSED: missing record fails with a clear error"

}

function test_invalid_proxy_status_rejected() {

    echo "=== Test: non-boolean proxy_status is rejected before the API ==="

    : > "${CURL_LOG}"
    CURL_FAKE_MODE="norecord" cloudflare_update_record "broobe.com" "x.broobe.com" "A" "enable" "1.2.3.4"
    local rc=$?

    if [[ ${rc} -eq 0 ]]; then
        echo "FAILED: 'enable' must be rejected (invalid JSON payload)"
        return 1
    fi
    if ! grep -q "proxy_status must be" "${EVENTS_FILE}"; then
        echo "FAILED: expected the validation error event"
        return 1
    fi
    if [[ "$(curl_calls_count)" -ne 0 ]]; then
        echo "FAILED: validation must happen before any API call"
        return 1
    fi

    echo "PASSED: non-boolean proxy_status rejected"

}

function test_logs_redact_credentials() {

    echo "=== Test: logged commands never contain the API key ==="

    : > "${EVENTS_FILE}"
    : > "${CURL_LOG}"
    # The update path logs the full API command (with credentials embedded
    # in the historical code); the log stream must carry REDACTED only.
    cloudflare_update_record "broobe.com" "dev.broobe.com" "A" "true" "1.2.3.4"

    if grep -q "secretkey123" "${EVENTS_FILE}"; then
        echo "FAILED: the API key leaked into the log stream"
        return 1
    fi
    if ! grep -q "REDACTED" "${EVENTS_FILE}"; then
        echo "FAILED: expected the redacted command in the log stream"
        return 1
    fi

    echo "PASSED: credentials redacted in logs"

}

function curl_calls_count() {

    grep -c . "${CURL_LOG}" 2>/dev/null || true

}

# Suite entry point: runs every case with its own setup/teardown so the
# interactive tests suite (tests_suite.sh) can call this by name.
function test_cloudflare_dns_flow() {

    cf_dns_setup

    local failed=0
    test_ssl_mode_uses_root_zone || failed=1
    echo ""
    test_update_record_tolerates_other_type || failed=1
    echo ""
    test_update_record_typed_hit_refreshes_content || failed=1
    echo ""
    test_update_record_missing_is_an_error || failed=1
    echo ""
    test_invalid_proxy_status_rejected || failed=1
    echo ""
    test_logs_redact_credentials || failed=1
    echo ""

    cf_dns_teardown

    return ${failed}

}

# Run all tests when executed directly (the full suite sources libs first).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo ""
    echo "========================================="
    echo "Cloudflare DNS Flow Tests"
    echo "========================================="
    test_cloudflare_dns_flow || exit 1
    echo "========================================="
    echo "All tests completed"
fi
