#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
################################################################################

function test_task_runner() {

    local pass_count=0
    local fail_count=0
    local total_count=0

    log_subsection "Test: CLI Parameter Handling"

    # Helper: assert exit code
    _assert_exit_code() {
        local test_name="${1}"
        local expected="${2}"
        local actual="${3}"
        total_count=$((total_count + 1))
        if [[ "${actual}" -eq "${expected}" ]]; then
            display --indent 6 --text "- ${test_name}" --result "PASS" --color GREEN
            pass_count=$((pass_count + 1))
        else
            display --indent 6 --text "- ${test_name} (expected: ${expected}, got: ${actual})" --result "FAIL" --color RED
            fail_count=$((fail_count + 1))
        fi
    }

    # Helper: assert string contains
    _assert_output_contains() {
        local test_name="${1}"
        local needle="${2}"
        local haystack="${3}"
        total_count=$((total_count + 1))
        if [[ "${haystack}" == *"${needle}"* ]]; then
            display --indent 6 --text "- ${test_name}" --result "PASS" --color GREEN
            pass_count=$((pass_count + 1))
        else
            display --indent 6 --text "- ${test_name} (output missing: '${needle}')" --result "FAIL" --color RED
            fail_count=$((fail_count + 1))
        fi
    }

    # Helper: assert string does NOT contain
    _assert_output_not_contains() {
        local test_name="${1}"
        local needle="${2}"
        local haystack="${3}"
        total_count=$((total_count + 1))
        if [[ "${haystack}" != *"${needle}"* ]]; then
            display --indent 6 --text "- ${test_name}" --result "PASS" --color GREEN
            pass_count=$((pass_count + 1))
        else
            display --indent 6 --text "- ${test_name} (should not contain: '${needle}')" --result "FAIL" --color RED
            fail_count=$((fail_count + 1))
        fi
    }

    local runner="${BROLIT_MAIN_DIR}/runner.sh"
    local output
    local exit_code

    #------------------------------------------------------------------------
    # Test: --help exits 0 and contains expected content
    #------------------------------------------------------------------------
    output="$("${runner}" --help 2>&1)" ; exit_code=$?
    _assert_exit_code "--help exits with 0" "0" "${exit_code}"
    _assert_output_contains "--help lists backup task" "backup" "${output}"
    _assert_output_contains "--help lists database task" "database" "${output}"
    _assert_output_contains "--help lists cloudflare-api task" "cloudflare-api" "${output}"
    _assert_output_contains "--help lists disk-cleanup task" "disk-cleanup" "${output}"
    _assert_output_contains "--help shows -D for domain" "-D" "${output}"
    _assert_output_not_contains "--help does not list -q/--quiet (unimplemented)" "-q, --quiet" "${output}"
    _assert_output_not_contains "--help does not list -v/--verbose (unimplemented)" "-v, --verbose" "${output}"

    #------------------------------------------------------------------------
    # Test: --version exits 0
    #------------------------------------------------------------------------
    output="$("${runner}" --version 2>&1)" ; exit_code=$?
    _assert_exit_code "--version exits with 0" "0" "${exit_code}"
    _assert_output_contains "--version contains version string" "BROLIT Shell" "${output}"

    #------------------------------------------------------------------------
    # Test: invalid flag exits 1
    #------------------------------------------------------------------------
    output="$("${runner}" --nonexistent-flag 2>&1)" ; exit_code=$?
    _assert_exit_code "invalid flag exits with 1" "1" "${exit_code}"
    _assert_output_contains "invalid flag shows error message" "Invalid option" "${output}"

    #------------------------------------------------------------------------
    # Test: invalid task is rejected
    #------------------------------------------------------------------------
    output="$("${runner}" -t nonexistent-task 2>&1)" ; exit_code=$?
    _assert_exit_code "invalid task exits non-zero" "1" "${exit_code}"
    _assert_output_contains "invalid task shows error" "Invalid task" "${output}"

    #------------------------------------------------------------------------
    # Test: task requiring subtask fails without subtask
    #------------------------------------------------------------------------
    output="$("${runner}" -t cloudflare-api 2>&1)" ; exit_code=$?
    _assert_exit_code "cloudflare-api without subtask exits non-zero" "1" "${exit_code}"
    _assert_output_contains "cloudflare-api without subtask shows error" "Subtask is required" "${output}"

    #------------------------------------------------------------------------
    # Test: invalid subtask is rejected
    #------------------------------------------------------------------------
    output="$("${runner}" -t cloudflare-api -st invalid_subtask 2>&1)" ; exit_code=$?
    _assert_exit_code "cloudflare-api with invalid subtask exits non-zero" "1" "${exit_code}"
    _assert_output_contains "invalid subtask shows error" "Invalid subtask" "${output}"

    #------------------------------------------------------------------------
    # Test: task requiring DOMAIN fails without it
    #------------------------------------------------------------------------
    output="$("${runner}" -t cloudflare-api -st clear_cache 2>&1)" ; exit_code=$?
    _assert_exit_code "cloudflare-api clear_cache without DOMAIN exits non-zero" "1" "${exit_code}"
    _assert_output_contains "missing DOMAIN shows error" "Missing required" "${output}"

    #------------------------------------------------------------------------
    # Test: backup databases requires DBNAME
    #------------------------------------------------------------------------
    output="$("${runner}" -t backup -st databases 2>&1)" ; exit_code=$?
    _assert_exit_code "backup databases without DBNAME exits non-zero" "1" "${exit_code}"
    _assert_output_contains "missing DBNAME shows error" "DBNAME" "${output}"

    #------------------------------------------------------------------------
    # Test: project install subtask is rejected (removed)
    #------------------------------------------------------------------------
    output="$("${runner}" -t project -st install 2>&1)" ; exit_code=$?
    _assert_exit_code "project install subtask exits non-zero" "1" "${exit_code}"
    _assert_output_contains "project install shows subtask error" "Invalid subtask" "${output}"

    #------------------------------------------------------------------------
    # Test: database subtask name consistency
    #------------------------------------------------------------------------
    output="$("${runner}" -t database -st user_create 2>&1)" ; exit_code=$?
    _assert_exit_code "database user_create (old name) exits non-zero" "1" "${exit_code}"

    output="$("${runner}" -t database -st create_db_user 2>&1)" ; exit_code=$?
    _assert_output_contains "database create_db_user asks for DBUSER" "DBUSER" "${output}"

    #------------------------------------------------------------------------
    # Test: word-splitting with spaces in domain value
    #------------------------------------------------------------------------
    output="$("${runner}" -t cloudflare-api -st clear_cache -D "test domain.com" 2>&1)" ; exit_code=$?
    # Should fail because the domain won't resolve, but should NOT crash
    _assert_exit_code "domain with spaces does not crash parser" "1" "${exit_code}"

    #------------------------------------------------------------------------
    # Summary
    #------------------------------------------------------------------------
    display --indent 2 --text " " --tcolor WHITE
    display --indent 2 --text "Results: ${pass_count}/${total_count} passed, ${fail_count} failed" --tcolor WHITE

    if [[ ${fail_count} -gt 0 ]]; then
        return 1
    fi

    return 0

}
