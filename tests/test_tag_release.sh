#!/usr/bin/env bash
# Verifies release/tag-release.sh: an annotated tag named after the version at
# the tagged commit, idempotent on the same commit, never moved, refusing a dirty
# HEAD and a commit without a valid version.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

R="${TMP}/repo"
git init -q -b master "${R}"
mkdir -p "${R}/release"
cp "${ROOT_DIR}/release/tag-release.sh" "${R}/release/tag-release.sh"
bump() { printf 'BROLIT_RELEASE_VERSION="%s"\n' "${1}" >"${R}/release/version.env"; git -C "${R}" add -A; git -C "${R}" commit -q -m "bump ${1}"; }
tagr() { "${R}/release/tag-release.sh" "$@"; }

bump 1.0.0
c1="$(git -C "${R}" rev-parse HEAD)"
tagr >/dev/null 2>&1 || fail "tagging HEAD failed"
[[ "$(git -C "${R}" cat-file -t refs/tags/v1.0.0)" == "tag" ]] || fail "the tag must be annotated"
[[ "$(git -C "${R}" rev-parse v1.0.0^{commit})" == "${c1}" ]] || fail "tag on the wrong commit"

tagr >/dev/null 2>&1 || fail "tagging the same commit twice must succeed"

bump 1.1.0
c2="$(git -C "${R}" rev-parse HEAD)"
tagr --commit "${c1}" >/dev/null 2>&1 || fail "re-tagging the old commit must be a no-op"
[[ "$(git -C "${R}" rev-parse v1.0.0^{commit})" == "${c1}" ]] || fail "an existing tag moved"

# a version that already has a tag on another commit is refused
git -C "${R}" tag -a v1.1.0 -m x "${c1}"
tagr >/dev/null 2>&1 && fail "an existing tag on another commit must be refused"
git -C "${R}" tag -d v1.1.0 >/dev/null

# the version is read at the tagged commit, not from the work tree
printf 'BROLIT_RELEASE_VERSION="9.9.9"\n' >"${R}/release/version.env"
tagr --commit "${c2}" >/dev/null 2>&1 || fail "tagging a past commit failed"
[[ "$(git -C "${R}" rev-parse v1.1.0^{commit})" == "${c2}" ]] || fail "version must come from the tagged commit"

# a dirty HEAD is refused
tagr >/dev/null 2>&1 && fail "a dirty HEAD must be refused"
git -C "${R}" checkout -q -- release/version.env

# a commit without a valid version is refused
git -C "${R}" rm -q release/version.env; git -C "${R}" commit -q -m "no version"
tagr >/dev/null 2>&1 && fail "a commit without a version must be refused"
tagr --commit nope >/dev/null 2>&1 && fail "an unknown commit must be refused"

echo "tag-release tests passed"
