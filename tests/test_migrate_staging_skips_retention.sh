#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.15
#############################################################################
#
# `migrate --transport local` captures into MIGRATE_LOCAL_STAGING_PATH, but
# storage_delete_backup deletes on the configured storage (Dropbox) by name.
# Retention over the staging listing could therefore delete a real backup that
# shares a name with a leftover staged file. With staging in use, retention
# must not run; without it, it must keep working as before.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1091
source "${TEST_LOADER_DIR}/../libs/commons.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/storage_controller.sh" >/dev/null 2>&1

function test_migrate_staging_skips_retention() {

    local failed=0
    DELETED=()

    function log_event() { :; }
    function display() { :; }
    function clear_previous_lines() { :; }
    function storage_list_dir() { printf '%s\n' "site_2026-11-24.tar.bz2" "site_2026-11-25.tar.bz2" "site_2026-11-26.tar.bz2"; }
    function storage_delete_backup() { DELETED+=("${1}"); return 0; }

    BACKUP_RETENTION_KEEP_DAILY=1
    BACKUP_RETENTION_KEEP_WEEKLY=0
    BACKUP_RETENTION_KEEP_MONTHLY=0

    MIGRATE_LOCAL_STAGING_PATH="/root/.brolit_migrate_staging"
    storage_delete_old_backups "/server/projects-online/site/example.com"
    if [[ ${#DELETED[@]} -eq 0 ]]; then
        echo "PASS: no retention deletes while migrate staging is in use"
    else
        echo "FAIL: deleted while staging was in use: ${DELETED[*]}"; failed=1
    fi

    DELETED=()
    MIGRATE_LOCAL_STAGING_PATH=""
    storage_delete_old_backups "/server/projects-online/site/example.com"
    if [[ ${#DELETED[@]} -eq 2 ]]; then
        echo "PASS: regular retention still deletes the older files (${#DELETED[@]})"
    else
        echo "FAIL: regular retention deleted ${#DELETED[@]} files, expected 2"; failed=1
    fi

    return ${failed}

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "========================================="
    echo "Migrate staging skips retention"
    echo "========================================="
    test_migrate_staging_skips_retention || exit 1
    echo "All tests completed"
fi
