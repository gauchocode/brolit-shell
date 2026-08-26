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

**Files affected:** `libs/storage_controller.sh`, `cron/backups_tasks.sh`

---

### A2. Retention config is per-method, not shared (revised 2026-08-26 — supersedes the old "unify into one source" idea below)

**This item originally proposed (A.2, now retired) making `.brolit_conf.json`'s
single `BACKUPS.config[].retention[]` block the source of truth for *both*
`storage_delete_old_backups()` (dropbox/sftp/local) and borg, injecting it into
the borgmatic YAML at generation time. Deeper investigation (real incident,
`myspyglass.online` on `spyglass-hccx13use`, 2026-08-26) found the actual
situation is worse than "two systems that happen to read the same value" — and
that forcing them onto literally the same 3 numbers is the wrong fix, not just
an implementation detail.**

**Confirmed facts:**

1. `BACKUPS.config[].retention[].{keep_daily,keep_weekly,keep_monthly}` is read
   once into `BACKUP_RETENTION_KEEP_*` globals
   (`brolit_configuration_manager.sh:393-407`) and consumed **only** by
   `storage_delete_old_backups()` (`storage_controller.sh:612`), called from 4
   sites in `backup_helper.sh` (server-config, openresty-vm, project files,
   database backups) — all going through `storage_upload_backup`, i.e. the
   dropbox/sftp/local path. Borg never touches these globals at all.
2. Borg's retention lives entirely inside each project's
   `/etc/borgmatic.d/<project>.yml`, using borgmatic's own native GFS fields
   (`keep_daily`/`keep_weekly`/`keep_monthly`/`keep_yearly`/`keep_within` —
   same *names*, unrelated mechanism: borgmatic prunes by real archive
   timestamp with proper GFS semantics; `storage_delete_old_backups()` buckets
   by sorting a flat filename list and checking for a literal `-weekly`/
   `-monthly` substring).
3. **`generate_borg_config()` (`cron/backups_tasks.sh:123-207`) writes this
   YAML exactly once** — `if [ ! -f "${yml_file}" ]` — and never touches it
   again. Nothing in the codebase writes `keep_daily`/`keep_weekly`/
   `keep_monthly`/`keep_yearly`/`keep_within` into a borgmatic YAML,
   confirmed by grepping for those field names across
   `borg_storage_controller.sh` and `backups_tasks.sh`: zero matches. So the
   "inject from JSON at generation time" half of the old A.2 proposal was
   never implemented either — retention has *never* been connected to
   `.brolit_conf.json` for borg, not even one-way.
4. The four YAML templates don't even agree with each other on defaults:
   `docker`/`postgres` ship `keep_monthly: 6, keep_yearly: 1` with no
   `keep_within`; `default`/`mysql` ship `keep_within: 1m` *and*
   `keep_monthly: 6, keep_yearly: 1`; all four ship `keep_daily`/`keep_weekly`
   **commented out** (disabled) by default. Yet the real, live
   `myspyglass.online.yml` has `keep_daily: 2, keep_weekly: 0` uncommented —
   someone hand-edited it after generation, with no way for that intent to
   have come from `.brolit_conf.json` (nothing writes those keys there) or to
   ever get reconciled again.
5. Real-world case for *why* a single shared value is the wrong target, not
   just an unimplemented one: `myspyglass.online` backs up ~167GB (two large
   media directories via explicit `source_directories`, not symlink-following
   — Borg has no `--dereference` equivalent to tar's `-h`, so the working
   fix for symlinked content is listing the real target paths directly, which
   this project's YAML already does). That's fine for Borg on a flat-fee 10TB
   Storage Box, but is exactly why Dropbox got disabled for this project today
   — a naive `tar | lbzip2` pipeline can't stage that volume on a 75GB root
   disk. Destinations with different cost/durability/capacity profiles
   legitimately want different retention depths, not the same 3 numbers
   forced onto both a crude count-based pruner and a native GFS engine.

**Revised proposal: retention becomes a per-method config block, kept in sync
on every write, not just at first generation.**

1. **Schema**: nest retention under each method instead of one shared
   `BACKUPS.config[].retention[]`:
   ```json
   "BACKUPS": {
     "methods": [{
       "dropbox": [{ "status": "enabled", "retention": { "keep_daily": 7, "keep_weekly": 4, "keep_monthly": 6 } }],
       "borg":    [{ "status": "enabled", "retention": { "keep_daily": 7, "keep_weekly": 4, "keep_monthly": 6, "keep_yearly": 1, "keep_within": "1d" } }],
       "sftp":    [{ "retention": { "keep_daily": 7, "keep_weekly": 4, "keep_monthly": 6 } }],
       "local":   [{ "retention": { "keep_daily": 7, "keep_weekly": 4, "keep_monthly": 6 } }]
     }]
   }
   ```
   Borg's block can carry fields (`keep_yearly`, `keep_within`) the others
   don't need — matches borgmatic's actual capability instead of lowest-common-
   denominator. `BACKUPS.config[].retention[]` (old shared block) is read as a
   fallback default for methods without their own block, for migration.
2. **`storage_delete_old_backups()`** reads
   `BACKUPS.methods[].<method>[].retention` for the method it's currently
   pruning (needs the method name threaded through from its 4 call sites)
   instead of the global `BACKUP_RETENTION_KEEP_*` vars.
3. **`generate_borg_config()`** injects `BACKUPS.methods[].borg[].retention`
   into the YAML's `keep_*` fields with `yq`, same mechanism already used
   there for `constants.project`/`group`/`hostname`.
4. **New: keep the YAML in sync after generation, not just once.** Add
   `sync_borg_retention_config()`, called from the same place a config-write
   flow would call it (brolit-admin's `brolit_config_write` job, or the
   interactive config editor) — re-applies just the `keep_*` fields via `yq`
   to every existing `/etc/borgmatic.d/*.yml` without touching
   `source_directories`/`repositories`/hooks. This is the piece that actually
   closes the "write-once, drifts forever" gap; steps 1-3 alone would still
   only apply to *newly created* projects.

**Files affected:** `libs/storage_controller.sh`, `cron/backups_tasks.sh`,
`libs/borg_storage_controller.sh`, `utils/brolit_configuration_manager.sh`

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

**Cross-reference (2026-08-26):** brolit-admin is planning a storage-box
visibility/audit UI (`brolit-admin` repo,
`docs/plan/active/2026-08-storage-box-visibility.md`) that wants exactly this
data — per-repo archive count, last archive date, dedup/original/compressed
size, quota (`sftp df` on the storage box) — surfaced over SSH instead of a
terminal table. If `borg_repo_status()` emits `--json` (or a `--machine`
flag), brolit-admin's inventory command can reuse the same function instead
of re-deriving the same `borg info`/quota-check logic independently. Worth
designing this function's JSON shape with that consumer in mind, not just the
terminal table.

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

**Update (2026-08-26): the "already partially solved" read side had a real,
confirmed bug — fixed.** `_json_read_field()` (`brolit_lite.sh:34-45`) runs
`jq -r`, and `jq -r` renders a *missing* field as the 4-character string
`"null"`, not an empty string. Both `show_backup_information()` and
`show_backup_information_by_domain()` only fell back to `$HOSTNAME` when the
read was empty (`[[ -z "${backup_host}" ]]`) — since `backup_host` is unset on
the overwhelming majority of servers, that fallback never fired, and every
borg repo path silently resolved to `.../<group>/null/projects-online/...`
instead of the real hostname. Fixed in both functions (commit `f2170221`):
`[[ -z "${backup_host}" || "${backup_host}" == "null" ]]`.

Found via a live incident on `spyglass-hccx13use`: `show_backup_information`
reported borg backups as completely empty for `myspyglass.online` despite
`borgmatic` successfully writing daily archives — the read was hitting the
`null` path, which doesn't exist, while the write path (borgmatic's own YAML,
which hardcodes `hostname` correctly per-project) was fine all along. This is
likely a **fleet-wide** false-negative, not specific to this server — any
borg-enabled server without an explicit `backup_host` would show the same
"empty" borg status in brolit-admin regardless of real backup health.

**Still open — this item's original scope, now narrower:**

1. **Read `backup_host` in restore functions**
   - `restore_backup_with_borg()` should check for `backup_host` in
     `.brolit_conf.json` before falling back to `HOSTNAME` (apply the same
     `-z || == "null"` fix, not just `-z`)
2. **`generate_borg_config()`** should also check the override (currently
   only uses live `$HOSTNAME`) — same fix needed there for consistency, even
   though it's write-once today (see item A2 above on making it re-syncable).

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
| P0 | B — Automatic prune after backup | Small | High — prevents storage bloat. **Confirmed live 2026-08-26**: `myspyglass.online`'s second Storage Box has ~2 months of unpruned daily archives despite `keep_daily: 2` configured — this isn't theoretical, it's already happening |
| P0 | A2 — Per-method retention, kept in sync (not just at generation) | Medium | High — retention has *never* been connected to borg's actual YAML for any server; blocks B from being configurable per the plan below it, and is what makes brolit-admin's new "retention" column (`docs/plan/active/2026-08-backup-data-richness.md`, this repo) accurate instead of dropbox-only-but-labeled-generic |
| P1 | A — SFTP prune support | Medium | Medium — closes gap |
| P1 | C — Borg verify + auto-check before restore | Medium | Medium — data safety |
| P1 | H — Encryption support | Small | Medium — security |
| P2 | D — Repo status dashboard | Small | Low — visibility. See 2026-08-26 cross-reference: design the JSON shape for brolit-admin's storage-box UI to consume, not just a terminal table |
| P2 | F — Project rename handling | Large | Medium — edge case |
| P2 | G — backup_host in restore flow | Small | Medium — edge case. **Read-side half already fixed 2026-08-26** (`show_backup_information*`); restore-side (`restore_backup_with_borg`) and `generate_borg_config()` still need the same fix |
