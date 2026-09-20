#!/usr/bin/env bash

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT_DIR="$(cd "${TEST_DIR}/../.." && pwd -P)"
TEMP_DIR="$(mktemp -d /tmp/brolit-release-test.XXXXXX)"
trap 'rm -rf "${TEMP_DIR}"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

report="$("${ROOT_DIR}/brolit_report.sh" metadata)"
echo "${report}" | jq -e '
  .protocol_name == "brolit-shell-report" and
  .protocol_version == 1 and
  (.capabilities | index("backup-borg-latest")) != null
' >/dev/null || fail "invalid shell report"

release_dir="$(BROLIT_RELEASE_BUILD_ALLOW_DIRTY=1 "${ROOT_DIR}/release/build-release.sh" "${TEMP_DIR}/dist")"
jq empty "${release_dir}/manifest.json" || fail "invalid release manifest"
archive_listing="$(tar -tzf "${release_dir}/brolit-shell-runtime.tar.gz")"
grep -q './cron/security_tasks.sh' <<<"${archive_listing}" || fail "cron runtime files missing"

install_root="${TEMP_DIR}/install"
BROLIT_INSTALL_TEST_MODE=1 "${ROOT_DIR}/release/install.sh" install \
  "${release_dir}/manifest.json" \
  "${release_dir}/brolit-shell-runtime.tar.gz" \
  "${install_root}" >/dev/null

[[ -L "${install_root}/current" ]] || fail "release was not activated atomically"
[[ -f "${install_root}/install-receipt.json" ]] || fail "install receipt missing"
jq -e '.previous_release == null and .active_release != null and .validation == "passed" and .trust == "unsigned"' "${install_root}/install-receipt.json" >/dev/null || fail "first-install receipt is invalid"
if find "${install_root}/current" -type f -perm /022 -print -quit | grep -q .; then
  fail "installed runtime contains group/world-writable files"
fi

# Signature enforcement is opt-in. The block below exercises the enforced
# path end to end; the default path stays ceremony-free.
export BROLIT_ENFORCE_RELEASE_SIGNATURE=1

if command -v ssh-keygen >/dev/null 2>&1; then
  sign_dir="${TEMP_DIR}/signing"
  mkdir -p "${sign_dir}"
  ssh-keygen -t ed25519 -f "${sign_dir}/key" -N "" -C "brolit-test" -q
  printf 'test-principal %s\n' "$(cut -d' ' -f1,2 "${sign_dir}/key.pub")" > "${sign_dir}/allowed_signers"

  signed_dir="${TEMP_DIR}/signed-release"
  mkdir -p "${signed_dir}"
  cp "${release_dir}/manifest.json" "${release_dir}/brolit-shell-runtime.tar.gz" "${signed_dir}/"
  BROLIT_SIGNING_KEY="${sign_dir}/key" "${ROOT_DIR}/release/sign-release.sh" "${signed_dir}" >/dev/null
  [[ -f "${signed_dir}/manifest.json.sig" ]] || fail "signature was not created"

  # Pinned install: signature verifies against the configured anchor.
  signed_root="${TEMP_DIR}/signed-install"
  BROLIT_INSTALL_TEST_MODE=1 BROLIT_RELEASE_ALLOWED_SIGNERS="${sign_dir}/allowed_signers" \
    "${ROOT_DIR}/release/install.sh" install \
    "${signed_dir}/manifest.json" \
    "${signed_dir}/brolit-shell-runtime.tar.gz" \
    "${signed_root}" >/dev/null
  jq -e '.trust == "pinned" and .principal == "test-principal" and .validation == "passed"' \
    "${signed_root}/install-receipt.json" >/dev/null || fail "signed install receipt is invalid"

  # Tampered manifest with the original signature is rejected.
  cp "${signed_dir}/manifest.json" "${TEMP_DIR}/tampered-manifest.json"
  cp "${signed_dir}/manifest.json.sig" "${TEMP_DIR}/tampered-manifest.json.sig"
  printf ' ' >> "${TEMP_DIR}/tampered-manifest.json"
  if BROLIT_INSTALL_TEST_MODE=1 BROLIT_RELEASE_ALLOWED_SIGNERS="${sign_dir}/allowed_signers" \
    "${ROOT_DIR}/release/install.sh" install \
    "${TEMP_DIR}/tampered-manifest.json" \
    "${signed_dir}/brolit-shell-runtime.tar.gz" \
    "${TEMP_DIR}/tampered-manifest-install" >/dev/null 2>&1; then
    fail "tampered manifest was accepted"
  fi

  # An anchor plus an unsigned manifest is a downgrade: rejected.
  if BROLIT_INSTALL_TEST_MODE=1 BROLIT_RELEASE_ALLOWED_SIGNERS="${sign_dir}/allowed_signers" \
    "${ROOT_DIR}/release/install.sh" install \
    "${release_dir}/manifest.json" \
    "${release_dir}/brolit-shell-runtime.tar.gz" \
    "${TEMP_DIR}/downgrade-install" >/dev/null 2>&1; then
    fail "unsigned manifest was accepted despite a configured anchor"
  fi

  # Enforced without any anchor or signature: rejected.
  if BROLIT_INSTALL_TEST_MODE=1 \
    "${ROOT_DIR}/release/install.sh" install \
    "${release_dir}/manifest.json" \
    "${release_dir}/brolit-shell-runtime.tar.gz" \
    "${TEMP_DIR}/enforced-unsigned-install" >/dev/null 2>&1; then
    fail "unsigned release was accepted under enforcement"
  fi

  # Enforcement off ignores even a present-but-invalid sidecar signature.
  cp "${release_dir}/manifest.json" "${TEMP_DIR}/badsidecar-manifest.json"
  printf 'bogus' > "${TEMP_DIR}/badsidecar-manifest.json.sig"
  unset BROLIT_ENFORCE_RELEASE_SIGNATURE
  BROLIT_INSTALL_TEST_MODE=1 "${ROOT_DIR}/release/install.sh" install \
    "${TEMP_DIR}/badsidecar-manifest.json" \
    "${release_dir}/brolit-shell-runtime.tar.gz" \
    "${TEMP_DIR}/badsidecar-install" >/dev/null \
    || fail "default path should ignore an unverifiable sidecar signature"
  jq -e '.trust == "unsigned"' "${TEMP_DIR}/badsidecar-install/install-receipt.json" >/dev/null \
    || fail "sidecar install receipt should record unsigned trust"
  export BROLIT_ENFORCE_RELEASE_SIGNATURE=1

  # First-contact trust: an artifact bundling a key is accepted and pins it.
  tofu_work="${TEMP_DIR}/tofu"
  mkdir -p "${tofu_work}/stage"
  tar -xzf "${release_dir}/brolit-shell-runtime.tar.gz" -C "${tofu_work}/stage"
  mkdir -p "${tofu_work}/stage/release"
  cp "${sign_dir}/allowed_signers" "${tofu_work}/stage/release/allowed_signers"
  tar -C "${tofu_work}/stage" -czf "${tofu_work}/runtime.tar.gz" .
  tofu_version="9.9.9"
  tofu_commit="$(jq -r '.commit' "${release_dir}/manifest.json")"
  tofu_sha="$(sha256sum "${tofu_work}/runtime.tar.gz" | awk '{print $1}')"
  jq --arg v "${tofu_version}" --arg sha "${tofu_sha}" '.version = $v | .sha256 = $sha' \
    "${release_dir}/manifest.json" > "${tofu_work}/manifest.json"
  tofu_root="${TEMP_DIR}/tofu-install"
  BROLIT_INSTALL_TEST_MODE=1 "${ROOT_DIR}/release/install.sh" install \
    "${tofu_work}/manifest.json" \
    "${tofu_work}/runtime.tar.gz" \
    "${tofu_root}" >/dev/null
  jq -e '.trust == "tofu" and .principal == "test-principal"' \
    "${tofu_root}/install-receipt.json" >/dev/null || fail "TOFU install receipt is invalid"
  [[ -f "${tofu_root}/current/allowed_signers" ]] || fail "TOFU key was not pinned"

  # Silent rotation is rejected: same anchor, valid signature, different key.
  ssh-keygen -t ed25519 -f "${sign_dir}/other" -N "" -C "brolit-test-other" -q
  rot_work="${TEMP_DIR}/rotation"
  mkdir -p "${rot_work}/stage"
  tar -xzf "${release_dir}/brolit-shell-runtime.tar.gz" -C "${rot_work}/stage"
  mkdir -p "${rot_work}/stage/release"
  printf 'test-principal %s\n' "$(cut -d' ' -f1,2 "${sign_dir}/other.pub")" > "${rot_work}/stage/release/allowed_signers"
  tar -C "${rot_work}/stage" -czf "${rot_work}/runtime.tar.gz" .
  rot_sha="$(sha256sum "${rot_work}/runtime.tar.gz" | awk '{print $1}')"
  jq --arg v "9.9.8" --arg sha "${rot_sha}" '.version = $v | .sha256 = $sha' \
    "${release_dir}/manifest.json" > "${rot_work}/manifest.json"
  BROLIT_SIGNING_KEY="${sign_dir}/key" "${ROOT_DIR}/release/sign-release.sh" "${rot_work}" >/dev/null
  if BROLIT_INSTALL_TEST_MODE=1 BROLIT_RELEASE_ALLOWED_SIGNERS="${sign_dir}/allowed_signers" \
    "${ROOT_DIR}/release/install.sh" install \
    "${rot_work}/manifest.json" \
    "${rot_work}/runtime.tar.gz" \
    "${TEMP_DIR}/rotation-install" >/dev/null 2>&1; then
    fail "silent key rotation was accepted"
  fi
else
  echo "SKIP: ssh-keygen not available, signature tests skipped" >&2
fi

"${ROOT_DIR}/release/install.sh" rollback "$(basename "$(readlink "${install_root}/current")")" "${install_root}" >/dev/null
jq -e '.previous_release != null and .validation == "rollback" and .artifact_sha256 != null and .manifest != null and .trust != null' "${install_root}/install-receipt.json" >/dev/null || fail "rollback receipt is incomplete"

cp "${release_dir}/brolit-shell-runtime.tar.gz" "${TEMP_DIR}/tampered.tar.gz"
printf 'tampered' >> "${TEMP_DIR}/tampered.tar.gz"
unset BROLIT_ENFORCE_RELEASE_SIGNATURE
if BROLIT_INSTALL_TEST_MODE=1 "${ROOT_DIR}/release/install.sh" install "${release_dir}/manifest.json" "${TEMP_DIR}/tampered.tar.gz" "${TEMP_DIR}/tampered-install" >/dev/null 2>&1; then
  fail "tampered artifact was accepted"
fi

if "${ROOT_DIR}/updater.sh" >/dev/null 2>&1; then
  fail "legacy updater unexpectedly performed an implicit update"
fi

echo "release tests passed"
