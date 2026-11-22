#!/usr/bin/env bash
# The Borg configuration-coverage check must honour the ignored-projects list of
# the host config, like the files backup does. Real case (stellacast-vm, 2026-11):
# /var/www/tmp (two maintenance pages) is ignored by the operator but failed the
# Borg section of every nightly as "configuration-coverage".
set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"; trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

log_event() { :; }; display() { :; }; send_notification() { echo "notified: ${2}" >>"${TMP}/notes"; }
project_is_ignored() { [[ " ${IGNORED:-} " == *" ${1} "* ]] && echo true || echo false; }
sed -n '/^function check_borgmatic_config_coverage() {/,/^}/p' "${ROOT_DIR}/libs/local/backup_helper.sh" >"${TMP}/fn.sh"
# shellcheck disable=SC1091
source "${TMP}/fn.sh"

export BROLIT_BORGMATIC_CONFIG_DIR="${TMP}/cfg" PROJECTS_PATH="${TMP}/www"
mkdir -p "${BROLIT_BORGMATIC_CONFIG_DIR}" "${PROJECTS_PATH}"/{shop.example.com,tmp,html,empty}
echo x >"${PROJECTS_PATH}/shop.example.com/a"; echo x >"${PROJECTS_PATH}/tmp/index.html"; echo x >"${PROJECTS_PATH}/html/i"
echo "repositories: []" >"${BROLIT_BORGMATIC_CONFIG_DIR}/shop.example.com.yml"

# tmp is non-empty, has no config and is NOT ignored: coverage fails and names it
IGNORED=""; : >"${TMP}/notes"
check_borgmatic_config_coverage; rc=$?
[[ ${rc} -eq 1 ]] || fail "an uncovered non-empty project must fail, rc=${rc}"
grep -q "tmp" "${TMP}/notes" || fail "the notification must name tmp"
grep -qE "(^|[^a-z])html" "${TMP}/notes" && fail "html must stay skipped"

# the same directory, ignored by the operator: coverage is complete
IGNORED="tmp"; : >"${TMP}/notes"
check_borgmatic_config_coverage; rc=$?
[[ ${rc} -eq 0 ]] || fail "an ignored project must not fail the coverage, rc=${rc}"
[[ ! -s "${TMP}/notes" ]] || fail "no notification expected: $(cat "${TMP}/notes")"
echo "borg coverage ignored-list tests passed"
