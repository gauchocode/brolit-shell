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

## Follow-up fixes from the first post-rollout night (2026-11-01)

The first night after the rollout surfaced three more blockers, now fixed and
covered by tests:

- The `network` classifier missed the most common SSH disconnect texts
  (`Connection closed by remote host`, `ssh_exchange_identification`, broken
  pipe), so those failures were classified `unknown` and never retried.
- `project_get_database_name` propagated compose-level `${VAR}` placeholders
  into borgmatic constants instead of resolving them from the project's
  `.env`. Affected project: `support.epicahub.com`.
- Projects with no database engine detected used to fall back to the MySQL
  template, producing a `mysql_databases` section whose `${database}` constant
  cannot resolve. New explicit opt-out: `BROLIT_DB_ENGINE=none` in the
  project's `.env` selects `borgmatic.template-default.yml`. Applied to
  `s3.planning-mkt.broobe.net` (MinIO).

`redcoach-test` additionally needed a borgmatic upgrade (1.8.11 had no
`repo-list` action, which the init gate uses as preflight); it is now on
2.1.7 like the rest, with relocations accepted and repositories initialized.

### Review follow-ups (2026-11-01, after the fleet rollout)

- The `network` classifier no longer matches a bare `connection closed`: it
  also matched sshd's `Connection closed by authenticating user ... [preauth]`,
  so an auth refusal was retried three times and reported as a network fault.
  The preauth form is now classified `auth`.
- Retries of one project record a single consecutive failure for the run-level
  breaker. Previously every attempt counted, so a three-attempt network failure
  tripped the limit of 3 inside the first project and skipped every later one.
- The retries knob is read into a local with a default so the arithmetic is
  safe under `set -u` (the previous form only worked because cron does not use
  `set -u`).

## Second-night fixes (2026-11-03, commits afa5a7a8..5a6fdcc8)

The 2026-11-03 nightly run surfaced four real defects, all fixed and rolled
out to all 14 servers:

1. **Stale destination locks stayed forever** (`epica-apps01`, `gaucho-dev04`,
   and any multi-destination config). A Storage Box kept a `lock.roster` from
   a borg process that died with its ssh session; borg waits `lock_wait` and
   gives up, and every later run repeats it, so the secondary
   (disaster-recovery) destination stopped receiving backups for days
   (`draw.epicahub.com`'s secondary last archived 2026-10-28). Fix:
   `borgmatic break-lock` on the config (covers every repository; guessing
   the failing URL from label-only output was unreliable) when the create or
   the preflight classifies `lock`, then one retry. Guard: never break while
   any local borg process is alive (a real lock must survive). Verified live:
   break + re-create succeeded for `draw.epicahub.com` and
   `wiki.epicahub.com`.
2. **The `on_error` hook called a function that does not exist for borgmatic.**
   `send_notification` lives in brolit's `notification_controller.sh`, but
   borgmatic runs hooks under `/bin/sh` without those libs, so every failing
   backup ended with `send_notification: not found` (exit 127) and borgmatic
   surfaced the hook failure instead of the repository reason. Templates now
   ship a plain `echo` hook and `sanitize_borgmatic_notification_hooks`
   rewrites configs generated from the old templates.
3. **The docker log-collection hook failed completed backups.** Non-Docker
   projects have no `docker-compose.yml`, so `docker compose ... logs` exited
   1 and borgmatic reported the repository action as failed even though the
   archive had been created (`support.broobe.net` failed nightly for this).
   The template hook is now a no-op without a compose file and
   `sanitize_borgmatic_docker_log_hooks` rewrites existing configs.
4. **Stale configs and unclassified failures.** A config whose project
   directory is gone now classifies as `missing_source` (was `unknown`), and
   the create failure status carries its class (`FAIL (<reason>)`) so the
   email states one actionable cause per project.

Fleet operations done the same night:

- `redcoach-docker01`: borgmatic 1.8.11 -> 2.1.7 via pipx; preflight
  (`repo-list`) now works, so its `unknown` init class is gone.
- `gaucho-automate01`: diverged master realigned to `5a6fdcc8`
  (`backup/pre-rollout-20261103` = 7b05939e). Borg stays disabled per
  operator config; the certificate triage is live.
- `redcoach-test`: `dev.provider` had `database: ${POSTGRES_DB}` left
  unsubstituted (borgmatic's env interpolation failed under cron) ->
  substituted to `postgres` from the project `.env`; `dev.bustracker`,
  `dev.socket` and `stage.booking` verified healthy by dry-run.
- `arqa-web-vm`: `bonus.arqa.com` failed because `/var/www/.../dumps/` did
  not exist (dump hook target) -> directory created, backup green;
  `dev.arqa.com` references a dead MySQL database (`arqa_dev`, project
  decommissioned: no code, no `.env`) -> config regenerated with the
  explicit no-database opt-out (`BROLIT_DB_ENGINE=none`), backup green.
- `epica-apps01`: stale config `support.broobe.net` (project directory
  removed) deleted with a backup copy at
  `/root/support.broobe.net.yml.removed-20261103`.

## Tests

`tests/test_borg_network_retries.sh` (offline, fake borgmatic + stubbed init
gate) covers: success on the third attempt, non-network init failure without
retry, `retries=0`, budget exhaustion, create failing once with network,
create failing for a non-network reason, breaker reset after recovery,
timeout-124 classification, and malformed retry values.

`tests/test_borg_storage_remediation.sh` covers the new classes in the
classifier, parent directory creation, lock cleanup including the "real
repository present" guard, the IPv4 fallback, the `missing_source` class,
and the `lock` remediation (break-lock invoked per config, the live-process
guard, failed break reported, preflight lock retried).

`tests/test_borgmatic_pause_hooks.sh` additionally covers the
`send_notification` hook replacement, the guarded docker log hook, template
hygiene, and the nightly wiring of both sanitizers.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-31 | Never suppress transient network alerts | Operator requirement: a night without backups is serious |
| 2026-10-31 | Retry only the `network` class | Other classes are deterministic and retrying them just delays the report |
| 2026-10-31 | Keep `FAIL` and its format after the last attempt | Alerting semantics unchanged; attempts are logged, not hidden |
| 2026-10-31 | Config via `SERVER_CONFIG` + env, not borgmatic YAML | Avoids unknown-key schema failures in generated configs |
