## Why

Moving a site between two brolit-managed VPS should be one command run from the source server, not a manual multi-step process the operator coordinates by hand. It became clear through design iteration that brolit's own restore path (`restore_project_backup()` → `_configure_restored_project()` → `project_update_domain_config()` in `libs/local/project_helper.sh:3153`) already creates the nginx vhost, updates the Cloudflare DNS record to the local server's IP, and issues the SSL certificate via certbot automatically whenever a project is restored — so `migrate` does not need to reimplement any of that. It only needs to orchestrate: backup on source, transfer over SSH, trigger a normal restore on the destination, verify, and — only if explicitly requested — decommission the source.

## What Changes

- Add a new `migrate` task, invoked **only from the source server**: `runner.sh -t migrate -st site -D <domain> --dest-host <host> --dest-user <user> [--dest-port <port>] --dest-ssh-key <path> [--decommission-source] [--purge-volumes] [--force]`.
- **Scope for v1: Dockerized projects.** Kept from the prior iteration — it's what will actually be validated against real traffic (`tukiverse-apps03` → `epica-apps02`), and the source decommission step (`docker compose down`, vhost/cert removal) is only specified for Docker projects. Host/classic project migration and decommission are deferred.
- `migrate` requires **brolit-shell to be present and configured on the destination**. It checks this over SSH before doing anything else:
  - If brolit is missing entirely, `migrate` installs it (clone + minimal non-interactive config: webserver role enabled) as a best-effort bootstrap.
  - If brolit is present but missing the config needed for restore's automatic DNS/SSL step (`SUPPORT_CLOUDFLARE_STATUS`, `PACKAGES_CERTBOT_STATUS`), `migrate` reports this clearly and does not proceed with automatic DNS/SSL config copying unless the operator explicitly opts in via `--bootstrap-dest-config` (copies the relevant Cloudflare section from the source's own `.brolit_conf.json`).
  - **For the real-world validation against `epica-apps02`, this destination is already brolit-provisioned and configured**, so the install/bootstrap path is built but not the primary path being exercised initially — it's tracked as a known gap to validate later.
- SSH credentials are supplied **per invocation as CLI flags** (`--dest-host`, `--dest-user`, `--dest-port`, `--dest-ssh-key`) — nothing new is persisted in `.brolit_conf.json`.
- Backup on the source reuses `backup_docker_project()` unmodified. The artifact is transferred to the destination directly over SSH (`rsync`/`scp`) — no shared remote storage account required.
- Restore on the destination is triggered remotely via SSH by invoking the destination's own `runner.sh -t restore -st from-local ...` — reusing 100% of the existing, tested restore logic (files, DB, Docker bring-up with port-collision handling, nginx vhost, Cloudflare DNS update, SSL issuance). `migrate` does not reimplement any of this.
- After restore, `migrate` verifies the destination responds (both via `--resolve` against the destination's IP, bypassing DNS propagation delay, and a plain external check).
- **Decommissioning the source is opt-in, not automatic**: only when `--decommission-source` is passed AND the destination verification succeeded does `migrate` stop the source's Docker Compose stack, remove its nginx vhost and SSL certificate files, remove the project directory, and de-register the project from the source's `.brolit_conf.json` — leaving only the backup artifact in brolit's tmp/backup folder on the source. Docker named volumes are preserved unless `--purge-volumes` is also passed, as an extra safeguard against irreversible data loss.
- If migration fails at any point before decommissioning is reached, the source is left completely untouched — decommissioning is strictly the last step and is never attempted after a failed or unverified migration.

**BREAKING**: none — purely additive; no existing command or flag changes behavior.

## Capabilities

### New Capabilities
- `site-migration`: SSH-orchestrated, single-command migration of a Dockerized project from a source VPS to a destination VPS, run entirely from the source, reusing existing backup and restore logic on each end (no new DNS/SSL/vhost logic), with an explicit opt-in step to decommission the source once the destination is verified.

### Modified Capabilities
(none — no existing spec files in `openspec/specs/`)

## Impact

- New CLI flags in the flag parser (`libs/task_runner.sh`, near the existing `-D|--domain` block): `--dest-host`, `--dest-user`, `--dest-port`, `--dest-ssh-key`, `--decommission-source`, `--purge-volumes`, `--bootstrap-dest-config`, `--force`.
- New `case migrate)` branch in the task dispatcher (`libs/task_runner.sh`).
- New helper module `libs/local/site_migration_helper.sh`: pre-flight (Docker project check, SSH connectivity, destination brolit/config check with optional bootstrap install), backup + transfer orchestration, remote restore trigger, verification, and gated source decommissioning.
- Reuses without modifying: `libs/local/backup_helper.sh` (`backup_docker_project()`), `libs/local/restore_backup_helper.sh` (`restore_project_backup()` / `restore_backup_from_local_cli()` triggered remotely, not called in-process), `libs/local/project_helper.sh` (`project_update_domain_config()`, invoked indirectly via the remote restore, not called directly).
- New test file `tests/test_site_migration.sh`.
- Real-world validation planned against `tukiverse-apps03` (source) → `epica-apps02` (destination, already brolit-provisioned), using Dockerized projects; bugs and improvements found feed back into this change before it's considered complete.
