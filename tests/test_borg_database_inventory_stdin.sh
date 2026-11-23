#!/usr/bin/env bash
# The real bdb_query runs db_exec.sh, which ends in `docker exec -i` and therefore reads
# stdin. Inside the loop over running containers that swallowed the rest of the list:
# on stellacast-vm only 1 of 5 MariaDB containers was inventoried (2026-11-23).
set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"; trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
log_event() { :; }
# shellcheck disable=SC1091
source "${ROOT_DIR}/libs/local/borg_database_inventory.sh"

export BROLIT_MAIN_DIR="${ROOT_DIR}" PROJECTS_PATH="${TMP}/www" BROLIT_CONFIG_FILE="${TMP}/conf.json"
mkdir -p "${PROJECTS_PATH}"
# Fake wrapper: like docker exec -i it drains stdin, then answers per container
cat >"${TMP}/db_exec.sh" <<'FAKE'
#!/usr/bin/env bash
cat >/dev/null
container="${3}"
case "${*: -1}" in
  "SHOW DATABASES") echo "db_${container}"; echo information_schema ;;
  *) echo 1 ;;
esac
FAKE
chmod +x "${TMP}/db_exec.sh"; export BROLIT_DB_EXEC="${TMP}/db_exec.sh"

docker() {
  case "${1:-}" in
  ps) if [[ "$*" == *"--format {{.Names}}"* && "$*" != *"--filter"* ]]; then printf '%s\n' c1_mariadb c2_mariadb c3_mariadb c4_mariadb; fi ;;
  inspect) [[ "$*" == *Config.Image* ]] && echo "mariadb:10.11" ;;
  esac
}
docker_list_project_databases() { :; }
bdb_container_owner() { echo ""; }
command() { [[ "${1:-}" == "-v" ]] && return 1; builtin command "$@"; }

out="$(bdb_collect 2>/dev/null)"
for c in c1 c2 c3 c4; do
  grep -q "db_${c}_mariadb" <<<"${out}" || fail "container ${c}_mariadb missing from the inventory: ${out}"
done
echo "inventory reads every container, stdin is not shared with the clients: ok"
