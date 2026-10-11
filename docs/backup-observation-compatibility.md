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
| Borgmatic YAML | Implemented (fixture-tested) | Profile `pyyaml-safe-load` (PyYAML ≥5.4, previously verified with 5.4.1; local corrective tests with 6.0.3): scalar constants, repository strings/mappings, source directories, nested/flat retention, database declarations and hook-presence metadata. Includes, tags, recursive constants and unresolved substitutions in repository/source paths are rejected with diagnostics. Hooks are never evaluated; their bodies and database credentials are excluded from the projection. |
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

## P2.1 local template correction (2026-10-11)

Source implementation was approved through Admin's
`docs/plan/active/2026-10-backup-status-and-troubleshooting.md`. This bounded
correction recognizes this repository's flat PostgreSQL/Docker template keys:

- Top-level `keep_within`, `keep_secondly`, `keep_minutely`, `keep_hourly`,
  `keep_daily`, `keep_weekly`, `keep_monthly`, and `keep_yearly`. Flat counts
  must be literal integers/integer strings; intervals use a literal number
  and `H`, `d`, `w`, `m` or `y`. Conflicting flat/nested values are unsupported,
  not resolved by guessing. Existing nested scalar retention remains supported.
- Non-empty top-level `before_backup`, `after_backup`, and `on_error` lists
  set the internal hook-presence hint; existing nested `hooks` presence remains
  supported. No hook text is returned, evaluated or searched for dump commands.
- Non-empty lists of named database declarations recognize `mysql_databases`,
  `mariadb_databases`, `postgresql_databases`, and the repository template's
  `postgres_databases` spelling. Both PostgreSQL spellings normalize to one
  `postgresql` engine hint. Credentials, names and connection options are not
  projected. Malformed declarations produce a sanitized unsupported result.

These are internal configuration hints only. Docker pause/unpause hooks do not
prove database coverage; even a configured PostgreSQL declaration or dump hook
does not prove a fresh dump, successful backup, archive contents or restoration.
Discovery exposes retention through the existing wire field; no database/hook
fields are added to strict wire `1.0`. Archive classification remains independent
and naming-inferred where previously supported.

`tests/backup_observation/fixtures/templates/{postgres,docker}.yml` are sanitized
excerpts of the repository templates with synthetic generated repositories and
two independent destinations. They are not deployed config/provider recordings.
`templates-existing-profile.yml` preserves nested retention/hooks and earlier
database declaration spellings. The 13 Python tests also parse all four actual
repository templates and exercise malformed/conflicting metadata and non-execution
canaries. The full isolated observer harness validates template discovery and
inventory against the unchanged pinned Admin schema, checks secret/hook-text
suppression, and verifies that configuration hints cannot upgrade archive evidence.
The harness resolves Admin fixtures through `BROLIT_ADMIN_ROOT` consistently.

Validation used the existing `eve-agents-app-dev:latest` image, host-installed
`/usr`, `/lib` and `/lib64` mounted read-only as tool inputs, repository checkouts
mounted read-only, fresh `/tmp` and `/root` tmpfs, `--read-only` and `--network none`.
Python 3.14 / PyYAML 6.0.3 and existing `jq`/`jsonschema` ran only inside Docker;
no dependency was added or installed. Parser tests and the full observer suite
passed. Initial full runs exposed the existing timing-sensitive cancellation
assertion (exit 20 instead of 10): its fixed 100 ms wait could signal before
request validation. The harness now waits for its controlled delay child before
signalling; collector runtime behavior is unchanged. Targeted `bash -n` and
`git diff --check` passed, as did Docker-isolated OpenSpec 1.3.1 strict validation
of `backup-observation-collector`. Both pinned Admin SHA-256 values remain
unchanged. Independent read-only code/security review completed in the
coordinating Admin session with no findings; it independently reran all 13
parser regressions and verified syntax and contract hashes. Borg support
remains exactly `borg-1.2.0`; no fleet,
provider, release or deployment validation/authorization is implied.

Reproduce on the same tool-equipped Linux host, from the Shell checkout (the
read-only tool mounts reuse existing executables/libraries, not credentials):

```sh
docker run --rm --network none --read-only --tmpfs /tmp --tmpfs /root \
  --mount type=bind,src=/usr,dst=/usr,readonly \
  --mount type=bind,src=/lib64,dst=/lib64,readonly \
  --mount type=bind,src=/lib,dst=/lib,readonly \
  --mount "type=bind,src=${PWD},dst=/repo,readonly" \
  --mount "type=bind,src=$(realpath ../brolit-admin),dst=/admin,readonly" \
  --workdir /repo -e BROLIT_ADMIN_ROOT=/admin \
  --entrypoint /usr/bin/bash eve-agents-app-dev:latest \
  tests/backup_observation/test_observer.sh
```

The Python parser regressions run as part of this harness. The broad
`tests/tests_suite.sh` was not invoked.
