#!/usr/bin/env bash
#
# Sign a built release manifest with an OpenSSH key.
#
# Produces a detached signature next to the manifest:
#   <release-dir>/manifest.json.sig
#
# The private signing key never enters the repository. A typical ceremony:
#   ssh-keygen -t ed25519 -f /secure/offline/brolit-release-2026 -C "brolit-release-2026"
#   # publish the public half in release/allowed_signers (public repo material)
#   ./release/sign-release.sh dist/brolit-shell-<version>-<commit> /secure/offline/brolit-release-2026
#
# Verification happens on the VPS inside release/install.sh against a pinned
# trust anchor (operator override, /etc/brolit/allowed_signers, or the
# previously installed release). Signature is verified BEFORE the checksum,
# per the fleet release plan.
#

set -euo pipefail

die() { echo "brolit sign release: $*" >&2; exit 1; }

usage() {
    cat >&2 <<'EOF'
Usage:
  sign-release.sh <release-dir> [signing-key]

  <release-dir> must contain manifest.json.
  Signing key defaults to $BROLIT_SIGNING_KEY.
EOF
    exit 2
}

release_dir="${1:-}"
key="${2:-${BROLIT_SIGNING_KEY:-}}"
[[ -n "${release_dir}" ]] || usage
[[ -n "${key}" ]] || die "signing key is required (pass as argument or set BROLIT_SIGNING_KEY)"

command -v ssh-keygen >/dev/null || die "ssh-keygen is required"

manifest="${release_dir}/manifest.json"
[[ -f "${manifest}" && ! -L "${manifest}" ]] || die "manifest not found: ${manifest}"
[[ -f "${key}" ]] || die "signing key not found: ${key}"

rm -f "${manifest}.sig"
ssh-keygen -Y sign -f "${key}" -n brolit-shell-release "${manifest}" \
    || die "signing failed"
[[ -f "${manifest}.sig" ]] || die "signature was not created"

echo "signed ${manifest} -> ${manifest}.sig"
