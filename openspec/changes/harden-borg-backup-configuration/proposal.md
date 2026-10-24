## Why

Generated Borgmatic configurations can contain unused, unresolved database environment expressions. Initialization then reports a destination outage for a project-local configuration error, and may attempt initialization after unrelated access failures. These defects must be fixed generically rather than with server-specific environment values or trust overrides.

## What Changes

- First delivery: generate database constants only for database-aware templates, require concrete database names, and publish new configurations atomically after checked mutations.
- Classify configuration and relocation failures before generic initialization results; never initialize after those failures or expose raw captured diagnostics.
- Isolate project-local failures from the shared destination circuit breaker.
- Document existing-installation remediation without automatically rewriting custom configurations, repository URLs, or security metadata.
- Follow-up scope, not part of this delivery: shared URL construction, explicit migration tooling, removal of existing automatic trust flags across readers/observers, and full per-destination redundancy accounting.

## Capabilities

### New Capabilities
- `borg-configuration-safety`: safe generated configuration and initialization failure isolation.

### Modified Capabilities
None in this delivery. Existing observer behavior remains unchanged and is explicitly not endorsed as a security solution.

## Impact

Cron configuration generation, Borg controller initialization/classification, side-effect-free helpers, isolated Bash regression tests, and operator documentation. No new dependencies, remote operations, deployment, archive mutation, or Brolit Admin changes.
