# Brolit Shell releases

Release bundles are immutable runtime archives. Production updates must verify
the manifest signature and checksum, then activate a release through
`install.sh`; they must not modify a Git working tree.

## Build

Run `release/build-release.sh <output-directory>` from a clean checkout. The
builder packages tracked runtime files only and writes:

- `manifest.json` with the release version, commit, protocol, capabilities, and
  SHA-256 checksum;
- `brolit-shell-runtime.tar.gz` with the runtime files.

For local-only tests on an uncommitted checkout, set
`BROLIT_RELEASE_BUILD_ALLOW_DIRTY=1`. Do not publish such an artifact.

If `release/allowed_signers` exists (public key material, safe to commit), it
is packaged as `release/allowed_signers` so verification stays self-contained
for this open-source repo. Never commit private keys or `*.sig` files.

## Signing (opt-in)

Signature enforcement is off by default: production installs verify archive
paths/types, checksum, shell syntax, and entrypoints with no key ceremony.
Trust comes from HTTPS distribution plus the operator-pinned version/commit.

To enforce authenticity, set `BROLIT_ENFORCE_RELEASE_SIGNATURE=1` on the VPS
before installing. Enforcement verifies the detached OpenSSH signature
(`manifest.json.sig`, staged next to the manifest) against a trust anchor and
records `trust: pinned|tofu` in the receipt; default installs record
`trust: unsigned`.

Key ceremony (offline, once per key generation):

```sh
ssh-keygen -t ed25519 -f /secure/offline/brolit-release-2026 -C "brolit-release-2026"
# publish ONLY the public half:
# <principal> <keytype> <base64> appended to release/allowed_signers
```

Sign a built release directory (produces `manifest.json.sig` next to the
manifest, staged and transported alongside it):

```sh
release/sign-release.sh dist/brolit-shell-<version>-<commit> /secure/offline/brolit-release-2026
```

Trust anchors, in precedence order:

1. `BROLIT_RELEASE_ALLOWED_SIGNERS` (explicit file path override);
2. `/etc/brolit/allowed_signers` (operator-managed);
3. `<root>/current/allowed_signers` (pinned by the previous install);
4. First-contact trust: the key bundled at `release/allowed_signers` inside
   the artifact, pinned into the new release on success.

Rules (apply when `BROLIT_ENFORCE_RELEASE_SIGNATURE=1`): a configured anchor
plus an unsigned release is a downgrade and is rejected; a bundled key that
differs from the pinned anchor is rejected (rotation must be explicit via 1
or 2). The install receipt records `trust` (`unsigned` by default; `pinned`
or `tofu` when enforcement is on) and the signing principal.

## Install and rollback

`release/install.sh install <manifest.json> <runtime.tar.gz> [root]` verifies
(archive paths/types → checksum → shell syntax and entrypoints, plus the
signature when `BROLIT_ENFORCE_RELEASE_SIGNATURE=1`)
before creating:

```text
/opt/brolit-shell/releases/<version>-<commit>/
/opt/brolit-shell/current -> releases/<version>-<commit>
/opt/brolit-shell/install-receipt.json
```

Activation is an atomic symlink replacement. Unknown files and the legacy
`/root/brolit-shell` tree are not deleted. Roll back with:
`release/install.sh rollback <version>-<commit> [root]`.

Server configuration and runtime data remain outside release directories. The
current compatibility runtime still reads `/root/.brolit_conf.json`, while
generated observer output from staged releases is written under
`/var/lib/brolit/lite-output`. A future migration can move configuration to
`/etc/brolit` without changing the release contract.

Admin fetches releases from the public source, verifies schema and checksum,
and pushes the bundle over the existing SSH worker path for on-VPS signature
verification and activation (see the fleet release plan in brolit-admin).
