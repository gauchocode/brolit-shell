# Brolit Shell — Security Hardening Skill

## Description

Guides security hardening and auditing of servers managed by brolit-shell. Use this skill when the user needs to configure firewalls, set up Fail2Ban, run security scans, or harden a new server.

## Security Components

### Firewall (UFW)

Managed by `libs/apps/firewall_helper.sh`:
- Default deny incoming, allow outgoing
- Configurable rules in `~/.brolit_firewall_conf.json`
- Standard allow: SSH (22), HTTP (80), HTTPS (443)

### Intrusion Detection (Fail2Ban)

Managed by `libs/apps/firewall_helper.sh`:
- Configurable: `bandtime`, `findtime`, `maxretry`, `ignoreip`
- Jail configurations for nginx, php-fpm, mysql, docker

### Malware Scanning

| Tool | File | Purpose |
|---|---|---|
| ClamAV | `libs/local/security_helper.sh` | General malware scan |
| Wordfence CLI | `libs/apps/wordfencecli_helper.sh` | WordPress-specific malware scan |
| Lynis | `libs/local/security_helper.sh` | System security audit |
| Rkhunter | `libs/local/security_helper.sh` | Rootkit detection |
| Chkrootkit | `libs/local/security_helper.sh` | Rootkit detection |

### Security Scanning Workflow

```bash
# Run via CLI
./runner.sh -t security -st clamav-scan
./runner.sh -t security -st lynis-audit

# Scheduled (cron)
cron/security_tasks.sh  # Runs Wordfence CLI on all WordPress projects
```

## Hardening Checklist for New Servers

### 1. Firewall Setup

```bash
# Configure via brolit menu or manually
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw enable
```

### 2. Fail2Ban Configuration

Set in `~/.brolit_firewall_conf.json`:
```json
{
    "fail2ban": [{
        "status": "enabled",
        "config": [{
            "bandtime": "3600",
            "findtime": "600",
            "maxretry": "3",
            "ignoreip": ["127.0.0.1"]
        }]
    }]
}
```

### 3. SSH Hardening

- Disable password authentication (key-only)
- Disable root login if not needed by brolit
- Change default SSH port (optional)
- Configure in `/etc/ssh/sshd_config`

### 4. Nginx Security

Security headers are configured in `config/nginx/globals/security.conf`:
- X-Frame-Options
- X-Content-Type-Options
- X-XSS-Protection
- Content-Security-Policy
- HSTS (when SSL is active)

### 5. PHP Hardening

Managed by `libs/apps/php_helper.sh`:
- Disable dangerous functions (`exec`, `shell_exec`, etc.)
- Set `expose_php = Off`
- Configure `open_basedir` per project

### 6. WordPress Security

- `config/nginx/globals/wordpress_sec.conf` — WordPress security rules
- Wordfence CLI for malware scanning
- WP-CLI checksum verification via `cron/wordpress_tasks.sh`

### 7. SSL/TLS

Managed by `libs/apps/certbot_helper.sh`:
- Let's Encrypt certificates via Certbot
- Auto-renewal via cron
- HTTP to HTTPS redirect in nginx vhosts

### 8. Monitoring

| Tool | Purpose |
|---|---|
| Monit | Process monitoring (nginx, mysql, php-fpm, redis) |
| Netdata | Real-time system monitoring with alerts |

## Security Scan Commands

| Scan | Command |
|---|---|
| ClamAV full scan | `clamscan -r /var/www/` |
| Lynis audit | `lynis audit system` |
| Rkhunter check | `rkhunter --check` |
| Wordfence scan | `wordfence malware-scan /var/www/domain/` |
| WP checksum | `wp core verify-checksums --path=/var/www/domain/` |
| Failed logins | `fail2ban-client status sshd` |
| Open ports | `ss -tulpn` |
| UFW status | `ufw status verbose` |

## Key Files

| File | Purpose |
|---|---|
| `libs/apps/firewall_helper.sh` | UFW and Fail2Ban management |
| `libs/local/security_helper.sh` | ClamAV, Lynis, Rkhunter, Chkrootkit |
| `libs/apps/wordfencecli_helper.sh` | WordPress malware scanning |
| `config/nginx/globals/security.conf` | Nginx security headers |
| `config/brolit/brolit_firewall_conf.json` | Firewall config template |
| `cron/security_tasks.sh` | Scheduled security scans |

## Instructions for AI Assistant

1. Never disable firewall rules without confirming with the user
2. Always suggest testing SSH access after firewall changes (to avoid lockout)
3. When hardening SSH, ensure the user has an active key-based session first
4. Reference CIS benchmarks when recommending security configurations
5. After hardening, suggest running a Lynis audit to verify the improvements
