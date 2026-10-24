## 1. Safe generation

- [x] 1.1 Extract testable generation helpers and add regressions for template-specific constants and existing-config preservation.
- [x] 1.2 Implement checked atomic generation with concrete required database names and loaded destination arrays.

## 2. Safe initialization and isolation

- [x] 2.1 Add safe preflight/classification regressions and initialize only positively missing repositories.
- [x] 2.2 Propagate classified results to cron, isolate project-local failures, and reset consecutive failures on success.

## 3. Documentation and validation

- [x] 3.1 Document generation behavior, diagnostics, manual existing-config remediation, and deferred trust/path migration.
- [x] 3.2 Run syntax checks and standalone Borg/regression suites; record exact commands and limitations.

## 4. Review gate

- [x] 4.1 Run read-only code review against commit 6f5d25a4 and resolve findings before delivery.
- [x] 4.2 Update the implementation plan and stop before any server deployment.

Review execution: the `std-requesting-code-review` invocation of `code-review`
was rejected because the local agent is configured as primary-only. An independent
general subagent followed its read-only instructions as the explicit fallback.
The first review requested three fixes; all were implemented and the re-review
approved the bounded local delivery with no remaining must-fix findings.
Real-tool validation was initially deferred; the bounded local matrix below
subsequently passed. Production-provider and database recovery remain separate
deployment gates.

## 5. Disposable integration and publication

- [x] 5.1 Build an isolated Ubuntu container with real yq, Borgmatic and Borg, without production mounts, SSH or runtime networking.
- [x] 5.2 Run real-template generation, initialization, negative interpolation and file backup/restore integration tests; record exact versions and results.
- [x] 5.3 Re-run offline regressions and read-only review; resolve findings before commit.
- [ ] 5.4 Commit the reviewed changes, bump to 3.14.10, merge/push the actual default branch (master), and record publication verification.

## 6. Versioned server smoke test

- [x] 6.1 Validate release packaging and runtime metadata for 3.14.10 before publication.
- [ ] 6.2 Test the published commit in an isolated directory on epica-apps01 without activating it or changing production configurations, archives, or cron.
- [ ] 6.3 Record tested/active versions separately and leave production activation and legacy remediation behind an explicit operator gate.
