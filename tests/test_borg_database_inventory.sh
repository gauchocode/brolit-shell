#!/usr/bin/env bash
# Database inventory and ownership rules (libs/local/borg_database_inventory.sh).
# The scenario is the real one found on stellacast-vm (2026-11-22): the live
# database in a container, a dormant host MySQL with copies of the same names, a
# project whose .env points at the host while its containers use another source,
# an orphan whose project directory is gone, and a throwaway database.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

log_event() { echo "${1}: ${2}" >>"${TMP}/log"; }
# shellcheck disable=SC1091
source "${ROOT_DIR}/libs/local/borg_database_inventory.sh"

export BROLIT_MAIN_DIR="${ROOT_DIR}" PROJECTS_PATH="${TMP}/www" BROLIT_CONFIG_FILE="${TMP}/conf.json"
mkdir -p "${PROJECTS_PATH}"/{app.stellacast.com,stage01.stellacast.com,stage03.stellacast.com,extras.stellacast.com}
echo "DB_HOST=127.0.0.1
DB_DATABASE=app_stellacast_prod" >"${PROJECTS_PATH}/app.stellacast.com/.env"
echo "DB_DATABASE=stellacast_prod" >"${PROJECTS_PATH}/app.stellacast.com/.env.docker"
echo "DB_DATABASE=01_stellacast_stage" >"${PROJECTS_PATH}/stage01.stellacast.com/.env"
echo "version: '3'" >"${PROJECTS_PATH}/app.stellacast.com/docker-compose.yml"
echo "version: '3'" >"${PROJECTS_PATH}/extras.stellacast.com/docker-compose.yml"

# ---- fakes ---------------------------------------------------------------
# Canned answers of database servers, keyed by "<kind>:<container>".
declare -A DBS=(
  ["compose:stellacast-prod_mariadb"]="app_stellacast_prod"
  ["compose:stellacast-extras_mariadb"]="extras_stellacast_prod"
  ["container:castinera-staging_mariadb"]="01_stellacast_stage"
  ["host:-"]="app_stellacast_prod stellacast_prod 01_stellacast_stage stage03_stellacast_stage staging_stellacast_stage stellacast_tmp"
)
# size_mb:writes:uptime per database name on each server
declare -A STAT=(
  ["compose:stellacast-prod_mariadb:app_stellacast_prod"]="15000:107527:894697"
  ["compose:stellacast-extras_mariadb:extras_stellacast_prod"]="900:3000:894697"
  ["container:castinera-staging_mariadb:01_stellacast_stage"]="12000:50:894697"
  ["host:-:app_stellacast_prod"]="14883:0:30014"
  ["host:-:stellacast_prod"]="14188:0:30014"
  ["host:-:01_stellacast_stage"]="12637:0:30014"
  ["host:-:stage03_stellacast_stage"]="12000:0:30014"
  ["host:-:staging_stellacast_stage"]="12343:0:30014"
  ["host:-:stellacast_tmp"]="22:0:30014"
)
bdb_query() {  # kind engine container sql
  local kind="${1}" container="${3}" sql="${4}" k="${1}:${3}" db st
  if [[ "${sql}" == "SHOW DATABASES" ]]; then
    for db in ${DBS[${k}]:-}; do echo "${db}"; done
    echo "information_schema"; echo "mysql"; echo "sys"; return 0
  fi
  db="$(sed -nE "s/.*table_schema='([^']+)'.*/\1/p" <<<"${sql}")"
  [[ -n "${db}" ]] || return 0
  st="${STAT[${k}:${db}]:-0:0:0}"
  IFS=: read -r size writes uptime <<<"${st}"
  if [[ "${sql}" == SELECT* ]]; then echo "${size}"; else :; fi
  [[ "${sql}" == "SHOW GLOBAL STATUS"* ]] && { echo -e "Com_insert\t${writes}\nCom_update\t0\nUptime\t${uptime}"; }
}
# The status query has no table_schema: answer it per call from the last database asked
LAST_DB=""
bdb_stats_wrapper() { :; }
docker() {
  case "${1:-}" in
  ps)
    if [[ "$*" == *"label=com.docker.compose.service=mariadb"* && "$*" == *"app.stellacast.com"* ]]; then echo "stellacast-prod_mariadb"
    elif [[ "$*" == *"label=com.docker.compose.service=mariadb"* && "$*" == *"extras.stellacast.com"* ]]; then echo "stellacast-extras_mariadb"
    elif [[ "$*" == *"{{.Image}}"* ]]; then printf 'clickhouse-analytics\tclickhouse/clickhouse-server:24\nredis-cache\tredis:7\nstellacast-prod_app\tstellacast/php-fpm:8\n'
    elif [[ "$*" == *"--format {{.Names}}"* && "$*" != *"--filter"* ]]; then printf '%s\n' stellacast-prod_mariadb stellacast-extras_mariadb castinera-staging_mariadb stellacast-prod_app
    fi ;;
  inspect)
    local name="${*: -1}" fmt="${3:-}"
    case "${fmt}" in
    *Config.Image*) case "${name}" in *mariadb*) echo "mariadb:10.11" ;; stellacast-prod_app) echo "stellacast/php-fpm:8.5" ;; clickhouse-analytics) echo "clickhouse/clickhouse-server:24" ;; esac ;;
    *working_dir*) case "${name}" in stellacast-prod_mariadb) echo "${PROJECTS_PATH}/app.stellacast.com" ;; stellacast-extras_mariadb) echo "${PROJECTS_PATH}/extras.stellacast.com" ;; esac ;;
    *Mounts*) case "${name}" in castinera-staging_mariadb) echo "${PROJECTS_PATH}/stage01.stellacast.com/mysql_data_staging" ;; esac ;;
    esac ;;
  esac
}
docker_list_project_databases() {
  case "${1}" in
  */app.stellacast.com/*) printf 'mariadb\tmysql\n' ;;
  */extras.stellacast.com/*) printf 'mariadb\tmysql\n' ;;
  esac
}
mysql() { return 0; }; mysqladmin() { return 0; }
export -f mysql mysqladmin 2>/dev/null || true
# The global status query carries no schema, so make bdb_stats ask per database instead
bdb_query_orig="$(declare -f bdb_query)"
bdb_query() {
  local kind="${1}" container="${3}" sql="${4}" k
  k="${kind}:${container}"
  if [[ "${sql}" == "SHOW GLOBAL STATUS"* ]]; then
    local st="${STAT[${k}:${CUR_DB}]:-0:0:0}"; IFS=: read -r _ writes uptime <<<"${st}"
    printf 'Com_insert\t%s\nCom_update\t0\nUptime\t%s\n' "${writes}" "${uptime}"; return 0
  fi
  if [[ "${sql}" == "SHOW DATABASES" ]]; then
    local db; for db in ${DBS[${k}]:-}; do echo "${db}"; done; echo information_schema; echo mysql; echo sys; return 0
  fi
  local db size
  db="$(sed -nE "s/.*table_schema='([^']+)'.*/\1/p" <<<"${sql}")"; CUR_DB="${db}"
  size="$(cut -d: -f1 <<<"${STAT[${k}:${db}]:-0:0:0}")"; echo "${size}"
}
: "${bdb_query_orig}"

# ---- 1. listing: system schemas and unsafe names are never listed -------------
list="$(bdb_list_databases host mysql -)"
[[ "${list}" == *"app_stellacast_prod"* && "${list}" != *"information_schema"* && "${list}" != *"sys"$'\n'* ]] || fail "listing: ${list}"

# ---- 2. dormancy and size ------------------------------------------------------
CUR_DB="stellacast_prod"; [[ "$(bdb_stats host mysql - stellacast_prod)" == $'14188\t0\tyes' ]] || fail "dormant host copy: $(bdb_stats host mysql - stellacast_prod)"
CUR_DB="app_stellacast_prod"; [[ "$(bdb_stats compose mariadb stellacast-prod_mariadb app_stellacast_prod)" == $'15000\t107527\tno' ]] || fail "live database: $(bdb_stats compose mariadb stellacast-prod_mariadb app_stellacast_prod)"

# ---- 3. the full inventory of the real scenario -------------------------------
inv="$(bdb_collect)"
echo "${inv}" >"${TMP}/inv.tsv"
rows="$(grep -c . "${TMP}/inv.tsv")"
[[ "${rows}" -eq 9 ]] || fail "expected 9 databases, got ${rows}: $(cat "${TMP}/inv.tsv")"
grep -qP "^compose\tapp.stellacast.com/mariadb\tmariadb\tstellacast-prod_mariadb\tapp_stellacast_prod\tapp.stellacast.com\tstructure\t" "${TMP}/inv.tsv" || fail "compose database must be owned by structure"
grep -qP "^container\tcastinera-staging_mariadb\tmariadb\tcastinera-staging_mariadb\t01_stellacast_stage\tstage01.stellacast.com\tstructure\t" "${TMP}/inv.tsv" || fail "a standalone container owned through its bind mount"
grep -qP "^host\thost\tmysql\t-\tstellacast_tmp\t-\tnone\t" "${TMP}/inv.tsv" || fail "host database has no structural owner"

# ---- 4. resolution -----------------------------------------------------------
conf() { jq "$1" "${ROOT_DIR}/config/brolit/brolit_conf.json" >"${BROLIT_CONFIG_FILE}"; }
conf '.'
res="$(bdb_resolve <"${TMP}/inv.tsv")"
get() { awk -F'\t' -v s="${1}" -v d="${2}" '$2==s && $5==d {print $11"|"$12"|"$13"|"$14}' <<<"${res}"; }
[[ "$(get app.stellacast.com/mariadb app_stellacast_prod)" == "linked|app.stellacast.com|structure|0" ]] || fail "live db: $(get app.stellacast.com/mariadb app_stellacast_prod)"
[[ "$(get castinera-staging_mariadb 01_stellacast_stage)" == "linked|stage01.stellacast.com|structure|0" ]] || fail "mount-owned: $(get castinera-staging_mariadb 01_stellacast_stage)"
# same name in two sources (host + container): ambiguous, large and dormant, so held
[[ "$(get host app_stellacast_prod)" == "held|-|held-dormant|1" ]] || fail "duplicate host copy must be held: $(get host app_stellacast_prod)"
[[ "$(get host 01_stellacast_stage)" == "held|-|held-dormant|1" ]] || fail "second duplicate: $(get host 01_stellacast_stage)"
# named only by the app's files, unique name, but large and dormant: a file link is weak evidence
[[ "$(get host stellacast_prod)" == "held|-|held-dormant|1" ]] || fail "file link of a dormant giant must be held: $(get host stellacast_prod)"
# nobody references it and it is large and dormant
[[ "$(get host stage03_stellacast_stage)" == "held|-|held-dormant|1" ]] || fail "unmatched giant: $(get host stage03_stellacast_stage)"
[[ "$(get host staging_stellacast_stage)" == "held|-|held-dormant|1" ]] || fail "orphan: $(get host staging_stellacast_stage)"
# small and unmatched: dumped as standalone, still pending
[[ "$(get host stellacast_tmp)" == "standalone|standalone-host-stellacast_tmp|pending-unmatched|1" ]] || fail "small unmatched: $(get host stellacast_tmp)"

# ---- 5. a file reference links only when it is unique and the database is not dormant
printf 'compose\tx/mariadb\tmariadb\tc1\tshopdb\t-\tnone\t300\t5000\tno\n' >"${TMP}/one.tsv"
echo "DB_NAME=shopdb" >"${PROJECTS_PATH}/stage03.stellacast.com/.env"
[[ "$(bdb_resolve <"${TMP}/one.tsv" | awk -F'\t' '{print $11"|"$12"|"$13"|"$14}')" == "linked|stage03.stellacast.com|file|0" ]] || fail "a unique live file reference links: $(bdb_resolve <"${TMP}/one.tsv")"
echo "DB_NAME=shopdb" >"${PROJECTS_PATH}/extras.stellacast.com/.env"
[[ "$(bdb_resolve <"${TMP}/one.tsv" | awk -F'\t' '{print $11"|"$13"|"$14}')" == "standalone|pending-ambiguous|1" ]] || fail "two projects claiming one name is ambiguous"
rm -f "${PROJECTS_PATH}/extras.stellacast.com/.env"
# same name in two sources, small and live, referenced by exactly one project: still ambiguous
printf 'host\thost\tmysql\t-\tshopdb\t-\tnone\t50\t900\tno\ncompose\ty/mariadb\tmariadb\tc2\tshopdb\ty\tstructure\t60\t800\tno\n' >"${TMP}/dup.tsv"
mkdir -p "${PROJECTS_PATH}/y"
[[ "$(bdb_resolve <"${TMP}/dup.tsv" | awk -F'\t' '$1=="host" {print $11"|"$13"|"$14}')" == "standalone|pending-ambiguous|1" ]] || fail "one reference but the name lives in two sources must be ambiguous: $(bdb_resolve <"${TMP}/dup.tsv")"
rm -f "${PROJECTS_PATH}/stage03.stellacast.com/.env"

# ---- 6. recorded decisions win over everything, and are tolerated when stale -----
conf '.BACKUPS.config[0].databases[0].decisions = [
 {"source":"host","database":"app_stellacast_prod","decision":"ignore"},
 {"source":"host","database":"stage03_stellacast_stage","decision":"link","project":"stage03.stellacast.com"},
 {"source":"host","database":"staging_stellacast_stage","decision":"link","project":"staging.stellacast.com"},
 {"source":"host","database":"stellacast_prod","decision":"standalone"}]'
res="$(bdb_resolve <"${TMP}/inv.tsv")"
[[ "$(get host app_stellacast_prod)" == "ignored|-|decision|0" ]] || fail "ignore decision: $(get host app_stellacast_prod)"
[[ "$(get host stage03_stellacast_stage)" == "linked|stage03.stellacast.com|decision|0" ]] || fail "link decision: $(get host stage03_stellacast_stage)"
[[ "$(get host stellacast_prod)" == "standalone|standalone-host-stellacast_prod|decision|0" ]] || fail "standalone decision is dumped even if large and dormant: $(get host stellacast_prod)"
# the project of this decision no longer exists: stale, pending again, held because it is a dormant giant
[[ "$(get host staging_stellacast_stage)" == "held|-|held-dormant|1" ]] || fail "stale link decision: $(get host staging_stellacast_stage)"
# a structural owner is never overridden by an ignore of another source
[[ "$(get app.stellacast.com/mariadb app_stellacast_prod)" == "linked|app.stellacast.com|structure|0" ]] || fail "decision on the host must not touch the container database"

# ---- 7. unsupported engines are reported, caches are not ----------------------
unsup="$(bdb_collect_unsupported)"
[[ "${unsup}" == clickhouse-analytics$'\t'* && "${unsup}" != *redis* && "${unsup}" != *php-fpm* ]] || fail "unsupported: ${unsup}"

# ---- 8. engine from an image that is only an id: environment, and only then ---
docker() {
  case "${3:-}" in
  *Config.Image*) echo "${FAKE_IMAGE}" ;;
  *Config.Env*) printf '%s\n' "${FAKE_ENV}" ;;
  esac
}
FAKE_IMAGE="c14f2faa3568"; FAKE_ENV=$'PATH=/bin\nMYSQL_ROOT_PASSWORD=x\nMYSQL_DATABASE=d'
[[ "$(bdb_container_engine lmarket_mysql)" == "mysql" ]] || fail "id-only image with MySQL env must resolve to mysql"
FAKE_ENV=$'MARIADB_ROOT_PASSWORD=x'; [[ "$(bdb_container_engine c)" == "mariadb" ]] || fail "MariaDB env"
FAKE_ENV=$'POSTGRES_PASSWORD=x'; [[ "$(bdb_container_engine c)" == "postgres" ]] || fail "Postgres env"
FAKE_IMAGE="stellacast/php-fpm:8.5"; FAKE_ENV=$'MYSQL_DATABASE=app'
[[ -z "$(bdb_container_engine app)" ]] || fail "a named application image with a MYSQL_DATABASE variable must NOT be taken for a database"

echo "borg database inventory tests passed"
