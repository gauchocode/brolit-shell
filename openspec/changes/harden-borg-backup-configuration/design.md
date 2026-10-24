## Context

The approved direction is a reusable upstream correction with safe existing-installation handling, not a VPS-specific patch. The first delivery intentionally addresses generation and failure classification; repository identity migration is a separate security-sensitive phase.

## Goals / Non-Goals

**Goals:** generate only necessary database constants; fail closed on unresolved required values; preserve existing configurations; check all YAML mutations; isolate configuration/trust failures; avoid initialization on non-missing repositories; provide deterministic offline regressions.

**Non-Goals:** deployment, automatic legacy repair, general Compose interpolation, changing backup coverage policy, rewriting paths, accepting moved repositories, removing security/cache state, PostgreSQL template redesign, and observer trust-policy changes.

## Decisions

1. Extract generation into a helper that can be sourced without executing cron. Keep the existing created/exists/skipped/failed stdout protocol. Use loaded Borg destination arrays rather than parsing the main JSON directly.
2. Docker/default templates do not need a database constant. Database-aware templates require a concrete name and must not guess the project domain. Do not source application environment files, use eval, or expand arbitrary variable expressions.
3. Use restrictive same-directory staging, checked yq mutations, required repository/constant checks, and atomic publication. Failure leaves the final path absent or unchanged. Existing configs, including empty-project configs, remain untouched.
4. Preserve the current generated URL spelling for this delivery. Changing it alone cannot safely repair existing Borg security records.
5. Distinguish configuration, relocation, authentication, network, quota, lock, missing repository, and unknown failures. Preflight with bounded `repo-list --short --last 1`, which reads the repository manifest without calculating every archive's statistics; never use unbounded `info` for this gate. Initialize only when the result positively establishes a missing repository. Unsupported probe syntax fails closed without attempting init. Security/config failures outrank broad already-exists or encryption-mismatch text. Do not automatically accept relocation.
6. Return a classified initialization failure explicitly to cron. Only clear shared-destination failures contribute to its breaker; successful initialization resets consecutive failures. Project-local failures do not skip unrelated sites or traditional backup methods. Never infer restore verification from an exit status.
7. Log fixed classes and safe contextual metadata, not stderr/config/environment contents. Existing observer/global trust flags are a known separate workstream; this change must not add or rely on them as remediation.
8. The user subsequently authorized a disposable Docker integration environment and feature-branch publication. Actual-template validation requires two narrow PostgreSQL schema corrections (`postgresql_databases`, `format: plain`); this does not redesign credentials, dump hooks or database coverage. Test both Borgmatic 1.9.14 and 2.1.7 with real yq and local Borg repositories, including a payload restore, before publishing.

## Risks / Trade-offs

- Stricter generation may reject ambiguous database setups that formerly guessed a name → retain existing configs and document operator correction.
- Static YAML validity is weaker than runtime variable resolution → test missing variable diagnostics and exact generation behavior, do not claim config validate proves backup success.
- Restricting initialization can expose earlier false-success tests → update fixtures to distinguish preflight information from creation.
- Existing custom configs remain broken until reviewed → provide a manual, backup-first remediation guide; no implicit migration.
- Tests with fake providers do not prove upstream version compatibility → explicitly document the validation boundary.

## Migration Plan

No automatic configuration migration in this delivery. Operators inspect affected configs, back them up outside Borgmatic's scanned configuration directories, and remove a database constant only after proving it is unused. Referenced values require an application-specific concrete configuration. Relocation requires independently verified repository identity and a separately approved procedure. Code rollback must not revert unrelated configuration edits or mutate archives.

## Open Questions

Follow-up design approval is required for removing existing trust overrides and selecting a cross-provider repository URL policy. Neither is silently bundled into this delivery.
