## Why

Existing Borgmatic profiles need secret-safe static diagnosis independently of generation and repository observation. The user approved Phase A implementation on 2026-10-25; deployment, remote execution and repairs remain unauthorized.

## What Changes

- Add a standalone, bounded inspect/propose doctor, without commons, script initialization, hooks, external commands or network access.
- Add a distinct versioned JSON protocol, strict YAML/reference profile, memory-only minimal proposal simulation, offline tests and operator documentation.
- Preserve existing generation, observation, scheduling and all application configurations.

## Impact

New source under `libs/backup_config_doctor/`, a standalone shell entry point, isolated tests and documentation only. No dependency installation, apply/prepare/rollback implementation, Admin integration or deployment.
