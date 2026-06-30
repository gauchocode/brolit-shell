# Fix SSL Certificate Handling During Restore and Cloudflare Integration

## Context

When restoring a site migrated from another server using "RESTORE FROM BACKUP", the site
always fails with `ERR_SSL_VERSION_OR_CIPHER_MISMATCH`. The root cause is a combination
of bugs in Cloudflare DNS management, broken certbot retry logic, and inadequate DNS
propagation handling.

Investigation also revealed that Cloudflare's Universal SSL (Free plan) does not cover
nested subdomains (e.g., `app.en.goseries.tv`), since `*.goseries.tv` only matches
single-level subdomains. However, that is a Cloudflare configuration issue, not a code
bug.

The code bugs below prevent certbot from successfully obtaining certificates during
restore when Cloudflare is involved.

## Problems Identified

### P1: `cloudflare_set_record()` always forces `proxy=false`

**File:** `libs/apps/cloudflare_helper.sh:491-493`

```bash
# Default value
proxy_status=false #need to be a bool, not a string

[[ ${proxy_status} == "true" ]] && proxy_status=true
```

Line 491 overwrites the `proxy_status` parameter received at line 474. The caller's
value is destroyed before the boolean conversion on line 493 runs. Result: every call to
`cloudflare_set_record()` creates DNS records with proxy OFF, regardless of what the
caller passes.

**Fix:** Remove line 491 and replace lines 493 with a proper conversion:

```bash
# Convert string to boolean for Cloudflare API
[[ "${proxy_status}" == "true" ]] && proxy_status=true || proxy_status=false
```

### P2: `certbot_certificate_force_renew()` uses undefined `${email}`

**File:** `libs/apps/certbot_helper.sh:395-404`

```bash
function certbot_certificate_force_renew() {
  local domains="${1}"        # only receives domains
  ...
  certbot --nginx ... -m "${email}" -d "${domains}"  # ${email} is undefined
```

The function only accepts `${domains}` as parameter 1, but uses `${email}` which is
never received.

**Fix:** Add `${email}` as the first parameter:

```bash
function certbot_certificate_force_renew() {
  local email="${1}"
  local domains="${2}"
```

### P3: `$?` checks `domain_get_root` instead of `cloudflare_update_record`

**File:** `libs/apps/certbot_helper.sh:509-514` and `595-598`

```bash
root_domain=$(domain_get_root "${domain}")
[[ $? -eq 0 ]] && cloudflare_update_record ... "A" "true" ...
[[ $? -eq 1 ]] && cloudflare_update_record ... "CNAME" "true" ...
```

`$?` on line 512 captures the exit status of `domain_get_root` (almost always 0), not
of the `cloudflare_update_record` call. The CNAME branch on line 513 checks `$?` which
is now the exit status of the A record update, not the original `domain_get_root`.

**Fix:** Use conditional logic based on whether `root_domain` differs from `domain`:

```bash
root_domain=$(domain_get_root "${domain}")
if [[ -n "${root_domain}" && "${root_domain}" != "${domain}" ]]; then
    cloudflare_update_record "${root_domain}" "${domain}" "CNAME" "true" "${root_domain}"
else
    cloudflare_update_record "${root_domain}" "${domain}" "A" "true" "${SERVER_IP}"
fi
```

Apply to both locations: `certbot_helper_installer_menu()` (line 509) and
`certbot_certificate_install_auto()` (line 596).

### P4: DNS propagation wait is only `sleep 5` with no retry

**File:** `libs/local/project_helper.sh:3163-3173`

```bash
if ! dig +short "${project_domain}" @1.1.1.1 | grep -q "${SERVER_IP}"; then
    sleep 5
fi
```

If DNS has not propagated, the code sleeps 5 seconds and proceeds anyway. Certbot will
immediately fail because the HTTP-01 challenge cannot reach the server.

**Fix:** Create a new helper function `wait_for_dns_propagation()` in `libs/commons.sh`
with a proper retry loop (max 60s, 5s interval). Call it from `project_update_domain_config()`
before running certbot.

### P5: Cloudflare proxy interferes with certbot HTTP-01 challenge

**File:** `libs/apps/certbot_helper.sh` — `certbot_certificate_install_auto()` path

When Cloudflare proxy is ON for a DNS record, HTTP requests to the domain are
intercepted by Cloudflare's edge. The certbot HTTP-01 challenge
(`/.well-known/acme-challenge/`) fails because Cloudflare serves its own response.

The current code sets proxy OFF initially via `cloudflare_set_record()` in
`project_update_domain_config()`, but:
1. Bug P1 means `cloudflare_set_record()` always sets proxy OFF (works by accident)
2. If the record already exists with proxy ON (e.g., from a previous partial setup),
   `cloudflare_set_record()` deletes and recreates it — but P1 means the new record
   always has proxy OFF

After certbot succeeds, `certbot_certificate_install_auto()` tries to re-enable proxy
via `cloudflare_update_record()` at lines 595-598, but bug P3 breaks this logic.

**Fix:**
1. Fix P1 so `cloudflare_set_record()` respects the caller's proxy setting
2. Fix P3 so proxy re-enable logic works correctly
3. Add explicit proxy disable/enable guard in `certbot_certificate_install_auto()`:
   - Before certbot: check and disable proxy if ON
   - After certbot succeeds: re-enable proxy

### P6: Undefined variables in `_configure_restored_project()` for Docker projects

**File:** `libs/local/restore_backup_helper.sh:605-608`

```bash
project_post_install_tasks "..." "${project_db_status}" "${db_engine}" ...
project_update_brolit_config "..." "${project_db_status}" "${db_engine}" ...
```

Variables `${project_db_status}`, `${db_engine}`, `${db_user}`, `${db_pass}` are set
in `restore_project_backup()` as local variables but never passed to
`_configure_restored_project()`. For Docker projects, these remain empty strings.

**Fix:** In `_configure_restored_project()`, extract DB info from the Docker `.env`
file when `project_install_type` is Docker:

```bash
if [[ "${project_install_type}" == "docker"* ]]; then
    local env_file="${project_install_path}/.env"
    if [[ -f "${env_file}" ]]; then
        db_engine="mysql"
        db_user="$(grep -oP '^MYSQL_USER=\K.*' "${env_file}" 2>/dev/null)"
        db_pass="$(grep -oP '^MYSQL_PASSWORD=\K.*' "${env_file}" 2>/dev/null)"
        project_db_status="enabled"
    fi
fi
```

## Implementation Plan

### Step 1: Fix `cloudflare_set_record()` proxy bug

**File:** `libs/apps/cloudflare_helper.sh`

- Remove line 491 (`proxy_status=false`)
- Replace line 493 with: `[[ "${proxy_status}" == "true" ]] && proxy_status=true || proxy_status=false`

### Step 2: Fix `certbot_certificate_force_renew()` email parameter

**File:** `libs/apps/certbot_helper.sh`

- Add `local email="${1}"` as first parameter
- Change `local domains="${1}"` to `local domains="${2}"`

### Step 3: Fix `$?` check in certbot helper

**File:** `libs/apps/certbot_helper.sh`

Replace the `$?` pattern in both `certbot_helper_installer_menu()` (lines 509-514) and
`certbot_certificate_install_auto()` (lines 595-598) with conditional logic based on
`root_domain` vs `domain`.

### Step 4: Create `wait_for_dns_propagation()` function

**File:** `libs/commons.sh`

Add new function with retry loop: max 60s, 5s interval, checks `dig +short` against
expected IP.

### Step 5: Integrate DNS wait into certbot flow

**File:** `libs/local/project_helper.sh`

Replace the `sleep 5` in `project_update_domain_config()` (lines 3163-3173) with a call
to `wait_for_dns_propagation()`. If propagation fails, log a warning and skip certbot
(instead of running certbot注定 to fail).

### Step 6: Add Cloudflare proxy guard in `certbot_certificate_install_auto()`

**File:** `libs/apps/certbot_helper.sh`

In the non-interactive Cloudflare path, before calling `certbot_certificate_install`:
- Check if DNS record has proxy ON
- If yes, disable it temporarily

After certbot succeeds:
- Re-enable proxy via `cloudflare_update_record()`

### Step 7: Fix undefined Docker variables in restore

**File:** `libs/local/restore_backup_helper.sh`

In `_configure_restored_project()`, before the call to `project_post_install_tasks()`:
- If `project_install_type` is Docker, extract `db_engine`, `db_user`, `db_pass` from
  the `.env` file using anchored grep patterns

## Files Affected

| File | Changes |
|------|---------|
| `libs/apps/cloudflare_helper.sh` | Fix proxy_status overwrite in `cloudflare_set_record()` |
| `libs/apps/certbot_helper.sh` | Fix email param, fix $? logic, add proxy guard |
| `libs/commons.sh` | Add `wait_for_dns_propagation()` function |
| `libs/local/project_helper.sh` | Replace sleep 5 with DNS propagation wait |
| `libs/local/restore_backup_helper.sh` | Fix undefined Docker variables |

## Test Scenarios

1. **Restore site from backup (same domain, Cloudflare proxied):**
   - DNS should wait for propagation (up to 60s)
   - Cloudflare proxy should be disabled before certbot
   - Certbot should obtain certificate via HTTP-01
   - Cloudflare proxy should be re-enabled after certbot
   - Site should work with HTTPS

2. **Create new site with Cloudflare:**
   - DNS record created with proxy OFF
   - Certbot obtains certificate
   - Proxy re-enabled after certbot
   - Verify `cloudflare_set_record()` now respects proxy parameter

3. **Restore Docker project:**
   - Verify `db_engine`, `db_user`, `db_pass` are correctly extracted from `.env`
   - Verify `brolit_project_conf.json` is written with correct DB info

4. **Certbot failure (DNS not propagated after 60s):**
   - Should log warning and continue with HTTP-only config
   - Should NOT silently proceed with certbot注定 to fail
