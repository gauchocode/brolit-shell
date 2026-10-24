# Borg configuration safety

## New profiles

Cron's generator uses destination arrays already loaded by the configuration
manager. It does not read the main JSON itself. Production directories and
repository URL spelling are unchanged.

- Docker and fallback file-only templates do not detect or emit a database name.
- Templates referencing `{database}` require a literal detected name matching
  `[A-Za-z0-9_][A-Za-z0-9_.-]*`. Missing names, shell/Compose substitutions,
  PHP expressions and ambiguous definitions fail closed. The project/domain is
  **not** a database-name fallback. Environment/PHP files are never evaluated.
- Supported literal WordPress definitions and `.env` database names are read
  statically. WordPress requires one plain literal definition; commented
  definitions, other `DB_NAME` mentions, duplicates, inline-commented definitions
  and expressions are conservatively rejected, not evaluated. An ambiguous
  WordPress file does not fall back to a sibling `.env`. Non-literal or unusual
  database setups require operator review.
- At least one complete destination is required. Users, hosts, group and hostname
  must be concrete supported values, and ports must be in 1–65535.
- All writes and required structure/value checks must succeed before publication.
  Project, group and hostname must equal the requested strings exactly; nonempty
  template placeholders, missing/null values and non-string values cannot pass.
  Hidden same-directory staging files are mode 600 and cleaned on ordinary
  failure or handled signals. Publication is atomic and cannot overwrite a
  concurrent creator. Existing profiles, including profiles for now-empty
  projects and symbolic links, return `exists` without modification.

The generator is defined in `libs/local/borg_config_helper.sh`; sourcing this
helper does not run backups. Its `created`, `exists`, `skipped`, `failed` stdout
protocol is unchanged. The existing pause-hook sanitizer is a separate,
pre-existing behavior and has not been changed by this delivery.

## Initialization and diagnostics

Each repository is checked using bounded `borgmatic repo-list --short --last 1`
before creation. This lists at most one archive name from the repository manifest
without calculating archive statistics. Unsupported probe syntax fails closed;
there is no fallback to `info` or an unbounded listing. See the official
[repo-list action reference](https://torsion.org/borgmatic/reference/command-line/actions/repo-list/).
Creation is allowed **only** for a positive repository-missing diagnostic. An
unrelated missing file, unknown error, bad configuration, relocation challenge,
authentication failure, lock or connectivity failure does not permit init.
Config/relocation failures take precedence over misleading `already exists` or
encryption-mismatch text. Creation races retain the existing already-present and
encryption-mismatch compatibility behavior only after a missing preflight.
Expected probe/init failures are captured explicitly, including when the caller
enables Bash `errexit`; a missing repository does not prematurely terminate the
initializer before classification.

Logs/display report fixed classes: `config`, `relocation`, `network`, `auth`,
`space`, `lock`, `python_env`, `repo_missing`, `encryption_mismatch`, `unknown`.
Captured provider output is never copied into these diagnostics. Do not paste
raw configuration/environment/provider output into tickets or notifications.

Only classified shared `network`, `auth` and `space` failures count toward the
run-level breaker. Success resets the consecutive count. Local/unknown/mixed
errors also interrupt the shared failure sequence, so one invalid profile cannot
disable the next project's Borg attempt. The gate returns the actual class to
cron; independent traditional database/file scheduling remains unchanged.

Multi-repository initialization still returns usable if at least one repository
succeeds, with a reduced-redundancy warning for other failures. This is **not** a
claim that a later combined create succeeded everywhere or that a restore was
verified. Full per-destination create accounting is deferred.

## Existing-installation remediation (manual only)

1. Stop overlapping scheduled runs while reviewing an affected profile. Keep
   traditional backup methods available and establish the actual coverage gap.
2. Make a restrictive backup of the original profile **outside every directory
   Borgmatic scans for configuration** (for example, a root-only incident
   directory outside `/etc/borgmatic.d` and `/etc/borgmatic`). Do not leave
   `profile.old.yml`, `.bak` copies, or temporary repair profiles in scan dirs.
3. Review the entire profile, includes, hooks and constant references. Remove a
   legacy `database` constant only after proving it is unused. If referenced,
   supply a concrete application-specific name after verifying the application;
   do not guess the domain or source/evaluate its environment files.
4. Review and validate the edited profile privately with the installed supported
   tools. Static YAML/schema checks alone do not prove interpolation, repository
   access, archive creation, database coverage or restorability. Plan a separate
   controlled backup/restore verification before claiming recovery readiness.
5. If the class is `relocation`, independently verify repository identity and
   obtain approval for a provider-specific migration procedure. Do not change
   URLs, delete Borg security/cache records, or accept relocation to silence it.
6. Preserve custom edits on rollback; reverting the code does not justify
   replacing configuration or changing archives.

No automatic profile repair or path migration is included. Existing global and
observer trust overrides are unchanged, remain a known security follow-up, and
are **not** recommended remediation. New code does not add a trust override.

## Validation boundary

Standalone Bash fixtures test publication, failure isolation and fixed-code
diagnostics without loading cron or the full test suite. The strict `yq` double
operates on JSON (a YAML subset); it is not a YAML parser and does not prove
compatibility with upstream tool versions. Real supported `yq`/Borgmatic/Borg
integration and controlled restore verification are separate gates. The
disposable [integration environment](../tests/borg-safety-integration/README.md)
passed on 2026-10-24 with Ubuntu 24.04 (amd64), Borg 1.2.8, yq 4.47.2 and
Borgmatic **1.9.14 and 2.1.7**. Both runs validated all four real generated
templates, missing-only initialization, two local repositories, blocked
relocation, failed environment interpolation and a file create/extract round
trip checked with `cmp`. They also passed the six offline Bash suites and all
13 observer template-parser tests. The PostgreSQL template now uses the schema
keys `postgresql_databases` and `format: plain` accepted by both tested versions.

This is not a claim of PostgreSQL/MySQL dump correctness, Docker hook execution,
SSH/provider compatibility, large-manifest performance, other OS/tool versions,
or production restore readiness. Those require deployment-specific validation.
The manifest probe's `--last 1` bounds returned names, not all
manifest processing or transport work; it is not a constant-time guarantee for
every manifest size. `BROLIT_BORG_INIT_TIMEOUT` defaults to 300 seconds. A timeout
or unsupported syntax fails closed and must not trigger automatic initialization.
