# Plan: Borg Configuration Safety — First Delivery

## Status
- **Phase**: In Progress (real-tool integration and publication; not deployed)
- **Last Updated**: 2026-10-24

## Overview

Implement the first bounded delivery of the user's approved generic OSS correction. Specification: `openspec/changes/harden-borg-backup-configuration/`. No VPS-specific identifiers or credentials belong in implementation or fixtures.

## Requirements
- [x] Safe template-specific database constants and checked atomic new configuration generation.
- [x] Existing configurations preserved by generation, never silently migrated or deleted.
- [x] Correct classified initialization errors without raw diagnostic leakage.
- [x] Project-local failures do not disable unrelated backups.
- [x] Offline regression tests, operator documentation, and independent read-only review.

## Technical Design

### Database Changes
None. No changes to application databases or backup archives.

### API Changes
None. Preserve generator stdout status compatibility and existing public shell entry points.

### Implementation
Extract side-effect-free generation helpers; retain current repository URL spelling; validate needed constants and destination arrays; stage restrictive configs and publish atomically. Preflight with bounded `borgmatic repo-list --short --last 1` and initialize only a positively missing repository. Preserve trust challenges as errors. Propagate failure classes to the cron breaker and avoid counting config/trust failures as shared outages.

## Implementation Progress

### Phase 1: Generation
- [x] Implement and test safe generation.

`libs/local/borg_config_helper.sh` is definition-only on sourcing and is loaded
through the existing local-helper loader. It retains the generator status
protocol, uses loaded destination arrays, skips database detection for file-only
templates, requires supported concrete values, and checks writes and structure
before atomic no-clobber publication. Existing profiles (including empty-site
profiles and symlinks) are preserved. Restrictive hidden staging is cleaned on
failure/handled signals. Production directories and URL spelling are unchanged.

The existing WordPress database-name reader depended on an interactive helper
that also prints/logs values. Its database-name branch now reads literal PHP
definitions statically instead, without executing PHP or accepting expressions.
Other application environment files are still only read, never sourced.

### Phase 2: Initialization
- [x] Implement and test classification/preflight and breaker isolation.

Init now performs bounded read-only manifest preflight (`repo-list --short --last 1`) and creates only after
a positive repository-missing result. Config/relocation override misleading
already-exists/mismatch text. Generic missing files and unknown failures cannot
trigger init. Captured provider output is not logged/displayed. Checked
same-directory per-repository configs preserve multi-repository isolation and
the existing at-least-one-usable return contract. `BORG_INIT_FAILURE_REASON`
reaches cron through `borg_initialize_for_backup`; only shared network/auth/space
classes count in its extracted breaker helper, and success/local errors reset
the consecutive sequence. Independent traditional backup scheduling is unchanged.

### Phase 3: Validation and Documentation
- [x] Run `bash -n` on changed shell files.
- [x] Run `bash tests/test_borg_config_generation.sh`, `bash tests/test_borg_init_mismatch.sh`, and new initialization/isolation regression suites.
- [x] Run existing recovery, pause-hook, and backup resilience tests using their supported entry points.
- [x] Add manual remediation guidance and record test boundaries.

Validation on 2026-10-24 (all commands below exited 0 on final run):

```bash
bash -c 'for file in cron/backups_tasks.sh libs/borg_storage_controller.sh libs/local/borg_config_helper.sh libs/local/project_helper.sh tests/test_borg_config_generation.sh tests/test_borg_init_safety.sh tests/test_borg_init_mismatch.sh; do bash -n "${file}" || exit; done'
bash tests/test_borg_config_generation.sh
bash tests/test_borg_init_safety.sh
bash tests/test_borg_init_mismatch.sh
bash -c 'source tests/test_borg_repository_recovery.sh; test_borg_repository_recovery'
bash tests/test_borgmatic_pause_hooks.sh
bash tests/test_backup_project_resilience.sh
python3 -c 'import ast,pathlib; ast.parse(pathlib.Path("tests/fixtures/borg_safety_yq.py").read_text()); print("PASS: fixture Python syntax")'
openspec validate harden-borg-backup-configuration --strict
git diff --check
```

Results: new generation/init-safety suites passed; mismatch suite passed all five
test groups; recovery **14/14**; pause hooks **13/13**; backup resilience all ten
test groups passed. Recovery was invoked through its actual function entry point
(merely running that file does not execute its tests).

Generation fixtures cover Docker/default no-detection behavior, concrete
MySQL/Postgres names, missing/unresolved names, static WordPress/env detection,
idempotent empty/custom-profile preservation, absent config directories, two
destinations, empty/misaligned/unresolved destinations and invalid ports, every
YAML operation failing, successful-but-no-op mutations (including the first
mutation with realistic nonempty placeholders), missing/null/wrong-type required
constants on Docker and fallback/default paths, find/mkdir/mktemp/cp/chmod/ln
failures, concurrent creation, symbolic links, restrictive modes and cleanup.
Init fixtures cover all classes, success-like config/relocation messages,
generic missing-file/key negatives, timeout, only-positive-missing creation,
creation races, canary non-disclosure, multiple repositories, failed per-repo
mutation, empty/missing config, actual cron gate propagation and breaker resets.
The fake provider requires exactly the lightweight probe options, rejects `info`,
and verifies unsupported `repo-list` syntax never triggers init or fallback.
WordPress regressions include multiline/inline-commented retired definitions
followed by an active expression, duplicate/ambiguous definitions, plain header
comments, and no `.env` fallback for ambiguous WordPress files.

Operator guide: `docs/borg-configuration-safety.md`. Manual remediation must back
up profiles outside **all** Borgmatic scan dirs, prove unused constants before
removing them, supply application-specific concrete values when referenced, and
separately verify repository identity before any approved relocation procedure.

Validation limitations:
- No cron script or full `tests/tests_suite.sh` was sourced/run. No host/service,
  SSH/provider, install, commit, push or deployment operations were performed.
- Host `yq`, Borgmatic and ShellCheck are unavailable. The strict offline `yq`
  double handles JSON-subset fixtures, not real YAML. Supported-version real
  `yq`/Borgmatic/Borg integration and restore verification remain outstanding.
- Docker cache was inspected without pulling. A read-only/no-network probe of
  existing `tukibrain-tools:latest` found neither executable (exit 127):
  `docker run --rm --pull=never --network none --read-only --entrypoint /bin/sh tukibrain-tools:latest -c 'command -v yq; command -v borgmatic'`.
  No packages or images were installed/downloaded.
- The manifest probe bounds returned archive names, not all manifest/transport
  processing. It is not guaranteed constant time for all manifests. The
  300-second timeout and unsupported syntax fail closed with no initialization;
  there is no archive-info fallback. Supported-version/performance integration
  remains to be validated separately by the parent.
- WordPress detection intentionally supports a conservative static subset, not a
  general PHP parser. Ambiguous/commented definitions and expressions require
  explicit operator review rather than guessing or environment evaluation.
- Existing trust overrides/observer policy and pause-hook sanitizer are unchanged.
  Initialization partial-success behavior is retained; full per-destination
  create accounting and repository identity/path migration remain deferred.

### Phase 4: Review
- [x] Read-only review against `6f5d25a4`; fix and re-review findings (fallback described below).
- [x] Stop before deployment, commits, or remote configuration edits.

The `std-requesting-code-review` procedure was loaded from the global command.
Invoking `code-review` failed with `Agent code-review cannot run as a subagent`
because this repository configures it as primary-only. An independent `general`
subagent was instructed to follow `.opencode/agents/code-review.md` strictly
read-only and report separate Standards and Spec axes against the fixed baseline.
This is an explicitly recorded fallback, not a successful native agent invocation.

Initial review requested changes: S1 (expensive info preflight) was routed to
design and replaced by bounded manifest listing; P1 (exact generated identity
validation) and P2 (ambiguous WordPress definitions) were fixed in Build with
regressions. Independent re-review approved this bounded delivery with no
remaining must-fix findings. Real-tool integration remains a release gate, not
a claim inferred from the test doubles.

The parent session independently reran all six Bash regression commands listed
above, changed-shell syntax checks, strict OpenSpec validation and
`git diff --check`; all exited 0 after the review fixes.

Review revisions implemented locally (awaiting parent re-review):
- **S1**: replaced archive-statistics `info` with the approved bounded manifest
  probe and added exact-options/no-info/unsupported-syntax regressions.
- **P1**: validate exact requested project/group/hostname string equality rather
  than nonempty values. Added realistic nonempty template placeholders and
  missing/null/type cases, including fallback/default generation. The tool double
  evaluates supplied comparisons and faithfully models `null != ""` as true,
  rather than substituting truthiness or a hardcoded expected result.
- **P2**: reject commented/duplicate/nonliteral WordPress database definitions
  with a conservative static comment scan, without executing PHP or falling back
  to potentially stale `.env` values. Added inline/multiline and ambiguity cases.

All validation commands above were rerun after these revisions. Task 4.1 remains
unchecked; this is not an independent-review completion claim.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-24 | User approved the general upstream approach; execute a bounded first delivery before identity migration. | Avoid coupling correctness fixes with a security-sensitive compatibility change. |
| 2026-10-24 | Existing configs are preserved; no automatic legacy cleanup in this delivery. | Custom hooks, constants, and includes cannot safely be inferred from incident examples. |
| 2026-10-24 | Do not change URL spelling or add relocation acceptance. | SSH paths are provider-specific and repository identity must be verified. |
| 2026-10-24 | Existing automatic trust flags and observer behavior require separate design review. | Their removal affects an existing compatibility contract and must not be a hidden side effect. |
| 2026-10-24 | Review S1 routed to design: replace archive-statistics `info` preflight with bounded `repo-list --short --last 1`. | Avoid repeating the historical 20–42 minute metadata scan; unsupported CLI syntax must fail closed, never trigger initialization. |
| 2026-10-24 | User authorized committing, pushing and trying an environment; choose a disposable local Docker environment and a feature branch. | Validate real tools without modifying production, existing configurations, or master. |

## Open Questions

Follow-up: verified path migration, explicit config repair tooling, removal of legacy automatic trust overrides, and per-destination partial-backup reporting. These are not completion claims for this delivery.

## Notes

Scope is local repository code and documentation only. Provider fakes establish deterministic behavior, not restore validity or supported-version integration. Risk is configuration/backup availability regression; mitigate with preservation, atomic writes, fixed-code diagnostics, and no remote deployment.

The first eight tasks for the bounded delivery are complete locally, including
the documented independent review fallback and re-review. The user subsequently
authorized integration testing and publication (tasks 5.1–5.4). Production
deployment remains excluded. The broader path/trust/migration work remains
outside this delivery, as does the separate Brolit Admin report discrepancy.

### Phase 5: Disposable Integration and Publication

- [x] Build and test `tests/borg-safety-integration/docker-compose.yml`.
- [x] Record real versions and generation/init/create/extract results.
- [x] Re-run offline regressions and independent read-only review.
- [ ] Commit the reviewed code, bump to 3.14.10, and merge/push master (user's updated request).

The pre-existing `tests/test-environment` exposes root-password SSH and requests
privileged mode; its Ubuntu yq package is not the Mike Farah yq required by the
generator. Rather than expand that legacy environment's privileges or change its
purpose, add a separate minimal environment. Its image build installs tools only
inside Docker. Runtime has no network, no ports, no capabilities, a read-only
checkout/root filesystem and temporary data in tmpfs. No application secrets or
host Docker socket are mounted. The integration script never sources cron.

Final integration matrix on 2026-10-24 (both builds and runs exited 0):

| OS / architecture | Borg | Borgmatic | Mike Farah yq | Result |
|---|---|---|---|---|
| Ubuntu 24.04 / amd64 | 1.2.8 | 2.1.7 | 4.47.2 | PASS |
| Ubuntu 24.04 / amd64 | 1.2.8 | 1.9.14 | 4.47.2 | PASS |

```bash
docker compose -p brolit-borg-safety -f tests/borg-safety-integration/docker-compose.yml build
docker compose -p brolit-borg-safety -f tests/borg-safety-integration/docker-compose.yml run --rm --no-deps borg-safety
BORGMATIC_VERSION=1.9.14 docker compose -p brolit-borg-safety -f tests/borg-safety-integration/docker-compose.yml build
BORGMATIC_VERSION=1.9.14 docker compose -p brolit-borg-safety -f tests/borg-safety-integration/docker-compose.yml run --rm --no-deps borg-safety
```

Both versions passed real-template generation/schema validation for Docker,
default, MySQL and PostgreSQL; unresolved required database rejection; existing
profile preservation; single and multi-repository missing-only initialization;
an existing-repository repeat probe; create/extract with exact payload comparison;
blocked relocation and missing-environment classification without creation.
Each run also passed six offline Bash suites and all 13 observer parser tests.

Real integration exposed and fixed two pre-existing PostgreSQL schema errors:
`postgres_databases` became `postgresql_databases`, and `format: sql` became
`format: plain`. It also exposed expected probe failure aborting under
`set -e`; capture now occurs inside explicit conditionals. These are bounded
schema/control-flow fixes, not PostgreSQL backup redesign. No production DB,
Docker-hook or provider behavior was exercised. Original validation limitations
above are historical; this matrix supersedes only the real-tool/local file
round-trip gap, not external-provider, large-repository or production recovery
readiness.

The container initially lacked PyYAML for the existing observer tests and its
default tmpfs was noexec, causing executable fixture lookup to fall through to
real yq. Test-image dependencies and explicit tmpfs exec corrected the harness;
no production behavior or host dependencies were changed to bypass tests.

Independent read-only review of the expanded delivery against `6f5d25a4`
approved the code with no must-fix findings, conditional on completing and
recording this matrix. The complete matrix subsequently passed. The same
documented native-agent-unavailable fallback was used. Parent syntax/Compose
configuration validation and whitespace checks also passed.

### Phase 6: Versioned Publication and Server Smoke Test

The user subsequently requested merging into the default branch, a distinct
version, and a test on epica-apps01. The actual default branch is `master`, not
`main`. Use version **3.14.10**, updating the release metadata and entrypoint
headers together without changing report protocol versions.

- [x] Run isolated release packaging/installer regressions and check metadata.
- [ ] Commit and merge into master; push without force and verify the remote SHA.
- [ ] Transfer only the published code/test fixtures into a separate root-only
  validation directory on epica-apps01 and run controlled synthetic-data tests.
- [ ] Record tested and active versions independently; do not activate a release
  or change cron, security metadata, existing configurations or backup archives.

Read-only server preflight on 2026-10-24 found a clean tracked legacy checkout at
`6f5d25a4` on master, no staged `/opt/brolit-shell/current`, Borg 1.2.8,
Borgmatic 2.1.7 and Mike Farah yq 4.44.6. Test that installed toolchain too.
Do not update the production Git tree: the documented release contract requires
an immutable bundle and staged installer for actual activation. A server smoke
test is not production activation and must not be reported as such.

Release regressions passed in the disposable container, including signed pinned
installation, tampered manifest/archive rejection, signature-enforced unsigned
downgrade rejection, first-contact trust, silent key-rotation rejection, and
rollback receipts. The first packaging attempt as capability-free container root
could not read owner-only checkout paths or preserve another UID's metadata;
running as the checkout owner's UID/GID resolved the harness issue without adding
capabilities. The exact passing invocation is documented in the integration
README. No generated private test keys or artifacts survived container removal.
