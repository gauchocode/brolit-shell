#!/usr/bin/env bash
# Projects in BACKUPS.config[].projects[].ignored must not get a borgmatic config
# generated nor be backed up/warned about by the nightly. Real case (stellacast-vm,
# 2026-11-24): /var/www/tmp is ignored but failed config generation every night.
set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"; trap 'rm -rf "${TMP}"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

log_event() { :; }; display() { :; }; load_configurations() { :; }
project_is_ignored() { [[ " ${IGNORED:-} " == *" ${1} "* ]] && echo true || echo false; }
generate_borg_config() { echo "${1}" >>"${TMP}/called"; [[ "${1}" == tmp ]] && echo failed || echo created; }
sed -n '/^function generate_config() {/,/^}/p' "${ROOT_DIR}/cron/backups_tasks.sh" >"${TMP}/fn.sh"
# shellcheck disable=SC1091
source "${TMP}/fn.sh"

export PROJECTS_PATH="${TMP}/www" BACKUP_BORG_STATUS=enabled
mkdir -p "${PROJECTS_PATH}"/{shop.example.com,tmp,html}

IGNORED=""; : >"${TMP}/called"
generate_config >/dev/null 2>&1
grep -qx tmp "${TMP}/called" || fail "control: a non-ignored tmp must be processed"

IGNORED="tmp"; : >"${TMP}/called"
generate_config >/dev/null 2>&1
grep -qx tmp "${TMP}/called" && fail "an ignored project must not get a generated config"
grep -qx shop.example.com "${TMP}/called" || fail "regular projects must still be processed"

# the nightly project loop honours it too
grep -A4 'project_domain=$(basename "${project_dir}")' "${ROOT_DIR}/cron/backups_tasks.sh" | grep -q 'project_is_ignored' \
  || fail "the nightly project loop must skip ignored projects"
echo "backups_tasks ignored-projects tests passed"
