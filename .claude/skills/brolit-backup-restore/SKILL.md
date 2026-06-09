# Brolit Shell — Backup and Restore Operations Skill

## Description

Guides backup and restore operations using brolit-shell. Use this skill when the user needs to create, schedule, verify, or restore backups for projects, databases, or full server configurations.

## Supported Backup Methods

| Method | Storage Controller | Config Key |
|---|---|---|
| Borg (recommended) | `libs/borg_storage_controller.sh` | `BACKUPS.methods.borg` |
| SFTP | `libs/storage_controller.sh` | `BACKUPS.methods.sftp` |
| Local | `libs/storage_controller.sh` | `BACKUPS.methods.local` |
| Dropbox | `libs/apps/dropbox_uploader_helper.sh` | `BACKUPS.methods.dropbox` |

## What Gets Backed Up

| Component | Config Key | What's Included |
|---|---|---|
| Projects | `BACKUPS.projects` | `/var/www/<domain>/` files |
| Databases | `BACKUPS.databases` | MySQL/PostgreSQL dumps |
| Server config | `BACKUPS.server_cfg` | nginx vhosts, brolit configs, SSL certs |
| Cron configs | `BACKUPS.server_cfg` | `/etc/cron.d/` entries |

## Backup Operations

### CLI Backup Commands

```bash
# Full project backup (files + database)
./runner.sh -t backup -st project -d example.com

# Database-only backup
./runner.sh -t backup -st database -db database_name

# Server configuration backup
./runner.sh -t backup -st config

# All projects backup (used by cron)
./runner.sh -t backup -st all-projects
```

### Scheduled Backups (Cron)

Cron backup flow is in `cron/backups_tasks.sh`:
1. Generates borgmatic configs from brolit config
2. Runs borgmatic for each configured backup set
3. Sends notification with results

### Backup Compression

Configured under `BACKUPS.config.compression`:
- Types: `lbzip2`, `pigz`, `zstd`
- Retention: `keep_daily`, `keep_weekly`, `keep_monthly`

## Restore Operations

### CLI Restore Commands

```bash
# Restore project from backup
./runner.sh -t restore -st project -d example.com

# Restore database from backup
./runner.sh -t restore -st database -db database_name

# Restore server configuration
./runner.sh -t restore -st config
```

### Restore Flow

1. Select backup source (Borg archive, SFTP path, Local path, Dropbox, or URL)
2. Download/extract backup files
3. Restore project files to `/var/www/<domain>/`
4. Restore database via `database_import()`
5. Reconfigure nginx vhost
6. Reissue SSL certificate if needed
7. Restart services
8. Verify site is responding

### Docker Project Restore

For Docker-based projects, the restore flow also:
- Recreates the Docker Compose environment
- Handles port collisions via `network_next_available_port()`
- Restores `.env` and Docker volumes

## Key Files

| File | Purpose |
|---|---|
| `utils/backup_restore_manager.sh` | Menu + CLI handlers for backup/restore |
| `libs/local/backup_helper.sh` | Backup filename, compression, retention |
| `libs/local/restore_backup_helper.sh` | Restore from all sources |
| `libs/storage_controller.sh` | Storage abstraction layer |
| `libs/borg_storage_controller.sh` | Borg-specific operations |
| `cron/backups_tasks.sh` | Scheduled backup execution |
| `config/borg/borgmatic.template-*.yml` | Borgmatic config templates |

## Troubleshooting

| Issue | Solution |
|---|---|
| Borg connectivity fails | Test SSH: `ssh -p PORT user@server`, check SSH keys |
| Backup too large | Check compression config, exclude large dirs |
| Restore fails on DB import | Check `.my.cnf` credentials, verify DB doesn't exist |
| Port collision on Docker restore | Automatic via `network_next_available_port()` |
| Backup not in list | Check retention settings, verify archive exists on remote |

## Instructions for AI Assistant

1. Always verify the backup method is enabled in config before starting
2. Use `brolit_configuration_manager.sh` to read config, never parse JSON directly
3. For restore operations, always confirm the target domain/path before overwriting
4. Suggest verifying site health after restore: `curl -I https://domain.com`
5. Remind user about retention settings when cleaning old backups
