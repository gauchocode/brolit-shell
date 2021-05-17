#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.25
################################################################################

source ~/.broobe-utils-options

source ~/.cloudflare.conf

source ~/.dropbox_uploader

# Dropbox-uploader runner
DROPBOX_UPLOADER="/root/lemp-utils-scripts/tools/third-party/dropbox-uploader/dropbox_uploader.sh"

# Server Name
VPSNAME="$HOSTNAME"

################################################################################

alias ..="cd .."

alias userlist="cut -d: -f1 /etc/passwd"
alias myip="curl http://ipecho.net/plain; echo"

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

################################################################################

function _string_remove_spaces() {

    # Parameters
    # $1 = ${string}

    local string=$1

    # Return
    echo "${string//[[:blank:]]/}"

}

function _clear_last_line() {

    printf "\033[1A" >&2
    echo -e "${F_DEFAULT}                                                                                                         ${ENDCOLOR}" >&2
    echo -e "${F_DEFAULT}                                                                                                         ${ENDCOLOR}" >&2
    printf "\033[1A" >&2
    printf "\033[1A" >&2

}

function _cloudflare_get_zone_id() {

    # $1 = ${zone_name}

    local zone_name=$1

    local zone_id

    # Checking cloudflare credentials file
    # generate_cloudflare_config

    # Using globals: ${dns_cloudflare_email} and ${dns_cloudflare_api_key}

    # Get Zone ID
    zone_id="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" \
        -H "X-Auth-Email: ${dns_cloudflare_email}" \
        -H "X-Auth-Key: ${dns_cloudflare_api_key}" \
        -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && ${zone_id} != "" ]]; then

        # Return
        echo "${zone_id}"

    else

        # Return
        echo "Domain ${zone_name} not found"

        return 1

    fi

}

################################################################################

# Creates an archive (*.tar.gz) from given directory
function maketar() { tar cvzf "${1%%/}.tar.gz" "${1%%/}/"; }

# Create a ZIP archive of a file or folder
function makezip() { zip -r "${1%%/}.zip" "$1"; }

# Make dir and cd
function mcd() {

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

# All lemp-utils config
function lemp_utils_config() {

    # Return
    echo "server_type: ${SERVER_CONFIG} | netdata_url: ${NETDATA_SUBDOMAIN} | mail_notif: ${MAIL_NOTIF} | telegram_notif: ${TELEGRAM_NOTIF} | dropbox_enable: ${DROPBOX_ENABLE} | cloudflare_enable: ${CLOUDFLARE_ENABLE} | smtp_server: ${SMTP_SERVER}"

}

# All server info
function serverinfo() {

    local distro
    local cpu_cores
    local ram_amount
    local disk_volume
    local disk_usage
    local public_ip
    local inet_ip # configured on network file

    public_ip="$(curl --silent http://ipecho.net/plain)"
    inet_ip="$(/sbin/ifconfig eth0 | grep -w "inet" | awk '{print $2}')"

    distro="$(lsb_release -d | awk -F"\t" '{print $2}')"

    cpu_cores="$(grep -c "processor" /proc/cpuinfo)"
    ram_amount="$(grep MemTotal /proc/meminfo | cut -d ":" -f 2)"
    ram_amount="$(_string_remove_spaces "${ram_amount}")"

    disk_volume="$(df /boot | grep -Eo '/dev/[^ ]+')"
    disk_size="$(df -h | grep -w "${disk_volume}" | awk '{print $2}')"
    disk_usage="$(df -h | grep -w "${disk_volume}" | awk '{print $5}')"

    if [[ ${public_ip} == "${inet_ip}" ]]; then

        # Return
        echo "\"server_name\": ${VPSNAME} , \"ip\": ${public_ip} , \"distro\": ${distro} , \"cpu_cores\": ${cpu_cores} , \"ram_avail\": ${ram_amount} , \"disk_size\": ${disk_size} , \"disk_usage\": ${disk_usage}"
    else

        # Return
        echo "\"server_name\": ${VPSNAME} , \"ip\": ${public_ip} , \"floating_ip\": ${inet_ip} , \"distro\": ${distro} , \"cpu_cores\": ${cpu_cores} , \"ram_avail\": ${ram_amount} , \"disk_size\": ${disk_size} , \"disk_usage\": ${disk_usage}"

    fi

}

function mysql_databases() {

    local database
    local databases
    local all_databases

    # Database blacklist
    local database_bl="information_schema,performance_schema,mysql,sys,phpmyadmin"

    # Run command
    all_databases="$(mysql -Bse 'show databases')"

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 && ${all_databases} != "error" ]]; then

        for database in ${all_databases}; do
            if [[ ${database_bl} != *"${database}"* ]]; then
                databases="${databases} , \"${database}\""
            fi
        done

        # Remove 3 last chars
        databases="${databases:3}"

        # Return
        echo "${databases}"

    else

        # Log
        echo "Something went wrong listing MySQL databases!"

        return 1

    fi

}

function sites_directories() {

    local directories
    local all_directories

    # Run command
    all_directories="$(ls /var/www)"

    for site in ${all_directories}; do

        directories="${directories} , \"${site}\""

    done

    # Remove 3 last chars
    directories="${directories:3}"

    # Return
    echo "${directories}"

}

function cloudflare_domain_exists() {

    # $1 = ${root_domain}

    local root_domain=$1

    local zone_name
    local zone_id

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && ${zone_id} != "" ]]; then

        # Return
        echo "true"

    else

        # Return
        echo "false"
    fi

}

function dropbox_get_backup() {

    # ${1} = ${chosen_project}

    local chosen_project=$1

    local dropbox_chosen_backup_path
    local dropbox_backup_list

    # Get dropbox backup list
    dropbox_chosen_backup_path="${VPSNAME}/site/${chosen_project}"
    dropbox_backup_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_chosen_backup_path}")"

    # Return
    echo "${dropbox_backup_list}"

}

function show_server_data() {

    local server_info
    local server_config
    local server_databases

    server_info="$(serverinfo)"
    server_config="$(lemp_utils_config)"
    server_databases="$(mysql_databases)"
    server_sites="$(sites_directories)"

    # Run commands
    echo "{"
    echo "\"SERVERINFO_RESULT\": { ${server_info} },"
    echo "\"CONFIG_RESULT\": { ${server_config} },"
    echo "\"MYSQLDBS_RESULT\": { ${server_databases} },"
    echo "\"SITES_RESULT\": { ${server_sites} },"
    echo "}"

}
