## Phase A (approved)

- [x] Inspect existing dependency/parser profile and define separate static contract. (Reopened by the 2026-10-25 review: exact 6.0.3 pin replaced by PyYAML >= 5.4; closed by the fleet-version matrix.)
- [x] Record proposal/design/spec before implementation.
- [x] Implement strict bounded discovery, YAML/reference analysis and memory-only proposal.
- [x] Add isolated offline safety, confidentiality, bounds and proposal tests.
- [x] Document exact commands, protocol/schema and unsupported cases.
- [x] Run narrow offline validation and report results.
- [x] Parent session read-only code review (2026-10-25): request changes; see Admin `docs/reports/2026-10-25-backup-config-doctor-phase-a-review.md`.
- [x] Security review (not delegated by implementation agent): rounds 2 and 3 ran 2026-10-25/26 (Low for Phase A); findings closed or deferred to Admin parent plan Phase B.

## Review remediation (Admin `docs/plan/completed/2026-10-backup-config-doctor-remediation.md`)

- [x] Parser profile PyYAML >= 5.4 with `parser_profile`; non-relabelable timeout; mountinfo decoding; entry-point `PATH`/env hardening; tests moved to `tests/backup_config_doctor/` and made portable.
- [x] Decision A: `checks`/`check_last`, archive-field Borg placeholders, scanned hooks with `hook_intent_unknown` guard.
- [x] Decision B: source-path findings no longer block the proposal.
- [x] Decision C: `file`/`location` per profile.
- [x] Decision D: test mode refuses root and relative roots.
- [x] Decision E: root default locations and explicit limitations.
- [x] Documentation, schema (doctor 0.2.0) and OpenSpec updated.
- [x] Fleet-version matrix: Ubuntu 22.04 (Python 3.10.12 / PyYAML 5.4.1) and 24.04 (Python 3.12.3 / PyYAML 6.0.1); 33 tests passed unprivileged at the time (40 after Phase 6), and production `inspect` as root works on synthetic profiles in both.
- [x] Round-2 review (2026-10-25, Standards/Spec/Security): request changes (minor); security Low for Phase A.
- [x] Round-2 fixes: descriptor swap, outer timeout guard, `RLIMIT_CORE`, per-profile `MemoryError`, unparsed-sibling suppression, hook guard (literal command word, constant expansion, more locations), `CapEff` test-mode check, wrapper `PATH` pin, tests (40), docs.
- [x] Round-3 review (2026-10-26): request changes (minor).
- [x] Round-3 fixes: hook guard on raw and expanded bodies, memoized constant expansion with one shared budget, one-shot-safe `main()`, absolute `DOCTOR_DIR`, wording, tests (43), docs.
- [x] Round-4 focused verification (2026-10-26): clear to close Phase A after nit fixes.
- [x] Borgmatic 1.9.14 / 2.1.7 semantics check (2026-10-26, user-approved; disposable containers, fake `borg`): rule premise and fix confirmed; differences recorded in `docs/backup-config-doctor.md`.

## Explicitly excluded

Prepare/apply/rollback, deployment, SSH, repairs, installs, commits/pushes, Admin changes and mutation-capable global tests.

## Validation (2026-10-25, updated 2026-10-26)

- Python 3.14.8 / installed PyYAML 6.0.3; installed jsonschema 4.23.0 for optional protocol conformance.
- Initial delivery: 20 offline tests passed. After remediation: 43 tests pass with `DOCTOR_REQUIRE_PARSER=1` (33 after Phase 2, 40 after Phase 6, 43 after Phase 7); shell syntax checks pass per file; runtime verified on Ubuntu 22.04 (Python 3.10.12 / PyYAML 5.4.1) and 24.04 (Python 3.12.3 / PyYAML 6.0.1).
- Existing generation, init-safety and scheduled-routing regressions pass.
- Existing observer parser: 13 tests pass.
- Observer conformance script: unprivileged protocol check passes; provider checks explicitly skipped because this session is unprivileged. No sudo or permission escalation attempted.
- No production doctor invocation, Docker image build, install, SSH, deployment or configuration repair performed.
