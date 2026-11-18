# Plan: Legacy brolit-shell runtime migration

## Status
- **Phase**: Planning
- **Last Updated**: 2026-11-18

## Overview

Two active servers still run legacy brolit-shell trees instead of staged releases:

- `gaucho-apps01-ds4` — 3.6
- `gaucho-dedicate01-gcds-1264` — 3.9

The staged fleet runs 3.14.16 from `/opt/brolit-shell/current`. These hosts need
a separate migration plan because a staged install changes the runtime root and
activates many versions of behavioral changes at once. This document does not
authorize execution.

## Requirements

- [ ] Preserve existing sites, databases, storage credentials, cron schedules and
      notification configuration.
- [ ] Keep the legacy `/root/brolit-shell` tree untouched as a rollback source.
- [ ] Validate one host at a time; no simultaneous migration.
- [ ] Restore the previous runtime if inventory, a representative backup or a
      representative site operation fails.
- [ ] Record exactly which workflows were tested; installation alone is not
      validation.

## Technical Design

### Current compatibility path

The staged installer writes `/opt/brolit-shell/releases/<version>-<commit>` and
atomically replaces `/opt/brolit-shell/current`. Admin inventory already prefers
that root, and task execution switches to `current/runner.sh` once synced release
metadata exists. Server configuration remains in `/root/.brolit_conf.json` and
other legacy locations until a separate configuration-migration plan.

### Pre-migration inventory

For each host, capture and privately review:

- exact current commit/version and whether the tree has local modifications;
- sites, install types, databases, Compose versions and mount shapes;
- enabled backup methods, retention, schedules and current backup protection;
- cron entries and custom scripts that hardcode `/root/brolit-shell`;
- available disk, supported Bash/jq/docker versions and outbound connectivity;
- the previous night's actual backup results, not only their presence.

### Compatibility fixtures

Before touching either host, run the current test suite plus representative
fixtures for the host's actual project types. Pay particular attention to:

- restore from every enabled storage method;
- Docker Compose database discovery and deletion coverage;
- credential/config paths that remain under `/root`;
- cron behavior under a non-interactive environment;
- notification formats and any custom scripts that source internal shell files.

### Installation and activation

1. Take a fresh verified backup and a host-level snapshot where available.
2. Build the release from a clean, pushed commit; record its SHA-256.
3. Stage the bundle through the Admin worker SSH path and verify the checksum.
4. Run the official staged installer. Do not pull into or modify the legacy Git
   tree.
5. Run metadata validation, inventory sync and a read-only server-status task.
6. Run one representative backup and verify the resulting archive.
7. Exercise one low-risk site workflow before marking the host migrated.
8. Update Admin inventory and record the activated release and evidence.

### Rollback

Use the staged installer's rollback command to the exact previous release when
one exists. A legacy tree has no staged release name, so the first migration must
also document and test an explicit legacy rollback: repoint any runtime selector
or remove the staged release metadata only through a reviewed procedure. Do not
invent that rollback during an incident.

## Implementation Progress

### Phase 1: Discovery
- [ ] Capture both hosts' inventories and local modifications.
- [ ] Identify hardcoded legacy paths and custom consumers.

### Phase 2: Compatibility and rehearsal
- [ ] Build host-specific compatibility fixtures.
- [ ] Rehearse installation and legacy rollback on a disposable host.

### Phase 3: Migration
- [ ] Migrate `gaucho-apps01-ds4` and validate.
- [ ] Migrate `gaucho-dedicate01-gcds-1264` only after the first host is stable.

### Phase 4: Closure
- [ ] Record validation, rollback targets and remaining legacy consumers.
- [ ] Decide whether/when to archive the old trees; never delete them as part of
      the initial migration.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-11-18 | Separate plan, no immediate execution | The version gap and runtime-root change are materially larger than the staged fleet patch |
| 2026-11-18 | One host at a time, legacy tree preserved | Limits blast radius and keeps rollback evidence available |
| 2026-11-18 | Configuration migration is out of scope | Runtime activation and moving `/root/.brolit_conf.json` are independent risks |

## Open Questions

1. Do these hosts have local changes or custom cron/scripts that depend on
   internal shell functions rather than the public runner interface?
2. Is a host-level snapshot available for each server?
3. Which low-risk site workflow is acceptable as the post-migration functional
   check on each host?
4. Who owns the maintenance window and the decision to roll back?

## Notes

`stellacast-gpu` remains excluded by the user's current decision. This plan does
not include it.
