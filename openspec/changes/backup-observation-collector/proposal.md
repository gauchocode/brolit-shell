## Why

Existing inventory conflates configuration, stored artifacts and backup freshness, and its entry points can mutate server state during initialization. Admin needs bounded, per-destination evidence collected through an isolated shell boundary before it can evaluate protection accurately.

## What Changes

- Propose a root-only standalone `backup_observer.sh` with capabilities, discovery and single-scope inventory operations, independent of `runner.sh`, `script_init`, `libs/commons.sh` and `brolit_lite.sh`.
- Add a read-only backup configuration projection inside `utils/brolit_configuration_manager.sh`, with non-executing credential parsing and explicit unsupported-format outcomes.
- Introduce independent Borg repository metadata observations and native JSON Dropbox listing with bounded, scope-bound pagination.
- Return facts, provenance, completeness and sanitized errors using Admin's canonical versioned contract; Admin owns persistence, tenant binding, policy and alerts.
- Require isolated conformance and compatibility tests before advertising adapter support. The approved local implementation is now materialized; this artifact still does not authorize a pilot, deployment or production operation.

## Capabilities

### New Capabilities

- `backup-observation-collector`: Standalone entry, safe configuration projection, protocol compliance, limits and isolation.
- `borg-backup-observation`: Safe Borgmatic discovery and per-repository structured Borg archive metadata.
- `dropbox-backup-observation`: Authorized root discovery, native identity and safe full/incremental listing semantics.

### Modified Capabilities

None. No canonical specs currently exist in `openspec/specs/`; existing migration change artifacts are unrelated.

## Impact

The approved local implementation affects a new standalone entry and narrowly scoped observation modules, the configuration manager, isolated tests and compatibility documentation. Existing backup/restore commands and general inventory are not rerouted.

Canonical upstream references are in the sibling **brolit-admin** repository:

- `docs/plan/active/2026-09-backup-observability.md` (approved Phase 1 scope).
- `docs/architecture/backup-observation-contract.md` (canonical protocol checkpoint and links to its formal schemas/fixtures as published).

Exact wire fields, enum values, limits, exit codes and schema versions are defined upstream, not independently here. The approved revision and fixtures are pinned before implementation. No new dependency is approved; missing tools produce explicit limitations. Production operations, pilot authorization and release remain outside this proposal.
