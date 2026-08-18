#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.13
################################################################################
#
# User Manager: create/delete system users, manage sudo membership and
# authorized_keys entries for the "user" task (see libs/task_runner.sh).
#
# The private key is never handled here: brolit-admin generates the keypair
# on its worker and only ever sends this host the public key.
#
################################################################################

USER_MANAGER_USERNAME_RE='^[a-z_][a-z0-9_-]{0,31}$'

################################################################################
# Validate a username against the standard Linux username pattern.
#
# Arguments:
#   ${1} = ${username}
#
# Outputs:
#   0 if valid, 1 on error
################################################################################

function user_manager_validate_username() {

  local username="${1}"

  if [[ -z "${username}" ]] || [[ ! "${username}" =~ ${USER_MANAGER_USERNAME_RE} ]]; then
    log_event "error" "Invalid username: '${username}'" "true"
    display --indent 6 --text "- Invalid username" --result "FAIL" --color RED
    return 1
  fi

  return 0

}

################################################################################
# Create a system user (no password login; SSH keys only).
#
# Arguments:
#   ${1} = ${username}
#   ${2} = ${grant_sudo} - "true" or "false"
#
# Outputs:
#   0 if the user was created, 1 on error
################################################################################

function brolit_user_create() {

  local username="${1}"
  local grant_sudo="${2:-false}"

  user_manager_validate_username "${username}" || return 1

  if id "${username}" &>/dev/null; then
    log_event "error" "User '${username}' already exists" "true"
    display --indent 6 --text "- Create system user" --result "FAIL" --color RED
    return 1
  fi

  # Non-interactive, no password login (key-only access).
  adduser --disabled-password --gecos "" "${username}"

  exitstatus=$?
  if [[ ${exitstatus} -ne 0 ]]; then
    log_event "error" "Failed to create system user: ${username}" "true"
    display --indent 6 --text "- Create system user" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- Create system user" --result "DONE" --color GREEN
  log_event "info" "System user created: ${username}"

  if [[ "${grant_sudo}" == "true" ]]; then
    brolit_user_grant_sudo "${username}"
    exitstatus=$?
    [[ ${exitstatus} -ne 0 ]] && return 1
  fi

  return 0

}

################################################################################
# Delete a system user and its home directory.
#
# Arguments:
#   ${1} = ${username}
#
# Outputs:
#   0 if deleted, 1 on error
################################################################################

function brolit_user_delete() {

  local username="${1}"

  user_manager_validate_username "${username}" || return 1

  if ! id "${username}" &>/dev/null; then
    log_event "error" "User '${username}' does not exist" "true"
    display --indent 6 --text "- Delete system user" --result "FAIL" --color RED
    return 1
  fi

  # Non-interactive: no whiptail prompt, this task only runs headless via runner.sh.
  userdel --remove "${username}"

  exitstatus=$?
  if [[ ${exitstatus} -ne 0 ]]; then
    log_event "error" "Failed to delete system user: ${username}" "true"
    display --indent 6 --text "- Delete system user" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- Delete system user" --result "DONE" --color GREEN
  log_event "info" "System user deleted: ${username}" "false"

  return 0

}

################################################################################
# Add a user to the sudo group.
#
# Arguments:
#   ${1} = ${username}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function brolit_user_grant_sudo() {

  local username="${1}"

  user_manager_validate_username "${username}" || return 1

  if ! id "${username}" &>/dev/null; then
    log_event "error" "User '${username}' does not exist" "true"
    display --indent 6 --text "- Grant sudo" --result "FAIL" --color RED
    return 1
  fi

  usermod -aG sudo "${username}"

  exitstatus=$?
  if [[ ${exitstatus} -ne 0 ]]; then
    log_event "error" "Failed to grant sudo to: ${username}" "true"
    display --indent 6 --text "- Grant sudo" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- Grant sudo to ${username}" --result "DONE" --color GREEN
  log_event "info" "Sudo granted to: ${username}"

  return 0

}

################################################################################
# Remove a user from the sudo group.
#
# Arguments:
#   ${1} = ${username}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function brolit_user_revoke_sudo() {

  local username="${1}"

  user_manager_validate_username "${username}" || return 1

  if ! id "${username}" &>/dev/null; then
    log_event "error" "User '${username}' does not exist" "true"
    display --indent 6 --text "- Revoke sudo" --result "FAIL" --color RED
    return 1
  fi

  # gpasswd returns non-zero if the user is not a member; treat that as success.
  if ! id -nG "${username}" | tr ' ' '\n' | grep -qx "sudo"; then
    display --indent 6 --text "- Revoke sudo from ${username}" --result "SKIPPED" --color YELLOW
    return 0
  fi

  gpasswd -d "${username}" sudo

  exitstatus=$?
  if [[ ${exitstatus} -ne 0 ]]; then
    log_event "error" "Failed to revoke sudo from: ${username}" "true"
    display --indent 6 --text "- Revoke sudo" --result "FAIL" --color RED
    return 1
  fi

  display --indent 6 --text "- Revoke sudo from ${username}" --result "DONE" --color GREEN
  log_event "info" "Sudo revoked from: ${username}"

  return 0

}

################################################################################
# Append a public SSH key to a user's authorized_keys.
#
# Arguments:
#   ${1} = ${username}
#   ${2} = ${json_file} - path to a JSON file with a "public_key" field
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function brolit_user_add_key() {

  local username="${1}"
  local json_file="${2}"

  local user_home
  local ssh_dir
  local auth_keys
  local public_key
  local fingerprint

  user_manager_validate_username "${username}" || return 1

  if ! id "${username}" &>/dev/null; then
    log_event "error" "User '${username}' does not exist" "true"
    display --indent 6 --text "- Add SSH key" --result "FAIL" --color RED
    return 1
  fi

  if [[ ! -f "${json_file}" ]]; then
    log_event "error" "Key payload file not found: ${json_file}" "true"
    display --indent 6 --text "- Add SSH key" --result "FAIL" --color RED
    return 1
  fi

  public_key="$(json_read_field "${json_file}" "public_key")"

  if [[ -z "${public_key}" ]]; then
    log_event "error" "Key payload missing 'public_key' field" "true"
    display --indent 6 --text "- Add SSH key" --result "FAIL" --color RED
    return 1
  fi

  user_home="$(getent passwd "${username}" | cut -d: -f6)"
  ssh_dir="${user_home}/.ssh"
  auth_keys="${ssh_dir}/authorized_keys"

  mkdir -p "${ssh_dir}"
  touch "${auth_keys}"

  if grep -qF "${public_key}" "${auth_keys}" 2>/dev/null; then
    display --indent 6 --text "- Add SSH key" --result "ALREADY EXISTS" --color YELLOW
    return 0
  fi

  echo "${public_key}" >>"${auth_keys}"

  chown -R "${username}:${username}" "${ssh_dir}"
  chmod 700 "${ssh_dir}"
  chmod 600 "${auth_keys}"

  fingerprint="$(ssh-keygen -lf /dev/stdin <<<"${public_key}" 2>/dev/null | awk '{print $2}')"

  display --indent 6 --text "- Add SSH key for ${username}" --result "DONE" --color GREEN
  log_event "info" "SSH key added for ${username} (${fingerprint})"

  return 0

}

################################################################################
# Remove a public SSH key from a user's authorized_keys by fingerprint.
#
# Arguments:
#   ${1} = ${username}
#   ${2} = ${fingerprint} - e.g. SHA256:abc123...
#
# Outputs:
#   0 on success (including "not found"), 1 on error
################################################################################

function brolit_user_remove_key() {

  local username="${1}"
  local fingerprint="${2}"

  local user_home
  local auth_keys
  local tmp_file
  local line
  local line_fp
  local removed="false"

  user_manager_validate_username "${username}" || return 1

  if [[ -z "${fingerprint}" ]]; then
    log_event "error" "Fingerprint is required to remove a key" "true"
    display --indent 6 --text "- Remove SSH key" --result "FAIL" --color RED
    return 1
  fi

  user_home="$(getent passwd "${username}" | cut -d: -f6)"
  auth_keys="${user_home}/.ssh/authorized_keys"

  if [[ ! -f "${auth_keys}" ]]; then
    display --indent 6 --text "- Remove SSH key" --result "NOT FOUND" --color YELLOW
    return 0
  fi

  tmp_file="$(mktemp)"

  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    line_fp="$(ssh-keygen -lf /dev/stdin <<<"${line}" 2>/dev/null | awk '{print $2}')"
    if [[ "${line_fp}" == "${fingerprint}" ]]; then
      removed="true"
      continue
    fi
    echo "${line}" >>"${tmp_file}"
  done <"${auth_keys}"

  cat "${tmp_file}" >"${auth_keys}"
  rm -f "${tmp_file}"
  chmod 600 "${auth_keys}"

  if [[ "${removed}" == "true" ]]; then
    display --indent 6 --text "- Remove SSH key for ${username}" --result "DONE" --color GREEN
    log_event "info" "SSH key removed for ${username} (${fingerprint})"
  else
    display --indent 6 --text "- Remove SSH key" --result "NOT FOUND" --color YELLOW
  fi

  return 0

}

################################################################################
# List a user's authorized_keys as JSON.
#
# Arguments:
#   ${1} = ${username}
#
# Outputs:
#   JSON array of {type, comment, fingerprint} to stdout
################################################################################

function brolit_user_list_keys() {

  local username="${1}"

  local user_home
  local auth_keys
  local line
  local type
  local comment
  local fingerprint
  local entries="[]"

  user_manager_validate_username "${username}" || return 1

  user_home="$(getent passwd "${username}" | cut -d: -f6)"
  auth_keys="${user_home}/.ssh/authorized_keys"

  if [[ ! -f "${auth_keys}" ]]; then
    echo "${entries}"
    return 0
  fi

  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    type="$(awk '{print $1}' <<<"${line}")"
    comment="$(cut -d' ' -f3- <<<"${line}")"
    fingerprint="$(ssh-keygen -lf /dev/stdin <<<"${line}" 2>/dev/null | awk '{print $2}')"
    entries="$(jq --arg type "${type}" --arg comment "${comment}" --arg fingerprint "${fingerprint}" \
      '. + [{type: $type, comment: $comment, fingerprint: $fingerprint}]' <<<"${entries}")"
  done <"${auth_keys}"

  echo "${entries}"
  return 0

}

################################################################################
# List non-system users (UID >= 1000) with sudo membership as JSON.
#
# Arguments:
#   none
#
# Outputs:
#   JSON array of {username, has_sudo} to stdout
################################################################################

function brolit_user_list() {

  local username
  local uid
  local has_sudo
  local entries="[]"

  while IFS=: read -r username _ uid _ _ _ shell; do
    [[ ${uid} -lt 1000 ]] && continue
    [[ "${username}" == "nobody" ]] && continue

    if id -nG "${username}" 2>/dev/null | tr ' ' '\n' | grep -qx "sudo"; then
      has_sudo="true"
    else
      has_sudo="false"
    fi

    entries="$(jq --arg username "${username}" --argjson has_sudo "${has_sudo}" \
      '. + [{username: $username, has_sudo: $has_sudo}]' <<<"${entries}")"
  done </etc/passwd

  echo "${entries}"
  return 0

}
