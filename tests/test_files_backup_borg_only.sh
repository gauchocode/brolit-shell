#!/usr/bin/env bash
# The compressed files backup of the sites needs Dropbox, SFTP or Local. A host
# where Borg is the only enabled method used to report "Files Backup: ERROR"
# every night, with no message, although Borg had backed the sites up
# (spyglass-hccx13use, 2026-11). It must be skipped there, and still be an error
# (with the reason) when NO method is enabled, and unchanged otherwise.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# shellcheck disable=SC1091
source "${ROOT_DIR}/libs/local/backup_helper.sh"
log_event() { echo "${1}: ${2}" >>"${TMP}/log"; }
display() { :; }
log_subsection() { :; }
log_break() { :; }
get_all_directories() { printf '%s\n' "${PROJECTS_PATH}/shop.example.com" "${PROJECTS_PATH}/html"; }
project_is_ignored() { [[ "${1}" == "html" ]] && echo true || echo false; }
backup_project_files() { echo "called ${3}" >>"${TMP}/calls"; printf '%s' "${FAKE_FILES_SIZE-1.5 MiB}"; }
MAIL="${TMP}/mail"
mail_backup_section() { printf '%s\n' "${1}" >"${MAIL}"; printf '%s\n' "${@:4}" >>"${MAIL}"; }

export PROJECTS_PATH="${TMP}/www" BROLIT_TMP_DIR="${TMP}/tmp" NOW="2026-11-21"
mkdir -p "${PROJECTS_PATH}" "${BROLIT_TMP_DIR}/${NOW}"

reset() {
  : >"${TMP}/log"; : >"${TMP}/calls"; : >"${MAIL}"
  BACKUP_FILES_MAIL_LIST=(); BACKUP_FILES_MAIL_ERRORS=(); BACKUP_FILES_MAIL_NOTES=()
  BACKUP_DROPBOX_STATUS=disabled BACKUP_SFTP_STATUS=disabled BACKUP_LOCAL_STATUS=disabled BACKUP_BORG_STATUS=disabled
  unset FAKE_FILES_SIZE
}

# --- Borg is the only method: skipped, not an error, nothing is called
reset; BACKUP_BORG_STATUS=enabled
backup_all_projects_files; rc=$?
[[ ${rc} -eq 0 ]] || fail "Borg-only must not fail, got rc=${rc}"
[[ ${#BACKUP_FILES_MAIL_ERRORS[@]} -eq 0 ]] || fail "Borg-only must record no error: ${BACKUP_FILES_MAIL_ERRORS[*]}"
[[ "${BACKUP_FILES_MAIL_LIST[*]}" == *"(Borg is the only enabled method);SKIPPED"* ]] || fail "the mail list must say it was skipped: ${BACKUP_FILES_MAIL_LIST[*]}"
[[ ! -s "${TMP}/calls" ]] || fail "no compressed backup may be attempted: $(cat "${TMP}/calls")"
grep -q "info: No compression backup method enabled.*Borg covers them" "${TMP}/log" || fail "the skip must be logged"
backup_files_mail_render
[[ "$(head -1 "${MAIL}")" == "none" ]] || fail "the mail section must be OK, got: $(head -1 "${MAIL}")"
grep -q "SKIPPED" "${MAIL}" || fail "the mail must list the skipped item"

# --- no method at all: an error, with the reason
reset
backup_all_projects_files; rc=$?
[[ ${rc} -eq 1 ]] || fail "no method at all must fail, got rc=${rc}"
[[ "${BACKUP_FILES_MAIL_ERRORS[*]}" == *"no backup method enabled"* ]] || fail "the error must be recorded: ${BACKUP_FILES_MAIL_ERRORS[*]}"
grep -q "error: No backup method is enabled" "${TMP}/log" || fail "the error must be logged"
backup_files_mail_render
msg="$(head -1 "${MAIL}")"
[[ "${msg}" == *"Why it failed, and what a sysadmin has to decide:"* && "${msg}" == *"Enable one."* ]] || fail "the mail must carry the reason: ${msg}"

# --- a normal host is unchanged: each non-ignored site is backed up and listed
reset; BACKUP_DROPBOX_STATUS=enabled; BACKUP_BORG_STATUS=enabled
backup_all_projects_files; rc=$?
[[ ${rc} -eq 1 || ${rc} -eq 0 ]] || fail "unexpected rc ${rc}"
[[ "$(cat "${TMP}/calls")" == "called shop.example.com" ]] || fail "only the non-ignored site is backed up: $(cat "${TMP}/calls")"
[[ "${BACKUP_FILES_MAIL_LIST[*]}" == "shop.example.com;1.5 MiB" && ${#BACKUP_FILES_MAIL_ERRORS[@]} -eq 0 ]] || fail "the site must be listed with its size: ${BACKUP_FILES_MAIL_LIST[*]} / ${BACKUP_FILES_MAIL_ERRORS[*]}"

# --- a REAL failure with a method enabled is still an error
reset; BACKUP_LOCAL_STATUS=enabled; FAKE_FILES_SIZE=""
backup_all_projects_files >/dev/null 2>&1
[[ "${BACKUP_FILES_MAIL_ERRORS[*]}" == "shop.example.com" ]] || fail "an empty result with a method enabled must stay an error: ${BACKUP_FILES_MAIL_ERRORS[*]}"

echo "files backup borg-only tests passed"
