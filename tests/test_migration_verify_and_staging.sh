#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
################################################################################
# Focused tests for two migrate fixes:
#   1. the destination is verified by HTTP status, not by `curl --fail`
#      (a stopped stack answering 502 used to pass through the 301 to HTTPS);
#   2. the staged captures are removed when a migration ends, whether it
#      succeeds, fails or is cancelled during capture/transfer.
# Drives the real functions of libs/local/site_migration_helper.sh with stubs.
################################################################################

MVS_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
MVS_ROOT_DIR="$(cd "${MVS_TEST_DIR}/.." && pwd -P)"
# shellcheck source=libs/local/job_control_helper.sh
source "${MVS_ROOT_DIR}/libs/local/job_control_helper.sh"
# shellcheck source=libs/local/site_migration_helper.sh
source "${MVS_ROOT_DIR}/libs/local/site_migration_helper.sh"

################################################################################
# Assert two strings are equal and report a focused test result.
#
# Arguments:
#   ${1} = expected value
#   ${2} = actual value
#   ${3} = test description
#
# Outputs:
#   0 when equal, 1 otherwise.
################################################################################

function _mvs_assert_equal() {

  local expected="${1}"
  local actual="${2}"
  local description="${3}"

  if [[ ${expected} == "${actual}" ]]; then
    printf 'PASS: %s\n' "${description}"
    return 0
  fi

  printf 'FAIL: %s (expected %q, got %q)\n' "${description}" "${expected}" "${actual}" >&2
  return 1

}

################################################################################
# Verification: one case per (HTTPS status, HTTP status) pair.
#
# Arguments:
#   ${1} = test root
#
# Outputs:
#   0 when every case holds, 1 otherwise.
################################################################################

function _mvs_verify_tests() {

  local test_root="${1}"
  local failed=0
  local calls_file="${test_root}/curl-calls"
  local shown_file="${test_root}/shown"

  function log_subsection() { :; }
  function log_event() { :; }
  function display() { printf '%s|%s\n' "${4}" "${6}" >> "${shown_file}"; }
  # The destination answers the address query; the local stack check (verify-local)
  # fails unless a case says the stack is up (FAKE_LOCAL_RC=0).
  function _migrate_ssh() {
    if [[ "${5}" == *verify-local* ]]; then return "${FAKE_LOCAL_RC:-1}"; fi
    printf '203.0.113.9\n'
  }
  # Fake curl: the status comes from FAKE_HTTPS / FAKE_HTTP according to the URL scheme.
  function curl() {
    local url="${*: -1}"
    printf '%s\n' "${url}" >> "${calls_file}"
    case "${url}" in
      https://*) printf '%s' "${FAKE_HTTPS}" ;;
      *) printf '%s' "${FAKE_HTTP}" ;;
    esac
    return 0
  }

  local case_line https http expected_rc expected_calls description rc calls
  while IFS='|' read -r https http expected_rc expected_calls description; do
    : > "${calls_file}"
    : > "${shown_file}"
    FAKE_HTTPS="${https}" FAKE_HTTP="${http}"
    export FAKE_HTTPS FAKE_HTTP
    migrate_verify_destination "root" "203.0.113.9" "22" "/unused" "example.com" >/dev/null 2>&1
    rc=$?
    calls="$(wc -l < "${calls_file}" | tr -d ' ')"
    _mvs_assert_equal "${expected_rc}:${expected_calls}" "${rc}:${calls}" "${description}" || failed=1
  done <<'CASES'
200|-|0|1|HTTPS 200 passes without trying HTTP
301|-|0|1|an HTTPS redirect is an answer from a live site
401|-|0|1|a protected site (401) passes: the old --fail rejected it
404|-|0|1|an app answering 404 is up
502|301|1|1|HTTPS 502 fails even though HTTP redirects (the production case)
503|200|1|1|HTTPS 5xx fails at once, HTTP is not consulted
000|200|0|2|no HTTPS answer and HTTP serves the site: warning, passes
000|404|0|2|no HTTPS answer and HTTP answers 404: passes
000|301|1|2|no HTTPS answer and HTTP only redirects to it: fails
000|502|1|2|no HTTPS answer and HTTP 502: fails
000|000|1|2|no answer on either: fails
CASES

  FAKE_HTTPS=000 FAKE_HTTP=200
  : > "${shown_file}"
  migrate_verify_destination "root" "203.0.113.9" "22" "/unused" "example.com" >/dev/null 2>&1
  _mvs_assert_equal "WARNING" "$(awk -F'|' '{print $2}' "${shown_file}" | tail -1)" \
    "HTTP-only success is reported as a warning" || failed=1

  # A destination behind a gateway has no certificate before the DNS switch and its
  # plain HTTP only redirects: the stack answering locally is what passes it.
  : > "${calls_file}"
  FAKE_HTTPS=000 FAKE_HTTP=301 FAKE_LOCAL_RC=0
  export FAKE_HTTPS FAKE_HTTP FAKE_LOCAL_RC
  : > "${shown_file}"
  migrate_verify_destination "root" "203.0.113.9" "22" "/unused" "example.com" >/dev/null 2>&1
  _mvs_assert_equal "0:WARNING" "$?:$(awk -F'|' '{print $2}' "${shown_file}" | tail -1)" \
    "no HTTPS, HTTP only redirects, stack answers locally: passes with a warning" || failed=1

  # A server error over HTTPS is a hard failure whatever the local check says.
  FAKE_HTTPS=502 FAKE_HTTP=301 FAKE_LOCAL_RC=0
  migrate_verify_destination "root" "203.0.113.9" "22" "/unused" "example.com" >/dev/null 2>&1
  _mvs_assert_equal "1" "$?" "HTTPS 502 fails even when the stack answers locally" || failed=1
  unset FAKE_LOCAL_RC

  FAKE_HTTPS=502 FAKE_HTTP=301
  : > "${shown_file}"
  migrate_verify_destination "root" "203.0.113.9" "22" "/unused" "example.com" >/dev/null 2>&1
  _mvs_assert_equal "FAIL" "$(awk -F'|' '{print $2}' "${shown_file}" | tail -1)" \
    "a 502 is reported as a failure" || failed=1

  : > "${calls_file}"
  function _migrate_ssh() { printf ''; }
  migrate_verify_destination "root" "dest.example.net" "22" "/unused" "example.com" >/dev/null 2>&1
  _mvs_assert_equal "1:0" "$?:$(wc -l < "${calls_file}" | tr -d ' ')" \
    "an unresolvable destination fails without probing" || failed=1

  return "${failed}"

}

################################################################################
# Staging cleanup: only this project's directories, validated, symlinks left alone.
#
# Arguments:
#   ${1} = test root
#
# Outputs:
#   0 when every case holds, 1 otherwise.
################################################################################

function _mvs_cleanup_tests() {

  local test_root="${1}"
  local failed=0
  local root="${test_root}/staging"
  local ssh_log="${test_root}/ssh-calls"

  export SERVER_NAME="src-host"
  MIGRATE_LOCAL_STAGING_PATH_DEFAULT="${root}"
  export MVS_SSH_LOG="${ssh_log}"

  function log_event() { :; }
  function display() { :; }
  function _migrate_ssh() { printf '%s\n' "${5}" >> "${MVS_SSH_LOG}"; }

  function _mvs_seed() {
    rm --recursive --force -- "${root}"
    mkdir --parents \
      "${root}/src-host/projects-online/site/example.com" \
      "${root}/src-host/projects-online/site/other.com" \
      "${root}/src-host/projects-online/database/site_db" \
      "${root}/src-host/projects-online/database/other_db" \
      "${root}/dest-host/projects-online/site/example.com"
    : > "${root}/src-host/projects-online/site/example.com/example.com_site-files_2026-11-19.tar.bz2"
    : > "${root}/src-host/projects-online/site/other.com/other.com_site-files_2026-11-19.tar.bz2"
    : > "${ssh_log}"
  }

  _mvs_seed
  migrate_cleanup_staging "example.com" "root" "dest" "22" "/unused" "dest-host" "site_db"
  _mvs_assert_equal "0" "$?" "cleanup of a valid migration succeeds" || failed=1
  _mvs_assert_equal "gone" "$([[ -e ${root}/src-host/projects-online/site/example.com ]] && echo present || echo gone)" \
    "the project's site capture is removed on the source" || failed=1
  _mvs_assert_equal "gone" "$([[ -e ${root}/src-host/projects-online/database/site_db ]] && echo present || echo gone)" \
    "the project's database capture is removed on the source" || failed=1
  _mvs_assert_equal "present:present:present" \
    "$([[ -e ${root}/src-host/projects-online/site/other.com ]] && echo present || echo gone):$([[ -e ${root}/src-host/projects-online/database/other_db ]] && echo present || echo gone):$([[ -d ${root} ]] && echo present || echo gone)" \
    "other projects' captures and the staging root stay" || failed=1
  _mvs_assert_equal "rm --recursive --force --one-file-system -- '${root}/dest-host/projects-online/site/example.com' '${root}/dest-host/projects-online/database/site_db'" \
    "$(< "${ssh_log}")" "the destination is asked to remove exactly the same two paths under its own name" || failed=1

  _mvs_seed
  local bad rc
  for bad in "" "../site" "a b.com" "/etc" ".hidden" "x/../y" "a;b"; do
    migrate_cleanup_staging "${bad}" "root" "dest" "22" "/unused" "dest-host" "site_db" 2>/dev/null
    rc=$?
    _mvs_assert_equal "1" "${rc}" "an unsafe domain is refused: '${bad}'" || failed=1
  done
  _mvs_assert_equal "2:0" "$(find "${root}/src-host/projects-online/site" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '):$(wc -l < "${ssh_log}" | tr -d ' ')" \
    "an unsafe domain removes nothing and sends nothing" || failed=1

  _mvs_seed
  migrate_cleanup_staging "example.com" "root" "dest" "22" "/unused" "../etc" "site_db"
  _mvs_assert_equal "gone:0" "$([[ -e ${root}/src-host/projects-online/site/example.com ]] && echo present || echo gone):$(wc -l < "${ssh_log}" | tr -d ' ')" \
    "an unsafe destination name cleans the source and sends nothing" || failed=1

  _mvs_seed
  migrate_cleanup_staging "example.com"
  _mvs_assert_equal "gone:0" "$([[ -e ${root}/src-host/projects-online/site/example.com ]] && echo present || echo gone):$(wc -l < "${ssh_log}" | tr -d ' ')" \
    "without a destination only the source is cleaned" || failed=1

  _mvs_seed
  mkdir --parents "${test_root}/precious"
  : > "${test_root}/precious/keep"
  rm --recursive --force -- "${root}/src-host/projects-online/site/example.com"
  ln -s "${test_root}/precious" "${root}/src-host/projects-online/site/example.com"
  migrate_cleanup_staging "example.com" >/dev/null 2>&1
  _mvs_assert_equal "kept" "$([[ -e ${test_root}/precious/keep ]] && echo kept || echo lost)" \
    "a symlink in place of the capture is never followed" || failed=1

  _mvs_seed
  SERVER_NAME="../escape"
  migrate_cleanup_staging "example.com" >/dev/null 2>&1
  _mvs_assert_equal "present" "$([[ -e ${root}/src-host/projects-online/site/example.com ]] && echo present || echo gone)" \
    "an unsafe local server name removes nothing" || failed=1
  SERVER_NAME="src-host"

  return "${failed}"

}

################################################################################
# Wrapper and signals: cleanup on every way out, and only while it is safe.
#
# Arguments:
#   ${1} = test root
#
# Outputs:
#   0 when every case holds, 1 otherwise.
################################################################################

function _mvs_wrapper_tests() {

  local test_root="${1}"
  local failed=0
  local root="${test_root}/staging2"
  local ssh_log="${test_root}/ssh-calls2"
  local site_dir="${root}/src-host/projects-online/site/example.com"

  export SERVER_NAME="src-host"
  MIGRATE_LOCAL_STAGING_PATH_DEFAULT="${root}"
  export MVS_SSH_LOG="${ssh_log}"

  function log_event() { :; }
  function display() { :; }
  function _migrate_ssh() { printf '%s\n' "${5}" >> "${MVS_SSH_LOG}"; }

  function _mvs_seed2() {
    rm --recursive --force -- "${root}"
    mkdir --parents "${site_dir}"
    : > "${site_dir}/capture.tar.bz2"
    : > "${ssh_log}"
  }

  local rc
  for rc in 0 1; do
    _mvs_seed2
    function _migrate_site_run() { MIGRATE_RUN_DEST_SERVER_NAME="dest-host"; return "${MVS_RUN_RC}"; }
    MVS_RUN_RC="${rc}" migrate_site "example.com" "dest" "root" "22" "/unused" >/dev/null 2>&1
    _mvs_assert_equal "${rc}:gone:1" "$?:$([[ -e ${site_dir} ]] && echo present || echo gone):$(wc -l < "${ssh_log}" | tr -d ' ')" \
      "migrate_site returns ${rc} and removes the captures here and on the destination" || failed=1
  done

  _mvs_seed2
  ( MIGRATE_RUN_DOMAIN="example.com"; MIGRATE_STAGING_SIGNAL_SAFE="1"; _migrate_on_signal 143 ) >/dev/null 2>&1
  _mvs_assert_equal "143:gone" "$?:$([[ -e ${site_dir} ]] && echo present || echo gone)" \
    "TERM during capture or transfer removes the capture and exits 143" || failed=1

  _mvs_seed2
  ( MIGRATE_RUN_DOMAIN="example.com"; MIGRATE_STAGING_SIGNAL_SAFE="0"; _migrate_on_signal 130 ) >/dev/null 2>&1
  _mvs_assert_equal "130:present" "$?:$([[ -e ${site_dir} ]] && echo present || echo gone)" \
    "a signal during the remote restore removes nothing, the destination is reading it" || failed=1

  # A real TERM, the way Admin cancels: the process is waiting on a child.
  _mvs_seed2
  local marker="${test_root}/in-capture"
  rm --force -- "${marker}" "${marker}.child"
  function _migrate_site_run() {
    MIGRATE_RUN_DEST_SERVER_NAME="dest-host"
    MIGRATE_STAGING_SIGNAL_SAFE="1"
    : > "${marker}"
    sleep 30 &
    printf '%s' "$!" > "${marker}.child"
    wait $!
    return 0
  }
  ( migrate_site "example.com" "dest" "root" "22" "/unused" >/dev/null 2>&1 ) &
  local pid=$!
  local waited=0
  while [[ ! -e ${marker} && ${waited} -lt 50 ]]; do sleep 0.1; waited=$((waited + 1)); done
  kill -TERM "${pid}" 2>/dev/null
  wait "${pid}" 2>/dev/null
  rc=$?
  # Kill only the child this test started, never by name.
  [[ -f "${marker}.child" ]] && kill "$(< "${marker}.child")" 2>/dev/null
  _mvs_assert_equal "143:gone:1" "${rc}:$([[ -e ${site_dir} ]] && echo present || echo gone):$(wc -l < "${ssh_log}" | tr -d ' ')" \
    "a real TERM mid-capture removes the capture on both servers and ends with 143" || failed=1

  return "${failed}"

}

function test_migration_verify_and_staging() {

  local test_root
  local failed=0

  test_root="$(mktemp -d)" || return 1

  ( _mvs_verify_tests "${test_root}" ) || failed=1
  ( _mvs_cleanup_tests "${test_root}" ) || failed=1
  ( _mvs_wrapper_tests "${test_root}" ) || failed=1

  rm --recursive --force -- "${test_root}"

  if [[ ${failed} -eq 0 ]]; then
    printf 'migration verify and staging tests passed\n'
  fi

  return "${failed}"

}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  test_migration_verify_and_staging
fi
