#!/usr/bin/env bash
# When the mounts backup cannot establish coverage, the failure must say WHY and
# the reason must reach the mail, so a sysadmin can decide. The classifier that
# guards deletions stays exactly as strict as before.
#
# Real case (tukiverse-dev01, 2026-11-21): containers made with `docker run`
# mount a path inside a Compose project; they carry no Compose project label, so
# coverage "could not be established" every night with no explanation.
#
# Docker is a fake on PATH driven by fixture files; no daemon, no host data.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
SAVED_PATH="${PATH}"
trap 'PATH="${SAVED_PATH}"; rm -rf "${TMP}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

# Only what the functions under test call.
log_event() { echo "${1}: ${2}" >>"${TMP}/log"; }
display() { :; }
log_subsection() { :; }
# shellcheck disable=SC1091
source "${ROOT_DIR}/libs/local/project_helper.sh"
# shellcheck disable=SC1091
source "${ROOT_DIR}/libs/local/backup_helper.sh"
# Redefine after sourcing: the real helpers would have replaced these.
log_event() { echo "${1}: ${2}" >>"${TMP}/log"; }
display() { :; }
log_subsection() { :; }

PROJECT="${TMP}/projects/site.example.com"
mkdir -p "${PROJECT}" "${TMP}/bin"
: >"${PROJECT}/docker-compose.yml"
export FAKE_RECORDS="${TMP}/records" FAKE_PS_FAIL=0 FAKE_INSPECT_FAIL=0
: >"${FAKE_RECORDS}"

cat >"${TMP}/bin/docker" <<'FAKE'
#!/usr/bin/env bash
case "${1:-}" in
  ps)
    [[ "${FAKE_PS_FAIL:-0}" == "1" ]] && exit 1
    [[ -s "${FAKE_RECORDS}" ]] || exit 0
    echo "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    ;;
  inspect)
    [[ "${FAKE_INSPECT_FAIL:-0}" == "1" ]] && exit 1
    cat "${FAKE_RECORDS}"
    ;;
  volume) exit 0 ;;
esac
FAKE
chmod +x "${TMP}/bin/docker"
PATH="${TMP}/bin:${PATH}"

ID1="1111111111111111111111111111111111111111111111111111111111111111"
ID2="2222222222222222222222222222222222222222222222222222222222222222"
ID3="3333333333333333333333333333333333333333333333333333333333333333"
rec() { jq -n -c "$@"; }
# A container Compose created, with a bind inside the project.
compose_rec() { rec --arg id "${ID1}" --arg dir "${PROJECT}" '{id:$id,name:"/site-app-1",project:"site",working_dir:$dir,mounts:[{Type:"bind",Source:($dir+"/data"),Destination:"/data"}]}'; }
# The real case: made with docker run, no Compose labels, bind inside the project.
adhoc_rec() { rec --arg id "${2}" --arg name "${1}" --arg dir "${PROJECT}" '{id:$id,name:$name,project:null,working_dir:null,mounts:[{Type:"bind",Source:($dir+"/data/convex"),Destination:"/convex"}]}'; }

# --- the gate is still strict: an unlabelled container mounting the project is ambiguous (2)
{ compose_rec; adhoc_rec "/amazing_carson" "${ID2}"; } >"${FAKE_RECORDS}"
project_compose_mount_coverage "${PROJECT}" json >/dev/null 2>&1; rc=$?
[[ ${rc} -eq 2 ]] || fail "the gate must keep answering 2 for an ambiguous context, got ${rc}"

# --- the explanation names the container, the labels and the path
out="$(project_compose_mount_coverage_explain "${PROJECT}")"
[[ "${out}" == *"Container amazing_carson was not created by Docker Compose"* ]] || fail "explain must name the container: ${out}"
[[ "${out}" == *"project label: none"* && "${out}" == *"working directory label: none"* ]] || fail "explain must show the missing labels: ${out}"
[[ "${out}" == *"${PROJECT}/data/convex"* ]] || fail "explain must show the mounted path: ${out}"
[[ "${out}" == *"Remove it, or create it with Docker Compose"* ]] || fail "explain must say what to decide: ${out}"
[[ "${out}" != *"site-app-1"* ]] || fail "a Compose-managed container is not a cause: ${out}"

# --- several offenders, one line each
{ compose_rec; adhoc_rec "/amazing_carson" "${ID2}"; adhoc_rec "/tg-module-guard-collector" "${ID3}"; } >"${FAKE_RECORDS}"
out="$(project_compose_mount_coverage_explain "${PROJECT}")"
[[ "$(echo "${out}" | grep -c '^Container ')" == "2" ]] || fail "two offenders must give two lines: ${out}"
[[ "${out}" == *"tg-module-guard-collector"* ]] || fail "second offender missing: ${out}"

# --- partly labelled (a working_dir but no project label) is also named
rec --arg id "${ID2}" --arg dir "${PROJECT}" '{id:$id,name:"/half",project:null,working_dir:$dir,mounts:[]}' >"${FAKE_RECORDS}"
out="$(project_compose_mount_coverage_explain "${PROJECT}")"
[[ "${out}" == *"Container half was not created by Docker Compose"* && "${out}" == *"it uses the directory of this project"* ]] || fail "a working_dir-only container must be explained: ${out}"

# --- a container unrelated to the project is not blamed
rec --arg id "${ID2}" '{id:$id,name:"/elsewhere",project:null,working_dir:null,mounts:[{Type:"bind",Source:"/srv/other",Destination:"/x"}]}' >"${FAKE_RECORDS}"
out="$(project_compose_mount_coverage_explain "${PROJECT}")"
[[ "${out}" != *"elsewhere"* ]] || fail "an unrelated container must not be blamed: ${out}"
[[ "${out}" == *"reason this check does not name"* ]] || fail "with no named cause it must say so, not stay silent: ${out}"

# --- other causes
: >"${FAKE_RECORDS}"; compose_rec >"${FAKE_RECORDS}"
out="$(FAKE_PS_FAIL=1 project_compose_mount_coverage_explain "${PROJECT}")"
[[ "${out}" == *"docker ps failed"* ]] || fail "docker ps failure must be named: ${out}"
out="$(FAKE_INSPECT_FAIL=1 project_compose_mount_coverage_explain "${PROJECT}")"
[[ "${out}" == *"docker inspect failed for container 0123456789ab"* ]] || fail "inspect failure must be named: ${out}"
printf 'COMPOSE_FILE=a.yml:b.yml\n' >"${PROJECT}/.env"
out="$(project_compose_mount_coverage_explain "${PROJECT}")"
[[ "${out}" == *"sets COMPOSE_FILE"* ]] || fail "COMPOSE_FILE must be named: ${out}"
rm -f "${PROJECT}/.env"
out="$(project_compose_mount_coverage_explain "${TMP}/missing")"
[[ "${out}" == "The project directory does not exist." ]] || fail "missing directory: ${out}"

# --- nothing but printable text leaves it, whatever a label contains
rec --arg id "${ID2}" --arg dir "${PROJECT}" "{id:\$id,name:\"/evil\",project:null,working_dir:null,mounts:[{Type:\"bind\",Source:(\$dir+\"/x\"+\"\\u001b[31m\\u0007\"),Destination:\"/x\"}]}" >"${FAKE_RECORDS}"
out="$(project_compose_mount_coverage_explain "${PROJECT}")"
[[ "$(printf '%s' "${out}" | LC_ALL=C tr -d '[:print:]\n' | wc -c)" == "0" ]] || fail "control characters must be stripped"

# --- the mounts backup records the reason when the gate cannot decide
export PROJECTS_PATH="${TMP}/projects" BROLIT_TMP_DIR="${TMP}/tmp" NOW="2026-11-21" SERVER_NAME="srv"
mkdir -p "${BROLIT_TMP_DIR}/${NOW}"
project_compose_mounts_backup_enabled() { return 0; }
{ compose_rec; adhoc_rec "/amazing_carson" "${ID2}"; } >"${FAKE_RECORDS}"
: >"${TMP}/log"
project_compose_backup_mounts "site.example.com"; rc=$?
[[ ${rc} -eq 1 ]] || fail "the mounts backup must still fail when coverage is ambiguous, got ${rc}"
[[ "${PROJECT_MOUNTS_FAILURE_REASON[site.example.com]:-}" == *"amazing_carson"* ]] || fail "the reason must be recorded for the mail"
grep -q "error: Mounts backup for site.example.com: coverage could not be established" "${TMP}/log" || fail "the original error line must stay"
grep -q "error: Mounts backup for site.example.com: Container amazing_carson" "${TMP}/log" || fail "the reason must be in the log too"

# --- the mail carries it, escaped, and only when something failed
MAIL_ARGS="${TMP}/mail-args"
mail_backup_section() { printf '%s' "${1}" >"${MAIL_ARGS}"; }
get_all_directories() { echo "${PROJECTS_PATH}/site.example.com"; }
project_is_ignored() { echo false; }
project_get_install_type() { echo docker-compose; }
BACKUP_FILES_MAIL_LIST=(); BACKUP_FILES_MAIL_ERRORS=(); BACKUP_FILES_MAIL_NOTES=()
project_compose_backup_mounts() { PROJECT_MOUNTS_FAILURE_REASON["${1}"]=$'Container <b>evil</b> & co mounts a path.\nSecond line "quoted".'; return 1; }
backup_all_projects_mounts; rc=$?
[[ ${rc} -eq 1 ]] || fail "backup_all_projects_mounts must report the failure, got ${rc}"
backup_files_mail_render
msg="$(cat "${MAIL_ARGS}")"
[[ "${msg}" == "Error creating backup file for: site.example.com (mounts)"* ]] || fail "the error line must stay first: ${msg}"
[[ "${msg}" == *"Why it failed, and what a sysadmin has to decide:"* ]] || fail "the mail must introduce the reason: ${msg}"
[[ "${msg}" == *"site.example.com: Container &lt;b&gt;evil&lt;/b&gt; &amp; co mounts a path.<br />Second line &quot;quoted&quot;."* ]] || fail "the reason must be HTML-escaped with line breaks kept: ${msg}"
[[ "${msg}" != *"<b>evil</b>"* ]] || fail "unescaped HTML reached the mail"
[[ ${#BACKUP_FILES_MAIL_NOTES[@]} -eq 0 && ${#BACKUP_FILES_MAIL_ERRORS[@]} -eq 0 ]] || fail "the accumulators must be reset after rendering"
[[ -z "${PROJECT_MOUNTS_FAILURE_REASON[site.example.com]:-}" ]] || fail "the recorded reason must be consumed"

# a failure the mounts backup does not explain still points to the log
project_compose_backup_mounts() { return 1; }
backup_all_projects_mounts >/dev/null
backup_files_mail_render
msg="$(cat "${MAIL_ARGS}")"
[[ "${msg}" == *"site.example.com: the mounts backup failed; the log of the run has the detail."* ]] || fail "an unexplained failure must point to the log: ${msg}"

# a clean night adds nothing
project_compose_backup_mounts() { return 0; }
backup_all_projects_mounts
backup_files_mail_render
[[ "$(cat "${MAIL_ARGS}")" == "none" ]] || fail "no error, no reason: $(cat "${MAIL_ARGS}")"

echo "mounts coverage reason tests passed"
