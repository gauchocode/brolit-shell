# Borg & Storage Management Improvements

## Context

The current backup system supports four storage backends (borg, dropbox, sftp, local)
but prune/delete operations, integrity checks, and the initial setup experience have
significant gaps. Borg is the primary backup method for this server, with dual remote
repositories on Hetzner Storage Boxes.

## Design Decision

All credentials (user, server, port, API keys, passwords) stay in
`/root/.brolit_conf.json`. No separate secrets file — the config file must have
permissions **600** after installation. This keeps management simple and is
consistent with how the rest of the system works.

## Problems Identified & Improvements

### A. Make PRUNE work for ALL storage types

**Problem:** `storage_delete_backup()` only handles dropbox and local. SFTP has no
delete/upload/download implementation at all. The retention settings in
`.brolit_conf.json` (`keep_daily`/`keep_weekly`/`keep_monthly`) are used by
`storage_delete_old_backups()` but it cannot prune SFTP backups because
`storage_list_dir()` and `storage_delete_backup()` lack SFTP code paths.

**Proposed changes:**

1. **Implement SFTP list + delete in `storage_controller.sh`**
   - Add `sftp_list_dir()` using `ssh + ls` or `sftp` batch commands
   - Add `sftp_delete_file()` using `ssh rm` or `sftp rm`
   - Wire them into `storage_list_dir()` and `storage_delete_backup()`

2. **Unify retention config source**
   - `borgmatic` templates currently hardcode retention (`keep_monthly: 6`,
     `keep_yearly: 1`). These should be read from `.brolit_conf.json`
     `BACKUPS.config[].retention[]` instead, so there's a single source of truth.
   - During `generate_borg_config()`, inject retention values from
     `.brolit_conf.json` into the YAML with `yq`.

**Files affected:** `libs/storage_controller.sh`, `cron/backups_tasks.sh`,
`libs/borg_storage_controller.sh`

---

### B. Automatic prune-on-backup for borg

**Problem:** `borg_prune_archives()` is only accessible via the interactive
BACKUP TOOLS menu. The cron-driven backup flow in `backups_tasks.sh` never calls
prune automatically. Old borg archives accumulate until someone remembers to run
the menu option.

**Proposed changes:**

1. **Add `borg_prune_all_repos()` — a non-interactive version**
   - Iterates over all configs in `/etc/borgmatic.d/` and runs
     `borgmatic prune --config <file>` without any whiptail prompts
   - Called automatically after `backup_all_files_with_borg()` completes

2. **Make it configurable**
   - Add a `prune_after_backup` boolean field in
     `.brolit_conf.json` → `BACKUPS.methods[].borg[].prune_after_backup`
   - Default: `true`. When enabled, prune runs after each backup cycle.

**Files affected:** `libs/borg_storage_controller.sh`, `cron/backups_tasks.sh`,
`libs/local/backup_helper.sh`, `config/brolit/brolit_conf.json`

---

### C. Borg integrity check automation

**Problem:** The current system has `borgmatic check` in the YAML templates
(archives check + repository check every 2 weeks), but there is no interactive
option to run integrity checks on demand for borg. There is a "VERIFY BACKUP
INTEGRITY" menu option (06) but it only checks dropbox.

**Proposed changes:**

1. **Add `borg_verify_integrity()` — interactive + CLI**
   - Lists available repos from `/etc/borgmatic.d/`
   - User selects one or all
   - Runs `borgmatic check --config <file>` or `borg check` directly with
     detailed output
   - Reports: last check date, any corrupted archives, repo health summary

2. **Wire it into `menu_backup_tools()`**
   - Add option 07 "VERIFY BORG INTEGRITY"
   - Rename existing 06 to "VERIFY DROPBOX INTEGRITY"

3. **Auto-check before restore**
   - Already partially done in `restore_project_with_borg()` (uses `borg check`
     before restore), but errors are not surfaced to a notification. Add
     `send_notification` on check failure before restore starts.

**Files affected:** `libs/borg_storage_controller.sh`, `utils/it_utils_manager.sh`

---

### D. Borg repo status dashboard

**Problem:** There is no way to quickly see the health, size, and last backup
date of all borg repositories from a single command or menu option.

**Proposed changes:**

1. **Add `borg_repo_status()`**
   - For each config in `/etc/borgmatic.d/`, runs `borg info --json`
   - Collects: last archive date, number of archives, original size, dedup size,
     compressed size, total unique chunks
   - Outputs a formatted table in the terminal

2. **Wire into menu**
   - Add option 08 in BACKUP TOOLS: "BORG REPO STATUS"

**Files affected:** `libs/borg_storage_controller.sh`, `utils/it_utils_manager.sh`

---

### E. UI for initial borg credential setup

**Problem:** Currently, setting up borg on a new server requires manually editing
`/root/.brolit_conf.json`. There is no whiptail menu to input:
- Storage box user(s), server(s), port(s)
- Group name
- Enable/disable borg

This is a barrier for new users and error-prone (typos, wrong port, etc.).

**Proposed changes:**

1. **Add `_brolit_configuration_write_backup_borg()` in
   `brolit_configuration_manager.sh`**
   - Whiptail form to input: status (radiolist), group (text), and for each
     server: user, server, port
   - Support adding multiple storage boxes (dynamically with a loop)
   - Validates: no empty fields, port is numeric, server is not empty
   - Writes to `.brolit_conf.json` using `jq`

2. **Expose via menu**
   - Add to `utils/brolit_configuration_manager.sh` main menu or to
     `utils/it_utils_manager.sh` backup tools section
   - Also add an `ssh-keygen` helper that prints the public key and instructs
     the user to add it to the Hetzner Storage Box web UI

3. **Post-setup workflow**
   - After credentials are saved, ask: "Generate borgmatic templates now?"
   - If yes, calls `generate_borg_config()` for all existing projects
   - Optionally runs `check_borg_server_connectivity()` to verify

**Files affected:** `utils/brolit_configuration_manager.sh`,
`utils/it_utils_manager.sh`

---

### F. Project rename handling for borg backups

**Problem:** When a project domain is renamed, the borg repository path on the
storage box still uses the old domain name. New backups go to a new path, and
old archives become orphans.

**Proposed changes:**

1. **Add `borg_rename_project_repo()` in `borg_storage_controller.sh`**
   - Given old and new domain names:
     a. Connects to each configured storage box via SSH
     b. Creates new repo directory on the box
     c. Copies archives from old repo to new repo using `borg copy`
        (source: old repo path, dest: new repo path)
     d. Verifies the new repo with `borg check`
     e. Regenerates the borgmatic config for the new domain
     f. Offers to delete the old repo (or marks it for manual cleanup)

2. **Integration with project rename flow**
   - When a project is renamed via `project_helper.sh`, call
     `borg_rename_project_repo()` automatically if borg is enabled

**Files affected:** `libs/borg_storage_controller.sh`,
`libs/local/project_helper.sh`

---

### G. Backup host discovery for renamed servers

**Problem:** Already partially solved with the `backup_host` override field
(`brolit_lite.sh:2415`). However, the restore flow does not use this override
— it relies on `SERVER_NAME` / `HOSTNAME` and can fail if the server hostname
changed.

**Proposed changes:**

1. **Read `backup_host` in restore functions**
   - `restore_backup_with_borg()` should check for `backup_host` in
     `.brolit_conf.json` before falling back to `HOSTNAME`
   - Same for `generate_borg_config()` — it already reads hostname from the
     system, but should check for an override

**Files affected:** `libs/borg_storage_controller.sh`,
`libs/local/restore_backup_helper.sh`, `cron/backups_tasks.sh`

---

### H. Borg encryption support

**Problem:** `initialize_repository()` always uses `--encryption=none`. This means
backup data on the storage box is stored in plaintext. While this simplifies
automation, it is a security concern.

**Proposed changes:**

1. **Add `encryption` field to `.brolit_conf.json`**
   - `BACKUPS.methods[].borg[].encryption` — options: `none` (default),
     `repokey-blake2`, `keyfile-blake2`
   - `BACKUPS.methods[].borg[].passphrase` — optional, stored in
     `BORG_PASSPHRASE` env var at runtime

2. **Pass encryption setting to `borgmatic init`**
   - During `initialize_repository()`, use the configured encryption mode
   - Store passphrase in `/root/.config/borg/passphrase` or env file

3. **Template updates**
   - Add `encryption_passphrase` to the YAML templates (borgmatic supports
     `encryption_passphrase` in config)

**Files affected:** `libs/borg_storage_controller.sh`, `config/borg/*.yml`,
`config/brolit/brolit_conf.json`, `cron/backups_tasks.sh`

---

## Implementation Order

| Priority | Feature | Effort | Impact |
|----------|---------|--------|--------|
| P0 | E — UI for borg credential setup | Medium | High — unblocks new server setup |
| P0 | B — Automatic prune after backup | Small | High — prevents storage bloat |
| P1 | A — SFTP prune support | Medium | Medium — closes gap |
| P1 | C — Borg verify + auto-check before restore | Medium | Medium — data safety |
| P1 | H — Encryption support | Small | Medium — security |
| P2 | D — Repo status dashboard | Small | Low — visibility |
| P2 | F — Project rename handling | Large | Medium — edge case |
| P2 | G — backup_host in restore flow | Small | Medium — edge case |
