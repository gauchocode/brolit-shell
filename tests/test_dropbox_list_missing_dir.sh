#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Regression tests for _brolit_dropbox_list() missing-folder handling.
#
# A per-project database folder that was never created must read as an empty
# backup set, not as a provider outage -- even when the uploader reports the
# miss with a generic failure carrying no recognizable message. Real outages
# (parent unreachable, existing-but-unreadable child) must stay failures.
#
# The tests drive the real function with a fake dropbox_uploader executable
# and never touch the network, credentials, or real configuration.

if ! declare -F _brolit_dropbox_list >/dev/null 2>&1; then
    TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
    # shellcheck disable=SC1090
    source "${TEST_LOADER_DIR}/../brolit_lite.sh" >/dev/null 2>&1
fi

################################################################################
# Test setup: fake uploader
#
# Globals:
#   DROPBOX_LIST_TEST_DIR - created by setup, removed by teardown
#   DROPBOX_UPLOADER - pointed at the fake executable
################################################################################

function dropbox_list_test_setup() {

    DROPBOX_LIST_TEST_DIR="$(mktemp -d)"
    export DROPBOX_LIST_CALL_LOG="${DROPBOX_LIST_TEST_DIR}/calls.log"
    : > "${DROPBOX_LIST_CALL_LOG}"

    cat > "${DROPBOX_LIST_TEST_DIR}/fake_uploader.sh" <<'FAKE_EOF'
#!/usr/bin/env bash
# Fake dropbox_uploader: only implements "-q list <path>".
# Last argument is the path; every invocation is appended to the call log.
requested_path="${*: -1}"
printf '%s\n' "${requested_path}" >> "${DROPBOX_LIST_CALL_LOG}"
case "${requested_path}" in
    HOST/projects-online/database)
        printf '[D] presentproj  \n[D] other  \n[D] deniedproj  \n'
        exit 0
        ;;
    HOST2/projects-online)
        printf '[D] site  \n'
        exit 0
        ;;
    HOST2/projects-online/database|HOST2/projects-online/database/*)
        echo 'Some error occured. rerun the script with "-d" option.'
        exit 1
        ;;
    */projects-online/database/presentproj)
        printf '[F] 12345 2026-10-12;02:20:18 presentproj_db_2026-10-12.tar.bz2\n'
        exit 0
        ;;
    */projects-online/database/missingproj)
        # Real-world shape: generic failure, no "not found" wording.
        echo 'Some error occured. rerun the script with "-d" option.'
        exit 1
        ;;
    */projects-online/database/deniedproj)
        echo 'Error 403: insufficient permissions.'
        exit 1
        ;;
    */projects-online/database/oldstyle)
        echo 'list_folder/path/not_found/.'
        exit 1
        ;;
    DOWN/*|DOWN2|DOWN2/*)
        echo 'Timeout while connecting.'
        exit 1
        ;;
    DOWN)
        echo 'Timeout while connecting.'
        exit 1
        ;;
    HOST)
        echo 'Some error occured.'
        exit 1
        ;;
    *)
        echo 'Unexpected path in fake uploader.'
        exit 2
        ;;
esac
FAKE_EOF
    chmod +x "${DROPBOX_LIST_TEST_DIR}/fake_uploader.sh"

    DROPBOX_UPLOADER="${DROPBOX_LIST_TEST_DIR}/fake_uploader.sh"

}

function dropbox_list_test_teardown() {

    rm -rf "${DROPBOX_LIST_TEST_DIR}"

}

function dropbox_list_call_count() {

    wc -l < "${DROPBOX_LIST_CALL_LOG}" | tr -d ' '

}

################################################################################
# Test: missing child with healthy parent reads as empty
#
# Globals:
#   DROPBOX_UPLOADER
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_dropbox_list_missing_child_is_empty() {

    echo "=== Test: missing child with healthy parent reads as empty ==="

    local output status stderr_output
    stderr_output="$(mktemp)"
    output="$(_brolit_dropbox_list "HOST/projects-online/database/missingproj" 2>"${stderr_output}")"
    status=$?

    if [[ ${status} -ne 0 ]]; then
        echo "FAILED: expected exit 0, got ${status}"
        rm -f "${stderr_output}"
        return 1
    fi
    if [[ -n "${output}" ]]; then
        echo "FAILED: expected empty output, got: ${output}"
        rm -f "${stderr_output}"
        return 1
    fi
    if [[ -s "${stderr_output}" ]]; then
        echo "FAILED: expected no stderr diagnostic, got:"
        cat "${stderr_output}"
        rm -f "${stderr_output}"
        return 1
    fi
    if [[ "$(dropbox_list_call_count)" -ne 2 ]]; then
        echo "FAILED: expected child + parent probe calls"
        rm -f "${stderr_output}"
        return 1
    fi

    rm -f "${stderr_output}"
    echo "PASSED: missing child reads as empty without error flag"

}

################################################################################
# Test: legacy recognizable miss message still reads as empty
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_dropbox_list_legacy_miss_message_is_empty() {

    echo "=== Test: legacy recognizable miss message still reads as empty ==="

    local output status
    output="$(_brolit_dropbox_list "HOST/projects-online/database/oldstyle" 2>/dev/null)"
    status=$?

    if [[ ${status} -ne 0 || -n "${output}" ]]; then
        echo "FAILED: legacy miss path regressed (status=${status})"
        return 1
    fi
    if [[ "$(dropbox_list_call_count)" -ne 1 ]]; then
        echo "FAILED: legacy miss must not trigger a parent probe"
        return 1
    fi

    echo "PASSED: legacy miss message path preserved"

}

################################################################################
# Test: existing-but-unreadable child stays a failure (fail closed)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_dropbox_list_unreadable_child_stays_failure() {

    echo "=== Test: existing-but-unreadable child stays a failure ==="

    local output status
    output="$(_brolit_dropbox_list "HOST/projects-online/database/deniedproj" 2>/dev/null)"
    status=$?

    if [[ ${status} -eq 0 ]]; then
        echo "FAILED: unreadable existing child must not read as empty"
        return 1
    fi

    echo "PASSED: unreadable existing child stays a failure"

}

################################################################################
# Test: unreachable parent stays a failure (fail closed)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_dropbox_list_unreachable_parent_stays_failure() {

    echo "=== Test: unreachable parent stays a failure ==="

    local output status
    output="$(_brolit_dropbox_list "DOWN/projects-online/database/anything" 2>/dev/null)"
    status=$?

    if [[ ${status} -eq 0 ]]; then
        echo "FAILED: unreachable scope must not read as empty"
        return 1
    fi

    echo "PASSED: unreachable parent stays a failure"

}

################################################################################
# Test: healthy listing passes through untouched
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_dropbox_list_healthy_passthrough() {

    echo "=== Test: healthy listing passes through untouched ==="

    local output status
    output="$(_brolit_dropbox_list "HOST/projects-online/database/presentproj" 2>/dev/null)"
    status=$?

    if [[ ${status} -ne 0 ]]; then
        echo "FAILED: healthy listing must succeed"
        return 1
    fi
    if ! grep -q 'presentproj_db_2026-10-12.tar.bz2' <<<"${output}"; then
        echo "FAILED: healthy listing output altered"
        return 1
    fi

    echo "PASSED: healthy listing passes through untouched"

}

################################################################################
# Test: parentless path cannot probe and stays a failure
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_dropbox_list_parentless_path_stays_failure() {

    echo "=== Test: parentless path stays a failure ==="

    local output status
    output="$(_brolit_dropbox_list "HOST" 2>/dev/null)"
    status=$?

    if [[ ${status} -eq 0 ]]; then
        echo "FAILED: parentless failing path must not read as empty"
        return 1
    fi

    echo "PASSED: parentless path stays a failure"

}

################################################################################
# Test: whole missing database tree reads as empty via ancestor probe
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_dropbox_list_missing_tree_is_empty() {

    echo "=== Test: whole missing database tree reads as empty ==="

    local output status stderr_output
    stderr_output="$(mktemp)"
    output="$(_brolit_dropbox_list "HOST2/projects-online/database/projx" 2>"${stderr_output}")"
    status=$?

    if [[ ${status} -ne 0 ]]; then
        echo "FAILED: expected exit 0, got ${status}"
        rm -f "${stderr_output}"
        return 1
    fi
    if [[ -n "${output}" ]]; then
        echo "FAILED: expected empty output, got: ${output}"
        rm -f "${stderr_output}"
        return 1
    fi
    if [[ -s "${stderr_output}" ]]; then
        echo "FAILED: expected no stderr diagnostic, got:"
        cat "${stderr_output}"
        rm -f "${stderr_output}"
        return 1
    fi

    rm -f "${stderr_output}"
    echo "PASSED: missing database tree reads as empty without error flag"

}

################################################################################
# Test: outage at every ancestor stays a failure (fail closed)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_dropbox_list_deep_outage_stays_failure() {

    echo "=== Test: outage at every ancestor stays a failure ==="

    local output status
    output="$(_brolit_dropbox_list "DOWN2/a/b" 2>/dev/null)"
    status=$?

    if [[ ${status} -eq 0 ]]; then
        echo "FAILED: total outage must not read as empty"
        return 1
    fi

    echo "PASSED: total outage stays a failure"

}

# Run all tests when executed directly (the full suite sources libs first).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo ""
    echo "========================================="
    echo "Dropbox List Missing-Dir Tests"
    echo "========================================="
    echo ""

    dropbox_list_test_setup

    test_dropbox_list_missing_child_is_empty || exit 1
    echo ""
    : > "${DROPBOX_LIST_CALL_LOG}"
    test_dropbox_list_legacy_miss_message_is_empty || exit 1
    echo ""
    test_dropbox_list_unreadable_child_stays_failure || exit 1
    echo ""
    test_dropbox_list_unreachable_parent_stays_failure || exit 1
    echo ""
    test_dropbox_list_healthy_passthrough || exit 1
    echo ""
    test_dropbox_list_parentless_path_stays_failure || exit 1
    echo ""
    test_dropbox_list_missing_tree_is_empty || exit 1
    echo ""
    test_dropbox_list_deep_outage_stays_failure || exit 1
    echo ""

    dropbox_list_test_teardown

    echo "========================================="
    echo "All tests completed"
fi
