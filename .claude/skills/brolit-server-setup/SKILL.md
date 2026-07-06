# Brolit Shell - New Server Setup Skill

## Description
Guides the interactive configuration of brolit-shell on a new server. Use this skill when the user wants to set up, configure, or deploy brolit-shell on a fresh Ubuntu server (22.04 or 24.04).

## Prerequisites
- Fresh Ubuntu 22.04 or 24.04 LTS server
- Root access (script MUST run as root)
- Internet connectivity
- Bash >= 4

## Setup Workflow

### Phase 1: Install Brolit-Shell on the Server

1. Clone the repository:
   ```bash
   cd /root/
   git clone https://github.com/gauchocode/brolit-shell
   cd brolit-shell
   chmod +x runner.sh
   ```

2. Verify Bash version:
   ```bash
   bash --version
   # Must be >= 4
   ```

### Phase 2: Generate the Configuration File

The first time `runner.sh` is executed, it detects the missing config file and offers to create one from the template at `config/brolit/brolit_conf.json`. The config file is stored at `~/.brolit_conf.json`.

**Important**: The template is copied to `~/.brolit_conf.json` and must be edited before running the script again. All values default to `"disabled"`.

Alternatively, copy the template manually:
```bash
 cp /root/brolit-shell/config/brolit/brolit_conf.json ~/.brolit_conf.json
```

### Phase 3: Configure Server Roles

Edit `~/.brolit_conf.json` and set the server profile under `SERVER_CONFIG`:

```json
{
    "SERVER_CONFIG": {
        "type": "production",
        "timezone": "America/Argentina/Buenos_Aires",
        "config": [
            {
                "webserver": "enabled",
                "database": "enabled"
            }
        ]
    }
}
```

**Decision points to ask the user:**
- Is this a **webserver**? (nginx + php)
- Is this a **database** server? (mysql/mariadb/postgres)
- What **timezone** should be used?

### Phase 4: Configure Packages (PACKAGES section)

Based on the server roles selected, configure each package. Only enable what is needed.

#### Web Server Stack (if webserver role enabled)

**Nginx:**
```json
"nginx": [{ "status": "enabled" }]
```

**PHP-FPM:**
```json
"php": [{
    "status": "enabled",
    "version": "default",
    "config": [{ "opcode": "disabled" }],
    "extensions": [{
        "wpcli": "enabled",
        "composer": "enabled",
        "redis": "disabled",
        "memcached": "disabled"
    }]
}]
```
- `version`: "default" uses OS default, or specify "8.1", "8.2", "8.3"
- Extensions: enable `wpcli` for WordPress sites, `composer` for PHP dependency management

**Certbot (SSL certificates):**
```json
"certbot": [{
    "status": "enabled",
    "config": [{ "email": "admin@example.com" }]
}]
```
- Requires a valid email for Let's Encrypt notifications

#### Database Stack (if database role enabled)

Choose ONE database engine:

**MySQL:**
```json
"mysql": [{
    "status": "enabled",
    "config": [{ "port": "default" }]
}]
```

**MariaDB (alternative to MySQL):**
```json
"mariadb": [{
    "status": "enabled",
    "config": [{ "port": "default" }]
}]
```

**PostgreSQL (alternative):**
```json
"postgres": [{
    "status": "enabled",
    "config": [{ "port": "default" }]
}]
```

**Warning**: Do NOT enable mysql AND mariadb simultaneously. The script validates this and will exit.

#### Optional Packages

**Redis:**
```json
"redis": [{ "status": "enabled" }]
```
- Recommended if using WordPress with object caching

**Docker:**
```json
"docker": [{ "status": "enabled" }]
```
- Required for Portainer

**Portainer (Docker management UI):**
```json
"portainer": [{
    "status": "enabled",
    "version": "latest",
    "config": [{
        "port": "9000",
        "nginx_proxy": "enabled",
        "subdomain": "portainer.example.com"
    }]
}]
```
- Requires Docker enabled first

**Portainer Agent:**
```json
"portainer_agent": [{
    "status": "enabled",
    "config": [{ "port": "9001" }]
}]
```

**Netdata (monitoring):**
```json
"netdata": [{
    "status": "enabled",
    "config": [{
        "web_admin": "enabled",
        "subdomain": "netdata.example.com",
        "user": "admin",
        "user_pass": "CHANGE_ME",
        "claim_token": "",
        "claim_room": ""
    }],
    "notifications": [{
        "alarm_level": "CRITICAL"
    }]
}]
```

**Monit (process monitoring):**
```json
"monit": [{
    "status": "enabled",
    "config": [{
        "monit_maila": "admin@example.com",
        "monit_httpd": [{
            "status": "enabled",
            "user": "admin",
            "pass": "CHANGE_ME"
        }],
        "monit_services": [{
            "system": "enabled",
            "nginx": "enabled",
            "phpfpm": "enabled",
            "mysql": "enabled"
        }]
    }]
}]
```

**Borg (backup tool):**
```json
"borg": [{ "status": "enabled" }]
```

**Cockpit (web-based server management):**
```json
"cockpit": [{
    "status": "enabled",
    "config": [{
        "port": "9090",
        "nginx_proxy": "enabled",
        "subdomain": "cockpit.example.com"
    }]
}]
```

**Node.js:**
```json
"nodejs": [{
    "status": "enabled",
    "version": "default",
    "config": [{ "npm": "enabled" }]
}]
```

**Custom packages:**
```json
"custom": [{
    "status": "enabled",
    "config": [{
        "vim": "true",
        "htop": "true",
        "bat": "true"
    }]
}]
```

### Phase 5: Configure Backup Methods

At least ONE backup method should be enabled. Located under `BACKUPS.methods`.

**Borg (recommended for production):**
```json
"borg": [{
    "status": "enabled",
    "config": [{
        "user": "borg-user",
        "server": "backup-server.example.com",
        "port": "22"
    }],
    "group": "server-group-name"
}]
```

**SFTP:**
```json
"sftp": [{
    "status": "enabled",
    "config": [{
        "server_ip": "backup-server-ip",
        "server_port": "22",
        "server_user": "backup-user",
        "server_user_password": "encrypted-password",
        "server_remote_path": "/backups/server-name"
    }]
}]
```

**Local:**
```json
"local": [{
    "status": "enabled",
    "config": [{ "backup_path": "/mnt/backup-drive" }]
}]
```

**Dropbox:**
```json
"dropbox": [{
    "status": "enabled",
    "config": [{ "file": "/root/.dropbox_uploader" }]
}]
```
- After enabling, must run `/root/brolit-shell/tools/third-party/dropbox-uploader/dropbox_uploader.sh` to authenticate

**Backup configuration (compression and retention):**
```json
"BACKUPS": {
    "config": [{
        "compression": [{
            "type": "lbzip2",
            "level": "5",
            "cores": "",
            "test": "true"
        }],
        "retention": [{
            "keep_daily": "7",
            "keep_weekly": "4",
            "keep_monthly": "3"
        }]
    }]
}
```
- Compression types: `lbzip2`, `pigz`, `zstd`
- Retention values should be > 0

### Phase 6: Configure Notifications

At least one notification method is recommended.

**Email (SMTP):**
```json
"email": [{
    "status": "enabled",
    "config": [{
        "email_to": "admin@example.com",
        "from_email": "brolit@server.example.com",
        "smtp_server": "smtp.provider.com",
        "smtp_port": "587",
        "smtp_tls": "true",
        "smtp_user": "user@provider.com",
        "smtp_user_pass": "app-password"
    }]
}]
```

**Telegram:**
```json
"telegram": [{
    "status": "enabled",
    "config": [{
        "bot_token": "BOT_TOKEN_HERE",
        "chat_id": "CHAT_ID_HERE"
    }]
}]
```

**Discord:**
```json
"discord": [{
    "status": "enabled",
    "config": [{
        "webhook": "DISCORD_WEBHOOK_URL"
    }]
}]
```

**ntfy:**
```json
"ntfy": [{
    "status": "enabled",
    "config": [{
        "username": "user",
        "password": "pass",
        "server": "https://ntfy.example.com",
        "topic": "brolit-alerts"
    }]
}]
```

### Phase 7: Configure Security

**Firewall (UFW):**
The firewall config is in a separate file. The path is set in `SECURITY.config.file` (default: `/root/.brolit_firewall_conf.json`).

```json
"SECURITY": {
    "status": "enabled",
    "config": [{ "file": "/root/.brolit_firewall_conf.json" }]
}
```

The firewall config file (`brolit_firewall_conf.json`) structure:
```json
{
    "ufw": [{
        "status": "enabled",
        "config": [{
            "ssh": "allow",
            "http": "allow",
            "https": "allow"
        }]
    }],
    "fail2ban": [{
        "status": "enabled",
        "config": [{
            "bandtime": "600",
            "findtime": "600",
            "maxretry": "3",
            "ignoreip": ["127.0.0.1"]
        }]
    }]
}
```
- Only set ports to `"allow"` or `"deny"` for UFW rules

### Phase 8: Configure DNS / Cloudflare

```json
"DNS": {
    "cloudflare": [{
        "status": "enabled",
        "config": [{
            "email": "admin@example.com",
            "api_key": "CLOUDFLARE_API_KEY"
        }]
    }]
}
```
- Needed for certbot DNS challenge and cache purging

### Phase 9: Configure Projects Path

```json
"PROJECTS": {
    "path": "/var/www",
    "config_path": "/etc/brolit"
}
```
- `path`: Where web projects will be stored
- `config_path`: Where project-specific configs are stored (default `/etc/brolit`)

### Phase 10: Apply Configuration (Server Setup)

After editing `~/.brolit_conf.json`, run the server setup:

```bash
cd /root/brolit-shell
./runner.sh
```

The script will:
1. Check for `~/.brolit_conf.json`
2. Validate the config version matches the template version
3. Load all configuration sections
4. Detect package configuration changes (what's installed vs. what's configured)
5. Offer to install/remove packages accordingly
6. Run `server_setup()` which calls `server_prepare()` then configures based on roles

The `server_setup()` function in `utils/server_setup.sh` handles:
- System timezone configuration
- Package update/upgrade
- Nginx installation and reconfiguration
- PHP installation and reconfiguration
- MySQL/MariaDB installation
- Certbot, Redis, Monit, Netdata, Cockpit installation

### Phase 11: Post-Setup Tasks

1. **Install aliases** (optional):
   ```bash
   # From the brolit menu, or manually:
   cp /root/brolit-shell/aliases.sh ~/.bash_aliases
   source ~/.bash_aliases
   ```

2. **Customize login message** (optional):
   ```bash
   # From the brolit menu
   ```

3. **Configure cron jobs**:
   Use the "CRON TASKS" option in the main menu to set up:
   - Backup schedules
   - Security tasks
   - Uptime monitoring
   - WordPress maintenance
   - Optimization tasks

4. **Verify MySQL credentials**:
   ```bash
   # Ensure /root/.my.cnf exists with correct credentials
   ```

5. **If using Dropbox**, authenticate:
   ```bash
   /root/brolit-shell/tools/third-party/dropbox-uploader/dropbox_uploader.sh
   ```

## Quick Reference: Common Server Profiles

### Profile 1: Full LEMP Web Server
```json
{
    "SERVER_CONFIG": {
        "timezone": "UTC",
        "config": [{ "webserver": "enabled", "database": "enabled" }]
    },
    "PACKAGES": {
        "nginx": [{ "status": "enabled" }],
        "php": [{
            "status": "enabled", "version": "default",
            "config": [{ "opcode": "disabled" }],
            "extensions": [{ "wpcli": "enabled", "composer": "enabled", "redis": "enabled", "memcached": "disabled" }]
        }],
        "mysql": [{ "status": "enabled", "config": [{ "port": "default" }] }],
        "redis": [{ "status": "enabled" }],
        "certbot": [{ "status": "enabled", "config": [{ "email": "admin@example.com" }] }]
    }
}
```

### Profile 2: Docker Host
```json
{
    "SERVER_CONFIG": {
        "timezone": "UTC",
        "config": [{ "webserver": "disabled", "database": "disabled" }]
    },
    "PACKAGES": {
        "docker": [{ "status": "enabled" }],
        "portainer": [{ "status": "enabled", "config": [{ "port": "9000", "nginx_proxy": "enabled", "subdomain": "portainer.example.com" }] }],
        "nginx": [{ "status": "enabled" }],
        "certbot": [{ "status": "enabled", "config": [{ "email": "admin@example.com" }] }]
    }
}
```

### Profile 3: Database-Only Server
```json
{
    "SERVER_CONFIG": {
        "timezone": "UTC",
        "config": [{ "webserver": "disabled", "database": "enabled" }]
    },
    "PACKAGES": {
        "mysql": [{ "status": "enabled", "config": [{ "port": "default" }] }],
        "redis": [{ "status": "enabled" }]
    }
}
```

### Profile 4: Monitoring Server
```json
{
    "SERVER_CONFIG": {
        "timezone": "UTC",
        "config": [{ "webserver": "disabled", "database": "disabled" }]
    },
    "PACKAGES": {
        "docker": [{ "status": "enabled" }],
        "nginx": [{ "status": "enabled" }],
        "netdata": [{ "status": "enabled", "config": [{ "web_admin": "enabled", "subdomain": "netdata.example.com", "user": "admin", "user_pass": "CHANGE_ME" }] }],
        "certbot": [{ "status": "enabled", "config": [{ "email": "admin@example.com" }] }]
    }
}
```

## Troubleshooting

- **"Config version outdated"**: The `BROLIT_SETUP.config[].version` in `~/.brolit_conf.json` must match the template version in `config/brolit/brolit_conf.json`. Regenerate the config.
- **"No server role enabled"**: At least one of `webserver` or `database` should be `"enabled"` in `SERVER_CONFIG.config`.
- **"No backup method enabled"**: Enable at least one backup method under `BACKUPS.methods`.
- **Package conflicts**: Do not enable both `mysql` and `mariadb` simultaneously.
- **Docker-dependent packages**: Portainer requires Docker to be enabled.
- **MySQL root password**: If `/root/.my.cnf` doesn't exist, the script will prompt for the root password.

## Key Files and Locations

| File | Purpose |
|------|---------|
| `~/.brolit_conf.json` | Main configuration file (user-specific) |
| `~/.brolit_firewall_conf.json` | Firewall configuration (separate file) |
| `~/.my.cnf` | MySQL root credentials |
| `~/.cloudflare.conf` | Cloudflare API credentials (auto-generated) |
| `/root/brolit-shell/config/brolit/brolit_conf.json` | Config template (reference) |
| `/var/www/` | Default projects path |
| `/etc/brolit/` | Project-specific configurations |
| `/etc/nginx/` | Nginx configuration |
| `/etc/php/` | PHP configuration |
| `/etc/mysql/` | MySQL/MariaDB configuration |
| `/etc/letsencrypt/` | SSL certificates |
| `/etc/brolit/` | Brolit config directory |

## Instructions for AI Assistant

When using this skill to configure a new server:

1. **Ask the user** about server profile first: webserver, database, docker host, or monitoring.
2. **Gather information interactively**: timezone, domain, email, notification preferences.
3. **Build the JSON config** based on the selected profile and user answers.
4. **Write the config file** to `~/.brolit_conf.json` (only on the remote server).
5. **Warn about secrets**: remind user to set passwords, API keys, SMTP credentials after the initial setup.
6. **Suggest running** `./runner.sh` to apply the configuration.
7. **Offer to set up cron jobs** after the initial setup completes.
8. **Always read the config** using the brolit_configuration_manager functions, never directly parse the JSON.
9. **Follow Bash coding standards** from CLAUDE.md when modifying any `.sh` files.
10. **Validate config version** matches the template before running the script.
