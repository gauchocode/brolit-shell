#!/usr/bin/env bash
# A Borg failure must say why in the mail, in plain words, and a missing yq must
# be repaired or named instead of surfacing as the unexplained class "config".
#
# Real case (spyglass-hccx13use, 2026-11): Borg was enabled before yq became a
# prerequisite, so the host had none; every project failed with
# "repository: config" and no backup ran, for days.
#
# Everything outside the functions under test is replaced; nothing touches the host.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

log_event() { echo "${1}: ${2}" >>"${TMP}/log"; }
display() { :; }

{
  sed -n '/^function borg_failure_reason_text() {/,/^}/p;/^function borg_note_failure() {/,/^}/p;/^function initialize_repository() {/,/^}/p' "${ROOT_DIR}/libs/borg_storage_controller.sh"
  sed -n '/^function backup_mail_notes_html() {/,/^}/p;/^function borg_mail_failure_title() {/,/^}/p' "${ROOT_DIR}/libs/local/backup_helper.sh"
} >"${TMP}/fns.sh"
# shellcheck disable=SC1091
source "${TMP}/fns.sh"

# --- one sentence per class, none empty, the fallback only for unknown ones
fallback="$(borg_failure_reason_text some-class-nobody-defined)"
for class in yq_missing missing_source config relocation lock stale_lock network parent_missing auth space python_env borgmatic_version encryption_mismatch repo_missing; do
  text="$(borg_failure_reason_text "${class}")"
  [[ -n "${text}" ]] || fail "class ${class} has no text"
  [[ "${text}" != "${fallback}" ]] || fail "class ${class} falls back to the generic text"
done
[[ "$(borg_failure_reason_text unknown)" == "${fallback}" && "$(borg_failure_reason_text)" == "${fallback}" ]] || fail "unknown/empty must use the fallback"
[[ "$(borg_failure_reason_text yq_missing)" == *"yq"*"Install"* ]] || fail "yq_missing must say what to install"
[[ "$(borg_failure_reason_text relocation)" == *"sysadmin has to confirm"* ]] || fail "relocation is a person's decision and must say so"

# --- the note carries the project, the sentence and the class code
BORG_FAILURE_NOTES=()
borg_note_failure "myspyglass.online" "config"
[[ "${BORG_FAILURE_NOTES[0]}" == "myspyglass.online: The borgmatic config is missing, cannot be read, lists no repositories or uses an undefined variable. [config]" ]] || fail "note shape: ${BORG_FAILURE_NOTES[0]}"

# --- initialize_repository and yq
CONFIG="${TMP}/proj.yml"; printf 'repositories:\n  - path: ssh://x/./r\n' >"${CONFIG}"
_borgmatic_resolve_cmd() { echo "/bin/true"; }
_initialize_repository_for_config() { echo "initialized" >>"${TMP}/calls"; return 0; }
run_init() { ( PATH=/nonexistent; initialize_repository "$@" ); }

# a. no yq and no installer function at all
: >"${TMP}/log"; unset -f yq yq_installer 2>/dev/null
BORG_INIT_FAILURE_REASON=""
( PATH=/nonexistent; initialize_repository "${CONFIG}"; echo "rc=$? reason=${BORG_INIT_FAILURE_REASON}" ) >"${TMP}/out" 2>&1
grep -q "rc=1 reason=yq_missing" "${TMP}/out" || fail "yq absent and no installer must give yq_missing: $(cat "${TMP}/out")"
grep -q "Repository init failure class: yq_missing" "${TMP}/log" || fail "the class must be logged"

# b. an installer that fails
yq_installer() { return 1; }
( PATH=/nonexistent; initialize_repository "${CONFIG}"; echo "rc=$? reason=${BORG_INIT_FAILURE_REASON}" ) >"${TMP}/out" 2>&1
grep -q "rc=1 reason=yq_missing" "${TMP}/out" || fail "a failing installer must give yq_missing: $(cat "${TMP}/out")"

# c. an installer that works: the run continues and says it repaired it
: >"${TMP}/log"; : >"${TMP}/calls"
yq_installer() { yq() { echo 1; }; return 0; }
( PATH=/nonexistent; initialize_repository "${CONFIG}"; echo "rc=$?" ) >"${TMP}/out" 2>&1
grep -q "rc=0" "${TMP}/out" || fail "a successful self-repair must let the init go on: $(cat "${TMP}/out")"
grep -q "yq was missing and has been installed" "${TMP}/log" || fail "the repair must be logged"

# d. a yq that is there and finds no repositories keeps the old class
yq() { echo 0; }
( PATH=/nonexistent; initialize_repository "${CONFIG}"; echo "rc=$? reason=${BORG_INIT_FAILURE_REASON}" ) >"${TMP}/out" 2>&1
grep -q "rc=1 reason=config" "${TMP}/out" || fail "no repositories must stay class config: $(cat "${TMP}/out")"
unset -f yq yq_installer

# --- the mail text
html="$(backup_mail_notes_html $'a <b> & "q"\nsecond' "other")"
[[ "${html}" == '<br />a &lt;b&gt; &amp; &quot;q&quot;<br />second<br />other' ]] || fail "escaping or line breaks wrong: ${html}"

BORG_FAILURE_NOTES=()
[[ "$(borg_mail_failure_title "p1 p2" "")" == "Borg backup failed for: p1 p2" ]] || fail "without notes the title is unchanged"
[[ "$(borg_mail_failure_title "p1" "network")" == "Borg backup failed for: p1 — repository unavailable (network)" ]] || fail "the breaker cause must stay"
borg_note_failure "p1" "yq_missing"
title="$(borg_mail_failure_title "p1" "")"
[[ "${title}" == "Borg backup failed for: p1<br /><br />Why it failed, and what a sysadmin has to decide:<br />p1: yq v4 is not installed"* ]] || fail "the reason must follow the title: ${title}"
BORG_FAILURE_NOTES=(); borg_note_failure "x<script>" "auth"
[[ "$(borg_mail_failure_title "x" "")" != *"<script>"* ]] || fail "unescaped HTML reached the title"

echo "borg failure reason tests passed"
