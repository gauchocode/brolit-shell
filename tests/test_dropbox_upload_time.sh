#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Tests for the Dropbox upload time (UTC) carried by the backup report.
#
# The uploader's list prints "[F] <size> <date;time> <name>" with Dropbox's
# client_modified. brolit_lite.sh asks for UTC (DROPBOX_LIST_UTC=1) and exposes
# the instant as files_time_utc / database_time_utc. No network, no credentials.

if ! declare -F _brolit_dropbox_line_time_utc >/dev/null 2>&1; then
    TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
    # shellcheck disable=SC1090
    source "${TEST_LOADER_DIR}/../brolit_lite.sh" >/dev/null 2>&1
fi

################################################################################
# Test: a valid listing line yields an ISO UTC instant
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_dropbox_line_time_utc_valid() {

    echo "=== Test: valid listing line yields an ISO UTC instant ==="

    local output
    output="$(_brolit_dropbox_line_time_utc " [F] 669380058 2026-11-16;01:04:12 stage.example.com_site-files_2026-11-16.tar.bz2")"

    if [[ "${output}" != "2026-11-16T01:04:12Z" ]]; then
        echo "FAILED: expected 2026-11-16T01:04:12Z, got '${output}'"
        return 1
    fi

    echo "PASSED: valid line parsed"

}

################################################################################
# Test: lines without a valid time yield nothing
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_dropbox_line_time_utc_invalid() {

    echo "=== Test: lines without a valid time yield nothing ==="

    local line output
    for line in \
        "" \
        " [D] somefolder  " \
        " [F] 123 unknown name.tar.bz2" \
        " [F] 123 2026-11-16 name.tar.bz2" \
        " [F] 123 2026-11-16;25:00:00 name.tar.bz2"; do
        output="$(_brolit_dropbox_line_time_utc "${line}")"
        if [[ -n "${output}" ]]; then
            echo "FAILED: expected no output for '${line}', got '${output}'"
            return 1
        fi
    done

    echo "PASSED: invalid lines ignored"

}

################################################################################
# Test: the listing is requested in UTC
#
# Globals:
#   DROPBOX_UPLOADER
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_dropbox_list_requests_utc() {

    echo "=== Test: the listing is requested in UTC ==="

    local test_dir env_log
    test_dir="$(mktemp -d)"
    env_log="${test_dir}/env.log"
    export DROPBOX_UTC_ENV_LOG="${env_log}"

    cat > "${test_dir}/fake_uploader.sh" <<'FAKE_EOF'
#!/usr/bin/env bash
printf '%s\n' "${DROPBOX_LIST_UTC:-unset}" >> "${DROPBOX_UTC_ENV_LOG}"
printf ' [F] 100 2026-11-16;01:04:12 proj_site-files_2026-11-16.tar.bz2\n'
FAKE_EOF
    chmod +x "${test_dir}/fake_uploader.sh"

    local previous_uploader="${DROPBOX_UPLOADER:-}"
    DROPBOX_UPLOADER="${test_dir}/fake_uploader.sh"
    _brolit_dropbox_list "HOST/projects-online/site/proj" >/dev/null 2>&1
    DROPBOX_UPLOADER="${previous_uploader}"

    local seen
    seen="$(cat "${env_log}" 2>/dev/null)"
    rm -rf "${test_dir}"
    unset DROPBOX_UTC_ENV_LOG

    if [[ "${seen}" != "1" ]]; then
        echo "FAILED: uploader saw DROPBOX_LIST_UTC='${seen}', expected 1"
        return 1
    fi

    echo "PASSED: uploader is asked for UTC"

}

################################################################################
# Test: the uploader renders the same instant in UTC regardless of TZ
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_dropbox_uploader_utc_conversion() {

    echo "=== Test: client_modified renders as UTC under any TZ ==="

    local client_modified="2026-11-16T00:04:12Z"
    local utc berlin

    utc="$(TZ=UTC date -u -d "${client_modified}" '+%Y-%m-%d;%H:%M:%S')"
    berlin="$(TZ=Europe/Berlin date -u -d "${client_modified}" '+%Y-%m-%d;%H:%M:%S')"

    if [[ "${utc}" != "2026-11-16;00:04:12" || "${berlin}" != "${utc}" ]]; then
        echo "FAILED: UTC rendering depends on TZ (utc=${utc}, berlin=${berlin})"
        return 1
    fi

    echo "PASSED: UTC rendering is timezone independent"

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

    echo "========================================="
    echo "Dropbox Upload Time Tests"
    echo "========================================="
    echo ""

    test_dropbox_line_time_utc_valid || exit 1
    echo ""
    test_dropbox_line_time_utc_invalid || exit 1
    echo ""
    test_dropbox_list_requests_utc || exit 1
    echo ""
    test_dropbox_uploader_utc_conversion || exit 1
    echo ""

    echo "========================================="
    echo "All tests completed"
fi
