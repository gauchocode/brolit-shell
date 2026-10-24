#!/usr/bin/env bash
# Author: GauchoCode
# Version: 3.11
# Description: Offline init preflight, classification and breaker regressions.
################################################################################

################################################################################
# Exercise real controller entry points with isolated provider/tool fixtures.
# Arguments:
#   none
# Outputs:
#   0 if all assertions pass, 1 otherwise.
################################################################################
function test_borg_init_safety() (
    set -e
    local root tmp mode expected status value
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    tmp="$(mktemp -d "${TMPDIR:-/tmp/opencode}/borg-init.XXXXXX")"
    trap 'rm --recursive --force -- "${tmp}"' EXIT
    source "${root}/libs/borg_storage_controller.sh"
    ################################################################################
    # Fixture resolver; no arguments; outputs fake executable path and 0.
    ################################################################################
    function _borgmatic_resolve_cmd() { echo "${tmp}/bin/borgmatic"; }
    ################################################################################
    # Fixture logging; arguments: log parameters; outputs: captured message, 0.
    ################################################################################
    function log_event() { echo "${*}" >> "${tmp}/events"; }
    ################################################################################
    # Fixture display; arguments: display parameters; outputs: captured message, 0.
    ################################################################################
    function display() { echo "${*}" >> "${tmp}/events"; }
    ################################################################################
    # Fixture notification; arguments ignored; outputs: captured marker, 0.
    ################################################################################
    function send_notification() { echo notification >> "${tmp}/events"; }
    mkdir "${tmp}/bin"
    cp "${root}/tests/fixtures/borg_safety_yq.py" "${tmp}/bin/yq"
    chmod +x "${tmp}/bin/yq"
    export PATH="${tmp}/bin:${PATH}" FAKE_CALLS="${tmp}/calls"
    cat > "${tmp}/bin/borgmatic" <<'FAKE'
#!/usr/bin/env bash
action="${1}"
probe_options="${2:-} ${3:-} ${4:-}"
printf '%s\n' "${action}" >> "${FAKE_CALLS}"
while [[ "${1:-}" != --config && $# -gt 0 ]]; do shift; done
config="${2}"
repo="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["repositories"][0]["path"])' "${config}")"
if [[ "${action}" == repo-list ]]; then
    # Reject archive-info and missing/unbounded listing options outright.
    [[ "${probe_options}" == '--short --last 1' ]] || exit 90
    mode="${FAKE_PROBE_MODE:-${repo}}"
elif [[ "${action}" == init ]]; then
    mode="${FAKE_INIT_MODE:-success}"
else
    echo 'Unexpected heavyweight or unsupported action' >&2
    exit 91
fi
case "${mode}" in
    healthy|success) exit 0 ;;
    missing) echo 'Repository /fixture/repo does not exist' ;;
    config) echo 'Cannot find variable MARIADB_DATABASE in environment; already exists; does not match existing repository encryption mode' ;;
    relocation) echo 'Repository at location ssh://fixture was previously located at ssh://old; already exists; does not match existing repository encryption mode' ;;
    network) echo 'Connection refused' ;;
    auth) echo 'Permission denied (publickey)' ;;
    space) echo 'No space left on device' ;;
    lock) echo 'Failed to create/acquire the lock (timeout)' ;;
    python_env) echo 'ModuleNotFoundError: no module named borgmatic' ;;
    encryption_mismatch) echo 'Requested encryption mode does not match existing repository encryption mode' ;;
    exists) echo 'Repository already exists' ;;
    generic_missing_file) echo 'No such file or directory: /fixture/key' ;;
    missing_key) echo 'Repository key file does not exist' ;;
    timeout) exit 124 ;;
    unsupported) echo 'Unrecognized arguments: repo-list --short --last 1' ;;
    *) echo 'Unexpected failure' ;;
esac
echo SECRET_CANARY >&2
exit 2
FAKE
    chmod +x "${tmp}/bin/borgmatic"
    printf '%s\n' '{"repositories":[{"path":"healthy"}]}' > "${tmp}/config.yml"
    : > "${tmp}/events"
    : > "${FAKE_CALLS}"
    initialize_repository "${tmp}/config.yml"
    [[ -z "${BORG_INIT_FAILURE_REASON}" && "$(cat "${FAKE_CALLS}")" == repo-list ]]
    # Every non-missing preflight failure is fail-closed, including generic ENOENT.
    for mode in config relocation network auth space lock python_env encryption_mismatch exists generic_missing_file missing_key timeout unsupported unknown; do
        export FAKE_PROBE_MODE="${mode}"
        : > "${FAKE_CALLS}"
        if initialize_repository "${tmp}/config.yml"; then return 1; fi
        expected="${mode}"
        case "${mode}" in exists|generic_missing_file|missing_key|unsupported) expected=unknown ;; timeout) expected=network ;; esac
        [[ "${BORG_INIT_FAILURE_REASON}" == "${expected}" && "$(cat "${FAKE_CALLS}")" == repo-list ]]
    done
    export FAKE_PROBE_MODE=missing
    for mode in success exists encryption_mismatch config relocation network unknown; do
        export FAKE_INIT_MODE="${mode}"
        : > "${FAKE_CALLS}"
        status=0
        initialize_repository "${tmp}/config.yml" || status=$?
        case "${mode}" in
            success|exists|encryption_mismatch) [[ "${status}" -eq 0 && -z "${BORG_INIT_FAILURE_REASON}" ]] ;;
            *) [[ "${status}" -ne 0 && "${BORG_INIT_FAILURE_REASON}" == "${mode}" ]] ;;
        esac
        [[ "$(cat "${FAKE_CALLS}")" == $'repo-list\ninit' ]]
    done
    ! grep -q SECRET_CANARY "${tmp}/events"
    unset FAKE_PROBE_MODE FAKE_INIT_MODE
    # Real cron gate: an invalid project must not suppress the next healthy
    # project's preflight, and its actual class must survive the wrapper.
    BORG_REPO_INIT_FAILURES=0 BORG_REPO_UNAVAILABLE=0 BORG_FIRST_FAILURE_REASON=""
    BROLIT_BORG_REPO_FAILURE_LIMIT=1
    export FAKE_PROBE_MODE=config
    if borg_initialize_for_backup "${tmp}/config.yml"; then return 1; fi
    [[ "${BORG_INIT_FAILURE_REASON}" == config && "${BORG_REPO_UNAVAILABLE}" -eq 0 ]]
    unset FAKE_PROBE_MODE
    : > "${FAKE_CALLS}"
    borg_initialize_for_backup "${tmp}/config.yml"
    [[ "$(cat "${FAKE_CALLS}")" == repo-list && "${BORG_REPO_INIT_FAILURES}" -eq 0 ]]
    export FAKE_PROBE_MODE=network
    BROLIT_BORG_REPO_FAILURE_LIMIT=3
    if borg_initialize_for_backup "${tmp}/config.yml"; then return 1; fi
    [[ "${BORG_INIT_FAILURE_REASON}" == network && "${BORG_REPO_INIT_FAILURES}" -eq 1 && "${BORG_FIRST_FAILURE_REASON}" == network ]]
    unset FAKE_PROBE_MODE
    borg_initialize_for_backup "${tmp}/config.yml"
    [[ "${BORG_REPO_INIT_FAILURES}" -eq 0 && -z "${BORG_FIRST_FAILURE_REASON}" ]]
    # Actual public multi-repository entry point; a bad destination does not
    # prevent initialization of a positively missing second destination.
    printf '%s\n' '{"repositories":[{"path":"network"},{"path":"missing"}]}' > "${tmp}/config.yml"
    : > "${FAKE_CALLS}"
    initialize_repository "${tmp}/config.yml"
    [[ -z "${BORG_INIT_FAILURE_REASON}" && "$(cat "${FAKE_CALLS}")" == $'repo-list\nrepo-list\ninit' ]]
    [[ -z "$(find "${tmp}" -name '.brolit-init.*' -print)" ]]
    printf '%s\n' '{"repositories":[{"path":"network"},{"path":"config"}]}' > "${tmp}/config.yml"
    if initialize_repository "${tmp}/config.yml"; then return 1; fi
    [[ "${BORG_INIT_FAILURE_REASON}" == unknown ]]
    # Failed per-repository mutations cannot run the original multi-repo file.
    export FAKE_YQ_COUNT="${tmp}/yq-count" FAKE_YQ_FAIL_AT=2
    : > "${FAKE_CALLS}"
    if initialize_repository "${tmp}/config.yml"; then return 1; fi
    [[ "${BORG_INIT_FAILURE_REASON}" == config && ! -s "${FAKE_CALLS}" ]]
    [[ -z "$(find "${tmp}" -name '.brolit-init.*' -print)" ]]
    unset FAKE_YQ_COUNT FAKE_YQ_FAIL_AT
    printf '%s\n' '{"repositories":[]}' > "${tmp}/empty.yml"
    if initialize_repository "${tmp}/empty.yml"; then return 1; fi
    [[ "${BORG_INIT_FAILURE_REASON}" == config ]]
    if initialize_repository "${tmp}/absent.yml"; then return 1; fi
    [[ "${BORG_INIT_FAILURE_REASON}" == config ]]
    # Consecutive shared failures only. Success/local errors reset the count.
    BORG_REPO_INIT_FAILURES=0 BORG_REPO_UNAVAILABLE=0 BORG_FIRST_FAILURE_REASON=""
    BROLIT_BORG_REPO_FAILURE_LIMIT=2
    borg_record_init_result 1 network
    [[ "${BORG_REPO_INIT_FAILURES}" -eq 1 && "${BORG_FIRST_FAILURE_REASON}" == network ]]
    borg_record_init_result 0 ''
    [[ "${BORG_REPO_INIT_FAILURES}" -eq 0 && -z "${BORG_FIRST_FAILURE_REASON}" ]]
    for value in config relocation lock python_env unknown repo_missing encryption_mismatch; do
        borg_record_init_result 1 network
        borg_record_init_result 1 "${value}"
        [[ "${BORG_REPO_INIT_FAILURES}" -eq 0 && "${BORG_REPO_UNAVAILABLE}" -eq 0 ]]
    done
    borg_record_init_result 1 network
    borg_record_init_result 1 network
    [[ "${BORG_REPO_INIT_FAILURES}" -eq 2 && "${BORG_REPO_UNAVAILABLE}" -eq 1 ]]
    [[ "$(grep -c notification "${tmp}/events")" -eq 1 ]]
    ! grep -q SECRET_CANARY "${tmp}/events"
    echo 'PASS: init (preflight, priority, no leakage, multi-repo, mutations, breaker isolation)'
)

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_borg_init_safety
fi
