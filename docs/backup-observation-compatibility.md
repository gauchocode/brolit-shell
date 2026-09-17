# Backup observation compatibility

## Contract pin

The collector implements the Admin backup observation wire contract `1.0`.
The authoritative contract remains in the sibling `brolit-admin` repository;
this repository does not copy or modify it.

| Artifact | SHA-256 |
|---|---|
| `application/contracts/backup-observation/v1.schema.json` | `4c63f2d473ee97c989c448167e5f863a9ddca569f1b933f32280d5cc581f6638` |
| `application/contracts/backup-observation/README.md` | `6debcfab13caffda12696e6e8ab5d16629ed64a47deb43da01d7483c6e58b3f9` |

The supplied Admin fixtures are synthetic contract examples, not provider
recordings. Protocol limits used by the entry point are a 16 KiB request,
1 KiB–4 MiB report, 1–1,000 items, and 1–300 seconds. Exit statuses are 0,
10, 20, 30 and 40 for complete, partial, failed, unsupported and malformed
requests respectively.

## Tested evidence in this repository

| Surface | Status | Limitation |
|---|---|---|
| Standalone entry and request boundary | Implemented | Requires `jq` and `python3`; no normal shell initialization is loaded. |
| Read-only JSON projection | Implemented | Mismatched/missing config is reported without migration or repair. |
| Credential parser | Implemented | Only literal `OAUTH_APP_KEY`, `OAUTH_APP_SECRET` and `OAUTH_REFRESH_TOKEN` assignments at `/root/.dropbox_uploader` are accepted; files are never sourced. |
| Borgmatic YAML | Implemented (fixture-tested) | Profile `pyyaml-safe-load` (PyYAML ≥5.4, verified with 5.4.1): scalar constants, repository strings/mappings, source directories, retention, database declarations. Includes, tags, recursive constants, substitutions beyond scalar constants and hooks are rejected with diagnostics, never evaluated. |
| Borg structured metadata | Implemented (fixture-tested) | Exact profile `borg-1.2.0`: read-only `borg info --json` and `borg list --json` with `BORG_RSH` BatchMode and pre-provisioned host-key checking (`StrictHostKeyChecking=yes`). Operator-approved read-only flags `BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes` and `BORG_RELOCATED_REPO_ACCESS_IS_OK=yes` are set because fleet Storage Box repositories are unencrypted; no other trust override, no lock breaking, no repository initialization. Per-archive sizes are unavailable in this profile (unknown, not zero). Naive archive timestamps are converted with `SERVER_CONFIG.timezone`; without a valid timezone the backup time is unknown. Multi-request Borg pages are reported `best_effort`, not snapshot-consistent, so they cannot authorize absence reconciliation. |
| Dropbox identity/listing | Implemented (fixture-tested) | Profile `dropbox-oauth-refresh-json-full-v1`: literal refresh credentials, fixed OAuth/account/list-folder endpoints, account/root namespace identity, explicit configured root, native file IDs/revisions/paths/sizes and bounded full pagination. The isolated fake validates two pages without network; a live account and fleet version distribution remain unverified. Existing mutation-capable uploader helpers are not imported. |
| Dropbox incremental | Unsupported | Admin atomic checkpoint/replay conformance is not available. |

The unsupported provider outcomes are deliberate. Presence of a binary, a
template, or a source-code reference is not treated as runtime compatibility.
No package installation, live provider request, deployment or pilot
authorization was performed as part of this change.

## Required executable features

`jq` is used only with the existing `-e`, `-c`, and `-n` JSON operations. A
strict `python3` standard-library decoder rejects duplicate object keys and
nesting deeper than 16 before request validation. `mktemp`, `date`, `cat`,
`wc`, and `env` provide bounded local transport and cleanup primitives.
`curl`, `borg`, `borgmatic`, and `yq` were probed during investigation. The
collector invokes only the fixed `borg` and Dropbox `curl` profiles above, plus
`python3` with the local PyYAML parser. `borgmatic` and `yq` are never invoked.
No `pipx run`, package manager, or provider helper is used. The isolated
harness never permits a network request.

Borg observation writes no configuration and no repository data. Borg itself
maintains its local cache under `/root/.cache/borg` and takes short-lived
repository locks during `info`/`list`; these tool-local effects are expected
parts of the `borg-1.2` profile. If a repository is busy-locked, the error is
classified `busy_locked` and nothing is forced.

## Safe subset decisions

The configuration projection checks the current configuration version and
returns only backup method status and non-secret discovery selectors. It does
not read credentials. Handle resolution accepts only deterministic Borg
configuration handles for regular files directly under `/etc/borgmatic.d`, or
the fixed `dropbox-root` handle when an explicit absolute Dropbox root is
configured. A forged, stale or arbitrary handle is not converted into a path;
disabled generation does not erase an explicitly configured historical root.

Dropbox credentials are parsed as literal assignments only. The OAuth refresh
exchange and bearer requests use fixed endpoints and mode-0600 temporary curl
configuration files, so secrets do not appear in argv, reports or diagnostics.
Continuation cursors are wrapped with a scope binding and a credential-derived
integrity MAC; the raw provider cursor is never accepted without validation.
The observer never calls upload, download, delete, restore or folder-creation
operations.

The fixture harness uses fake `borg` and `curl` binaries with a command log.
It runs without network access and treats an empty command log as a required
security assertion. Provider fakes are not compatibility declarations.

The fixture harness uses `BROLIT_ADMIN_ROOT` when set, otherwise it resolves a
sibling `brolit-admin` checkout; CI should set that variable explicitly.
Targeted `bash -n` and `git diff --check` are available and used. `shellcheck`
is not installed in the validation environment and was not installed.
