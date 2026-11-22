#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
################################################################################
#
# Job Control Helper: atomically updates the phase in an Admin-owned job control
# file. Missing, malformed, or stale control state is always a safe no-op for
# cancellable markers; noncancellable markers fail strictly for existing files.
#
################################################################################

################################################################################
# Private: update the phase of the current Admin job without changing its
# process identity. The launcher remains responsible for creating and removing
# the control and lock files; this helper never creates either file.
#
# The subshell owns the lock descriptor, so every return releases the descriptor
# and its flock. The lock covers the complete read/validate/write transition and
# serializes shell transitions with Admin's check-and-TERM critical section.
#
# Arguments:
#   ${1} = ${new_state} ("cancellable" or "noncancellable")
#
# Outputs:
#   0 for a successful transition or a manual/missing-control no-op; 1 for an
#   invalid existing control file, lock failure, identity mismatch, or write
#   failure. The cancellable public wrapper deliberately ignores failures.
################################################################################

function _brolit_job_control_set_state() (

  local new_state="${1}"
  local job_id="${BROLIT_JOB_ID:-}"
  # The override keeps tests away from /run. It must name an existing,
  # non-symlink absolute directory other than the filesystem root.
  local control_dir="${BROLIT_JOB_CONTROL_DIR:-/run}"
  local control_file
  local lock_file
  local lock_fd
  local pid=""
  local proc_start=""
  local previous_state=""
  local extra=""
  local current_start=""
  local temp_file=""
  local -a control_lines=()

  [[ ${new_state} == "cancellable" || ${new_state} == "noncancellable" ]] || return 1
  [[ ${job_id} =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$ ]] || return 0
  [[ ${control_dir} == /* && ${control_dir} != "/" && ${control_dir} != *$'\n'* && ${control_dir} != *$'\r'* ]] || return 0
  [[ -d ${control_dir} && ! -L ${control_dir} ]] || return 0

  control_file="${control_dir}/brolit-job-${job_id}.control"
  lock_file="${control_dir}/brolit-job-${job_id}.lock"

  # A normal shell run has no Admin control file and must remain unaffected.
  # Once a control file exists, however, every validation or lock failure is
  # significant: the noncancellable caller must not enter a restore phase.
  [[ -e ${control_file} || -L ${control_file} ]] || return 0
  [[ -f ${control_file} && ! -L ${control_file} && -r ${control_file} ]] || return 1
  [[ -f ${lock_file} && ! -L ${lock_file} && -r ${lock_file} ]] || return 1

  # Opening for read does not create an absent lock file. Linux flock supports
  # exclusive locks on read-only descriptors; root-only launch permissions stay
  # unchanged. The subshell closes lock_fd on every success and error path.
  if ! { exec {lock_fd}< "${lock_file}"; } 2>/dev/null; then
    return 1
  fi
  if ! flock --exclusive "${lock_fd}" 2>/dev/null; then
    return 1
  fi

  # Exactly one record is allowed. Rewriting malformed content could turn an
  # invalid file into a cancellation authorization, so malformed input is left
  # untouched instead. All state reads occur after acquiring the shared lock.
  if ! mapfile -t control_lines < "${control_file}" 2>/dev/null; then
    return 1
  fi
  [[ ${#control_lines[@]} -eq 1 ]] || return 1
  IFS=' ' read -r pid proc_start previous_state extra <<< "${control_lines[0]}"

  [[ -z ${extra} ]] || return 1
  [[ ${pid} =~ ^[1-9][0-9]*$ ]] || return 1
  [[ ${proc_start} =~ ^[0-9]+$ ]] || return 1
  [[ ${previous_state} == "cancellable" || ${previous_state} == "noncancellable" ]] || return 1
  [[ ${control_lines[0]} == "${pid} ${proc_start} ${previous_state}" ]] || return 1
  [[ -r /proc/${pid}/stat ]] || return 1

  if ! current_start="$(awk '{print $22}' "/proc/${pid}/stat" 2>/dev/null)"; then
    return 1
  fi
  [[ ${current_start} =~ ^[0-9]+$ && ${current_start} == "${proc_start}" ]] || return 1

  [[ ${previous_state} == "${new_state}" ]] && return 0

  # mktemp creates a root-only file in the same directory, making the final
  # rename atomic. PID and start-time are copied verbatim from the validated
  # launcher record rather than replaced with this shell's identity.
  if ! temp_file="$(mktemp "${control_dir}/.brolit-job-${job_id}.control.XXXXXX" 2>/dev/null)"; then
    return 1
  fi
  if ! printf '%s %s %s\n' "${pid}" "${proc_start}" "${new_state}" > "${temp_file}" 2>/dev/null; then
    rm --force -- "${temp_file}" 2>/dev/null || true
    return 1
  fi
  if ! mv --force -- "${temp_file}" "${control_file}" 2>/dev/null; then
    rm --force -- "${temp_file}" 2>/dev/null || true
    return 1
  fi

  return 0

)

################################################################################
# Mark the current job phase as safe for Admin to cancel. Failures leave the
# previous state intact and therefore remain deny-by-default.
#
# Arguments:
#   none
#
# Outputs:
#   Always returns 0; missing or invalid job control state is a no-op.
################################################################################

function brolit_job_control_mark_cancellable() {

  _brolit_job_control_set_state "cancellable" || true
  return 0

}

################################################################################
# Mark the current job phase as not safe for Admin to cancel. Manual runs with
# no job ID/control file are no-ops. Existing Admin state must pass all lock,
# identity, validation, and write checks or this function returns failure.
#
# Arguments:
#   none
#
# Outputs:
#   0 for a successful transition or manual no-op, 1 on strict failure.
################################################################################

function brolit_job_control_mark_noncancellable() {

  _brolit_job_control_set_state "noncancellable"

}
