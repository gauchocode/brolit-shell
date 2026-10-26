## ADDED Requirements

### Requirement: Definition-only bounded inspection
The doctor SHALL inspect only fixed configuration roots, never invoke Borgmatic, shell initialization, hooks, commands or repositories, and never write config, temporary files or proposal state.

#### Scenario: Test mode as root
- **WHEN** test mode is invoked with euid 0, any effective capability, or a relative root
- **THEN** the doctor SHALL return `invalid_invocation` before any filesystem access.

#### Scenario: Wall-clock budget exhausted
- **WHEN** the 10-second budget expires during discovery, reading or source probing
- **THEN** the result SHALL report `inspection_incomplete` with `truncated` true, keep only fully analyzed profiles, suppress all proposals, and never relabel the timeout as a filesystem or source-path finding.

#### Scenario: Unsupported filesystem or YAML
- **WHEN** an ancestor is symlinked, remote, automounted or unknown, or YAML uses unsupported/over-budget constructs
- **THEN** inspection SHALL return fixed unsupported/incomplete findings without following the path or proposing a repair.

### Requirement: Secret-safe independent protocol
The doctor SHALL emit only versioned bounded JSON with random invocation-local handles, an allowlisted configuration basename and fixed location class per profile, fixed findings, completeness, static states and limitations, never absolute paths, values, parser errors or content-derived identifiers.

#### Scenario: Operator correlation
- **WHEN** a profile file name matches `[A-Za-z0-9._-]{1,128}`
- **THEN** the profile SHALL report that basename as `file` and its fixed `location`; otherwise `file` SHALL be null, the profile SHALL not be analyzed, and discovery SHALL be incomplete.

#### Scenario: Malformed secret-bearing input
- **WHEN** parsing fails
- **THEN** stdout SHALL contain a fixed finding and stderr SHALL not expose the exception or input.

### Requirement: Narrow memory-only proposal
The doctor SHALL propose only deletion of a proven unused `constants.database` that blocks supported static resolution, after complete reference analysis and exact byte-preserving in-memory validation. Ambiguity SHALL suppress eligibility.

#### Scenario: Brolit-generated legacy profile
- **WHEN** a profile generated from a Brolit template (with `checks`, `check_last`, Borg placeholders in `archive_name_format`, inert hooks and source directories) carries an unreferenced `constants.database` with an environment dependency
- **THEN** the result MAY contain the informational proposal, while still reporting source-path findings and remaining incomplete.

#### Scenario: Hook intent unknown
- **WHEN** a hook body is empty, has a non-literal command word, or (as written, or after budgeted constant expansion) mentions `database`, a Borgmatic configuration location, a `config.yml`/`config.yaml` file or a configuration reader
- **THEN** the profile SHALL report `hook_intent_unknown`, be ambiguous, and have no proposal.

#### Scenario: Unused simple database constant
- **WHEN** the document fits the supported grammar and exact deletion can be proven without changing other bytes
- **THEN** the result MAY contain an informational semantic proposal, with no apply authority or disk writes.

#### Scenario: Custom or referenced constant
- **WHEN** a direct/transitive reference, unknown field, custom mechanism or incomplete evidence other than source-path findings exists
- **THEN** the result SHALL have no proposal and SHALL require manual review.

#### Scenario: Profile not fully analyzable
- **WHEN** any discovered profile, including a lone one, is `unsupported_profile`, `yaml_invalid` or `duplicate_key` (it may include or merge constants)
- **THEN** discovery SHALL be reported unsupported and no profile in the run SHALL carry a proposal.
