#!/usr/bin/env bash
# Verifies what brolit_report.sh says about the runtime it runs from: a git tree
# exactly at a release tag is clean, a tree on an untagged commit or with
# modified tracked files reports the drift, and a tree that is not a git
# repository is "legacy_runtime". The report must also name the real version and
# commit of a git tree.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

T="${TMP}/tree"
git init -q -b master "${T}"
mkdir -p "${T}/libs" "${T}/release"
cp "${ROOT_DIR}/brolit_report.sh" "${T}/brolit_report.sh"
cp "${ROOT_DIR}/libs/release_manifest.sh" "${T}/libs/release_manifest.sh"
printf 'BROLIT_RELEASE_VERSION="9.1.0"\nBROLIT_REPORT_PROTOCOL_VERSION="1"\nBROLIT_MIN_ADMIN_PROTOCOL="1"\n' >"${T}/release/version.env"
git -C "${T}" add -A && git -C "${T}" commit -q -m "bump 9.1.0"
git -C "${T}" tag -a v9.1.0 -m release

report() { bash "${T}/brolit_report.sh" metadata; }
errors() { report | jq -c '.errors'; }

# at a release tag, clean
[[ "$(errors)" == "[]" ]] || fail "a tree at a release tag must report no errors, got $(errors)"
[[ "$(report | jq -r '.producer_version')" == "9.1.0" ]] || fail "wrong producer_version"
[[ "$(report | jq -r '.producer_commit')" == "$(git -C "${T}" rev-parse HEAD)" ]] || fail "producer_commit must be the tree's HEAD"

# modified tracked file
echo "# local" >>"${T}/release/version.env"
[[ "$(errors)" == '["modified_runtime"]' ]] || fail "a modified tracked file must report modified_runtime, got $(errors)"
git -C "${T}" checkout -q -- release/version.env

# untracked files do not count
touch "${T}/brolit_backups_tasks.lock"
[[ "$(errors)" == "[]" ]] || fail "untracked files must not be reported, got $(errors)"

# a commit that is not a release
echo "x" >"${T}/x.txt"; git -C "${T}" add x.txt; git -C "${T}" commit -q -m "after the release"
[[ "$(errors)" == '["untagged_runtime"]' ]] || fail "an untagged commit must report untagged_runtime, got $(errors)"

# untagged and modified
echo "# local" >>"${T}/x.txt"
[[ "$(errors)" == '["untagged_runtime","modified_runtime"]' ]] || fail "both drifts must be reported, got $(errors)"
git -C "${T}" checkout -q -- x.txt

# a non-release tag does not count as a release
git -C "${T}" tag -a wip-1 -m wip
[[ "$(errors)" == '["untagged_runtime"]' ]] || fail "only vX.Y.Z tags are releases, got $(errors)"
git -C "${T}" tag -a v9.1.1 -m release
[[ "$(errors)" == "[]" ]] || fail "tagging the commit as a release must clear the drift, got $(errors)"

# not a git tree and no manifest: legacy
N="${TMP}/plain"; mkdir -p "${N}/libs" "${N}/release"
cp "${T}/brolit_report.sh" "${N}/"; cp "${T}/libs/release_manifest.sh" "${N}/libs/"; cp "${T}/release/version.env" "${N}/release/"
[[ "$(bash "${N}/brolit_report.sh" metadata | jq -c '.errors')" == '["legacy_runtime"]' ]] || fail "a tree that is not a git repository must be legacy_runtime"

echo "report runtime errors tests passed"
