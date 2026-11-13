#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Regression tests for the merged "files" mail section.
#
# On 2026-11-13 (gaucho-docker-host03) a nightly run with three failed
# sites sent an email whose subject said ERROR but whose body showed
# "Files Backup: OK ✅": backup_all_projects_files() and
# backup_additional_dirs() both called mail_backup_section() on the same
# fixed section file, and the second render (always error_msg="none" for
# empty additional dirs) overwrote the first one's error state. The list
# array was also an undeclared global shared by both functions.
#
# The section is now rendered once (backup_files_mail_render) from
# explicit accumulators, with every failed site named in the error.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/backup_helper.sh" >/dev/null 2>&1

TEST_TMP=""
CALLS_FILE=""
HELPERS_BACKUP=""

function bms_setup() {

    TEST_TMP="$(mktemp -d)"
    CALLS_FILE="${TEST_TMP}/mail-calls.log"
    : > "${CALLS_FILE}"

    export PROJECTS_PATH="${TEST_TMP}/www"
    export BROLIT_TMP_DIR="${TEST_TMP}/tmp"
    export BACKUP_CONFIG_ADDITIONAL_DIRS="   "
    export NOW="2026-11-13"
    export COUNT_TOTAL_SITES=0
    mkdir -p "${PROJECTS_PATH}" "${BROLIT_TMP_DIR}/${NOW}"

    # Keep the original helper definitions so the teardown can restore
    # them for test suites that run after this one in the same shell.
    HELPERS_BACKUP="$(declare -f log_subsection log_break log_event display clear_previous_lines mail_backup_section backup_all_server_configs get_all_directories project_is_ignored backup_project_files)"

    # Quiet logging helpers.
    function log_subsection() { :; }
    function log_break() { :; }
    function log_event() { :; }
    function display() { :; }
    function clear_previous_lines() { :; }

    # Mail renderer stub: capture one line per call:
    #   error_msg|error_type|backup_type|entry;entry;...
    function mail_backup_section() {
        local error_msg="${1}"
        local error_type="${2}"
        local backup_type="${3}"
        shift 3
        printf '%s|%s|%s|%s\n' "${error_msg}" "${error_type}" "${backup_type}" "$*" >> "${CALLS_FILE}"
    }

    # Backup flow stubs.
    function backup_all_server_configs() { return 0; }
    function get_all_directories() { printf '%s\n' "${PROJECTS_PATH}/ok.example.com" "${PROJECTS_PATH}/fail.example.com"; }
    function project_is_ignored() { echo "false"; }

}

function bms_teardown() {

    # Restore the real helpers (declaration capture, see setup).
    eval "${HELPERS_BACKUP}"
    unset PROJECTS_PATH BROLIT_TMP_DIR BACKUP_CONFIG_ADDITIONAL_DIRS NOW COUNT_TOTAL_SITES
    unset BACKUP_FILES_MAIL_LIST BACKUP_FILES_MAIL_ERRORS
    rm -rf "${TEST_TMP}"

}

# Fails the backup of every project whose name starts with "fail".
function bms_stub_backup_project_files() {

    function backup_project_files() {
        if [[ "${3}" == fail* ]]; then
            return 1
        fi
        echo "1.0MiB"
        return 0
    }

}

################################################################################
# A failed site must survive the additional-dirs pass and appear in the
# single rendered section (the exact old bug: the second render used to
# overwrite the error with "none").
################################################################################

function test_failed_sites_survive_until_the_single_render() {

    bms_stub_backup_project_files

    backup_all_files >/dev/null 2>&1

    local failed=0
    local calls
    calls="$(wc -l < "${CALLS_FILE}")"

    # Exactly one render of the "files" section.
    if [[ "${calls}" -ne 1 ]]; then
        echo "FAILED: expected 1 mail section render, got ${calls}"
        sed 's/^/       /' "${CALLS_FILE}"
        failed=1
    fi

    # The render must be an ERROR naming the failed site, and still list
    # the successful one.
    if ! grep -q "^Error creating backup file for: fail.example.com|files_backup|files|ok.example.com;1.0MiB$" "${CALLS_FILE}"; then
        echo "FAILED: merged render does not name the failed site or lost the success list"
        sed 's/^/       /' "${CALLS_FILE}"
        failed=1
    fi

    [[ ${failed} -eq 0 ]] && echo "PASSED: failed site reaches the single mail render with the success list"

    return ${failed}

}

################################################################################
# All-success nights render an OK section with every site listed.
################################################################################

function test_all_ok_renders_ok_section() {

    function backup_project_files() { echo "2.0MiB"; return 0; }

    : > "${CALLS_FILE}"
    backup_all_files >/dev/null 2>&1

    local failed=0

    if ! grep -q "^none|none|files|ok.example.com;2.0MiB fail.example.com;2.0MiB$" "${CALLS_FILE}"; then
        echo "FAILED: OK-night render is wrong"
        sed 's/^/       /' "${CALLS_FILE}"
        failed=1
    fi

    [[ ${failed} -eq 0 ]] && echo "PASSED: all-success night renders an OK section with all sites"

    return ${failed}

}

################################################################################
# The renderer resets its accumulators so a second run starts clean.
################################################################################

function test_render_resets_accumulators() {

    bms_stub_backup_project_files

    backup_all_files >/dev/null 2>&1
    : > "${CALLS_FILE}"

    # Second render without new backup data must be a clean OK/empty.
    backup_files_mail_render >/dev/null 2>&1

    local failed=0

    if ! grep -q "^none|none|files|$" "${CALLS_FILE}"; then
        echo "FAILED: accumulators were not reset after the first render"
        sed 's/^/       /' "${CALLS_FILE}"
        failed=1
    fi

    [[ ${failed} -eq 0 ]] && echo "PASSED: accumulators reset after each render"

    return ${failed}

}

################################################################################
# A failed additional directory must reach the same single render while
# the sites all succeed (the mirror of the incident: the additional-dirs
# pass used to overwrite the section state).
################################################################################

function test_failed_additional_dir_reaches_the_render() {

    # Fails only the additional dir named "faildir"; sites succeed.
    function backup_project_files() {
        if [[ "${3}" == "faildir" ]]; then
            return 1
        fi
        echo "3.0MiB"
        return 0
    }

    export BACKUP_CONFIG_ADDITIONAL_DIRS="/etc/okdir /var/backups/faildir"

    : > "${CALLS_FILE}"
    backup_all_files >/dev/null 2>&1

    local failed=0

    # Exactly one render: sites OK + dir failed = ERROR naming the dir,
    # with both the sites and the successful dir in the list.
    if [[ "$(wc -l < "${CALLS_FILE}")" -ne 1 ]]; then
        echo "FAILED: expected 1 mail section render, got $(wc -l < "${CALLS_FILE}")"
        sed 's/^/       /' "${CALLS_FILE}"
        failed=1
    fi
    if ! grep -q "^Error creating backup file for: faildir|files_backup|files|ok.example.com;3.0MiB fail.example.com;3.0MiB okdir;3.0MiB$" "${CALLS_FILE}"; then
        echo "FAILED: additional-dirs failure did not reach the merged render"
        sed 's/^/       /' "${CALLS_FILE}"
        failed=1
    fi

    export BACKUP_CONFIG_ADDITIONAL_DIRS="   "

    [[ ${failed} -eq 0 ]] && echo "PASSED: failed additional dir reaches the merged render"

    return ${failed}

}

# Suite entry point: runs every case with its own setup/teardown so the
# interactive tests suite (tests_suite.sh) can call this by name.
function test_backup_mail_sections() {

    bms_setup

    local failed=0
    test_failed_sites_survive_until_the_single_render || failed=1
    echo ""
    test_all_ok_renders_ok_section || failed=1
    echo ""
    test_render_resets_accumulators || failed=1
    echo ""
    test_failed_additional_dir_reaches_the_render || failed=1
    echo ""

    bms_teardown

    return ${failed}

}

# Run all tests when executed directly (the full suite sources libs first).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo ""
    echo "========================================="
    echo "Backup Mail Sections Tests"
    echo "========================================="
    test_backup_mail_sections || exit 1
    echo "========================================="
    echo "All tests completed"
fi
