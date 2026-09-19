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
        printf '%s\n' '["inventory.v2","backup-history.v2","backup-dropbox-line-parser","backup-borg-latest"]'
    fi
}
