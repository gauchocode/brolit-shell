# New CLI Commands for Automation

**Date:** 2026-06-09
**Criteria:** Automation (brolit-ui, scripts, cron)
**Status:** In Progress
**Issue:** BLIT-176

---

## Overview

Add 6 new CLI commands + scaffold to facilitate the future addition of commands. All base functions already exist, only routing in task_runner is needed.

## Estimate: ~25 min

---

## T0. Scaffold: Convention for new tasks

- Document the 3-step pattern in `show_help()` or comment in `tasks_handler`
- Pattern: 1) validate subtask, 2) validate params, 3) route to handler
- File: `libs/task_runner.sh`

## T1. certbot — SSL certificate management

- Subtasks: `install`, `expand`, `force-renew`, `delete`, `list`, `test-renew`
- Base functions in `libs/apps/certbot_helper.sh`:
  - `certbot_certificate_install "${domain}" "${email}"`
  - `certbot_certificate_expand "${domain}"`
  - `certbot_certificate_force_renew "${domain}"`
  - `certbot_certificate_delete "${domain}"`
  - `certbot_show_certificates_info`
  - `certbot_certificate_renew_test`
- Handler: implement `certbot_tasks_handler` in `utils/certbot_manager.sh`
- Params: `-D` domain (except `list` and `test-renew`)

## T2. database export/import — Complete documented subtasks

- Subtasks: `export_db`, `import_db`
- Base functions in `libs/apps/mysql_helper.sh`:
  - `mysql_database_export`
  - `mysql_database_import`
- Params: `-db` dbname, `-D` domain (path), `-tf` file (import)

## T3. restore — Complete stubs

- Subtasks: `from-local`, `from-storage`, `from-url`, `from-borg`
- Base functions in `libs/local/restore_backup_helper.sh`:
  - `restore_backup_from_local`
  - `restore_backup_from_storage`
  - `restore_backup_from_public_url`
  - `restore_backup_with_borg`
- Params: `-D` domain, `-tf` file/path, `-tv` backup_date

## T4. project online/offline — Change nginx status

- Subtasks: `online`, `offline`
- Base function: `nginx_server_change_status "${domain}" "${status}"`
- Call directly without going through `project_change_status` (interactive)
- Params: `-D` domain

## T5. wpcli search-replace — Fix commented case

- Uncomment and implement case in `wpcli_tasks_handler`
- Params: `-D` domain, `-tv` "old_url,new_url"

## T6. project regen-nginx — Regenerate nginx config

- Subtask: `regen-nginx`
- Non-interactive wrapper that calls low-level functions
- Params: `-D` domain, `-pt` project_type

---

## Dependencies

```
T0 (scaffold) → everything else
T2, T5 (existing fixes) → independent
T1 (certbot) → independent
T4 → T6 (both use nginx)
T3 (restore, more complex) → last
```

## Verification

1. `bash -n` on all modified files
2. Test each new subtask with valid/invalid flags
3. `./runner.sh --help` shows all new tasks
