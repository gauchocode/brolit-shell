#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Regression tests for the per-project backup path (backup_project), fixed on
# 2026-10-20 after a live failure on gaucho-docker-host01:
#   1. The final temp cleanup aborted the whole run on an empty parameter
#      ("backup_type: parameter null or not set") AFTER the files and
#      database backups had already been uploaded.
#   2. Docker projects silently skipped the database: the generic path only
#      looks for a local MySQL/Postgres, so a containerized DB was never
#      dumped.
#
# Drives the real function with stubbed helpers. No network, no real files.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/backup_helper.sh" >/dev/null 2>&1

TEST_TMP=""
EVENTS_FILE=""
CALLS_FILE=""

function bkp_setup() {

    TEST_TMP="$(mktemp -d)"
    EVENTS_FILE="${TEST_TMP}/events.log"
    CALLS_FILE="${TEST_TMP}/calls.log"
    : > "${EVENTS_FILE}"
    : > "${CALLS_FILE}"

    export PROJECTS_PATH="${TEST_TMP}/www"
    export BROLIT_TMP_DIR="${TEST_TMP}/tmp"
    export NOW="2026-10-20"
    mkdir -p "${PROJECTS_PATH}/site.example.com" "${BROLIT_TMP_DIR}/${NOW}"

    function log_subsection() { echo "subsection $*" >> "${EVENTS_FILE}"; }
    function log_break() { :; }
    function log_event() { echo "event $1: $2" >> "${EVENTS_FILE}"; }
    function display() { echo "display $*" >> "${EVENTS_FILE}"; }
    function clear_previous_lines() { :; }

    # Files backup stub: success unless BKP_FILES_FAIL is set.
    function backup_project_files() {
        echo "files" >> "${CALLS_FILE}"
        [[ -n "${BKP_FILES_FAIL:-}" ]] && return 1
        echo "1.5MiB"
        return 0
    }
    function project_get_type() { echo "${BKP_PROJECT_TYPE:-wordpress}"; }
    function project_get_install_type() { echo "${BKP_INSTALL_TYPE:-docker}"; }
    function project_get_configured_database() { echo "site_prod"; }
    function project_get_configured_database_engine() { echo "mysql"; }
    function project_get_stage_from_domain() { echo "prod"; }
    function project_get_name_from_domain() { echo "site"; }
    function mysql_database_exists() { return 0; }
    function postgres_database_exists() { return 1; }
    function backup_project_database() { echo "database" >> "${CALLS_FILE}"; echo "/tmp/x.sql;1MiB"; }
    function backup_docker_project() { echo "docker:$2" >> "${CALLS_FILE}"; return 0; }

}

function bkp_teardown() {

    rm -rf "${TEST_TMP}"

}

################################################################################
# Tests
################################################################################

function test_empty_param_does_not_abort() {

    echo "=== Test: empty parameter does not abort the backup ==="

    : > "${CALLS_FILE}"
    local out rc
    out="$(backup_project "site.example.com" "" 2>&1)"
    rc=$?

    if [[ ${rc} -ne 0 ]]; then
        echo "FAILED: backup must not abort (rc ${rc}): ${out}"
        return 1
    fi
    if grep -q "parameter null or not set" <<<"${out}"; then
        echo "FAILED: the temp cleanup still aborts on an empty parameter"
        return 1
    fi
    if ! grep -q "^files$" "${CALLS_FILE}"; then
        echo "FAILED: expected the files backup to run"
        return 1
    fi

    echo "PASSED: empty parameter no longer aborts the backup"

}

function test_docker_project_backs_up_database() {

    echo "=== Test: docker project gets its containerized database backed up ==="

    : > "${CALLS_FILE}"
    BKP_INSTALL_TYPE="docker" backup_project "site.example.com" "" >/dev/null 2>&1

    if ! grep -q "^docker:docker_backup$" "${CALLS_FILE}"; then
        echo "FAILED: expected the docker database backup to be invoked"
        return 1
    fi

    echo "PASSED: docker project database backup invoked"

}

function test_default_install_uses_local_database() {

    echo "=== Test: non-docker project keeps the local database path ==="

    : > "${CALLS_FILE}"
    BKP_INSTALL_TYPE="default" backup_project "site.example.com" "wordpress" >/dev/null 2>&1

    if ! grep -q "^database$" "${CALLS_FILE}"; then
        echo "FAILED: expected the local database backup to be invoked"
        return 1
    fi
    if grep -q "^docker:docker_backup$" "${CALLS_FILE}"; then
        echo "FAILED: non-docker project must not use the docker path"
        return 1
    fi

    echo "PASSED: non-docker project keeps the local database path"

}

function test_files_failure_still_fails() {

    echo "=== Test: a failed files backup still fails the project ==="

    BKP_FILES_FAIL="1" backup_project "site.example.com" "" >/dev/null 2>&1
    local rc=$?

    if [[ ${rc} -eq 0 ]]; then
        echo "FAILED: a failed files backup must fail the project backup"
        return 1
    fi

    echo "PASSED: files failure still fails the project"

}

# Suite entry point: runs every case with its own setup/teardown so the
# interactive tests suite (tests_suite.sh) can call this by name.
function test_backup_project_resilience() {

    bkp_setup

    local failed=0
    test_empty_param_does_not_abort || failed=1
    echo ""
    test_docker_project_backs_up_database || failed=1
    echo ""
    test_default_install_uses_local_database || failed=1
    echo ""
    test_files_failure_still_fails || failed=1
    echo ""

    bkp_teardown

    return ${failed}

}

# Run all tests when executed directly (the full suite sources libs first).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo ""
    echo "========================================="
    echo "Backup Project Resilience Tests"
    echo "========================================="
    test_backup_project_resilience || exit 1
    echo "========================================="
    echo "All tests completed"
fi
