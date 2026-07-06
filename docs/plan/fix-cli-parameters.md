# Fix CLI Parameters — Execution Plan

**Date:** 2026-06-09
**Base report:** `docs/reports/2026-06-09-cli-parameter-review.md`
**Status:** Pending

---

## Overview

Fix critical bugs and improve robustness of the brolit-shell CLI parameter system. 13 tasks in 4 phases, ~6-7h estimated.

---

## Phase 1: Critical Bugs (C1-C4)

### T1. Fix duplicate `-d` flag (C1)

**File:** `libs/task_runner.sh`

- Line 45 (`show_help`): change `-d --domain` to `-D --domain` (match `-do` already used in parser)
- Lines 49-50: remove `-q, --quiet` and `-v, --verbose` from help (not implemented)
- Line 53: implement `--version` case in `flags_handler`
- Update `show_help()` with complete task list: `backup`, `restore`, `project`, `project-install`, `database`, `cloudflare-api`, `wpcli`, `ssh-keygen`, `disk-cleanup`, `aliases-install`
- Line 597: change `exit` to `exit 1` in the `*)` catch-all

**Verification:** `bash -n libs/task_runner.sh`, `./runner.sh --help`, `./runner.sh --version`

### T2. Fix word-splitting in `$*` (C2)

**File:** `runner.sh:38`

```bash
# Before:
flags_handler $*

# After:
flags_handler "$@"
```

**Verification:** `bash -n runner.sh`

### T3. Add DBNAME validation for backup databases (C3)

**File:** `libs/task_runner.sh` — `backup)` case, before the `databases)` handler

Add validation:

```bash
databases)
    validate_required_params "backup-databases" "DBNAME"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
```

**Verification:** `./runner.sh -t backup -st databases` without `-db` → should fail with missing params error

### T4. Remove `install` from valid project subtasks (C4)

**File:** `libs/task_runner.sh:266`

```bash
# Before:
validate_task_and_subtask "project" "${STASK}" "delete install"

# After:
validate_task_and_subtask "project" "${STASK}" "delete"
```

**Verification:** `./runner.sh -t project -st install` → invalid subtask error

---

## Phase 2: Parameter Routing Fixes (S2, S3, S4)

### T5. Unify subtask names in database_manager (S3)

**Files:** `libs/task_runner.sh:303`, `utils/database_manager.sh:762-840`

Recommended option: align handler with validator.

In `task_runner.sh` update the list:
```bash
validate_task_and_subtask "database" "${STASK}" \
    "list_db create_db delete_db rename_db import_db export_db \
     list_db_user create_db_user delete_db_user change_db_user_psw"
```

In `database_tasks_handler` rename cases to match:
- `create_db_user` → already exists, just add to validation
- `delete_db_user` → already exists, just add to validation
- `change_db_user_psw` → already exists, just add to validation
- `list_db_user` → already exists, just add to validation

Add param validations for the new subtasks:
```bash
list_db_user)
    # no params needed
    ;;
create_db_user)
    validate_required_params "database-create-user" "DBUSER"
    ;;
delete_db_user)
    validate_required_params "database-delete-user" "DBUSER"
    ;;
change_db_user_psw)
    validate_required_params "database-change-psw" "DBUSER" "DBUSERPSW"
    ;;
```

**Verification:** Test each subtask via CLI

### T6. Pass DOMAIN explicitly to cloudflare_tasks_handler (S2)

**File:** `libs/task_runner.sh:357`

```bash
# Before:
execute_task_with_error_handling "cloudflare-${STASK}" "cloudflare_tasks_handler" "${STASK}" "${TVALUE}"

# After:
execute_task_with_error_handling "cloudflare-${STASK}" "cloudflare_tasks_handler" "${STASK}" "${DOMAIN}" "${TVALUE}"
```

**File:** `utils/cloudflare_manager.sh:761`

```bash
function cloudflare_tasks_handler() {
    local subtask="${1}"
    local domain="${2}"
    local tvalue="${3}"
    # use ${domain} and ${tvalue} instead of globals
}
```

**Verification:** `./runner.sh -t cloudflare-api -st clear_cache -do example.com`

### T7. Pass full parameters to project_tasks_handler (S4)

**File:** `libs/task_runner.sh:284`

```bash
# Before:
execute_task_with_error_handling "project-${STASK}" "project_tasks_handler" "${STASK}" "${PROJECTS_PATH}"

# After:
execute_task_with_error_handling "project-${STASK}" "project_tasks_handler" "${STASK}" "${PROJECTS_PATH}" "${PTYPE}" "${DOMAIN}" "${PNAME}" "${PSTATE}"
```

**Verification:** `./runner.sh -t project -st delete -do example.com` → DOMAIN reaches the handler

---

## Phase 3: Robustness Improvements (S1, S5, S7, S8)

### T8. Implement `--version` and clean up help (S5)

**File:** `libs/task_runner.sh`

- Add to `flags_handler` case:
  ```bash
  --version)
      echo "BROLIT Shell v${SCRIPT_V}"
      exit 0
      ;;
  ```
- Update `show_help()` with complete list of tasks and subtasks

**Verification:** `./runner.sh --version`, `./runner.sh --help`

### T9. Make tasks without subtask explicit (S1)

**File:** `libs/task_runner.sh`

Add a comment on each task that does not require a subtask in `tasks_handler`:
```bash
aliases-install)
    # No subtask required
    ...
```

### T10. Move chmod out of the hot path (S7)

**File:** `runner.sh:21`

Move `chmod +x ...` inside `_check_scripts_permissions()` in `commons.sh`.

**Verification:** `bash -n runner.sh`

### T11. Replace recursion with loop in menu_main_options (S8)

**File:** `libs/commons.sh:1830`

Wrap in `while true; do ... done` with a break in the else (cancel).

**Verification:** Run `./runner.sh` without args, navigate menus, cancel.

---

## Phase 4: Tech Debt (S6, S9)

### T12. Make BROLIT_MAIN_DIR dynamic in brolit_lite.sh (S6)

**File:** `brolit_lite.sh:2229`

```bash
# Before:
declare -g BROLIT_MAIN_DIR="/root/brolit-shell"

# After:
declare -g BROLIT_MAIN_DIR
BROLIT_MAIN_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
```

**Verification:** `bash -n brolit_lite.sh`

### T13. Create CLI tests (S9)

**New file:** `tests/test_task_runner.sh`

Contents:
- Test each valid task/subtask combination (mock)
- Test rejection of invalid tasks/subtasks
- Test validation of required parameters
- Test word-splitting with values containing spaces
- Test `--help`, `--version`, invalid flags

**Verification:** `./tests/tests_suite.sh`

---

## Dependencies

```
Phase 1:  T1  T2  T3  T4          (parallel, no dependencies)
Phase 2:  T5  →  T6  →  T7        (sequential)
Phase 3:  T8  T9  T10  T11        (parallel)
Phase 4:  T12 → T13               (T13 at the end, validates everything)
```

## Estimate

| Phase | Tasks | Time |
|---|---|---|
| Phase 1 (Critical) | T1-T4 | 2-3h |
| Phase 2 (Routing) | T5-T7 | 1.5h |
| Phase 3 (Robustness) | T8-T11 | 1.5h |
| Phase 4 (Tech Debt) | T12-T13 | 1.5h |
| **Total** | **13 tasks** | **~6-7h** |

## General verification post-implementation

1. `bash -n` on all modified files
2. `./runner.sh --help` — verify complete and correct output
3. `./runner.sh --version` — verify output
4. `./runner.sh -t backup -st databases` — should fail without `-db`
5. `./runner.sh -t project -st install` — should reject subtask
6. `./runner.sh -t cloudflare-api -st clear_cache -do example.com` — verify routing
7. `./runner.sh -t project -st delete -do example.com` — verify DOMAIN reaches the handler
8. `./tests/tests_suite.sh` — full suite
