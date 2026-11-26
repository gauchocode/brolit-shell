#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.15
#############################################################################
#
# brolit-admin shows a live view of `migrate`: besides the backup events it
# needs one event at each stage boundary. brolit_progress must accept the
# transfer, restore and verify phases (without a percentage), keep rejecting
# unknown phases, and migrate must emit one event per boundary.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1091
source "${TEST_LOADER_DIR}/../libs/commons.sh" >/dev/null 2>&1

function test_migrate_progress_phases() {

    local failed=0 out

    export BROLIT_PROGRESS=1
    for phase in transfer restore verify; do
        out="$(brolit_progress "${phase}" "-" "example.com" 2>&1 >/dev/null)"
        if [[ "${out}" == '[[BROLIT_PROGRESS]]{"v":1,"phase":"'"${phase}"'","pct":null,"detail":"example.com"}' ]]; then
            echo "PASS: ${phase} event emitted without a percentage"
        else
            echo "FAIL: ${phase}: got '${out}'"; failed=1
        fi
    done

    out="$(brolit_progress "bogus" "-" "example.com" 2>&1 >/dev/null)"
    if [[ -z "${out}" ]]; then echo "PASS: unknown phase is still ignored"; else echo "FAIL: unknown phase emitted '${out}'"; failed=1; fi

    BROLIT_PROGRESS=0
    out="$(brolit_progress transfer "-" "example.com" 2>&1 >/dev/null)"
    if [[ -z "${out}" ]]; then echo "PASS: nothing is emitted unless BROLIT_PROGRESS=1"; else echo "FAIL: emitted without the flag"; failed=1; fi

    local helper="${TEST_LOADER_DIR}/../libs/local/site_migration_helper.sh" phase subsection
    for pair in "transfer:Migrate: Transfer Artifact" "restore:Migrate: Remote Restore" "verify:Migrate: Verify Destination"; do
        phase="${pair%%:*}"; subsection="${pair#*:}"
        if grep -A2 "log_subsection \"${subsection}\"" "${helper}" | grep -q "brolit_progress \"${phase}\""; then
            echo "PASS: migrate emits ${phase} at '${subsection}'"
        else
            echo "FAIL: migrate does not emit ${phase} at '${subsection}'"; failed=1
        fi
    done

    return ${failed}

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "========================================="
    echo "Migrate progress phases"
    echo "========================================="
    test_migrate_progress_phases || exit 1
    echo "All tests completed"
fi
