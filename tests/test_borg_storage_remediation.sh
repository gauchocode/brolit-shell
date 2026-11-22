#!/usr/bin/env bash
# Author: GauchoCode
# Version: 3.14
# Description: Offline regressions for Borg storage auto-remediation helpers.
################################################################################

################################################################################
# Assert the storage remediation helpers are effective and, above all, safe:
# parent directories get created, stale locks are removed only when the
# directory holds nothing else, and IPv6-unreachable arms an IPv4 retry.
# Uses fake sftp/borgmatic binaries; no network or real repositories.
#
# Arguments:
#   none
# Outputs:
#   0 if all assertions pass, 1 on error.
################################################################################
function test_borg_storage_remediation() (
    set -e
    local root tmp config_file rc
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    mkdir --parents "${TMPDIR:-/tmp/opencode}"
    tmp="$(mktemp -d "${TMPDIR:-/tmp/opencode}/borg-remediation.XXXXXX")"
    trap 'rm --recursive --force -- "${tmp}"' EXIT

    mkdir --parents "${tmp}/bin"
    config_file="${tmp}/site.example.yml"
    printf 'repositories: []\n' > "${config_file}"

    # Fake sftp: logs every command and answers ls -l with SFTP_LISTING.
    cat > "${tmp}/bin/sftp" <<'EOF'
#!/usr/bin/env bash
while read -r cmd; do
    [[ -z ${cmd} ]] && continue
    echo "${cmd}" >> "${SFTP_LOG}"
    case "${cmd}" in
        ls\ -l*)
            if [[ "${cmd}" == *lock.exclusive ]]; then
                [[ -n ${SFTP_LISTING_DIR:-} ]] && printf '%s\n' "${SFTP_LISTING_DIR}"
            else
                [[ -n ${SFTP_LISTING:-} ]] && printf '%s\n' "${SFTP_LISTING}"
            fi
            ;;
        rm\ *lock.exclusive)
            exit 1
            ;;
    esac
done
EOF
    chmod +x "${tmp}/bin/sftp"

    # Fake borgmatic: fails preflight as repo_missing, then fails/succeeds init
    # according to BORG_FAKE_MODE, and can also fail with an IPv6 error.
    cat > "${tmp}/bin/borgmatic" <<'EOF'
#!/usr/bin/env bash
action=""
for arg in "$@"; do
    case "${arg}" in
        repo-list|init|create|break-lock) action="${arg}"; break ;;
    esac
done
if [[ "${action}" == "break-lock" ]]; then
    echo "break-lock $*" >> "${BORG_LOG}"
    exit "${BORG_BREAK_RC:-0}"
fi
n=$(cat "${BORG_FAKE_COUNT}" 2>/dev/null || echo 0)
n=$((n + 1))
echo "${n}" > "${BORG_FAKE_COUNT}"
if [[ "${action}" == "repo-list" ]]; then
    if [[ "${BORG_FAKE_MODE}" == "ipv6" ]]; then
        echo "Remote: ssh: connect to host example port 23: Network is unreachable" >&2
        exit 1
    fi
    if [[ "${BORG_FAKE_MODE}" == "lock_preflight" ]]; then
        if [[ ${n} -le 1 ]]; then
            echo "Command 'borg repo-list ssh://u391408@u391408.your-storagebox.de:23/home/applications/g/h/site/x::x' failed" >&2
            echo "Failed to create/acquire the lock /home/applications/g/h/site/x/lock (timeout)." >&2
            exit 1
        fi
        echo "x-2026-01-01"
        exit 0
    fi
    echo "/x is not a valid repository. Check repo config." >&2
    exit 1
fi
if [[ "${action}" == "init" ]]; then
    case "${BORG_FAKE_MODE}" in
        parent_missing)
            if [[ ${n} -le 2 ]]; then
                echo "Command 'borg init --encryption=none ssh://u372319@u372319.your-storagebox.de:23/home/applications/g/h/site/x' failed" >&2
                echo "The parent path of the repo directory [/home/applications/g/h/site/x] does not exist." >&2
                exit 1
            fi
            ;;
        stale_lock)
            if [[ ${n} -le 2 ]]; then
                echo "Command 'borg init --encryption=none ssh://u372319@u372319.your-storagebox.de:23/home/applications/g/h/site/x' failed" >&2
                echo "There is already something at /home/applications/g/h/site/x." >&2
                exit 1
            fi
            ;;
    esac
fi
exit 0
EOF
    chmod +x "${tmp}/bin/borgmatic"

    # Fake pgrep: PGREP_LIVE simulates a real local borg process on the repo.
    cat > "${tmp}/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
[[ -n ${PGREP_LIVE:-} ]] && printf '%s\n' "${PGREP_LIVE}"
exit 0
EOF
    chmod +x "${tmp}/bin/pgrep"

    source "${root}/libs/borg_storage_controller.sh"
    function log_event() { :; }
    function display() { :; }
    export PATH="${tmp}/bin:${PATH}"
    export SFTP_LOG="${tmp}/sftp.log"
    : > "${SFTP_LOG}"

    # Classifier: the two new classes are recognised.
    [[ "$(borg_init_failure_reason 'The parent path of the repo directory [/x] does not exist.')" == "parent_missing" ]]
    [[ "$(borg_init_failure_reason 'There is already something at /x.')" == "stale_lock" ]]
    [[ "$(borg_init_failure_reason 'Network is unreachable')" == "network" ]]
    # A stale config (project directory gone) is named for what it is instead
    # of landing in "unknown" next to real transport failures.
    [[ "$(borg_init_failure_reason 'Source directories or root pattern paths do not exist: /var/www/x')" == "missing_source" ]]
    [[ "$(borg_init_failure_reason 'Connection closed by remote host. Is borg working on the server?')" == "network" ]]
    [[ "$(borg_init_failure_reason 'ssh_exchange_identification: Connection closed by remote host')" == "network" ]]
    # An sshd preauth refusal is an auth failure, not a transient network cut:
    # retrying it three times only delays the correct diagnosis.
    [[ "$(borg_init_failure_reason 'Connection closed by authenticating user root 1.2.3.4 port 40212 [preauth]')" == "auth" ]]

    # Retrying one project records a single consecutive failure. Counting each
    # attempt would trip the run-level breaker (limit 3) inside the first
    # project and skip every later one. Isolated in a subshell so the stubs do
    # not affect the remediation flows below.
    (
        BORG_REPO_INIT_FAILURES=0
        BORG_REPO_UNAVAILABLE=0
        BORG_FIRST_FAILURE_REASON=""
        # shellcheck disable=SC2317
        function initialize_repository() { return 1; }
        # shellcheck disable=SC2317
        function borg_repo_failure_limit() { echo 3; }
        # shellcheck disable=SC2317
        function send_notification() { :; }
        BORG_INIT_FAILURE_REASON="network"
        borg_initialize_for_backup "${config_file}" no || true
        borg_initialize_for_backup "${config_file}" no || true
        [[ "${BORG_REPO_INIT_FAILURES}" -eq 0 ]]
        borg_initialize_for_backup "${config_file}" || true
        [[ "${BORG_REPO_INIT_FAILURES}" -eq 1 ]]
        [[ "${BORG_REPO_UNAVAILABLE}" -eq 0 ]]
    )

    # Parent directories are created level by level, stopping at the parent.
    borg_storage_create_parent_dirs "ssh://u372319@u372319.your-storagebox.de:23/home/applications/g/h/site/x"
    grep -qF 'mkdir /home/applications/g/h/site' "${SFTP_LOG}"
    ! grep -qF 'mkdir /home/applications/g/h/site/x' "${SFTP_LOG}"

    # Stale locks: only lock files present => removed, init retried and OK.
    export BORG_FAKE_MODE=stale_lock BORG_FAKE_COUNT="${tmp}/count"
    : > "${BORG_FAKE_COUNT}"
    export SFTP_LISTING='-rw------- ? u u 75 Oct 31 08:33 /home/applications/g/h/site/x/lock.roster'
    rc=0; _initialize_repository_for_config "${config_file}" "borgmatic" || rc=$?
    [[ ${rc} -eq 0 ]]
    grep -qF 'rm /home/applications/g/h/site/x/lock.roster' "${SFTP_LOG}"

    # Guard: a directory holding a real repository (config) must not be cleaned.
    export SFTP_LISTING='-rw------- ? u u 75 Oct 31 08:33 /home/applications/g/h/site/x/config'
    rc=0; borg_storage_clear_stale_locks "ssh://u372319@u372319.your-storagebox.de:23/home/applications/g/h/site/x" || rc=$?
    [[ ${rc} -eq 1 ]]

    # Parent-missing init: parent created on the storage host, then init OK.
    : > "${SFTP_LOG}"
    export BORG_FAKE_MODE=parent_missing
    : > "${BORG_FAKE_COUNT}"
    rc=0; _initialize_repository_for_config "${config_file}" "borgmatic" || rc=$?
    [[ ${rc} -eq 0 ]]
    grep -qF 'mkdir /home/applications/g/h/site' "${SFTP_LOG}"

    # IPv6-unreachable arms an IPv4 retry for the caller.
    unset BORG_RSH
    export BORG_FAKE_MODE=ipv6
    : > "${BORG_FAKE_COUNT}"
    rc=0; _initialize_repository_for_config "${config_file}" "borgmatic" || rc=$?
    [[ ${rc} -eq 1 ]]
    [[ "${BORG_RSH}" == "ssh -4" ]]

    # Relative Borg URLs (ssh://host/./path) must stay login-relative instead
    # of becoming /./absolute paths.
    : > "${SFTP_LOG}"
    borg_storage_create_parent_dirs "ssh://u372319@u372319.your-storagebox.de:23/./applications/g/h/site/x"
    grep -qF 'mkdir ./applications/g/h/site' "${SFTP_LOG}"
    ! grep -qF 'mkdir /./applications' "${SFTP_LOG}"
    ! grep -qF 'mkdir /applications' "${SFTP_LOG}"

    # Guard: dotfiles are inspected too, so a directory with .keep is not
    # treated as lock-only.
    export SFTP_LISTING='-rw------- ? u u 75 Oct 31 08:33 /home/applications/g/h/site/x/.keep'
    rc=0; borg_storage_clear_stale_locks "ssh://u372319@u372319.your-storagebox.de:23/home/applications/g/h/site/x" || rc=$?
    [[ ${rc} -eq 1 ]]

    # lock.exclusive is a directory: rm fails, so the owner file is removed
    # first and the directory afterwards. No false success.
    : > "${SFTP_LOG}"
    export SFTP_LISTING='drwxr-xr-x ? u u 75 Oct 31 08:33 /home/applications/g/h/site/x/lock.exclusive'
    export SFTP_LISTING_DIR='-rw------- ? u u 75 Oct 31 08:33 /home/applications/g/h/site/x/lock.exclusive/owner'
    rc=0; borg_storage_clear_stale_locks "ssh://u372319@u372319.your-storagebox.de:23/home/applications/g/h/site/x" || rc=$?
    [[ ${rc} -eq 0 ]]
    grep -qF 'rm /home/applications/g/h/site/x/lock.exclusive/owner' "${SFTP_LOG}"
    grep -qF 'rmdir /home/applications/g/h/site/x/lock.exclusive' "${SFTP_LOG}"

    # Lock-class remediation: `borgmatic break-lock` clears every destination
    # of the config, so it never depends on the error text naming the right
    # repository (a multi-destination config logs labels, not always URLs).
    export BORG_LOG="${tmp}/borg.log"
    : > "${BORG_LOG}"
    unset PGREP_LIVE BORG_BREAK_RC
    rc=0; borg_storage_break_config_locks "${config_file}" || rc=$?
    [[ ${rc} -eq 0 ]]
    grep -qF -- "--config ${config_file} break-lock" "${BORG_LOG}"

    # Guard: a live borg process vetoes the break (the lock may be real).
    : > "${BORG_LOG}"
    export PGREP_LIVE="4242 borg create ssh://u391408@u391408.your-storagebox.de:23/home/applications/g/h/site/x"
    rc=0; borg_storage_break_config_locks "${config_file}" || rc=$?
    [[ ${rc} -eq 1 ]]
    [[ ! -s "${BORG_LOG}" ]]
    unset PGREP_LIVE

    # A failed break-lock is reported, never swallowed as success.
    : > "${BORG_LOG}"
    export BORG_BREAK_RC=2
    rc=0; borg_storage_break_config_locks "${config_file}" || rc=$?
    [[ ${rc} -eq 1 ]]
    unset BORG_BREAK_RC

    # Missing config: nothing to do, no command run.
    rc=0; borg_storage_break_config_locks "${tmp}/does-not-exist.yml" || rc=$?
    [[ ${rc} -eq 1 ]]

    # Preflight blocked by a lock: broken once, preflight retried, init path OK.
    : > "${BORG_LOG}"
    : > "${BORG_FAKE_COUNT}"
    export BORG_FAKE_MODE=lock_preflight
    rc=0; _initialize_repository_for_config "${config_file}" "borgmatic" || rc=$?
    [[ ${rc} -eq 0 ]]
    grep -qF 'break-lock' "${BORG_LOG}"

    # Precedence: an authentication failure outranks a missing repository,
    # and malformed/root URLs are rejected instead of being operated on.
    [[ "$(borg_init_failure_reason 'Permission denied (publickey). /x is not a valid repository.')" == "auth" ]]
    rc=0; borg_storage_create_parent_dirs "ssh://u372319@u372319.your-storagebox.de:23/" || rc=$?
    [[ ${rc} -eq 1 ]]
    rc=0; borg_storage_clear_stale_locks "ssh://u372319@u372319.your-storagebox.de:23/" || rc=$?
    [[ ${rc} -eq 1 ]]
)

test_borg_storage_remediation
