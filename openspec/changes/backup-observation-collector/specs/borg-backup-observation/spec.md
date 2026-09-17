## ADDED Requirements

### Requirement: Safe typed Borgmatic discovery
Discovery SHALL parse only a tested typed configuration subset without invoking Borgmatic or hooks. It SHALL preserve individual configured repositories and source/database association evidence. Unresolved includes, tags, constants or executable authentication constructs MUST produce explicit limitations rather than guessed paths.

#### Scenario: Unsupported configuration syntax
- **WHEN** a configuration contains an unsupported include or recursive substitution
- **THEN** discovery reports a scoped limitation without evaluating it or concluding historical archives are absent

#### Scenario: Multiple destinations and mixed sources
- **WHEN** configuration defines two repositories and both file and database sources
- **THEN** each repository retains independent identity and association evidence without a files-only classification inferred from its name

### Requirement: Structured per-repository metadata
Inventory SHALL use a tested structured Borg metadata profile for exactly one resolved repository, preserve native identity and available timestamp/size semantics, and compute oldest/newest from explicit archive timestamps. It MUST NOT use listing order, archive names or repository modification time as authoritative backup time.

#### Scenario: Unordered same-day archives
- **WHEN** structured output contains distinct archives on the same day in arbitrary order
- **THEN** all native archive identities remain distinct and extrema follow actual archive timestamps

#### Scenario: Missing optional metrics
- **WHEN** a tested profile provides no per-archive size
- **THEN** size remains unknown with its limitation instead of zero or an apportioned repository total

### Requirement: Independent completeness and safe failures
Each repository SHALL retain its own outcome. Successful empty listing SHALL differ from failed access. The adapter MUST NOT create repositories, break locks, override host trust, read archive contents or perform backup maintenance. A tested profile MAY set the fixed `BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=yes` and `BORG_RELOCATED_REPO_ACCESS_IS_OK=yes` environment exceptions for approved compatibility cases; the request and configuration cannot control these flags. Necessary tool-local caches/locks SHALL be documented and bounded per tested profile.

#### Scenario: One mirror is inaccessible
- **WHEN** one configured repository lists successfully and another fails authentication
- **THEN** the successful evidence and the other repository's explicit failure remain separate, without declaring mirror equivalence or an empty failed repository

#### Scenario: Repository is busy
- **WHEN** Borg reports a lock conflict
- **THEN** collection reports the canonical busy limitation without breaking the lock or repairing the repository

#### Scenario: Empty valid repository
- **WHEN** an authorized repository returns a valid complete structured listing with no archives
- **THEN** that scope is reported complete and empty, distinct from access failure

### Requirement: Honest version and continuation support
The adapter SHALL probe capabilities and select only tested command/output profiles. It MUST NOT scrape human output or claim native Borg incremental cursors. Bounded listing interruption SHALL remain incomplete unless a separately tested continuation strategy satisfies the canonical contract.

#### Scenario: Untested Borg version
- **WHEN** no validated structured listing profile matches the executable
- **THEN** inventory is unsupported rather than falling back to a text parser

#### Scenario: Listing is truncated
- **WHEN** an archive listing exceeds the allowed byte or time budget
- **THEN** its outcome cannot authorize full-scope absence reconciliation
