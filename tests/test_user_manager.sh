#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
################################################################################
#
# Tests for the managed user task: username validation and runner wiring.
# Pure functions only — no root, no real system users, no SSH.
#
# Self-contained: tests_suite.sh loads libs/commons.sh and then script_init
# (which defines the real display/log_event/user_manager functions), but this
# file can also be run standalone. Stubs below only apply when the real
# functions are not defined yet and are replaced by the real ones on init.
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

if ! declare -F user_manager_validate_username >/dev/null 2>&1; then
  # shellcheck source=../libs/local/user_manager.sh
  source "${BASH_SOURCE[0]%/*}/../libs/local/user_manager.sh"
fi

function test_user_manager() {

    local pass_count=0
    local fail_count=0
    local total_count=0

    log_subsection "Test: Managed user task"

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

    log_subsection "Test: Username validation"

    # Helper: assert username acceptance/rejection
    _assert_username() {
        local test_name="${1}"
        local username="${2}"
        local expected="${3}"
        user_manager_validate_username "${username}" >/dev/null 2>&1
        _assert_exit_code "${test_name}" "${expected}" "$?"
    }

    _assert_username "accepts simple username" "deploy" 0
    _assert_username "accepts underscore prefix" "_svc" 0
    _assert_username "accepts hyphen and digits" "web-01_2" 0
    _assert_username "accepts 32 chars" "$(printf 'a%.0s' $(seq 1 32))" 0
    _assert_username "rejects empty" "" 1
    _assert_username "rejects leading digit" "1deploy" 1
    _assert_username "rejects leading hyphen" "-deploy" 1
    _assert_username "rejects uppercase" "Deploy" 1
    _assert_username "rejects embedded space" "de ploy" 1
    _assert_username "rejects dot" "deploy.bot" 1
    _assert_username "rejects shell metacharacters" 'deploy;touch /tmp/pwned' 1
    _assert_username "rejects 33 chars" "$(printf 'a%.0s' $(seq 1 33))" 1

    log_subsection "Test: Runner wiring"

    # Every user subtask dispatched by task_runner.sh must resolve to a defined
    # function, otherwise the task fails at runtime with a missing-function error.
    _assert_function_defined() {
        local function_name="${1}"
        total_count=$((total_count + 1))
        if declare -F "${function_name}" >/dev/null 2>&1; then
            display --indent 6 --text "- ${function_name} is defined" --result "PASS" --color GREEN
            pass_count=$((pass_count + 1))
        else
            display --indent 6 --text "- ${function_name} is NOT defined" --result "FAIL" --color RED
            fail_count=$((fail_count + 1))
        fi
    }

    _assert_function_defined "brolit_user_create"
    _assert_function_defined "brolit_user_delete"
    _assert_function_defined "brolit_user_grant_sudo"
    _assert_function_defined "brolit_user_revoke_sudo"
    _assert_function_defined "brolit_user_add_key"
    _assert_function_defined "brolit_user_remove_key"
    _assert_function_defined "brolit_user_list_keys"
    _assert_function_defined "brolit_user_list"

    log_event "info" "User manager tests: ${pass_count}/${total_count} passed, ${fail_count} failed" "false"
    if [[ ${fail_count} -gt 0 ]]; then
        return 1
    fi
    return 0

}
