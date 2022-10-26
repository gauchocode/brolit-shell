#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.5
################################################################################

# Version
SCRIPT_VERSION="3.2.5"
ALIASES_VERSION="3.2.5-099"

################################################################################

alias ..="cd .."

alias servername="echo ${HOSTNAME}"

alias userlist="cut -d: -f1 /etc/passwd"
alias myip="curl http://ipecho.net/plain; echo"
alias myipv6="curl --silent 'https://api64.ipify.org'"

alias ports='netstat -tulanp'

alias path='echo -e ${PATH//:/\\n}'

alias now="echo It\'s now $(date +%T)"

## Colorize the grep command output for ease of use (good for log files)
alias grep='grep --color=auto'

alias lt='ls --human-readable --size -1 -S --classify'
alias lss='du -h --max-depth=1'

alias cpv='rsync -ah --info=progress2'

## Get top process eating memory
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias psmem20='ps auxf | sort -nr -k 4 | head -20'

## Get top process eating cpu
alias pscpu='ps auxf | sort -nr -k 3'
alias pscpu10='ps auxf | sort -nr -k 3 | head -10'
alias pscpu20='ps auxf | sort -nr -k 3 | head -20'

alias atop='atop -a 1'

## Get cpu info
alias cpuinfo='lscpu'
alias cpucores='grep -c "processor" /proc/cpuinfo'
alias ramamount='grep MemTotal /proc/meminfo | cut -d ":" -f 2'

alias get_script_version='echo $SCRIPT_VERSION'
alias get_aliases_version='echo $ALIASES_VERSION'

################################################################################

# Creates an archive (*.tar.gz) from given directory
function maketar() { tar cvzf "${1%%/}.tar.gz" "${1%%/}/"; }

# Create a ZIP archive of a file or folder
function makezip() { zip -r "${1%%/}.zip" "$1"; }

function extract() {

    local file_path="${1}"
    local directory_to_extract="${2}"
    local compress_type="${3}"

    # Get filename and file extension
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
            #tar -xzvf "${file_path}" -C "${directory_to_extract}"
            pv --width 70 "${file_path}" | tar xzvf -C "${directory_to_extract}"
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
            #gunzip "${file_path}" -C "${directory_to_extract}"
            pv --width 70 "${file_path}" | gunzip -C "${directory_to_extract}"
            ;;

        *.tar)
            #tar xf "${file_path}"
            pv --width 70 "${file_path}" | tar xf
            ;;

        *.tbz2)
            #tar xjf "${file_path}" -C "${directory_to_extract}"
            pv --width 70 "${file_path}" | tar xjf -C "${directory_to_extract}"
            ;;

        *.tgz)
            #tar xzf "${file_path}" -C "${directory_to_extract}"
            pv --width 70 "${file_path}" | tar xzf -C "${directory_to_extract}"
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
            #tar xvf "${file_path}" -C "${directory}"
            pv --width 70 "${file_path}" | tar xvf -C "${directory_to_extract}"
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
