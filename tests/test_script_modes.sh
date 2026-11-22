#!/usr/bin/env bash
# The runner makes every *.sh executable on each run (libs/commons.sh). A script
# stored as 100644 therefore turns the server's tree "modified" on the first run,
# and Admin refuses to update a tree with modified tracked files.
set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
bad="$(git -C "${ROOT_DIR}" ls-files -s | awk '$1=="100644" && $4 ~ /\.sh$/ {print $4}')"
[[ -z "${bad}" ]] || { echo "FAIL: shell scripts not stored executable (git update-index --chmod=+x):"; echo "${bad}" | head -10; exit 1; }
echo "script modes tests passed"
