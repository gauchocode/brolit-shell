# Brolit Shell — Backup and Restore Operations Skill

## Description

Guides backup and restore operations using brolit-shell. Use this skill when the user needs to create, schedule, verify, or restore backups for projects, databases, or full server configurations.

## Pre-Flight Checklist (CRITICAL - Run Before ANY Restore)

**ALWAYS verify config before attempting restore. This prevents failed restores.**

```bash
# 1. Check if project exists in config
PROJECT_EXISTS=$(jq -r --arg d "DOMAIN" '.projects[] | select(.project_domain == $d)' /root/.brolit_conf.json 2>/dev/null)
[[ -z "${PROJECT_EXISTS}" ]] && echo "ERROR: Project not in config" && exit 1

# 2. Get project type and containers
PROJECT_TYPE=$(echo "${PROJECT_EXISTS}" | jq -r '.project_type')
CONTAINERS=$(echo "${PROJECT_EXISTS}" | jq -r '.project_container.docker_compose_action != "skip"' 2>/dev/null)
WEBROOT=$(echo "${PROJECT_EXISTS}" | jq -r '.project_config.webroot' 2>/dev/null)

# 3. Check backup methods enabled
BACKUP_METHODS=$(jq -r '.BACKUPS.methods[] | keys[]' /root/.brolit_conf.json 2>/dev/null)
echo "Available methods: ${BACKUP_METHODS}"

# 4. Check if backup file exists
ls -la /root/backups/DOMAIN/

# 5. Check for docker-compose
find "${WEBROOT}" -name "docker-compose*.yml" 2>/dev/null | head -5
```

## Quick Reference

### Backup Commands (CLI)

```bash
# Full project backup (files + database)
./runner.sh -t backup -st project -D example.com

# All databases (MySQL + PostgreSQL, host + Docker)
./runner.sh -t backup -st databases

# Server configuration (nginx, brolit configs, SSL certs)
./runner.sh -t backup -st server-config

# All project files
./runner.sh -t backup -st files

# Everything with report + notification
./runner.sh -t backup -st full-report

# List available backups (JSON)
./runner.sh -t backup -st list -D example.com

# List ALL backups (all storage methods unified)
./runner.sh -t backup -st list-all -D example.com

# Search backups by date range
./runner.sh -t backup -st search -D example.com -tv "2026-06-01,2026-06-15"
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
./runner.sh -t restore -st from-borg -D example.com
./runner.sh -t restore -st from-borg -D example.com -tv 2026-06-09

# Download backup without restoring
./runner.sh -t restore -st download -D example.com
./runner.sh -t restore -st download -D example.com -tf /path/to/output
```

## Supported Backup Methods

| Method | Config Key | Status |
|---|---|---|
| Borg (recommended) | `BACKUPS.methods.borg` | Production ready |
| SFTP | `BACKUPS.methods.sftp` | Production ready |
| Local | `BACKUPS.methods.local` | Production ready |
| Dropbox | `BACKUPS.methods.dropbox` | Production ready |

## What Gets Backed Up

| Component | Config Key | What's Included |
|---|---|---|
| Projects | `BACKUPS.projects` | `/var/www/<domain>/` files |
| Databases | `BACKUPS.databases` | MySQL/PostgreSQL dumps |
| Server config | `BACKUPS.server_cfg` | nginx vhosts, brolit configs, SSL certs |
| Docker volumes | `BACKUPS.projects` | Docker volume data |

## Pre-Execution Checklist

1. [ ] Verify brolit config exists: `cat ~/.brolit_conf.json | jq .BACKUPS`
2. [ ] Check backup method is enabled (borg, sftp, local, dropbox)
3. [ ] Verify disk space: `df -h /var/www`
4. [ ] For restore: confirm target domain exists or will be created

## Restore Flow

1. Select backup source (Borg, SFTP, Local, Dropbox, or URL)
2. Download/extract backup files
3. Restore project files to `/var/www/<domain>/`
4. Restore database via `database_import()`
5. Reconfigure nginx vhost
6. Reissue SSL certificate if needed
7. Restart services
8. Verify site is responding

## Post-Execution Verification

```bash
# Check site is responding
curl -I https://example.com

# Check nginx config
nginx -t

# Check database exists
./runner.sh -t database -st list_db

# Check backup files
ls -la /path/to/backups/
```

## Key Files

| File | Purpose |
|---|---|
| `utils/backup_restore_manager.sh` | Menu + CLI handlers for backup/restore |
| `libs/local/backup_helper.sh` | Backup filename, compression, retention |
| `libs/local/restore_backup_helper.sh` | Restore from all sources (interactive + CLI) |
| `libs/storage_controller.sh` | Storage abstraction layer |
| `libs/borg_storage_controller.sh` | Borg-specific operations |
| `cron/backups_tasks.sh` | Scheduled backup execution |

## Troubleshooting

| Issue | Solution |
|---|---|
| Borg connectivity fails | Test SSH: `ssh -p PORT user@server`, check SSH keys |
| Backup too large | Check compression config, exclude large dirs |
| Restore fails on DB import | Check `.my.cnf` credentials, verify DB doesn't exist |
| Port collision on Docker restore | Automatic via `network_next_available_port()` |
| Backup not in list | Check retention settings, verify archive exists on remote |
| "Missing required parameters" | Check `--help` for required flags |
| "Permission denied" | Script must run as root |

## Instructions for AI Assistant

1. Always verify the backup method is enabled in config before starting
2. Use `brolit_configuration_manager.sh` to read config, never parse JSON directly
3. For restore operations, always confirm the target domain/path before overwriting
4. Use CLI commands (not interactive menus) when executing programmatically
5. Suggest verifying site health after restore: `curl -I https://domain.com`
6. Remind user about retention settings when cleaning old backups
7. Capture command output and exit codes for error reporting
