## Why

Wordfence malware scans can fail before execution because the upstream image uses a Debian package unavailable in its current slim base. Build and scan failures can also be hidden or misreported as clean results, leaving CLI and scheduled scans without an authoritative status.

## What Changes

- Build Wordfence CLI from one shared source directory with a project-owned Dockerfile pinned to a compatible Debian base and Wordfence CLI version.
- Surface clone, build, and container execution failures and verify the image before scanning.
- Keep the Wordfence license out of process arguments by delivering it to the container through stdin-backed configuration.
- Define a stable scan result contract for clean, malware-found, and execution-error outcomes; apply it to CLI and cron consumers.
- Add automated tests for build, scan-result, report, and caller error behavior.

## Capabilities

### New Capabilities
- `wordfence-security-scanning`: Wordfence image preparation and malware scan outcome handling.

### Modified Capabilities

## Impact

- Affected scripts: `libs/apps/wordfencecli_helper.sh`, `utils/installers/wordfencecli_installer.sh`, `libs/task_runner.sh`, and `cron/security_tasks.sh`.
- New Docker build configuration under `config/docker/wordfence-cli/`.
- New custom Bash test coverage under `tests/`.
- Runtime uses Docker, Git, the Wordfence CLI upstream source, and its license key.
