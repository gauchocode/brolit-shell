# AI Execution Capability Plan

## Context

When an AI assistant (Claude, GPT, etc.) is asked to execute brolit operations like backup or restore, it fails because:

1. **Restore functions depend on whiptail** — 80+ interactive prompts in `restore_backup_helper.sh`
2. **Skills have inaccurate documentation** — CLI commands in skills don't match actual implementation
3. **No non-interactive restore path** — CLI `restore` subtasks call functions that require terminal interaction

**Goal**: Make brolit fully executable by AI assistants via CLI, while preserving interactive mode for human users.

---

## Phase 1: Non-Interactive Restore Functions

### Problem

Current restore flow:
```
./runner.sh -t restore -st from-storage -D example.com
  → subtasks_restore_handler()
    → restore_backup_from_storage()
      → whiptail menus for server selection, backup selection, confirmation
```

### Solution

Create dual-mode functions that detect terminal availability:

```bash
# Detect if running interactively
if [[ -t 0 ]] && [[ -t 1 ]]; then
  # Interactive mode - use whiptail
  restore_backup_from_storage "$@"
else
  # Non-interactive mode - require all params via CLI
  restore_backup_from_storage_cli "$@"
fi
```

### Functions to Create

| Function | File | Parameters |
|----------|------|------------|
| `restore_backup_from_storage_cli()` | `restore_backup_helper.sh` | `$domain`, `$backup_date` |
| `restore_backup_from_local_cli()` | `restore_backup_helper.sh` | `$domain`, `$file_path` |
| `restore_backup_from_url_cli()` | `restore_backup_helper.sh` | `$domain`, `$url` |
| `restore_backup_with_borg_cli()` | `restore_backup_helper.sh` | `$domain`, `$backup_date` |

### Implementation Details

#### `restore_backup_from_storage_cli()`

```bash
function restore_backup_from_storage_cli() {
  local domain="${1}"
  local backup_date="${2}"
  
  # Validate required params
  if [[ -z "${domain}" ]]; then
    log_event "error" "Domain is required for non-interactive restore" "true"
    return 1
  fi
  
  # Get project install type
  local install_type
  install_type="$(project_get_install_type "${PROJECTS_PATH}/${domain}")"
  
  # List available backups for domain
  local backup_list
  backup_list="$(storage_list_backups "${domain}")"
  
  # If backup_date provided, find matching backup
  if [[ -n "${backup_date}" ]]; then
    local chosen_backup
    chosen_backup="$(echo "${backup_list}" | grep "${backup_date}" | head -1)"
    
    if [[ -z "${chosen_backup}" ]]; then
      log_event "error" "No backup found for date: ${backup_date}" "true"
      return 1
    fi
  else
    # Use latest backup
    chosen_backup="$(echo "${backup_list}" | head -1)"
  fi
  
  # Execute restore
  restore_project_backup "${chosen_backup}" "ok" "" "${domain}" ""
}
```

#### `restore_backup_from_local_cli()`

```bash
function restore_backup_from_local_cli() {
  local domain="${1}"
  local file_path="${2}"
  
  # Validate
  if [[ -z "${domain}" ]]; then
    log_event "error" "Domain is required" "true"
    return 1
  fi
  
  if [[ -z "${file_path}" ]]; then
    log_event "error" "File path is required (-tf)" "true"
    return 1
  fi
  
  if [[ ! -f "${file_path}" ]]; then
    log_event "error" "Backup file not found: ${file_path}" "true"
    return 1
  fi
  
  # Execute restore
  restore_project_backup "${file_path}" "ok" "local" "${domain}" ""
}
```

### Files to Modify

| File | Changes |
|------|---------|
| `libs/local/restore_backup_helper.sh` | Add `_cli` versions of restore functions |
| `utils/backup_restore_manager.sh` | Update `subtasks_restore_handler()` to detect mode |
| `libs/task_runner.sh` | Add parameter validation for restore subtasks |

---

## Phase 2: Enhanced Skills

### Skill: `brolit-backup-restore/SKILL.md`

Rewrite with accurate CLI commands:

```markdown
# Brolit Shell — Backup and Restore Operations Skill

## Quick Reference

### Backup Commands (CLI)
```bash
# Full project backup (files + database)
./runner.sh -t backup -st project -D example.com

# All databases
./runner.sh -t backup -st databases

# Server config
./runner.sh -t backup -st server-config

# Everything with report
./runner.sh -t backup -st full-report
```

### Restore Commands (CLI)
```bash
# From storage (latest backup)
./runner.sh -t restore -st from-storage -D example.com

# From storage (specific date)
./runner.sh -t restore -st from-storage -D example.com -tv 2026-06-09

# From local file
./runner.sh -t restore -st from-local -D example.com -tf /path/to/backup.tar.gz

# From URL
./runner.sh -t restore -st from-url -D example.com -tf https://example.com/backup.tar.gz

# From Borg
./runner.sh -t restore -st from-borg -D example.com -tv 2026-06-09
```

## Pre-Execution Checklist

1. [ ] Verify brolit config exists: `cat ~/.brolit_conf.json | jq .BACKUPS`
2. [ ] Check backup method is enabled (borg, sftp, local, dropbox)
3. [ ] Verify disk space: `df -h /var/www`
4. [ ] For restore: confirm target domain exists or will be created

## Post-Execution Verification

```bash
# Check site is responding
curl -I https://example.com

# Check nginx config
nginx -t

# Check database
./runner.sh -t database -st list_db
```
```

### Skill: `brolit-ai-execution/SKILL.md` (NEW)

Dedicated skill for AI execution:

```markdown
# Brolit Shell — AI Execution Skill

## Purpose

Guide AI assistants through brolit operations without interactive prompts.

## Workflow

### Step 1: Understand the Request

Map user request to brolit task:
- "backup site X" → `./runner.sh -t backup -st project -D X`
- "restore site X" → `./runner.sh -t restore -st from-storage -D X`
- "list databases" → `./runner.sh -t database -st list_db`
- "check server" → `./runner.sh -t server-status`

### Step 2: Validate Prerequisites

```bash
# Check brolit is installed
ls -la /usr/local/bin/brolit

# Check running as root
whoami

# Check config exists
cat ~/.brolit_conf.json | jq .SERVER_NAME
```

### Step 3: Execute with Error Handling

```bash
# Always capture output
output=$(./runner.sh -t backup -st project -D example.com 2>&1)
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
  echo "Error: $output"
  # Suggest fix based on error
fi
```

### Step 4: Verify Result

```bash
# For backup: check backup location
ls -la /path/to/backups/

# For restore: check site
curl -I https://example.com
```

## Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| "Missing required parameters" | Missing `-D` flag | Add `-D domain.com` |
| "Invalid subtask" | Wrong `-st` value | Check valid subtasks with `--help` |
| "Permission denied" | Not running as root | Run with `sudo` |
| "Config not found" | Missing `~/.brolit_conf.json` | Run server setup first |
```

---

## Phase 3: Parameter Validation

### Update `task_runner.sh`

Add validation for restore parameters:

```bash
case "${STASK}" in
  from-local)
    validate_required_params "restore-from-local" "DOMAIN" "FILE"
    ;;
  from-storage)
    validate_required_params "restore-from-storage" "DOMAIN"
    ;;
  from-url)
    validate_required_params "restore-from-url" "DOMAIN" "FILE"
    ;;
  from-borg)
    validate_required_params "restore-from-borg" "DOMAIN"
    ;;
esac
```

---

## Implementation Order

1. **Phase 1**: Create non-interactive restore functions
   - Add `_cli` functions to `restore_backup_helper.sh`
   - Update `subtasks_restore_handler()` for dual mode
   - Add parameter validation to `task_runner.sh`

2. **Phase 2**: Update skills
   - Rewrite `brolit-backup-restore/SKILL.md`
   - Create `brolit-ai-execution/SKILL.md`

3. **Phase 3**: Testing
   - `bash -n` syntax check on all modified files
   - Manual test: backup with CLI
   - Manual test: restore with CLI (non-interactive)

---

## Files Affected

| File | Changes |
|------|---------|
| `libs/local/restore_backup_helper.sh` | Add `_cli` functions, dual-mode detection |
| `utils/backup_restore_manager.sh` | Update `subtasks_restore_handler()` |
| `libs/task_runner.sh` | Add restore parameter validation |
| `.claude/skills/brolit-backup-restore/SKILL.md` | Rewrite with accurate commands |
| `.claude/skills/brolit-cli-commands/SKILL.md` | Add restore examples |
| `.claude/skills/brolit-ai-execution/SKILL.md` | **New** - AI execution guide |

---

## Success Criteria

1. `./runner.sh -t restore -st from-storage -D example.com` works without whiptail when no TTY
2. `./runner.sh -t restore -st from-local -D example.com -tf /path/to/backup.tar.gz` works non-interactively
3. AI assistant can execute backup and restore by following skill instructions
4. Interactive mode still works when terminal is available
