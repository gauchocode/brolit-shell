# Week 1 Improvements: Parameter Validation and Error Handling

## Implementation Date
2025-11-08

## Summary
Significant improvements have been implemented in the non-interactive task execution system (runner.sh) to provide better parameter validation and robust error handling.

## Changes Implemented

### 1. New Function: `validate_required_params()`
**Location:** [libs/task_runner.sh:69-102](../libs/task_runner.sh#L69-L102)

**Purpose:** Validate that all required parameters are present before executing a task.

**Features:**
- Verifies multiple parameters in a single call
- Generates clear and descriptive error messages
- Converts variable names to flag format (DOMAIN → --domain)
- Provides help suggestions to the user

**Usage example:**
```bash
validate_required_params "cloudflare-clear-cache" "DOMAIN"
```

**Error output:**
```
[ERROR] Task 'cloudflare-clear-cache': Missing required parameters: DOMAIN
  - Missing required parameters for task 'cloudflare-clear-cache' [FAIL]
    Missing: --domain
  - Use --help for usage information
```

### 2. New Function: `validate_task_and_subtask()`
**Location:** [libs/task_runner.sh:104-151](../libs/task_runner.sh#L104-L151)

**Purpose:** Validate that the requested task and subtask are valid.

**Features:**
- Verifies that the subtask is present when required
- Validates that the subtask is one of the allowed options
- Shows list of valid subtasks on error

**Usage example:**
```bash
validate_task_and_subtask "backup" "${STASK}" "all files databases server-config project"
```

**Error output:**
```
[ERROR] Task 'backup': Invalid subtask 'invalid'. Valid options: all files databases server-config project
  - Invalid subtask 'invalid' for task 'backup' [FAIL]
    Valid subtasks: all files databases server-config project
```

### 3. New Function: `execute_task_with_error_handling()`
**Location:** [libs/task_runner.sh:153-200](../libs/task_runner.sh#L153-L200)

**Purpose:** Execute tasks with consistent logging and error handling.

**Features:**
- Measures task execution time
- Logs task start and end
- Provides appropriate exit codes
- Shows task duration
- Generates structured logs

**Successful execution output:**
```
[INFO] Starting task: backup-all
  - Executing task: backup-all
  [... task execution ...]
[INFO] Task 'backup-all' completed successfully in 45s
  - Task 'backup-all' completed [DONE]
    Duration: 45s
```

**Error output:**
```
[ERROR] Task 'backup-all' failed with exit code 1 after 12s
  - Task 'backup-all' failed [FAIL]
    Exit code: 1
    Duration: 12s
```

### 4. Improved Function: `tasks_handler()`
**Location:** [libs/task_runner.sh:202-457](../libs/task_runner.sh#L202-L457)

**Improvements implemented:**
- **Subtask validation:** All tasks now validate that the subtask is valid
- **Parameter validation:** Each task validates its specific required parameters
- **Proper exit codes:** Each task returns the correct exit code
- **Improved error messages:** Clearer and more actionable errors

**Validations per task:**

#### backup
- Valid subtasks: `all files databases server-config project`
- Required parameters:
  - For `project`: `--domain`

#### restore
- Valid subtasks: `all files databases server-config project`
- Required parameters:
  - For `files`, `database`, `project`: `--domain`

#### project
- Valid subtasks: `delete install`
- Required parameters:
  - For `delete`: `--domain`
  - For `install`: `--domain --pname --ptype --pstate`

#### database
- Valid subtasks: `list_db create_db delete_db rename_db import_db export_db user_create user_delete`
- Required parameters:
  - For `create_db`, `delete_db`, `export_db`: `--dbname`
  - For `rename_db`: `--dbname --dbname-new`
  - For `import_db`: `--dbname`
  - For `user_create`: `--dbuser --dbuser-psw`
  - For `user_delete`: `--dbuser`

#### cloudflare-api
- Valid subtasks: `clear_cache dev_mode ssl_mode`
- Required parameters:
  - All subtasks: `--domain`
  - For `dev_mode`, `ssl_mode`: `--task-value`

#### wpcli
- Valid subtasks: `plugin-install plugin-activate plugin-deactivate plugin-update plugin-version clear-cache cache-activate cache-deactivate verify-installation core-update search-replace`
- Required parameters:
  - All subtasks: `--domain`
  - For plugin operations: `--task-value`

## Benefits of the Improvements

### 1. Better User Experience
- Clear and descriptive error messages
- Immediate suggestions about missing parameters
- Early validation before expensive operations

### 2. Greater Robustness
- Early detection of configuration errors
- Consistent exit codes for automation
- Comprehensive user input validation

### 3. Better Debugging
- Structured logs with timestamps
- Task duration information
- Specific exit codes for each error type

### 4. Maintainability
- Centralized validation code
- Easy to add new validations
- Consistency in error handling

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error / Failed validation |
| Others | Specific code returned by the executed function |

## Testing

A test script has been created: [test_task_validation.sh](../test_task_validation.sh)

**Run tests:**
```bash
cd /home/lpadula/Documents/brolit-shell
./test_task_validation.sh
```

**Included test cases:**
1. Missing subtask for backup
2. Invalid subtask for backup
3. Missing domain for cloudflare-api
4. Missing task-value for cloudflare dev_mode
5. Invalid task
6. Missing domain for project backup
7. Valid command structure validation

## Usage Examples

### Before (without validation)
```bash
$ ./runner.sh --task cloudflare-api --subtask clear_cache
# Cryptic error or silent failure
```

### After (with validation)
```bash
$ ./runner.sh --task cloudflare-api --subtask clear_cache
[ERROR] Task 'cloudflare-clear_cache': Missing required parameters: DOMAIN
  - Missing required parameters for task 'cloudflare-clear_cache' [FAIL]
    Missing: --domain
  - Use --help for usage information
```

### Correct command
```bash
$ ./runner.sh --task cloudflare-api --subtask clear_cache --domain example.com
[INFO] Starting task: cloudflare-clear_cache
  - Executing task: cloudflare-clear_cache
  [... execution ...]
[INFO] Task 'cloudflare-clear_cache' completed successfully in 2s
  - Task 'cloudflare-clear_cache' completed [DONE]
    Duration: 2s
```

## Backward Compatibility

✅ **Fully backward compatible**

- All existing commands continue to work
- Validations added but interfaces not changed
- Existing scripts require no modifications

## Next Steps (Week 2)

1. Resolve flag conflict (-d for --debug and --domain)
2. Implement --dry-run mode
3. Add JSON output support (--output-format json)
4. Improve task-specific --help documentation

## Modified Files

- [libs/commons.sh](../libs/commons.sh) - Reduced from 2655 to 2102 lines (-21%)
  - Added import of task_runner.sh
  - Removed functions moved to task_runner.sh

## Created Files

- [libs/task_runner.sh](../libs/task_runner.sh) - New module (588 lines)
  - Contains all CLI task validation and handling functions
  - Improves code organization and maintainability
- [docs/IMPROVEMENTS-week1.md](IMPROVEMENTS-week1.md) - This documentation
- [docs/REFACTORING-task-runner.md](REFACTORING-task-runner.md) - Refactoring documentation
- [test_task_validation.sh](../test_task_validation.sh) - Test script

## Implementation Notes

- Validation functions use indirect variable expansion (`${!param}`)
- Existing behavior is preserved for tasks without subtasks
- Error handling is fail-fast: stops at the first error
- Logs are written to both file and standard output

## Author

Implemented by: Claude Code Assistant
Date: 2025-11-08
BROLIT Version: 3.4
