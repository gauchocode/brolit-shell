#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Regression tests for sanitize_borgmatic_stale_configs().
#
# Deleting a project leaves its borgmatic config behind, and every nightly
# run failed that project with class missing_source forever (gaucho-host01-vm
# carried two orphaned configs for deleted sites, 2026-11-16). The sanitizer
# archives configs whose project directory no longer exists, never deletes
# them, and never touches server-level or placeholder configs.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/log_and_display_helper.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/borg_storage_controller.sh" >/dev/null 2>&1

TEST_TMP=""

function stale_setup() {
    TEST_TMP="$(mktemp -d)"
    function log_event() { :; }
    function display() { :; }

    export BROLIT_BORGMATIC_CONFIG_DIR="${TEST_TMP}/borgmatic.d"
    export PROJECTS_PATH="${TEST_TMP}/www"
    mkdir -p "${BROLIT_BORGMATIC_CONFIG_DIR}" "${PROJECTS_PATH}/live-project"

    # One config per scenario.
    touch "${BROLIT_BORGMATIC_CONFIG_DIR}/live-project.yml"        # project exists -> keep
    touch "${BROLIT_BORGMATIC_CONFIG_DIR}/deleted-project.yml"     # project gone  -> archive
    touch "${BROLIT_BORGMATIC_CONFIG_DIR}/configuration-coverage.yml" # server-level -> keep
    touch "${BROLIT_BORGMATIC_CONFIG_DIR}/html.yml"                # placeholder   -> keep
}

function stale_teardown() {
    [[ -n "${TEST_TMP}" && -d "${TEST_TMP}" ]] && rm -rf "${TEST_TMP}"
}

PASS=0
FAIL=0

function check() {
    local name="$1"
    local condition="$2"
    if [[ "${condition}" == "ok" ]]; then
        PASS=$((PASS + 1))
        echo "PASS: ${name}"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: ${name}"
    fi
}

function test_stale_configs() {

    stale_setup

    sanitize_borgmatic_stale_configs

    local rc=$?
    local archive_dir
    archive_dir="$(ls -d "${BROLIT_BORGMATIC_CONFIG_DIR}"/backup-orphan-* 2>/dev/null | head -1)"

    check "sanitizer returns 0" "$([[ ${rc} -eq 0 ]] && echo ok || echo fail)"
    check "stale config archived" "$([[ -f "${archive_dir}/deleted-project.yml" ]] && echo ok || echo fail)"
    check "stale config removed from config dir" "$([[ ! -f "${BROLIT_BORGMATIC_CONFIG_DIR}/deleted-project.yml" ]] && echo ok || echo fail)"
    check "live project config kept" "$([[ -f "${BROLIT_BORGMATIC_CONFIG_DIR}/live-project.yml" ]] && echo ok || echo fail)"
    check "configuration-coverage kept" "$([[ -f "${BROLIT_BORGMATIC_CONFIG_DIR}/configuration-coverage.yml" ]] && echo ok || echo fail)"
    check "html placeholder kept" "$([[ -f "${BROLIT_BORGMATIC_CONFIG_DIR}/html.yml" ]] && echo ok || echo fail)"
    check "nothing deleted (archive preserved)" "$([[ -d "${archive_dir}" ]] && echo ok || echo fail)"

    stale_teardown

    echo ""
    if [[ ${FAIL} -gt 0 ]]; then
        echo "${FAIL} checks failed"
        return 1
    fi
    echo "All stale-config sanitizer checks passed"
    return 0
}

# Run directly or via the tests suite by name.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_stale_configs || exit 1
fi
