# Code: Bash Best Practices
An attempt to bring order in good advice on writing Bash scripts I collected from several sources.

## Suggested tools
* VSCode with shellcheck and Bash IDE extensions.
* WSL or WSL2 on Windows 10/11 environments.

## Code: General
The principles of Clean Code apply to Bash as well.
Always use long parameter notation when available. This makes the script more readable, especially for lesser known/used commands that you don’t remember all the options for.

  # Avoid:
  rm -rf -- "${dir}"

  # Good:
  rm --recursive --force -- "${dir}"

  # Very Bad:
  rm --recursive --force -- "/{dir}" #If $dir is empty, it will delete everything!

  # Good:
  rm --recursive --force -- "/${dir:?}" #If $dir is empty, the command will fail
  
  # Don’t use:

  cd "${foo}"
  [...]
  cd ..

  # but
  
  (
    cd "${foo}"
    [...]
  )

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
### Explicitly declare arrays to enhance code clarity and prevent unexpected behavior
my_array=()

### Initialize an array 
my_array=(1 2 3)  

### Retrieve third element 
${my_array[2]}

### Retrieve all elements 
${my_array[@]} 

### Retrieve array indices 
${!my_array[@]} 

### Calculate array size 
${#my_array[@]} 

### Overwrite 1st element 
my_array[0]=3

### Append value(s) 
my_array+=(4) 

### Save ls output as an array of files 
my_array=( $(ls) )

### Retrieve n elements starting at index s
${my_array[@]:s:n}

### Remove an element from an array
unset my_array[2]

### Iterate over array elements
for element in "${my_array[@]}"; do
    echo "${element}"
done

### Check if an array is empty
if [[ ${#my_array[@]} -eq 0 ]]; then
    echo "Array is empty"
fi

## Some sources
* https://github.com/dylanaraps/pure-bash-bible
* https://bertvv.github.io/cheat-sheets/Bash.html
* https://github.com/anordal/shellharden/blob/master/how_to_do_things_safely_in_bash.md
* https://stackoverflow.com/questions/10953833/passing-multiple-distinct-arrays-to-a-shell-function
* https://www.gauchocode.com/mastering-bash-i-our-first-script/