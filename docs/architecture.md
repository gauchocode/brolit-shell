# Brolit Shell — Architecture

## System Overview

Brolit Shell is a BASH-based server management tool for LEMP stacks on Ubuntu 22.04/24.04/26.04. It provides both an interactive TUI (via whiptail) and a CLI (via flags) for managing web servers, databases, backups, security, and monitoring. Supports both local Nginx and OpenResty on Proxmox VE VMs.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Entry Points                            │
│  runner.sh (interactive/CLI)  brolit_lite.sh (API)  updater │
└────────────┬────────────────────────┬───────────────────────┘
             │                        │
             ▼                        ▼
┌────────────────────────┐  ┌─────────────────────────────────┐
│   libs/commons.sh      │  │  brolit_lite.sh (standalone)    │
│   (orchestrator)       │  │  Lightweight functions for      │
│   sources all libs     │  │  brolit-ui / brolit-admin       │
└────────┬───────────────┘  └─────────────────────────────────┘
         │
    ┌────┴────────────────────────────────────────────────┐
    │                                                     │
    ▼             ▼              ▼              ▼          ▼
┌────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────┐
│Controllers│ │Local Libs│ │ App Libs  │ │  Utils    │ │ Cron │
└────────┘  └──────────┘  └──────────┘  └──────────┘  └──────┘
```

## Component Layers

### 1. Entry Points

| File | Purpose | Mode |
|------|---------|------|
| `runner.sh` | Main entry — interactive or CLI | Both |
| `brolit_lite.sh` | Lightweight API for external tools (brolit-ui) | Library |
| `updater.sh` | Self-update via git pull | Standalone |

### 2. Controllers (`libs/`)

| Controller | Purpose |
|---|---|
| `commons.sh` | Central orchestrator: sources all scripts, globals, menus, utility functions |
| `notification_controller.sh` | Multi-channel notification dispatcher (Telegram, Discord, Email, Ntfy) |
| `database_controller.sh` | DB engine router (MySQL/PostgreSQL) |
| `storage_controller.sh` | Backup storage abstraction (Borg/Dropbox/SFTP/Local) |
| `borg_storage_controller.sh` | Borg-specific backup operations |
| `task_runner.sh` | CLI flag parsing, task routing, validation |

### 3. Local Helpers (`libs/local/`)

| Helper | Responsibility |
|---|---|
| `project_helper.sh` | Project CRUD, config, database wiring |
| `backup_helper.sh` | Backup filename, compression, retention |
| `restore_backup_helper.sh` | Restore from local/FTP/URL/storage/Borg |
| `domains_helper.sh` | Domain parsing (root, subdomain, extension) |
| `json_helper.sh` | Read/write JSON via jq |
| `log_and_display_helper.sh` | Logging, display, spinner, sections |
| `whiptail_helper.sh` | TUI dialog wrappers |
| `packages_helper.sh` | apt/dpkg package management |
| `security_helper.sh` | ClamAV, Lynis, Rkhunter, Chkrootkit scans |
| `system_helper.sh` | Unattended upgrades, timezone, swap, cron |
| `optimizations_helper.sh` | RAM, images, logs, old package cleanup |
| `mail_notification_helper.sh` | SMTP email + template engine |
| `mail_template_engine.sh` | HTML template rendering |
| `wordpress_installer.sh` | Interactive WordPress project creation |
| `proxmox_helper.sh` | Proxmox VE detection, VM management |
| `npm_migration_helper.sh` | NPM to OpenResty migration |

### 4. App Integrations (`libs/apps/`)

| Integration | File | Lines |
|---|---|---|
| Docker | `docker_helper.sh` | 2625 |
| Docker Optimizer | `docker_optimizer_helper.sh` | 1901 |
| Nginx | `nginx_helper.sh` | 651 |
| OpenResty | `openresty_helper.sh` | 343 |
| MySQL/MariaDB | `mysql_helper.sh` | 1597 |
| PostgreSQL | `postgres_helper.sh` | 1588 |
| PHP | `php_helper.sh` | 419 |
| Certbot | `certbot_helper.sh` | 925 |
| Cloudflare | `cloudflare_helper.sh` | 1855 |
| WP-CLI | `wpcli_helper.sh` | 4076 |
| WordPress | `wordpress_helper.sh` | 533 |
| Wordfence CLI | `wordfencecli_helper.sh` | 268 |
| Firewall (UFW/Fail2Ban) | `firewall_helper.sh` | 376 |
| Netdata | `netdata_helper.sh` | 59 |
| Dropbox | `dropbox_uploader_helper.sh` | 480 |
| FTP | `ftp_helper.sh` | 57 |
| SFTP | `sftp_local_helper.sh` | 260 |
| Telegram | `telegram_notification_helper.sh` | 96 |
| Discord | `discord_notification_helper.sh` | 93 |
| Ntfy | `ntfy_notification_helper.sh` | 72 |

### 5. Managers (`utils/`)

Manager scripts provide menus (interactive) and task handlers (CLI). Both paths converge on the same handler functions:

| Manager | Menu Entry | CLI Task |
|---|---|---|
| `backup_restore_manager.sh` | Menu 01/02 | `-t backup` / `-t restore` |
| `project_manager.sh` | Menu 03 | `-t project` |
| `database_manager.sh` | Menu 04 | `-t database` |
| `environment_manager.sh` | Menu 05 | — |
| `wpcli_manager.sh` | Menu 06 | `-t wpcli` |
| `certbot_manager.sh` | Menu 07 | — |
| `cloudflare_manager.sh` | Menu 08 | `-t cloudflare-api` |
| `it_utils_manager.sh` | Menu 09 | — |

### 6. Installers (`utils/installers/`)

19 individual installers: nginx, openresty, php, mysql, postgres, redis, docker, portainer, certbot, borg, netdata, monit, cockpit, nodejs, wpcli, wordfencecli, zabbix, dtop.

### 7. Cron Tasks (`cron/`)

| Script | Purpose |
|---|---|
| `backups_tasks.sh` | Generate borgmatic configs + run Borg backup |
| `security_tasks.sh` | Wordfence CLI malware scan on all projects |
| `optimizer_tasks.sh` | Image/PDF optimization, old logs/pkg cleanup |
| `wordpress_tasks.sh` | WP checksum verification + updates |
| `uptime_tasks.sh` | HTTP uptime checks on all sites |
| `disk_cleanup_tasks.sh` | apt cache + journal cleanup |
| `brolit_ui_tasks.sh` | Data aggregation for brolit-ui |

## Execution Flow

### Interactive Mode

```
runner.sh (no args)
  → source libs/commons.sh
    → _source_all_scripts() [loads all libs, apps, utils]
  → script_init("true")
    → _setup_globals_and_options()
    → _check_distro() / _check_root()
    → brolit_configuration_load()
  → menu_main_options()
    → whiptail menu (10 options)
    → each option calls utils/*_manager.sh menu function
    → recursive: returns to menu after action
```

### CLI Mode

```
runner.sh -t TASK -st SUBTASK -d DOMAIN ...
  → flags_handler() [task_runner.sh:443]
    → parse flags (-t, -st, -d, -db, -tv, etc.)
    → script_init("true")
    → tasks_handler(TASK) [task_runner.sh:217]
      → validate_task_and_subtask()
      → validate_required_params()
      → execute_task_with_error_handling()
        → utils/*_tasks_handler()
```

## Configuration

| File | Location | Purpose |
|------|----------|---------|
| `brolit_conf.json` | `~/.brolit_conf.json` | Main config (server, packages, backups, notifications, DNS, proxmox) |
| `brolit_project.json` | `/etc/brolit/<domain>.json` | Per-project config |
| `brolit_firewall_conf.json` | `~/.brolit_firewall_conf.json` | UFW + Fail2Ban rules |
| `brolit_wp_defaults.json` | Config template | WordPress default settings |
| `.my.cnf` | `~/.my.cnf` | MySQL root credentials |

Config is loaded by `utils/brolit_configuration_manager.sh` at startup and stored in global variables.

### Proxmox Mode

When `proxmox_mode: "enabled"` in `brolit_conf.json`:
- `OPENRESTY_VM_IP`: IP address of the VM running OpenResty
- `OPENRESTY_VM_PASS`: SSH password for the VM (optional if SSH keys are configured)
- All OpenResty operations are executed via SSH to the VM

## Data Storage

| Path | Purpose |
|------|---------|
| `/var/www/` | Web project files |
| `/etc/brolit/` | Per-project BROLIT configs |
| `/etc/nginx/sites-available/` | Nginx virtual hosts |
| `/usr/local/openresty/nginx/conf/` | OpenResty config (when using Proxmox mode) |
| `/etc/letsencrypt/` | SSL certificates |
| `log/` | Runtime logs (gitignored) |
| `reports/` | Scan/audit reports (gitignored) |

## External Dependencies

**Required on host:** bash >= 4, jq, whiptail, curl, root access

**Managed services:** nginx, openresty, php-fpm, mysql/mariadb/postgres, redis, docker, certbot, borg, wp-cli, cloudflare API, netdata, monit, ufw, fail2ban, portainer, cockpit, zabbix

**Proxmox support:** Requires SSH access to VMs running OpenResty (configured via `OPENRESTY_VM_IP` in `brolit_conf.json`).

## Test Architecture

Custom BASH test suite in `tests/`. No external frameworks (BATS/shunit2). Each test file sources needed libs directly. Entry via `tests/tests_suite.sh`. Docker-based test environment in `tests/test-environment/`.
