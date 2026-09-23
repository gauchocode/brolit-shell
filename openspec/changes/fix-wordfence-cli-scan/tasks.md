## 1. Shared Wordfence build

- [x] 1.1 Add the owned Bookworm Dockerfile and pin the source version to `v5.0.6`.
- [x] 1.2 Consolidate clone/update/build behavior into one helper, protect the stored license, and surface failures.
- [x] 1.3 Route installer, updater, malware scan, and vulnerability scan through the shared build helper.

## 2. Scan outcomes and consumers

- [x] 2.1 Implement the strict stdout result contract, stdin-only license handoff, and strict CSV validation.
- [x] 2.2 Update CLI security scan handling to distinguish errors, clean scans, and findings.
- [x] 2.3 Verify scheduled scan handling preserves `Error` state and nonzero exit on Wordfence failures.

## 3. Verification

- [x] 3.1 Add mocked unit tests for source/build failures, scan result outcomes, report validation, and CLI error propagation.
- [x] 3.2 Run Bash syntax checks and the focused test suite; resolve failures.
- [x] 3.3 Build and smoke-test the Docker image; document the license-gated scan/CSV integration command.
