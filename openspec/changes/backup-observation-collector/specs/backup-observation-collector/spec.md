## ADDED Requirements

### Requirement: Isolated root-only entry
The collector SHALL provide standalone capabilities, discovery and inventory operations without sourcing runner, commons or brolit_lite, calling script_init, installing dependencies, migrating configuration or sending notifications. Provider access SHALL require root.

#### Scenario: Observation bypasses initialization
- **WHEN** a valid request is submitted in an isolated fixture environment
- **THEN** only audited observation modules and allowlisted metadata operations are invoked and initialization canaries remain untouched

#### Scenario: Non-root execution
- **WHEN** an unprivileged process invokes the collector
- **THEN** it fails using canonical failure semantics before reading credentials or invoking providers

### Requirement: Canonical protocol and bounded execution
The collector MUST follow the reviewed Admin contract at `docs/architecture/backup-observation-contract.md` in brolit-admin and its referenced schemas/fixtures for exact request/report fields, versions, limits and exit semantics. It SHALL accept one bounded stdin request, emit protocol-only stdout and sanitized stderr, enforce scope correlation and preserve explicit incomplete outcomes.

#### Scenario: Unsupported or malformed request
- **WHEN** the request uses an unsupported version, unknown operation or malformed input
- **THEN** the collector rejects it with canonical error/exit semantics without provider access

#### Scenario: Output or runtime budget exhausted
- **WHEN** observation exceeds a canonical budget or subprocess output is truncated
- **THEN** it cannot emit a complete inventory and reports the affected scope and sanitized cause

### Requirement: Configuration projection and non-executing credentials
The collector SHALL obtain `.brolit_conf.json` data only through a new read-only projection within `utils/brolit_configuration_manager.sh`. It MUST NOT invoke full configuration loaders, source credentials, evaluate substitutions or execute hooks. Unsupported or invalid configuration SHALL retain diagnostic evidence without mutation.

#### Scenario: Hostile credential assignments
- **WHEN** a credential fixture contains command substitution, shell operators or executable statements
- **THEN** the parser rejects unsupported syntax, executes none of it and exposes no credential value

#### Scenario: Missing or outdated configuration
- **WHEN** configuration is absent, invalid or requires migration
- **THEN** the collector reports the limitation without creating, copying, repairing or migrating files

### Requirement: Authorized scope and secret isolation
Inventory SHALL resolve handles against authorized current configuration, reject arbitrary file/endpoint/command requests and keep credentials out of observable arguments, protocol output and diagnostics. Subprocess environments SHALL exclude unapproved executable hooks and credential commands.

#### Scenario: Stale or forged handle
- **WHEN** inventory references an unresolved handle or an unapproved root
- **THEN** collection fails explicitly without accessing the requested location

#### Scenario: Provider error contains a secret
- **WHEN** a provider returns credential-bearing stderr or response fields
- **THEN** only allowlisted sanitized metadata and error information reach stdout or stderr

### Requirement: Evidence-only tested capabilities
The collector SHALL advertise only implemented operations validated for the detected tool profile, distinguish unavailable tools from failed observations and install nothing. It SHALL return evidence and provenance without protection-policy, execution-success or restorability claims.

#### Scenario: Unknown tool profile or missing parser
- **WHEN** the installed version or necessary parser features lack a tested profile
- **THEN** the affected operation is reported unsupported through a valid failure path without installation or optimistic compatibility claims

#### Scenario: Artifact exists
- **WHEN** an archive or file is observed
- **THEN** its existence is evidence of presence only and does not assert successful backup execution or recoverability
