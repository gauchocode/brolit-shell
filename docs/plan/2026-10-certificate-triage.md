# Plan: Certificate report triage

## Status
- **Phase**: Complete
- **Last Updated**: 2026-10-31

## Overview

The nightly "SSL certificates need attention" mail mixed very different
problems under one label, and most of them were not renewal failures at all.
`certbot_domain_triage` now classifies each domain by where it actually lives,
so the report either shows an actionable cause or stays quiet when there is
nothing to fix.

## Classes

| Class | Detection | Report behaviour |
|---|---|---|
| `nxdomain` | no A record | red `nxdomain` label instead of a bare "no certificate"/EXPIRED, still WARNING (candidate for cleanup) |
| `moved` | A records exist but none is this server's public IP | red `moved` label, still WARNING (stale vhost here) |
| `cloudflare` | any A record inside Cloudflare's published ranges | grey `CF fronted`, **no WARNING** for a missing origin certificate |
| `ok` | anything else | unchanged |

An **expired** certificate behind Cloudflare still warns: with Full (strict)
TLS the origin certificate matters, so suppressing it could hide a real
outage. Only the "no certificate" case is silenced for Cloudflare-fronted
domains.

## Implementation

`libs/apps/certbot_helper.sh`:
- `_certbot_domain_ipv4` (resolver, overridable in tests),
- `_certbot_ip_is_cloudflare` (CIDR match against the 11 published ranges),
- `_certbot_public_ip` (with `CERTBOT_TRIAGE_PUBLIC_IP` override),
- `certbot_domain_triage` (returns one of the four classes).

`libs/local/mail_notification_helper.sh::mail_certificates_section` applies
the triage in the "no certificate with vhost" and "EXPIRED" branches. An
unknown public IP never produces a `moved` verdict.

## Tests

`tests/test_certbot_domain_triage.sh` (offline, stubbed resolver and public
IP): Cloudflare range edges, NXDOMAIN, Cloudflare, moved, local, multi-A and
unknown-public-IP cases.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-31 | Silence only "no certificate" for Cloudflare | Those origins legitimately have no public cert |
| 2026-10-31 | Keep EXPIRED warnings even behind Cloudflare | Full/strict TLS would break the site |
| 2026-10-31 | Dead/moved domains keep WARNING with a cause label | They need cleanup, not silence |
