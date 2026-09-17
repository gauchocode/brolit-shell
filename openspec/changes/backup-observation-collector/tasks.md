## 1. Contract and implementation approval gates

- [x] 1.1 Review this proposal and pin the approved brolit-admin canonical contract revision, referenced schemas and sanitized fixtures; reconcile any differences upstream before code.
- [x] 1.2 Record exact required executable features and a proposed parser/Borg/authentication support matrix from available tooling; request explicit confirmation for any new dependency, without installing it during investigation.
- [x] 1.3 Resolve safe YAML/authentication subsets, Borg cache/lock effects and Dropbox refresh persistence; document unsupported cases and obtain approval before runtime implementation.
- [x] 1.4 Confirm canonical request/report budgets and scope/continuation semantics with Admin; keep fleet operating defaults and pilot authorization as separate gates.

## 2. Isolated collector and configuration projection

- [x] 2.1 Add a network-disabled fixture harness under `tests/backup_observation/` with fake provider executables, read-only config fixtures and command/side-effect recording; never invoke the general test suite.
- [x] 2.2 Implement root-only `backup_observer.sh` and audited definition-only modules under `libs/backup_observation/`, proving runner, commons, script_init and brolit_lite are never invoked or sourced.
- [x] 2.3 Implement bounded stdin validation, canonical version/exit handling, protocol-only stdout, sanitized stderr and minimal valid missing-encoder failure output; test malformed input and unsupported versions.
- [x] 2.4 Add the read-only projection inside `utils/brolit_configuration_manager.sh`, audit source-time behavior and verify no full loader, migration, directory initialization or unrelated credential export occurs.
- [x] 2.5 Implement restricted literal credential parsing and sanitized subprocess environments; test malicious assignments, substitutions, hooks and command overrides without executing them.
- [x] 2.6 Implement authorized handle resolution and stale-handle rejection; test arbitrary paths/endpoints, scope mismatch and configuration changes.
- [x] 2.7 Implement capability probes, runtime/item/byte limits, bounded temporary state and signal cleanup; verify missing tools never trigger installation and interruption never reports completeness.

## 3. Borg discovery and metadata adapter

- [x] 3.1 Implement the approved typed Borgmatic configuration subset through a verified safe parser, including explicit unsupported diagnostics for includes/tags/substitutions outside that subset.
- [x] 3.2 Discover all configured repositories and source/database hints without hard-coded site paths; test two destinations, database-only and mixed configurations.
- [x] 3.3 Implement one tested structured Borg command/output profile at a time, preserving native IDs, timestamp provenance and nullable size semantics; reject untested versions without text fallback.
- [x] 3.4 Test unordered/same-day archives, valid empty listings and unavailable metrics; prove repository modification time and name order never determine backup freshness.
- [x] 3.5 Test independent destination failures, invalid YAML, inaccessible/missing repositories, locks, trust/relocation requests and output truncation; assert no backup/content/maintenance command or lock-breaking override occurs.
- [x] 3.6 Document measured local cache/lock effects for tested profiles and mark any unverified profile unsupported; do not advertise Borg-native incremental support.

## 4. Dropbox native listing adapter

- [x] 4.1 Implement restricted credential access, fixed endpoint JSON transport and the approved authentication/refresh path; verify tokens never enter observable argv, reports or diagnostics.
- [x] 4.2 Implement account/namespace and authorized-root discovery with provisional origin-scoped identity and disabled-generation historical-root cases.
- [x] 4.3 Implement bounded native full listing and preserve file IDs, revisions, byte sizes, paths and separate timestamps; retain unknown files and mark naming classifications as inferred.
- [x] 4.4 Implement scope-bound pagination and test multi-page success, interruption, malformed/repeated cursors, invalidation, namespace/root mismatch, oversized output and rate limits.
- [x] 4.5 Implement incremental deltas only if approved profiles and Admin atomic checkpoint/replay tests exist; otherwise explicitly report that capability unsupported.
- [x] 4.6 Prove API operation allowlists prohibit upload, download, restore, delete and directory creation, including mutation-capable helper calls.

## 5. Cross-repository conformance and release readiness

- [x] 5.1 Validate all operation and failure fixtures against the pinned Admin schemas, including scope correlation, timestamp semantics, limits, unknown values and exit/report consistency.
- [x] 5.2 Run network-disabled side-effect and secret-canary tests, including hostile configs/credentials and poisoned subprocess environments; inspect every attempted provider operation.
- [x] 5.3 Coordinate Admin tests for partial full scans, idempotent page replay, crash-before-checkpoint, cursor invalidation and no absence inference from incomplete observation.
- [x] 5.4 Run targeted shell syntax/lint checks on implemented files using available approved tooling and `git diff --check`; record unavailable checks without installing tools silently.
- [x] 5.5 Publish only tested tool/parser/authentication compatibility profiles, unsupported limitations and the pinned protocol revision; distinguish simulated fixtures from runtime validation.
- [ ] 5.6 Complete code/security review and obtain separate pilot/deployment authorization before any server operation; document additive rollout and rollback through Admin scheduling controls.
