#!/usr/bin/env bash
# Tests for the backup progress protocol: the emitter, the pv/curl readers and
# the instrumentation inside compress(). No Docker, storage or network access.

source "$(dirname "${BASH_SOURCE[0]}")/../libs/commons.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../libs/apps/dropbox_uploader_helper.sh"

function test_backup_progress() {
  local tmp failed=0 events payload line output err src out count saved_path="${PATH}"

  tmp="$(mktemp -d)"

  # Hermetic pv. It records its arguments and only produces numeric output when
  # BOTH --numeric and --force are present, interleaved with the data: dropping
  # either option, or misspelling it, must fail the tests instead of passing
  # silently. The host binary is not required.
  mkdir -p "${tmp}/bin"
  cat > "${tmp}/bin/pv" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${FAKE_PV_ARGS_FILE:-/dev/null}"
numeric=false
force=false
for arg in "$@"; do
  case "${arg}" in
    --numeric|-n) numeric=true ;;
    --force|-f) force=true ;;
  esac
done
if [[ "${numeric}" == "true" && "${force}" == "true" ]]; then
  printf '0\n' >&2
  cat
  printf '50\n100\n' >&2
else
  cat
fi
FAKE
  chmod +x "${tmp}/bin/pv"
  PATH="${tmp}/bin:${PATH}"
  FAKE_PV_ARGS_FILE="${tmp}/pv-args"
  export FAKE_PV_ARGS_FILE

  # Hermetic Dropbox uploader: a curl-like meter on stderr when -p is used,
  # nothing when -q is used, and a real transport error on demand.
  cat > "${tmp}/bin/uploader" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${FAKE_UPLOADER_ARGS_FILE:-/dev/null}"
if [[ "${1:-}" == "-p" ]]; then
  printf '##### 10.0%%\r##### 100.0%%\r' >&2
fi
if [[ "${FAKE_UPLOADER_FAIL:-0}" == "1" ]]; then
  printf 'curl: (7) Failed to connect to content.dropboxapi.com\n' >&2
  printf 'error output\n'
  exit 1
fi
printf 'ok\n'
exit 0
FAKE
  chmod +x "${tmp}/bin/uploader"
  FAKE_UPLOADER_ARGS_FILE="${tmp}/uploader-args"
  export FAKE_UPLOADER_ARGS_FILE

  function display() { :; }
  function log_event() { :; }
  function log_section() { :; }
  function log_subsection() { :; }
  function log_break() { :; }
  function clear_previous_lines() { :; }
  function get_file_size() { printf '1234\n'; }
  function spinner_start() { :; }
  function spinner_stop() { :; }

  # Every line must carry the sentinel and be valid JSON.
  function assert_stream() {
    local name="${1}" stream="${2}" expected="${3}"
    local body seen=0
    while IFS= read -r line; do
      [[ -n "${line}" ]] || continue
      seen=$((seen + 1))
      if [[ "${line}" != "[[BROLIT_PROGRESS]]"* ]]; then
        printf 'FAIL: %s: line without sentinel: %s\n' "${name}" "${line}"
        failed=1
        continue
      fi
      body="${line#\[\[BROLIT_PROGRESS\]\]}"
      if ! printf '%s' "${body}" | jq -e . >/dev/null 2>&1; then
        printf 'FAIL: %s: invalid JSON: %s\n' "${name}" "${body}"
        failed=1
      fi
    done <<< "${stream}"

    if (( seen == 0 )) && [[ "${expected}" != "empty" ]]; then
      printf 'FAIL: %s: no events emitted\n' "${name}"
      failed=1
    fi
    if (( seen > 0 )) && [[ "${expected}" == "empty" ]]; then
      printf 'FAIL: %s: unexpected events emitted\n' "${name}"
      failed=1
    fi
  }

  # Off by default: interactive runs and old consumers see nothing.
  unset BROLIT_PROGRESS
  events="$(brolit_progress compress 50 example.com 2>&1)"
  assert_stream "disabled" "${events}" "empty"

  BROLIT_PROGRESS=0
  events="$(brolit_progress compress 50 example.com 2>&1)"
  assert_stream "explicitly disabled" "${events}" "empty"

  # Enabled: fixed protocol shape.
  BROLIT_PROGRESS=1
  events="$(brolit_progress compress 42 example.com 2>&1)"
  assert_stream "enabled" "${events}" "present"
  payload="${events#\[\[BROLIT_PROGRESS\]\]}"
  if [[ "$(printf '%s' "${payload}" | jq -r '.v')" != "1" ]]; then
    echo "FAIL: protocol version is not 1"; failed=1
  fi
  if [[ "$(printf '%s' "${payload}" | jq -r '.phase')" != "compress" ]]; then
    echo "FAIL: phase not reported"; failed=1
  fi
  if [[ "$(printf '%s' "${payload}" | jq -r '.pct')" != "42" ]]; then
    echo "FAIL: percentage not reported"; failed=1
  fi
  if [[ "$(printf '%s' "${payload}" | jq -r '.detail')" != "example.com" ]]; then
    echo "FAIL: detail not reported"; failed=1
  fi

  # Percentage normalisation: unmeasurable is null, out of range is clamped,
  # leading zeros never reach JSON as an invalid number.
  if [[ "$(brolit_progress upload - site 2>&1 | sed 's/.*"pct"://; s/,.*//')" != "null" ]]; then
    echo "FAIL: unmeasurable percentage is not null"; failed=1
  fi
  if [[ "$(brolit_progress upload 150 site 2>&1 | sed 's/.*"pct"://; s/,.*//')" != "100" ]]; then
    echo "FAIL: percentage not clamped"; failed=1
  fi
  if [[ "$(brolit_progress upload 007 site 2>&1 | sed 's/.*"pct"://; s/,.*//')" != "7" ]]; then
    echo "FAIL: leading zeros not normalised"; failed=1
  fi
  if [[ "$(brolit_progress upload abc site 2>&1 | sed 's/.*"pct"://; s/,.*//')" != "null" ]]; then
    echo "FAIL: non numeric percentage is not null"; failed=1
  fi

  # Unknown phases are dropped: the protocol is closed by design.
  events="$(brolit_progress nope 50 example.com 2>&1)"
  assert_stream "unknown phase" "${events}" "empty"

  # The detail is restricted to characters that cannot carry a path or a secret.
  payload="$(brolit_progress compress 10 '../../etc/passwd' 2>&1)"
  payload="${payload#\[\[BROLIT_PROGRESS\]\]}"
  if [[ "$(printf '%s' "${payload}" | jq -r '.detail')" != "....etcpasswd" ]]; then
    echo "FAIL: detail sanitization"; failed=1
  fi
  payload="$(brolit_progress compress 10 'user secret$token' 2>&1)"
  payload="${payload#\[\[BROLIT_PROGRESS\]\]}"
  if [[ "$(printf '%s' "${payload}" | jq -r '.detail')" != "usersecrettoken" ]]; then
    echo "FAIL: detail sanitization of spaces and symbols"; failed=1
  fi

  # The detail is bounded as well as sanitized: the consumer's schema caps it.
  payload="$(brolit_progress compress 10 "$(printf 'a%.0s' {1..400}).example.com" 2>&1)"
  payload="${payload#\[\[BROLIT_PROGRESS\]\]}"
  if [[ "$(printf '%s' "${payload}" | jq -r '.detail | length')" != "255" ]]; then
    echo "FAIL: detail not truncated to 255"; failed=1
  fi

  # The default detail comes from the caller's context.
  BROLIT_PROGRESS_DETAIL="ctx.example.com"
  payload="$(brolit_progress compress 10 2>&1)"
  payload="${payload#\[\[BROLIT_PROGRESS\]\]}"
  if [[ "$(printf '%s' "${payload}" | jq -r '.detail')" != "ctx.example.com" ]]; then
    echo "FAIL: detail from BROLIT_PROGRESS_DETAIL"; failed=1
  fi
  unset BROLIT_PROGRESS_DETAIL

  # pv reader: throttled, monotonic, always closed with the last value.
  events="$(printf '0\n1\n2\n3\n50\n99\n100\n' | brolit_progress_pv compress example.com 2>&1)"
  assert_stream "pv reader" "${events}" "present"
  count="$(printf '%s\n' "${events}" | grep -c '\[\[BROLIT_PROGRESS\]\]')"
  if (( count < 3 || count > 7 )); then
    echo "FAIL: pv reader throttle produced ${count} events"; failed=1
  fi
  if ! printf '%s\n' "${events}" | tail -n 1 | grep -q '"pct":100'; then
    echo "FAIL: pv reader did not close with the last value"; failed=1
  fi

  # pv diagnostics are not swallowed with the meter, and a trailing non-numeric
  # line must not turn the closing event into null.
  events="$(printf '0\npv: /missing: No such file or directory\n50\n' | brolit_progress_pv compress example.com 2>&1)"
  if ! printf '%s\n' "${events}" | grep -q 'pv: /missing: No such file or directory'; then
    echo "FAIL: pv diagnostic was swallowed"; failed=1
  fi
  if [[ "$(printf '%s\n' "${events}" | tail -n 1 | sed 's/.*"pct"://; s/,.*//')" != "50" ]]; then
    echo "FAIL: pv reader closed with something other than the last valid value"; failed=1
  fi

  # Absurdly long numeric input is not fed to the arithmetic.
  events="$(printf '0\n%s\n50\n' "$(printf '9%.0s' {1..5000})" | brolit_progress_pv compress example.com 2>&1 | grep '^\[\[BROLIT_PROGRESS\]\]')"
  if [[ "$(printf '%s\n' "${events}" | tail -n 1 | sed 's/.*"pct"://; s/,.*//')" != "50" ]]; then
    echo "FAIL: oversized pv value corrupted the closing event"; failed=1
  fi

  # curl meter reader: carriage-return separated updates.
  events="$(printf '########## 10.0%%\r########## 42.5%%\r########## 100.0%%\r' | brolit_progress_meter upload example.com 2>&1)"
  assert_stream "curl meter" "${events}" "present"
  if ! printf '%s\n' "${events}" | grep -q '"pct":10'; then
    echo "FAIL: curl meter missed the first value"; failed=1
  fi
  if ! printf '%s\n' "${events}" | grep -q '"pct":42'; then
    echo "FAIL: curl meter missed an intermediate value"; failed=1
  fi
  # The meter never claims completion: only dropbox_upload knows whether the
  # whole upload, including every chunk and the commit, succeeded.
  if printf '%s\n' "${events}" | grep -q '"pct":100'; then
    echo "FAIL: curl meter reported 100"; failed=1
  fi
  if ! printf '%s\n' "${events}" | tail -n 1 | grep -q '"pct":99'; then
    echo "FAIL: curl meter did not cap the last request at 99"; failed=1
  fi

  # Even an unexpected request restart cannot claim completion or make the
  # displayed percentage go backwards.
  events="$(printf '## 100.0%%\r## 100.0%%\r' | brolit_progress_meter upload example.com 2>&1)"
  if [[ "$(printf '%s\n' "${events}" | grep -c '\[\[BROLIT_PROGRESS\]\]')" -ne 1 ]]; then
    echo "FAIL: repeated meter completion produced duplicate events"; failed=1
  fi

  # curl's own errors survive the meter.
  events="$(printf '## 10.0%%\rcurl: (6) Could not resolve host: content.dropboxapi.com\r' | brolit_progress_meter upload example.com 2>&1)"
  if ! printf '%s\n' "${events}" | grep -q 'Could not resolve host'; then
    echo "FAIL: curl error was swallowed by the meter"; failed=1
  fi

  # compress(): real pipeline, stdout stays clean because callers capture it.
  src="${tmp}/src"
  out="${tmp}/out/backup.tar.gz"
  err="${tmp}/err.log"
  mkdir -p "${src}/site/sub" "${tmp}/out"
  printf 'hello\n' > "${src}/site/sub/file.txt"

  BACKUP_CONFIG_COMPRESSION_TYPE="gzip"
  BACKUP_CONFIG_COMPRESSION_LEVEL=""
  BACKUP_CONFIG_COMPRESSION_CORES=""
  BACKUP_CONFIG_FOLLOW_SYMLINKS="false"
  BACKUP_CONFIG_COMPRESSION_TEST="false"
  TAR="$(command -v tar)"
  BROLIT_PROGRESS=1
  BROLIT_PROGRESS_DETAIL="site.example.com"

  output="$(compress "${src}" "site" "${out}" "" 2>"${err}")"
  if [[ "${output}" == *BROLIT_PROGRESS* ]]; then
    echo "FAIL: compress leaked progress into stdout"; failed=1
  fi
  if [[ ! -s "${out}" ]]; then
    echo "FAIL: compress did not produce an archive"; failed=1
  fi
  if ! grep -q '"phase":"compress"' "${err}"; then
    echo "FAIL: compress emitted no compress event"; failed=1
  fi
  if ! grep -q '"pct":100' "${err}"; then
    echo "FAIL: compress did not close the phase at 100"; failed=1
  fi
  if ! grep -q '"detail":"site.example.com"' "${err}"; then
    echo "FAIL: compress did not use the progress context"; failed=1
  fi
  assert_stream "compress" "$(grep '^\[\[BROLIT_PROGRESS\]\]' "${err}")" "present"

  # Without the flag the pipeline emits nothing and still builds the archive.
  BROLIT_PROGRESS=0
  out="${tmp}/out/backup2.tar.gz"
  err="${tmp}/err2.log"
  output="$(compress "${src}" "site" "${out}" "" 2>"${err}")"
  if [[ -s "${err}" ]]; then
    echo "FAIL: disabled compress wrote to stderr: $(head -c 200 "${err}")"; failed=1
  fi
  if [[ ! -s "${out}" ]]; then
    echo "FAIL: disabled compress did not produce an archive"; failed=1
  fi

  # dropbox_upload(): -p only when progress is requested, real exit status, and
  # exactly one completion event, claimed by the caller and not by the meter.
  DROPBOX_UPLOADER="${tmp}/bin/uploader"
  BROLIT_PROGRESS_DETAIL="site.example.com"
  local upload_file="${tmp}/archive.tar.gz"
  printf 'archive\n' > "${upload_file}"

  BROLIT_PROGRESS=1
  err="${tmp}/upload.log"
  dropbox_upload "${upload_file}" "/backups" >"${tmp}/upload-stdout" 2>"${err}"
  if [[ $? -ne 0 ]]; then
    echo "FAIL: successful upload reported an error"; failed=1
  fi
  if [[ "$(head -c 2 "${FAKE_UPLOADER_ARGS_FILE}")" != "-p" ]]; then
    echo "FAIL: progress-enabled upload did not use -p"; failed=1
  fi
  if [[ "$(grep -c '"phase":"upload"' "${err}")" -lt 2 ]]; then
    echo "FAIL: upload emitted no progress"; failed=1
  fi
  if [[ "$(grep '"phase":"upload"' "${err}" | grep -c '"pct":100')" -ne 1 ]]; then
    echo "FAIL: upload completion was not reported exactly once"; failed=1
  fi
  if grep -q BROLIT_PROGRESS "${tmp}/upload-stdout"; then
    echo "FAIL: upload leaked progress into stdout"; failed=1
  fi

  # Above the uploader's 150 MB threshold every chunk has its own meter and
  # failed chunks are retried. Without explicit chunk markers there is no honest
  # overall percentage, so the upload reports only start and completion.
  local large_file="${tmp}/large-archive.tar.gz"
  truncate -s 157286001 "${large_file}"
  err="${tmp}/upload-large.log"
  dropbox_upload "${large_file}" "/backups" >/dev/null 2>"${err}"
  if [[ $? -ne 0 ]]; then
    echo "FAIL: successful chunked upload reported an error"; failed=1
  fi
  if [[ "$(head -c 2 "${FAKE_UPLOADER_ARGS_FILE}")" != "-q" ]]; then
    echo "FAIL: chunked upload enabled a misleading per-chunk meter"; failed=1
  fi
  local large_pcts
  large_pcts="$(grep '"phase":"upload"' "${err}" | sed 's/.*"pct"://; s/,.*//' | tr '\n' ' ')"
  if [[ "${large_pcts}" != "0 100 " ]]; then
    echo "FAIL: chunked upload did not report exactly 0 and 100: ${large_pcts}"; failed=1
  fi

  # Exactly at the threshold the uploader still uses a single request.
  truncate -s 157286000 "${large_file}"
  dropbox_upload "${large_file}" "/backups" >/dev/null 2>/dev/null
  if [[ "$(head -c 2 "${FAKE_UPLOADER_ARGS_FILE}")" != "-p" ]]; then
    echo "FAIL: single-request upload at the threshold did not use -p"; failed=1
  fi

  # A failed upload keeps curl's diagnostics and never claims completion.
  FAKE_UPLOADER_FAIL=1
  export FAKE_UPLOADER_FAIL
  err="${tmp}/upload-fail.log"
  dropbox_upload "${upload_file}" "/backups" >/dev/null 2>"${err}"
  if [[ $? -eq 0 ]]; then
    echo "FAIL: failed upload reported success"; failed=1
  fi
  if ! grep -q 'Failed to connect to content.dropboxapi.com' "${err}"; then
    echo "FAIL: upload error diagnostics were lost"; failed=1
  fi
  if grep '"phase":"upload"' "${err}" | grep -q '"pct":100'; then
    echo "FAIL: failed upload reported 100"; failed=1
  fi
  unset FAKE_UPLOADER_FAIL

  # Without the flag the uploader is quiet and no event is emitted.
  BROLIT_PROGRESS=0
  err="${tmp}/upload-quiet.log"
  dropbox_upload "${upload_file}" "/backups" >/dev/null 2>"${err}"
  if [[ "$(head -c 2 "${FAKE_UPLOADER_ARGS_FILE}")" != "-q" ]]; then
    echo "FAIL: non-progress upload did not use -q"; failed=1
  fi
  if grep -q BROLIT_PROGRESS "${err}"; then
    echo "FAIL: quiet upload emitted progress"; failed=1
  fi

  # Machine-readable progress must not be interleaved with spinner control
  # characters on the same stderr line.
  events="$(bash -c 'source "$1"; QUIET=false; BROLIT_EXEC_TYPE=default; BROLIT_PROGRESS=1; spinner_start "Uploading"; spinner_stop 0' _ "$(pwd)/libs/local/log_and_display_helper.sh" 2>&1)"
  assert_stream "spinner in progress mode" "${events}" "empty"

  rm -rf -- "${tmp}"
  # Never leak the fake pv into the caller's PATH.
  PATH="${saved_path}"
  return "${failed}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  test_backup_progress
fi
