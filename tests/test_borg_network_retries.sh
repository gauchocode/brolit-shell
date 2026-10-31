#!/usr/bin/env bash
# Author: GauchoCode
# Version: 3.14
# Description: Offline regressions for network-class Borg backup retries.
################################################################################

################################################################################
# Assert backup_borgmatic_config_once retries ONLY network-class failures,
# honours the retry budget, and leaves every other class single-attempt.
# Uses a fake borgmatic and a stubbed init gate; no repositories or network.
#
# Arguments:
#   none
# Outputs:
#   0 if all assertions pass, 1 on error.
################################################################################
function test_borg_network_retries() (
    set -e
    local root tmp config_dir rc
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    tmp="$(mktemp -d "${TMPDIR:-/tmp/opencode}/borg-retries.XXXXXX")"
    trap 'rm --recursive --force -- "${tmp}"' EXIT

    config_dir="${tmp}/etc-borgmatic.d"
    mkdir --parents "${config_dir}" "${tmp}/bin"
    printf 'repositories: []\n' > "${config_dir}/site.example.yml"

    # Fake borgmatic: counts calls, fails with a network error until the
    # attempt named by BORG_FAKE_SUCCEED_AT, or always fails for other classes.
    cat > "${tmp}/bin/borgmatic" <<'EOF'
#!/usr/bin/env bash
n=$(cat "${BORG_FAKE_COUNT}" 2>/dev/null || echo 0)
n=$((n + 1))
echo "${n}" > "${BORG_FAKE_COUNT}"
if [[ "${BORG_FAKE_MODE}" == "create_network" && ${n} -lt ${BORG_FAKE_SUCCEED_AT} ]]; then
    echo "Remote: ssh: connect to host example port 23: Network is unreachable" >&2
    exit 1
fi
if [[ "${BORG_FAKE_MODE}" == "create_config" ]]; then
    echo "Error parsing configuration file" >&2
    exit 1
fi
if [[ "${BORG_FAKE_MODE}" == "create_timeout" && ${n} -lt ${BORG_FAKE_SUCCEED_AT} ]]; then
    exit 124
fi
exit 0
EOF
    chmod +x "${tmp}/bin/borgmatic"
    export PATH="${tmp}/bin:${PATH}"

    source "${root}/libs/local/backup_helper.sh"
    source "${root}/libs/borg_storage_controller.sh"

    function log_event() { :; }
    function display() { :; }

    export BROLIT_BORG_NETWORK_RETRY_DELAY=0
    export BROLIT_BORGMATIC_CONFIG_DIR="${config_dir}"
    export BORG_REPO_UNAVAILABLE=0

    run_case() {
        local mode="$1" succeed_at="$2" case_reason="$3" retries="$4"
        export BORG_FAKE_MODE="${mode}" BORG_FAKE_SUCCEED_AT="${succeed_at}"
        export BORG_FAKE_COUNT="${tmp}/count" BROLIT_BORG_NETWORK_RETRIES="${retries}"
        export BORG_REPO_UNAVAILABLE=0
        : > "${BORG_FAKE_COUNT}"
        INIT_CALLS="${tmp}/init-calls"
        : > "${INIT_CALLS}"

        # shellcheck disable=SC2317
        function borg_initialize_for_backup() {
            local n
            n=$(cat "${INIT_CALLS}" 2>/dev/null || echo 0)
            n=$((n + 1))
            echo "${n}" > "${INIT_CALLS}"
            if [[ -n "${case_reason}" ]]; then
                if [[ "${case_reason}" == "network" && ${n} -ge ${BORG_FAKE_SUCCEED_AT} ]]; then
                    return 0
                fi
                BORG_INIT_FAILURE_REASON="${case_reason}"
                # The real init gate also latches the run-level breaker.
                BORG_REPO_UNAVAILABLE=1
                return 1
            fi
            return 0
        }

        backup_borgmatic_config_once "${config_dir}/site.example.yml" "site.example"
    }

    # 1. Network failure on init, succeeds on the 3rd attempt: OK, 3 init calls.
    rc=0; run_case "none" 3 "network" 2 || rc=$?
    [[ ${rc} -eq 0 ]]
    [[ "$(cat "${tmp}/init-calls")" -eq 3 ]]

    # 2. Non-network init failure: no retry, fails immediately.
    rc=0; run_case "none" 1 "config" 2 || rc=$?
    [[ ${rc} -eq 1 ]]
    [[ "$(cat "${tmp}/init-calls")" -eq 1 ]]

    # 3. retries=0 keeps the previous single-attempt behaviour.
    rc=0; run_case "none" 99 "network" 0 || rc=$?
    [[ ${rc} -eq 1 ]]
    [[ "$(cat "${tmp}/init-calls")" -eq 1 ]]

    # 4. retries=2 with a network failure that never clears: 3 attempts, FAIL.
    rc=0; run_case "none" 99 "network" 2 || rc=$?
    [[ ${rc} -eq 1 ]]
    [[ "$(cat "${tmp}/init-calls")" -eq 3 ]]

    # 5. create fails with network once, succeeds on the retry.
    rc=0; run_case "create_network" 2 "" 2 || rc=$?
    [[ ${rc} -eq 0 ]]
    [[ "$(cat "${tmp}/count")" -eq 2 ]]

    # 6. create fails for a non-network reason: no retry.
    rc=0; run_case "create_config" 1 "" 2 || rc=$?
    [[ ${rc} -eq 1 ]]
    [[ "$(cat "${tmp}/count")" -eq 1 ]]

    # 7. Success after network retries must clear the run-level breaker,
    # otherwise later projects would be SKIPPED while this one reports OK.
    rc=0; run_case "none" 2 "network" 2 || rc=$?
    [[ ${rc} -eq 0 ]]
    [[ ${BORG_REPO_UNAVAILABLE} -eq 0 ]]

    # 8. create killed by GNU timeout (124, no output) counts as network and
    # is retried, instead of being classified as unknown.
    rc=0; run_case "create_timeout" 2 "" 2 || rc=$?
    [[ ${rc} -eq 0 ]]
    [[ "$(cat "${tmp}/count")" -eq 2 ]]

    # 9. A malformed retry value falls back to the default instead of
    # producing an arithmetic error or silently disabling retries.
    rc=0; run_case "none" 3 "network" "foo" || rc=$?
    [[ ${rc} -eq 0 ]]
    [[ "$(cat "${tmp}/init-calls")" -eq 3 ]]
)

test_borg_network_retries
