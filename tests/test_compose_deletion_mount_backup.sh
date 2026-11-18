#!/usr/bin/env bash
# Tests for deletion-time backups of uncovered Compose mounts. All Docker,
# compression and storage operations are fakes; no host data is touched.

source "$(dirname "${BASH_SOURCE[0]}")/../libs/local/project_helper.sh"

function test_compose_deletion_mount_backup() {
  local tmp failed=0 receipt rc saved_path="${PATH}"
  tmp="$(mktemp -d)"

  export PROJECTS_PATH="${tmp}/www"
  export BROLIT_TMP_DIR="${tmp}/tmp"
  export NOW="2026-11-18"
  export SERVER_NAME="fixture-server"
  export BACKUP_CONFIG_COMPRESSION_EXTENSION="tar.bz2"
  export FAKE_VOLUME_ROOT="${tmp}/volumes"
  export FAKE_REMOTE_ROOT="${tmp}/remote"
  export FAKE_DOCKER_EVENTS="${tmp}/docker-events"
  export FAKE_COMPRESS_SOURCES="${tmp}/compress-sources"
  mkdir -p "${PROJECTS_PATH}/site.example.com" "${BROLIT_TMP_DIR}/${NOW}" \
    "${FAKE_VOLUME_ROOT}/real-services_db-config" "${FAKE_VOLUME_ROOT}/real-services_deno-cache" \
    "${tmp}/outside:colon" "${FAKE_REMOTE_ROOT}"
  printf 'db config\n' > "${FAKE_VOLUME_ROOT}/real-services_db-config/postgresql.conf"
  printf 'cache\n' > "${FAKE_VOLUME_ROOT}/real-services_deno-cache/cache.dat"
  printf 'bind data\n' > "${tmp}/outside:colon/data.txt"
  : > "${PROJECTS_PATH}/site.example.com/docker-compose.yml"
  printf 'COMPOSE_PROJECT_NAME=real-services\n' > "${PROJECTS_PATH}/site.example.com/.env"
  : > "${FAKE_DOCKER_EVENTS}"

  mkdir -p "${tmp}/bin"
  cat > "${tmp}/bin/docker" <<'FAKE'
#!/usr/bin/env bash
if [[ "${1:-}" == "ps" ]]; then
  exit 0
fi
if [[ "${1:-}" == "volume" && "${2:-}" == "ls" ]]; then
  printf 'real-services_db-config\nreal-services_deno-cache\n'
  exit 0
fi
if [[ "${1:-}" == "volume" && "${2:-}" == "inspect" ]]; then
  printf '%s\n' "${FAKE_VOLUME_ROOT}/${5}"
  exit 0
fi
if [[ "${1:-}" == "compose" ]]; then
  for last in "$@"; do :; done
  printf '%s\n' "${last}" >> "${FAKE_DOCKER_EVENTS}"
  exit 0
fi
if [[ "${1:-}" == "volume" && "${2:-}" == "rm" ]]; then
  [[ "${FAKE_RM_FAIL:-}" == "${4}" ]] && exit 1
  printf 'rm:%s\n' "${4}" >> "${FAKE_DOCKER_EVENTS}"
  exit 0
fi
exit 0
FAKE
  chmod +x "${tmp}/bin/docker"
  PATH="${tmp}/bin:${PATH}"

  function log_event() { :; }
  function display() { :; }
  function backup_get_filename() { printf '%s_%s.%s\n' "${1}" "${NOW}" "${2}"; }
  function compress() {
    local source="${2}" output="${3}"
    printf '%s\n' "${source}" >> "${FAKE_COMPRESS_SOURCES}"
    printf 'source=%s\n' "${source}" > "${output}"
    printf '1KiB\n'
  }
  function storage_upload_backup() {
    local file="${1}" directory="${2}"
    [[ "${FAKE_UPLOAD_FAIL:-0}" == "1" ]] && return 1
    mkdir -p "${FAKE_REMOTE_ROOT}/${directory}"
    cp "${file}" "${FAKE_REMOTE_ROOT}/${directory}/$(basename -- "${file}")"
  }
  function storage_download_backup() {
    local remote="${1}" directory="${2}"
    mkdir -p "${directory}"
    cp "${FAKE_REMOTE_ROOT}/${remote}" "${directory}/$(basename -- "${remote}")"
    if [[ "${FAKE_CORRUPT_DOWNLOAD:-0}" == "1" ]]; then
      printf 'corrupted\n' >> "${directory}/$(basename -- "${remote}")"
    fi
  }

  # A real Unix socket proves it is skipped as IPC, not archived as file data.
  python3 -c 'import socket,sys,time; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1]); time.sleep(30)' "${tmp}/docker.sock" &
  local socket_pid=$!
  for _ in 1 2 3 4 5; do [[ -S "${tmp}/docker.sock" ]] && break; done

  local gate_output
  gate_output="$({
    jq -n -c '{kind:"volume",source:"real-services_db-config",destination:"/etc/postgresql-custom"}'
    # The same identity reported under another gate kind must be deduplicated.
    jq -n -c '{kind:"volume-namespace",source:"real-services_db-config",destination:"docker-volume"}'
    jq -n -c '{kind:"volume",source:"real-services_deno-cache",destination:"/root/.cache/deno"}'
    jq -n -c --arg source "${tmp}/outside:colon" '{kind:"bind",source:$source,destination:"/data"}'
    jq -n -c --arg source "${tmp}/docker.sock" '{kind:"bind",source:$source,destination:"/var/run/docker.sock"}'
  })"

  receipt="$(project_compose_archive_deletion_mounts "site.example.com" "${gate_output}")"
  rc=$?
  if [[ ${rc} -ne 0 || -z "${receipt}" || ! -f "${receipt}" ]]; then
    echo "FAIL: mount archive did not produce a receipt"; failed=1
  else
    if [[ "$(wc -l < "${receipt}")" -ne 3 ]]; then
      echo "FAIL: expected two volumes and one colon-containing bind in the receipt"; failed=1
    fi
    if [[ "$(jq -r 'select(.kind == "volume") | .source' "${receipt}" | sort -u | wc -l)" -ne 2 ]]; then
      echo "FAIL: duplicate volume identity was not deduplicated"; failed=1
    fi
    if ! jq -e --arg source "${tmp}/outside:colon" 'select(.kind == "bind" and .source == $source)' "${receipt}" >/dev/null; then
      echo "FAIL: colon-containing bind source was not preserved"; failed=1
    fi
    if grep -q 'docker.sock' "${receipt}"; then
      echo "FAIL: socket was archived as if it held file data"; failed=1
    fi
  fi
  if [[ "$(cat "${FAKE_DOCKER_EVENTS}")" != "stop" ]]; then
    echo "FAIL: archive phase should stop, but never down/remove, the project"; failed=1
  fi
  if [[ "$(find "${FAKE_REMOTE_ROOT}" -type f -name '*mount-*' | wc -l)" -ne 3 ]]; then
    echo "FAIL: expected three distinct remote mount archives"; failed=1
  fi

  # Finalization verifies the remote bytes again and only then removes volumes.
  if ! project_compose_finalize_archived_deletion_mounts "site.example.com" "${receipt}"; then
    echo "FAIL: verified finalization failed"; failed=1
  fi
  if [[ "$(grep -c '^down$' "${FAKE_DOCKER_EVENTS}")" -ne 1 ]]; then
    echo "FAIL: finalization did not stop the Compose project exactly once"; failed=1
  fi
  for name in real-services_db-config real-services_deno-cache; do
    if [[ "$(grep -c "^rm:${name}$" "${FAKE_DOCKER_EVENTS}")" -ne 1 ]]; then
      echo "FAIL: backed-up volume was not removed exactly once: ${name}"; failed=1
    fi
  done
  if [[ ! -f "${tmp}/outside:colon/data.txt" ]]; then
    echo "FAIL: external bind content was deleted"; failed=1
  fi

  # The volume name is identity, not a host path. compress must receive the
  # inspected mountpoint, never /real-services_db-config or another /data.
  if ! grep -Fxq "${FAKE_VOLUME_ROOT#/}/real-services_db-config" "${FAKE_COMPRESS_SOURCES}"; then
    echo "FAIL: volume archive did not read the inspected mountpoint"; failed=1
  fi
  if grep -Fxq 'real-services_db-config' "${FAKE_COMPRESS_SOURCES}"; then
    echo "FAIL: volume name was used as a host path"; failed=1
  fi

  # Feed the actual gate's JSON output directly into the archive helper: this
  # catches pretty-printed/multi-line output and any schema drift.
  : > "${FAKE_DOCKER_EVENTS}"
  local actual_gate actual_gate_rc actual_receipt
  actual_gate="$(project_compose_mount_coverage "${PROJECTS_PATH}/site.example.com" json)"
  actual_gate_rc=$?
  if [[ ${actual_gate_rc} -ne 1 ]]; then
    echo "FAIL: expected the real gate to find fixture volumes"; failed=1
  fi
  while IFS= read -r line; do
    if ! printf '%s' "${line}" | jq -e 'type == "object" and (keys == ["destination","kind","source"])' >/dev/null; then
      echo "FAIL: gate JSON output is not JSONL: ${line}"; failed=1
    fi
  done <<< "${actual_gate}"
  actual_receipt="$(project_compose_archive_deletion_mounts "site.example.com" "${actual_gate}")"
  if [[ $? -ne 0 || -z "${actual_receipt}" ]]; then
    echo "FAIL: actual gate JSON could not be archived"; failed=1
  fi
  project_compose_abort_archived_deletion_mounts "site.example.com" "${actual_receipt}"
  if ! grep -q '^start$' "${FAKE_DOCKER_EVENTS}"; then
    echo "FAIL: abort did not restart the project after gate integration"; failed=1
  fi

  # Upload failure: stop is rolled back with start; nothing is removed and local
  # large artifacts are cleaned.
  : > "${FAKE_DOCKER_EVENTS}"
  FAKE_UPLOAD_FAIL=1 project_compose_archive_deletion_mounts "site.example.com" "${gate_output}" >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo "FAIL: failed upload was accepted"; failed=1
  fi
  if [[ "$(cat "${FAKE_DOCKER_EVENTS}")" != $'stop\nstart' ]]; then
    echo "FAIL: failed upload did not restore the stopped project"; failed=1
  fi
  if [[ -d "${BROLIT_TMP_DIR}/${NOW}/mounts-site.example.com" ]]; then
    echo "FAIL: failed upload left local mount archives behind"; failed=1
  fi
  unset FAKE_UPLOAD_FAIL

  FAKE_CORRUPT_DOWNLOAD=1 project_compose_archive_deletion_mounts "site.example.com" "${gate_output}" >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    echo "FAIL: checksum mismatch was accepted"; failed=1
  fi
  unset FAKE_CORRUPT_DOWNLOAD

  # Changing only the source must not let a valid archive authorize deleting a
  # different volume. It fails before down and restarts the stopped project.
  receipt="$(project_compose_archive_deletion_mounts "site.example.com" "${gate_output}")"
  : > "${FAKE_DOCKER_EVENTS}"
  python3 - "${receipt}" <<'PY'
import json,sys
p=sys.argv[1]
rows=[json.loads(line) for line in open(p) if line.strip()]
rows[0]['source']='other-volume'
with open(p,'w') as f:
    for row in rows: f.write(json.dumps(row)+'\n')
PY
  if project_compose_finalize_archived_deletion_mounts "site.example.com" "${receipt}"; then
    echo "FAIL: source-tampered receipt was accepted"; failed=1
  fi
  if grep -qE '^(down|rm:)' "${FAKE_DOCKER_EVENTS}"; then
    echo "FAIL: source tampering reached destructive steps"; failed=1
  fi
  if ! grep -q '^start$' "${FAKE_DOCKER_EVENTS}"; then
    echo "FAIL: pre-down verification failure did not restart the project"; failed=1
  fi

  # A receipt outside the expected workdir must never make cleanup delete its
  # parent. Derive cleanup from the project, not from caller-supplied dirname.
  mkdir -p "${tmp}/unrelated"
  printf 'keep\n' > "${tmp}/unrelated/sentinel"
  if project_compose_finalize_archived_deletion_mounts "site.example.com" "${tmp}/unrelated/missing-receipt"; then
    echo "FAIL: external invalid receipt was accepted"; failed=1
  fi
  if [[ ! -f "${tmp}/unrelated/sentinel" ]]; then
    echo "FAIL: finalization deleted an unrelated receipt parent"; failed=1
  fi

  # A removal failure is not reported as success.
  receipt="$(project_compose_archive_deletion_mounts "site.example.com" "${gate_output}")"
  if FAKE_RM_FAIL=real-services_db-config project_compose_finalize_archived_deletion_mounts "site.example.com" "${receipt}"; then
    echo "FAIL: volume removal failure was accepted"; failed=1
  fi
  unset FAKE_RM_FAIL

  kill "${socket_pid}" >/dev/null 2>&1 || true
  test_compose_deletion_orchestration || failed=1
  rm -rf -- "${tmp}"
  PATH="${saved_path}"
  return "${failed}"
}

# Orchestration runs in a subshell so its stubs cannot leak into the suite.
function test_compose_deletion_orchestration() (
  local tmp events receipt
  tmp="$(mktemp -d)"
  events="${tmp}/events"
  : > "${events}"
  PROJECTS_PATH="${tmp}/www"
  BROLIT_TMP_DIR="${tmp}/tmp"
  NOW="2026-11-18"
  SERVER_NAME="fixture-server"
  SUPPORT_CLOUDFLARE_STATUS="disabled"
  mkdir -p "${PROJECTS_PATH}/site.example.com" "${BROLIT_TMP_DIR}/${NOW}"

  function log_event() { :; }
  function log_section() { :; }
  function log_subsection() { :; }
  function display() { :; }
  function clear_previous_lines() { :; }
  function project_get_type() { printf 'other\n'; }
  function project_get_install_type() { printf 'docker-compose\n'; }
  function project_compose_deletion_safe() {
    printf '{"kind":"volume","source":"db-config","destination":"/data"}\n'
    return 1
  }
  function project_get_configured_database() { :; }
  function project_get_configured_database_user() { :; }
  function project_get_configured_database_engine() { :; }
  function database_ask_engine() { :; }
  function send_notification() { :; }
  function mail_send_notification() { :; }
  function project_compose_archive_deletion_mounts() {
    printf 'archive\n' >> "${events}"
    receipt="$(mktemp "${tmp}/receipt.XXXXXX")"
    printf '%s\n' "${receipt}"
  }
  function backup_project() {
    printf 'backup\n' >> "${events}"
    [[ "${BACKUP_FAIL:-0}" == "1" ]] && return 1
    return 0
  }
  function project_compose_finalize_archived_deletion_mounts() { printf 'finalize\n' >> "${events}"; }
  function project_compose_abort_archived_deletion_mounts() { printf 'abort\n' >> "${events}"; }
  function project_delete_files() { printf 'delete\n' >> "${events}"; }
  function nginx_server_delete() { :; }
  function certbot_certificate_delete() { :; }

  if ! project_delete "site.example.com" true; then
    echo "FAIL: orchestrated deletion failed"; return 1
  fi
  if [[ "$(cat "${events}")" != $'archive\nbackup\nfinalize\ndelete' ]]; then
    echo "FAIL: deletion order was not archive/backup/finalize/delete"; return 1
  fi

  : > "${events}"
  if BACKUP_FAIL=1 project_delete "site.example.com" true; then
    echo "FAIL: backup failure was accepted"; return 1
  fi
  if [[ "$(cat "${events}")" != $'archive\nbackup\nabort' ]]; then
    echo "FAIL: backup failure did not abort before finalize/delete"; return 1
  fi

  rm -rf -- "${tmp}"
  return 0
)

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_compose_deletion_mount_backup
fi
