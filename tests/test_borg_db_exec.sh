#!/usr/bin/env bash
# utils/borg/db_exec.sh is the dump/restore command borgmatic runs for databases
# in containers. It must: take the arguments borgmatic really passes (observed on
# borgmatic 2.2.0), drop the connection flags that describe a host connection,
# honour --result-file / --file, resolve the superuser credential INSIDE the
# container, and never put a credential in the host's argv.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WRAPPER="${ROOT_DIR}/utils/borg/db_exec.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

BIN="${TMP}/bin"; mkdir -p "${BIN}"
export LOG="${TMP}/clients.log" DLOG="${TMP}/docker.log"
# Fake docker: logs its argv and runs what follows "exec -i <container>" locally,
# which is the container's shell script under test.
cat >"${BIN}/docker" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"${DLOG}"
[[ "${1:-}" == exec && "${2:-}" == -i ]] || exit 99
shift 3
exec "$@"
EOF
# Fake clients: record argv and the credential variables they received.
for c in mariadb-dump mysqldump mariadb mysql pg_dump pg_restore psql; do
    cat >"${BIN}/${c}" <<EOF
#!/usr/bin/env bash
echo "${c} \$* | MYSQL_PWD=\${MYSQL_PWD:-} PGPASSWORD=\${PGPASSWORD:-}" >>"\${LOG}"
[[ -t 0 ]] || { read -r -t 1 line && echo "stdin:\$line" >>"\${LOG}"; }
echo "OUT-${c}"
exit "\${FAKE_RC:-0}"
EOF
done
chmod +x "${BIN}"/*
export PATH="${BIN}:${PATH}"
reset() { : >"${LOG}"; : >"${DLOG}"; unset MYSQL_ROOT_PASSWORD MARIADB_ROOT_PASSWORD MYSQL_ROOT_PASSWORD_FILE POSTGRES_PASSWORD POSTGRES_USER FAKE_RC; }

# --- 1. MariaDB dump with the exact argv observed from borgmatic 2.2.0
reset; export MYSQL_ROOT_PASSWORD="s3cr3t-PW"
PIPE="${TMP}/pipe1"
bash "${WRAPPER}" dump mariadb app_mysql --single-transaction --quick --add-drop-database --single-transaction --events --routines --all-tablespaces --databases exito_dev --result-file "${PIPE}"; rc=$?
[[ ${rc} -eq 0 ]] || fail "dump rc=${rc}"
[[ "$(cat "${PIPE}")" == "OUT-mariadb-dump" ]] || fail "output must go to the result file: $(cat "${PIPE}")"
grep -q "^mariadb-dump -uroot --single-transaction --quick --add-drop-database --single-transaction --events --routines --all-tablespaces --databases exito_dev | MYSQL_PWD=s3cr3t-PW" "${LOG}" || fail "client argv/credential: $(cat "${LOG}")"
grep -q -- "--result-file" "${LOG}" && fail "--result-file must not reach the client"
grep -qF "s3cr3t-PW" "${DLOG}" && fail "the credential must never appear in the host's docker argv: $(cat "${DLOG}")"

# --- 2. "=" form of the output flag, and connection flags that must be dropped
reset; export MYSQL_ROOT_PASSWORD="pw2"; PIPE="${TMP}/pipe2"
bash "${WRAPPER}" dump mariadb c --defaults-extra-file=/dev/fd/9 --host localhost --port 3306 --protocol tcp --user bob -hx -P1 -ualice -pXXX --password=zzz --databases d --result-file="${PIPE}"
grep -q "^mariadb-dump -uroot --databases d |" "${LOG}" || fail "connection flags must be dropped: $(cat "${LOG}")"
[[ "$(cat "${PIPE}")" == "OUT-mariadb-dump" ]] || fail "= form of --result-file"

# --- 3. secret through the *_FILE variable; no secret at all
reset; echo -n "from-file-pw" >"${TMP}/secret"; export MYSQL_ROOT_PASSWORD_FILE="${TMP}/secret"
bash "${WRAPPER}" dump mysql c --databases d >/dev/null
grep -q "MYSQL_PWD=from-file-pw" "${LOG}" || fail "_FILE secret not used: $(cat "${LOG}")"
reset
bash "${WRAPPER}" dump mysql c --databases d >/dev/null
grep -q "MYSQL_PWD= " "${LOG}" || fail "no secret must mean no MYSQL_PWD: $(cat "${LOG}")"

# --- 4. engine to binary: mysql uses mysqldump; mariadb falls back to mysqldump when mariadb-dump is absent
reset; export MYSQL_ROOT_PASSWORD=x
bash "${WRAPPER}" dump mysql c --databases d >/dev/null; grep -q "^mysqldump " "${LOG}" || fail "mysql must use mysqldump"
reset; export MYSQL_ROOT_PASSWORD=x; mv "${BIN}/mariadb-dump" "${BIN}/mariadb-dump.off"
bash "${WRAPPER}" dump mariadb c --databases d >/dev/null; grep -q "^mysqldump " "${LOG}" || fail "mariadb must fall back to mysqldump: $(cat "${LOG}")"
mv "${BIN}/mariadb-dump.off" "${BIN}/mariadb-dump"

# --- 5. client mode keeps stdin (restore of a plain dump) and uses the client binary
reset; export MYSQL_ROOT_PASSWORD=x
echo "SELECT 1;" | bash "${WRAPPER}" client mariadb c --batch >/dev/null
grep -q "^mariadb -uroot --batch | MYSQL_PWD=x" "${LOG}" || fail "client argv: $(cat "${LOG}")"
grep -q "stdin:SELECT 1;" "${LOG}" || fail "stdin must reach the client"

# --- 6. PostgreSQL: dump to --file, user default, credential from the container, restore keeps --dbname
reset; export POSTGRES_PASSWORD="pg-pw"; PIPE="${TMP}/pipe3"
bash "${WRAPPER}" dump postgres pgc --no-password --clean --if-exists --format custom --file "${PIPE}" --host h --port 5432 --username u appdb
grep -q "^pg_dump -U postgres --clean --if-exists --format custom appdb | MYSQL_PWD= PGPASSWORD=pg-pw" "${LOG}" || fail "pg_dump argv: $(cat "${LOG}")"
[[ "$(cat "${PIPE}")" == "OUT-pg_dump" ]] || fail "pg_dump output must go to --file"
grep -qF "pg-pw" "${DLOG}" && fail "pg credential in host argv"
reset; export POSTGRES_USER=app POSTGRES_PASSWORD=p
bash "${WRAPPER}" restore postgres pgc --dbname appdb --clean >/dev/null
grep -q "^pg_restore -U app --dbname appdb --clean |" "${LOG}" || fail "pg_restore must keep --dbname: $(cat "${LOG}")"
reset; echo "select 1" | bash "${WRAPPER}" client postgres pgc --dbname appdb >/dev/null
grep -q "^psql -U postgres --dbname appdb |" "${LOG}" || fail "psql: $(cat "${LOG}")"

# --- 7. exit status of the client is the wrapper's exit status
reset; export MYSQL_ROOT_PASSWORD=x FAKE_RC=3
bash "${WRAPPER}" dump mariadb c --databases d >/dev/null; rc=$?
[[ ${rc} -eq 3 ]] || fail "client failure must propagate, rc=${rc}"

# --- 8. bad usage is refused before touching docker
reset
for bad in "bogus mariadb c" "dump oracle c" "dump mariadb c;rm" "dump mariadb" ""; do
    # shellcheck disable=SC2086
    bash "${WRAPPER}" ${bad} >/dev/null 2>&1; rc=$?
    [[ ${rc} -eq 64 ]] || fail "'${bad}' must be a usage error (64), got ${rc}"
done
[[ ! -s "${DLOG}" ]] || fail "docker must not run on a usage error"

echo "borg db_exec wrapper tests passed"
