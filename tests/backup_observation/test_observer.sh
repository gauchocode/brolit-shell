#!/usr/bin/env bash
# Author: GauchoCode
# Version: 0.1.0
################################################################################
# Isolated, network-free observer checks. This file is intentionally not part
# of tests/tests_suite.sh.
################################################################################

set -u

readonly TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly ROOT_DIR="$(cd -- "${TEST_DIR}/../.." && pwd -P)"
readonly FIXTURE_DIR="${TEST_DIR}/fixtures"
readonly FAKE_BIN_DIR="${TEST_DIR}/fake-provider-bin"
readonly OBSERVER="${ROOT_DIR}/backup_observer.sh"
readonly ADMIN_ROOT="${BROLIT_ADMIN_ROOT:-$(cd -- "${ROOT_DIR}/../brolit-admin" 2>/dev/null && pwd -P || printf '')}"
readonly ADMIN_SCHEMA="${ADMIN_ROOT}/application/contracts/backup-observation/v1.schema.json"
readonly TEMP_DIR="$(mktemp -d /tmp/brolit-observer-test.XXXXXX)"
readonly ATTEMPT_LOG="${TEMP_DIR}/attempts.log"
readonly CANARY="${TEMP_DIR}/secret-canary"

cleanup() {
    rm -rf -- "${TEMP_DIR}"
}
trap cleanup EXIT

fail() {
    printf 'FAIL: %s\n' "${1}" >&2
    exit 1
}

assert_eq() {
    [[ "${1}" == "${2}" ]] || fail "${3}: got '${1}', expected '${2}'"
}

assert_file_empty() {
    [[ ! -s "${1}" ]] || fail "${2}"
}

validate_report() {
    local report_file="${1}"
    command -v jsonschema >/dev/null 2>&1 || fail "jsonschema is required for fixture conformance checks"
    jsonschema -i "${report_file}" "${ADMIN_SCHEMA}" >/dev/null 2>&1 || fail "report does not validate against Admin schema: ${report_file}"
}

assert_monotonic_budget() {
    BO_MAX_RUNTIME_SECONDS=1
    BO_START_MONOTONIC_NS="$(bo_monotonic_ns)"
    bo_within_runtime_budget || fail "fresh monotonic runtime budget was rejected"
    BO_START_MONOTONIC_NS=$((BO_START_MONOTONIC_NS - 2000000000))
    if bo_within_runtime_budget; then
        fail "expired monotonic runtime budget was accepted"
    fi
}

run_observer() {
    local request="${1}"
    local borg_mode="${2:-}"
    printf '%s\n' "${request}" | env \
        PATH="${FAKE_BIN_DIR}:/usr/bin:/bin" \
        BO_EXEC_PATH="${FAKE_BIN_DIR}:/usr/bin:/bin" \
        BO_TOOL_PATH="/usr/bin:/bin" \
        BO_BORG_TEST_TOKEN_KEY="fixture-borg-token-key" \
        BO_ATTEMPT_LOG="${ATTEMPT_LOG}" \
        BROLIT_OBSERVER_TEST_BORG_MODE="${borg_mode}" \
        BROLIT_OBSERVER_TEST_MODE=1 \
        BROLIT_OBSERVER_TEST_CONFIG_FILE="${FIXTURE_DIR}/config-valid.json" \
        BROLIT_OBSERVER_TEST_BORGMATIC_DIR="${FIXTURE_DIR}/borgmatic.d" \
        "${OBSERVER}" --test-mode
}

run_dropbox_observer() {
    local request="${1}"
    local mode="${2:-}"
    local dropbox_config="${TEMP_DIR}/dropbox-config.json"
    local dropbox_credentials="${TEMP_DIR}/dropbox.credentials"
    jq --arg file "${dropbox_credentials}" '.BACKUPS.methods[0].dropbox[0].config[0].file = $file' \
        "${FIXTURE_DIR}/config-dropbox-valid.json" >"${dropbox_config}"
    cp "${FIXTURE_DIR}/credentials-valid" "${dropbox_credentials}"
    chmod 600 "${dropbox_credentials}"
    printf '%s\n' "${request}" | env \
        PATH="${FAKE_BIN_DIR}:/usr/bin:/bin" \
        BO_EXEC_PATH="${FAKE_BIN_DIR}:/usr/bin:/bin" \
        BO_TOOL_PATH="/usr/bin:/bin" \
        BO_BORG_TEST_TOKEN_KEY="fixture-borg-token-key" \
        BO_ATTEMPT_LOG="${ATTEMPT_LOG}" \
        BROLIT_OBSERVER_TEST_MODE=1 \
        BROLIT_OBSERVER_TEST_CONFIG_FILE="${dropbox_config}" \
        BROLIT_OBSERVER_TEST_BORGMATIC_DIR="${FIXTURE_DIR}/borgmatic.d" \
        BROLIT_OBSERVER_TEST_CREDENTIAL_FILE="${dropbox_credentials}" \
        BROLIT_OBSERVER_TEST_DROPBOX_MODE="${mode}" \
        "${OBSERVER}" --test-mode
}

valid_discover='{"schema_version":"1.0","collection_id":"test-discover","operation":"discover","scope":{"kind":"source","source_id":"test-source"},"budgets":{"max_report_bytes":65536,"max_items":100,"max_runtime_seconds":30}}'
valid_inventory='{"schema_version":"1.0","collection_id":"test-inventory","operation":"inventory","scope":{"kind":"location","source_id":"test-source","provider":"borg","location_id":"borg-demo.stellacast.com-r0"},"budgets":{"max_report_bytes":65536,"max_items":100,"max_runtime_seconds":30},"scan":{"scan_id":"test-scan","mode":"full","page_index":0,"continuation":null}}'
paged_inventory='{"schema_version":"1.0","collection_id":"test-inventory-paged","operation":"inventory","scope":{"kind":"location","source_id":"test-source","provider":"borg","location_id":"borg-demo.stellacast.com-r0"},"budgets":{"max_report_bytes":65536,"max_items":1,"max_runtime_seconds":30},"scan":{"scan_id":"test-scan-paged","mode":"full","page_index":0,"continuation":null}}'

valid_capabilities='{"schema_version":"1.0","collection_id":"test-capabilities","operation":"capabilities","scope":{"kind":"source","source_id":"test-source"},"budgets":{"max_report_bytes":65536,"max_items":100,"max_runtime_seconds":30}}'
invalid_version='{"schema_version":"2.0","collection_id":"test-capabilities","operation":"capabilities","scope":{"kind":"source","source_id":"test-source"},"budgets":{"max_report_bytes":65536,"max_items":100,"max_runtime_seconds":30}}'
forged_inventory='{"schema_version":"1.0","collection_id":"test-inventory","operation":"inventory","scope":{"kind":"location","source_id":"test-source","provider":"borg","location_id":"borg-forged"},"budgets":{"max_report_bytes":65536,"max_items":100,"max_runtime_seconds":30},"scan":{"scan_id":"test-scan","mode":"full","page_index":0,"continuation":null}}'
item_limited_capabilities='{"schema_version":"1.0","collection_id":"test-item-limit","operation":"capabilities","scope":{"kind":"source","source_id":"test-source"},"budgets":{"max_report_bytes":65536,"max_items":1,"max_runtime_seconds":30}}'

set +e
PATH=/tmp BROLIT_OBSERVER_TEST_MODE=1 BROLIT_OBSERVER_DISABLE_JQ=1 /bin/bash "${OBSERVER}" --test-mode </dev/null >"${TEMP_DIR}/missing-jq.json" 2>"${TEMP_DIR}/missing-jq.err"
status=$?
set -e
assert_eq "${status}" "30" "missing jq exit"
jq -e '.outcome == "unsupported" and .errors[0].code == "dependency_unavailable"' "${TEMP_DIR}/missing-jq.json" >/dev/null || fail "missing jq fallback was not valid JSON"
if grep -qi 'unbound variable' "${TEMP_DIR}/missing-jq.err"; then
    fail "missing jq fallback referenced an unbound variable"
fi

source "${ROOT_DIR}/libs/backup_observation/protocol.sh"
assert_monotonic_budget

if [[ ${EUID:-1} -ne 0 ]]; then
    # The protocol still has a useful unprivileged check, while provider tests
    # are explicitly skipped rather than run with weakened root semantics.
    set +e
    malformed_output="$(printf '%s\n' "${invalid_version}" | "${OBSERVER}" 2>"${TEMP_DIR}/malformed.err")"
    status=$?
    set -e
    assert_eq "${status}" "40" "unsupported version exit"
    assert_eq "${malformed_output}" "" "malformed request stdout"
    printf 'SKIP: isolated provider checks require root (unprivileged protocol check passed)\n'
    exit 0
fi

# Every shipped Admin report fixture must validate against the pinned schema;
# request fixtures are validated by the Admin contract suite separately.
for report_fixture in /home/lpadula/Documents/brolit-admin/application/contracts/backup-observation/fixtures/*.json; do
    [[ "$(basename -- "${report_fixture}")" == request-* ]] && continue
    jsonschema -i "${report_fixture}" "${ADMIN_SCHEMA}" >/dev/null 2>&1 || fail "Admin report fixture does not validate: ${report_fixture}"
done

set +e
capabilities_output="$(run_observer "${valid_capabilities}" 2>"${TEMP_DIR}/capabilities.err")"
status=$?
set -e
assert_eq "${status}" "0" "capabilities exit"
# Capabilities advertise only tested local transport profiles; credentials and
# roots remain runtime gates. The fake binaries provide Borg 1.2 and curl.
printf '%s' "${capabilities_output}" | jq -e '.outcome == "complete" and (.items[0].operations == ["discover","inventory"]) and (.items[0].inventory_modes == ["full"]) and (.items[1].operations == ["discover","inventory"]) and (.items[1].inventory_modes == ["full"])' >/dev/null || fail "capabilities did not advertise the tested profiles"
printf '%s\n' "${capabilities_output}" >"${TEMP_DIR}/capabilities.json"
validate_report "${TEMP_DIR}/capabilities.json"
# Only the local version probe may run; no repository command is allowed.
if grep -qE '^borg (info|list|create|prune|check|extract|init)' "${ATTEMPT_LOG}"; then
    fail "provider repository command was invoked for capabilities"
fi

long_id="$(printf 'c%.0s' {1..128})"
: >"${ATTEMPT_LOG}"
long_source_id="$(printf 's%.0s' {1..128})"
long_inventory="$(printf '%s' "${valid_inventory}" | jq -c --arg collection_id "${long_id}" '.collection_id = $collection_id | .budgets.max_report_bytes = 1024')"
set +e
long_output="$(run_observer "${long_inventory}" 2>"${TEMP_DIR}/long-budget.err")"
status=$?
set -e
assert_eq "${status}" "20" "failure byte budget exit"
printf '%s\n' "${long_output}" >"${TEMP_DIR}/long-budget.json"
[[ $(wc -c <"${TEMP_DIR}/long-budget.json") -le 1024 ]] || fail "failure report exceeded the requested byte budget"
jq -e '.outcome == "failed" and .errors[0].code == "budget_exceeded"' "${TEMP_DIR}/long-budget.json" >/dev/null || fail "failure byte budget was not reported"
validate_report "${TEMP_DIR}/long-budget.json"
# A read-only structured listing is expected; no mutation command is allowed.
if grep -qE '^borg (create|prune|compact|check|extract|init|break-lock)' "${ATTEMPT_LOG}"; then
    fail "mutation command was invoked for failure byte budget"
fi

cancel_request='{"schema_version":"1.0","collection_id":"test-cancel","operation":"inventory","scope":{"kind":"location","source_id":"test-source","provider":"borg","location_id":"borg-forged"},"budgets":{"max_report_bytes":65536,"max_items":100,"max_runtime_seconds":30},"scan":{"scan_id":"test-cancel-scan","mode":"full","page_index":0,"continuation":null}}'
: >"${ATTEMPT_LOG}"
set +e
env PATH="${FAKE_BIN_DIR}:/usr/bin:/bin" BO_ATTEMPT_LOG="${ATTEMPT_LOG}" BROLIT_OBSERVER_TEST_MODE=1 BROLIT_OBSERVER_TEST_CONFIG_FILE="${FIXTURE_DIR}/config-valid.json" BROLIT_OBSERVER_TEST_DELAY_SECONDS=2 "${OBSERVER}" --test-mode <<<"${cancel_request}" >"${TEMP_DIR}/cancel.json" 2>"${TEMP_DIR}/cancel.err" &
cancel_pid=$!
sleep 0.1
kill -TERM "${cancel_pid}"
wait "${cancel_pid}"
status=$?
set -e
assert_eq "${status}" "10" "cancelled report exit"
jq -e '.outcome == "partial" and .collection_id == "test-cancel" and .scope.location_id == "borg-forged" and .errors[0].code == "cancelled" and .pagination.scan_id == "test-cancel-scan" and .pagination.page_complete == false and .pagination.has_more == false and .pagination.next_token == null and .pagination.checkpoint == null' "${TEMP_DIR}/cancel.json" >/dev/null || fail "cancellation report was not canonical and incomplete"
validate_report "${TEMP_DIR}/cancel.json"
assert_file_empty "${ATTEMPT_LOG}" "provider command was invoked after cancellation"

: >"${ATTEMPT_LOG}"
set +e
item_limited_output="$(run_observer "${item_limited_capabilities}" 2>"${TEMP_DIR}/item-limit.err")"
status=$?
set -e
assert_eq "${status}" "20" "item budget exit"
printf '%s\n' "${item_limited_output}" >"${TEMP_DIR}/item-limit.json"
jq -e '.outcome == "failed" and .errors[0].code == "budget_exceeded" and (.items | length) == 0' >/dev/null <<<"${item_limited_output}" || fail "item budget was not enforced"
validate_report "${TEMP_DIR}/item-limit.json"
# Only the local version probe is allowed; no repository command.
if grep -qE '^borg (info|list|create|prune|check|extract|init)' "${ATTEMPT_LOG}"; then
    fail "repository command was invoked for item budget"
fi

: >"${ATTEMPT_LOG}"
set +e
invalid_output="$(run_observer "${invalid_version}" 2>"${TEMP_DIR}/invalid.err")"
status=$?
set -e
assert_eq "${status}" "40" "unsupported version exit"
assert_eq "${invalid_output}" "" "unsupported version stdout"
assert_file_empty "${ATTEMPT_LOG}" "provider command was invoked for malformed input"

# Ambient fixture variables must not activate test mode without the explicit
# test-only argument used by the harness.
: >"${ATTEMPT_LOG}"
set +e
ambient_output="$(env PATH="${FAKE_BIN_DIR}:/usr/bin:/bin" BO_EXEC_PATH="${FAKE_BIN_DIR}:/usr/bin:/bin" BO_ATTEMPT_LOG="${ATTEMPT_LOG}" BROLIT_OBSERVER_TEST_MODE=1 BROLIT_OBSERVER_TEST_CONFIG_FILE="${FIXTURE_DIR}/config-valid.json" "${OBSERVER}" <<<"${valid_capabilities}")"
status=$?
set -e
assert_eq "${status}" "20" "ambient test-mode variables exit"
printf '%s' "${ambient_output}" | jq -e '.outcome == "failed" and .errors[0].code == "invalid_configuration"' >/dev/null || fail "ambient test-mode variables changed the production configuration boundary"
assert_file_empty "${ATTEMPT_LOG}" "ambient test-mode variables activated fixture provider commands"

malformed_config="${TEMP_DIR}/malformed-config.json"
printf '%s\n' '{"BROLIT_SETUP":{"config":[{"version":"3.10.7"}]},"BACKUPS":{"methods":"not-an-array"}}' >"${malformed_config}"
set +e
malformed_config_output="$(env PATH="${FAKE_BIN_DIR}:/usr/bin:/bin" BO_EXEC_PATH="${FAKE_BIN_DIR}:/usr/bin:/bin" BO_ATTEMPT_LOG="${ATTEMPT_LOG}" BROLIT_OBSERVER_TEST_CONFIG_FILE="${malformed_config}" "${OBSERVER}" --test-mode <<<"${valid_capabilities}")"
status=$?
set -e
assert_eq "${status}" "20" "malformed configuration exit"
printf '%s' "${malformed_config_output}" | jq -e '.outcome == "failed" and .errors[0].code == "invalid_configuration"' >/dev/null || fail "malformed configuration was accepted"
assert_file_empty "${ATTEMPT_LOG}" "provider command was invoked for malformed configuration"

: >"${ATTEMPT_LOG}"
set +e
forged_output="$(run_observer "${forged_inventory}" 2>"${TEMP_DIR}/forged.err")"
status=$?
set -e
assert_eq "${status}" "20" "forged handle exit"
printf '%s' "${forged_output}" | jq -e '.outcome == "failed" and .errors[0].code == "scope_unresolved"' >/dev/null || fail "forged handle was not rejected"
printf '%s\n' "${forged_output}" >"${TEMP_DIR}/forged.json"
validate_report "${TEMP_DIR}/forged.json"
assert_file_empty "${ATTEMPT_LOG}" "provider command was invoked for forged handle"

# ── Borg adapter (fixture-backed, network-free) ──────────────────────────
: >"${ATTEMPT_LOG}"

set +e
discover_output="$(run_observer "${valid_discover}" 2>"${TEMP_DIR}/discover.err")"
status=$?
set -e
# demo.stellacast.com.yml yields two repositories; broken.stellacast.com.yml
# keeps a failed diagnostic without hiding the healthy locations.
assert_eq "${status}" "10" "discover partial exit"
printf '%s' "${discover_output}" | jq -e '
  .outcome == "partial"
  and (.items | length) == 3
  and ([.items[] | select(.outcome == "complete")] | length) == 2
  and ([.items[] | select(.outcome == "failed")] | length) == 1
  and (.errors[0].code == "invalid_configuration")
  and (([.items[] | select(.outcome == "complete")][0].destination.repository_native_id) == "b84ddee397162a6bbf4def41e630048005bea7dbb39d4a23390c0c7acf9dd4b6")
  and (([.items[] | select(.outcome == "complete")][0].destination.identity_kind) == "native")
  and (([.items[] | select(.outcome == "complete")][0].resource_hints[0].resource_hint) == "demo.stellacast.com")
' >/dev/null || fail "borg discovery output mismatch: ${discover_output}"
printf '%s\n' "${discover_output}" >"${TEMP_DIR}/discover.json"
validate_report "${TEMP_DIR}/discover.json"
grep -q '^borg info.*--json' "${ATTEMPT_LOG}" || fail "borg discovery did not use a read-only identity probe"
if grep -qE '^borg (create|prune|compact|check|extract|init|break-lock)' "${ATTEMPT_LOG}"; then
    fail "borg mutation command was invoked during discovery"
fi
[[ ! -e /tmp/brolit-observation-hook-canary && ! -e /tmp/brolit-observation-passcommand-canary ]] || fail "hostile Borgmatic configuration was evaluated"

set +e
inventory_output="$(run_observer "${valid_inventory}" 2>"${TEMP_DIR}/inventory.err")"
status=$?
set -e
assert_eq "${status}" "0" "inventory complete exit"
printf '%s' "${inventory_output}" | jq -e '
  .outcome == "complete"
  and (.items | length) == 2
  and (.items[0].native_id == "7d6dc4b30983dae745cc3d2cabd6162f9f9a4985315f4d6a41088aeb1fce5802")
  and (.items[0].backup_time.provenance == "archive_metadata")
  and (.items[0].backup_time.value | test("Z$"))
  and (.items[0].provider_modified_time.provenance == "unknown")
  and (.items[0].classification.type == "files")
  and (.items[0].associations[0].provenance == "naming_inference")
   and .pagination.page_complete and (.pagination.has_more | not) and (.pagination.checkpoint == null) and .pagination.consistency == "best_effort"
' >/dev/null || fail "borg inventory output mismatch: ${inventory_output}"
printf '%s\n' "${inventory_output}" >"${TEMP_DIR}/inventory.json"
validate_report "${TEMP_DIR}/inventory.json"
grep -q '^borg list.*--json' "${ATTEMPT_LOG}" || fail "borg inventory did not use structured listing"
grep -q 'borg-env unencrypted=yes relocated=yes' "${ATTEMPT_LOG}" || fail "Borg compatibility exceptions were not fixed to the tested profile"

set +e
locked_output="$(run_observer "${valid_inventory}" lock 2>"${TEMP_DIR}/locked.err")"
status=$?
set -e
assert_eq "${status}" "20" "busy lock exit"
printf '%s' "${locked_output}" | jq -e '.outcome == "failed" and .errors[0].code == "busy_locked"' >/dev/null || fail "Borg lock failure was not classified as busy_locked"

set +e
missing_output="$(run_observer "${valid_inventory}" missing 2>"${TEMP_DIR}/missing-repository.err")"
status=$?
set -e
assert_eq "${status}" "20" "missing repository exit"
printf '%s' "${missing_output}" | jq -e '.outcome == "failed" and .errors[0].code == "repository_missing"' >/dev/null || fail "missing repository was not classified"

set +e
truncated_output="$(run_observer "${valid_inventory}" truncated 2>"${TEMP_DIR}/truncated.err")"
status=$?
set -e
assert_eq "${status}" "20" "truncated Borg output exit"
printf '%s' "${truncated_output}" | jq -e '.outcome == "failed" and .errors[0].code == "budget_exceeded"' >/dev/null || fail "truncated Borg output was not bounded"

# Paging: one item per page produces a partial first page with a token, then a
# terminal page from that token; a forged token is rejected.
set +e
paged_output="$(run_observer "${paged_inventory}" 2>"${TEMP_DIR}/paged.err")"
status=$?
set -e
assert_eq "${status}" "10" "paged inventory exit"
printf '%s' "${paged_output}" | jq -e '.outcome == "partial" and (.items | length) == 1 and .pagination.has_more and (.pagination.next_token | test("^s[0-9a-f]+m[0-9a-f]{64}o1$"))' >/dev/null || fail "first page was not a continuing page"
printf '%s\n' "${paged_output}" >"${TEMP_DIR}/paged.json"
validate_report "${TEMP_DIR}/paged.json"
next_token="$(printf '%s' "${paged_output}" | jq -r '.pagination.next_token')"
second_page="$(printf '%s' "${paged_inventory}" | jq -c --arg token "${next_token}" '.collection_id = "test-inventory-paged-2" | .scan.page_index = 1 | .scan.continuation = $token')"
set +e
second_output="$(run_observer "${second_page}" 2>"${TEMP_DIR}/paged2.err")"
status=$?
set -e
assert_eq "${status}" "0" "second page exit"
printf '%s' "${second_output}" | jq -e '.outcome == "complete" and (.items | length) == 1 and (.pagination.has_more | not) and (.pagination.next_token == null)' >/dev/null || fail "second page did not terminate the scan"
printf '%s\n' "${second_output}" >"${TEMP_DIR}/paged2.json"
validate_report "${TEMP_DIR}/paged2.json"
forged_page="$(printf '%s' "${paged_inventory}" | jq -c '.collection_id = "test-inventory-forged" | .scan.page_index = 1 | .scan.continuation = "sdeadbeefa99"')"
set +e
forged_page_output="$(run_observer "${forged_page}" 2>"${TEMP_DIR}/paged-forged.err")"
status=$?
set -e
assert_eq "${status}" "20" "forged continuation exit"
printf '%s' "${forged_page_output}" | jq -e '.outcome == "failed" and .errors[0].code == "cursor_invalid"' >/dev/null || fail "forged continuation was not rejected"
printf '%s\n' "${forged_page_output}" >"${TEMP_DIR}/paged-forged.json"
validate_report "${TEMP_DIR}/paged-forged.json"

# ── Dropbox adapter (fixture-backed, network-free) ───────────────────────
dropbox_discover_request='{"schema_version":"1.0","collection_id":"test-dropbox-discover","operation":"discover","scope":{"kind":"source","source_id":"test-source"},"budgets":{"max_report_bytes":65536,"max_items":100,"max_runtime_seconds":30}}'
dropbox_inventory_request='{"schema_version":"1.0","collection_id":"test-dropbox-inventory","operation":"inventory","scope":{"kind":"location","source_id":"test-source","provider":"dropbox","location_id":"dropbox-root"},"budgets":{"max_report_bytes":65536,"max_items":2,"max_runtime_seconds":30},"scan":{"scan_id":"test-dropbox-scan","mode":"full","page_index":0,"continuation":null}}'
dropbox_incremental_request='{"schema_version":"1.0","collection_id":"test-dropbox-incremental","operation":"inventory","scope":{"kind":"location","source_id":"test-source","provider":"dropbox","location_id":"dropbox-root"},"budgets":{"max_report_bytes":65536,"max_items":2,"max_runtime_seconds":30},"scan":{"scan_id":"test-dropbox-incremental-scan","mode":"incremental","page_index":0,"continuation":null}}'
: >"${ATTEMPT_LOG}"
set +e
dropbox_incremental_output="$(run_dropbox_observer "${dropbox_incremental_request}" 2>"${TEMP_DIR}/dropbox-incremental.err")"
status=$?
set -e
assert_eq "${status}" "30" "Dropbox incremental exit"
printf '%s' "${dropbox_incremental_output}" | jq -e '.outcome == "unsupported" and .errors[0].code == "unsupported_version" and .pagination.mode == "incremental" and (.items | length) == 0' >/dev/null || fail "Dropbox incremental mode was not rejected"
printf '%s\n' "${dropbox_incremental_output}" >"${TEMP_DIR}/dropbox-incremental.json"
validate_report "${TEMP_DIR}/dropbox-incremental.json"
assert_file_empty "${ATTEMPT_LOG}" "provider command was invoked for unsupported incremental mode"

set +e
dropbox_discover_output="$(run_dropbox_observer "${dropbox_discover_request}" 2>"${TEMP_DIR}/dropbox-discover.err")"
status=$?
set -e
assert_eq "${status}" "0" "Dropbox discovery exit"
printf '%s' "${dropbox_discover_output}" | jq -e '.outcome == "complete" and (.items | length) == 1 and .items[0].destination.identity_kind == "native" and .items[0].destination.account_id == "dbid:fixture-account" and .items[0].destination.namespace_id == "123456" and .items[0].destination.authorized_root == "/fixture-host/projects-online" and .items[0].generation_enabled' >/dev/null || fail "Dropbox discovery output mismatch: ${dropbox_discover_output}"
printf '%s\n' "${dropbox_discover_output}" >"${TEMP_DIR}/dropbox-discover.json"
validate_report "${TEMP_DIR}/dropbox-discover.json"

set +e
dropbox_page_one="$(run_dropbox_observer "${dropbox_inventory_request}" 2>"${TEMP_DIR}/dropbox-page-one.err")"
status=$?
set -e
assert_eq "${status}" "10" "Dropbox first page exit"
printf '%s' "${dropbox_page_one}" | jq -e '.outcome == "partial" and (.items | length) == 1 and .items[0].native_id == "id:fixture-one" and .items[0].revision == "rev-one" and .items[0].sizes[0].value == 1234 and .items[0].backup_time.provenance == "naming_inference" and .items[0].provider_modified_time.provenance == "provider_metadata" and .items[0].metadata.client_modified_at != null and .items[0].classification.type == "files" and .pagination.has_more and (.pagination.next_token | test("^d[A-Za-z0-9]+c[A-Za-z0-9_-]+$"))' >/dev/null || fail "Dropbox first page mismatch: ${dropbox_page_one}"
printf '%s\n' "${dropbox_page_one}" >"${TEMP_DIR}/dropbox-page-one.json"
validate_report "${TEMP_DIR}/dropbox-page-one.json"
dropbox_next_token="$(printf '%s' "${dropbox_page_one}" | jq -r '.pagination.next_token')"
dropbox_page_two_request="$(printf '%s' "${dropbox_inventory_request}" | jq -c --arg token "${dropbox_next_token}" '.collection_id = "test-dropbox-inventory-2" | .scan.page_index = 1 | .scan.continuation = $token')"
set +e
dropbox_page_two="$(run_dropbox_observer "${dropbox_page_two_request}" 2>"${TEMP_DIR}/dropbox-page-two.err")"
status=$?
set -e
assert_eq "${status}" "0" "Dropbox second page exit"
printf '%s' "${dropbox_page_two}" | jq -e '.outcome == "complete" and (.items | length) == 1 and .items[0].native_id == "id:fixture-two" and .items[0].revision == "rev-two" and .items[0].classification.type == "database" and .items[0].sizes[0].value == 4567 and (.pagination.has_more | not) and (.pagination.next_token == null) and (.pagination.checkpoint == null)' >/dev/null || fail "Dropbox second page mismatch: ${dropbox_page_two}"
printf '%s\n' "${dropbox_page_two}" >"${TEMP_DIR}/dropbox-page-two.json"
validate_report "${TEMP_DIR}/dropbox-page-two.json"

dropbox_forged_request="$(printf '%s' "${dropbox_inventory_request}" | jq -c '.collection_id = "test-dropbox-forged" | .scan.page_index = 1 | .scan.continuation = "ddeadbeefcZmFrZS1jdXJzb3I"')"
set +e
dropbox_forged_output="$(run_dropbox_observer "${dropbox_forged_request}" 2>"${TEMP_DIR}/dropbox-forged.err")"
status=$?
set -e
assert_eq "${status}" "20" "Dropbox forged cursor exit"
printf '%s' "${dropbox_forged_output}" | jq -e '.outcome == "failed" and .errors[0].code == "cursor_invalid"' >/dev/null || fail "Dropbox forged cursor was not rejected"
printf '%s\n' "${dropbox_forged_output}" >"${TEMP_DIR}/dropbox-forged.json"
validate_report "${TEMP_DIR}/dropbox-forged.json"

set +e
dropbox_repeat_one="$(run_dropbox_observer "${dropbox_inventory_request}" repeat 2>"${TEMP_DIR}/dropbox-repeat-one.err")"
set -e
dropbox_repeat_token="$(printf '%s' "${dropbox_repeat_one}" | jq -r '.pagination.next_token')"
dropbox_repeat_request="$(printf '%s' "${dropbox_inventory_request}" | jq -c --arg token "${dropbox_repeat_token}" '.collection_id = "test-dropbox-repeat-2" | .scan.page_index = 1 | .scan.continuation = $token')"
set +e
dropbox_repeat_two="$(run_dropbox_observer "${dropbox_repeat_request}" repeat 2>"${TEMP_DIR}/dropbox-repeat-two.err")"
status=$?
set -e
assert_eq "${status}" "20" "Dropbox repeated cursor exit"
printf '%s' "${dropbox_repeat_two}" | jq -e '.outcome == "failed" and .errors[0].code == "cursor_invalid"' >/dev/null || fail "Dropbox repeated cursor was not rejected"
printf '%s\n' "${dropbox_repeat_two}" >"${TEMP_DIR}/dropbox-repeat-two.json"
validate_report "${TEMP_DIR}/dropbox-repeat-two.json"

set +e
dropbox_malformed="$(run_dropbox_observer "${dropbox_inventory_request}" malformed 2>"${TEMP_DIR}/dropbox-malformed.err")"
status=$?
set -e
assert_eq "${status}" "20" "Dropbox malformed response exit"
printf '%s' "${dropbox_malformed}" | jq -e '.outcome == "failed" and .errors[0].code == "malformed_response"' >/dev/null || fail "Dropbox malformed response was not rejected"
printf '%s\n' "${dropbox_malformed}" >"${TEMP_DIR}/dropbox-malformed.json"
validate_report "${TEMP_DIR}/dropbox-malformed.json"

set +e
dropbox_rate_limited="$(run_dropbox_observer "${dropbox_inventory_request}" rate 2>"${TEMP_DIR}/dropbox-rate.err")"
status=$?
set -e
assert_eq "${status}" "20" "Dropbox rate-limit exit"
printf '%s' "${dropbox_rate_limited}" | jq -e '.outcome == "failed" and .errors[0].code == "rate_limited"' >/dev/null || fail "Dropbox rate limit was not classified"
printf '%s\n' "${dropbox_rate_limited}" >"${TEMP_DIR}/dropbox-rate.json"
validate_report "${TEMP_DIR}/dropbox-rate.json"

set +e
dropbox_oversized="$(run_dropbox_observer "${dropbox_inventory_request}" oversized 2>"${TEMP_DIR}/dropbox-oversized.err")"
status=$?
set -e
assert_eq "${status}" "20" "Dropbox oversized response exit"
printf '%s' "${dropbox_oversized}" | jq -e '.outcome == "failed" and .errors[0].code == "budget_exceeded"' >/dev/null || fail "Dropbox oversized response was not bounded"
printf '%s\n' "${dropbox_oversized}" >"${TEMP_DIR}/dropbox-oversized.json"
validate_report "${TEMP_DIR}/dropbox-oversized.json"

set +e
dropbox_outside_root="$(run_dropbox_observer "${dropbox_inventory_request}" outside-root 2>"${TEMP_DIR}/dropbox-outside-root.err")"
status=$?
set -e
assert_eq "${status}" "20" "Dropbox outside-root exit"
printf '%s' "${dropbox_outside_root}" | jq -e '.outcome == "failed" and .errors[0].code == "malformed_response"' >/dev/null || fail "Dropbox outside-root response was not rejected"
printf '%s\n' "${dropbox_outside_root}" >"${TEMP_DIR}/dropbox-outside-root.json"
validate_report "${TEMP_DIR}/dropbox-outside-root.json"

set +e
dropbox_reset_one="$(run_dropbox_observer "${dropbox_inventory_request}")"
set -e
dropbox_reset_token="$(printf '%s' "${dropbox_reset_one}" | jq -r '.pagination.next_token')"
dropbox_reset_request="$(printf '%s' "${dropbox_inventory_request}" | jq -c --arg token "${dropbox_reset_token}" '.collection_id = "test-dropbox-reset-2" | .scan.page_index = 1 | .scan.continuation = $token')"
set +e
dropbox_reset_output="$(run_dropbox_observer "${dropbox_reset_request}" reset 2>"${TEMP_DIR}/dropbox-reset.err")"
status=$?
set -e
assert_eq "${status}" "20" "Dropbox reset cursor exit"
printf '%s' "${dropbox_reset_output}" | jq -e '.outcome == "failed" and .errors[0].code == "cursor_invalid"' >/dev/null || fail "Dropbox reset cursor was not classified as cursor_invalid"
printf '%s\n' "${dropbox_reset_output}" >"${TEMP_DIR}/dropbox-reset.json"
validate_report "${TEMP_DIR}/dropbox-reset.json"

if grep -qE 'fixture-(app-key|app-secret|refresh-token)|sl\.fixture-token' "${ATTEMPT_LOG}" || \
   grep -qE 'fixture-(app-key|app-secret|refresh-token)|sl\.fixture-token' <<<"${dropbox_discover_output}${dropbox_page_one}${dropbox_page_two}"; then
    fail "Dropbox secret entered argv, reports, or diagnostics"
fi
if grep -qE 'upload|download|delete|create_folder|restore' "${ATTEMPT_LOG}"; then
    fail "mutation-capable Dropbox operation was attempted"
fi

if grep -REq 'source .*dropbox_uploader\.sh|dropbox_(upload|download|delete|create_dir)\(' "${OBSERVER}" "${ROOT_DIR}/libs/backup_observation" 2>/dev/null; then
    fail "mutation-capable Dropbox helper was imported by the observer boundary"
fi

source "${ROOT_DIR}/libs/backup_observation/config_projection.sh"
export BROLIT_OBSERVER_TEST_MODE=1
hostile_credentials="${TEMP_DIR}/credentials-hostile"
cp "${FIXTURE_DIR}/credentials-hostile" "${hostile_credentials}"
chmod 600 "${hostile_credentials}"
export BROLIT_OBSERVER_TEST_CREDENTIAL_FILE="${hostile_credentials}"
if bo_parse_literal_credentials "${hostile_credentials}"; then
    fail "hostile credential assignment was accepted"
fi
[[ ! -e "${CANARY}" ]] || fail "credential command substitution executed"

printf 'PASS: isolated observer checks\n'
