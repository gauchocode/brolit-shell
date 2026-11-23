#!/usr/bin/env bash
# retrieve_cron_jobs must always print valid JSON whatever the crontab holds. A cron with
# double quotes made it invalid on gaucho-automate01 and Admin kept stale cron data.
set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"; trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
command -v jq >/dev/null || { echo "skip: jq missing"; exit 0; }

cat >"${TMP}/crontab" <<'FAKE'
#!/usr/bin/env bash
[[ "${1:-}" == "-l" ]] || exit 1
cat "${CRONTAB_FIXTURE}"
FAKE
chmod +x "${TMP}/crontab"
export CRONTAB_FIXTURE="${TMP}/fixture"
printf '%s\n' \
  '*/30 * * * * /usr/bin/flock -n /var/lock/a.lock /usr/bin/timeout 25m /root/brolit-shell/cron/a.sh > /dev/null' \
  '0 3 1 * * docker exec pg psql -U root -d n8n -c "VACUUM FULL execution_data;" >> /var/log/n8n-vacuum.log 2>&1' \
  '5 4 * * * echo "back\slash" | sed '"'"'s/a/b/'"'"'' >"${CRONTAB_FIXTURE}"

out="$(cd "${ROOT_DIR}" && PATH="${TMP}:${PATH}" bash -c 'source ./brolit_lite.sh >/dev/null 2>&1; retrieve_cron_jobs' 2>/dev/null)"
jq -e 'type == "array" and length == 3' <<<"${out}" >/dev/null || fail "not a valid 3-entry JSON array: ${out}"
[[ "$(jq -r '.[1].command' <<<"${out}")" == 'docker exec pg psql -U root -d n8n -c "VACUUM FULL execution_data;" >> /var/log/n8n-vacuum.log 2>&1' ]] || fail "quoted command did not round-trip"
[[ "$(jq -r '.[2].command' <<<"${out}")" == 'echo "back\slash" | sed '"'"'s/a/b/'"'"'' ]] || fail "backslash command did not round-trip"
echo "cron list is valid JSON and commands round-trip: ok"
