## 1. Flag & dispatcher wiring

- [x] 1.1 Add new flags to the parser in `libs/task_runner.sh` (~line 1016 block): `--dest-host`, `--dest-user`, `--dest-port` (default `22`), `--dest-ssh-key`, `--decommission-source`, `--purge-volumes`, `--bootstrap-dest-config`, `--force`. Export accordingly (`DESTHOST`, `DESTUSER`, `DESTPORT`, `DESTSSHKEY`, `DECOMMISSION_SOURCE`, `PURGE_VOLUMES`, `BOOTSTRAP_DEST_CONFIG`, `FORCE`).
- [x] 1.2 Update `docs/flags.md` with the new `migrate` task, its `site` subtask, and the new flags, including a clear warning about `--decommission-source`/`--purge-volumes`.
- [x] 1.3 Add `migrate` to the task dispatcher in `libs/task_runner.sh` (new `case migrate)` branch, mirroring `restore)`): `validate_task_and_subtask "migrate" "${STASK}" "site"`.
- [x] 1.4 Wire `migrate site` required params: `DOMAIN`, `DESTHOST`, `DESTUSER`, `DESTSSHKEY`. `DESTPORT` defaults to `22`; `DECOMMISSION_SOURCE`/`PURGE_VOLUMES`/`BOOTSTRAP_DEST_CONFIG`/`FORCE` optional.
- [x] 1.5 Route through `execute_task_with_error_handling "migrate-${STASK}" "subtasks_migrate_handler" ...`.

## 2. Pre-flight checks

- [x] 2.1 Create `libs/local/site_migration_helper.sh` following file header/function-doc conventions in `AGENTS.md`.
- [x] 2.2 Implement `migrate_check_docker_project()`: reuse the same install-type detection `backup_docker_project()` uses; fail closed with a "Docker-only" message otherwise.
- [x] 2.3 Implement `migrate_check_ssh_connectivity()`: `ssh -o BatchMode=yes -o ConnectTimeout=10 -i "${DESTSSHKEY}" -p "${DESTPORT}" "${DESTUSER}@${DESTHOST}" true`; distinguish unreachable-host vs auth-failure where possible.
- [x] 2.4 Implement `migrate_check_dest_brolit()`: over SSH, check `runner.sh` exists at the expected remote path and `.brolit_conf.json` exists; if missing, install (clone + minimal webserver-role config) per 2.6. Also added `migrate_check_dest_docker()` (Docker/Compose presence) as a prerequisite, per spec.
- [x] 2.5 Implement `migrate_check_dest_dns_ssl_config()`: over SSH, read the destination's `.brolit_conf.json` and confirm `DNS.cloudflare[0].status`/`PACKAGES.certbot[0].status` are `enabled`. If missing and `BOOTSTRAP_DEST_CONFIG` is not set, fail closed with an actionable message. If missing and `BOOTSTRAP_DEST_CONFIG` is set, copy the `DNS.cloudflare` section from the source's own `.brolit_conf.json` to the destination and log exactly what was copied.
- [x] 2.6 Implement `migrate_bootstrap_dest_brolit()`: clone brolit-shell on the destination via SSH, generate `.brolit_conf.json` from the template with the webserver role enabled (minimal, non-interactive) — marked in code comments as not yet validated against a real fresh server.
- [x] 2.7 Implement `migrate_resolve_dest_path()` and `migrate_check_dest_path_collision()`: default destination path mirrors `PROJECTS_PATH/<domain>`; fail unless `FORCE` is set if it already exists.
- [x] 2.8 (Added, not in original plan) Implement `migrate_check_dest_backup_local()`: verify `BACKUPS.methods.local` is enabled on the destination (required — see corrected section 3 below) and resolve the destination's server name + local backup path.

## 3. Capture, transfer, remote restore trigger

**Correction found during implementation**: `restore -st from-local` only restores files (no database, no vhost/DNS/SSL) — see `restore_backup_from_local_cli()` vs `restore_backup_from_storage_cli()` in `libs/local/restore_backup_helper.sh`. The full pipeline (files+DB+port-collision+vhost+DNS+SSL) lives behind `restore -st from-storage`, which reads from the destination's own configured storage. `migrate` therefore requires `BACKUPS.methods.local` enabled on **both** source and destination, and transfers the artifact directly into the destination's local-storage path structure (namespaced under the destination's own server name) rather than an arbitrary tmp path. `design.md` and `specs/site-migration/spec.md` were updated to match. This is why `migrate_capture_source()` also now requires `BACKUP_LOCAL_STATUS` on the source, and `subtasks_migrate_handler`/`migrate_site()` call `migrate_check_dest_backup_local()` before capture.

- [x] 3.1 Implement `migrate_capture_source()`: call `backup_docker_project()` unmodified; requires `BACKUP_LOCAL_STATUS=enabled` on source so the resulting artifact lands at a known local path.
- [x] 3.2 Implement `migrate_transfer_artifact()`: `rsync` over SSH, pushing the source's local-storage artifact tree (`${BACKUP_LOCAL_CONFIG_BACKUP_PATH}/${SERVER_NAME}/projects-online/{site,database}/...`) into the equivalent path on the destination, namespaced under the destination's own server name; treats non-zero exit as fatal, leaving the source untouched.
- [x] 3.3 Implement `migrate_trigger_remote_restore()`: `ssh ... "cd <dest_brolit_path> && ./runner.sh -t restore -st from-storage -D '${DOMAIN}'"`; captures and propagates the remote exit code. Does not reimplement any restore-internal logic (port collision, vhost, DNS, SSL) — the destination's own `restore` handles all of it.

## 4. Verification

- [x] 4.1 Implement `migrate_verify_destination()`: resolve the destination's public IP (via `--dest-host` if already an IP, or `ssh ... 'curl -s https://api.ipify.org'`), then `curl --resolve "${DOMAIN}:443:${dest_ip}" "https://${DOMAIN}/"` (and an HTTP fallback) to confirm the site responds without depending on DNS propagation timing.
- [x] 4.2 Report verification pass/fail clearly; this result gates the decommission step in section 5 (`migrate_site()` passes both `restore_result` and `verification_result` into `migrate_decommission_source()`, which hard-guards on both).

## 5. Gated source decommissioning

**Simplification found during implementation**: `libs/local/project_helper.sh:2558` (`project_delete()`) already stops the Docker stack, takes a final backup, removes files/nginx vhost/certificates/project config, and — critically — only deletes the Cloudflare DNS record if it still points at this server's own `SERVER_IP` (it won't, once the destination's restore has repointed it). So `migrate_decommission_source()` reuses `project_delete()` directly instead of reimplementing each removal step.

- [x] 5.1 Implement `migrate_decommission_source()`, only ever invoked when `DECOMMISSION_SOURCE` is set AND remote restore exited 0 AND verification passed: calls `project_delete("${domain}", "true")`, which internally stops the Docker stack (`docker compose stop`) before removing files.
- [x] 5.2 Nginx vhost removal — handled by `project_delete()` (`nginx_server_delete`).
- [x] 5.3 SSL certificate removal — handled by `project_delete()` (`certbot_certificate_delete`).
- [x] 5.4 Project directory removal — handled by `project_delete()` (`project_delete_files`).
- [x] 5.5 De-registration from `.brolit_conf.json` — handled by `project_delete()` (removes `${BROLIT_CONFIG_PATH}/${domain}_conf.json`).
- [x] 5.6 Added an explicit log line confirming decommission completed and that only the backup artifact remains.
- [x] 5.7 Added a hard guard at the top of `migrate_decommission_source()` that refuses to run (and never calls `project_delete()`) if passed a non-zero restore result or failed verification result, independent of the caller's own gating.
- [x] 5.8 (New) `--purge-volumes`: capture `docker compose config --volumes` before calling `project_delete()` (since it removes the compose file), then `docker volume rm` those names after. Implemented but not yet exercised against a real Docker project with named volumes — validate in section 8.

## 6. CLI + interactive handlers

- [x] 6.1 Implement `subtasks_migrate_handler()` (new `utils/site_migration_manager.sh`) with a `site` case calling `migrate_site()`, which internally runs the helpers from sections 2–5 in strict order, short-circuiting on the first failed check.
- [x] 6.2 Add a whiptail interactive menu entry (`site_migration_manager_menu()`) prompting for domain, destination SSH details, and decommission options, with a distinct type-the-domain-to-confirm step specifically for `--decommission-source`, and a separate yes/no for `--purge-volumes`. Wired into the main menu as option 12 ("MIGRATE SITE (BETA)"), hidden on Proxmox nodes.
- [x] 6.3 Log each migration attempt and each decommission action via `log_event`/`log_section`; never logs SSH key contents or Cloudflare credentials, only paths/hostnames/which config section was copied.

## 7. Tests

- [x] 7.1 Create `tests/test_site_migration.sh` following the existing custom bash test-suite pattern.
- [x] 7.2 Unit-test `migrate_check_docker_project()`: non-Docker fails, Docker project passes, unknown domain fails.
- [ ] 7.3 Unit-test `migrate_check_dest_dns_ssl_config()`: not yet covered (requires mocking multi-call SSH sequences; deferred — flagged as a gap for section 8 real-world testing to surface instead).
- [x] 7.4 Unit-test the decommission gate: `migrate_decommission_source()` refuses to run (never calls `project_delete()`) given a non-zero restore result or failed verification, independent of `DECOMMISSION_SOURCE`.
- [ ] 7.5 Unit-test `--purge-volumes` in isolation: not yet covered — deferred to section 8 real-world testing (needs a real Docker Compose project with named volumes).
- [x] 7.6 Run `bash -n` on all new/modified files (`libs/task_runner.sh`, `libs/commons.sh`, `libs/local/site_migration_helper.sh`, `utils/site_migration_manager.sh`, `tests/test_site_migration.sh`, `tests/tests_suite.sh`) — all pass.
- [x] 7.7 Register new test file in `tests/tests_suite.sh` (auto-sourced via glob; also added menu option 14 and wired into the "RUN ALL TESTS" path).

## 8. Real-world validation (tukiverse-apps03 → epica-apps02)

**Findings from initial reconnaissance (read-only, both servers):** both `tukiverse-apps03` and `epica-apps02` have brolit-shell at `/root/brolit-shell` with a `.brolit_conf.json` present, and `epica-apps02` has Docker + Compose and `DNS.cloudflare`/`PACKAGES.certbot` enabled — the destination pre-flight requirements are satisfied. `tukiverse-apps03` has 13 Dockerized projects and 1 host project (`apps`) under `/var/www`. **Neither server has `BACKUPS.methods.local` enabled** — both only have Dropbox enabled (same shared Dropbox app/account on both). This blocked the `local` transport as originally designed and surfaced two further pre-existing bugs, fixed as part of this change (see design.md): `storage_download_backup()` had no Local branch at all, and `storage_list_dir()`'s independent `if` blocks (vs `elif`) meant multiple enabled methods silently clobbered each other. Added `--transport local|dropbox` (default `local`) plus `-sm|--storage-method` on `restore -st from-storage` so migrate can force which method the destination's restore uses. `--transport dropbox` is the path that will actually work against these two servers today without any config changes; `--transport local` requires enabling `BACKUPS.methods.local` on both first (not yet done — pending decision on whether to change production backup config for this).

- [x] 8.1 Confirm which sites on `tukiverse-apps03` are Dockerized (in scope) vs host/classic (out of scope for v1). Result: 13 Dockerized (`aiagents.epicahub.com`, `deploy-agent.epicahub.com`, `ee-agent.epicahub.com`, `lp-agent.epicahub.com`, `mc-agent.epicahub.com`, `metabase.broobe.com`, `minio-agent.epicahub.com`, `ns-agent.epicahub.com`, `operator-agent.epicahub.com`, `orchestrator-agent.epicahub.com`, `tbots-ui.epicahub.com`, `tns-agent.epicahub.com`, `ts-agent.epicahub.com`), 1 host (`apps`).
- [ ] 8.2 Dry-run `migrate site` (no `--decommission-source`) against a disposable/non-production Dockerized project on both VPS first.
- [ ] 8.3 Validate CLI mode end-to-end for one real Dockerized production domain WITHOUT `--decommission-source`: capture, transfer, remote restore, verify vhost+DNS+SSL are correct on `epica-apps02`, manually confirm the site before going further.
- [ ] 8.4 Deliberately pre-occupy the target port on `epica-apps02` before a migration run to exercise the port-collision path already present in the destination's own restore logic.
- [ ] 8.5 Only after 8.3 is manually confirmed correct, run `migrate site --decommission-source` (without `--purge-volumes`) against a real (ideally low-stakes) production domain and confirm `tukiverse-apps03` ends with only the backup artifact remaining.
- [ ] 8.6 Separately validate `--purge-volumes` against a disposable project, not a real production site, given it's irreversible data loss.
- [ ] 8.7 Validate interactive whiptail mode end-to-end for at least one domain.
- [ ] 8.8 Exercise failure paths: non-Docker domain, unreachable SSH host, wrong SSH key, destination missing Docker, destination missing Cloudflare/certbot config (with and without `--bootstrap-dest-config`), remote restore failure (confirm decommission never triggers) — confirm each fails closed with a clear message.
- [ ] 8.9 Log bugs found during 8.1–8.8 as follow-up tasks in this change (or a fast-follow change) before considering the feature production-ready.
- [ ] 8.10 Explicitly note whether the destination bootstrap-install-brolit path (section 2.6) ever gets validated against a real fresh server, or remains a documented-but-unvalidated fallback.

## 9. Documentation

- [x] 9.1 Update `docs/CHANGELOG.md` with the new `migrate` task.
- [x] 9.2 Document the `migrate site` command, its Docker-only scope, required flags, the decommission gating/two-phase recommended usage, and the `--purge-volumes` warning in `.claude/skills/brolit-backup-restore/SKILL.md`.
- [x] 9.3 Document the recommended scoped Cloudflare API token practice for `--bootstrap-dest-config` in the same doc.
