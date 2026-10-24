## ADDED Requirements

### Requirement: Generate only meaningful database constants
The generator SHALL omit database detection and constants for templates without database references. It MUST require a concrete supported name when the template requires one, without evaluating arbitrary expressions or guessing the project name.

#### Scenario: Docker project with Compose variables
- **WHEN** a Docker project declares a database using an unresolved environment expression
- **THEN** the generated file-only Docker profile contains no database constant and does not invoke database-name detection

#### Scenario: Required database name is unresolved
- **WHEN** a database-aware profile has an empty or unresolved required database name
- **THEN** generation fails without publishing a final configuration

### Requirement: Preserve configuration on failed generation
The generator SHALL check mutations and required structure before atomic publication. Existing configurations MUST remain unchanged, including custom configs and configs for empty project directories.

#### Scenario: Mutation or validation fails
- **WHEN** a YAML operation fails or destinations are missing
- **THEN** no partial final config is published and restrictive staging files are removed

#### Scenario: An existing custom configuration is found
- **WHEN** generation encounters an existing configuration
- **THEN** it returns exists without rewriting or deleting it

### Requirement: Classify initialization safely
The system SHALL identify configuration and relocation failures separately, SHALL initialize only after positively identifying a missing repository, and MUST NOT expose raw captured diagnostics or accept relocation automatically.

#### Scenario: Config interpolation fails
- **WHEN** repository information fails because an environment variable is missing
- **THEN** configuration failure is reported and initialization is not attempted

#### Scenario: Trust failure includes success-like text
- **WHEN** diagnostics contain a relocation challenge and already-exists or encryption-mismatch text
- **THEN** the result is a trust failure rather than success

### Requirement: Isolate project-local failures
Configuration and relocation errors SHALL NOT trip the shared destination breaker. Its consecutive counter SHALL reset after successful initialization. Independent non-Borg methods MUST remain available.

#### Scenario: An invalid profile precedes a healthy profile
- **WHEN** one project fails with an invalid configuration
- **THEN** the subsequent project's Borg attempt is not suppressed as a shared outage

#### Scenario: Success interrupts shared failures
- **WHEN** a successful initialization follows a shared connectivity failure
- **THEN** the consecutive failure count resets
