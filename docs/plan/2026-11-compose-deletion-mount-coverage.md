# Plan: Compose deletion gate — verified mount coverage

## Status
- **Phase**: Complete
- **Last Updated**: 2026-11-17

## Overview

`project_compose_deletion_safe()` blocks the deletion of **every** project whose
installation type starts with `docker`:

```bash
[[ "${install_type}" == docker* ]] && return 1
```

The message shown is `Docker persistent mount backup coverage is not verified`,
which suggests a verifiable condition exists, but the function returns before
inspecting anything. Combined with `project_compose_runtime_inventory()`
(which only ever emits `coverage: "unverified"` and never authorizes), the
result is that **no docker-compose site can be deleted through brolit-shell**.

Reproduced on 2026-11-17 on `gaucho-dev02` (144.126.140.82), brolit-shell
3.14.14, job `be6c0f52-8df3-447f-b3e5-dca26595c0e2`:

```
- Selecting dev.real-services.broobe.net for deletion   [ DONE ]
- Docker persistent mount backup coverage is not verified  [ FAIL ]
```

The guard runs **before** `backup_project()` and before any container stop, so
the failure is clean (nothing was deleted, nothing backed up). On the tenant's
dev servers 17 of 20 sites are docker-compose, so the block is effectively
total for that class of project.

The guard protects something real: a pre-delete backup is a files tarball of
the project directory plus a database dump. It does **not** capture Docker
named/anonymous volumes, nor bind mounts living outside the project directory.
Deleting such a project orphans that data: the containers and the directory are
removed, the volumes and external paths stay behind unreferenced, and no backup
holds them.

## Requirements

- [ ] Deletion of a docker-compose project is allowed only when the platform can
      prove there is no persistent mount data outside the project directory.
- [ ] Every uncertain condition keeps the deletion blocked (fail closed), with a
      message naming the exact uncovered items.
- [ ] Nothing is stopped, backed up or removed before the gate resolves.
- [ ] Non-docker projects keep their current behavior unchanged, including the
      `COMPOSE_FILE` / stray-compose-file scans.
- [ ] Regression tests cover allow and block paths with a fake `docker` binary
      (no daemon, no host resources).

## Technical Design

### Coverage criterion (what "verified" means)

PASS only if **all** of the following hold:

1. Every container related to the project can be fully inspected
   (`docker inspect` succeeded, labels and mounts well-formed).
2. For every mount of every related container:
   - `bind` with `Source` inside the project directory → **covered** by the
     pre-delete files backup;
   - `tmpfs` → **not persistent**, nothing to lose;
   - `volume` (named or anonymous) → **uncovered**;
   - `bind` with `Source` outside the project directory → **uncovered**;
   - any other type → uncertainty → **block**.
3. No Docker volume exists for this Compose project, checked by label
   (`com.docker.compose.project`) and by name prefix (`<project>_`, `<project>/`).
4. The Compose project name is unambiguous: a single value across related
   container labels, or — when no containers exist — the sanitized directory
   basename plus an optional top-level `name:` from the Compose file. A
   `COMPOSE_FILE` declaration in any `.env` inside the project is treated as an
   unknown context and blocks.

If any step fails (missing `docker`, missing `jq`, daemon error, unparsable
output) → block. This mirrors the existing fail-closed style.

### `libs/local/project_helper.sh`

- New `project_compose_mount_coverage <project_dir>`: reuses the inspect loop of
  `project_compose_runtime_inventory()`, adds volume enumeration and the
  inside/outside classification. Returns `0` when clean, `1` when uncovered
  items exist (`UNCOVERED:<type>:<id>:<source>:<destination>` lines on stdout),
  `2` on uncertainty. Never prints environment or command fields.
- New `project_compose_volume_names <project_names...>`: wraps
  `docker volume ls --filter label=... --format '{{.Name}}'` plus the name-prefix
  fallback. Returns `2` on any error.
- `project_compose_deletion_safe()` keeps the non-docker branch as-is and, for
  `docker*` types, consults `project_compose_mount_coverage` instead of returning
  1 unconditionally.
- `project_delete()` / `project_delete_files()` messages differentiate:
  `- Docker persistent mounts are not covered: <n> item(s)` listing each one,
  versus the existing generic message when the inspection itself is uncertain.

### Out of scope

- Backing up Docker volumes (would change backup semantics and storage cost).
- Operator override flag for deliberate break-glass deletion.

### Latent issue found

`project_compose_reconcile()` invokes `${BROLIT_MAIN_DIR}/tools/compose-reconcile.py`,
which does not exist in the repository (`git ls-files tools/` has no such file).
The function is dead code that fails on every call. Reported here; removal or
implementation is a separate change.

## Implementation Progress

### Done

- [x] `project_compose_sanitize_name`, `project_compose_volume_names`,
      `project_compose_mount_coverage`, `project_display_deletion_block`.
- [x] `project_compose_deletion_safe` consults the coverage check for `docker*`
      types and keeps the hint scan for everything else.
- [x] Both call sites (`project_delete`, `project_delete_files`) capture the
      gate output and the gate exit code, and list every uncovered item before
      failing.
- [x] `project_dotenv_has_compose_file` extracted and reused by both the
      deletion gate and the compose-file hint scan.
- [x] `project_dotenv_compose_project_names`: `COMPOSE_PROJECT_NAME` from the
      project `.env`/`.env.docker` widens the volume lookup (brolit writes
      `${project_name}_stack` there, so the namespace is not the directory name).
- [x] Bind sources are re-resolved with `realpath -e`; a symlink pointing out of
      the project is uncovered, a source that does not exist holds no data.
- [x] The jq program uses explicit `if`/`select` instead of relying on `and`/`or`
      short-circuiting, and only requires `.project` on related containers
      (a missing `working_dir` label no longer blocks).
- [x] Gate exit code 2 gets its own message ("coverage could not be verified")
      distinct from 1 ("uncovered items"), for docker and non-docker projects.
- [x] `tests/test_compose_delete_safety.sh` rewritten around a fake `docker`
      with `clean`/`containers`/`volume`/`broken` modes: clean projects and a
      container with an in-project bind now reach the backup step; volumes and a
      broken inspection still block.
- [x] New `tests/test_compose_mount_coverage.sh`: 20 cases (bind inside/outside,
      bind through a symlink, missing bind source, named/anonymous volume,
      tmpfs, unrelated container, container without Compose labels, orphan
      volume by namespace, `COMPOSE_PROJECT_NAME` from `.env`, labelled volume,
      sibling prefix, missing label, malformed record, failed inspect, unknown
      mount type, `COMPOSE_FILE`, missing directory, missing `docker`, missing
      `jq`, name sanitization).
- [x] Both tests wired into `tests/tests_suite.sh` (menu options 25 and 26, and
      the "run all" path), restoring `PATH` so the fake `docker` never leaks
      into other tests.

### Validation

```
bash tests/test_compose_mount_coverage.sh     # ok
bash tests/test_compose_delete_safety.sh      # ok
bash tests/test_compose_runtime_inventory.sh  # ok
```

Full `tests/test_*.sh` sweep: 5 pre-existing failures, all in `test_borg_*`
(`brolit_configuration_manager.sh not found`), reproduced on a clean worktree at
`HEAD` — unrelated to this change.

## Tests

- Rewrite the `docker`/`docker-compose` block in `tests/test_compose_delete_safety.sh`:
  a project with no containers and no volumes must now reach the backup step
  instead of being blocked.
- New `tests/test_compose_mount_coverage.sh` with a fake `docker` on `PATH`:
  - no containers, no volumes → allowed;
  - named volume mounted → blocked, volume named in the message;
  - anonymous volume mounted → blocked;
  - bind outside the project dir → blocked;
  - bind inside the project dir → allowed;
  - leftover volume by compose label / name prefix → blocked;
  - `docker` absent, `jq` absent, malformed inspect output, daemon error → blocked;
  - `COMPOSE_FILE` in `.env` → blocked;
  - non-docker project with a stray compose file → unchanged.

## Rollout

1. Land in `brolit-shell`, bump the release version.
2. Update the servers (dev first: `gaucho-dev02`).
3. Re-run `delete_site_with_backup` from brolit-admin for the three pending
   sites; if any of them still reports uncovered items, the message now names
   the volume or bind path that blocks it, which decides the next step.

## Risks

| Risk | Mitigation |
|------|------------|
| Loosening a deliberate fail-closed gate | Only `volume`, external `bind` and uncertainty block; project-directory binds and tmpfs cannot lose data a files backup misses |
| Missing an orphan volume whose name/label does not match | Block on any uncertainty; check both label and prefix; require an unambiguous project name |
| Operator reads "allowed" as "data is backed up" | Message on success states the backup covers the project directory and database only |
| `jq`/`docker` unavailable on an old host | Explicit block with a distinct message |

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-11-17 | Pass when no volume / external bind is present | Exactly the data a pre-delete backup cannot capture; everything else is covered by the files tarball |
| 2026-11-17 | No operator override | An override would reproduce today's break-glass risk without audit; implement coverage instead |
| 2026-11-17 | Do not back up Docker volumes in this change | New storage cost and restore semantics; separate plan |
| 2026-11-17 | `.env` `COMPOSE_PROJECT_NAME` widens the volume search instead of blocking | brolit always writes it (install and restore), so blocking would re-break every Docker site; a hit under any candidate namespace still blocks |
| 2026-11-17 | Bind sources resolved with `realpath -e`; a missing source is covered | A path that does not exist holds no data; a symlink resolving outside the project is data the tarball does not contain |
| 2026-11-17 | Related containers only require `.project`, not `.working_dir` | The label names the volume namespace; requiring both blocked containers from `docker run` and old Compose |
| 2026-11-17 | A deletion may skip an absent/stopped DB dump only after the mount gate passes | A missing container has no live DB to dump; volumes/external binds still block, and in-project data is in the files archive. Unknown inspect output always fails |

## Review findings

A read-only review of the first implementation raised two high-severity items
and several medium ones. All of them are addressed:

| Finding | Resolution |
|---|---|
| `COMPOSE_PROJECT_NAME` ignored → orphan volumes under `${project_name}_stack` escaped (fail-open) | `project_dotenv_compose_project_names` adds every declared name to the volume lookup |
| jq `and`/`or` on nullable labels could abort or silently misclassify | Explicit `if`/`select`, plus a fixture with `working_dir: null` |
| Tests unreachable from the documented runner | Both wired into `tests_suite.sh` |
| Integration test never exercised a real container | `containers` mode with `working_dir` and an in-project bind |
| Multi-container / ambiguity untested | Covered by the missing-label and unrelated-container fixtures |
| Duplicated `.env` scan | Extracted `project_dotenv_has_compose_file` |
| Fake `docker` leaked into `PATH` | `PATH` restored at the end of both tests |
| `name:` parsing accepted comments and `$` interpolation | Comment stripped, interpolated values treated as unknown |
| Block message did not distinguish rc 1 from rc 2 | `project_display_deletion_block` takes the gate exit code |
| Bind source through a symlink counted as covered | `realpath -e` containment re-check |
| Plan said volumes are "destroyed"; they are orphaned | Wording corrected below |

## Deployment and live verification

- Released as 3.14.16 (`bbaf1a79513feed08d2bfb610275af6cafe56f23`), pushed to
  `origin/master` and installed through the staged installer on `gaucho-dev02`
  and `gaucho-dev04`. Both report the release commit, `backup-progress.v1`, and
  `valid` validation after an Admin sync.
- The first staged deployment exposed that Admin still invoked the legacy
  `/root/brolit-shell/runner.sh`; Admin commit `75ed380` now selects
  `/opt/brolit-shell/current/runner.sh` when the synced release metadata exists.
- All requested deletions on `gaucho-dev02` completed: app
  (`e82f3f19-a30f-4b8b-aa1d-588fb1321de5`), Supabase
  (`99220eac-cdef-430c-bdb4-6bc802f51ddd`) and Firecrawl
  (`264038a0-5826-4755-9fa7-69a60cb37926`). The final inventory has 7 sites and
  none of the three domains remains.

## Open Questions

1. Should tmpfs-only projects with a running database container be considered
   covered? Current answer: yes, tmpfs dies with the container and the database
   dump covers the data.
2. Which Compose runs on the fleet — v1 (`docker-compose`) or v2? The gate does
   not depend on it (labels are read from containers), but the v1 packaging
   question decides whether `COMPOSE_PROJECT_NAME` is authoritative there.

