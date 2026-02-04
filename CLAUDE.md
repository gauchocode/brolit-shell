# Brolit Shell - Project Rules

This is a Bash-based infrastructure management tool. All code must follow these conventions strictly.

## Bash Coding Standards

### Shebang
- Always start scripts with `#!/bin/bash`. No spaces before `#!`.

### Variables
- Reference variables using `${var}` instead of `$var`.
- Always quote variables: `"${var}"` to avoid issues with spaces or special characters.
- Use UPPERCASE for environment/exported variables, lowercase for local variables.
- Variables storing function arguments must be declared at the beginning of the function.

### Global vs Local Variables
- Prefer `local` variables inside functions.
- Mark global variables as `readonly` if they should not change.

### Arrays
- Explicitly declare arrays: `my_array=()` or `my_array=(...)`.
- Expand arrays with `"${my_array[@]}"` to avoid losing elements.
- Check size with `${#my_array[@]}`.
- Avoid unquoted variables or uncontrolled spaces when working with arrays.

### Long Option Notation
- Use long options when available (e.g., `--recursive`, `--force`).
- Use `--` to indicate the end of options when needed.
- Avoid cryptic compact option combinations unless they aid readability.

### Error Handling and Exit Codes
- Always check if critical operations fail: `if [[ ! -f "${file}" ]]; then ... exit 1`.
- Use `exit` with proper codes (0 = success, non-zero = error).
- Use `return` in functions to indicate success/failure.
- Provide clear error messages.

### Resource Existence and Type Checks
- Before operating on files or directories, check if they exist and are the expected type (`-f`, `-d`, etc.).
- When creating resources, check if they already exist.

### Code Structure
- Comment non-trivial blocks.
- Maintain consistent indentation.
- Organize logically: global variables, functions, "main" section.
- Use descriptive names for variables and functions.

### Functions
- Split multiple behaviors into clear functions.
- Avoid code duplication by reusing functions.

### Function Documentation
Each function must include a comment block:
```bash
################################################################################
# Function Description
#
# Arguments:
#   ${1} = ${var1}
#   ${2} = ${var2}
#
# Outputs:
#   Short explanation of the output
################################################################################
```

### User Messages
- Display informative messages (e.g., "Backup directory does not exist, creating...").
- Distinguish between error messages (stderr) and normal output.

### Security
- Use `--` when a parameter might start with `-` to prevent misinterpretation as an option.
- Quote variables to prevent unexpected expansions.
- Avoid `eval` unless strictly necessary and safe.

## Project-Specific Rules

### Brolit Configuration
- The `.brolit_conf.json` file must always be read from `utils/brolit_configuration_manager.sh`.
