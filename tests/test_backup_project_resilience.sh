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
#   3. The first fix (delegating to backup_docker_project) duplicated the
#      whole site upload and broke project_delete, which stops the stack
#      before the final backup: the dump against a stopped container
#      failed and aborted the deletion.
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
        printf '{"services":{"db":{"image":"mysql:8","volumes":[{"target":"/var/lib/mysql"}]}}}\n'
        ;;
    *"ps --format"*)
        printf 'proj_db_1\n'
        ;;
    *"printenv MYSQL_DATABASE"*)
        printf 'site_prod\n'
        ;;
    *"inspect"*)
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
    function docker_list_project_databases() { printf 'db\tmysql\n'; }

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

function test_docker_stopped_container_is_skipped() {

    echo "=== Test: a stopped container is skipped instead of failing ==="

    : > "${CALLS_FILE}"
    eval "${BKPK_REAL_DOCKER_FN}"
    FAKE_CONTAINER_RUNNING="false" backup_docker_project "site.example.com" "docker_backup" "database_only" >/dev/null 2>&1
    local rc=$?

    if [[ ${rc} -ne 0 ]]; then
        echo "FAILED: a stopped container must not fail the backup (rc ${rc})"
        return 1
    fi
    if [[ "$(call_count database)" -ne 0 ]]; then
        echo "FAILED: no dump must be attempted against a stopped container"
        return 1
    fi
    if ! grep -q "not running" "${EVENTS_FILE}"; then
        echo "FAILED: expected the skip to be logged"
        return 1
    fi

    echo "PASSED: stopped container skipped without failing"

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
    test_docker_stopped_container_is_skipped || failed=1
    echo ""
    test_docker_database_failure_is_reported || failed=1
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
