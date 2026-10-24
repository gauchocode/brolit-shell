#!/usr/bin/env bash
#
# Regression tests for complete-backup email subject classification.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
BROLIT_MAIN_DIR="$(cd "${TEST_LOADER_DIR}/.." &>/dev/null && pwd -P)"
export BROLIT_MAIN_DIR

# shellcheck disable=SC1090
source "${BROLIT_MAIN_DIR}/libs/local/mail_notification_helper.sh"
# shellcheck disable=SC1090
source "${BROLIT_MAIN_DIR}/utils/backup_restore_manager.sh"

TEST_TMP=""
CAPTURED_MAIL_SUBJECT=""
CAPTURED_NOTIFICATION_STATUS=""

function backup_subject_setup() {

    TEST_TMP="$(mktemp -d)"
    export BROLIT_TMP_DIR="${TEST_TMP}"
    export NOW="2026-10-24"
    export NOWDISPLAY="2026-10-24 10:00"
    export SERVER_NAME="test-server"
    export BACKUP_BORG_STATUS="enabled"
    export OUTDATED_PACKAGES=true
    export STATUS_SERVER=1

    CAPTURED_MAIL_SUBJECT=""
    CAPTURED_NOTIFICATION_STATUS=""

    # whiptail returns menu selection on stderr; the production function swaps
    # descriptors to capture it.
    function whiptail() { echo "01)" >&2; }
    function log_section() { :; }
    function log_event() { :; }
    function mail_server_status_section() { :; }
    function mail_backup_section() { :; }
    function mail_footer() { :; }
    function backup_all_databases() { return "${TEST_DATABASE_RC:-0}"; }
    function backup_all_files() {
        STORAGE_DELETE_ERRORS="${TEST_RETENTION_ERRORS:-0}"
        return "${TEST_FILES_RC:-0}"
    }
    function backup_all_files_with_borg() { return "${TEST_BORG_RC:-0}"; }
    function mail_template_assemble() { : > "${1}"; }
    function mail_send_notification() { CAPTURED_MAIL_SUBJECT="${1}"; }
    function send_notification() { CAPTURED_NOTIFICATION_STATUS="${3}"; }
    function menu_main_options() { return 0; }

}

function backup_subject_teardown() {

    rm -rf "${TEST_TMP}"
    unset TEST_DATABASE_RC TEST_FILES_RC TEST_BORG_RC TEST_RETENTION_ERRORS

}

function assert_backup_subject() {

    local expected="${1}"
    shift

    local actual
    actual="$(mail_backup_subject_status "$@")"

    if [[ "${actual}" != "${expected}" ]]; then
        printf 'FAILED: expected %q, got %q for statuses:' "${expected}" "${actual}" >&2
        printf ' %q' "$@" >&2
        printf '\n' >&2
        return 1
    fi

}

function test_backup_subject_status() {

    local failed=0

    # Unrelated server/package/certificate health is intentionally absent from
    # this contract: successful backup dimensions must stay green.
    assert_backup_subject "🟢" 0 0 0 0 || failed=1

    assert_backup_subject "⛔ ERROR" 1 0 0 0 || failed=1
    assert_backup_subject "⛔ ERROR" 0 1 0 0 || failed=1
    assert_backup_subject "⛔ ERROR" 0 0 1 0 || failed=1
    assert_backup_subject "⛔ ERROR" 0 0 0 1 || failed=1

    # Missing or malformed required results must not create a green subject.
    assert_backup_subject "⛔ ERROR" 0 0 || failed=1
    assert_backup_subject "⛔ ERROR" 0 0 0 || failed=1
    assert_backup_subject "⛔ ERROR" 0 unexpected 0 0 || failed=1

    # Exercise the production manual call site. Unrelated server/package
    # warnings cannot change a successful backup subject.
    backup_subject_setup
    backup_manager_menu >/dev/null 2>&1
    [[ "${CAPTURED_MAIL_SUBJECT}" == "🟢 "* ]] || {
        echo "FAILED: successful manual backup was not green: ${CAPTURED_MAIL_SUBJECT}" >&2
        failed=1
    }
    [[ "${CAPTURED_NOTIFICATION_STATUS}" == "success" ]] || {
        echo "FAILED: successful manual backup notification was not successful" >&2
        failed=1
    }
    backup_subject_teardown

    # Borg failure must agree across email subject and push notification.
    backup_subject_setup
    TEST_BORG_RC=1 backup_manager_menu >/dev/null 2>&1
    [[ "${CAPTURED_MAIL_SUBJECT}" == "⛔ ERROR "* ]] || {
        echo "FAILED: manual Borg failure did not produce an error subject" >&2
        failed=1
    }
    [[ "${CAPTURED_NOTIFICATION_STATUS}" == "alert" ]] || {
        echo "FAILED: manual Borg failure did not produce an alert notification" >&2
        failed=1
    }
    backup_subject_teardown

    # Retention failure must also agree across both notification channels.
    backup_subject_setup
    TEST_RETENTION_ERRORS=2 backup_manager_menu >/dev/null 2>&1
    [[ "${CAPTURED_MAIL_SUBJECT}" == "⛔ ERROR "* ]] || {
        echo "FAILED: manual retention failure did not produce an error subject" >&2
        failed=1
    }
    [[ "${CAPTURED_NOTIFICATION_STATUS}" == "alert" ]] || {
        echo "FAILED: manual retention failure did not produce an alert notification" >&2
        failed=1
    }
    backup_subject_teardown

    # Keep the scheduled production wiring under regression coverage without
    # sourcing the mutation-capable cron script.
    grep -Fq 'mail_backup_subject_status "${database_backup_result}" "${files_backup_result}" "${borg_backup_result}" "${retention_backup_result}"' \
        "${BROLIT_MAIN_DIR}/cron/backups_tasks.sh" || {
        echo "FAILED: scheduled backup subject arguments are not wired consistently" >&2
        failed=1
    }
    grep -Fq 'if [[ ${database_backup_result} -ne 0 ]] || [[ ${files_backup_result} -ne 0 ]] || [[ ${borg_backup_result} -ne 0 ]]; then' \
        "${BROLIT_MAIN_DIR}/cron/backups_tasks.sh" || {
        echo "FAILED: scheduled push notification does not classify every nonzero backup result as an alert" >&2
        failed=1
    }
    grep -Fq 'elif [[ ${retention_backup_result} -ne 0 ]]; then' \
        "${BROLIT_MAIN_DIR}/cron/backups_tasks.sh" || {
        echo "FAILED: scheduled push notification does not classify every nonzero retention result as an alert" >&2
        failed=1
    }

    return ${failed}

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_backup_subject_status || exit 1
    echo "Backup subject status tests passed"
fi
