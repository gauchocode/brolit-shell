#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Regression tests for tar exclusion handling in files backups.
#
# On 2026-11-08 and 2026-11-11 (tukiverse-apps01) the nightly backup filled
# the disk and took unrelated stacks down. Root cause: backup_project_files()
# concatenated the excluded_on_tar patterns into a single string with literal
# single quotes around each pattern, and compress() expanded that string
# unquoted. Word splitting does not remove quotes, so tar received patterns
# like --exclude='*recovery-live*' (quotes included), matched nothing, and
# archived everything the config explicitly excluded.
#
# These tests pin:
#   1. Patterns reach compress() as separate arguments, without quotes.
#   2. A real tar run excludes the configured patterns (including patterns
#      with spaces and brackets) and keeps everything else.
#   3. decompress() applies exclude arguments too.
#   4. compress() aborts before archiving when free space is insufficient.
#   5. compress() deletes the partial output when the pipeline fails.
#
# pv and (in specific cases) df / the compressor are faked on PATH: no
# network, no real servers.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1091
source "${TEST_LOADER_DIR}/../libs/commons.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/backup_helper.sh" >/dev/null 2>&1

TEST_TMP=""
EVENTS_FILE=""
CALLS_FILE=""
PATH_BACKUP=""
LOGGING_HELPERS_BACKUP=""

function bte_setup() {

    TEST_TMP="$(mktemp -d)"
    EVENTS_FILE="${TEST_TMP}/events.log"
    CALLS_FILE="${TEST_TMP}/calls.log"
    : > "${EVENTS_FILE}"
    : > "${CALLS_FILE}"

    export PROJECTS_PATH="${TEST_TMP}/www"
    export BROLIT_TMP_DIR="${TEST_TMP}/tmp"
    export NOW="2026-11-11"
    export SERVER_NAME="test-server"
    export TAR="$(command -v tar)"
    export BACKUP_CONFIG_COMPRESSION_TYPE="gzip"
    export BACKUP_CONFIG_COMPRESSION_EXTENSION="tar.gz"
    export BACKUP_CONFIG_COMPRESSION_TEST="false"
    export BACKUP_CONFIG_COMPRESSION_LEVEL=""
    export BACKUP_CONFIG_COMPRESSION_CORES=""
    export BACKUP_CONFIG_FOLLOW_SYMLINKS="true"
    export EXCLUDED_FILES_LIST=""
    mkdir -p "${PROJECTS_PATH}" "${BROLIT_TMP_DIR}/${NOW}"

    # Minimal pv replacement: passthrough for filter mode, cat for file mode.
    mkdir -p "${TEST_TMP}/bin"
    cat > "${TEST_TMP}/bin/pv" <<'FAKE_EOF'
#!/usr/bin/env bash
files=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s) shift 2 ;;
        --width) shift 2 ;;
        --width=*) shift ;;
        -*) shift ;;
        *) files+=("$1"); shift ;;
    esac
done
if [[ ${#files[@]} -gt 0 ]]; then
    cat "${files[@]}"
else
    cat
fi
FAKE_EOF
    chmod +x "${TEST_TMP}/bin/pv"

    PATH_BACKUP="${PATH}"
    export PATH="${TEST_TMP}/bin:${PATH}"

    # Quiet the logging/display helpers after commons.sh was sourced, and
    # keep their original definitions so the teardown can restore them for
    # the test suites that run after this one in the same shell.
    LOGGING_HELPERS_BACKUP="$(declare -f log_subsection log_break log_event display clear_previous_lines)"
    function log_subsection() { echo "subsection $*" >> "${EVENTS_FILE}"; }
    function log_break() { :; }
    function log_event() { echo "event $1: $2" >> "${EVENTS_FILE}"; }
    function display() { echo "display $*" >> "${EVENTS_FILE}"; }
    function clear_previous_lines() { :; }

}

function bte_teardown() {

    export PATH="${PATH_BACKUP}"
    # Restore the real helpers from libs (declaration capture, see setup).
    eval "${LOGGING_HELPERS_BACKUP}"
    rm -rf "${TEST_TMP}"

}

################################################################################
# 1. backup_project_files() must pass every pattern to compress() as its own
#    argument, with no quote characters embedded (the exact old bug).
################################################################################

function test_exclude_patterns_are_passed_as_separate_args() {

    # Run inside a subshell: the stubs below (compress, storage_*) must not
    # leak into the other tests, which exercise the real functions.
    (
        # Stub compress: capture one exclusion argument per line (skip the
        # three fixed arguments), then behave like success.
        function compress() {
            shift 3
            local a
            for a in "$@"; do
                printf '%s\n' "${a}" >> "${CALLS_FILE}"
            done
            echo "1.0MiB"
            return 0
        }
        function compression_backup_methods_enabled() { return 0; }
        function storage_create_dir() { return 0; }
        function storage_upload_backup() { echo "ok"; return 0; }
        function storage_delete_old_backups() { return 0; }

        export EXCLUDED_FILES_LIST=$'*.log\n*.tmp\nmy logs*\ndata[0-9]'

        backup_project_files "site" "${PROJECTS_PATH}" "site.example.com" >/dev/null 2>&1

        local failed=0

        # One line per pattern: exactly 4 arguments.
        if [[ "$(wc -l < "${CALLS_FILE}")" -ne 4 ]]; then
            echo "FAILED: expected 4 exclude arguments, got $(wc -l < "${CALLS_FILE}")"
            sed 's/^/       /' "${CALLS_FILE}"
            failed=1
        fi

        # No argument may contain a quote character (the regression).
        if grep -q "'" "${CALLS_FILE}"; then
            echo "FAILED: exclude arguments contain literal quotes"
            sed 's/^/       /' "${CALLS_FILE}"
            failed=1
        fi

        # Each pattern must arrive as its own --exclude=PATTERN argument.
        local pattern
        for pattern in '*.log' '*.tmp' 'my logs*' 'data[0-9]'; do
            if ! grep -qx -F -- "--exclude=${pattern}" "${CALLS_FILE}"; then
                echo "FAILED: missing standalone argument --exclude=${pattern}"
                failed=1
            fi
        done

        # A pattern containing spaces must be a single argument, not split.
        if grep -qx -F -- '--exclude=my' "${CALLS_FILE}"; then
            echo "FAILED: pattern with spaces was split into separate words"
            failed=1
        fi

        [[ ${failed} -eq 0 ]] && echo "PASSED: exclude patterns reach compress() as separate unquoted arguments"

        # Configs migrated from older versions may hold comma-separated
        # lists on one line, with stray spaces around the entries.
        : > "${CALLS_FILE}"
        export EXCLUDED_FILES_LIST='*.log, *.tmp ,data[0-9]'

        backup_project_files "site" "${PROJECTS_PATH}" "site.example.com" >/dev/null 2>&1

        if [[ "$(wc -l < "${CALLS_FILE}")" -ne 3 ]]; then
            echo "FAILED: expected 3 exclude arguments from a comma-separated list, got $(wc -l < "${CALLS_FILE}")"
            sed 's/^/       /' "${CALLS_FILE}"
            failed=1
        fi
        local legacy_pattern
        for legacy_pattern in '*.log' '*.tmp' 'data[0-9]'; do
            if ! grep -qx -F -- "--exclude=${legacy_pattern}" "${CALLS_FILE}"; then
                echo "FAILED: comma list entry --exclude=${legacy_pattern} did not arrive standalone"
                failed=1
            fi
        done

        [[ ${failed} -eq 0 ]] && echo "PASSED: comma-separated legacy pattern lists are split correctly"

        exit ${failed}
    )

}

################################################################################
# 2. Real tar run: the configured patterns are excluded, everything else is
#    kept. Includes patterns with spaces and glob brackets.
################################################################################

function test_real_tar_archive_excludes_configured_patterns() {

    local site="${PROJECTS_PATH}/site.example.com"
    local out="${BROLIT_TMP_DIR}/${NOW}/site.example.com_site-files_2026-11-11.tar.gz"

    mkdir -p "${site}/wp-content/themes/child" \
        "${site}/pg_data/base" \
        "${site}/recovery-live/pg_data" \
        "${site}/node_modules/.cache" \
        "${site}/data1" \
        "${site}/dataX" \
        "${site}/my logs"
    echo '<?php' > "${site}/index.php"
    echo 'css' > "${site}/wp-content/themes/child/style.css"
    head -c 2048 /dev/urandom > "${site}/pg_data/base/1"
    head -c 2048 /dev/urandom > "${site}/recovery-live/pg_data/keep"
    echo 'log' > "${site}/debug.log"
    echo 'log' > "${site}/wp-content/error.log"
    echo 'cache' > "${site}/node_modules/.cache/tmp"
    echo 'seed' > "${site}/data1/seed"
    echo 'keep' > "${site}/dataX/keep"
    echo 'trash' > "${site}/my logs/trash.txt"
    echo 'notes' > "${site}/keep notes.txt"

    local -a patterns=(
        "--exclude=*.log"
        "--exclude=*pg_data*"
        "--exclude=*recovery-live*"
        "--exclude=*.cache"
        "--exclude=data[0-9]"
        "--exclude=my logs*"
    )

    # Also exercise the argument filter: an empty argument (legacy caller
    # style) and an invalid non---exclude argument must be ignored without
    # affecting the archive.
    local result
    result="$(compress "${PROJECTS_PATH}" "site.example.com" "${out}" "${patterns[@]}" "" "--bogus")"
    local rc=$?

    local failed=0

    if [[ ${rc} -ne 0 ]]; then
        echo "FAILED: compress returned ${rc}"
        return 1
    fi

    if [[ ! -f "${out}" ]]; then
        echo "FAILED: archive was not created at ${out}"
        return 1
    fi

    if ! grep -q "Ignoring invalid exclude argument" "${EVENTS_FILE}"; then
        echo "FAILED: invalid exclude argument was not reported"
        failed=1
    fi

    local listing
    listing="$(tar -tzf "${out}")"

    # Nothing excluded may be in the archive.
    local -a forbidden=(
        'pg_data'
        'recovery-live'
        '\.log$'
        '\.cache'
        '^site\.example\.com/data1/'
        'my logs'
    )
    local f
    for f in "${forbidden[@]}"; do
        if echo "${listing}" | grep -Eq "${f}"; then
            echo "FAILED: archive contains excluded content matching '${f}'"
            echo "${listing}" | grep -E "${f}" | head -5 | sed 's/^/       /'
            failed=1
        fi
    done

    # Everything else must be in the archive.
    local expected=(
        "site.example.com/index.php"
        "site.example.com/wp-content/themes/child/style.css"
        "site.example.com/dataX/keep"
        "site.example.com/keep notes.txt"
    )
    local e
    for e in "${expected[@]}"; do
        if ! echo "${listing}" | grep -qxF -- "${e}"; then
            echo "FAILED: archive is missing ${e}"
            failed=1
        fi
    done

    # The pattern count must be logged so regressions are visible in run logs.
    if ! grep -q "6 exclusion pattern(s)" "${EVENTS_FILE}"; then
        echo "FAILED: effective pattern count not logged"
        failed=1
    fi

    [[ ${failed} -eq 0 ]] && echo "PASSED: real tar archive honors every exclude pattern (incl. spaces and brackets)"

    return ${failed}

}

################################################################################
# 3. decompress() applies the exclude arguments during extraction.
################################################################################

function test_decompress_applies_exclude_patterns() {

    local src="${TEST_TMP}/extract-src"
    local arc="${TEST_TMP}/payload.tar.bz2"
    local dst="${TEST_TMP}/extract-dst"

    mkdir -p "${src}/sub" "${dst}"
    echo 'a' > "${src}/a.log"
    echo 'b' > "${src}/sub/b.log"
    echo 'c' > "${src}/keep.txt"
    tar -cjf "${arc}" -C "${TEST_TMP}" "$(basename "${src}")"

    # compress_type bzip2 routes through --use-compress-program: GNU tar
    # does not auto-detect bzip2 when reading from a pipe.
    decompress "${arc}" "${dst}" "bzip2" "--exclude=*.log" >/dev/null 2>&1
    local rc=$?

    local failed=0

    if [[ ${rc} -ne 0 ]]; then
        echo "FAILED: decompress returned ${rc}"
        failed=1
    fi
    if [[ -f "${dst}/extract-src/a.log" || -f "${dst}/extract-src/sub/b.log" ]]; then
        echo "FAILED: excluded *.log files were extracted"
        failed=1
    fi
    if [[ ! -f "${dst}/extract-src/keep.txt" ]]; then
        echo "FAILED: keep.txt was not extracted"
        failed=1
    fi

    [[ ${failed} -eq 0 ]] && echo "PASSED: decompress() applies exclude arguments"

    return ${failed}

}

################################################################################
# 4. compress() must abort before archiving when free space is insufficient
#    (fake df reporting a nearly-full filesystem).
################################################################################

function test_compress_aborts_without_free_space() {

    cat > "${TEST_TMP}/bin/df" <<'FAKE_EOF'
#!/usr/bin/env bash
# Fake nearly-full filesystem: 1 KiB available, regardless of arguments.
printf 'Filesystem 1024-blocks Used Available Capacity Mounted\n'
printf 'fakefs 100000000 99999872 1024 100% /\n'
FAKE_EOF
    chmod +x "${TEST_TMP}/bin/df"

    local site="${PROJECTS_PATH}/big.example.com"
    local out="${BROLIT_TMP_DIR}/${NOW}/big.example.com_site-files_2026-11-11.tar.gz"

    mkdir -p "${site}"
    # Big enough that estimate * 1.2 exceeds the 1 KiB the fake df reports.
    head -c 40960 /dev/urandom > "${site}/blob.bin"

    compress "${PROJECTS_PATH}" "big.example.com" "${out}" >/dev/null 2>&1
    local rc=$?

    rm -f "${TEST_TMP}/bin/df"

    local failed=0

    if [[ ${rc} -eq 0 ]]; then
        echo "FAILED: compress succeeded although free space was insufficient"
        failed=1
    fi
    if [[ -f "${out}" ]]; then
        echo "FAILED: archive was created although free space was insufficient"
        failed=1
    fi
    if ! grep -q "Not enough free space" "${EVENTS_FILE}"; then
        echo "FAILED: free-space abort was not logged"
        failed=1
    fi

    [[ ${failed} -eq 0 ]] && echo "PASSED: compress() aborts when free space is insufficient"

    return ${failed}

}

################################################################################
# 5. compress() must delete the partial output when the pipeline fails
#    (failing compressor on PATH) instead of leaving a truncated archive.
################################################################################

function test_compress_cleans_partial_output_on_pipeline_failure() {

    cat > "${TEST_TMP}/bin/zzfailingcomp" <<'FAKE_EOF'
#!/usr/bin/env bash
# Emit some output so a partial file exists, then fail like a disk-full
# compressor would.
head -c 4096 /dev/zero
exit 3
FAKE_EOF
    chmod +x "${TEST_TMP}/bin/zzfailingcomp"

    local site="${PROJECTS_PATH}/fail.example.com"
    local out="${BROLIT_TMP_DIR}/${NOW}/fail.example.com_site-files_2026-11-11.tar.gz"

    mkdir -p "${site}"
    echo 'data' > "${site}/index.php"

    local previous_type="${BACKUP_CONFIG_COMPRESSION_TYPE}"
    export BACKUP_CONFIG_COMPRESSION_TYPE="zzfailingcomp"

    compress "${PROJECTS_PATH}" "fail.example.com" "${out}" >/dev/null 2>&1
    local rc=$?

    export BACKUP_CONFIG_COMPRESSION_TYPE="${previous_type}"
    rm -f "${TEST_TMP}/bin/zzfailingcomp"

    local failed=0

    if [[ ${rc} -eq 0 ]]; then
        echo "FAILED: compress reported success although the compressor failed"
        failed=1
    fi
    if [[ -f "${out}" ]]; then
        echo "FAILED: partial archive was left behind after a pipeline failure"
        failed=1
    fi
    if ! grep -q "Something went wrong making backup file" "${EVENTS_FILE}"; then
        echo "FAILED: pipeline failure was not logged"
        failed=1
    fi

    [[ ${failed} -eq 0 ]] && echo "PASSED: partial output is removed when the compress pipeline fails"

    return ${failed}

}

# Suite entry point: runs every case with its own state so the interactive
# tests suite (tests_suite.sh) can call this by name.
function test_backup_tar_excludes() {

    bte_setup

    local failed=0
    test_exclude_patterns_are_passed_as_separate_args || failed=1
    echo ""
    test_real_tar_archive_excludes_configured_patterns || failed=1
    echo ""
    test_decompress_applies_exclude_patterns || failed=1
    echo ""
    test_compress_aborts_without_free_space || failed=1
    echo ""
    test_compress_cleans_partial_output_on_pipeline_failure || failed=1
    echo ""

    bte_teardown

    return ${failed}

}

# Run all tests when executed directly (the full suite sources libs first).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo ""
    echo "========================================="
    echo "Backup TAR Exclude Tests"
    echo "========================================="
    test_backup_tar_excludes || exit 1
    echo "========================================="
    echo "All tests completed"
fi
