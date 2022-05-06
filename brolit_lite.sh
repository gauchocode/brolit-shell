#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc4
################################################################################

# Var declarations

## Server Name
declare -g SERVER_NAME="${HOSTNAME}"

## Dirs
declare -g BROLIT_MAIN_DIR="/root/brolit-shell"
declare -g BROLIT_PROJECT_CONFIG_PATH="/etc/brolit"

#declare -g BROLIT_TMP_DIR="/root/brolit-shell/tmp"
declare -g BROLIT_LITE_OUTPUT_DIR="/root/brolit-shell/tmp/lite-output"
if [[ ! -d ${BROLIT_LITE_OUTPUT_DIR} ]]; then
    mkdir -p "${BROLIT_LITE_OUTPUT_DIR}"
fi

# Cloudflare
declare -g CLF_CONFIG_FILE=~/.cloudflare.conf
if [[ -f ${CLF_CONFIG_FILE} ]]; then
    # shellcheck source=~/.cloudflare.conf
    source "${CLF_CONFIG_FILE}"
    # Declare new global vars from cloudflare config file
    declare -g SUPPORT_CLOUDFLARE_EMAIL="${dns_cloudflare_email}"
    declare -g SUPPORT_CLOUDFLARE_API_KEY="${dns_cloudflare_api_key}"
fi

DPU_CONFIG_FILE=~/.dropbox_uploader
if [[ -f ${DPU_CONFIG_FILE} ]]; then
    # shellcheck source=~/.dropbox_uploader
    source "${DPU_CONFIG_FILE}"
    # Dropbox-uploader directory
    DPU_F="${BROLIT_MAIN_DIR}/tools/third-party/dropbox-uploader"
    # Dropbox-uploader runner
    DROPBOX_UPLOADER="${DPU_F}/dropbox_uploader.sh"

fi

# Version
BROLIT_VERSION="3.2-rc4"
BROLIT_LITE_VERSION="3.2-rc4-099"

################################################################################

### HELPERS

################################################################################

################################################################################
# Private: Read field from json file
#
# Arguments:
#  $1 = ${json_file}
#  $2 = ${json_field}
#
# Outputs:
#   0 if monit were installed, 1 on error.
################################################################################

function _json_read_field() {

    local json_file="${1}"
    local json_field="${2}"

    local json_field_value

    json_field_value="$(cat "${json_file}" | jq -r ".${json_field}")"

    # Return
    echo "${json_field_value}"

}

################################################################################
# Private: Write field to json file
#
# Arguments:
#  $1 = ${json_file}
#  $2 = ${json_field}}
#  $3 = ${json_field_value}
#
# Outputs:
#   0 if monit were installed, 1 on error.
################################################################################

function _json_write_field() {

    local json_file="${1}"
    local json_field="${2}"
    local json_field_value="${3}"

    json_field_value="$(jq ".${json_field} = \"${json_field_value}\"" "${json_file}")" && echo "${json_field_value}" >"${json_file}"

    exitstatus=$?
    if [[ "${exitstatus}" -eq 0 ]]; then

        return 0

    else

        log_event "error" "Getting value from ${json_field}" "false"
        return 1

    fi

}

################################################################################
# Private: Transfor output to json
#
# Arguments:
#  $1 = ${mode}
#
# Outputs:
#   0 if monit were installed, 1 on error.
################################################################################

function _jsonify_output() {

    local mode="${1}"

    # Remove fir parameter
    shift

    # Mode "key-value" example:
    # > echo "key1 value1 key2 value2"
    # {'key1': value1, 'key2': value2}

    if [[ ${mode} == "key-value" ]]; then

        arr=()

        while [ $# -ge 1 ]; do
            arr=("${arr[@]}" "${1}")
            shift
        done

        vars=(${arr[@]})
        len=${#arr[@]}

        printf "{"
        for ((i = 0; i < len; i += 2)); do
            printf "\"${vars[i]}\": \"${vars[i + 1]}\""
            if [ $i -lt $((len - 2)) ]; then
                printf ", "
            fi
        done
        printf "}"
        echo

    else

        # Mode "value-list" example:
        # > echo "value1 value2 value3 value4"
        # [ "value1" "value2" "value3" "value4" ]

        arr=()

        while [ $# -ge 1 ]; do
            arr=("${arr[@]}" "${1}")
            shift
        done

        vars=(${arr[@]})
        len=${#arr[@]}

        printf "["
        for ((i = 0; i < len; i += 1)); do
            printf "\"${vars[i]}\""
            if [ $i -lt $((len - 1)) ]; then
                printf ", "
            fi
        done
        printf "]"
        echo

    fi

}

################################################################################
# Private: Remove spaces from string
#
# Arguments:
#  $1 = ${string}
#
# Outputs:
#   0 if monit were installed, 1 on error.
################################################################################

function _string_remove_spaces() {

    local string="${1}"

    # Return
    echo "${string//[[:blank:]]/}"

}

################################################################################
# Private: Get Domain zone id from cloudflare
#
# Arguments:
#  $1 = ${zone_name}
#
# Outputs:
#   0 if monit were installed, 1 on error.
################################################################################

function _cloudflare_get_zone_id() {

    local zone_name="${1}"

    local zone_id

    # Using globals: ${SUPPORT_CLOUDFLARE_EMAIL} and ${SUPPORT_CLOUDFLARE_API_KEY}

    # Get Zone ID
    zone_id="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${zone_name}" \
        -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
        -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
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
# Private: Check if package is installed
#
# Arguments:
#  $1 = ${package}
#
# Outputs:
#   0 if monit were installed, 1 on error.
################################################################################

function _is_pkg_installed() {

    local package="${1}"

    if [ "$(dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -c "ok installed")" == "1" ]; then

        # Return
        echo "true"

    else

        # Return
        echo "false"

    fi

}

################################################################################
# Private: Check php installed version
#
# Arguments:
#  none
#
# Outputs:
#   0 if monit were installed, 1 on error.
################################################################################

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
    php_installed_versions="$(echo -n "${php_fpm_installed_pkg}" | grep -Eo '[+-]?[0-9]+([.][0-9]+)?')"
    # The "tr '\n' ' '" part, will replace /n with space
    # Return example: 7.4 7.2 7.0

    # Check elements number on string
    #count_elements="$(echo "${php_installed_versions}" | wc -w)"

    #if [[ $count_elements != "0" ]]; then
    #
    #    # Remove last space
    #    php_installed_versions="$(_string_remove_spaces "${php_installed_versions}")"
    #
    #fi

    for php_v in ${php_installed_versions}; do

        # Default versions
        php_default_version="$(php -v | grep -Eo 'PHP [0-9.].[0-9.]' | cut -d " " -f 2)"

        if [[ ${php_default_version} == "${php_v}" ]]; then
            php_default=true
        else
            php_default=false
        fi

        phpv_data="{\"name\":\"php\",\"version\":\"${php_v}\",\"default\":\"${php_default}\"}"
        all_php_data="${all_php_data} , ${phpv_data}"

    done

    # Remove 3 fist chars
    all_php_data="${all_php_data:3}"

    # Return
    echo "${all_php_data}"

}

################################################################################
# Private: Check mysql installed version
#
# Arguments:
#  none
#
# Outputs:
#   0 if monit were installed, 1 on error.
################################################################################

function _mysql_check_installed_version() {

    local mysql_installed_pkg
    local mysql_installed_version

    # MySQL or MariaDB?
    mysql_installed_pkg="$(sudo dpkg --list | grep -Eo 'mysql-server-[0-9]+([.][0-9]+)?')"

    if [[ ${mysql_installed_pkg} != "" ]]; then

        # Extract only version numbers
        mysql_installed_version="$(mysql -V | awk -F' ' '{print $3}' | grep -o '[0-9.]*$' | tr '\n' ' ')"

    else

        mysql_installed_pkg="$(sudo dpkg --list | grep -Eo 'mariadb-server-[0-9]+([.][0-9]+)?')"

        if [[ ${mysql_installed_pkg} != "" ]]; then

            # Extract only version numbers
            mysql_installed_version="$(mysql -V | grep -Eo '[+-]?[0-9]+([.][0-9]+)+([.][0-9]+)?-MariaDB' | cut -d "-" -f 1)"

        fi

    fi

    # Return
    echo "{\"name\":\"${mysql_installed_pkg}\",\"version\":\"${mysql_installed_version}\",\"default\":\"true\"}"

}

################################################################################
# Private: Check nginx installed version
#
# Arguments:
#  none
#
# Outputs:
#   0 if monit were installed, 1 on error.
################################################################################

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
            echo "{\"name\":\"nginx\",\"version\":\"${nginx_installed_version}\",\"default\":\"true\"} , "
        fi

    fi

}

################################################################################
# Private: Check apache installed version
#
# Arguments:
#  none
#
# Outputs:
#   0 if monit were installed, 1 on error.
################################################################################

function _apache_check_installed_version() {

    local apache_installed_version

    # Check if package is installed
    apache2_installed_pkg="$(sudo dpkg --list | grep -Eo 'apache2-bin')"
    if [[ ${apache2_installed_pkg} != "" ]]; then

        # Installed versions
        apache_installed_version="$(apache2 -v | awk -F' ' '{print $3}' | grep -o '[0-9.]*$' | tr '\n' ' ' | cut -d " " -f 1)"

        if [[ ${apache_installed_version} != "" ]]; then
            # Return
            echo "{\"name\":\"apache2\",\"version\":\"${apache_installed_version}\",\"default\":\"true\"} , "
        fi

    fi

}

function _backup_get_date() {

    local backup_file="${1}"

    local backup_date

    backup_date="$(echo "${backup_file}" | grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}')"

    # Return
    echo "${backup_date}"

}

function _certbot_certificate_get_valid_days() {
    # $1 = domains (domain.com,www.domain.com)

    local domain="${1}"

    local cert_days

    cert_days_output="$(certbot certificates --domain "${domain}" 2>&1)"
    cert_days="$(echo "${cert_days_output}" | grep -Eo 'VALID: [0-9]+[0-9]' | cut -d ' ' -f 2)"

    if [[ ${cert_days} == "" ]]; then

        # Return
        echo "no-cert"

    else

        # Return
        echo "${cert_days}"

    fi

}

function _cloudflare_domain_exists() {

    # $1 = ${root_domain}

    local root_domain="${1}"

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

function _cloudflare_record_exists() {

    # $1 = ${domain}
    # $2 = ${zone_id}

    local domain="${1}"
    local zone_id="${2}"

    # Only for better readibility
    record_name="${domain}"

    # Retrieve record_id
    record_id="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${record_name}" -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*')"

    exitstatus=$?
    if [[ ${record_id} == "" ]]; then

        return 1

    else

        # Clean output
        record_id="$(echo "${record_id}" | tr -d '\n')"

        # Return
        echo "${record_id}"

    fi

}

function _get_domain_extension() {

    # Parameters
    # $1 = ${domain}

    local domain="${1}"

    local first_lvl
    local next_lvl
    local domain_ext

    # Get first_lvl domain name
    first_lvl="$(cut -d'.' -f1 <<<"${domain}")"

    # Extract first_lvl
    domain_ext=${domain#"$first_lvl."}

    next_lvl="${first_lvl}"

    local -i count=0
    while ! grep --word-regexp --quiet ".${domain_ext}" "${BROLIT_MAIN_DIR}/config/domain_extension-list" && [ ! "${domain_ext#"$next_lvl"}" = "" ]; do

        # Remove next level domain-name
        domain_ext=${domain_ext#"$next_lvl."}
        next_lvl="$(cut -d'.' -f1 <<<"${domain_ext}")"

        count=("$count"+1)

    done

    if grep --word-regexp --quiet ".${domain_ext}" "${BROLIT_MAIN_DIR}/config/domain_extension-list"; then

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

    local domain="${1}"

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

    local domain="${1}"

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

    local domain="${1}"

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

function _wp_config_path() {

    local dir_to_search="${1}"

    # Find where wp-config.php is
    find_output="$(find "${dir_to_search}" -name "wp-config.php" | sed 's|/[^/]*$||')"

    # Check if directory exists
    if [[ -d ${find_output} ]]; then

        # Return
        echo "${find_output}"

        return 0

    else

        return 1

    fi

}

################################################################################
# Private: Get project type
#
# Arguments:
#   $1 = ${dir_path}
#
# Outputs:
#   ${project_type}
################################################################################

function _project_get_type() {

    local dir_path="${1}"

    #local project_type

    # TODO: if brolit_conf exists, should check this file and get project type

    if [[ -n ${dir_path} ]]; then

        # WP?
        wp_path="$(_wp_config_path "${dir_path}")"
        if [[ -n ${wp_path} ]]; then

            # Return
            echo "wordpress"

            return 0

        fi

        # Laravel?
        laravel_v="$(php "${dir_path}/artisan" --version | grep -oE "Laravel Framework [0-9]+\.[0-9]+\.[0-9]+")"
        if [[ -n ${laravel_v} ]]; then

            # Return
            echo "laravel"

            return 0

        fi

        # other-php?
        php="$(find "${dir_path}" -name "index.php" -type f)"
        if [[ -n ${php} ]]; then

            # Return
            echo "php"

            return 0

        fi

        # Node.js?
        nodejs="$(find "${dir_path}" -name "package.json" -type f)"
        if [[ -n ${nodejs} ]]; then

            # Return
            echo "nodejs"

            return 0

        fi

        # html-only?
        html="$(find "${dir_path}" -name "index.html" -type f)"
        if [[ -n ${html} ]]; then

            # Return
            echo "html"

            return 0

        fi

        # docker-compose?
        docker="$(
            find "${dir_path}" -name "docker-compose.yml" -type f
            find "${dir_path}" -name "docker-compose.yaml" -type f
        )"
        if [[ -n ${docker} ]]; then

            # Return
            echo "docker-compose"

            return 0

        fi

        # Unknown

        # Return
        echo "unknown"

        return 0

    else

        return 1

    fi

}

################################################################################
# Private: Get project name from domain
#
# Arguments:
#   $1 = ${project_domain}
#
# Outputs:
#   ${project_type}
################################################################################

function _project_get_name_from_domain() {

    local project_domain="${1}"

    # Trying to extract project name from domain
    root_domain="$(_get_root_domain "${project_domain}")"
    possible_project_name="$(_extract_domain_extension "${root_domain}")"

    # Replace '-' and '.' chars
    possible_name="$(echo "${possible_project_name}" | sed -r 's/[.-]+/_/g')"

    # Return
    echo "${possible_name}"

}

################################################################################
# Private: Get project stage from domain
#
# Arguments:
#   $1 = ${project_domain}
#
# Outputs:
#   ${project_type}
################################################################################

function _project_get_stage_from_domain() {

    local project_domain="${1}"

    local project_stages
    local possible_project_stage

    project_stages="demo stage test beta dev"

    # Trying to extract project stage from domain
    possible_project_stage="$(_get_subdomain_part "${project_domain}" | cut -d "." -f 1)"

    if [[ ${project_stages} != *"${possible_project_stage}"* ]]; then

        possible_project_stage="prod"

    fi

    # Return
    echo "${possible_project_stage}"

}

################################################################################
# Private: Get project config
#
# Arguments:
#   $1 = ${project_path}
#   $2 = ${config_field}
#
# Outputs:
#   ${project_type}
################################################################################

function _project_get_config() {

    local project_path="${1}"
    local config_field="${2}"

    local config_value
    local project_name
    local project_config_file

    project_name="$(basename "${project_path}")"
    project_config_file="${BROLIT_PROJECT_CONFIG_PATH}/${project_name}_conf.json"

    if [[ -e ${project_config_file} ]]; then

        config_value="$(cat "${project_config_file}" | jq -r ".${config_field}")"

        # Return
        echo "${config_value}"

    else

        # Return
        echo "false"

    fi

}

########################## UTILS FOR DEVOPS ###################################

function cronjob_check() {

    local script="${1}"
    local cron_file="${2}"

    if [[ -z ${cron_file} ]]; then
        cron_file="/var/spool/cron/crontabs/root"
    fi

    # Command
    grep -qi "${script}" "${cron_file}"

    grep_result=$?
    if [[ ${grep_result} != 0 ]]; then

        # Return JSON
        echo "BROLIT_RESULT => { Cronjob not found }"
        return 0

    else
        # Return JSON
        echo "BROLIT_RESULT => { Cronjob found }"
        return 1

    fi

}

function cronjob_install() {

    local script="${1}"
    local scheduled_time="${2}"

    local cron_file

    cron_file="/var/spool/cron/crontabs/root"

    if [[ ! -f ${cron_file} ]]; then

        touch "${cron_file}"
        /usr/bin/crontab "${cron_file}"

    fi

    # Command
    grep -qi "${script}" "${cron_file}"

    grep_result=$?
    if [[ ${grep_result} != 0 ]]; then

        /bin/echo "${scheduled_time} ${script}" >>"${cron_file}"

        # Return JSON
        echo "BROLIT_RESULT => { Cronjob installed }"
        return 0

    else

        # Return JSON
        echo "BROLIT_RESULT => { Cronjob already exists }"
        return 1

    fi

}

################################################################################
# Private: Get Brolit shell config
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# Should be deprecated
function _brolit_shell_config() {

    # Return JSON part
    echo "\"script_version\": \"${BROLIT_VERSION}\" , \"netdata_url\": \"${NETDATA_SUBDOMAIN}\" , \"mail_notif\": \"${MAIL_NOTIF}\" , \"telegram_notif\": \"${NOTIFICATION_TELEGRAM_STATUS}\" , \"dropbox_enable\": \"${BACKUP_DROPBOX_STATUS}\" , \"cloudflare_enable\": \"${SUPPORT_CLOUDFLARE_STATUS}\" , \"smtp_server\": \"${NOTIFICATION_EMAIL_SMTP_SERVER}\""

}

################################################################################
# Server disks information
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function server_disk_info() {

    # Return JSON
    df -hP | grep '^/dev' | awk 'BEGIN {printf"{\"disks_info\":["}{if($1=="Filesystem")next;if(a)printf",";printf"{\"mount\":\""$6"\",\"size\":\""$2"\",\"used\":\""$3"\",\"avail\":\""$4"\",\"use%\":\""$5"\"}";a++;}END{print"]}";}'

}

################################################################################
# Private: Get server info
#
# Arguments:
#   none
#
# Outputs:
#   0 if monit were installed, 1 on error.
################################################################################

function _serverinfo() {

    local distro
    local cpu_cores
    local ram_amount
    local disk_volume
    local disk_usage
    local public_ip
    local inet_ip # configured on network file

    public_ip="$(curl --silent https://api.ipify.org)"
    inet_ip="$(/sbin/ifconfig eth0 | grep -w "inet" | awk '{print $2}')"

    distro="$(lsb_release -d | awk -F"\t" '{print $2}')"

    cpu_cores="$(grep -c "processor" /proc/cpuinfo)"
    ram_amount="$(grep MemTotal /proc/meminfo | cut -d ":" -f 2)"
    ram_amount="$(_string_remove_spaces "${ram_amount}")"

    disk_volume="$(df / | grep -Eo '/dev/[^ ]+')"
    disk_size="$(df -h | grep -w "${disk_volume}" | awk '{print $2}')"
    disk_usage="$(df -h | grep -w "${disk_volume}" | awk '{print $5}')"

    if [[ ${public_ip} == "${inet_ip}" ]]; then

        # Return JSON part
        echo "\"server_name\": \"${SERVER_NAME}\" , \"distro\": \"${distro}\" , \"cpu_cores\": \"${cpu_cores}\" , \"ram_avail\": \"${ram_amount}\" , \"disk_size\": \"${disk_size}\" , \"disk_usage\": \"${disk_usage}\""
    else

        # Return JSON part
        echo "\"server_name\": \"${SERVER_NAME}\" , \"floating_ip\": \"${inet_ip}\" , \"distro\": \"${distro}\" , \"cpu_cores\": \"${cpu_cores}\" , \"ram_avail\": \"${ram_amount}\" , \"disk_size\": \"${disk_size}\" , \"disk_usage\": \"${disk_usage}\""

    fi

}

################################################################################
# Private: MySQL databases
#
# Arguments:
#   none
#
# Outputs:
#   ${databases} if ok, 1 on error.
################################################################################

# TODO postgresql_databases

function _mysql_databases() {

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

        # Remove 3 fist chars
        databases="${databases:3}"

        # Return
        echo "${databases}"

    else

        # Log
        echo "Something went wrong listing MySQL databases!"

        return 1

    fi

}

################################################################################
# Private: Get packages data
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# JSON FORMAT:
#
# {
#  "webservers":[
#    {"name":"nginx","version":"1.0","default":"true"},
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

function _packages_get_data() {

    local php_v_installed
    local all_php_data
    local php_default

    ## webserver
    apache_v_installed="$(_apache_check_installed_version)"
    nginx_v_installed="$(_nginx_check_installed_version)"
    webservers_v_installed="${nginx_v_installed}${apache_v_installed}"

    if [[ ${webservers_v_installed} == "" ]]; then

        webservers_v_installed="\"no-webserver\""

    else

        # Remove 3 last chars
        webservers_v_installed="${webservers_v_installed::-3}"

    fi

    ## databases
    mysql_v_installed="$(_mysql_check_installed_version)"

    ## languages
    php_v_installed="$(_php_check_installed_version)"

    # Return JSON part
    echo "\"webservers\":[ ${webservers_v_installed} ], \"databases\": [ ${mysql_v_installed} ], \"languages\": [ ${php_v_installed} ]"

}

# TODO: add read_project_config on json results
function sites_directories() {

    local directories
    local all_directories
    local site_cert
    local directory_bl
    local site_size_du
    local site_size

    # Directory blacklist
    local directory_bl="html,phpmyadmin,sql"

    # Run command
    all_directories="$(ls /var/www)"

    for site in ${all_directories}; do

        if [[ ${directory_bl} != *"${site}"* ]]; then

            # Size
            site_size_du="$(du --human-readable --max-depth=0 "/var/www/${site}")"
            site_size="$(echo "${site_size_du}" | awk '{print $1;}')"

            # Type
            site_type="$(_project_get_type "/var/www/${site}")"

            # Cert
            site_cert="$(_certbot_certificate_get_valid_days "${site}")"

            # Cloudflare
            root_domain="$(_get_root_domain "${site}")"
            site_cf="$(_cloudflare_domain_exists "${root_domain}")"

            # Json
            site_data="{\"name\":\"${site}\" , \"type\":\"${site_type}\" , \"size\":\"${site_size}\" , \"certificate_days_to_expire\":\"${site_cert}\" , \"domain_on_cloudflare\":\"${site_cf}\"}"

            directories="${directories} , ${site_data}"

        fi

    done

    if [[ ${directories} != "" ]]; then

        # Remove 3 first chars
        directories="${directories:3}"

        # Return
        echo "${directories}"

    else

        # Return
        echo "\"no-sites\""

    fi

}

function dropbox_get_site_backups() {

    # ${1} = ${chosen_project}

    local chosen_project="${1}"

    local dropbox_chosen_backup_path
    local dropbox_backup_list

    local backup_files

    local backup_type="site"

    # Get dropbox backup list
    dropbox_chosen_backup_path="${SERVER_NAME}/projects-online/${backup_type}/${chosen_project}"
    dropbox_backup_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_chosen_backup_path}")"

    for backup_file in ${dropbox_backup_list}; do

        backup_files="\"${backup_file}\" , ${backup_files}"

    done

    if [[ ${backup_files} != "" ]]; then
        # Remove 3 last chars
        backup_files="${backup_files::3}"
    else
        backup_files="\"empty-response\""
    fi

    # Return
    echo "${backup_files}"

}

################################################################################
# Private: Get backup from Dropbox
#
# Arguments:
#   ${1} = ${chosen_project}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _dropbox_get_backup() {

    local project_domain="${1}"

    local project_name
    local project_db
    local dropbox_site_backup_path
    local dropbox_site_backup_list
    local backup_to_search
    local backup_db
    local backup_date
    local backups_string

    # Reset
    backups_string=''

    if [[ ${project_domain} == "" ]]; then
        return 1
    fi

    project_db="$(_project_get_config "${PROJECTS_PATH}/${project_domain}" "project_db")"

    if [[ ${project_db} == "false" ]]; then

        project_name="$(_project_get_name_from_domain "${project_domain}")"
        project_stage="$(_project_get_stage_from_domain "${project_domain}")"
        project_db="${project_name}_${project_stage}"

    fi

    # Get dropbox backup list
    dropbox_site_backup_path="${SERVER_NAME}/projects-online/site/${project_domain}"

    #echo "Running: ${DROPBOX_UPLOADER} -hq list \"${dropbox_site_backup_path}\" | grep -E \"${project_domain}_site-files_[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}.tar.bz2\""

    dropbox_site_backup_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_site_backup_path}" | grep -Eo "${project_domain}_site-files_[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}.tar.bz2")"

    for backup_file in ${dropbox_site_backup_list}; do

        backup_date="$(_backup_get_date "${backup_file}")"

        backup_to_search="${project_db}_database_${backup_date}.tar.bz2"

        search_backup_db="$("${DROPBOX_UPLOADER}" -hq search "${backup_to_search}" | grep -E "${backup_date}" || ret=$?)" # using ret to bypass unexped errors

        backup_db="$(basename "${search_backup_db}")"

        if [[ ${search_backup_db} != "" ]]; then
            backups_string="${backups_string}\"$backup_date\":{\"files\":\"${backup_file}\",\"database\":\"${backup_db}\"} , "
        else
            backups_string="${backups_string}\"$backup_date\":{\"files\":\"${backup_file}\",\"database\":\"false\"} , "
        fi

    done

    if [[ $backups_string != "" ]]; then
        # Remove 3 last chars
        backups_string="${backups_string::-3}"

    else
        backups_string="\"empty-response\""
    fi

    # Return JSON
    #echo "SERVER_DATA_RESULT => { ${backups_string} }"
    echo "${backups_string}"

}

################################################################################
# Get project backups from Dropbox
#
# Arguments:
#   none
#
# Outputs:
#   json file, 1 on error.
################################################################################

function dropbox_get_sites_backups() {

    local dropbox_chosen_backup_path
    local dropbox_backup_list
    local backup_files

    local backup_type="site"
    local backup_project=""
    local backup_projects=""

    # Get dropbox backup list
    dropbox_chosen_backup_path="${SERVER_NAME}/projects-online/${backup_type}"
    dropbox_project_backup_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_chosen_backup_path}" | awk -F " " '{ print $2 }')"

    for backup_dir in ${dropbox_project_backup_list}; do

        backup_files="$(_dropbox_get_backup "${backup_dir}")"

        if [[ ${backup_dir} != "error" ]]; then
            backup_project="\"${backup_dir}\" : { ${backup_files} }"
        else
            backup_project="\"${backup_dir}\" : ${backup_files}"
        fi

        backup_projects="${backup_project},${backup_projects}"

    done

    if [[ ${backup_projects} != "" ]]; then
        backup_projects="${backup_projects::-1}" # Remove last char
    else
        backup_projects="\"empty-response\""
    fi

    # Return/Write JSON
    echo "{ ${backup_projects} }" >"${BROLIT_LITE_OUTPUT_DIR}/dropbox_get_sites_backups.json"

}

################################################################################
# Get record details from Cloudflare
#
# Arguments:
#   ${1} = ${domain}
#
# Outputs:
#   json file, 1 on error.
################################################################################

function cloudflare_get_record_details() {

    local domain="${1}"

    local record_name
    local zone_id
    local record_id

    record_name="${domain}"

    root_domain="$(_get_root_domain "${domain}")"

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"

    record_id="$(_cloudflare_record_exists "${record_name}" "${zone_id}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && ${record_id} != "" ]]; then

        # DNS Record Details
        record="$(curl -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${record_id}" \
            -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" \
            -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" \
            -H "Content-Type: application/json")"

        if [[ ${record} == *"\"success\":false"* || ${record} == "" ]]; then

            # Return
            echo "Get record details failed"

            return 1

        else

            # Return JSON
            echo "{ \"cloudflare_data\": ${record} }"

        fi

    fi

}

################################################################################
# Get project config
#
# Arguments:
#   ${1} = ${project_domain}
#
# Outputs:
#   0 if monit were installed, 1 on error.
################################################################################

function read_project_config() {

    local project_domain="${1}"

    local project_config
    local project_config_file

    #DEVOPS_CONFIG_FILE="${PROJECTS_PATH}/${project_domain}/brolit.conf"
    project_config_file="${BROLIT_PROJECT_CONFIG_PATH}/${project_name}_conf.json"

    if [[ -f ${project_config_file} ]]; then

        project_config="$(<"${project_config_file}")"

        # Return
        echo "BROLIT_RESULT => ${project_config}"

    else

        # Return
        echo "BROLIT_RESULT => { no-site-config }"

    fi

}

function firewall_show_status() {

    local ufw_status=""

    # ufw app list, replace space with "-" and "/n" with space
    ufw_status="$(ufw status | sed -n '1 p' | cut -d " " -f 2 | tr " " "-" | sed -z 's/\n/ /g' | sed -z 's/--//g')"

    # Details begins at line 5
    counter=5
    ufw_status_line="$(ufw status | sed -n "${counter} p" | cut -d "-" -f 2 | tr " " ";" | sed -z 's/;;//g')"
    while [ -n "${ufw_status_line}" ]; do
        ufw_status_line="$(ufw status | sed -n "${counter} p" | cut -d "-" -f 2 | tr " " ";" | sed -z 's/;;//g')"
        ufw_status_details="${ufw_status_details} ${ufw_status_line}"
        counter=$(($counter + 1))
    done

    # String to JSON
    json_string="$(_jsonify_output "key-value" "ufw-status" "${ufw_status}")"

    if [[ ${ufw_status_details} != "" ]]; then

        json_string_d="$(_jsonify_output "value-list" "${ufw_status_details}")"

        # Return JSON
        echo "${json_string},{\"ufw-details\": ${json_string_d}}"

    else

        # Return JSON
        echo "${json_string},{\"ufw-details\": \"empty-response\"}"

    fi

}

function firewall_app_list() {

    # ufw app list, replace space with "-" and "/n" with space
    app_list="$(ufw app list | cut -d ":" -f 2 | tr " " "-" | sed -z 's/\n/ /g' | sed -z 's/--//g')"

    # String to JSON
    json_string="$(_jsonify_output "value-list" "${app_list}")"

    # Return JSON
    echo "${json_string}" > "${BROLIT_LITE_OUTPUT_DIR}/firewall_app_list.json"

}

function list_packages_to_upgrade() {

    # apt commands
    pkgs="$(apt list --upgradable 2>/dev/null | awk -F/ "{print \$1}" | sed -e '1,/.../ d')"

    json_string="$(_jsonify_output "value-list" "${pkgs}")"

    # Return JSON
    echo "${json_string}" >"${BROLIT_LITE_OUTPUT_DIR}/list_packages_to_upgrade.json"

}

################################################################################
# Show server data
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function show_server_data() {

    local server_info
    local server_config
    local server_databases
    local server_sites
    local server_pkgs

    server_info="$(_serverinfo)"

    server_config="$(_brolit_shell_config)"

    server_firewall="$(firewall_show_status)"

    if [[ "$(_is_pkg_installed "mysql-server")" == "true" || "$(_is_pkg_installed "mariadb-server")" == "true" ]]; then
        server_databases="$(_mysql_databases)"
    else
        server_databases="\"no-databases\""
    fi

    server_sites="$(sites_directories)"
    server_pkgs="$(_packages_get_data)"

    # Return JSON
    echo "{ \"server_info\": { ${server_info} },\"firewall_info\":  [ ${server_firewall} ] , \"server_pkgs\": { ${server_pkgs} }, \"server_config\": { ${server_config} }, \"databases\": [ ${server_databases} ], \"sites\": [ ${server_sites} ] }" >"${BROLIT_LITE_OUTPUT_DIR}/show_server_data.json"

}