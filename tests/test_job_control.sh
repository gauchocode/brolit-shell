#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
################################################################################
# Focused tests for phase-aware job control and its migration integration.
################################################################################

JOB_CONTROL_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
JOB_CONTROL_ROOT_DIR="$(cd "${JOB_CONTROL_TEST_DIR}/.." && pwd -P)"
# shellcheck source=libs/local/job_control_helper.sh
source "${JOB_CONTROL_ROOT_DIR}/libs/local/job_control_helper.sh"
# shellcheck source=libs/local/site_migration_helper.sh
source "${JOB_CONTROL_ROOT_DIR}/libs/local/site_migration_helper.sh"

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

function _job_control_assert_equal() {

  local expected="${1}"
  local actual="${2}"
  local description="${3}"

  if [[ ${actual} == "${expected}" ]]; then
    printf 'PASS: %s\n' "${description}"
    return 0
  fi

  printf 'FAIL: %s (expected %q, got %q)\n' "${description}" "${expected}" "${actual}" >&2
  return 1

}

################################################################################
# Exercise transitions, identity preservation, and fail-closed no-op cases.
#
# Arguments:
#   ${1} = temporary test root
#
# Outputs:
#   0 when all cases pass, 1 otherwise.
################################################################################

function _job_control_state_tests() {

  local test_root="${1}"
  local control_dir="${test_root}/control"
  local job_id="123e4567-e89b-42d3-a456-426614174000"
  local control_file="${control_dir}/brolit-job-${job_id}.control"
  local lock_file="${control_dir}/brolit-job-${job_id}.lock"
  local pid="$$"
  local proc_start
  local failed=0
  local malformed
  local expected
  local actual
  local transition_rc

  mkdir -p "${control_dir}"
  proc_start="$(awk '{print $22}' "/proc/${pid}/stat")"
  export BROLIT_JOB_ID="${job_id}"
  export BROLIT_JOB_CONTROL_DIR="${control_dir}"

  printf '%s %s noncancellable\n' "${pid}" "${proc_start}" > "${control_file}"
  : > "${lock_file}"
  chmod 600 "${control_file}" "${lock_file}"

  brolit_job_control_mark_cancellable
  _job_control_assert_equal "${pid} ${proc_start} cancellable" "$(< "${control_file}")" \
    "capture transition preserves PID and start-time" || failed=1
  _job_control_assert_equal "600" "$(stat -c '%a' "${control_file}")" \
    "atomic replacement keeps the control file private" || failed=1

  brolit_job_control_mark_noncancellable
  _job_control_assert_equal "${pid} ${proc_start} noncancellable" "$(< "${control_file}")" \
    "restore transition preserves PID and start-time" || failed=1
  _job_control_assert_equal "" "$(find "${control_dir}" -maxdepth 1 -name '.brolit-job-*.control.*' -print -quit)" \
    "atomic replacement leaves no temporary files" || failed=1

  for malformed in \
    "not-a-pid ${proc_start} noncancellable" \
    "${pid} not-a-time noncancellable" \
    "0 ${proc_start} noncancellable" \
    "${pid} ${proc_start} unknown" \
    "${pid} ${proc_start} noncancellable " \
    "${pid} ${proc_start} noncancellable extra"; do
    printf '%s\n' "${malformed}" > "${control_file}"
    brolit_job_control_mark_cancellable
    _job_control_assert_equal "${malformed}" "$(< "${control_file}")" \
      "malformed control content is untouched: ${malformed}" || failed=1
    brolit_job_control_mark_noncancellable
    transition_rc=$?
    _job_control_assert_equal "1" "${transition_rc}" \
      "strict marker rejects malformed content: ${malformed}" || failed=1
  done

  printf '%s %s noncancellable\nextra-line\n' "${pid}" "${proc_start}" > "${control_file}"
  expected="${pid} ${proc_start} noncancellable"$'\n'"extra-line"
  brolit_job_control_mark_cancellable
  _job_control_assert_equal "${expected}" "$(< "${control_file}")" \
    "multi-line control content is untouched" || failed=1

  printf '%s %s0 noncancellable\n' "${pid}" "${proc_start}" > "${control_file}"
  brolit_job_control_mark_cancellable
  _job_control_assert_equal "${pid} ${proc_start}0 noncancellable" "$(< "${control_file}")" \
    "stale process start-time is untouched" || failed=1
  brolit_job_control_mark_noncancellable
  transition_rc=$?
  _job_control_assert_equal "1" "${transition_rc}" \
    "strict marker rejects stale process identity" || failed=1

  printf '%s %s noncancellable\n' "${pid}" "${proc_start}" > "${control_file}"
  unset BROLIT_JOB_ID
  brolit_job_control_mark_cancellable
  _job_control_assert_equal "${pid} ${proc_start} noncancellable" "$(< "${control_file}")" \
    "missing BROLIT_JOB_ID is a no-op" || failed=1
  brolit_job_control_mark_noncancellable
  transition_rc=$?
  _job_control_assert_equal "0" "${transition_rc}" \
    "strict marker permits manual use without BROLIT_JOB_ID" || failed=1

  export BROLIT_JOB_ID="not-a-uuid"
  brolit_job_control_mark_cancellable
  _job_control_assert_equal "${pid} ${proc_start} noncancellable" "$(< "${control_file}")" \
    "invalid BROLIT_JOB_ID is a no-op" || failed=1
  export BROLIT_JOB_ID="${job_id}"

  rm --force -- "${control_file}"
  brolit_job_control_mark_cancellable
  if [[ -e ${control_file} ]]; then
    actual="present"
  else
    actual="absent"
  fi
  _job_control_assert_equal "absent" "${actual}" \
    "a missing control file is never created by a phase marker" || failed=1
  brolit_job_control_mark_noncancellable
  transition_rc=$?
  _job_control_assert_equal "0" "${transition_rc}" \
    "strict marker permits manual use without a control file" || failed=1

  printf '%s %s noncancellable\n' "${pid}" "${proc_start}" > "${control_file}"
  rm --force -- "${lock_file}"
  brolit_job_control_mark_cancellable
  transition_rc=$?
  _job_control_assert_equal "0" "${transition_rc}" \
    "best-effort marker ignores a missing lock" || failed=1
  _job_control_assert_equal "${pid} ${proc_start} noncancellable" "$(< "${control_file}")" \
    "missing lock cannot make a job cancellable" || failed=1

  printf '%s %s cancellable\n' "${pid}" "${proc_start}" > "${control_file}"
  brolit_job_control_mark_noncancellable
  transition_rc=$?
  _job_control_assert_equal "1" "${transition_rc}" \
    "strict marker fails when the lock is absent" || failed=1
  _job_control_assert_equal "${pid} ${proc_start} cancellable" "$(< "${control_file}")" \
    "missing lock leaves the previous state untouched" || failed=1

  : > "${lock_file}"
  function flock() { return 1; }
  brolit_job_control_mark_noncancellable
  transition_rc=$?
  unset -f flock
  _job_control_assert_equal "1" "${transition_rc}" \
    "strict marker propagates lock acquisition failure" || failed=1
  _job_control_assert_equal "${pid} ${proc_start} cancellable" "$(< "${control_file}")" \
    "lock failure leaves the previous state untouched" || failed=1

  function mv() { return 1; }
  brolit_job_control_mark_noncancellable
  transition_rc=$?
  unset -f mv
  _job_control_assert_equal "1" "${transition_rc}" \
    "strict marker propagates atomic write failure" || failed=1
  _job_control_assert_equal "${pid} ${proc_start} cancellable" "$(< "${control_file}")" \
    "write failure leaves the previous state untouched" || failed=1

  return "${failed}"

}

################################################################################
# Verify migration operations observe the required phase and source placement.
#
# Arguments:
#   ${1} = temporary test root
#
# Outputs:
#   0 when all cases pass, 1 otherwise.
################################################################################

function _job_control_migration_tests() {

  local test_root="${1}"
  local control_dir="${test_root}/migration-control"
  local job_id="123e4567-e89b-42d3-a456-426614174001"
  local control_file="${control_dir}/brolit-job-${job_id}.control"
  local lock_file="${control_dir}/brolit-job-${job_id}.lock"
  local events="${test_root}/migration-events"
  local pid="$$"
  local proc_start
  local failed=0
  local restore_rc
  local first_restore_action
  local capture_predecessor
  local transfer_predecessor
  local migration_helper="${JOB_CONTROL_ROOT_DIR}/libs/local/site_migration_helper.sh"

  mkdir -p "${control_dir}"
  proc_start="$(awk '{print $22}' "/proc/${pid}/stat")"
  export BROLIT_JOB_ID="${job_id}"
  export BROLIT_JOB_CONTROL_DIR="${control_dir}"
  export PROJECTS_PATH="${test_root}/projects"
  export SERVER_NAME="fixture-source"
  export BACKUP_DROPBOX_STATUS="disabled"
  MIGRATE_LOCAL_STAGING_PATH_DEFAULT="${test_root}/staging"
  mkdir -p "${MIGRATE_LOCAL_STAGING_PATH_DEFAULT}/${SERVER_NAME}/projects-online/database/site_db"
  : > "${lock_file}"
  chmod 600 "${lock_file}"

  function log_subsection() { :; }
  function log_event() { :; }
  function display() { :; }
  function backup_docker_project() {
    printf 'backup:%s\n' "$(awk '{print $3}' "${control_file}")" >> "${events}"
    return 0
  }
  function project_get_configured_database() { printf 'site_db\n'; }
  function project_get_type() { printf 'wordpress\n'; }
  function project_get_install_type() { printf 'docker-compose\n'; }
  function _migrate_rsync_push() {
    printf 'rsync:%s\n' "$(awk '{print $3}' "${control_file}")" >> "${events}"
    return 0
  }
  function _migrate_ssh() {
    local state="no-control"
    if [[ -f ${control_file} ]]; then
      state="$(awk '{print $3}' "${control_file}")"
    fi
    printf 'restore:%s\n' "${state}" >> "${events}"
    return 0
  }

  : > "${events}"
  printf '%s %s noncancellable\n' "${pid}" "${proc_start}" > "${control_file}"
  migrate_capture_source "example.com" "local" >/dev/null 2>&1
  _job_control_assert_equal "backup:cancellable" "$(< "${events}")" \
    "source backup runs only after the cancellable marker" || failed=1

  : > "${events}"
  printf '%s %s noncancellable\n' "${pid}" "${proc_start}" > "${control_file}"
  migrate_transfer_artifact "dest" "host" "22" "/unused/key" "example.com" "fixture-dest" >/dev/null 2>&1
  _job_control_assert_equal $'rsync:cancellable\nrsync:cancellable' "$(< "${events}")" \
    "site and database transfers both remain cancellable" || failed=1

  : > "${events}"
  printf '%s %s cancellable\n' "${pid}" "${proc_start}" > "${control_file}"
  migrate_trigger_remote_restore "dest" "host" "22" "/unused/key" "example.com" "local" >/dev/null 2>&1
  _job_control_assert_equal "restore:noncancellable" "$(< "${events}")" \
    "remote restore starts only after the noncancellable marker" || failed=1

  : > "${events}"
  printf '%s %s cancellable\n' "${pid}" "${proc_start}" > "${control_file}"
  rm --force -- "${lock_file}"
  migrate_trigger_remote_restore "dest" "host" "22" "/unused/key" "example.com" "local" >/dev/null 2>&1
  restore_rc=$?
  _job_control_assert_equal "1" "${restore_rc}" \
    "failed strict transition aborts remote restore" || failed=1
  _job_control_assert_equal "" "$(< "${events}")" \
    "failed strict transition prevents the restore SSH action" || failed=1
  _job_control_assert_equal "${pid} ${proc_start} cancellable" "$(< "${control_file}")" \
    "aborted restore preserves the previous control state" || failed=1

  : > "${events}"
  rm --force -- "${control_file}" "${lock_file}"
  migrate_trigger_remote_restore "dest" "host" "22" "/unused/key" "example.com" "local" >/dev/null 2>&1
  restore_rc=$?
  _job_control_assert_equal "0" "${restore_rc}" \
    "manual restore without Admin control files remains allowed" || failed=1
  _job_control_assert_equal "restore:no-control" "$(< "${events}")" \
    "manual restore reaches SSH without Admin control files" || failed=1

  first_restore_action="$(awk '
    $0 == "function migrate_trigger_remote_restore() {" { in_function=1; next }
    in_function && /^[[:space:]]*$/ { next }
    in_function { gsub(/^[[:space:]]+/, ""); print; exit }
  ' "${migration_helper}")"
  _job_control_assert_equal "brolit_job_control_mark_noncancellable || return 1" "${first_restore_action}" \
    "strict noncancellable guard is the first restore function action" || failed=1

  capture_predecessor="$(awk '
    /^  backup_docker_project / { print previous; exit }
    { previous=$0 }
  ' "${migration_helper}" | sed 's/^[[:space:]]*//')"
  _job_control_assert_equal "brolit_job_control_mark_cancellable" "${capture_predecessor}" \
    "cancellable immediately precedes source backup" || failed=1

  transfer_predecessor="$(awk '
    /^  _migrate_rsync_push / { print previous; exit }
    { previous=$0 }
  ' "${migration_helper}" | sed 's/^[[:space:]]*//')"
  _job_control_assert_equal "brolit_job_control_mark_cancellable" "${transfer_predecessor}" \
    "cancellable immediately precedes artifact transfer" || failed=1

  return "${failed}"

}

################################################################################
# Serialize an Admin-like check/TERM critical section with a restore transition.
# The cancellation signal is represented by an event, never sent to a process.
#
# Arguments:
#   ${1} = temporary test root
#
# Outputs:
#   0 when lock ordering is preserved, 1 otherwise.
################################################################################

function _job_control_concurrency_tests() {

  local test_root="${1}"
  local control_dir="${test_root}/concurrency-control"
  local job_id="123e4567-e89b-42d3-a456-426614174002"
  local control_file="${control_dir}/brolit-job-${job_id}.control"
  local lock_file="${control_dir}/brolit-job-${job_id}.lock"
  local events="${test_root}/concurrency-events"
  local lock_held="${test_root}/lock-held"
  local lock_release="${test_root}/lock-release"
  local lock_attempted="${test_root}/lock-attempted"
  local lock_acquired="${test_root}/lock-acquired"
  local transition_completed="${test_root}/transition-completed"
  local pid="$$"
  local proc_start
  local holder_pid
  local transition_pid
  local holder_rc
  local transition_rc
  local failed=0
  local actual
  local attempt

  mkdir -p "${control_dir}"
  proc_start="$(awk '{print $22}' "/proc/${pid}/stat")"
  printf '%s %s cancellable\n' "${pid}" "${proc_start}" > "${control_file}"
  : > "${lock_file}"
  : > "${events}"
  export BROLIT_JOB_ID="${job_id}"
  export BROLIT_JOB_CONTROL_DIR="${control_dir}"

  (
    exec 9< "${lock_file}" || exit 1
    flock --exclusive 9 || exit 1
    printf 'check:%s\n' "$(awk '{print $3}' "${control_file}")" > "${events}"
    : > "${lock_held}"
    while [[ ! -e ${lock_release} ]]; do
      sleep 0.01
    done
    printf 'TERM:cancellable\n' >> "${events}"
  ) &
  holder_pid=$!

  for ((attempt = 0; attempt < 500; attempt++)); do
    [[ -e ${lock_held} ]] && break
    sleep 0.01
  done
  if [[ ! -e ${lock_held} ]]; then
    _job_control_assert_equal "present" "absent" \
      "Admin-like canceller acquired the lock" || failed=1
    : > "${lock_release}"
    wait "${holder_pid}" 2>/dev/null || true
    return 1
  fi

  (
    function flock() {
      : > "${lock_attempted}"
      command flock "$@" || return 1
      : > "${lock_acquired}"
    }
    brolit_job_control_mark_noncancellable || exit 1
    : > "${transition_completed}"
  ) &
  transition_pid=$!

  for ((attempt = 0; attempt < 500; attempt++)); do
    [[ -e ${lock_attempted} ]] && break
    sleep 0.01
  done
  sleep 0.05

  if [[ -e ${lock_attempted} ]]; then actual="present"; else actual="absent"; fi
  _job_control_assert_equal "present" "${actual}" \
    "strict transition attempts the shared flock" || failed=1
  if [[ -e ${lock_acquired} ]]; then actual="acquired"; else actual="blocked"; fi
  _job_control_assert_equal "blocked" "${actual}" \
    "transition cannot acquire Admin's held lock" || failed=1
  if [[ -e ${transition_completed} ]]; then actual="completed"; else actual="blocked"; fi
  _job_control_assert_equal "blocked" "${actual}" \
    "transition cannot complete during check-and-TERM" || failed=1

  : > "${lock_release}"
  if wait "${holder_pid}"; then holder_rc=0; else holder_rc=$?; fi
  if wait "${transition_pid}"; then transition_rc=0; else transition_rc=$?; fi

  _job_control_assert_equal "0" "${holder_rc}" \
    "Admin-like canceller released the lock cleanly" || failed=1
  _job_control_assert_equal "0" "${transition_rc}" \
    "waiting transition completed after lock release" || failed=1
  if [[ -e ${lock_acquired} ]]; then actual="acquired"; else actual="absent"; fi
  _job_control_assert_equal "acquired" "${actual}" \
    "transition acquired the lock after check-and-TERM" || failed=1
  _job_control_assert_equal $'check:cancellable\nTERM:cancellable' "$(< "${events}")" \
    "simulated cancellation finished inside its lock critical section" || failed=1
  _job_control_assert_equal "${pid} ${proc_start} noncancellable" "$(< "${control_file}")" \
    "serialized transition eventually wrote noncancellable" || failed=1

  return "${failed}"

}

################################################################################
# Run all job-control tests in isolated subshells.
#
# Arguments:
#   none
#
# Outputs:
#   0 when all tests pass, 1 otherwise.
################################################################################

function test_job_control() {

  local test_root
  local failed=0

  test_root="$(mktemp -d)" || return 1

  ( _job_control_state_tests "${test_root}" ) || failed=1
  ( _job_control_migration_tests "${test_root}" ) || failed=1
  ( _job_control_concurrency_tests "${test_root}" ) || failed=1

  rm --recursive --force -- "${test_root}"

  if [[ ${failed} -eq 0 ]]; then
    printf 'job control tests passed\n'
  fi

  return "${failed}"

}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  test_job_control
fi
