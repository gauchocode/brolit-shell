#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.25
################################################################################

source ~/.broobe-utils-options

CLF_CONFIG_FILE=~/.cloudflare.conf
if [[ ${CLOUDFLARE_ENABLE} == "true" && -f ${CLF_CONFIG_FILE} ]]; then
    # shellcheck source=${CLF_CONFIG_FILE}
    source "${CLF_CONFIG_FILE}"
fi

DPU_CONFIG_FILE=~/.dropbox_uploader
if [[ ${DROPBOX_ENABLE} == "true" && -f ${DPU_CONFIG_FILE} ]]; then
    # shellcheck source=${DPU_CONFIG_FILE}
    source "${DPU_CONFIG_FILE}"
    # Dropbox-uploader directory
    DPU_F="/root/lemp-utils-scripts/tools/third-party/dropbox-uploader"
    # Dropbox-uploader runner
    DROPBOX_UPLOADER="${DPU_F}/dropbox_uploader.sh"
    #DROPBOX_UPLOADER="${DPU_F}/dropbox_uploader_original.sh"

fi

# Version
SCRIPT_VERSION="3.0.25"
ALIASES_VERSION="3.0.25-004"

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

alias get_script_version='echo $SCRIPT_VERSION'
alias get_aliases_version='echo $ALIASES_VERSION'

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

function _php_check_installed_version() {

    local php_fpm_installed_pkg
    local php_installed_versions

    # Installed versions
    php_fpm_installed_pkg="$(sudo dpkg --list | grep -oh 'php[0-9]\.[0-9]\-fpm')"

    # Grep -oh parameters explanation:
    #
    # -h, --no-filename
    #   Suppress the prefixing of file names on output. This is the default
    #   when there is only  one  file  (or only standard input) to search.
    # -o, --only-matching
    #   Print  only  the matched (non-empty) parts of a matching line,
    #   with each such part on a separate output line.
    #
    # In this case, output example: php7.2-fpm php7.3-fpm php7.4-fpm

    # Extract only version numbers
    php_installed_versions="$(echo -n "${php_fpm_installed_pkg}" | grep -Eo '[+-]?[0-9]+([.][0-9]+)?' | tr '\n' ' ')"
    # The "tr '\n' ' '" part, will replace /n with space
    # Return example: 7.4 7.2 7.0

    # Check elements number on string
    count_elements="$(echo "${php_installed_versions}" | wc -w)"

    if [[ $count_elements == "1" ]]; then

        # Remove last space
        php_installed_versions="$(_string_remove_spaces "${php_installed_versions}")"

    fi

    # Return
    echo "${php_installed_versions}"

}

function _mysql_check_installed_version() {

    local mysql_fpm_installed_pkg
    local mysql_installed_version

    # Installed versions
    mysql_fpm_installed_pkg="$(sudo dpkg --list | grep -oh 'mysql-server-core-[0-9]\.[0-9]')"

    # Grep -oh parameters explanation:
    #
    # -h, --no-filename
    #   Suppress the prefixing of file names on output. This is the default
    #   when there is only  one  file  (or only standard input) to search.
    # -o, --only-matching
    #   Print  only  the matched (non-empty) parts of a matching line,
    #   with each such part on a separate output line.
    #
    # In this case, output example: mysql-server-core-5.7

    # Extract only version numbers
    mysql_installed_version="$(echo -n "${mysql_fpm_installed_pkg}" | grep -Eo '[+-]?[0-9]+([.][0-9]+)?' | tr '\n' ' ')"
    # The "tr '\n' ' '" part, will replace /n with space
    # Return example: 5.7

    # Remove last space
    mysql_installed_version="$(_string_remove_spaces "${mysql_installed_version}")"

    # Return
    echo "${mysql_installed_version}"

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

########################## UTILS FOR DEVOPS ###################################

# All lemp-utils config
function lemp_utils_config() {

    # Return
    echo "\"server_type\": \"${SERVER_CONFIG}\" , \"netdata_url\": \"${NETDATA_SUBDOMAIN}\" , \"mail_notif\": \"${MAIL_NOTIF}\" , \"telegram_notif\": \"${TELEGRAM_NOTIF}\" , \"dropbox_enable\": \"${DROPBOX_ENABLE}\" , \"cloudflare_enable\": \"${CLOUDFLARE_ENABLE}\" , \"smtp_server\": \"${SMTP_SERVER}\""

}

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
        echo "\"server_name\": \"${VPSNAME}\" , \"ip\": \"${public_ip}\" , \"distro\": \"${distro}\" , \"cpu_cores\": \"${cpu_cores}\" , \"ram_avail\": \"${ram_amount}\" , \"disk_size\": \"${disk_size}\" , \"disk_usage\": \"${disk_usage}\""
    else

        # Return
        echo "\"server_name\": \"${VPSNAME}\" , \"ip\": \"${public_ip}\" , \"floating_ip\": \"${inet_ip}\" , \"distro\": \"${distro}\" , \"cpu_cores\": \"${cpu_cores}\" , \"ram_avail\": \"${ram_amount}\" , \"disk_size\": \"${disk_size}\" , \"disk_usage\": \"${disk_usage}\""

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

    local backup_files

    # Get dropbox backup list
    dropbox_chosen_backup_path="${VPSNAME}/site/${chosen_project}"
    dropbox_backup_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_chosen_backup_path}")"

    for backup_file in ${dropbox_backup_list}; do

        backup_files="${backup_files} , \"${backup_file}\""

    done

    # Remove 3 last chars
    backup_files="${backup_files:3}"

    # Return JSON
    echo "{"
    echo "\"BACKUPS_RESULT\": [ ${backup_files} ],"
    echo "}"

}

function packages_get_data() {

    local php_v_installed
    local all_phpv

    php_v_installed="$(_php_check_installed_version)"

    for php_v in ${php_v_installed}; do

        all_phpv="${all_phpv} , \"${php_v}\""

    done

    mysql_v_installed="$(_mysql_check_installed_version)"

    # Remove 3 last chars
    all_phpv="${all_phpv:3}"

    # Return JSON
    echo "{ \"WEBSERVER_RESULT\": { \"nginx\" : \"1.14\" }, \"DBE_RESULT\": { \"maria-db\" : \"${mysql_v_installed}\" }, \"PHP_RESULT\": [ ${all_phpv} ] }"

}

function show_server_data() {

    local server_info
    local server_config
    local server_databases
    local server_sites
    local server_pkgs

    server_info="$(serverinfo)"
    server_config="$(lemp_utils_config)"
    server_databases="$(mysql_databases)"
    server_sites="$(sites_directories)"
    server_pkgs="$(packages_get_data)"

    # Return JSON
    echo "RESULT => { \"SERVERINFO_RESULT\": { ${server_info} }, \"PKGS_RESULT\": { ${server_pkgs} } , \"CONFIG_RESULT\": { ${server_config} }, \"MYSQLDBS_RESULT\": [ ${server_databases} ], \"SITES_RESULT\": [ ${server_sites} ] }"

}
