# Agent instructions for brolit-shell

> Read this file first. It is the source of truth for working on this repository.

## Project overview

BASH-based server management tool (LEMP stack). Ubuntu 22.04/24.04/26.04, Docker support, Proxmox VE with OpenResty.

## Canonical docs

| Doc | Purpose |
|---|---|
| `docs/architecture.md` | System architecture, components, data flows |
| `docs/business-context.md` | Business context, use cases, deployment model |
| `docs/naming-conventions.md` | File, variable, function naming rules |
| `docs/CODE.md` | Bash best practices reference |

## Entry points

| File | Mode |
|---|---|
| `runner.sh` | Main entry — interactive (no args) or CLI (with flags) |
| `brolit_lite.sh` | Lightweight API for external tools (brolit-ui) |
| `updater.sh` | Self-update via git pull |

## Coding conventions

- Shebang: `#!/usr/bin/env bash`
- Variables: `${var}` quoting always, UPPER for env/global, lowercase for local
- Always use `local` inside functions
- Error handling: `exitstatus=$?` after calls, then `if [[ ${exitstatus} -eq 0/1 ]]`
- Arrays: declare explicitly, expand with `"${my_array[@]}"`
- Use long opts (`--recursive`), use `--` for safety
- Check file/dir existence before operations (`-f`, `-d`)
- Avoid `eval` unless strictly necessary
- Use `readonly` for constants
- Use `${var:?}` for critical path variables to fail on empty

Full reference: `docs/naming-conventions.md` and `docs/CODE.md`

## File conventions

- **Header**: `#!/usr/bin/env bash`, then `# Author: GauchoCode`, `# Version: 3.9`, then `# Description` + `################################################################################`
- **Function docs** (required before every function):
  ```bash
  ################################################################################
  # Function Description
  #
  # Arguments:
  #   ${1} = ${var1}
  #   ${2} = ${var2}
  #
  # Outputs:
  #   0 if ok, 1 on error.
  ################################################################################
  ```

## Core libs loading order

All sourced from `BROLIT_MAIN_DIR`:
1. `libs/commons.sh` — globals, basic utilities, sources everything below
2. `libs/notification_controller.sh`
3. `libs/database_controller.sh`
4. `libs/storage_controller.sh`
5. `libs/borg_storage_controller.sh`
6. `libs/task_runner.sh`
7. `libs/local/*.sh` — project, domains, backup, restore, packages, whiptail, log, etc.
8. `libs/apps/*.sh` — docker, nginx, mysql, certbot, cloudflare, wpcli, etc.
9. `utils/*.sh` — manager scripts (project, backup, certbot, etc.)

## Commonly used utility functions

| Function | File |
|---|---|
| `display` | `libs/local/log_and_display_helper.sh:456` |
| `log_event` | `libs/local/log_and_display_helper.sh:219` |
| `log_section` / `log_subsection` | `libs/local/log_and_display_helper.sh:354/383` |
| `clear_previous_lines` | `libs/local/log_and_display_helper.sh:430` |
| `whiptail_selection_menu` | `libs/local/whiptail_helper.sh:107` |
| `project_set_config_var` | `libs/local/project_helper.sh:76` |
| `domain_get_root` | `libs/local/domains_helper.sh:60` |
| `package_is_installed` | `libs/local/packages_helper.sh:104` |
| `network_port_is_use` | `libs/commons.sh:1089` |
| `network_next_available_port` | `libs/commons.sh:1114` |
| `network_port_is_excluded` | `libs/commons.sh:1159` |

## Project-specific rules

- The `.brolit_conf.json` file must always be read from `utils/brolit_configuration_manager.sh`, never parsed directly
- Config version in `~/.brolit_conf.json` must match the template in `config/brolit/brolit_conf.json`
- MySQL and MariaDB must not be enabled simultaneously
- Script MUST run as root

## Testing

- Custom BASH test suite in `tests/`
- Entry: `tests/tests_suite.sh` (sources `libs/commons.sh` then all test files)
- Test files: `tests/test_*.sh` — each sources needed libs directly
- No BATS/shunit2 — pure custom functions
- Run syntax check: `bash -n <file>`

## Linting

- `shellcheck` annotations used inline in source files (`# shellcheck disable=SCxxxx`)
- No automated lint command; manual `bash -n` for syntax validation

## Commit conventions

- Messages must be in **English**
- Use conventional commits format: `type: description`
  - `fix:` bug fix
  - `feat:` new feature
  - `refactor:` code change without fix/feat
  - `chore:` maintenance, tooling, deps
  - `docs:` documentation only

## OpenSpec Integration

- OpenSpec is initialized in `openspec/`
- Use `/opsx:propose` to create or update a spec proposal before plan execution
- Use `/opsx:apply` after approval to materialize spec changes
- Use `/opsx:sync` to align OpenSpec state with repository planning artifacts
- Use `/opsx:archive` when work is complete
- Keep implementation plans in `docs/plan/`

## Skills

| Skill | Location |
|---|---|
| Server Setup | `.claude/skills/brolit-server-setup/SKILL.md` |
| Systematic Debugging | `.claude/skills/brolit-systematic-debugging/SKILL.md` |
| Backup and Restore | `.claude/skills/brolit-backup-restore/SKILL.md` |
| Security Hardening | `.claude/skills/brolit-security-hardening/SKILL.md` |
| CLI Commands | `.claude/skills/brolit-cli-commands/SKILL.md` |

Skills provide specialized instructions and workflows for specific tasks.
Use the skill tool to load a skill when a task matches its description.
