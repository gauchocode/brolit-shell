#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.25
################################################################################

function _string_remove_spaces() {

  # Parameters
  # $1 = ${string}

  local string=$1

  # Return
  echo "${string//[[:blank:]]/}"

}

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

# All server info
function serverinfo () {

    local cpu_cores
    local ram_amount
    local disk_volume
    local disk_usage
    local public_ip
    local inet_ip       # configured on network file

    public_ip="$(myip)"
    inet_ip="$(/sbin/ifconfig eth0 | grep -w "inet" | awk '{print $2}')"

    cpu_cores="$(cpucores)"
    ram_amount="$(ramamount)"
    ram_amount="$(_string_remove_spaces "${ram_amount}")"

    disk_volume="$(df /boot | grep -Eo '/dev/[^ ]+')"
    disk_size="$(df -h | grep -w "${disk_volume}" | awk '{print $2}')"
    disk_usage="$(df -h | grep -w "${disk_volume}" | awk '{print $5}')"

    if [[ ${public_ip} == "${inet_ip}" ]]; then

        echo "ip: ${public_ip} | cpu-cores: ${cpu_cores} | ram-avail: ${ram_amount} | disk-size: ${disk_size} | disk-usage: ${disk_usage}"
    else

        echo "ip: ${public_ip} | floating-ip: ${inet_ip} | cpu-cores: ${cpu_cores} | ram-avail: ${ram_amount} | disk-size: ${disk_size} | disk-usage: ${disk_usage}"

    fi

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
alias cpucores='grep -c "processor" /proc/cpuinfo'
alias ramamount='grep MemTotal /proc/meminfo | cut -d ":" -f 2'