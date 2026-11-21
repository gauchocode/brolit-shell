#!/usr/bin/env bash
#
# Author: GauchoCode
# Version: 3.14
#
# Description: Creates the annotated release tag vX.Y.Z for a commit. A release
# is that tag: `updater.sh update|install vX.Y.Z` and brolit-admin move servers
# to it. The version comes from release/version.env AT THE TAGGED COMMIT, so a
# tag can never disagree with the code it names.
#
#   release/tag-release.sh [--commit <sha>]     tag HEAD, or the given commit
#
# The tag is created locally; publishing it is a separate, deliberate step and
# the exact command is printed:  git push origin vX.Y.Z
################################################################################

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd -P)"
commit_arg="HEAD"

while [[ $# -gt 0 ]]; do
  case "${1}" in
  --commit)
    [[ $# -ge 2 ]] || { echo "tag-release: --commit needs a value" >&2; exit 2; }
    commit_arg="${2}"
    shift 2
    ;;
  *)
    echo "usage: release/tag-release.sh [--commit <sha>]" >&2
    exit 2
    ;;
  esac
done

commit="$(git -C "${ROOT_DIR}" rev-parse --verify "${commit_arg}^{commit}" 2>/dev/null)" ||
  { echo "tag-release: unknown commit ${commit_arg}" >&2; exit 1; }

# Tagging HEAD of a dirty tree would name code that is not what is committed.
if [[ "${commit_arg}" == "HEAD" && -n "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=no)" ]]; then
  echo "tag-release: refusing to tag HEAD with modified tracked files" >&2
  exit 1
fi

version="$(git -C "${ROOT_DIR}" show "${commit}:release/version.env" 2>/dev/null |
  sed -n 's/^BROLIT_RELEASE_VERSION="\(.*\)"$/\1/p' | head -n 1)"
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]] ||
  { echo "tag-release: ${commit} declares no valid BROLIT_RELEASE_VERSION (got '${version}')" >&2; exit 1; }

tag="v${version}"

if git -C "${ROOT_DIR}" rev-parse -q --verify "refs/tags/${tag}" >/dev/null; then
  existing="$(git -C "${ROOT_DIR}" rev-parse "refs/tags/${tag}^{commit}")"
  if [[ "${existing}" == "${commit}" ]]; then
    echo "tag-release: ${tag} already exists on ${commit}"
    exit 0
  fi
  echo "tag-release: ${tag} already exists on ${existing}; a release tag is never moved" >&2
  exit 1
fi

git -C "${ROOT_DIR}" tag -a "${tag}" -m "brolit-shell ${version}" "${commit}"
echo "tag-release: created ${tag} on ${commit}"
echo "publish it with: git push origin ${tag}"
