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
ALIASES_VERSION="3.0.25-022"

# Server Name
VPSNAME="$HOSTNAME"

SFOLDER="/root/lemp-utils-scripts"

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

    local mysql_installed_pkg
    local mysql_installed_version

    # MySQL or MariaDB?
    mysql_installed_pkg="$(sudo dpkg --list | grep -Eo 'mysql-client-[0-9]+([.][0-9]+)?')"
    if [[ ${mysql_installed_pkg} == "" ]]; then

        mysql_installed_pkg="$(sudo dpkg --list | grep -Eo 'mariadb-client-[0-9]+([.][0-9]+)?')"

    fi

    # Installed versions

    # Extract only version numbers
    mysql_installed_version="$(mysql -V | awk -F' ' '{print $3}' | grep -o '[0-9.]*$' | tr '\n' ' ')"

    # Remove last space
    mysql_installed_version="$(_string_remove_spaces "${mysql_installed_version}")"

    # Return
    echo "{\"name\":\"${mysql_installed_pkg}\",\"version\":\"${mysql_installed_version}\",\"default\":\"true\"}"

}

function _nginx_check_installed_version() {

    local nginx_installed_version

    # Check if package is installed
    nginx_installed_pkg="$(sudo dpkg --list | grep -Eo 'nginx-core')"
    if [[ ${nginx_installed_pkg} != "" ]]; then

        # Installed versions
        nginxv="$(nginx -v 2>&1)"
        nginxv="$(_string_remove_spaces "${nginxv}")"
        nginx_installed_version="$(echo "${nginxv}" | cut -d "(" -f 1 | grep -o '[0-9.]*$')"

        if [[ ${nginx_installed_version} != "" ]]; then
            # Return
            echo "{\"name\":\"nginx\",\"version\":\"${nginx_installed_version}\",\"default\":\"true\"}"
        fi

    fi

}

function _apache_check_installed_version() {

    local apache_installed_version

    # Check if package is installed
    apache2_installed_pkg="$(sudo dpkg --list | grep -Eo 'apache2-bin')"
    if [[ ${apache2_installed_pkg} != "" ]]; then

        # Installed versions
        apache_installed_version="$(apache2 -v | awk -F' ' '{print $3}' | grep -o '[0-9.]*$' | tr '\n' ' ' | cut -d " " -f 1)"

        if [[ ${apache_installed_version} != "" ]]; then
            # Return
            echo "{\"name\":\"apache2\",\"version\":\"${apache_installed_version}\",\"default\":\"true\"}"
        fi

    fi

}

function _get_backup_date() {

    local backup_file=$1

    local backup_date

    backup_date="$(echo "${backup_file}" | grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}')"

    # Return
    echo "${backup_date}"

}

function _get_domain_extension() {

    # Parameters
    # $1 = ${domain}

    local domain=$1

    local first_lvl
    local next_lvl
    local domain_ext

    # Get first_lvl domain name
    first_lvl="$(cut -d'.' -f1 <<<"${domain}")"

    # Extract first_lvl
    domain_ext=${domain#"$first_lvl."}

    next_lvl="${first_lvl}"

    local -i count=0
    while ! grep --word-regexp --quiet ".${domain_ext}" "${SFOLDER}/config/domain_extension-list" && [ ! "${domain_ext#"$next_lvl"}" = "" ]; do

        # Remove next level domain-name
        domain_ext=${domain_ext#"$next_lvl."}
        next_lvl="$(cut -d'.' -f1 <<<"${domain_ext}")"

        count=("$count"+1)

    done

    if grep --word-regexp --quiet ".${domain_ext}" "${SFOLDER}/config/domain_extension-list"; then

        domain_ext=.${domain_ext}

        # Return
        echo "${domain_ext}"

    else

        return 1

    fi

}

function _get_subdomain_part() {

    # Parameters
    # $1 = ${domain}

    local domain=$1

    local domain_extension
    local domain_no_ext
    local subdomain_part

    # Get Domain Ext
    domain_extension="$(_get_domain_extension "${domain}")"

    # Check result
    domain_extension_output=$?
    if [[ ${domain_extension_output} -eq 0 ]]; then

        # Remove domain extension
        domain_no_ext=${domain%"$domain_extension"}

        root_domain=${domain_no_ext##*.}${domain_extension}

        if [[ ${root_domain} != "${domain}" ]]; then

            subdomain_part=${domain//.$root_domain/}

            # Return
            echo "${subdomain_part}"

        else

            # Return
            echo ""

        fi

    else

        return 1

    fi

}

function _get_root_domain() {

    # Parameters
    # $1 = ${domain}

    local domain=$1

    local domain_extension
    local domain_no_ext

    # Get Domain Ext
    domain_extension="$(_get_domain_extension "${domain}")"

    # Check result
    domain_extension_output=$?
    if [[ ${domain_extension_output} -eq 0 ]]; then

        # Remove domain extension
        domain_no_ext=${domain%"$domain_extension"}

        root_domain=${domain_no_ext##*.}${domain_extension}

        # Return
        echo "${root_domain}"

    else

        return 1

    fi

}

function _extract_domain_extension() {

    # Parameters
    # $1 = ${domain}

    local domain=$1

    local domain_extension
    local domain_no_ext

    domain_extension="$(_get_domain_extension "${domain}")"
    domain_extension_output=$?
    if [[ ${domain_extension_output} -eq 0 ]]; then

        domain_no_ext=${domain%"$domain_extension"}

        # Return
        echo "${domain_no_ext}"

    else

        return 1

    fi

}

function _get_project_name_from_domain() {

    # Parameters
    # $1 = ${project_domain}

    local project_domain=$1

    # Trying to extract project name from domain
    root_domain="$(_get_root_domain "${project_domain}")"
    possible_project_name="$(_extract_domain_extension "${root_domain}")"

    # Replace '-' and '.' chars
    possible_name="$(echo "${possible_project_name}" | sed -r 's/[.-]+/_/g')"

    # Return
    echo "${possible_name}"

}

function _get_project_state_from_domain() {

    # Parameters
    # $1 = ${project_domain}

    local project_domain=$1

    project_states="dev,test,stage"

    # Trying to extract project state from domain
    possible_project_state="$(_get_subdomain_part "${project_domain}" | cut -d "." -f 1)"

    if [[ ${possible_project_state} != *"${project_states}"* ]]; then

        possible_project_state="prod"

    fi

    # Return
    echo "${possible_project_state}"

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

    # Return JSON part
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

        # Return JSON part
        echo "\"server_name\": \"${VPSNAME}\" , \"ip\": \"${public_ip}\" , \"distro\": \"${distro}\" , \"cpu_cores\": \"${cpu_cores}\" , \"ram_avail\": \"${ram_amount}\" , \"disk_size\": \"${disk_size}\" , \"disk_usage\": \"${disk_usage}\""
    else

        # Return JSON part
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
                databases="\"${database}\" , ${databases}"
            fi
        done

        # Remove 3 last chars
        databases="${databases::3}"

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

function dropbox_get_sites_backups() {

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

    # Return
    echo "${backup_files}"

}

# TODO: {"2020-05-19":{"files":"ZZZZZ1","database":"YYYY1"},"2020-05-20":{"files":"ZZZZZ2","database":"YYYY2"}}
function dropbox_get_backup() {

    # ${1} = ${chosen_project}

    local project_domain=$1

    local project_name

    local dropbox_site_backup_path
    #local dropbox_db_backup_path
    local dropbox_site_backup_list
    #local dropbox_db_backup_list

    #local backup_files
    local backup_db
    local backup_date

    if [[ ${project_domain} == "" ]]; then
        exit 1
    fi

    project_name="$(_get_project_name_from_domain "${project_domain}")"
    project_state="$(_get_project_state_from_domain "${project_domain}")"

    # Get dropbox backup list
    dropbox_site_backup_path="${VPSNAME}/site/${project_domain}"
    dropbox_site_backup_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_site_backup_path}")"

    for backup_file in ${dropbox_site_backup_list}; do

        backup_date="$(_get_backup_date "${backup_file}")"

        backup_to_search="${project_name}_${project_state}_database_${backup_date}.tar.bz2"

        search_backup_db="$("${DROPBOX_UPLOADER}" -hq search "${backup_to_search}" | grep -E "${backup_date}")"

        #echo "command executed: ${DROPBOX_UPLOADER} -hq search ${backup_to_search} | grep -E ${backup_date}"

        backup_db="$(basename "${search_backup_db}")"

        if [[ ${search_backup_db} != "" ]]; then
            backups_string="${backups_string} {\"$backup_date\":{\"files\":\"${backup_file}\",\"database\":\"${backup_db}\"},"
        else
            backups_string="${backups_string} {\"$backup_date\":{\"files\":\"${backup_file}\",\"database\":\"false\"},"
        fi

    done

    # Return JSON part
    echo "{"
    echo "\"backups\": ${backups_string}"
    echo "}"

}

# JSON FORMAT:
#
# {
#  "webservers":[
#    {"name":"nginx","version":"1.0","default":"true"},
#    {"name":"nginx","version":"2.0","default":"false"},
#    {"name":"apache","version":"2.0","default":"false"}
#   ],
# "databases":[
#    {"name":"mysql","version":"1.0","default":"true"},
#    {"name":"mariadb","version":"2.0","default":"false"}
#   ],
# "languages":[
#    {"name":"php","version":"7.4","default":"true"},
#    {"name":"php","version":"7.3","default":"false"}
#    ]
# }

function packages_get_data() {

    local php_v_installed
    local all_php_data
    local php_default

    # webserver
    apache_v_installed="$(_apache_check_installed_version)"
    nginx_v_installed="$(_nginx_check_installed_version)"

    # databases
    mysql_v_installed="$(_mysql_check_installed_version)"

    # languages
    php_v_installed="$(_php_check_installed_version)"

    for php_v in ${php_v_installed}; do

        # Default versions
        php_default_version="$(php -v | grep -Eo 'PHP [0-9.].[0-9.]' | cut -d " " -f 2)"

        if [[ ${php_default_version} == "${php_v}" ]]; then
            php_default=true
        else
            php_default=false
        fi

        phpv_data="{\"name\":\"php\",\"version\":\"${php_v}\",\"default\":\"${php_default}\"},"
        all_php_data="\"${phpv_data}\" , ${all_php_data}"

    done

    # Remove 3 last chars
    all_php_data="${all_php_data::3}"

    # Return JSON part
    echo "\"webservers\":[ \"${nginx_v_installed}\", \"${apache_v_installed}\" ], \"databases\": [ \"${mysql_v_installed}\" ], \"languages\": [ ${all_php_data} ]"

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
    echo "SERVER_DATA_RESULT => { \"server_info \": { ${server_info} }, \"server_pkgs\": { ${server_pkgs} } , \"server_config\": { ${server_config} }, \"databases\": [ ${server_databases} ], \"sites\": [ ${server_sites} ] }"

}
