#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Regression tests for inventory bounds: the Cloudflare zone-id lookup must
# call the API once per distinct root domain (per-process cache) with bounded
# flags, and per-site disk sizing must resolve to an explicit "unknown"
# instead of stalling the whole inventory or fabricating a zero.
#
# Drives the real functions from brolit_lite.sh with faked network/disk
# binaries (PATH override) and stubbed site helpers. No network, no
# credentials, no real configuration.

if ! declare -F _cloudflare_get_zone_id >/dev/null 2>&1; then
    TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
    # shellcheck disable=SC1090
    source "${TEST_LOADER_DIR}/../brolit_lite.sh" >/dev/null 2>&1
fi

################################################################################
# Test setup: fake binaries and site-helper stubs
#
# Globals:
#   INVENTORY_TEST_DIR - created by setup, removed by teardown
################################################################################

function inventory_bounds_setup() {

    INVENTORY_TEST_DIR="$(mktemp -d)"
    export INVENTORY_CALL_LOG="${INVENTORY_TEST_DIR}/calls.log"
    : > "${INVENTORY_CALL_LOG}"
    mkdir -p "${INVENTORY_TEST_DIR}/bin" "${INVENTORY_TEST_DIR}/www/site-a" "${INVENTORY_TEST_DIR}/www/site-b"

    cat > "${INVENTORY_TEST_DIR}/bin/curl" <<'FAKE_EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${INVENTORY_CALL_LOG}"
if [[ "${INVENTORY_FAKE_CURL_MODE:-ok}" == "timeout" ]]; then
    echo "curl: (28) Operation timed out" >&2
    exit 28
fi
printf '{"result":[{"id":"zone123"}],"success":true}'
exit 0
FAKE_EOF
    chmod +x "${INVENTORY_TEST_DIR}/bin/curl"

    cat > "${INVENTORY_TEST_DIR}/bin/du" <<'FAKE_EOF'
#!/usr/bin/env bash
if [[ "${INVENTORY_FAKE_DU_MODE:-ok}" == "fail" ]]; then
    echo "du: slow disk, giving up" >&2
    exit 1
fi
printf '1234\t%s\n' "${@: -1}"
exit 0
FAKE_EOF
    chmod +x "${INVENTORY_TEST_DIR}/bin/du"

    export PATH="${INVENTORY_TEST_DIR}/bin:${PATH}"
    export SUPPORT_CLOUDFLARE_EMAIL="test@example.com"
    export SUPPORT_CLOUDFLARE_API_KEY="test-key"
    PROJECTS_PATH="${INVENTORY_TEST_DIR}/www"

    # Stub out the site helpers: only the du/cloudflare behavior is under test.
    function _project_is_ignored() { echo "false"; }
    function _project_get_type() { echo "other"; }
    function _project_get_install_type() { echo "docker-compose"; }
    function _certbot_certificate_get_valid_days() { echo "70"; }
    function _get_root_domain() { echo "${1}"; }
    function _cloudflare_domain_exists() { echo "false"; }

}

function inventory_bounds_teardown() {

    rm -rf "${INVENTORY_TEST_DIR}"

}

function inventory_curl_calls() {

    grep -c . "${INVENTORY_CALL_LOG}" 2>/dev/null || true

}

################################################################################
# Test: one API call per distinct root domain per process
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_cloudflare_zone_cache() {

    echo "=== Test: one API call per distinct root domain ==="

    # NOTE: cache writes only persist in the main shell ($(...) forks and
    # discards them), mirroring the prefetch pattern used by inventory.
    local first second third
    _cloudflare_get_zone_id "example.com" >"${INVENTORY_TEST_DIR}/zone.tmp" 2>/dev/null
    first="$(cat "${INVENTORY_TEST_DIR}/zone.tmp")"
    second="$(_cloudflare_get_zone_id "example.com" 2>/dev/null)"
    third="$(_cloudflare_get_zone_id "other.com" 2>/dev/null)"

    if [[ "${first}" != "zone123" || "${second}" != "zone123" || "${third}" != "zone123" ]]; then
        echo "FAILED: expected zone123 from cache and network (got '${first}' '${second}' '${third}')"
        return 1
    fi
    if [[ "$(inventory_curl_calls)" -ne 2 ]]; then
        echo "FAILED: expected 2 API calls, got $(inventory_curl_calls)"
        return 1
    fi
    if ! grep -q -- "--max-time" "${INVENTORY_CALL_LOG}"; then
        echo "FAILED: curl invocations lack a bounded --max-time flag"
        return 1
    fi

    echo "PASSED: zone cache collapses repeat lookups with bounded calls"

}

################################################################################
# Test: API timeout resolves to not-found instead of hanging
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_cloudflare_timeout_is_failure() {

    echo "=== Test: API timeout resolves to failure ==="

    export INVENTORY_FAKE_CURL_MODE="timeout"
    local output status
    output="$(_cloudflare_get_zone_id "slow.com" 2>/dev/null)"
    status=$?
    export INVENTORY_FAKE_CURL_MODE="ok"

    if [[ ${status} -eq 0 ]]; then
        echo "FAILED: timed-out lookup must not succeed"
        return 1
    fi

    echo "PASSED: timed-out lookup fails fast with not-found"

}

################################################################################
# Test: inventory prefetch collapses per-site lookups to one API call
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_inventory_prefetch_collapses_lookups() {

    echo "=== Test: inventory prefetch collapses per-site lookups ==="

    # Both fixture sites share one root domain: the prefetch pass must call
    # the API once, with every per-site lookup served from the cache.
    function _get_root_domain() { echo "shared.example"; }
    : > "${INVENTORY_CALL_LOG}"
    _sites_directories >/dev/null 2>&1

    if [[ "$(inventory_curl_calls)" -ne 1 ]]; then
        echo "FAILED: expected 1 prefetch API call for 2 sites, got $(inventory_curl_calls)"
        return 1
    fi

    echo "PASSED: prefetch collapses per-site lookups to one call"

}

################################################################################
# Test: failed disk sizing resolves to unknown, never zero or empty
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_site_size_unknown_on_du_failure() {

    echo "=== Test: failed disk sizing is unknown ==="

    export INVENTORY_FAKE_DU_MODE="fail"
    local output
    output="$(_sites_directories 2>/dev/null)"
    export INVENTORY_FAKE_DU_MODE="ok"

    if ! grep -q '"size":"unknown"' <<<"${output}"; then
        echo "FAILED: expected explicit unknown sizes, got: ${output}"
        return 1
    fi
    if grep -q '"size":""\|"size":"0"' <<<"${output}"; then
        echo "FAILED: size must never be empty or zero on failure"
        return 1
    fi

    echo "PASSED: failed disk sizing is explicit unknown"

}

################################################################################
# Test: healthy disk sizing still flows through
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_site_size_healthy_passthrough() {

    echo "=== Test: healthy disk sizing passes through ==="

    local output
    output="$(_sites_directories 2>/dev/null)"

    if ! grep -q '"size":"1234"' <<<"${output}"; then
        echo "FAILED: healthy sizes must pass through, got: ${output}"
        return 1
    fi

    echo "PASSED: healthy disk sizing passes through"

}

# Run all tests when executed directly (the full suite sources libs first).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo ""
    echo "========================================="
    echo "Inventory Bounds Tests"
    echo "========================================="
    echo ""

    inventory_bounds_setup

    test_cloudflare_zone_cache || exit 1
    echo ""
    : > "${INVENTORY_CALL_LOG}"
    test_cloudflare_timeout_is_failure || exit 1
    echo ""
    test_inventory_prefetch_collapses_lookups || exit 1
    echo ""
    test_site_size_unknown_on_du_failure || exit 1
    echo ""
    test_site_size_healthy_passthrough || exit 1
    echo ""

    inventory_bounds_teardown

    echo "========================================="
    echo "All tests completed"
fi
