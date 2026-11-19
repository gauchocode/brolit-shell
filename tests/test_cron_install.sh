#!/usr/bin/env bash
# Verifies brolit_cronjob_install_task (runner.sh --task cron-install) against a
# throwaway crontab file: default schedule + wrapper, idempotency, custom
# schedule validation and unknown kinds. No root and no real crontab needed.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# Extract the two functions and point them at a temp crontab.
{
  echo 'log_section() { :; }; log_event() { :; }; display() { :; }'
  echo "crontab() { :; }"
  sed -n '/^function brolit_cronjob_install() {/,/^}/p;/^function brolit_cronjob_install_task() {/,/^}/p' "${ROOT_DIR}/libs/commons.sh" \
    | sed "s#/var/spool/cron/crontabs/root#${TMP}/root.cron#g; s#/usr/bin/crontab#true#g"
} >"${TMP}/fns.sh"
# shellcheck disable=SC1091
source "${TMP}/fns.sh"

export BROLIT_MAIN_DIR="${TMP}/brolit"
mkdir -p "${BROLIT_MAIN_DIR}/cron"
for f in backups optimizer wordpress security uptime disk_cleanup; do : >"${BROLIT_MAIN_DIR}/cron/${f}_tasks.sh"; done

brolit_cronjob_install_task backups || fail "first install failed"
grep -q "^45 00 \* \* \* /usr/bin/flock -n /var/lock/brolit_backups_tasks.lock /usr/bin/timeout 6h ${BROLIT_MAIN_DIR}/cron/backups_tasks.sh$" "${TMP}/root.cron" || fail "default line wrong: $(cat "${TMP}/root.cron")"

brolit_cronjob_install_task backups || fail "second install must succeed (idempotent)"
[[ "$(grep -c backups_tasks.sh "${TMP}/root.cron")" == "1" ]] || fail "duplicate cron line"

brolit_cronjob_install_task security "10 2 * * 1" || fail "custom schedule rejected"
grep -q "^10 2 \* \* 1 ${BROLIT_MAIN_DIR}/cron/security_tasks.sh$" "${TMP}/root.cron" || fail "custom schedule not written"

brolit_cronjob_install_task uptime "not a cron" && fail "invalid expression accepted"
brolit_cronjob_install_task uptime "* * * * * ; rm -rf /" && fail "injection accepted"
brolit_cronjob_install_task nope && fail "unknown kind accepted"
grep -q "uptime_tasks.sh" "${TMP}/root.cron" && fail "invalid input wrote a line"

echo "cron-install tests passed"
