# Brolit Shell — Systematic Debugging Skill

## Description

Guides systematic debugging of LEMP stack issues on servers managed by brolit-shell. Use this skill when troubleshooting nginx errors, PHP-FPM issues, MySQL connection problems, Docker container failures, or backup/restore errors.

## Debugging Workflow

### Step 1: Identify the Symptom

Ask the user:
- What is the exact error message?
- What operation were they performing? (backup, restore, project install, cron task)
- When did it start happening?
- Is it affecting one site or all sites?

### Step 2: Check Logs

| Component | Log Location | Check Command |
|---|---|---|
| Nginx error | `/var/log/nginx/error.log` | `tail -50 /var/log/nginx/error.log` |
| Nginx access | `/var/log/nginx/access.log` | `tail -50 /var/log/nginx/access.log` |
| PHP-FPM | `/var/log/php*-fpm.log` | `tail -50 /var/log/php*-fpm.log` |
| MySQL | `/var/log/mysql/error.log` | `tail -50 /var/log/mysql/error.log` |
| Docker | `docker logs <container>` | `docker logs --tail 50 <container>` |
| Brolit | `log/` directory | Check latest log file |
| Syslog | `/var/log/syslog` | `grep -i error /var/log/syslog | tail -20` |

### Step 3: Check Service Status

```bash
systemctl status nginx
systemctl status php*-fpm
systemctl status mysql
systemctl status docker
docker ps -a
```

### Step 4: Check Configuration

| Issue | What to Check |
|---|---|
| 502 Bad Gateway | PHP-FPM socket path in nginx vhost matches PHP version |
| 403 Forbidden | File permissions on `/var/www/`, nginx user is `www-data` |
| SSL errors | Certbot certificate expiry, nginx SSL config |
| DB connection refused | MySQL running, `.my.cnf` credentials correct, port matches |
| Docker port conflict | `network_port_is_use` in `libs/commons.sh:1089` |
| Backup failure | Borg connectivity, SSH key, remote server reachable |
| Cron task failure | Check `log/` for task output, verify config loaded |

### Step 5: Common Fix Patterns

**Nginx vhost syntax error:**
```bash
nginx -t
```

**PHP-FPM pool mismatch:**
- Check vhost `fastcgi_pass` matches the actual PHP-FPM socket
- Verify PHP version: `php -v` vs vhost config

**MySQL access denied:**
- Verify `/root/.my.cnf` exists with correct credentials
- Test: `mysql -e "SELECT 1"`

**Docker compose failure:**
```bash
docker compose -f /path/to/docker-compose.yml config
docker compose -f /path/to/docker-compose.yml logs
```

**Borg backup failure:**
- Test SSH connectivity: `ssh -p PORT borg-user@backup-server`
- Check borgmatic config: `validate-borgmatic-config -c /etc/borgmatic.d/CONFIG.yml`
- Check disk space on remote

### Step 6: Verify Fix

- Re-run the failed operation
- Check the relevant log for new errors
- Confirm service is responding: `curl -I https://domain.com`

## Key Files for Debugging

| File | Purpose |
|---|---|
| `libs/commons.sh` | Core init, globals, error handling |
| `libs/task_runner.sh` | CLI flag parsing, task routing, validation |
| `libs/apps/nginx_helper.sh` | Nginx vhost creation/reconfiguration |
| `libs/apps/docker_helper.sh` | Docker operations, port management |
| `libs/apps/mysql_helper.sh` | MySQL operations, credential management |
| `libs/borg_storage_controller.sh` | Borg backup/restore operations |
| `utils/brolit_configuration_manager.sh` | Config loading from `~/.brolit_conf.json` |

## Instructions for AI Assistant

1. Always start by reading the relevant log files before proposing fixes
2. Use `bash -n <file>` to check syntax before suggesting script edits
3. Reference functions by file:line format (e.g., `libs/apps/nginx_helper.sh:25`)
4. When modifying scripts, follow the coding conventions in AGENTS.md
5. After applying a fix, suggest the verification command to confirm it works
