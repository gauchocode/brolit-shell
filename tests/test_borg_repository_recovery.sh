#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
################################################################################
#
# Tests for the borg repository-unavailable response: failure classification
# and circuit-breaker limit resolution. Pure functions only -- no borgmatic,
# no repositories, no network.
#
# Self-contained: tests_suite.sh loads libs/commons.sh and then script_init
# (which defines the real display/log_event and sources
# libs/borg_storage_controller.sh), but this file can also run standalone.
# Stubs below only apply when the real functions are not defined yet.
#
################################################################################

if ! declare -F log_event >/dev/null 2>&1; then
  function log_event() { echo "log: $2" >&2; }
fi

if ! declare -F log_subsection >/dev/null 2>&1; then
  function log_subsection() { echo; echo "== $* =="; }
fi

if ! declare -F display >/dev/null 2>&1; then
  function display() {
    local text=""
    local result=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --text) text="$2"; shift ;;
        --result) result="$2"; shift ;;
        *) shift ;;
      esac
    done
    echo "- ${text} [${result}]"
  }
fi

if ! declare -F borg_init_failure_reason >/dev/null 2>&1; then
  # shellcheck source=../libs/borg_storage_controller.sh
  source "${BASH_SOURCE[0]%/*}/../libs/borg_storage_controller.sh"
fi

function test_borg_repository_recovery() {

    local pass_count=0
    local fail_count=0
    local total_count=0

    log_subsection "Test: Borg repository failure classification"

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

    _assert_reason() {
        local test_name="${1}"
        local expected="${2}"
        local output="${3}"
        local actual
        actual="$(borg_init_failure_reason "${output}")"
        total_count=$((total_count + 1))
        if [[ "${actual}" == "${expected}" ]]; then
            display --indent 6 --text "- ${test_name}" --result "PASS" --color GREEN
            pass_count=$((pass_count + 1))
        else
            display --indent 6 --text "- ${test_name} (expected: ${expected}, got: ${actual})" --result "FAIL" --color RED
            fail_count=$((fail_count + 1))
        fi
    }

    # Real incident (2026-10): a host whose shared borg destinations became
    # unreachable produced a nightly report where every project and the
    # global run failed with the same generic error. The classifier must name
    # the shared root cause from the raw output.
    _assert_reason "classifies unreachable destination as network" "network" \
        "ssh: connect to host storage.example.com port 22: Connection refused"
    _assert_reason "classifies DNS failure as network" "network" \
        "ssh: Could not resolve hostname storage.example.com: Temporary failure in name resolution"
    _assert_reason "classifies timeout as network" "network" \
        "borgmatic: Remote command timed out after 300 seconds"
    _assert_reason "classifies permission denied as auth" "auth" \
        "root@storage.example.com: Permission denied (publickey)"
    _assert_reason "classifies host key mismatch as auth" "auth" \
        "Host key verification failed"
    _assert_reason "classifies full disk as space" "space" \
        "OSError: [Errno 28] No space left on device"
    _assert_reason "classifies missing repo as repo_missing" "repo_missing" \
        "Repository /mnt/backup/borg does not exist"
    _assert_reason "classifies broken venv as python_env" "python_env" \
        "Traceback (most recent call last): ModuleNotFoundError: No module named 'borgmatic'"
    _assert_reason "classifies borg lock as lock" "lock" \
        "Failed to create/acquire lock /mnt/backup/borg/lock.exclusive (timeout)"
    _assert_reason "falls back to unknown for unrecognized output" "unknown" \
        "some other borgmatic error without a recognizable pattern"

    log_subsection "Test: Circuit breaker limit resolution"

    _assert_limit() {
        local test_name="${1}"
        local expected="${2}"
        local actual
        actual="$(borg_repo_failure_limit)"
        total_count=$((total_count + 1))
        if [[ "${actual}" == "${expected}" ]]; then
            display --indent 6 --text "- ${test_name}" --result "PASS" --color GREEN
            pass_count=$((pass_count + 1))
        else
            display --indent 6 --text "- ${test_name} (expected: ${expected}, got: ${actual})" --result "FAIL" --color RED
            fail_count=$((fail_count + 1))
        fi
    }

    unset BROLIT_BORG_REPO_FAILURE_LIMIT
    _assert_limit "defaults to 3 consecutive failures" "3"

    BROLIT_BORG_REPO_FAILURE_LIMIT=5
    _assert_limit "honors an explicit limit" "5"

    BROLIT_BORG_REPO_FAILURE_LIMIT=0
    _assert_limit "0 disables the breaker" "0"

    BROLIT_BORG_REPO_FAILURE_LIMIT=not-a-number
    _assert_limit "falls back to 3 on invalid input" "3"

    unset BROLIT_BORG_REPO_FAILURE_LIMIT

    log_event "info" "Borg repository recovery tests: ${pass_count}/${total_count} passed, ${fail_count} failed" "false"
    if [[ ${fail_count} -gt 0 ]]; then
        return 1
    fi
    return 0

}
