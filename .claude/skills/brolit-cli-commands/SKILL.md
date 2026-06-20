# Brolit Shell — CLI Commands Skill

## Description

Reference for all brolit CLI commands (non-interactive mode). Use this skill when the user needs to run brolit operations via command line, cron jobs, scripts, or from another tool (brolit-ui, n8n, AI assistants, etc.).

## Invocation

```bash
brolit [TASK] [SUB-TASK]... [OPTIONS]...
```

The `brolit` command is a symlink at `/usr/local/bin/brolit` → `/root/brolit-shell/runner.sh`. It works from any directory.

## Tasks Reference

### backup

Create backups of projects, databases, or full server.

```bash
brolit -t backup -st all                          # Backup all server configs + project files
brolit -t backup -st files                        # Backup all project files
brolit -t backup -st databases                    # Backup all databases (MySQL + PostgreSQL, host + Docker)
brolit -t backup -st server-config                # Backup nginx configs, brolit configs, SSL certs
brolit -t backup -st project -D example.com       # Backup single project (files + database)
brolit -t backup -st full-report                  # Full backup of everything + notification
```

### restore

Restore a project from a backup source. Supports both interactive (whiptail) and non-interactive (CLI) modes.

```bash
# From storage (latest backup)
brolit -t restore -st from-storage -D example.com

# From storage (specific date)
brolit -t restore -st from-storage -D example.com -tv 2026-06-09

# From local file
brolit -t restore -st from-local -D example.com -tf /path/to/backup.tar.gz

# From URL
brolit -t restore -st from-url -D example.com -tf https://example.com/backup.tar.gz

# From Borg (latest)
brolit -t restore -st from-borg -D example.com

# From Borg (specific date)
brolit -t restore -st from-borg -D example.com -tv 2026-06-09

# Download backup without restoring
brolit -t restore -st download -D example.com
brolit -t restore -st download -D example.com -tv 2026-06-09
brolit -t restore -st download -D example.com -tf /path/to/output

# List available backups (JSON output)
brolit -t restore -st list -D example.com

# List ALL backups across all storage methods (Dropbox, Borg, Local)
brolit -t restore -st list-all -D example.com

# Search backups by date range (format: YYYY-MM-DD,YYYY-MM-DD)
brolit -t restore -st search -D example.com -tv "2026-06-01,2026-06-15"
```

**Required parameters by subtask:**
| Subtask | Required | Optional |
|---------|----------|----------|
| `from-storage` | `-D` | `-tv` (date) |
| `from-local` | `-D`, `-tf` | — |
| `from-url` | `-D`, `-tf` | — |
| `from-borg` | `-D` | `-tv` (date) |
| `download` | `-D` | `-tv` (date), `-tf` (output dir) |
| `list` | `-D` | — |
| `list-all` | `-D` | — |
| `search` | `-D`, `-tv` (start,end) | — |

### project

Manage project state and nginx configuration.

```bash
brolit -t project -st online -D example.com       # Enable site (nginx)
brolit -t project -st offline -D example.com      # Disable site (nginx)
brolit -t project -st regen-nginx -D example.com  # Regenerate nginx config
brolit -t project -st delete -D example.com       # Full project teardown
```

### project-install

Install a new project from a JSON config file.

```bash
brolit -t project-install -tf /path/to/config.json -tt clean
brolit -t project-install -tf /path/to/config.json -tt copy
```

### database

Unified database operations. Auto-detects MySQL/PostgreSQL, host/Docker. Use `-de` to force engine.

```bash
brolit -t database -st list_db                    # List databases (auto-detect engine)
brolit -t database -st list_db -de postgres       # Force PostgreSQL
brolit -t database -st create_db -db mydb_prod
brolit -t database -st delete_db -db mydb_prod
brolit -t database -st rename_db -db old_name -dbn new_name
brolit -t database -st clone-db -db source -dbn target
brolit -t database -st export_db -db mydb_prod    # Exports to /var/www/mydb_prod_export.sql
brolit -t database -st import_db -db mydb_prod -tf /path/to/dump.sql
brolit -t database -st list_db_user
brolit -t database -st create_db_user -dbu newuser
brolit -t database -st delete_db_user -dbu olduser
brolit -t database -st change_db_user_psw -dbu myuser -dbup 'newpassword'
brolit -t database -st search-string -db mydb -tv 'pattern_to_find'
```

Engine auto-detection order:
1. If `-de` is `mysql` or `postgres` → use that
2. Check for Docker MySQL/MariaDB containers
3. Check for Docker PostgreSQL containers
4. Check installed packages (`PACKAGES_*_STATUS` from config)
5. If only one engine found → use it
6. If multiple → error, user must specify `-de`

### certbot

SSL certificate management.

```bash
brolit -t certbot -st install -D example.com     # Install new certificate
brolit -t certbot -st expand -D example.com       # Add domain to existing cert
brolit -t certbot -st force-renew -D example.com  # Force renewal
brolit -t certbot -st delete -D example.com       # Delete certificate
brolit -t certbot -st list                        # List all certificates
brolit -t certbot -st test-renew                  # Dry-run renewal test
```

### cloudflare-api

Cloudflare DNS and cache management.

```bash
brolit -t cloudflare-api -st clear_cache -D example.com
brolit -t cloudflare-api -st dev_mode -D example.com -tv on     # -tv: on/off
brolit -t cloudflare-api -st ssl_mode -D example.com -tv full   # -tv: flexible/full/strict
```

### wpcli

WordPress CLI operations.

```bash
brolit -t wpcli -st plugin-install -D example.com -tv akismet
brolit -t wpcli -st plugin-activate -D example.com -tv akismet
brolit -t wpcli -st plugin-deactivate -D example.com -tv akismet
brolit -t wpcli -st plugin-update -D example.com -tv akismet
brolit -t wpcli -st plugin-version -D example.com -tv akismet
brolit -t wpcli -st clear-cache -D example.com
brolit -t wpcli -st cache-activate -D example.com
brolit -t wpcli -st cache-deactivate -D example.com
brolit -t wpcli -st verify-installation -D example.com
brolit -t wpcli -st core-update -D example.com
brolit -t wpcli -st search-replace -D example.com -tv "http://old.com,https://new.com"
```

### server-status

Server health report (plain-text output).

```bash
brolit -t server-status                           # Full report: disk + packages + certs
brolit -t server-status -st disk                  # Disk usage only
brolit -t server-status -st packages              # Outdated packages only
brolit -t server-status -st certs                 # SSL certificate expiry for all domains
brolit -t server-status -st certs -D example.com  # Single domain cert check
```

### security-scan

Security scanning with optional target.

```bash
brolit -t security-scan                           # Full scan: wordfence + clamav + processes
brolit -t security-scan -D example.com            # Full scan on single project only
brolit -t security-scan -st wordfence             # WordPress malware scan only
brolit -t security-scan -st wordfence -D example.com
brolit -t security-scan -st clamav                # ClamAV scan only
brolit -t security-scan -st clamav -D example.com
brolit -t security-scan -st processes             # Process scanner (8-check cryptominer scan)
```

### disk-cleanup

Free disk space.

```bash
brolit -t disk-cleanup -st apt                    # Clean apt cache
brolit -t disk-cleanup -st journal                # Clean systemd journal
brolit -t disk-cleanup -st docker                 # Remove unused Docker data
brolit -t disk-cleanup -st all                    # All of the above
brolit -t disk-cleanup -st apt -dr                # Dry-run mode
```

### Other tasks

```bash
brolit -t ssh-keygen                              # Generate SSH keypair
brolit -t aliases-install                         # Install aliases + brolit symlink
brolit --version                                  # Show version
brolit --help                                     # Show help
```

## Options Reference

| Flag | Long | Description |
|------|------|-------------|
| `-t` | `--task` | Task to run |
| `-st` | `--subtask` | Sub-task within the task |
| `-D` | `--domain` | Domain (e.g. `example.com`) |
| `-db` | `--dbname` | Database name |
| `-dbn` | `--dbname-new` | New database name (rename/clone) |
| `-dbs` | `--dbstage` | Database stage (prod, dev, test) |
| `-dbu` | `--dbuser` | Database user |
| `-dbup` | `--dbuser-psw` | Database user password |
| `-de` | `--db-engine` | Database engine: `auto` (default), `mysql`, `postgres` |
| `-s` | `--site` | Site path |
| `-pn` | `--pname` | Project name |
| `-pt` | `--ptype` | Project type (wordpress, laravel, php, etc.) |
| `-ps` | `--pstate` | Project stage (prod, dev, test, stage) |
| `-tf` | `--file` | File path (for import, project-install, restore from local/url) |
| `-tt` | `--type` | Install type: `clean`, `copy` |
| `-tv` | `--task-value` | Generic value parameter (backup date for restore) |
| `-dr` | `--dry-run` | Dry-run mode |
| `-d` | `--debug` | Enable bash debug (`set -x`) |
| `-e` | `--env` | Environment |
| `-sl` | `--slog` | Script log name |

## Cron Examples

```bash
# Daily full backup with report at 2am
0 2 * * * /usr/local/bin/brolit -t backup -st full-report

# Nightly security scan
0 3 * * * /usr/local/bin/brolit -t security-scan

# Uptime check every 5 minutes (via separate cron script)
*/5 * * * * /root/brolit-shell/cron/uptime_tasks.sh

# Weekly disk cleanup
0 4 * * 0 /usr/local/bin/brolit -t disk-cleanup -st all

# Certificate expiry check daily
0 8 * * * /usr/local/bin/brolit -t server-status -st certs
```

## Important Notes

- The script **MUST run as root** (enforced by `_check_root` in `script_init`)
- CLI mode skips the banner and clear_screen (set via `script_init "true" "cli"`)
- `--help` and `--version` exit early without full initialization
- Database operations auto-detect engine unless `-de` is specified
- For Docker projects, brolit auto-detects containers and reads credentials from container environment
- Notifications (Telegram, Discord, Email, ntfy) are sent automatically on errors and important events
- Restore operations work in both interactive (terminal) and non-interactive (AI/CLI) modes
