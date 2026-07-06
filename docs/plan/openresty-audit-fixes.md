# OpenResty/Proxmox Audit Fixes Plan

## Context

brolit-shell 3.9 now supports Proxmox VE deployments where OpenResty runs inside
a dedicated VM (VM 100, 10.2.0.100) instead of on the Proxmox host. The initial
migration was successful, but a code audit revealed that several certbot,
setup, project and OpenResty helper paths still assume nginx is local.

## Goal

Make all nginx/certbot/setup/restore/backup flows work transparently when
`PROXMOX_MODE=enabled` and `OPENRESTY_VM_IP` points to the OpenResty VM.

## Scope

This plan covers the top 9 remaining issues from the audit.

## Tasks

### 1. certbot_certonly_cloudflare runs on OpenResty VM

**File:** `libs/apps/certbot_helper.sh:1060-1122`

The function always runs `certbot certonly --dns-cloudflare` locally. In Proxmox
mode the certificate must be generated on the OpenResty VM so OpenResty can use
it.

**Implementation:**
- Reuse `certbot_setup_cloudflare_vm` (already copies `/root/.cloudflare.conf`).
- Build the certbot command string.
- Run via `openresty_vm_exec` when Proxmox mode is enabled.
- Run locally when not in Proxmox mode.
- Apply the same retry/delete logic on the VM.

### 2. certbot_certificate_renew / renew_test run on OpenResty VM

**File:** `libs/apps/certbot_helper.sh:688-764`

Both functions run `certbot renew` locally.

**Implementation:**
- Detect challenge type from the first domain.
- Set up webroot/cloudflare credentials on the VM when needed.
- Run `certbot renew` or `certbot renew --dry-run` via `openresty_vm_exec`.
- Reload OpenResty after a successful renew using `certbot_reload_openresty`.

### 3. certbot_certificate_delete runs on OpenResty VM

**File:** `libs/apps/certbot_helper.sh:1265-1320`

The function checks local certbot output and deletes local files.

**Implementation:**
- In Proxmox mode, run `certbot certificates | grep` and
  `certbot delete --cert-name` on the VM.
- Also delete `/etc/letsencrypt/archive|live|renewal` on the VM when present.
- In non-Proxmox mode keep the current local behaviour.

### 4. certbot valid days / info run on OpenResty VM

**File:** `libs/apps/certbot_helper.sh:1134-1216`

`certbot_show_certificates_info`, `certbot_show_domain_certificates_expiration_date`
and `certbot_certificate_valid_days` read local certbot output.

**Implementation:**
- Create a small helper that runs `certbot certificates` on the VM when in
  Proxmox mode and returns the output.
- Use that helper in all cert info functions.

### 5. server_setup installs/configures OpenResty in Proxmox mode

**File:** `utils/server_setup.sh:311-413`

`server_setup()` always installs nginx locally when `PACKAGES_NGINX_STATUS` is
enabled.

**Implementation:**
- When `PROXMOX_MODE=enabled`, call `openresty_installer` and
  `openresty_reconfigure` instead of `nginx_installer` / `nginx_reconfigure`.
- Keep PHP, MySQL, certbot and other packages as they are (they run on the
  Proxmox host unless configured otherwise).

### 6. project_update_domain_config uses correct config paths

**File:** `libs/local/project_helper.sh:3197-3248`

The function greps `/etc/nginx/sites-available/...` directly to check if HTTP/2
is enabled. This bypasses `nginx_server_add_http2_support`, which already
handles OpenResty redirection.

**Implementation:**
- Remove direct `grep` on `/etc/nginx/sites-available`; always call
  `nginx_server_add_http2_support` which redirects to
  `openresty_server_add_http2_support` in Proxmox mode.
- That helper already checks if http2 is present before adding it.

### 7. Lua API uses correct paths for OpenResty VM

**File:** `config/openresty/api/routes.lua`

The Lua API generates configs with:
- `error_log /var/log/nginx/...`
- `include snippets/fastcgi-php.conf`
- `fastcgi_pass unix:/run/php/php*-fpm.sock`
- `root /var/www/...`

OpenResty in VM 100 uses:
- `/var/log/openresty/` for logs
- `/usr/local/openresty/nginx/conf/snippets/fastcgi-php.conf` for the fastcgi
  snippet
- PHP-FPM may run elsewhere (not on the OpenResty VM), so WordPress templates
  should not be generated blindly without PHP backend information.

**Implementation:**
- Change `error_log` to `/var/log/openresty/${domain}.error.log`.
- Change `include snippets/fastcgi-php.conf` to the full OpenResty path.
- For WordPress routes, keep the template but document that PHP-FPM backend
  must be reachable over TCP or a shared socket path; default to a placeholder
  upstream until the API accepts `php_upstream`.
- Change webroot to `/var/www/certbot` (already correct for the VM).

### 8. proxy_single_openresty log path

**File:** `config/nginx/sites-available/proxy_single_openresty:9`

The template uses `/var/log/nginx/domain.com.error.log`.

**Implementation:**
- Change to `/var/log/openresty/domain.com.error.log`.

### 9. Syntax checks and commit

- Run `bash -n` on every modified file.
- Run the existing test suite if possible.
- Commit with author `lpadula <leandro@gauchocode.com>` and conventional commit
  message.

## Out of scope (for this plan)

- zabbix_installer local nginx edits
- netdata_installer /etc/nginx/sites-available references
- monit nginx restart
- portainer_configure WSERVER handling
- backup/restore OpenResty VM config sync
- brolit_lite OpenResty detection

These will be handled in a follow-up pass once the critical path above is
merged.
