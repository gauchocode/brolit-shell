# Brolit Shell — Business Context

## What It Is

Brolit Shell is a BASH-based server management tool that automates the setup, configuration, backup, and maintenance of LEMP stack servers running Ubuntu 22.04/24.04.

## Target Users

- **Sysadmins and DevOps engineers** managing multiple Ubuntu servers
- **Web agencies** hosting WordPress and PHP sites
- **Freelance developers** managing their own infrastructure

## Core Value Proposition

Replace manual server management with a single, repeatable tool that handles the full lifecycle: initial setup, project deployment, ongoing backups, security hardening, and monitoring.

## Primary Use Cases

| Use Case | How Brolit Handles It |
|---|---|
| New server provisioning | `server_setup()` installs and configures the entire LEMP stack from a JSON config |
| Project deployment | Interactive or CLI-driven project creation with nginx vhosts, databases, SSL, and DNS |
| Automated backups | Borg-based encrypted backups with configurable retention, triggered via cron |
| Disaster recovery | Restore projects from Borg/SFTP/Dropbox/Local with automatic reconfiguration |
| WordPress management | WP-CLI wrapper for plugin/theme updates, cache ops, search-replace, security scans |
| SSL certificate lifecycle | Certbot integration with automatic creation, renewal, and expansion |
| Security hardening | UFW firewall, Fail2Ban, ClamAV, Wordfence CLI, Lynis audits |
| Monitoring | Netdata, Monit |
| DNS management | Cloudflare API for DNS records, cache purge, WAF rules |
| Notifications | Multi-channel alerts (Email, Telegram, Discord, Ntfy) for backup results, security scans, uptime checks |

## Deployment Model

Brolit Shell runs **directly on the target server** as root. It is not containerized itself — it manages containers (Docker) and services (nginx, mysql, etc.) on the host.

Configuration is stored in `~/.brolit_conf.json` on each server, managed via the built-in configuration manager or manually.

## Integration Ecosystem

- **brolit-ui / brolit-admin**: External web panels that consume `brolit_lite.sh` as an API
- **Cron**: Scheduled tasks for backups, security scans, WordPress maintenance, uptime monitoring
- **Cloud providers**: Works on any Ubuntu VPS (Hetzner, DigitalOcean, AWS, etc.)

## Key Business Rules

1. **Must run as root** — server-level operations require elevated privileges
2. **One config per server** — `~/.brolit_conf.json` defines the entire server profile
3. **Backup-first approach** — at least one backup method must be enabled before operations
4. **Ubuntu only** — supports 22.04 LTS and 24.04 LTS
5. **MySQL XOR MariaDB** — cannot run both simultaneously
6. **Config version must match** — `brolit_conf.json` version must match the template version

## Version

Current version: **3.9**. Maintained by GauchoCode.
