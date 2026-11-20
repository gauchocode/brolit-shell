#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Tests for the nightly backup of persistent Compose mounts.
#
# A files backup archives the project directory and a database dump covers the
# databases. A named volume, or a bind mount outside the project, is in
# neither (tukiverse.com and tukigrowth.com, 2026-11-19). These tests pin:
#
#   1. Off by default: a server without the config key behaves as before.
#   2. Only the data brolit does not already cover is archived: the data
#      directory of a dumped database, a mount labelled brolit.backup=false, a
#      socket and a mount above the size cap are skipped and recorded.
#   3. Redis and a database's other volumes ARE archived: the shell does not
#      dump them.
#   4. No container is ever stopped, paused or killed.
#   5. A clean tar pass is "consistent"; a store too busy for one is kept and
#      labelled "live"; a real failure leaves no partial archive.
#   6. Each mount has its own remote directory (retention treats a directory
#      as one series), and the manifest says what was archived and what not.
#   7. Failures make the result a failure, and the deletion archive is untouched.
#
# Docker, compression and storage are fakes: no daemon, no host data.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# commons.sh needs a root shell and a configured server; the functions under
# test only need these two files, which define functions and nothing else.
# shellcheck disable=SC1091
source "${TEST_LOADER_DIR}/../libs/local/project_helper.sh"
# shellcheck disable=SC1091
source "${TEST_LOADER_DIR}/../libs/local/backup_helper.sh"

PBM_TMP=""
PBM_FAILED=0
PBM_SAVED_PATH=""
# The suite runs every test in one shell: the fakes below must not outlive this
# test, or they would replace the real compress() and storage controller for the
# tests that run after it.
declare -A PBM_SAVED_FUNCS=()
PBM_FAKED_FUNCS=(log_event display log_subsection backup_get_filename compress storage_create_dir storage_upload_backup storage_delete_old_backups)

function pbm_fail() {
  echo "FAIL: $*"
  PBM_FAILED=1
}

function pbm_hex() {
  # A 64 character container id from a letter.
  printf '%s' "${1}" | head -c1 | awk '{for(i=0;i<64;i++) printf "%s", $0}'
}

function pbm_record() {
  # pbm_record <letter> <project> <image> <optout> <mounts_json>
  local id
  id="$(pbm_hex "${1}")"
  jq -n -c --arg id "${id}" --arg project "${2}" --arg working_dir "${PROJECTS_PATH}/${2}.example.com" \
    --arg image "${3}" --arg optout "${4}" --argjson mounts "${5}" \
    '{id:$id,project:$project,working_dir:$working_dir,config_files:"docker-compose.yml",image:$image,optout:$optout,mounts:$mounts}' \
    >"${FAKE_RECORDS}/${id}.json"
  printf '%s\n' "${id}" >>"${FAKE_IDS}"
}

function pbm_setup() {
  PBM_TMP="$(mktemp -d)"
  PBM_SAVED_PATH="${PATH}"
  local faked
  for faked in "${PBM_FAKED_FUNCS[@]}"; do
    if declare -F "${faked}" >/dev/null; then
      PBM_SAVED_FUNCS["${faked}"]="$(declare -f "${faked}")"
    else
      PBM_SAVED_FUNCS["${faked}"]=""
    fi
  done

  export PROJECTS_PATH="${PBM_TMP}/www"
  export BROLIT_TMP_DIR="${PBM_TMP}/tmp"
  export NOW="2026-11-20"
  export SERVER_NAME="test-server"
  export BACKUP_CONFIG_COMPRESSION_EXTENSION="tar.bz2"
  export BROLIT_MOUNTS_RETRY_SLEEP=0
  export BROLIT_MOUNTS_BACKUP_MAX_MB=1
  export BACKUP_CONFIG_MOUNTS="enabled"
  export FAKE_RECORDS="${PBM_TMP}/records"
  export FAKE_IDS="${PBM_TMP}/ids"
  export FAKE_VOLUME_ROOT="${PBM_TMP}/volumes"
  export FAKE_VOLUMES="${PBM_TMP}/volume-names"
  export FAKE_REMOTE_ROOT="${PBM_TMP}/remote"
  export FAKE_DOCKER_EVENTS="${PBM_TMP}/docker-events"
  export FAKE_COMPRESS_LOG="${PBM_TMP}/compress-log"
  export FAKE_RETENTION_LOG="${PBM_TMP}/retention-log"
  export FAKE_STRICT_FAILS="${PBM_TMP}/strict-fails"
  export FAKE_UPLOAD_FAIL=0
  export FAKE_BROKEN_INSPECT=0
  export FAKE_COMPRESS_ALWAYS_FAIL=0

  mkdir -p "${PROJECTS_PATH}/site.example.com/uploads" "${BROLIT_TMP_DIR}/${NOW}" "${FAKE_RECORDS}" \
    "${FAKE_VOLUME_ROOT}" "${FAKE_REMOTE_ROOT}" "${PBM_TMP}/outside/emdash" "${PBM_TMP}/bin"
  : >"${PROJECTS_PATH}/site.example.com/docker-compose.yml"
  : >"${FAKE_IDS}"
  : >"${FAKE_VOLUMES}"
  : >"${FAKE_DOCKER_EVENTS}"
  : >"${FAKE_COMPRESS_LOG}"
  : >"${FAKE_RETENTION_LOG}"
  printf '0\n' >"${FAKE_STRICT_FAILS}"

  # Contents: a CMS database with its WAL and shared memory index, and volumes.
  printf 'cms\n' >"${PBM_TMP}/outside/emdash/emdash.db"
  printf 'wal\n' >"${PBM_TMP}/outside/emdash/emdash.db-wal"
  printf 'shm\n' >"${PBM_TMP}/outside/emdash/emdash.db-shm"
  local name
  for name in site_data site_db site_redis site_cache site_labeled site_big; do
    mkdir -p "${FAKE_VOLUME_ROOT}/${name}"
    printf 'x\n' >"${FAKE_VOLUME_ROOT}/${name}/file"
    printf '%s\n' "${name}" >>"${FAKE_VOLUMES}"
  done
  head -c 2097152 /dev/zero >"${FAKE_VOLUME_ROOT}/site_big/big.bin"
  printf 'false\n' >"${FAKE_VOLUME_ROOT}/site_labeled.label"

  cat >"${PBM_TMP}/bin/docker" <<'FAKE'
#!/usr/bin/env bash
case "${1:-}" in
  ps)
    [[ "${FAKE_BROKEN_INSPECT}" == "1" ]] && exit 1
    cat "${FAKE_IDS}"
    ;;
  inspect)
    [[ "${FAKE_BROKEN_INSPECT}" == "1" ]] && exit 1
    for last in "$@"; do :; done
    cat "${FAKE_RECORDS}/${last}.json"
    ;;
  volume)
    case "${2:-}" in
      ls)
        for arg in "$@"; do [[ "${arg}" == label=* ]] && exit 0; done
        cat "${FAKE_VOLUMES}"
        ;;
      inspect)
        name="${@: -1}"
        case "$*" in
          *Mountpoint*) printf '%s\n' "${FAKE_VOLUME_ROOT}/${name}" ;;
          *Labels*) [[ -f "${FAKE_VOLUME_ROOT}/${name}.label" ]] && cat "${FAKE_VOLUME_ROOT}/${name}.label" || true ;;
        esac
        ;;
    esac
    ;;
  *)
    # Anything else (stop, pause, kill, rm, compose...) is recorded: the
    # nightly step must never run any of them.
    printf '%s\n' "$*" >>"${FAKE_DOCKER_EVENTS}"
    ;;
esac
exit 0
FAKE
  chmod +x "${PBM_TMP}/bin/docker"
  PATH="${PBM_TMP}/bin:${PATH}"

  function log_event() { :; }
  function display() { :; }
  function log_subsection() { :; }
  function backup_get_filename() { printf '%s_%s.%s\n' "${1}" "${NOW}" "${2}"; }
  function compress() {
    local source="${2}" output="${3}"
    shift 3
    printf 'strict=%s source=%s excludes=%s\n' "${BROLIT_STRICT_TAR:-0}" "${source}" "$*" >>"${FAKE_COMPRESS_LOG}"
    if [[ "${FAKE_COMPRESS_ALWAYS_FAIL}" == "1" ]]; then
      printf 'partial' >"${output}"
      return 1
    fi
    if [[ "${BROLIT_STRICT_TAR:-0}" == "1" ]]; then
      local fails
      fails="$(cat "${FAKE_STRICT_FAILS}")"
      if [[ "${fails}" == "always" ]]; then
        printf 'partial' >"${output}"
        return 1
      elif [[ "${fails}" -gt 0 ]]; then
        printf '%s\n' "$((fails - 1))" >"${FAKE_STRICT_FAILS}"
        printf 'partial' >"${output}"
        return 1
      fi
    fi
    printf 'archive-of=%s\n' "${source}" >"${output}"
    printf '1KiB\n'
  }
  function storage_create_dir() { mkdir -p "${FAKE_REMOTE_ROOT}/${1}"; }
  function storage_upload_backup() {
    [[ "${FAKE_UPLOAD_FAIL}" == "1" ]] && return 1
    mkdir -p "${FAKE_REMOTE_ROOT}/${2}"
    cp "${1}" "${FAKE_REMOTE_ROOT}/${2}/$(basename -- "${1}")"
  }
  function storage_delete_old_backups() { printf '%s\n' "${1}" >>"${FAKE_RETENTION_LOG}"; }
}

function pbm_teardown() {
  PATH="${PBM_SAVED_PATH}"
  local faked
  for faked in "${PBM_FAKED_FUNCS[@]}"; do
    if [[ -n "${PBM_SAVED_FUNCS[${faked}]:-}" ]]; then
      eval "${PBM_SAVED_FUNCS[${faked}]}"
    else
      unset -f "${faked}"
    fi
  done
  [[ -n "${PBM_SOCKET_PID:-}" ]] && kill "${PBM_SOCKET_PID}" 2>/dev/null
  PBM_SOCKET_PID=""
  rm -rf -- "${PBM_TMP}"
  unset BACKUP_CONFIG_MOUNTS FAKE_BROKEN_INSPECT FAKE_UPLOAD_FAIL FAKE_COMPRESS_ALWAYS_FAIL BROLIT_MOUNTS_BACKUP_MAX_MB
}

# The scenario: one app container with an in-project bind (covered), an
# emdash-style bind outside the project, a named volume and a socket; a
# database; a Redis; a helper that opts out; a labelled volume; a big volume.
function pbm_scenario() {
  python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); time.sleep(30)' "${PBM_TMP}/docker.sock" &
  PBM_SOCKET_PID=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -S "${PBM_TMP}/docker.sock" ]] && break; sleep 0.1; done

  local proj="${PROJECTS_PATH}/site.example.com"
  pbm_record a site "site-app:local" "" "$(jq -n -c \
    --arg inside "${proj}/uploads" --arg outside "${PBM_TMP}/outside/emdash" --arg sock "${PBM_TMP}/docker.sock" \
    --arg data "${FAKE_VOLUME_ROOT}/site_data" --arg big "${FAKE_VOLUME_ROOT}/site_big" --arg lab "${FAKE_VOLUME_ROOT}/site_labeled" \
    '[{Type:"bind",Source:$inside,Destination:"/app/uploads"},
      {Type:"bind",Source:$outside,Destination:"/data"},
      {Type:"bind",Source:$sock,Destination:"/var/run/docker.sock"},
      {Type:"volume",Name:"site_data",Source:$data,Destination:"/var/lib/app"},
      {Type:"volume",Name:"site_big",Source:$big,Destination:"/var/lib/big"},
      {Type:"volume",Name:"site_labeled",Source:$lab,Destination:"/var/lib/labeled"}]')"
  pbm_record b site "mariadb:10.6" "" "$(jq -n -c --arg v "${FAKE_VOLUME_ROOT}/site_db" \
    '[{Type:"volume",Name:"site_db",Source:$v,Destination:"/var/lib/mysql"}]')"
  pbm_record c site "redis:7-alpine" "" "$(jq -n -c --arg v "${FAKE_VOLUME_ROOT}/site_redis" \
    '[{Type:"volume",Name:"site_redis",Source:$v,Destination:"/data"}]')"
  pbm_record d site "worker:local" "false" "$(jq -n -c --arg v "${FAKE_VOLUME_ROOT}/site_cache" \
    '[{Type:"volume",Name:"site_cache",Source:$v,Destination:"/var/cache/worker"}]')"
}

function pbm_remote_root() {
  printf '%s' "${FAKE_REMOTE_ROOT}/${SERVER_NAME}/projects-online/site-mounts-daily/site.example.com"
}

function pbm_manifest() {
  find "$(pbm_remote_root)/manifest" -type f -name '*.json' 2>/dev/null | head -1
}

function test_dumped_database_rule() {
  local row expected image destination
  # image | destination | expected (0 = dumped, covered by a dump)
  while IFS='|' read -r image destination expected; do
    project_compose_is_dumped_database_mount "${image}" "${destination}"
    [[ $? -eq ${expected} ]] || pbm_fail "dumped database rule: ${image} ${destination} expected ${expected}"
  done <<'TABLE'
mariadb:10.11|/var/lib/mysql|0
mysql:8.0|/var/lib/mysql/data|0
postgres:17-alpine|/var/lib/postgresql/data|0
postgres:18-alpine|/var/lib/postgresql|0
supabase/postgres:17.6.1.083|/var/lib/postgresql/data|0
timescale/timescaledb:2|/var/lib/postgresql/data|0
registry.example.com/team/Postgres:16|/var/lib/postgresql/data|0
redis:7-alpine|/data|1
valkey/valkey:8-alpine|/data|1
mongo:7|/data/db|1
supabase/postgres:15.8|/etc/postgresql-custom|1
mariadb:10|/var/lib/postgresql/data|1
mysql:8|/etc/mysql|1
nginx:alpine|/var/lib/mysql|1
|/var/lib/mysql|1
TABLE
  project_compose_is_dumped_database_mount "mysql:8" "" && pbm_fail "empty destination accepted"
}

function test_flag_off_by_default() {
  pbm_setup
  pbm_scenario
  unset BACKUP_CONFIG_MOUNTS
  project_compose_mounts_backup_enabled && pbm_fail "mounts backup enabled without the config key"
  BACKUP_CONFIG_MOUNTS="disabled" project_compose_mounts_backup_enabled && pbm_fail "mounts backup enabled when disabled"
  BACKUP_CONFIG_MOUNTS="" project_compose_mounts_backup_enabled && pbm_fail "mounts backup enabled with an empty value"
  BACKUP_CONFIG_MOUNTS="enabled" project_compose_mounts_backup_enabled || pbm_fail "mounts backup not enabled when enabled"

  project_compose_backup_mounts "site.example.com"
  [[ $? -eq 0 ]] || pbm_fail "disabled backup did not return 0"
  [[ -z "$(find "${FAKE_REMOTE_ROOT}" -type f 2>/dev/null)" ]] || pbm_fail "disabled backup uploaded something"
  [[ ! -s "${FAKE_COMPRESS_LOG}" ]] || pbm_fail "disabled backup archived something"
  pbm_teardown
}

function test_full_scenario() {
  pbm_setup
  pbm_scenario

  project_compose_backup_mounts "site.example.com"
  local rc=$?
  [[ ${rc} -eq 0 ]] || pbm_fail "scenario: expected 0, got ${rc}"

  local root manifest
  root="$(pbm_remote_root)"
  manifest="$(pbm_manifest)"
  [[ -n "${manifest}" && -f "${manifest}" ]] || { pbm_fail "scenario: no manifest uploaded"; pbm_teardown; return; }

  # Archived: the CMS bind, the app volume and Redis. Nothing else.
  [[ "$(jq '.items | length' "${manifest}")" -eq 3 ]] || pbm_fail "scenario: expected 3 archived mounts, got $(jq '.items | length' "${manifest}")"
  local sources
  sources="$(jq -r '.items[].source' "${manifest}" | sort | tr '\n' ' ')"
  [[ "${sources}" == *"${PBM_TMP}/outside/emdash"* ]] || pbm_fail "scenario: the bind outside the project was not archived"
  [[ "${sources}" == *"site_data"* ]] || pbm_fail "scenario: the named volume was not archived"
  [[ "${sources}" == *"site_redis"* ]] || pbm_fail "scenario: Redis data was not archived (the shell does not dump it)"

  # Skipped, each with its reason.
  local reasons
  reasons="$(jq -r '.skipped[].reason' "${manifest}" | sort | tr '\n' ' ')"
  [[ "${reasons}" == "database_dump opted_out opted_out socket too_large " ]] || pbm_fail "scenario: skipped reasons were: ${reasons}"
  [[ "$(jq -r '.skipped[] | select(.reason=="database_dump") | .source' "${manifest}")" == "site_db" ]] || pbm_fail "scenario: the dumped database volume was not the one skipped"

  # Manifest metadata and per-archive evidence.
  [[ "$(jq -r '.schema_version' "${manifest}")" == "1" ]] || pbm_fail "scenario: manifest schema version"
  [[ "$(jq -r '.domain' "${manifest}")" == "site.example.com" ]] || pbm_fail "scenario: manifest domain"
  [[ "$(jq -r '.failures' "${manifest}")" == "0" ]] || pbm_fail "scenario: manifest failures"
  local item remote_path expected_hash actual_hash
  while IFS= read -r item; do
    remote_path="${FAKE_REMOTE_ROOT}/$(printf '%s' "${item}" | jq -r '.remote')"
    [[ -f "${remote_path}" ]] || { pbm_fail "scenario: remote archive missing: ${remote_path}"; continue; }
    expected_hash="$(printf '%s' "${item}" | jq -r '.sha256')"
    actual_hash="$(sha256sum "${remote_path}" | awk '{print $1}')"
    [[ "${expected_hash}" == "${actual_hash}" ]] || pbm_fail "scenario: manifest checksum does not match the uploaded archive"
    [[ "$(printf '%s' "${item}" | jq -r '.consistency')" == "consistent" ]] || pbm_fail "scenario: a clean pass was not labelled consistent"
    [[ "$(printf '%s' "${item}" | jq -r '.attempts')" == "1" ]] || pbm_fail "scenario: a clean pass should take one attempt"
  done < <(jq -c '.items[]' "${manifest}")

  # One remote directory per mount, and one for the manifest: retention keeps
  # the newest N files of a directory as a whole.
  local dirs
  dirs="$(find "${root}" -type f ! -path "${root}/manifest/*" -printf '%h\n' | sort -u | wc -l)"
  [[ "${dirs}" -eq 3 ]] || pbm_fail "scenario: expected 3 distinct mount directories, got ${dirs}"
  [[ "$(sort "${FAKE_RETENTION_LOG}" | uniq -d | wc -l)" -eq 0 ]] || pbm_fail "scenario: retention ran twice on one directory"
  [[ "$(grep -c . "${FAKE_RETENTION_LOG}")" -eq 4 ]] || pbm_fail "scenario: retention should run on 3 mount directories and the manifest"
  grep -q "/manifest$" "${FAKE_RETENTION_LOG}" || pbm_fail "scenario: retention did not run on the manifest directory"

  # SQLite's shared memory index is excluded, and every pass was strict first.
  grep -q -- "--exclude=\*.db-shm" "${FAKE_COMPRESS_LOG}" || pbm_fail "scenario: the -shm index was not excluded"
  [[ "$(grep -c "strict=0" "${FAKE_COMPRESS_LOG}")" -eq 0 ]] || pbm_fail "scenario: a tolerant pass ran although the strict one succeeded"

  # The deletion path's directory is never used, and no container was touched.
  [[ ! -d "${FAKE_REMOTE_ROOT}/${SERVER_NAME}/projects-online/site-mounts" ]] || pbm_fail "scenario: the deletion archive directory was used"
  [[ ! -s "${FAKE_DOCKER_EVENTS}" ]] || pbm_fail "scenario: a container was touched: $(cat "${FAKE_DOCKER_EVENTS}")"
  [[ ! -d "${BROLIT_TMP_DIR}/${NOW}/mounts-daily-site.example.com" ]] || pbm_fail "scenario: the work directory was left behind"
  pbm_teardown
}

function test_busy_store_is_kept_and_labelled_live() {
  pbm_setup
  pbm_scenario
  printf 'always\n' >"${FAKE_STRICT_FAILS}"

  project_compose_backup_mounts "site.example.com"
  [[ $? -eq 0 ]] || pbm_fail "busy store: a store too busy for a clean pass must not fail the backup"
  local manifest
  manifest="$(pbm_manifest)"
  [[ "$(jq '.items | length' "${manifest}")" -eq 3 ]] || pbm_fail "busy store: the archives were not kept"
  [[ "$(jq -r '.items[].consistency' "${manifest}" | sort -u)" == "live" ]] || pbm_fail "busy store: not labelled live"
  [[ "$(jq -r '.items[].attempts' "${manifest}" | sort -u)" == "4" ]] || pbm_fail "busy store: expected three strict passes and one tolerant pass"
  pbm_teardown
}

function test_snapshot_retries() {
  pbm_setup
  local out archive="${PBM_TMP}/snap.tar.bz2"

  # A change on the first two passes, a clean third: consistent, three attempts.
  printf '2\n' >"${FAKE_STRICT_FAILS}"
  out="$(project_compose_archive_mount_snapshot "/srv/data" "${archive}")"
  [[ $? -eq 0 && "${out}" == "1KiB|consistent|3" ]] || pbm_fail "snapshot: expected consistent on attempt 3, got ${out}"
  [[ -s "${archive}" && "$(cat "${archive}")" != "partial" ]] || pbm_fail "snapshot: the partial archive of a failed pass was kept"
  rm -f "${archive}"

  # A real failure on every pass, including the tolerant one: no file left.
  FAKE_COMPRESS_ALWAYS_FAIL=1
  : >"${FAKE_COMPRESS_LOG}"
  out="$(project_compose_archive_mount_snapshot "/srv/data" "${archive}")"
  [[ $? -ne 0 ]] || pbm_fail "snapshot: a real failure was reported as success"
  [[ ! -e "${archive}" ]] || pbm_fail "snapshot: a failed archive left a partial file"
  [[ "$(wc -l <"${FAKE_COMPRESS_LOG}")" -eq 4 ]] || pbm_fail "snapshot: expected three strict passes and one tolerant pass"
  FAKE_COMPRESS_ALWAYS_FAIL=0

  # The attempt count is configurable and never below one.
  printf '0\n' >"${FAKE_STRICT_FAILS}"
  out="$(BROLIT_MOUNTS_BACKUP_ATTEMPTS=0 project_compose_archive_mount_snapshot "/srv/data" "${archive}")"
  [[ "${out}" == "1KiB|consistent|1" ]] || pbm_fail "snapshot: an invalid attempt count was not defaulted, got ${out}"

  # Refuses a relative path or the filesystem root.
  project_compose_archive_mount_snapshot "relative" "${archive}" >/dev/null && pbm_fail "snapshot: a relative path was accepted"
  project_compose_archive_mount_snapshot "/" "${archive}" >/dev/null && pbm_fail "snapshot: the filesystem root was accepted"
  pbm_teardown
}

function test_failures_make_the_result_a_failure() {
  pbm_setup
  pbm_scenario

  # Every upload fails: the step fails, and still runs retention.
  FAKE_UPLOAD_FAIL=1
  project_compose_backup_mounts "site.example.com"
  [[ $? -ne 0 ]] || pbm_fail "failure: failed uploads were reported as success"
  [[ "$(grep -c . "${FAKE_RETENTION_LOG}")" -ge 3 ]] || pbm_fail "failure: retention must still run after a failed upload"
  [[ ! -d "${BROLIT_TMP_DIR}/${NOW}/mounts-daily-site.example.com" ]] || pbm_fail "failure: the work directory was left behind"
  FAKE_UPLOAD_FAIL=0

  # A real archive failure.
  : >"${FAKE_RETENTION_LOG}"
  FAKE_COMPRESS_ALWAYS_FAIL=1
  project_compose_backup_mounts "site.example.com"
  [[ $? -ne 0 ]] || pbm_fail "failure: failed archives were reported as success"
  FAKE_COMPRESS_ALWAYS_FAIL=0

  # Coverage that cannot be established: nothing is archived, and it is a failure.
  rm -rf "${FAKE_REMOTE_ROOT:?}"/*
  FAKE_BROKEN_INSPECT=1
  project_compose_backup_mounts "site.example.com"
  [[ $? -ne 0 ]] || pbm_fail "failure: an unverifiable coverage was reported as success"
  [[ -z "$(find "${FAKE_REMOTE_ROOT}" -type f)" ]] || pbm_fail "failure: something was uploaded without verified coverage"
  FAKE_BROKEN_INSPECT=0
  pbm_teardown
}

function test_nothing_to_back_up() {
  pbm_setup
  # Only a bind inside the project: covered by the files backup, nothing to do.
  pbm_record a site "site-app:local" "" "$(jq -n -c --arg inside "${PROJECTS_PATH}/site.example.com/uploads" \
    '[{Type:"bind",Source:$inside,Destination:"/app/uploads"}]')"
  : >"${FAKE_VOLUMES}"
  project_compose_backup_mounts "site.example.com"
  [[ $? -eq 0 ]] || pbm_fail "nothing: expected 0"
  [[ -z "$(find "${FAKE_REMOTE_ROOT}" -type f)" ]] || pbm_fail "nothing: uploaded although nothing was uncovered"
  [[ ! -s "${FAKE_COMPRESS_LOG}" ]] || pbm_fail "nothing: archived although nothing was uncovered"
  pbm_teardown
}

function test_nightly_pass_over_all_projects() {
  pbm_setup
  pbm_scenario
  mkdir -p "${PROJECTS_PATH}/plain.example.com"

  local saved_dirs saved_ignored saved_type
  saved_dirs="$(declare -f get_all_directories)"
  saved_ignored="$(declare -f project_is_ignored)"
  saved_type="$(declare -f project_get_install_type)"
  function get_all_directories() { printf '%s\n%s\n' "${PROJECTS_PATH}/site.example.com" "${PROJECTS_PATH}/plain.example.com"; }
  function project_is_ignored() { echo "false"; }
  function project_get_install_type() {
    case "${1}" in
      */site.example.com) echo "docker-compose" ;;
      *) echo "default" ;;
    esac
  }

  BACKUP_FILES_MAIL_ERRORS=()
  backup_all_projects_mounts
  [[ $? -eq 0 ]] || pbm_fail "nightly pass: expected 0"
  [[ -d "$(pbm_remote_root)" ]] || pbm_fail "nightly pass: the docker project was not processed"
  [[ ! -d "${FAKE_REMOTE_ROOT}/${SERVER_NAME}/projects-online/site-mounts-daily/plain.example.com" ]] || pbm_fail "nightly pass: a non-docker project was processed"
  [[ ${#BACKUP_FILES_MAIL_ERRORS[@]} -eq 0 ]] || pbm_fail "nightly pass: errors reported on success"

  # A failing project is reported in the files section and in the exit status.
  FAKE_UPLOAD_FAIL=1
  backup_all_projects_mounts
  [[ $? -ne 0 ]] || pbm_fail "nightly pass: a failure was not reported in the exit status"
  [[ "${BACKUP_FILES_MAIL_ERRORS[*]}" == *"site.example.com (mounts)"* ]] || pbm_fail "nightly pass: the failure was not listed in the report"
  FAKE_UPLOAD_FAIL=0

  # Off: the whole pass is a no-op.
  : >"${FAKE_COMPRESS_LOG}"
  BACKUP_CONFIG_MOUNTS="disabled"
  backup_all_projects_mounts
  [[ $? -eq 0 && ! -s "${FAKE_COMPRESS_LOG}" ]] || pbm_fail "nightly pass: ran while disabled"

  eval "${saved_dirs}"
  eval "${saved_ignored}"
  eval "${saved_type}"
  pbm_teardown
}

function test_fakes_do_not_leak() {
  local before after
  before="$(declare -f compress; declare -f log_event; declare -f storage_upload_backup)"
  pbm_setup
  pbm_teardown
  after="$(declare -f compress; declare -f log_event; declare -f storage_upload_backup)"
  [[ "${before}" == "${after}" ]] || pbm_fail "the test fakes leaked into the shell"
  [[ ":${PATH}:" != *":${PBM_TMP}/bin:"* ]] || pbm_fail "the fake docker leaked into PATH"
}

function test_backup_project_mounts() {
  PBM_FAILED=0

  test_dumped_database_rule
  test_flag_off_by_default
  test_full_scenario
  test_busy_store_is_kept_and_labelled_live
  test_snapshot_retries
  test_failures_make_the_result_a_failure
  test_nothing_to_back_up
  test_nightly_pass_over_all_projects
  test_fakes_do_not_leak

  if [[ ${PBM_FAILED} -eq 0 ]]; then
    echo "ok: backup project mounts"
  fi
  return ${PBM_FAILED}
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_backup_project_mounts
fi
