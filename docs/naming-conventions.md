# Brolit Shell — Naming Conventions

## Files and Directories

| Pattern | Example | Convention |
|---|---|---|
| Scripts | `runner.sh`, `updater.sh` | lowercase, snake_case, `.sh` extension |
| Libs | `docker_helper.sh`, `nginx_helper.sh` | `*_helper.sh` suffix |
| Controllers | `notification_controller.sh` | `*_controller.sh` suffix |
| Managers | `backup_restore_manager.sh` | `*_manager.sh` suffix |
| Installers | `mysql_installer.sh` | `*_installer.sh` suffix |
| Tests | `test_docker_helper.sh` | `test_*.sh` prefix |
| Cron scripts | `backups_tasks.sh` | `*_tasks.sh` suffix |
| Config templates | `brolit_conf.json` | lowercase, snake_case |
| Nginx vhosts | `wordpress_single`, `proxy_root_domain` | lowercase, snake_case, no extension |

## Variables

| Scope | Convention | Example |
|---|---|---|
| Environment/exported | UPPER_SNAKE_CASE | `BROLIT_MAIN_DIR`, `SERVER_NAME` |
| Global (non-exported) | UPPER_SNAKE_CASE | `BAK_CONFIG_FILE`, `PHP_V` |
| Local (function-scoped) | lower_snake_case | `local db_name`, `local exitstatus` |
| Config keys (JSON) | UPPER_SNAKE_CASE | `"SERVER_CONFIG"`, `"PACKAGES"` |
| Config sub-keys | lowercase or camelCase | `"webserver"`, `"smtp_server"` |

### Variable Rules

- Always reference as `${var}` (not `$var`)
- Always quote: `"${var}"`
- Declare function arguments at function start with `local`
- Use `readonly` for constants
- Use `${var:?}` for critical path variables to fail on empty

## Functions

| Pattern | Example | Convention |
|---|---|---|
| Public helpers | `database_export()`, `nginx_server_create()` | `module_action()` |
| Internal helpers | `_setup_globals_and_options()` | `_prefix` for private |
| Menu functions | `menu_main_options()`, `backup_manager_menu()` | `*_menu()` or `menu_*()` |
| Task handlers | `subtasks_backup_handler()` | `*_handler()` |
| Whiptail wrappers | `whiptail_selection_menu()` | `whiptail_*()` |
| Boolean checks | `package_is_installed()`, `network_port_is_use()` | `*_is_*()` or `*_check_*()` |
| Installers | `nginx_installer()` | `*_installer()` |

### Function Documentation

Every function must have a header comment:

```bash
################################################################################
# Short description of what the function does.
#
# Arguments:
#   ${1} = description of first argument
#   ${2} = description of second argument
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################
```

## Script Headers

Every script must start with:

```bash
#!/usr/bin/env bash
# Author: GauchoCode
# Version: X.Y
# Description: One-line description of the script
################################################################################
```

## Commit Messages

Follow conventional commits in English:

| Type | Usage |
|---|---|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `refactor:` | Code change without fix/feat |
| `chore:` | Maintenance, tooling, deps |
| `docs:` | Documentation only |

## Directories

| Directory | Purpose |
|---|---|
| `libs/` | Controllers (top-level) |
| `libs/local/` | Internal helper libraries |
| `libs/apps/` | External tool integrations |
| `utils/` | Manager scripts (menus + task handlers) |
| `utils/installers/` | Individual installer scripts |
| `config/` | Configuration templates by service |
| `cron/` | Scheduled task scripts |
| `tests/` | Test suite |
| `tools/` | Third-party tools |
| `templates/` | HTML/HTML email templates |
| `docs/` | Project documentation |
| `docs/plan/` | Implementation plans (`YYYY-MM-descriptive-name.md`) |
