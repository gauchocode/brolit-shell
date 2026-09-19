#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
OUTPUT_DIR="${1:-${ROOT_DIR}/dist}"
# shellcheck source=release/version.env
source "${ROOT_DIR}/release/version.env"

command -v git >/dev/null || { echo "git is required" >&2; exit 2; }
command -v tar >/dev/null || { echo "tar is required" >&2; exit 2; }
command -v sha256sum >/dev/null || { echo "sha256sum is required" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

commit="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
version="${BROLIT_RELEASE_VERSION:?BROLIT_RELEASE_VERSION is required}"
release_dir="${OUTPUT_DIR}/brolit-shell-${version}-${commit}"

artifact="${release_dir}/brolit-shell-runtime.tar.gz"
# Release manifests describe an immutable commit. Refuse to package a dirty
# tree by default so the manifest commit and runtime contents cannot diverge.
if [[ -n "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=all)" && "${BROLIT_RELEASE_BUILD_ALLOW_DIRTY:-0}" != "1" ]]; then
    echo "refusing to build a release from a dirty working tree" >&2
    echo "commit or set BROLIT_RELEASE_BUILD_ALLOW_DIRTY=1 for a local-only test build" >&2
    exit 1
fi

mkdir -p "${release_dir}"

staging_dir="$(mktemp -d "${OUTPUT_DIR}/.staging.XXXXXX")"
cleanup() { rm -rf "${staging_dir}"; }
trap cleanup EXIT

# Copy tracked runtime files only. This deliberately excludes ignored files,
# local dumps, reports, credentials, and developer dependencies. The explicit
# new-file list keeps local test builds usable before these files are committed.
copy_runtime_file() {
    local relative_path="${1}"
    [[ -f "${ROOT_DIR}/${relative_path}" ]] || return 0
    mkdir -p "${staging_dir}/$(dirname "${relative_path}")"
    cp -p "${ROOT_DIR}/${relative_path}" "${staging_dir}/${relative_path}"
}

require_runtime_file() {
    local relative_path="${1}"
    [[ -f "${ROOT_DIR}/${relative_path}" ]] || { echo "release build: required file missing: ${relative_path}" >&2; exit 1; }
    copy_runtime_file "${relative_path}"
}

while IFS= read -r -d '' relative_path; do
    case "${relative_path}" in
        brolit_lite.sh|runner.sh|updater.sh|backup_observer.sh|aliases.sh|cron/*|brolit_report.sh|config/*|libs/*|release/*|tools/*|utils/*)
            case "${relative_path}" in
                */.env|*/.env.*|tests/*|*/credentials*|*/private*|*.pem|*.key|*.sig) continue ;;
            esac
            # The pinned trust anchor is public key material and is safe to
            # ship; the example file stays documentation-only.
            case "${relative_path}" in
                release/allowed_signers.example) continue ;;
            esac
            copy_runtime_file "${relative_path}"
            ;;
    esac
done < <(git -C "${ROOT_DIR}" ls-files -z)

for required_file in brolit_report.sh libs/release_manifest.sh release/version.env release/manifest.schema.json release/build-release.sh release/install.sh release/sign-release.sh release/README.md; do
    require_runtime_file "${required_file}"
done

# Pin the trust anchor when the key ceremony has published it. The file holds
# public keys only; its absence simply means this build is unverifiable by
# signature until a key is published.
if [[ -f "${ROOT_DIR}/release/allowed_signers" ]]; then
    copy_runtime_file "release/allowed_signers"
fi

tar -C "${staging_dir}" -czf "${artifact}" .

artifact_sha256="$(sha256sum "${artifact}" | awk '{print $1}')"
jq -n \
    --arg product "brolit-shell" \
    --arg version "${version}" \
    --arg commit "${commit}" \
    --argjson protocol_version "${BROLIT_REPORT_PROTOCOL_VERSION}" \
    --argjson min_admin_protocol "${BROLIT_MIN_ADMIN_PROTOCOL}" \
    --arg sha256 "${artifact_sha256}" \
    --argjson capabilities '["inventory.v2","backup-history.v2","backup-dropbox-line-parser","backup-borg-latest"]' \
    '{product:$product,version:$version,commit:$commit,protocol_version:$protocol_version,min_admin_protocol:$min_admin_protocol,sha256:$sha256,capabilities:$capabilities}' \
    > "${release_dir}/manifest.json"

printf '%s\n' "${release_dir}"
