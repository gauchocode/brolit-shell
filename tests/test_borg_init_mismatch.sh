#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Regression tests for the borgmatic init usability check. A repository that
# already exists under a DIFFERENT encryption mode (e.g. a legacy repokey
# mirror) must be treated as usable (rc 0 + warning) instead of failing the
# whole backup job, while genuine failures keep failing with their classified
# reason. Drives the real functions with a fake borgmatic binary; no network,
# no repositories, no credentials.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/log_and_display_helper.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/borg_storage_controller.sh" >/dev/null 2>&1

TEST_TMP=""
EVENTS_FILE=""

function mismatch_setup() {

    TEST_TMP="$(mktemp -d)"
    EVENTS_FILE="${TEST_TMP}/events.log"
    : > "${EVENTS_FILE}"

    # Capture-only stubs: the assertions read EVENTS_FILE.
    function display() { echo "display $*" >> "${EVENTS_FILE}"; }
    function clear_previous_lines() { echo "clear" >> "${EVENTS_FILE}"; }
    function log_event() { echo "event $1: $2" >> "${EVENTS_FILE}"; }

    cat > "${TEST_TMP}/fake-borgmatic" <<'FAKE_EOF'
#!/usr/bin/env bash
cat "${FAKE_MSG}"
exit "${FAKE_RC}"
FAKE_EOF
    chmod +x "${TEST_TMP}/fake-borgmatic"

    : > "${TEST_TMP}/config.yml"

}

function mismatch_teardown() {

    rm -rf "${TEST_TMP}"

}

function run_init_with() {

    local message="${1}" rc="${2}"
    printf '%s\n' "${message}" > "${TEST_TMP}/msg.txt"
    export FAKE_MSG="${TEST_TMP}/msg.txt"
    export FAKE_RC="${rc}"
    _initialize_repository_for_config "${TEST_TMP}/config.yml" "${TEST_TMP}/fake-borgmatic" "test-label" > /dev/null 2>&1

}

function events() {

    cat "${EVENTS_FILE}"

}

################################################################################
# Tests
################################################################################

function test_classifier_classes() {

    echo "=== Test: init failure classifier classes ==="

    local got
    got="$(borg_init_failure_reason 'Requested encryption mode "none" does not match existing repository encryption mode "repokey"')"
    [[ "${got}" == "encryption_mismatch" ]] || { echo "FAILED: expected encryption_mismatch, got '${got}'"; return 1; }

    got="$(borg_init_failure_reason 'Failed to create/acquire the lock /repo/lock.exclusive (timeout).')"
    [[ "${got}" == "lock" ]] || { echo "FAILED: expected lock, got '${got}'"; return 1; }

    got="$(borg_init_result_classes_probe 'ssh: connect to host port 23: Connection timed out')"
    [[ "${got}" == "network" ]] || { echo "FAILED: expected network, got '${got}'"; return 1; }

    got="$(borg_init_result_classes_probe 'remote: Permission denied (publickey).')"
    [[ "${got}" == "auth" ]] || { echo "FAILED: expected auth, got '${got}'"; return 1; }

    got="$(borg_init_result_classes_probe 'repository does not exist')"
    [[ "${got}" == "repo_missing" ]] || { echo "FAILED: expected repo_missing, got '${got}'"; return 1; }

    echo "PASSED: classifier classes"

}

# Small indirection so classifier cases reuse the real function without
# hardcoding unrelated branches here.
function borg_init_result_classes_probe() {

    borg_init_failure_reason "${1}"

}

function test_encryption_mismatch_is_usable() {

    echo "=== Test: existing repo with different encryption mode is usable ==="

    run_init_with 'An error occurred Error running actions for repository Requested encryption mode "none" does not match existing repository encryption mode "repokey" Error running configuration' 2
    local rc=$?

    if [[ ${rc} -ne 0 ]]; then
        echo "FAILED: mismatch on an existing repo must be usable (rc 0), got ${rc}"
        return 1
    fi
    if ! grep -q "different encryption mode" <<<"$(events)"; then
        echo "FAILED: expected a visible warning about the encryption mode"
        return 1
    fi

    echo "PASSED: encryption mismatch treated as usable with warning"

}

function test_already_exists_is_usable() {

    echo "=== Test: already-existing repo stays usable ==="

    run_init_with 'Repository /mnt/repo already exists' 2
    local rc=$?

    if [[ ${rc} -ne 0 ]]; then
        echo "FAILED: already-existing repo must be usable, got ${rc}"
        return 1
    fi
    if ! grep -q "already exists" <<<"$(events)"; then
        echo "FAILED: expected the already-exists info event"
        return 1
    fi

    echo "PASSED: already-existing repo usable"

}

function test_genuine_failure_still_fails() {

    echo "=== Test: genuine init failure still fails ==="

    run_init_with 'something exploded unexpectedly' 3
    local rc=$?

    if [[ ${rc} -eq 0 ]]; then
        echo "FAILED: unknown init failure must not be treated as usable"
        return 1
    fi
    if ! grep -q "init failure class: unknown" <<<"$(events)"; then
        echo "FAILED: expected the unknown failure class event"
        return 1
    fi

    echo "PASSED: genuine failure keeps failing"

}

function test_fresh_init_success() {

    echo "=== Test: fresh init success path ==="

    run_init_with '' 0
    local rc=$?

    if [[ ${rc} -ne 0 ]] || ! grep -q "initialized successfully" <<<"$(events)"; then
        echo "FAILED: clean init must succeed with its info event"
        return 1
    fi

    echo "PASSED: fresh init success"

}

# Run all tests when executed directly (the full suite sources libs first).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo ""
    echo "========================================="
    echo "Borg Init Mismatch Tests"
    echo "========================================="
    echo ""

    mismatch_setup

    test_classifier_classes || exit 1
    echo ""
    : > "${EVENTS_FILE}"
    test_encryption_mismatch_is_usable || exit 1
    echo ""
    : > "${EVENTS_FILE}"
    test_already_exists_is_usable || exit 1
    echo ""
    : > "${EVENTS_FILE}"
    test_genuine_failure_still_fails || exit 1
    echo ""
    : > "${EVENTS_FILE}"
    test_fresh_init_success || exit 1
    echo ""

    mismatch_teardown

    echo "========================================="
    echo "All tests completed"
fi
