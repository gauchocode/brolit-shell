#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Regression tests for the per-project backup path (backup_project /
# backup_docker_project), fixed on 2026-10-20 after a live failure on
# gaucho-docker-host01:
#   1. The final temp cleanup aborted the whole run on an empty parameter
#      ("backup_type: parameter null or not set") AFTER the files and
#      database backups had already been uploaded.
#   2. Docker projects silently skipped the database: the generic path only
#      looks for a local MySQL/Postgres, so a containerized DB was never
#      dumped.
#   3. Database-only mode must not duplicate the file upload, and stopped
#      or ambiguous database containers must not be reported as backed up.
#
# The docker path is exercised against the REAL backup_docker_project with
# a PATH-faked docker binary and a real compose file. No network, no real
# containers.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/backup_helper.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/apps/docker_helper.sh" >/dev/null 2>&1

TEST_TMP=""
EVENTS_FILE=""
CALLS_FILE=""
FAKE_DOCKER_LOG=""

function bkp_setup() {

    TEST_TMP="$(mktemp -d)"
    EVENTS_FILE="${TEST_TMP}/events.log"
    CALLS_FILE="${TEST_TMP}/calls.log"
    FAKE_DOCKER_LOG="${TEST_TMP}/docker.log"
    : > "${EVENTS_FILE}"
    : > "${CALLS_FILE}"
    : > "${FAKE_DOCKER_LOG}"
    export FAKE_DOCKER_LOG

    export PROJECTS_PATH="${TEST_TMP}/www"
    export BROLIT_TMP_DIR="${TEST_TMP}/tmp"
    export NOW="2026-10-20"
    mkdir -p "${PROJECTS_PATH}/site.example.com" "${BROLIT_TMP_DIR}/${NOW}"
    mkdir -p "${PROJECTS_PATH}/nocompose.example.com"
    cat > "${PROJECTS_PATH}/site.example.com/docker-compose.yml" <<'COMPOSE_EOF'
services:
  db:
    image: mysql:8
    volumes:
      - dbdata:/var/lib/mysql
volumes:
  dbdata:
COMPOSE_EOF

    # Fake docker: compose config (for database detection), compose ps
    # (container name), exec printenv (in-container database name) and
    # inspect (running state).
    mkdir -p "${TEST_TMP}/bin"
    cat > "${TEST_TMP}/bin/docker" <<'FAKE_EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FAKE_DOCKER_LOG}"
case "$*" in
    *"config --format json"*)
        [[ "${FAKE_CONFIG_FAIL:-false}" == "false" ]] || exit 1
        printf '{"services":{"db":{"image":"mysql:8","volumes":[{"target":"/var/lib/mysql"}]}}}\n'
        ;;
    *" ps "*)
        [[ "${FAKE_PS_FAIL:-false}" == "false" ]] || exit 1
        [[ "${FAKE_PS_EMPTY:-false}" == "false" ]] || exit 0
        if [[ "${FAKE_REPLICAS:-false}" == "true" ]]; then
            printf 'proj_db_stopped\nproj_db_running\n'
            exit 0
        fi
        if [[ "${FAKE_CONTAINER_RUNNING:-true}" == "true" || "$*" == *"--all"* ]]; then
            printf 'proj_db_1\n'
        fi
        ;;
    *"printenv MYSQL_DATABASE"*)
        [[ "${FAKE_NAME_FAIL:-false}" == "false" ]] || exit 1
        printf 'site_prod\n'
        ;;
    *"inspect"*)
        [[ "${FAKE_INSPECT_FAIL:-false}" == "false" ]] || exit 1
        if [[ "${FAKE_CONTAINER_RUNNING:-true}" == "true" ]]; then
            printf 'true\n'
        else
            printf 'false\n'
        fi
        ;;
esac
exit 0
FAKE_EOF
    chmod +x "${TEST_TMP}/bin/docker"
    export PATH="${TEST_TMP}/bin:${PATH}"

    function log_subsection() { echo "subsection $*" >> "${EVENTS_FILE}"; }
    function log_break() { :; }
    function log_event() { echo "event $1: $2" >> "${EVENTS_FILE}"; }
    function display() { echo "display $*" >> "${EVENTS_FILE}"; }
    function clear_previous_lines() { :; }

    function backup_project_files() {
        echo "files" >> "${CALLS_FILE}"
        [[ -n "${BKP_FILES_FAIL:-}" ]] && return 1
        echo "1.5MiB"
        return 0
    }
    function project_get_type() { echo "${BKP_PROJECT_TYPE:-wordpress}"; }
    function project_get_install_type() { echo "${BKP_INSTALL_TYPE:-docker-compose}"; }
    function project_get_configured_database() { echo "site_prod"; }
    function project_get_configured_database_engine() { echo "mysql"; }
    function project_get_stage_from_domain() { echo "prod"; }
    function project_get_name_from_domain() { echo "site"; }
    function mysql_database_exists() { return 0; }
    function postgres_database_exists() { return 1; }
    function backup_project_database() {
        echo "database" >> "${CALLS_FILE}"
        [[ -n "${BKP_DB_FAIL:-}" ]] && return 1
        echo "/tmp/x.sql;1MiB"
        return 0
    }
    # Keep the real implementation so the cases that need it can restore it.
    BKPK_REAL_DOCKER_FN="$(declare -f backup_docker_project)"
    function backup_docker_project() { echo "docker:$2:$3" >> "${CALLS_FILE}"; return 0; }
    # Database detection needs jq (not present in the test image); the
    # detection itself is not what this slice changes, so it is stubbed
    # while the rest of backup_docker_project runs for real.
    BKPK_REAL_DETECT_FN="$(declare -f docker_list_project_databases)"
    function docker_list_project_databases() {
        local compose_file="${1}"
        [[ "${FAKE_DISCOVERY_FAIL:-false}" == "false" ]] || return 1
        [[ -f "${compose_file}" ]] || return 1
        printf 'db\tmysql\n'
    }

}

function bkp_teardown() {

    rm -rf "${TEST_TMP}"

}

function call_count() {

    grep -c "^${1}$" "${CALLS_FILE}" 2>/dev/null || true

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
    if [[ "$(call_count files)" -lt 1 ]]; then
        echo "FAILED: expected the files backup to run"
        return 1
    fi

    echo "PASSED: empty parameter no longer aborts the backup"

}

function test_docker_project_backs_up_database() {

    echo "=== Test: docker project gets its containerized database backed up ==="

    : > "${CALLS_FILE}"
    BKP_INSTALL_TYPE="docker-compose" backup_project "site.example.com" "" >/dev/null 2>&1

    if ! grep -qE "^docker:docker_backup:database_only$" "${CALLS_FILE}"; then
        echo "FAILED: expected the docker database backup in database_only mode"
        return 1
    fi

    echo "PASSED: docker project database backup invoked"

}

function test_default_install_uses_local_database() {

    echo "=== Test: non-docker project keeps the local database path ==="

    : > "${CALLS_FILE}"
    BKP_INSTALL_TYPE="default" backup_project "site.example.com" "wordpress" >/dev/null 2>&1

    if [[ "$(call_count database)" -lt 1 ]]; then
        echo "FAILED: expected the local database backup to be invoked"
        return 1
    fi
    if grep -q "^docker:" "${CALLS_FILE}"; then
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

function test_docker_database_only_does_not_duplicate_files() {

    echo "=== Test: database_only mode does not upload the site files again ==="

    : > "${CALLS_FILE}"
    # Real backup_docker_project (not the stub) for this case.
    eval "${BKPK_REAL_DOCKER_FN}"
    backup_docker_project "site.example.com" "docker_backup" "database_only" >/dev/null 2>&1
    local rc=$?

    if [[ ${rc} -ne 0 ]]; then
        echo "FAILED: database_only run must succeed (rc ${rc})"
        return 1
    fi
    if [[ "$(call_count files)" -ne 0 ]]; then
        echo "FAILED: database_only mode must not run the files backup"
        return 1
    fi
    if [[ "$(call_count database)" -lt 1 ]]; then
        echo "FAILED: database_only mode must dump the database"
        return 1
    fi

    echo "PASSED: database_only mode skips the files backup"

}

function test_docker_stopped_container_fails() {

    echo "=== Test: a stopped database fails the project backup ==="

    : > "${CALLS_FILE}"
    : > "${FAKE_DOCKER_LOG}"
    eval "${BKPK_REAL_DOCKER_FN}"
    FAKE_CONTAINER_RUNNING="false" backup_docker_project "site.example.com" "docker_backup" "database_only" >/dev/null 2>&1
    local rc=$?

    if [[ ${rc} -eq 0 ]]; then
        echo "FAILED: a stopped database must fail the backup"
        return 1
    fi
    if [[ "$(call_count database)" -ne 0 ]]; then
        echo "FAILED: no dump must be attempted against a stopped container"
        return 1
    fi
    if ! grep -q "stopped or its state is unavailable" "${EVENTS_FILE}"; then
        echo "FAILED: expected the failure to be logged"
        return 1
    fi
    if ! grep -q 'inspect.*proj_db_1' "${FAKE_DOCKER_LOG}"; then
        echo "FAILED: stopped Compose container was not discovered and inspected"
        return 1
    fi

    if FAKE_CONTAINER_RUNNING="false" backup_project "site.example.com" "" >/dev/null 2>&1; then
        echo "FAILED: stopped database must propagate to backup_project"
        return 1
    fi
    echo "PASSED: stopped database fails and propagates"

}

function test_docker_container_resolution_fails_closed() {
    local scenario rc
    eval "${BKPK_REAL_DOCKER_FN}"
    for scenario in FAKE_REPLICAS FAKE_PS_FAIL FAKE_PS_EMPTY FAKE_INSPECT_FAIL FAKE_NAME_FAIL FAKE_DISCOVERY_FAIL; do
        : > "${CALLS_FILE}"
        : > "${FAKE_DOCKER_LOG}"
        export "${scenario}=true"
        backup_docker_project "site.example.com" "docker_backup" "database_only" >/dev/null 2>&1
        rc=$?
        unset "${scenario}"
        if [[ ${rc} -eq 0 || "$(call_count database)" -ne 0 ]]; then
            echo "FAILED: ${scenario} must fail without dumping"
            return 1
        fi
        if [[ ${scenario} == FAKE_REPLICAS ]] && grep -q 'inspect\|printenv' "${FAKE_DOCKER_LOG}"; then
            echo "FAILED: ambiguous replicas must not be arbitrarily selected"
            return 1
        fi
    done
    echo "PASSED: replicas, missing containers and inspection errors fail closed"
}

function test_compose_config_failure_propagates() {
    local stub
    stub="$(declare -f docker_list_project_databases)"
    eval "${BKPK_REAL_DETECT_FN}"
    if FAKE_CONFIG_FAIL=true docker_list_project_databases "${PROJECTS_PATH}/site.example.com/docker-compose.yml" >/dev/null 2>&1; then
        echo "FAILED: compose config failure was hidden by jq"
        eval "${stub}"
        return 1
    fi
    eval "${stub}"
    echo "PASSED: compose config failure propagates through discovery"
}

function test_empty_dotenv_does_not_disclose_environment() {
    local output rc
    eval "${BKPK_REAL_DOCKER_FN}"
    : > "${PROJECTS_PATH}/site.example.com/.env"
    export BKP_SECRET_SENTINEL='private-secret-do-not-print'
    output="$(backup_docker_project "site.example.com" "docker_backup" "database_only" 2>&1)"
    rc=$?
    rm -- "${PROJECTS_PATH}/site.example.com/.env"
    unset BKP_SECRET_SENTINEL
    if [[ ${rc} -ne 0 || "${output}" == *private-secret-do-not-print* ]]; then
        echo "FAILED: empty dotenv caused backup failure or environment disclosure"
        return 1
    fi
    echo "PASSED: empty dotenv does not print environment"
}

function test_docker_database_failure_is_reported() {

    echo "=== Test: a failing docker database backup is reported as FAIL ==="

    : > "${EVENTS_FILE}"
    : > "${CALLS_FILE}"
    eval "${BKPK_REAL_DOCKER_FN}"
    BKP_DB_FAIL="1" backup_docker_project "site.example.com" "docker_backup" "database_only" >/dev/null 2>&1
    local rc=$?

    if [[ ${rc} -eq 0 ]]; then
        echo "FAILED: a failed database dump must fail the project backup"
        return 1
    fi
    if ! grep -q -- "- Project Backup --result FAIL" "${EVENTS_FILE}"; then
        echo "FAILED: expected the FAIL result to be displayed"
        return 1
    fi

    echo "PASSED: failing docker database reported as FAIL"

}


function test_docker_missing_compose_still_backs_up_files() {

    echo "=== Test: a missing compose file fails coverage while saving files ==="

    : > "${CALLS_FILE}"
    : > "${EVENTS_FILE}"
    eval "${BKPK_REAL_DOCKER_FN}"
    backup_docker_project "nocompose.example.com" "docker_backup" "files_and_db" >/dev/null 2>&1
    local rc=$?

    if [[ ${rc} -eq 0 ]]; then
        echo "FAILED: missing compose file must fail the backup"
        return 1
    fi
    if [[ "$(call_count files)" -lt 1 ]]; then
        echo "FAILED: the files backup must still run"
        return 1
    fi
    if [[ "$(call_count database)" -ne 0 ]]; then
        echo "FAILED: no database dump may be attempted without a compose file"
        return 1
    fi
    if ! grep -qi "compose" "${EVENTS_FILE}"; then
        echo "FAILED: expected the skip to be logged"
        return 1
    fi

    echo "PASSED: missing compose file keeps files but fails coverage"

}

function test_docker_failure_marks_project_backup_failed() {

    echo "=== Test: a failing docker database backup shows FAIL ==="

    : > "${EVENTS_FILE}"
    : > "${CALLS_FILE}"
    # Stub the docker path so it reports a failure.
    function backup_docker_project() { return 1; }
    backup_project "site.example.com" "" >/dev/null 2>&1
    local rc=$?

    if [[ ${rc} -eq 0 ]]; then
        echo "FAILED: a failed docker database backup must fail the project"
        return 1
    fi
    if ! grep -q -- "- Project Backup --result FAIL" "${EVENTS_FILE}"; then
        echo "FAILED: expected the FAIL result to be displayed"
        return 1
    fi

    echo "PASSED: failing docker database shows FAIL"

}

function test_successful_project_backup_shows_done() {

    echo "=== Test: a successful project backup shows DONE ==="

    : > "${EVENTS_FILE}"
    : > "${CALLS_FILE}"
    # Restore the healthy stub: a previous case replaces it with a failing
    # one and function definitions persist for the whole shell.
    function backup_docker_project() { echo "docker:$2:$3" >> "${CALLS_FILE}"; return 0; }
    backup_project "site.example.com" "" >/dev/null 2>&1
    local rc=$?

    if [[ ${rc} -ne 0 ]]; then
        echo "FAILED: a successful backup must return 0 (rc ${rc})"
        return 1
    fi
    if ! grep -q -- "- Project Backup --result DONE" "${EVENTS_FILE}"; then
        echo "FAILED: expected the DONE result to be displayed"
        return 1
    fi

    echo "PASSED: successful project backup shows DONE"

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
    test_docker_database_only_does_not_duplicate_files || failed=1
    echo ""
    test_docker_stopped_container_fails || failed=1
    echo ""
    test_docker_container_resolution_fails_closed || failed=1
    echo ""
    test_compose_config_failure_propagates || failed=1
    echo ""
    test_empty_dotenv_does_not_disclose_environment || failed=1
    echo ""
    test_docker_database_failure_is_reported || failed=1
    echo ""
    test_docker_missing_compose_still_backs_up_files || failed=1
    echo ""
    test_docker_failure_marks_project_backup_failed || failed=1
    echo ""
    test_successful_project_backup_shows_done || failed=1
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
