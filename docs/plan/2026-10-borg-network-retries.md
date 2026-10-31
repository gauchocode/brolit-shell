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

## Tests

`tests/test_borg_network_retries.sh` (offline, fake borgmatic + stubbed init
gate) covers: success on the third attempt, non-network init failure without
retry, `retries=0`, budget exhaustion, create failing once with network,
create failing for a non-network reason, breaker reset after recovery,
timeout-124 classification, and malformed retry values.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-31 | Never suppress transient network alerts | Operator requirement: a night without backups is serious |
| 2026-10-31 | Retry only the `network` class | Other classes are deterministic and retrying them just delays the report |
| 2026-10-31 | Keep `FAIL` and its format after the last attempt | Alerting semantics unchanged; attempts are logged, not hidden |
| 2026-10-31 | Config via `SERVER_CONFIG` + env, not borgmatic YAML | Avoids unknown-key schema failures in generated configs |
