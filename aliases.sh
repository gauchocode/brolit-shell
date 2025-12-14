#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.4
################################################################################

# Version
SCRIPT_VERSION="3.4"
ALIASES_VERSION="3.4-100"

################################################################################
# NAVIGATION ALIASES
################################################################################

alias ..="cd .."

################################################################################
# SYSTEM INFORMATION ALIASES
################################################################################

alias servername="echo ${HOSTNAME}"
alias path='echo -e ${PATH//:/\\n}'
alias now="echo It\'s now $(date +%T)"
alias get_script_version='echo $SCRIPT_VERSION'
alias get_aliases_version='echo $ALIASES_VERSION'

## CPU and Memory info
alias cpuinfo='lscpu'
alias cpucores='grep -c "processor" /proc/cpuinfo'
alias ramamount='grep MemTotal /proc/meminfo | cut -d ":" -f 2'
alias meminfo='free -m -l -t'
alias memtop='watch -n 1 free -m'

################################################################################
# PROCESS MANAGEMENT ALIASES
################################################################################

## Top processes eating memory
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias psmem20='ps auxf | sort -nr -k 4 | head -20'

## Top processes eating cpu
alias pscpu='ps auxf | sort -nr -k 3'
alias pscpu10='ps auxf | sort -nr -k 3 | head -10'
alias pscpu20='ps auxf | sort -nr -k 3 | head -20'

alias atop='atop -a 1'

################################################################################
# FILE AND DIRECTORY ALIASES
################################################################################

## File listing
alias lt='ls --human-readable --size -1 -S --classify'

## Disk usage
alias lss='du -h --max-depth=1'
alias diskspace='du -h --max-depth=1 | sort -hr'
alias diskspace10='du -h --max-depth=1 | sort -hr | head -11'
alias fsize='du -sh'

## File operations
alias cpv='rsync -ah --info=progress2'

## Colorize grep output
alias grep='grep --color=auto'

################################################################################
# NETWORK ALIASES
################################################################################

alias userlist="cut -d: -f1 /etc/passwd"
alias myip="curl http://ipecho.net/plain; echo"
alias myipv6="curl --silent 'https://api64.ipify.org'"
alias ports='netstat -tulanp'
alias listening='netstat -tulanp | grep LISTEN'
alias openports='ss -tulanp'

################################################################################
# GIT ALIASES
################################################################################

alias gitlog='git log --oneline --graph --decorate --all'
alias gitstatus='git status -sb'
alias gitdiff='git diff --color-words'

################################################################################
# SYSTEM UPDATE ALIASES
################################################################################

## Auto-detect package manager (apt/dnf)
alias update='if command -v apt &> /dev/null; then sudo apt update; elif command -v dnf &> /dev/null; then sudo dnf check-update; fi'
alias upgrade='if command -v apt &> /dev/null; then sudo apt upgrade -y; elif command -v dnf &> /dev/null; then sudo dnf upgrade -y; fi'

################################################################################
# DOCKER ALIASES
################################################################################

alias dps='docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dpsa='docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dimg='docker images'
alias dlog='docker logs -f'
alias dexec='docker exec -it'

################################################################################
# SYSTEMD ALIASES
################################################################################

alias sysstat='sudo systemctl status'
alias sysstart='sudo systemctl start'
alias sysstop='sudo systemctl stop'
alias sysrestart='sudo systemctl restart'
alias sysenable='sudo systemctl enable'
alias sysdisable='sudo systemctl disable'

################################################################################
# CUSTOM FUNCTIONS
################################################################################

# Creates an archive (*.tar.gz) from given directory
function maketar() {
    if [[ -z "$1" ]]; then
        echo "Usage: maketar <directory>"
        return 1
    fi
    if [[ ! -d "$1" ]]; then
        echo "Error: $1 is not a directory"
        return 1
    fi
    tar cvzf "${1%%/}.tar.gz" "${1%%/}/"
}

# Create a ZIP archive of a file or folder
function makezip() {
    if [[ -z "$1" ]]; then
        echo "Usage: makezip <file_or_directory>"
        return 1
    fi
    if [[ ! -e "$1" ]]; then
        echo "Error: $1 does not exist"
        return 1
    fi
    zip -r "${1%%/}.zip" "$1"
}

# Create a backup of a file or directory with timestamp
function backup() {
    if [[ -z "$1" ]]; then
        echo "Usage: backup <file_or_directory>"
        return 1
    fi
    if [[ ! -e "$1" ]]; then
        echo "Error: $1 does not exist"
        return 1
    fi
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="${1%%/}_backup_${timestamp}"
    cp -r "$1" "${backup_name}"
    echo "Backup created: ${backup_name}"
}

function extract() {

    local file_path="${1}"
    local directory_to_extract="${2}"
    local compress_type="${3}"

    # Validate parameters
    if [[ -z "${file_path}" ]]; then
        echo "Usage: extract <file> [destination_directory] [compress_type]"
        return 1
    fi

    if [[ ! -f "${file_path}" ]]; then
        echo "Error: ${file_path} is not a valid file"
        return 1
    fi

    # Set default destination directory if not provided
    if [[ -z "${directory_to_extract}" ]]; then
        directory_to_extract="."
    fi

    # Create destination directory if it doesn't exist
    if [[ ! -d "${directory_to_extract}" ]]; then
        mkdir -p "${directory_to_extract}"
    fi

    # Get filename and file extension
    local filename
    filename=$(basename -- "${file_path}")
    #file_extension="${filename##*.}"
    filename="${filename%.*}"

    # Log
    echo "Extracting compressed file: ${file_path}"

    if [[ -f "${file_path}" ]]; then

        case "${file_path}" in

        *.tar.bz2)
            if [[ -n "${compress_type}" ]]; then
                #tar xp "${file_path}" -C "${directory_to_extract}" --use-compress-program="${compress_type}"
                pv --width 70 "${file_path}" | tar xp -C "${directory_to_extract}" --use-compress-program="${compress_type}"
            else
                #tar xjf "${file_path}" -C "${directory_to_extract}"
                pv --width 70 "${file_path}" | tar xp -C "${directory_to_extract}"
            fi
            ;;

        *.tar.gz)
            pigz -dc "${file_path}" | pv --width 70 | tar xf - -C "${directory_to_extract}"
            ;;

        *.bz2)
            #bunzip2 "${file_path}" "${directory_to_extract}"
            pv --width 70 "${file_path}" | bunzip2 >"${directory_to_extract}/${filename}"
            ;;

        *.rar)
            #unrar x "${file_path}" "${directory_to_extract}"
            unrar x "${file_path}" "${directory_to_extract}" | pv -l >/dev/null
            ;;

        *.gz)
            #gunzip "${file_path}" > "${directory_to_extract}/${filename}"
            pv --width 70 "${file_path}" | gunzip >"${directory_to_extract}/${filename}"
            ;;

        *.tar)
            #tar xf "${file_path}" -C "${directory_to_extract}"
            pv --width 70 "${file_path}" | tar xf - -C "${directory_to_extract}"
            ;;

        *.tbz2)
            #tar xjf "${file_path}" -C "${directory_to_extract}"
            pv --width 70 "${file_path}" | tar xjf - -C "${directory_to_extract}"
            ;;

        *.tgz)
            #tar xzf "${file_path}" -C "${directory_to_extract}"
            pv --width 70 "${file_path}" | tar xzf - -C "${directory_to_extract}"
            ;;

        *.zip)
            #unzip "${file_path}" "${directory}"
            unzip -o "${file_path}" -d "${directory_to_extract}" | pv -l >/dev/null
            ;;

        *.Z)
            #uncompress "${file_path}" "${directory}"
            pv --width 70 "${file_path}" | uncompress "${directory_to_extract}"
            ;;

        *.xz)
            #tar xvf "${file_path}" -C "${directory_to_extract}"
            pv --width 70 "${file_path}" | tar xvf - -C "${directory_to_extract}"
            ;;

        *)
            echo "${file_path} cannot be extracted via extract()"
            return 1
            ;;

        esac

    else

        echo "${file_path} is not a valid file"
        return 1

    fi

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        echo "${file_path} extracted in ${directory_to_extract}"

    else

        echo "Error extracting ${file_path} in ${directory_to_extract}"

        return 1

    fi

}

# Search with grep
function search() {

    local path="${1}"
    local string="${2}"

    # grep parameters:
    # -r or -R is recursive,
    # -n is line number, and
    # -w stands for match the whole word.
    # -l (lower-case L) can be added to just give the file name of matching files.
    grep -rnw "${path}" -e "${string}"
}
