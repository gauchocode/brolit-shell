#!/usr/bin/env bash

set -o pipefail

RELEASE_MANIFEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
RELEASE_VERSION_FILE="${RELEASE_MANIFEST_DIR}/release/version.env"

release_manifest_path() {
    if [[ -f "${RELEASE_MANIFEST_DIR}/current/manifest.json" && ! -L "${RELEASE_MANIFEST_DIR}/current/manifest.json" ]]; then
        printf '%s\n' "${RELEASE_MANIFEST_DIR}/current/manifest.json"
    elif [[ -f "${RELEASE_MANIFEST_DIR}/manifest.json" && ! -L "${RELEASE_MANIFEST_DIR}/manifest.json" ]]; then
        printf '%s\n' "${RELEASE_MANIFEST_DIR}/manifest.json"
    else
        printf '%s\n' ""
    fi
}

release_manifest_is_immutable() {
    local manifest
    manifest="$(release_manifest_path)"
    [[ -n "${manifest}" ]] && command -v jq >/dev/null 2>&1 \
        && jq -e '(.product == "brolit-shell") and (.version | type == "string") and (.commit | type == "string") and (.protocol_version | type == "number") and (.min_admin_protocol | type == "number") and (.capabilities | type == "array")' "${manifest}" >/dev/null 2>&1
}

# What is wrong with the runtime this report describes, as a JSON array.
#
# - A staged release with a valid manifest (the retired /opt layout): none.
# - The git tree, the supported runtime: none while HEAD is exactly at a release
#   tag (vX.Y.Z) and no tracked file is modified. "untagged_runtime" says the
#   tree runs a commit that is not a release; "modified_runtime" says tracked
#   files differ from it. Both describe real drift, so a server on a tag stays
#   free of warnings.
# - Anything else (no manifest, not a git tree): "legacy_runtime".
release_manifest_runtime_errors() {
    if release_manifest_is_immutable; then
        printf '%s\n' '[]'
        return 0
    fi

    if command -v jq >/dev/null 2>&1 && git -C "${RELEASE_MANIFEST_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local errors=()
        git -C "${RELEASE_MANIFEST_DIR}" describe --tags --exact-match --match 'v[0-9]*' HEAD >/dev/null 2>&1 || errors+=("untagged_runtime")
        [[ -z "$(git -C "${RELEASE_MANIFEST_DIR}" status --porcelain --untracked-files=no 2>/dev/null)" ]] || errors+=("modified_runtime")
        if [[ ${#errors[@]} -eq 0 ]]; then
            printf '%s\n' '[]'
        else
            printf '%s\n' "${errors[@]}" | jq -R . | jq -sc .
        fi
        return 0
    fi

    printf '%s\n' '["legacy_runtime"]'
}

if [[ -f "${RELEASE_VERSION_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${RELEASE_VERSION_FILE}"
fi

release_manifest_value() {
    local key="${1}"
    local manifest
    manifest="$(release_manifest_path)"

    if [[ -f "${manifest}" ]] && command -v jq >/dev/null 2>&1; then
        jq -r --arg key "${key}" '.[$key] // empty' "${manifest}" 2>/dev/null
        return 0
    fi

    case "${key}" in
        version) printf '%s\n' "${BROLIT_RELEASE_VERSION:-unknown}" ;;
        protocol_version) printf '%s\n' "${BROLIT_REPORT_PROTOCOL_VERSION:-1}" ;;
        min_admin_protocol) printf '%s\n' "${BROLIT_MIN_ADMIN_PROTOCOL:-1}" ;;
        *) printf '%s\n' "" ;;
    esac
}

release_manifest_commit() {
    local manifest
    manifest="$(release_manifest_path)"

    if [[ -f "${manifest}" ]] && command -v jq >/dev/null 2>&1; then
        jq -r '.commit // empty' "${manifest}" 2>/dev/null
        return 0
    fi

    if git -C "${RELEASE_MANIFEST_DIR}" rev-parse HEAD >/dev/null 2>&1; then
        git -C "${RELEASE_MANIFEST_DIR}" rev-parse HEAD
    else
        printf '%s\n' ""
    fi
}

release_manifest_capabilities() {
    local manifest
    manifest="$(release_manifest_path)"

    if [[ -f "${manifest}" ]] && command -v jq >/dev/null 2>&1; then
        jq -c '.capabilities // []' "${manifest}" 2>/dev/null
    else
        printf '%s\n' '["inventory.v2","backup-history.v2","backup-dropbox-line-parser","backup-borg-latest","backup-progress.v1","job-control.v1"]'
    fi
}
