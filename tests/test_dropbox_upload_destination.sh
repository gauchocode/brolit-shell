#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Regression tests for the Dropbox upload destination path.
#
# On wigou (2026-11-14) a project folder was missing on Dropbox (its mkdir
# had failed silently): storage_upload_backup() passed the bare directory
# as the upload destination, so dropbox_uploader stored the whole 4.4GB
# archive as a FILE named like the folder. Every later retention listing
# then failed with path/not_folder. The upload destination must always be
# the explicit "<directory>/<filename>" remote path, which also makes the
# Dropbox API create missing parent folders on upload.
#
# The tests drive the real storage_upload_backup() with stubbed helpers
# and never touch the network, credentials, or real configuration.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/storage_controller.sh" >/dev/null 2>&1

TEST_TMP=""
CALLS_FILE=""

function bud_setup() {

    TEST_TMP="$(mktemp -d)"
    CALLS_FILE="${TEST_TMP}/upload-calls.log"
    : > "${CALLS_FILE}"

    export BACKUP_DROPBOX_STATUS="enabled"
    export BACKUP_LOCAL_STATUS="disabled"
    export MIGRATE_LOCAL_STAGING_PATH=""

    # Quiet logging helpers.
    function log_event() { :; }
    function display() { :; }
    function spinner_start() { :; }
    function spinner_stop() { :; }

    # Plenty of free space so the pre-upload quota check passes.
    function dropbox_account_space_free() { echo "99999999"; }

    # Capture the destination argument of every upload call.
    function dropbox_upload() {
        printf '%s\n' "${2}" >> "${CALLS_FILE}"
        return 0
    }

}

function bud_teardown() {

    rm -rf "${TEST_TMP}"

}

################################################################################
# The upload destination must be the explicit remote file path, never the
# bare directory (the exact wigou failure mode).
################################################################################

function test_upload_destination_is_explicit_file_path() {

    local local_file="${TEST_TMP}/proj_site-files_2026-11-14.tar.bz2"
    local remote_dir="host/projects-online/site/proj"
    echo "data" > "${local_file}"

    storage_upload_backup "${local_file}" "${remote_dir}" "4476.353MiB" >/dev/null 2>&1

    local failed=0

    if [[ "$(wc -l < "${CALLS_FILE}")" -ne 1 ]]; then
        echo "FAILED: expected exactly one upload call, got $(wc -l < "${CALLS_FILE}")"
        failed=1
    fi

    if ! grep -qx -F -- "${remote_dir}/proj_site-files_2026-11-14.tar.bz2" "${CALLS_FILE}"; then
        echo "FAILED: upload destination is not the explicit <dir>/<file> path"
        sed 's/^/       /' "${CALLS_FILE}"
        failed=1
    fi

    # The bare-directory regression: destination equal to the directory
    # itself (or any path not ending in the archive filename).
    if grep -qx -F -- "${remote_dir}" "${CALLS_FILE}"; then
        echo "FAILED: upload destination is the bare directory (wigou bug)"
        failed=1
    fi

    [[ ${failed} -eq 0 ]] && echo "PASSED: upload destination is the explicit remote file path"

    return ${failed}

}

# Suite entry point: runs every case with its own setup/teardown so the
# interactive tests suite (tests_suite.sh) can call this by name.
function test_dropbox_upload_destination() {

    bud_setup

    local failed=0
    test_upload_destination_is_explicit_file_path || failed=1
    echo ""

    bud_teardown

    return ${failed}

}

# Run all tests when executed directly (the full suite sources libs first).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo ""
    echo "========================================="
    echo "Dropbox Upload Destination Tests"
    echo "========================================="
    test_dropbox_upload_destination || exit 1
    echo "========================================="
    echo "All tests completed"
fi
