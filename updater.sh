#!/usr/bin/env bash
#
# Author: GauchoCode
# Version: 3.14
#
# Description: Moves the brolit-shell git tree to a release tag.
#
#   updater.sh status   [--fetch] [--root DIR]
#   updater.sh update   <vX.Y.Z>  [--root DIR]
#   updater.sh rollback [<commit>] [--root DIR]
#   updater.sh install  [<vX.Y.Z>] [--root DIR] [--repo URL] [--no-cron] [--cron-kinds "k1 k2"]
#
# `install` is the one way to put the shell on a server, from a terminal, from
# cloud-init or from brolit-admin: it clones the tree if it is missing, moves it
# to the tag (a pristine clone is repositioned; a tree with local commits is
# refused), syntax-checks it and installs the standard crons through
# `runner.sh --task cron-install` (default kinds: backups ui). With no tag it
# uses the newest release tag.
#
# A release is an annotated tag "vX.Y.Z" whose release/version.env declares the
# same version. An update only ever fast-forwards: it refuses a tree with
# modified tracked files, a detached HEAD, a tag that is not a descendant of
# the current commit, and a tag whose version does not match. After the merge
# every shell entry point is syntax-checked; on failure the tree goes back to
# the previous commit. The last line of output is machine readable:
#
#   UPDATER_RESULT status=<status> tag=<tag> commit=<sha> previous=<sha>
#
# Exit codes: 0 ok or already there, 2 usage, 3 refused (nothing changed),
#             4 verification failed (rolled back), 5 fetch/clone failed,
#             6 tree installed but a cron could not be installed.
################################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
ROOT_DIR="${SCRIPT_DIR}"
REMOTE="origin"
REPO_URL="https://github.com/gauchocode/brolit-shell"
CRON_KINDS="backups ui"
INSTALL_CRON="true"

readonly TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$'

################################################################################
# Prints usage and exits.
#
# Arguments:
#   none
#
# Outputs:
#   exits 2
################################################################################
function usage() {
  sed -n '/^#   updater.sh status/,/^#   updater.sh install /p' "${BASH_SOURCE[0]}" | sed 's/^#//' >&2
  exit 2
}

################################################################################
# Prints the machine readable result line.
#
# Arguments:
#   ${1} = ${status}
#   ${2} = ${tag}
#   ${3} = ${commit}
#   ${4} = ${previous}
#
# Outputs:
#   the UPDATER_RESULT line on stdout
################################################################################
function result_line() {
  echo "UPDATER_RESULT status=${1} tag=${2:--} commit=${3:--} previous=${4:--}"
}

################################################################################
# Refuses the operation: explains on stderr, prints the result line, exits 3.
#
# Arguments:
#   ${1} = ${reason}
#   ${2} = ${tag}
#
# Outputs:
#   exits 3
################################################################################
function refuse() {
  echo "updater: refused: ${1}" >&2
  result_line "refused" "${2:-}" "$(git -C "${ROOT_DIR}" rev-parse HEAD 2>/dev/null)" ""
  exit 3
}

################################################################################
# Appends one line to the update receipt (log/updater_receipt.log).
#
# Arguments:
#   ${1} = ${action}
#   ${2} = ${tag}
#   ${3} = ${previous}
#   ${4} = ${commit}
#   ${5} = ${result}
#
# Outputs:
#   none
################################################################################
function write_receipt() {
  mkdir -p -- "${ROOT_DIR}/log" 2>/dev/null || return 0
  printf '%s action=%s tag=%s previous=%s commit=%s result=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${1}" "${2:--}" "${3:--}" "${4:--}" "${5}" \
    >>"${ROOT_DIR}/log/updater_receipt.log" 2>/dev/null || true
}

################################################################################
# Syntax-checks the entry points, the cron scripts and the libraries.
#
# Arguments:
#   none
#
# Outputs:
#   0 if every file parses, 1 on the first failure (file named on stderr).
################################################################################
function verify_tree() {
  local file
  shopt -s nullglob
  for file in runner.sh brolit_lite.sh brolit_report.sh backup_observer.sh updater.sh \
    cron/*.sh libs/*.sh libs/*/*.sh utils/*.sh; do
    [[ -f "${ROOT_DIR}/${file}" ]] || continue
    if ! bash -n "${ROOT_DIR}/${file}" 2>/dev/null; then
      echo "updater: syntax check failed: ${file}" >&2
      shopt -u nullglob
      return 1
    fi
  done
  shopt -u nullglob
  return 0
}

################################################################################
# Reads the version declared by release/version.env at a given commit.
#
# Arguments:
#   ${1} = ${commit}
#
# Outputs:
#   the version on stdout (empty if absent)
################################################################################
function declared_version() {
  git -C "${ROOT_DIR}" show "${1}:release/version.env" 2>/dev/null |
    sed -n 's/^BROLIT_RELEASE_VERSION="\(.*\)"$/\1/p' | head -n 1
}

################################################################################
# Checks the tree is a git work tree on a branch with no modified tracked files.
#
# Arguments:
#   ${1} = ${tag} - only used to label a refusal
#
# Outputs:
#   returns normally when clean; refuses (exit 3) otherwise.
################################################################################
function require_clean_tree() {
  local tag="${1:-}"
  git -C "${ROOT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || refuse "${ROOT_DIR} is not a git work tree" "${tag}"
  git -C "${ROOT_DIR}" symbolic-ref --short -q HEAD >/dev/null 2>&1 || refuse "HEAD is detached; check out a branch first" "${tag}"
  local dirty
  dirty="$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=no)"
  if [[ -n "${dirty}" ]]; then
    echo "${dirty}" >&2
    refuse "tracked files are modified; review them (git diff) before updating" "${tag}"
  fi
}

################################################################################
# status: current version, commit and the release tags known locally.
#
# Arguments:
#   ${1} = ${fetch} - "fetch" to refresh tags from the remote first
#
# Outputs:
#   human readable summary and the result line; 0.
################################################################################
function cmd_status() {
  if [[ "${1:-}" == "fetch" ]]; then
    git -C "${ROOT_DIR}" fetch --tags --quiet "${REMOTE}" || { echo "updater: fetch failed" >&2; exit 5; }
  fi
  local head version
  head="$(git -C "${ROOT_DIR}" rev-parse HEAD 2>/dev/null || true)"
  version="$(declared_version HEAD)"
  echo "root:    ${ROOT_DIR}"
  echo "commit:  ${head:-unknown}"
  echo "version: ${version:-unknown}"
  echo "tracked changes: $(git -C "${ROOT_DIR}" status --porcelain --untracked-files=no 2>/dev/null | wc -l)"
  echo "release tags (newest first):"
  git -C "${ROOT_DIR}" tag --list 'v[0-9]*' --sort=-v:refname 2>/dev/null | head -n 10 | sed 's/^/  /'
  result_line "status" "v${version}" "${head}" ""
}

################################################################################
# Move the tree to a release tag. `update` only fast-forwards. `install` may
# also reposition a pristine tree (clean, no commits that are not on the remote)
# whose HEAD is ahead of the tag, which is what a fresh clone of master is.
#
# Arguments:
#   ${1} = ${tag} - may be empty for install (newest release tag is used)
#   ${2} = ${mode} - update|install
#
# Outputs:
#   0 moved or already at the tag; 3 refused; 4 rolled back; 5 fetch failed.
#   Exits; callers that need to continue run it in a subshell.
################################################################################
function move_tree() {
  local tag="${1:-}"
  local mode="${2:-update}"
  if [[ -n "${tag}" ]]; then
    [[ "${tag}" =~ ${TAG_RE} ]] || { echo "updater: a release tag like v3.14.24 is required" >&2; usage; }
  elif [[ "${mode}" != "install" ]]; then
    echo "updater: a release tag like v3.14.24 is required" >&2
    usage
  fi

  require_clean_tree "${tag}"

  local previous commit declared
  previous="$(git -C "${ROOT_DIR}" rev-parse HEAD)"

  # Without --force, git refuses to move a tag that already exists locally, so
  # a tag that was re-pointed upstream makes the fetch fail instead of silently
  # changing what a release means.
  git -C "${ROOT_DIR}" fetch --tags --quiet "${REMOTE}" || {
    echo "updater: fetch failed (network, or a release tag was moved upstream)" >&2
    result_line "fetch_failed" "${tag}" "${previous}" "${previous}"
    exit 5
  }

  if [[ -z "${tag}" ]]; then
    tag="$(git -C "${ROOT_DIR}" tag --list 'v[0-9]*' --sort=-v:refname | head -n 1)"
    [[ -n "${tag}" ]] || refuse "the repository has no release tags" ""
  fi

  git -C "${ROOT_DIR}" rev-parse -q --verify "refs/tags/${tag}" >/dev/null || refuse "unknown release tag ${tag}" "${tag}"
  [[ "$(git -C "${ROOT_DIR}" cat-file -t "refs/tags/${tag}")" == "tag" ]] || refuse "${tag} is not an annotated tag" "${tag}"

  commit="$(git -C "${ROOT_DIR}" rev-parse "refs/tags/${tag}^{commit}")"
  declared="$(declared_version "${commit}")"
  [[ "${declared}" == "${tag#v}" ]] || refuse "${tag} declares version '${declared:-none}' in release/version.env" "${tag}"

  if [[ "${previous}" == "${commit}" ]]; then
    echo "updater: already at ${tag} (${commit})"
    result_line "unchanged" "${tag}" "${commit}" "${previous}"
    exit 0
  fi

  if git -C "${ROOT_DIR}" merge-base --is-ancestor "${previous}" "${commit}"; then
    git -C "${ROOT_DIR}" merge --ff-only --quiet "${commit}" || refuse "fast-forward to ${tag} failed" "${tag}"
  elif [[ "${mode}" == "install" ]] && git -C "${ROOT_DIR}" merge-base --is-ancestor "${commit}" "${previous}"; then
    # HEAD is ahead of the tag. Only a pristine tree may be moved back to it.
    local branch unpushed
    branch="$(git -C "${ROOT_DIR}" symbolic-ref --short HEAD)"
    unpushed="$(git -C "${ROOT_DIR}" rev-list --count "${REMOTE}/${branch}..HEAD" 2>/dev/null || echo unknown)"
    [[ "${unpushed}" == "0" ]] ||
      refuse "the tree has commits that are not on ${REMOTE}/${branch} (${unpushed}); it cannot be repositioned to ${tag}" "${tag}"
    git -C "${ROOT_DIR}" reset --keep --quiet "${commit}" || refuse "could not reposition the tree to ${tag}" "${tag}"
  else
    refuse "${tag} is not a descendant of the current commit ${previous}; the history diverged or it is older" "${tag}"
  fi

  if ! verify_tree; then
    git -C "${ROOT_DIR}" reset --keep --quiet "${previous}"
    write_receipt "${mode}" "${tag}" "${previous}" "${commit}" "rolled_back"
    echo "updater: rolled back to ${previous}" >&2
    result_line "rolled_back" "${tag}" "${previous}" "${previous}"
    exit 4
  fi

  write_receipt "${mode}" "${tag}" "${previous}" "${commit}" "updated"
  echo "updater: ${previous} -> ${commit} (${tag}); rollback: updater.sh rollback ${previous}"
  result_line "updated" "${tag}" "${commit}" "${previous}"
}

################################################################################
# update: fast-forward the tree to a release tag.
#
# Arguments:
#   ${1} = ${tag}
#
# Outputs:
#   see move_tree.
################################################################################
function cmd_update() {
  move_tree "${1:-}" "update"
}

################################################################################
# install: the one way to put brolit-shell on a server. Clones the tree if it is
# missing, moves it to the tag, then installs the standard crons.
#
# Arguments:
#   ${1} = ${tag} - optional; the newest release tag when empty
#
# Outputs:
#   0 installed; 3 refused; 4 rolled back; 5 clone/fetch failed; 6 a cron failed.
################################################################################
function cmd_install() {
  local tag="${1:-}"
  local created=0
  local rc kind cron_rc=0

  if [[ -n "${tag}" && ! "${tag}" =~ ${TAG_RE} ]]; then
    echo "updater: a release tag like v3.14.24 is required" >&2
    usage
  fi

  if [[ ! -e "${ROOT_DIR}" || ( -d "${ROOT_DIR}" && -z "$(ls -A "${ROOT_DIR}" 2>/dev/null)" ) ]]; then
    git clone --quiet "${REPO_URL}" "${ROOT_DIR}" || {
      echo "updater: could not clone ${REPO_URL}" >&2
      rm -rf -- "${ROOT_DIR}"
      result_line "clone_failed" "${tag}" "" ""
      exit 5
    }
    created=1
  fi

  ( move_tree "${tag}" "install" )
  rc=$?
  if [[ ${rc} -ne 0 ]]; then
    # A tree this run created is removed on failure so no half install is left.
    [[ ${created} -eq 1 ]] && rm -rf -- "${ROOT_DIR}"
    exit "${rc}"
  fi

  if [[ "${INSTALL_CRON}" == "true" ]]; then
    for kind in ${CRON_KINDS}; do
      if ! TERM=dumb "${ROOT_DIR}/runner.sh" --task cron-install --subtask "${kind}" </dev/null; then
        echo "updater: cron-install ${kind} failed" >&2
        cron_rc=6
      fi
    done
  fi

  local head
  head="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
  tag="$(git -C "${ROOT_DIR}" describe --tags --exact-match HEAD 2>/dev/null || echo "${tag}")"
  if [[ ${cron_rc} -ne 0 ]]; then
    result_line "installed_cron_failed" "${tag}" "${head}" ""
    exit "${cron_rc}"
  fi
  result_line "installed" "${tag}" "${head}" ""
}

################################################################################
# rollback: return to a previous commit (default: the one before the last update).
#
# Arguments:
#   ${1} = ${target} - commit to return to; optional
#
# Outputs:
#   0 on success; 3 refused; 4 verification failed.
################################################################################
function cmd_rollback() {
  local target="${1:-}"
  require_clean_tree ""

  local current
  current="$(git -C "${ROOT_DIR}" rev-parse HEAD)"

  if [[ -z "${target}" ]]; then
    target="$(grep -E 'action=update .*result=updated$' "${ROOT_DIR}/log/updater_receipt.log" 2>/dev/null | tail -n 1 | sed -n 's/.* previous=\([0-9a-f]\{40\}\) .*/\1/p')"
    [[ -n "${target}" ]] || refuse "no previous commit recorded; pass one explicitly" ""
  fi
  [[ "${target}" =~ ^[0-9a-f]{7,40}$ ]] || refuse "rollback target must be a commit hash" ""
  git -C "${ROOT_DIR}" cat-file -e "${target}^{commit}" 2>/dev/null || refuse "unknown commit ${target}" ""
  target="$(git -C "${ROOT_DIR}" rev-parse "${target}^{commit}")"

  git -C "${ROOT_DIR}" merge-base --is-ancestor "${target}" "${current}" ||
    refuse "${target} is not an ancestor of the current commit; rollback only goes back along this history" ""

  git -C "${ROOT_DIR}" reset --keep --quiet "${target}" || refuse "reset to ${target} would lose local changes" ""

  if ! verify_tree; then
    git -C "${ROOT_DIR}" reset --keep --quiet "${current}"
    write_receipt "rollback" "-" "${current}" "${target}" "rolled_back"
    result_line "rolled_back" "" "${current}" "${current}"
    exit 4
  fi

  write_receipt "rollback" "-" "${current}" "${target}" "rolled_back_to_previous"
  echo "updater: ${current} -> ${target}"
  result_line "rolled_back_to_previous" "" "${target}" "${current}"
}

# Parse global options, then dispatch.
command="${1:-}"
[[ -n "${command}" ]] || usage
shift

positional=()
fetch_first=""
while [[ $# -gt 0 ]]; do
  case "${1}" in
  --root)
    [[ $# -ge 2 ]] || usage
    ROOT_DIR="$(readlink -m -- "${2}")"
    shift 2
    ;;
  --repo)
    [[ $# -ge 2 ]] || usage
    REPO_URL="${2}"
    shift 2
    ;;
  --cron-kinds)
    [[ $# -ge 2 ]] || usage
    CRON_KINDS="${2}"
    [[ "${CRON_KINDS}" =~ ^[a-z-]+( [a-z-]+)*$ ]] || { echo "updater: invalid --cron-kinds" >&2; exit 2; }
    shift 2
    ;;
  --no-cron)
    INSTALL_CRON="false"
    shift
    ;;
  --fetch)
    fetch_first="fetch"
    shift
    ;;
  *)
    positional+=("${1}")
    shift
    ;;
  esac
done

# Every command but install needs an existing tree.
if [[ "${command}" != "install" ]]; then
  [[ -d "${ROOT_DIR}" ]] || { echo "updater: ${ROOT_DIR} not found" >&2; exit 2; }
fi

case "${command}" in
status) cmd_status "${fetch_first}" ;;
update) cmd_update "${positional[0]:-}" ;;
rollback) cmd_rollback "${positional[0]:-}" ;;
install) cmd_install "${positional[0]:-}" ;;
*) usage ;;
esac
