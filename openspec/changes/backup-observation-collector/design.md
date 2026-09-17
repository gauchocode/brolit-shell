## Context

This is Phase 1 proposal work for Admin's fleet backup observability plan. Static inspection confirms `runner.sh` calls `script_init`, `libs/commons.sh` loads broad controllers, and `brolit_lite.sh` is not a safe standalone import. Existing Borg inventory uses name listings and assumed layouts. The bundled Dropbox uploader knows native list APIs but its human output is unsuitable as a metadata contract. The general test suite initializes the system and can perform real backup mutations.

The authoritative wire contract lives in **brolit-admin**, `docs/architecture/backup-observation-contract.md` and the formal schemas/fixtures it references. Those artifacts are being formalized separately. This proposal specifies shell behavior, not a competing JSON schema. Implementation requires a reviewed, pinned upstream revision; any mismatch is resolved there first.

## Goals / Non-Goals

**Goals:** An isolated, root-only collector; safe configuration discovery; independent repository/location observations; explicit provenance, unknowns and completeness; bounded runtime and output; test-backed capabilities.

**Non-Goals:** Backup creation, restoration, extraction, content browsing/download, integrity checks, pruning, compaction, repair, initialization, remote deletion, policy verdicts, alerts, Admin persistence, dependency installation or production operations. No SFTP/local/snapshot adapters in this MVP.

## Decisions

### 1. Standalone entry and bounded request

Propose `backup_observer.sh`, with internal modules under `libs/backup_observation/`. It reads one bounded canonical JSON request from stdin and dispatches only `capabilities`, `discover` or `inventory`; request options, version negotiation and exit/report mapping follow the upstream contract. It checks root before provider access. Protocol-only stdout and sanitized stderr are mandatory, including failures. No tenant authority comes from shell output.

Imports are audited definition-only modules. Never source `runner.sh`, `brolit_lite.sh`, `libs/commons.sh` or mutation-capable provider controllers, and never call `script_init`. Rejecting the existing initialization path avoids hidden configuration migration, package installation and credential execution. Do not add an observation route to the old runner.

Inventory handles resolve to currently authorized discovery configuration, not arbitrary paths, endpoints or command strings supplied by Admin. Configuration changes invalidate unresolved handles. Validate all inputs before subprocesses; use argument arrays, fixed executable/operation allowlists and restricted subprocess environments. No `eval`, shell interpolation of configuration values, user-supplied executable paths or request-directed file reads.

### 2. Read-only configuration boundary

Add a dedicated projection function inside `utils/brolit_configuration_manager.sh`; this remains the only layer reading `.brolit_conf.json`. Audit its source-time behavior before importing it and isolate any executable top-level behavior without invoking full loaders. The projection uses an available, verified JSON parser directly rather than helpers that import commons. It returns only required backup discovery data internally and an allowlisted non-secret report externally. Missing, invalid or mismatched-version configuration is diagnosed without copying, migrating or fixing it.

Borgmatic discovery uses a typed safe YAML subset: validated repository strings/mappings, literal scalar constants and explicit source/database hints. Includes, tags, recursive constants, substitutions and credential command references remain unsupported until individually implemented and tested. Never run Borgmatic to resolve configuration or execute hooks. Unsupported constructs retain configuration diagnostics and do not imply historical absence.

Credential inputs use a restricted, non-executing parser for explicitly supported literal assignments. Reject shell operators, substitutions, functions and unsupported syntax; never source credential files or invoke passcommands. Read only authorized credential paths. Secrets remain process-internal, excluded from reports, stderr, fixtures and observable argv. Ambient variables that enable provider hooks or arbitrary executables must be removed or rejected. Unsupported authentication is an explicit limitation.

### 3. Borg metadata per repository

Discover configured locations rather than synthesizing site-only repository paths. Preserve separate outcomes and physical-copy scope for each endpoint/repository, including database and mixed repositories. Probe installed Borg capabilities, then select only a tested structured metadata command profile. Do not assume Borg major versions share command syntax or JSON shapes; no fallback to terminal-table scraping.

Preserve native repository/archive IDs, archive timestamps and allowlisted size semantics when available. Compute extrema over parsed timestamps, never listing order or repository modification time. Missing metrics remain unknown; names are inference, not verified content. A successful empty listing is distinct from authentication, connectivity, locking and configuration errors.

No automatic host-key trust, lock breaking or repository initialization. The tested Borg profile may use the fixed `BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes` and `BORG_RELOCATED_REPO_ACCESS_IS_OK=yes` environment exceptions for the approved fleet compatibility cases; they are never request-controlled and are not general trust overrides. Record any necessary tool-local cache/lock effects in the tested profile with bounded handling; unsupported side-effect behavior blocks the profile. Borg offers no assumed native incremental cursor. If a bounded listing cannot be completed, report incompleteness rather than inventing resumable snapshot semantics.

### 4. Dropbox native JSON access

Use dedicated bounded API requests, informed by the bundled uploader but not its source/import or text output. Fixed allowlisted API endpoints cover authenticated identity, authorized-root listing and continuation. OAuth refresh is permitted authentication, with secrets kept internal and any persistence separately specified before implementation. Do not call existence-check helpers that create directories.

Resolve account/namespace identity natively, with an explicit origin-scoped provisional identity if unavailable. Retain file ID, revision, path, byte size and separate client/server timestamps. Listing a disabled backup method's historical root requires that root to remain configured/authorized; disabled generation alone is neither empty inventory nor permission for broader scans.

Bind opaque continuation to account, namespace, root and listing parameters using the canonical protocol rules. Detect malformed/repeated cursors, invalidation, rate limiting and malformed or oversized pages. Return bounded retry information, never unbounded retries. Full pagination and incremental deltas are separate capabilities. Admin owns atomic page/checkpoint persistence and absence reconciliation; the collector must not advance durable Admin state. Incremental support remains unadvertised until cross-repository crash/replay tests pass.

### 5. Dependency and compatibility gates

| Component | Proposed use | Current evidence / gate |
|---|---|---|
| Bash and core utilities | Isolated entry, timeouts and bounded temporary storage | Existing shell stack; exact required utilities and behavior must be verified |
| JSON parser (candidate: existing jq) | Requests, projection and native JSON | Probe executable and required features; missing parser is unsupported, with a safely encoded minimal failure path |
| Safe YAML parser | Typed Borgmatic projection | PyYAML safe-load profile is fixture-tested but not runtime/fleet-certified; binary named `yq` or pipx environment alone is insufficient |
| Borg | Structured repository archive metadata | Borg 1.2.0 profile is fixture-tested but not runtime/fleet-certified; sandbox tests remain required per profile |
| Borgmatic configuration | Configuration source only | No invocation of hooks or config execution; supported syntax matrix pending |
| HTTP client (candidate: existing curl) | Dropbox identity/list/refresh requests | Verify feature set, TLS behavior, bounded responses and secret transport |
| Dropbox native API | Root listings and continuation | Static source evidence only; authentication and pagination profiles unverified |

No installation, `pipx run`, network package fetching or new dependency without explicit confirmation. Missing prerequisites must be representable even when the normal JSON encoder is unavailable; a narrowly scoped bootstrap failure encoding path needs adversarial tests. Capabilities report only implemented and tested operations for the detected profile, with explicit unsupported diagnostics for unknown versions. This document certifies no runtime compatibility.

### 6. Isolation and contract verification

Use a dedicated future fixture harness under `tests/backup_observation/`; do not run `tests/tests_suite.sh`. Network-disabled containers, read-only configuration fixtures and fake Borg/HTTP executables record every attempted command. Hostile hooks and credentials contain canary side effects that must never occur. Test metadata, scope and secret behavior against the pinned upstream fixtures, including validation of failure reports and exit consistency.

Temporary state uses restrictive permissions, bounded storage and cleanup on signals. Cancellation, byte/item/time limits or truncated subprocess output cannot produce a complete observation. Diagnostics use allowlisted categories and sanitized text rather than forwarding arbitrary provider stderr.

## Risks / Trade-offs

- [Safe YAML/authentication subset omits real deployments] → Preserve unsupported evidence, measure fleet syntax later, and expand only through tested profiles and approved dependencies.
- [Provider listings change between pages] → Follow upstream consistency rules; never label an incomplete full scan authoritative or infer absence from one page.
- [Root collector could execute malicious configuration] → Strict typed parsing, explicit scope resolution, executable/environment allowlists, and side-effect canary tests.
- [Provider output embeds secrets or grows without bound] → Bound capture before parsing, allowlist returned fields and sanitize all failure paths.
- [Metadata mistaken for recoverability] → Separate timestamps, provenance and unknown classification; never assert successful execution, current dump contents or restorability.
- [Contract evolves concurrently] → Pin reviewed upstream schemas/fixtures before code and add conformance gates in both repositories.

## Migration Plan

The proposal artifacts define the approved additive collector boundary. The isolated collector is implemented locally and remains behind Admin's disabled-by-default rollout controls. Publish only the tested matrix, request explicit authorization for any scoped pilot, and do not change cron or upgrade servers as part of validation. Rollback disables Admin observation scheduling and reverts the collector release through an approved release process; stored backups require no migration.

## Open Questions

1. Which upstream contract revision, limits and shared fixtures are approved for implementation?
2. Which existing safe YAML/parser and provider versions are available across the fleet, and which literal authentication formats are necessary?
3. What exact Borg cache/lock effects are acceptable for each tested profile?
4. Will Dropbox OAuth refresh remain ephemeral or require an explicitly approved local credential update mechanism?
5. What measured listing volumes, timeout budgets and authorized historical roots inform the pilot?

## Proposal Tooling

The change metadata was scaffolded manually with the required patch tool to match the existing `spec-driven` layout. OpenSpec 1.3.1 is available and runs via the existing `eve-agents-app-dev:latest` Docker image, with its installed CLI directory and this repository mounted read-only, `--network none`, `--read-only` and telemetry disabled. No host Node execution or dependency installation is needed. OpenSpec artifact validation checks proposal structure only; it does not establish runtime/provider compatibility or upstream JSON conformance.
