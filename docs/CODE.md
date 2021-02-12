# Code: Bash Best Practices
An attempt to bring order in good advice on writing Bash scripts I collected from several sources.

## Some sources
* https://bertvv.github.io/cheat-sheets/Bash.html
* https://github.com/anordal/shellharden/blob/master/how_to_do_things_safely_in_bash.md
* https://www.reddit.com/r/commandline/comments/lha15t/bash_execution_tips_the_difference_between_and/

## Suggested tools
* VSCode with shellcheck and Bash IDE extensions
* WSL or WSL2 on Windows 10 env.

## Code: General
The principles of Clean Code apply to Bash as well
Always use long parameter notation when available. This makes the script more readable, especially for lesser known/used commands that you don’t remember all the options for.

  # Avoid:
  rm -rf -- "${dir}"

  # Good:
  rm --recursive --force -- "${dir}"

  # Don’t use:

  cd "${foo}"
  [...]
  cd ..

  # but
  
  (
    cd "${foo}"
    [...]
  )
  # pushd and popd may also be useful:

  pushd "${foo}"
  [...]
  popd
  # Use nohup foo | cat & if foo must be started from a terminal and run in the background.

## Code: Variables

* Prefer local variables within functions over global variables.
* If you need global variables, make them read-only.
* Variables should always be referred to in the ${var} form (as opposed to $var).
* Variables should always be quoted, especially if their value may contain a whitespace or separator character: "${var}".
* Capitalization
    Environment (exported) variables: ${ALL_CAPS}
    Local variables: ${lower_case}
* Positional parameters of the script should be checked, those of functions should not.
* Some loops happen in subprocesses, so don’t be surprised when setting variabless does nothing after them. Use stdout and greping to communicate status.

### Variable expansion

Good: "$my_var"
Bad: $my_var

### Command substitution

Good: "$(cmd)"
Bad: $(cmd)

There are exceptions where quoting is not necessary, but because it never hurts to quote.

The exceptions only matter in discussions of style – feel welcome to ignore them. For the sake of style neutrality, Shellharden does honor a few exceptions:

* variables of invariably numeric content: $?, $$, $!, $# and array length ${#array[@]}
* assignments: a=$b
* the magical case command: case $var in … esac
* the magical context between double-brackets ([[ and ]]) – this is a language of its own.

Should I use backticks?
Command substitutions also come in this form:

Correct: "`cmd`"
Bad: `cmd`

## Code: Arrays
arr=()	Create an empty array
arr=(1 2 3)	Initialize array
${arr[2]}	Retrieve third element
${arr[@]}	Retrieve all elements
${!arr[@]}	Retrieve array indices
${#arr[@]}	Calculate array size
arr[0]=3	Overwrite 1st element
arr+=(4)	Append value(s)
str=$(ls)	Save ls output as a string
arr=( $(ls) )	Save ls output as an array of files
${arr[@]:s:n}	Retrieve n elements starting at index s
