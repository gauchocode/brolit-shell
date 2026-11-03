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

### Review follow-ups (2026-11-01, after the fleet rollout)

- `_certbot_public_ip` requires HTTP success and validates the body: an error
  page, captive portal or plain-HTTP MITM used to become "the server IP" and
  label every resolved, non-Cloudflare domain `moved`.
- The Cloudflare ranges now match the canonical list in
  `config/nginx/conf.d/cloudflare-real-ip.conf`; four ranges were missing and
  a proxied domain resolving into them was mislabelled `moved`.
- `moved` also considers `SERVER_ADDITIONAL_IPS` and interface addresses (a
  vhost served from a secondary IP or the edge VM is not stale), and an
  AAAA-only name is no longer reported as `nxdomain`.
- The mail section resolves the public IP once per run instead of twice per
  broken domain.

## Tests

`tests/test_certbot_domain_triage.sh` (offline, stubbed resolver and public
IP): Cloudflare range edges, NXDOMAIN, Cloudflare, moved, local, multi-A and
unknown-public-IP cases.

## Rollout

| Date | Servers | Commit |
|------|---------|--------|
| 2026-10-31 | epica-apps01, arqa-web-vm, gaucho-dev04, redcoach-test, constructoradelbosque | d3b6884a |
| 2026-11-01 | gaucho-docker-host01, gaucho-docker-host02, gaucho-docker-host04, tukiverse-apps01, redcoach-docker01, redcoach-website, redcoach-mirror-cpx41use, centum-ai-services01 | 75e2d0c8 |
| 2026-11-03 | all of the above plus gaucho-automate01 | 5a6fdcc8 |

14 servers are on `5a6fdcc8` with the triage wired into
`mail_certificates_section` and `tests/test_certbot_domain_triage.sh`
passing. `gaucho-automate01` took the rollout on 2026-11-03 via a temporary
root password; its master was fully diverged (ahead 2453 / behind 2490) and
was realigned with `git reset --hard origin/master` after saving
`backup/pre-rollout-20261103` (7b05939e). Borg stays disabled there by
operator config (`BACKUPS.methods[].borg[].status = disabled`), so only the
certificate report matters on that host.

Operational notes from the rollout:

- `redcoach-docker01` had a divergent history: an older, rebased snapshot of
  master (86 files, ~8.4k lines behind, every local commit already present
  upstream with a different SHA). Realigned with `git reset --hard
  origin/master` after saving `backup/pre-rollout-20261101` (87e6bb7e).
- Several servers carry pre-existing mode-only changes (644 -> 755 on shell
  scripts). They reappear after updates, so some deployment/operator step is
  marking them executable; content is untouched. Pre-existing stashes from
  August/September were left alone.

Rollback is per server: `git checkout <previous commit>` (or
`backup/pre-rollout-20261101` on redcoach-docker01).

### Cloudflare SSL mode classification (2026-11-03)

The report now reads the zone SSL/TLS mode through the existing Cloudflare
API helpers (`certbot_cloudflare_ssl_mode`, cached per zone per run) instead
of labelling every Cloudflare-fronted domain "CF fronted":

- `flexible` / `off` -> grey "CF fronted": the origin certificate is not
  used, so a missing one is expected.
- `full` / `strict` -> WARNING "CF <mode>: origin cert required": the origin
  certificate is part of the trust chain.
- unreadable mode -> grey by default (an unreachable API must not produce
  daily noise); `BROLIT_CERT_CF_UNKNOWN=warn` opts into a warning.
- `BROLIT_CLOUDFLARE_SSL_EXPECT="zone=mode ..."` pins the expected mode per
  zone; a zone whose actual mode deviates warns with both modes called out.

The three mail decisions (no certificate, expired, days remaining) live in a
pure `mail_certificate_label` function (`color|warn|text`) covered by
`tests/test_mail_certificate_label.sh`. brolit never mutates a zone:
`cloudflare_set_ssl_mode` stays a manual, audited action; changing the mode
remains an operator decision made through the API.

Verified live on epica-apps01 2026-11-03: `broobe.com`,
`brolit-admin.epicahub.com` and `cod.gauchocode.com` all report `full`.

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-31 | Silence only "no certificate" for Cloudflare | Those origins legitimately have no public cert |
| 2026-10-31 | Keep EXPIRED warnings even behind Cloudflare | Full/strict TLS would break the site |
| 2026-10-31 | Dead/moved domains keep WARNING with a cause label | They need cleanup, not silence |
| 2026-11-03 | brolit never changes a zone's SSL mode automatically | Mode changes affect redirects/mixed content and are an operator decision; the report only reads via API |
| 2026-11-03 | Grey for flexible/off, WARNING for full/strict when the origin cert is missing | flexible/off never use the origin certificate; full/strict do |
| 2026-11-03 | Unknown SSL mode degrades to grey unless BROLIT_CERT_CF_UNKNOWN=warn | An unreachable API must not produce daily noise |
| 2026-11-03 | Expected-mode map (BROLIT_CLOUDFLARE_SSL_EXPECT) matched by zone suffix | Lets the operator adjust expectations per zone without code changes |
