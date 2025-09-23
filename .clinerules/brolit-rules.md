# Bash Rules (Best Practices)

- **Correct Shebang at the Beginning**
  - Always start scripts with `#!/bin/bash` (or the correct interpreter).
  - No spaces before `#!`.

- **Variable Usage**
  - Reference variables using `${var}` instead of `$var`.
  - Always quote variables: `"${var}"` to avoid issues with spaces or special characters.
  - Use uppercase for environment/exported variables, lowercase for local variables.

- **Global vs Local Variables**
  - Prefer local variables inside functions.
  - Mark global variables as `readonly` if they should not change.

- **Array Handling**
  - Explicitly declare arrays (`my_array=()` or `my_array=(...)`).
  - Always expand arrays with `"${my_array[@]}"` to avoid losing elements.
  - Check size with `${#my_array[@]}`.
  - Avoid unquoted variables or uncontrolled spaces when working with arrays.

- **Long Option Notation**
  - Use long options when available (e.g., `--recursive`, `--force`).
  - Use `--` to indicate the end of options when needed.
  - Avoid cryptic compact option combinations unless they aid readability.

- **Error Handling and Exit Codes**
  - Always check if critical operations fail (`if [[ ! -f "${file}" ]]; then ... exit 1`).
  - Use `exit` with proper codes (0 = success, !=0 = error).
  - Use `return` in functions to indicate success/failure.
  - Provide clear error messages.

- **Resource Existence and Type Checks**
  - Before operating on files or directories, check if they exist and are of the expected type (`-f`, `-d`, etc.).
  - When creating resources, check if they already exist.

- **Code Structure and Readability**
  - Comment non-trivial blocks.
  - Maintain consistent indentation.
  - Organize logically: global variables, functions, “main” section.
  - Use descriptive names for variables and functions.

- **Function Encapsulation**
  - Split multiple behaviors into clear functions.
  - Avoid code duplication by reusing functions.

- **User Messages**
  - Display informative messages (e.g., “Backup directory does not exist, creating…”, “Backup complete”).
  - Distinguish between error messages (stderr) and normal output.

- **Security and Robustness**
  - Use `--` when a parameter might start with “-” to prevent misinterpretation as an option.
  - Quote variables to prevent unexpected expansions.
  - Avoid `eval` unless strictly necessary and safe.
