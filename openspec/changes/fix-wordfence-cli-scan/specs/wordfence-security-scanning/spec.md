## ADDED Requirements

### Requirement: Reproducible Wordfence image build
The system MUST prepare Wordfence CLI from one shared source checkout at the configured version and build its Docker image using the repository-owned Dockerfile based on a Debian release that provides the required runtime dependencies. The system MUST surface source preparation or image build failures and MUST NOT launch a scan unless the expected image is available.

#### Scenario: Successful image preparation
- **WHEN** the Wordfence image is absent and source preparation and Docker build succeed
- **THEN** the expected Wordfence image is available before the scan container is started

#### Scenario: Docker build failure
- **WHEN** Docker returns a nonzero status while building the image
- **THEN** the build operation returns a nonzero status with the build failure visible
- **AND** no scan container is launched

#### Scenario: Source preparation failure
- **WHEN** cloning or checking out the configured Wordfence version fails
- **THEN** image build and scan execution stop with a nonzero status

### Requirement: Wordfence scan result contract
The system MUST bind-mount the canonical scan directory into the container at the same absolute path, including when projects are outside `/var/www`. Each invocation MUST write to a unique temporary report and publish the canonical report only after successful validation. The system MUST NOT place the Wordfence license in process arguments or environment; it MUST deliver the license through stdin-backed configuration. The system MUST distinguish a completed clean scan, a completed scan with malware findings, and a scan execution error. A completed scan MUST return status zero and emit exactly `false` for clean or `true` for findings on stdout. An operational failure MUST return nonzero and MUST NOT be reported as clean. Human-readable diagnostics MUST NOT contaminate the machine-readable stdout result.

#### Scenario: Clean scan
- **WHEN** Wordfence completes successfully and the report contains no findings
- **THEN** the scan returns status zero and stdout is exactly `false`

#### Scenario: Scan with findings
- **WHEN** Wordfence completes successfully and the report contains one or more findings
- **THEN** the scan returns status zero and stdout is exactly `true`

#### Scenario: Container execution failure
- **WHEN** `docker run` exits nonzero
- **THEN** the scan returns nonzero and does not emit a clean result

#### Scenario: Missing or invalid report
- **WHEN** the container exits zero but the expected CSV report is absent or invalid
- **THEN** the scan returns nonzero and does not emit a clean result

#### Scenario: Project directory outside the default web root
- **WHEN** a project is configured outside `/var/www`
- **THEN** the scanner receives a read-only bind mount of the canonical project directory at the same path inside the container

#### Scenario: Overlapping scans with identical directory basenames
- **WHEN** two scans run concurrently for directories that share the same basename
- **THEN** each scan writes and validates a distinct temporary CSV before atomically publishing its result report

#### Scenario: License is not exposed in process arguments
- **WHEN** Brolit starts a Wordfence container scan
- **THEN** the license is delivered through stdin as INI configuration
- **AND** neither Docker nor Wordfence receives the license value in process arguments or environment variables

### Requirement: CLI and scheduled scan error propagation
The CLI security scan and scheduled security task MUST distinguish Wordfence execution errors from clean scans and malware findings. They MUST NOT display or persist a clean status when a Wordfence scan fails.

#### Scenario: CLI Wordfence execution error
- **WHEN** a Wordfence scan invoked by the CLI returns nonzero
- **THEN** the task reports a scan error and does not label that project `CLEAN`

#### Scenario: Scheduled Wordfence execution error
- **WHEN** a Wordfence scan invoked by the scheduled task returns nonzero
- **THEN** the final scheduled scan state is `Error` and the script exits nonzero

#### Scenario: Successful clean or finding result
- **WHEN** the Wordfence scan completes successfully
- **THEN** CLI and scheduled consumers interpret `false` as clean and `true` as malware found
