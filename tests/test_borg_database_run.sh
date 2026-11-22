#!/usr/bin/env bash
# Running the database configs and reporting them truthfully:
#  - bdb_borg_databases_enabled: when the Borg database configs are in use
#  - backup_borgmatic_databases: each config goes through the existing per-config
#    path (retries, locks, classified reason) and failures are aggregated
#  - backup_all_databases_borg_report: the "Database Backup" section says what is
#    covered, held, ignored or unsupported, and is an error only when the
#    configuration itself failed
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

log_event() { echo "${1}: ${2}" >>"${TMP}/log"; }
log_subsection() { echo "section: ${1}" >>"${TMP}/log"; }
display() { :; }
mail_backup_section() { printf '%s\n' "${1}|${2}|${3}" >"${TMP}/mail"; printf '%s\n' "${@:4}" >>"${TMP}/mail"; }
# shellcheck disable=SC1091
source "${ROOT_DIR}/libs/local/borg_database_inventory.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/libs/local/borg_database_config.sh"
sed -n '/^function backup_borgmatic_databases() {/,/^}/p;/^function backup_all_databases_borg_report() {/,/^}/p' "${ROOT_DIR}/libs/local/backup_helper.sh" >"${TMP}/fns.sh"
# shellcheck disable=SC1091
source "${TMP}/fns.sh"

export BROLIT_CONFIG_FILE="${TMP}/conf.json" BROLIT_BORGMATIC_DB_CONFIG_DIR="${TMP}/cfg" BROLIT_BORG_DB_STATE_FILE="${TMP}/state.tsv"
mkdir -p "${BROLIT_BORGMATIC_DB_CONFIG_DIR}"

# ---- A. when the database configs are in use ------------------------------------
compression_backup_methods_enabled() { [[ "${COMPRESSION:-no}" == "yes" ]]; }
# The configuration is built from the real template, so its shape cannot drift from the test's.
conf() { jq "$1" "${ROOT_DIR}/config/brolit/brolit_conf.json" >"${BROLIT_CONFIG_FILE}"; }
mode() { conf ".BACKUPS.config[0].databases[0].borg = \"${1}\""; }
check() { # check <expected y|n> <description>
  bdb_borg_databases_enabled && got=y || got=n
  [[ "${got}" == "${1}" ]] || fail "${2}: expected ${1}, got ${got}"
}
BACKUP_BORG_STATUS=enabled
conf '.'
COMPRESSION=no;  check y "auto, Borg only"
COMPRESSION=yes; check n "auto, Borg and Dropbox must keep today's behaviour"
mode enabled;    check y "explicit enabled with Dropbox"
mode disabled; COMPRESSION=no; check n "explicit disabled"
mode auto; COMPRESSION=no; check y "explicit auto"
BACKUP_BORG_STATUS=disabled; mode enabled; check n "Borg itself disabled"
BACKUP_BORG_STATUS=enabled
rm -f "${BROLIT_CONFIG_FILE}"; COMPRESSION=no; check y "no readable config means auto"
echo "not json" >"${BROLIT_CONFIG_FILE}"; check y "an unreadable config means auto, not a crash"
# the key lives where the real configuration keeps it: inside databases[0], next to status and exclude
conf '.'; [[ "$(jq -r '.BACKUPS.config[0].databases | type' "${BROLIT_CONFIG_FILE}")" == "array" ]] || fail "the real template must keep databases as an array"
mode enabled; [[ "$(jq -r '.BACKUPS.config[0].databases[0].status' "${BROLIT_CONFIG_FILE}")" == "enabled" ]] || fail "setting the key must keep the existing databases settings"
COMPRESSION=yes; check y "explicit enabled read from the real configuration shape"

# ---- B. running the configs --------------------------------------------------------
conf '.'; COMPRESSION=no
D="${BROLIT_BORGMATIC_DB_CONFIG_DIR}"
touch "${D}/app.example.com.yml" "${D}/standalone-host-tmp.yml"
backup_borgmatic_config_once() {
  echo "${1}|${2}|${BROLIT_BORGMATIC_CONFIG_DIR:-unset}" >>"${TMP}/calls"
  if [[ "${2}" == "standalone-host-tmp (database)" ]]; then borg_project_status_line="${2};FAIL (database_dump)"; return 1; fi
  borg_project_status_line="${2};OK"; return 0
}
result=0; failed=(); status=()
: >"${TMP}/calls"; : >"${TMP}/log"
backup_borgmatic_databases result failed status
sort "${TMP}/calls" >"${TMP}/calls.sorted"
grep -q "^${D}/app.example.com.yml|app.example.com (database)|${D}$" "${TMP}/calls.sorted" || fail "each config runs with its own label and with the database directory as config directory: $(cat "${TMP}/calls")"
[[ "$(wc -l <"${TMP}/calls")" -eq 2 ]] || fail "both configs must run: $(cat "${TMP}/calls")"
[[ ${result} -eq 1 && "${failed[*]}" == "standalone-host-tmp (database)" ]] || fail "failure must be aggregated: result=${result} failed=${failed[*]}"
[[ "${#status[@]}" -eq 2 && "${status[*]}" == *"app.example.com (database);OK"* && "${status[*]}" == *"FAIL (database_dump)"* ]] || fail "status lines: ${status[*]}"
[[ -z "${BROLIT_BORGMATIC_CONFIG_DIR+x}" ]] || fail "the directory override must not leak out of the call"

# not run when the configs are not in use, nor when there is no directory
COMPRESSION=yes; result=0; failed=(); status=(); : >"${TMP}/calls"
backup_borgmatic_databases result failed status
[[ ! -s "${TMP}/calls" && ${result} -eq 0 ]] || fail "Borg and Dropbox (auto) must not run database configs"
COMPRESSION=no; rm -rf "${D}"; backup_borgmatic_databases result failed status
[[ ! -s "${TMP}/calls" ]] || fail "no directory, no run"
mkdir -p "${D}"

# ---- C. the section that tells the truth ----------------------------------------------
printf 'compose\tapp.stellacast.com/mariadb\tmariadb\tc1\tapp_stellacast_prod\tapp.stellacast.com\tstructure\t15000\t107527\tno\tlinked\tapp.stellacast.com\tstructure\t0\n' >"${BROLIT_BORG_DB_STATE_FILE}"
printf 'host\thost\tmysql\t-\tstellacast_tmp\t-\tnone\t22\t0\tyes\tstandalone\tstandalone-host-stellacast_tmp\tpending-unmatched\t1\n' >>"${BROLIT_BORG_DB_STATE_FILE}"
printf 'host\thost\tmysql\t-\tstellacast_prod\t-\tnone\t14188\t0\tyes\theld\t-\theld-dormant\t1\n' >>"${BROLIT_BORG_DB_STATE_FILE}"
printf 'host\thost\tmysql\t-\told_db\t-\tnone\t5\t0\tyes\tignored\t-\tdecision\t0\n' >>"${BROLIT_BORG_DB_STATE_FILE}"
bdb_collect_unsupported() { printf 'clickhouse-analytics\tclickhouse/clickhouse-server:24\tapp.stellacast.com\n'; }
BDB_CONVERGE_RC=0
backup_all_databases_borg_report; rc=$?
[[ ${rc} -eq 0 ]] || fail "a converged server with a held database is not an error, rc=${rc}"
[[ "$(head -1 "${TMP}/mail")" == "none|none|databases" ]] || fail "section must be OK: $(head -1 "${TMP}/mail")"
grep -q "^app_stellacast_prod;Borg: app.stellacast.com$" "${TMP}/mail" || fail "linked line: $(cat "${TMP}/mail")"
grep -q "^stellacast_tmp;Borg: standalone, decision pending$" "${TMP}/mail" || fail "pending standalone line"
grep -q "^stellacast_prod;HELD, decision pending (14188 MB, no writes)$" "${TMP}/mail" || fail "held line"
grep -q "^old_db;IGNORED$" "${TMP}/mail" || fail "ignored line"
grep -q "^clickhouse-analytics;NOT BACKED UP, engine not supported" "${TMP}/mail" || fail "unsupported line"
grep -q "Databases: 2 covered by Borg, 1 held for a decision, 1 ignored, 1 unsupported" "${TMP}/log" || fail "summary log: $(grep Databases: "${TMP}/log")"

# the configuration step failed: that IS an error, with the reason
BDB_CONVERGE_RC=2
backup_all_databases_borg_report; rc=$?
[[ ${rc} -eq 1 && "$(head -1 "${TMP}/mail")" == "borgmatic is too old for the database backups and could not be raised|database_backup|databases" ]] || fail "too-old borgmatic must be an error: rc=${rc} $(head -1 "${TMP}/mail")"
BDB_CONVERGE_RC=1
backup_all_databases_borg_report; rc=$?
[[ ${rc} -eq 1 && "$(head -1 "${TMP}/mail")" == "the database backup configuration could not be completed|database_backup|databases" ]] || fail "a failed converge must be an error"

# nothing on the server: skipped, not an error
: >"${BROLIT_BORG_DB_STATE_FILE}"; bdb_collect() { :; }; bdb_collect_unsupported() { :; }; BDB_CONVERGE_RC=0
backup_all_databases_borg_report; rc=$?
[[ ${rc} -eq 0 && "$(head -1 "${TMP}/mail")" == "none|none|databases" ]] && grep -q "nothing to dump;SKIPPED" "${TMP}/mail" || fail "empty server: $(cat "${TMP}/mail")"

echo "borg database run tests passed"
