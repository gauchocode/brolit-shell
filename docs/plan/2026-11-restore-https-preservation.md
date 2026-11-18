# Plan: Preserve existing HTTPS during project restore

## Status
- **Phase**: Planning
- **Last Updated**: 2026-11-18

## Overview

A storage restore of `dev.broobe.com` on 2026-11-18 left the public site blank
even though Astro was healthy and returned full HTML inside the stack.

`project_update_domain_config()` replaces the domain's nginx configuration with
an HTTP-only server before checking DNS. In this incident DNS propagation was
not confirmed, so certbot was skipped and the previous `listen 443 ssl` block was
not restored. HTTPS then reached another server block and returned an unrelated
empty response. Restoring the previous nginx configuration, validating it with
`nginx -t` and reloading restored the full Astro site.

## Requirements

- [ ] An existing valid HTTPS configuration must survive a restore when DNS or
      certbot cannot complete.
- [ ] Do not request or renew a certificate merely to reinstall an existing one.
- [ ] Preserve the new upstream/port while restoring SSL; do not blindly restore
      an old proxy target.
- [ ] Validate with `nginx -t` before reload and retain a rollback copy.
- [ ] Ordinary first-time HTTP-only installs keep their current behavior.
- [ ] Add regression coverage for DNS timeout, certbot failure and an existing
      certificate, including a changed upstream port.

## Technical Design

### Current sequence

For a single domain, `project_update_domain_config()` currently:

1. calls `nginx_server_create()` and overwrites the active configuration;
2. waits for DNS propagation;
3. calls `certbot_certificate_install_auto()` only if propagation succeeds;
4. leaves the new HTTP-only configuration active on DNS/certbot failure.

### Proposed direction

Separate content/upstream generation from SSL activation:

- Generate the HTTP configuration without destroying recoverable SSL state.
- If an existing certificate and HTTPS server are present, prefer certbot's
  install-only path (or an equivalent reviewed nginx merge) after the new
  upstream configuration is generated. This must not require an HTTP-01
  challenge.
- If SSL cannot be restored, roll back to the saved working configuration and
  report the restore as degraded/failed rather than silently leaving a different
  HTTPS application answering for the domain.
- Never reuse an old `proxy_pass` port when the restored project has a new one.

The exact implementation needs a fixture-based comparison of certbot's
install-only behavior and the nginx writer's file/reload semantics before code.

## Implementation Progress

### Phase 1: Evidence and tests
- [ ] Add fixtures for HTTP-only, valid existing HTTPS, DNS failure, certbot
      failure and changed upstream port.
- [ ] Document certbot install-only support on the fleet's certbot versions.

### Phase 2: Implementation
- [ ] Implement the least destructive preservation path.
- [ ] Validate syntax, reload and rollback behavior.

### Phase 3: Controlled validation
- [ ] Rehearse on a disposable domain.
- [ ] Only then consider another restore on a managed host.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-11-18 | Preserve/reinstall existing certificates without a new challenge | DNS propagation is irrelevant to installing a certificate already present |
| 2026-11-18 | Do not restore the whole old nginx file blindly | The restored application may use a different upstream port |
| 2026-11-18 | Separate plan, no immediate source change | This needs nginx/certbot fixtures and controlled validation |

## Open Questions

1. Which certbot versions on the fleet support the required install-only flow?
2. Should a restore that cannot preserve previously working HTTPS be marked
   failed even when files and database were restored successfully?

## Notes

Incident evidence and the fixed public response belong in the brolit-admin
backup-progress plan's live verification section. No private key or certificate
contents are needed for this plan.
