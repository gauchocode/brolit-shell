#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.13
################################################################################

# Creates an archive (*.tar.gz) from given directory
function maketar() { tar cvzf "${1%%/}.tar.gz"  "${1%%/}/"; }

# Create a ZIP archive of a file or folder
function makezip() { zip -r "${1%%/}.zip" "$1" ; }

# Make dir and cd
function mcd () {

    local dir=$1

    mkdir -p "$dir"
    cd "$dir"
}

# Search with grep
function search() {

    local path=$1
    local string=$2

    # grep parameters:
    # -r or -R is recursive,
    # -n is line number, and
    # -w stands for match the whole word.
    # -l (lower-case L) can be added to just give the file name of matching files.
    grep -rnw "$path" -e "$string"
}

################################################################################

alias ..="cd .."

alias userlist="cut -d: -f1 /etc/passwd"
alias myip="curl http://ipecho.net/plain; echo"

alias ports='netstat -tulanp'

alias path='echo -e ${PATH//:/\\n}'

alias now="echo It\'s now `date +%T`"

## Colorize the grep command output for ease of use (good for log files)
alias grep='grep --color=auto'

alias lt='ls --human-readable --size -1 -S --classify'
alias lss='du -h --max-depth=1'

alias cpv='rsync -ah --info=progress2'

## get top process eating memory
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias psmem20='ps auxf | sort -nr -k 4 | head -20'
 
## get top process eating cpu
alias pscpu='ps auxf | sort -nr -k 3'
alias pscpu10='ps auxf | sort -nr -k 3 | head -10'
alias pscpu20='ps auxf | sort -nr -k 3 | head -20'

alias atop='atop -a 1'
 
## Get server cpu info
alias cpuinfo='lscpu'

# TODO: Backup scripts
#alias backup='/root/lemp-utils-scripts/runner.sh --option backup --target all'