# Plan: Borg network-failure retries

## Status
- **Phase**: Complete
- **Last Updated**: 2026-10-31

## Overview

A single night of failed backups is a real incident, so transient network
errors must not be suppressed or downgraded. Instead of dropping the alert,
`backup_borgmatic_config_once` now retries network-class failures with
backoff before declaring the backup failed. Every other failure class keeps
the previous single-attempt behaviour, and a run that exhausts its attempts
still reports `FAIL` exactly as before.

Motivation: Storage Box connectivity can flap for minutes (route changes,
storage-side refusals). Without retries, one bad minute costs a whole night
of backups for every project on the host.

## Technical Design

### Where

`libs/local/backup_helper.sh::backup_borgmatic_config_once` wraps the existing
`borg_initialize_for_backup` gate and the `borgmatic --stats` create step in an
attempt loop.

### Retry policy

- Retry only when `borg_init_failure_reason` returns `network` (connection
  refused/reset/timeout, unreachable host, DNS resolution failures). The same
  classifier now also covers create-step failures, whose output is captured
  and re-printed so logs keep the borgmatic stats.
- Attempts budget: `1 + BROLIT_BORG_NETWORK_RETRIES` (default 2, i.e. three
  attempts total).
- Backoff: `_borg_network_retry_delay` = base seconds * 2^(retry-1), capped at
  300s. `BROLIT_BORG_NETWORK_RETRY_DELAY=0` retries immediately (used by the
  offline tests).
- `BROLIT_BORG_NETWORK_RETRIES=0` reproduces the previous single-attempt
  behaviour exactly.
- Non-network reasons (`config`, `auth`, `relocation`, `lock`, `space`,
  `python_env`, `encryption_mismatch`, `repo_missing`, `unknown`) never retry.
- A create step killed by GNU `timeout` (exit 124, usually silent) is mapped
  to `network`, mirroring the init path's config/relocation exceptions.
- Succeeding after network retries clears the run-level
  `BORG_REPO_UNAVAILABLE` breaker; otherwise later projects would be
  `SKIPPED` while the recovered one reported `OK`.
- Retry/delay values are validated as non-negative integers, and environment
  variables take precedence over the JSON default for ad-hoc runs.

### Configuration

`utils/brolit_configuration_manager.sh` reads two optional
`SERVER_CONFIG` keys and exports them with defaults:

| Key | Default | Meaning |
|---|---|---|
| `borg_network_retries` | `2` | Extra attempts after the first failure |
| `borg_network_retry_delay` | `30` | Base backoff seconds (0 = no wait) |

Environment variables of the same names (`BROLIT_BORG_NETWORK_RETRIES`,
`BROLIT_BORG_NETWORK_RETRY_DELAY`) take effect for ad-hoc runs. No per-project
keys were added to borgmatic YAML, to stay inside its configuration schema.

## Storage auto-remediation (2026-10-31)

The init gate now also fixes the storage-side layouts that used to keep a
host's backups failing night after night:

- `repo_missing` additionally matches Borg's real `is not a valid repository`
  message. Before, that text fell through to `unknown`, so missing
  repositories were never initialized at all.
- `parent_missing` (`The parent path of the repo directory ... does not
  exist`): `borg_storage_create_parent_dirs` creates the directory chain over
  SFTP and init is retried once. This is what a host/group that never backed
  up before hits on a fresh Storage Box.
- `stale_lock` (`There is already something at ...`):
  `borg_storage_clear_stale_locks` removes `lock.roster`/`lock` files, but
  only when every entry in the directory is a lock file. Anything else
  (`config`, `data`, …) aborts the cleanup, so a real repository cannot be
  damaged. The listing uses `ls -la` (dotfiles and symlinks cannot slip past
  the guard), `lock.exclusive` directories are emptied before `rmdir`, and a
  cleanup is only reported as successful when every removal succeeded.
- Repository URLs are validated before any remote operation: relative
  `ssh://host/./path` URLs stay login-relative (no `/./` absolute paths),
  and malformed, root-level, globbed or traversal paths are rejected.
  Classifier precedence is unchanged for the other classes, and the
  remediation retry keeps the exit-124-to-network mapping.
- Network failures caused by a missing IPv6 default route export
  `BORG_RSH=ssh -4`, so the caller's retries use IPv4 instead of repeating
  the identical unreachable attempt (init gate and create step).

Helpers live in `libs/borg_storage_controller.sh` (`_borg_parse_repo_url`,
`_borg_sftp_run`, `borg_storage_create_parent_dirs`,
`borg_storage_clear_stale_locks`).

## Tests

`tests/test_borg_network_retries.sh` (offline, fake borgmatic + stubbed init
gate) covers: success on the third attempt, non-network init failure without
retry, `retries=0`, budget exhaustion, create failing once with network,
create failing for a non-network reason, breaker reset after recovery,
timeout-124 classification, and malformed retry values.

`tests/test_borg_storage_remediation.sh` covers the new classes in the
classifier, parent directory creation, lock cleanup including the "real
repository present" guard, and the IPv4 fallback.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-31 | Never suppress transient network alerts | Operator requirement: a night without backups is serious |
| 2026-10-31 | Retry only the `network` class | Other classes are deterministic and retrying them just delays the report |
| 2026-10-31 | Keep `FAIL` and its format after the last attempt | Alerting semantics unchanged; attempts are logged, not hidden |
| 2026-10-31 | Config via `SERVER_CONFIG` + env, not borgmatic YAML | Avoids unknown-key schema failures in generated configs |
