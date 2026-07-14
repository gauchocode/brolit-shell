# Bash Best Practices Skill

## Description

Reference and enforcement guide for Bash coding standards in the brolit-shell project. Use this skill when writing, reviewing, or modifying any `.sh` file to ensure consistency with documented project conventions.

## Shebang & Script Header

Every script MUST start with:

```bash
#!/usr/bin/env bash
# Author: GauchoCode
# Version: 3.9
# Description: Short description of the script
################################################################################
```

- Never use `#!/bin/bash` — always `#!/usr/bin/env bash`
- The separator line `################################################################################` marks end of header
- Version must match the current project version

## Variable Conventions

### Naming by Scope

| Scope | Convention | Example |
|---|---|---|
| Environment (exported) | `UPPER_SNAKE_CASE` | `BROLIT_MAIN_DIR`, `SERVER_NAME` |
| Global (non-exported) | `UPPER_SNAKE_CASE` | `BAK_CONFIG_FILE`, `PHP_V` |
| Local (function-scoped) | `lower_snake_case` | `local db_name`, `local exitstatus` |
| Config keys (JSON) | `UPPER_SNAKE_CASE` | `"SERVER_CONFIG"`, `"PACKAGES"` |
| Config sub-keys | lowercase or camelCase | `"webserver"`, `"smtp_server"` |

### Rules

- Always reference variables as `${var}` — never bare `$var`
- Always quote variables: `"${var}"`
- Declare function-scoped variables with `local`
- Use `readonly` for constants
- Use `${var:?}` for critical-path variables to fail on empty/unset

## Function Documentation Format

Every function MUST have a header comment block (80 chars wide):

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

## Function Naming Conventions

| Pattern | Convention | Example |
|---|---|---|
| Public helpers | `module_action()` | `database_export()`, `nginx_server_create()` |
| Internal helpers | `_prefix` for private | `_setup_globals_and_options()` |
| Menu functions | `*_menu()` or `menu_*()` | `menu_main_options()`, `backup_manager_menu()` |
| Task handlers | `*_handler()` | `subtasks_backup_handler()` |
| Whiptail wrappers | `whiptail_*()` | `whiptail_selection_menu()` |
| Boolean checks | `*_is_*()` or `*_check_*()` | `package_is_installed()`, `network_port_is_use()` |
| Installers | `*_installer()` | `nginx_installer()` |

## File & Directory Naming

| Type | Pattern | Example |
|---|---|---|
| Scripts | lowercase, snake_case, `.sh` | `runner.sh`, `updater.sh` |
| Libs | `*_helper.sh` suffix | `docker_helper.sh`, `nginx_helper.sh` |
| Controllers | `*_controller.sh` suffix | `notification_controller.sh` |
| Managers | `*_manager.sh` suffix | `backup_restore_manager.sh` |
| Installers | `*_installer.sh` suffix | `mysql_installer.sh` |
| Tests | `test_*.sh` prefix | `test_docker_helper.sh` |
| Cron scripts | `*_tasks.sh` suffix | `backups_tasks.sh` |

## Error Handling Patterns

### Return codes

```bash
# After a command, capture exit status
some_command
exitstatus=$?
if [[ ${exitstatus} -eq 0 ]]; then
    # success path
elif [[ ${exitstatus} -eq 1 ]]; then
    # error path
fi
```

- Return `0` on success, `1` on error
- Always use `exitstatus=$?` pattern — never `if some_command; then`
- Use `${var:?}` to fail immediately on empty critical variables:

```bash
local domain="${1:?Missing domain argument}"
```

## Code Style Rules

### Always prefer

- Long options over short: `--recursive --force` instead of `-rf`
- `--` to protect against variable expansion: `rm -- "${dir}"`
- `$(cmd)` form for command substitution — never backticks
- Quote command substitutions: `"$(cmd)"`
- Explicit array declaration: `my_array=()`
- Quoted array expansion: `"${my_array[@]}"`
- Subshells for directory changes: `( cd "${dir}" && command )`

### Never

- Use `$var` without braces
- Use backticks `` `cmd` ``
- Leave variables unquoted
- Use `cd ..` to return — use subshells
- Rely on variable assignments inside subprocesses (loops in subshells)

### Array Operations

```bash
# Declare
my_array=()
my_array=(1 2 3)

# Access elements
echo "${my_array[2]}"      # third element
echo "${my_array[@]}"      # all elements
echo "${#my_array[@]}"     # count
echo "${!my_array[@]}"     # indices

# Modify
my_array[0]=3              # overwrite
my_array+=(4)              # append
unset my_array[2]          # remove
echo "${my_array[@]:2:3}"  # slice: 3 elements from index 2

# Iterate
for element in "${my_array[@]}"; do
    echo "${element}"
done
```

## Anti-Patterns (What NOT to do)

| Anti-Pattern | Correct Approach |
|---|---|
| `$var` without braces | `${var}` |
| `$var` without quotes | `"${var}"` |
| `` `cmd` `` (backticks) | `$(cmd)` |
| `cd dir` ... `cd ..` | `( cd dir && cmd )` |
| `if cmd; then` | `exitstatus=$?; if [[ ${exitstatus} -eq 0 ]]; then` |
| Global variables in functions | Always `local varname` |
| Unquoted arrays | `"${array[@]}"` |
| Parsing `.brolit_conf.json` directly | Use `utils/brolit_configuration_manager.sh` |
| Enabling MySQL and MariaDB simultaneously | Mutually exclusive |
| Running as non-root | Script MUST run as root |

## Key Files

| File | Purpose |
|---|---|
| `docs/CODE.md` | Bash best practices reference |
| `docs/naming-conventions.md` | File, variable, function naming rules |
| `AGENTS.md` | Full coding conventions and lib loading order |
| `docs/architecture.md` | System architecture and component map |

## Instructions for AI Assistant

1. Always use `#!/usr/bin/env bash` as shebang — never `#!/bin/bash`
2. Always declare function variables with `local`
3. Always use `${var}` with braces and quotes: `"${var}"`
4. Always use `$(cmd)` — never backticks
5. Always use `--long-opts` over short flags when available
6. Always use `--` to protect against variable expansion in commands like `rm`, `mv`, `cp`
7. Always check file/dir existence before operations (`-f`, `-d`)
8. Always include the function documentation block before every function
9. Always include the script header (shebang + author + version + description) in every script
10. Always use `exitstatus=$?` pattern for error handling — never `if cmd; then`
11. Always use subshells `( cd dir && cmd )` instead of `cd dir; cmd; cd ..`
12. Always declare arrays explicitly and expand with `"${array[@]}"`
13. Use `readonly` for constants
14. Use `${var:?}` for critical-path variables to fail on empty
15. Never use `eval` unless strictly necessary
16. Annotate shellcheck suppressions inline: `# shellcheck disable=SCxxxx`
17. Run `bash -n <file>` to validate syntax before suggesting changes
