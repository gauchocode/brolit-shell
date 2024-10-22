#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.8
################################################################################

################################################################################
# Private: Generate a timestamp
#
# Arguments:
#  none
#
# Outputs:
#   timestamp
################################################################################

function _timestamp() {

    date +"%Y-%m-%dT%H:%M:%S"

}

################################################################################
# Private: Read field from json file
#
# Arguments:
#  ${1} = ${json_file}
#  ${2} = ${json_field}
#
# Outputs:
#   0 if ok, 1 on error.
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
#  ${1} = ${json_file}
#  ${2} = ${json_field}
#  ${3} = ${json_field_value}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _json_write_field() {

    local json_file="${1}"
    local json_field="${2}"
    local json_field_value="${3}"

    json_field_value="$(jq ".${json_field} = \"${json_field_value}\"" "${json_file}")" && echo "${json_field_value}" >"${json_file}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        return 0

    else

        echo "Error getting value from ${json_field}" && return 1

    fi

}

################################################################################
# Private: Transfor output to json
#
# Arguments:
#  ${1} = ${mode}
#
# Outputs:
#   0 if ok, 1 on error.
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

        #echo $@

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
#  ${1} = ${string}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _string_remove_spaces() {

    local string="${1}"

    # Return
    echo "${string//[[:blank:]]/}"

}

################################################################################
# Remove first and last quote (") from a string
#
# Arguments:
#   ${1} = ${string}
#
# Outputs:
#   string
################################################################################

function _string_remove_quotes() {

    local string="${1}"

    local new_string

    new_string="$(sed -e 's/^"//' -e 's/"$//' <<<"$string")"

    # Return
    echo "${new_string}"

}

################################################################################
# Private: Replace /n for space char
#
# Arguments:
#  ${1} = ${string}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _string_replace_newline_with_spaces() {

    local string="${1}"

    # Return
    echo "${string//$'\n'/ }"

}

################################################################################
# Private: Get Domain zone id from cloudflare
#
# Arguments:
#  ${1} = ${zone_name}
#
# Outputs:
#   0 if ok, 1 on error.
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
        echo "${zone_id}" && return 0

    else

        # Return
        echo "Domain ${zone_name} not found" && return 1

    fi

}

################################################################################
# Private: Get record details from Cloudflare
#
# Arguments:
#   ${1} = ${domain}
#
# Outputs:
#   json file, 1 on error.
################################################################################

function _cloudflare_get_record_details() {

    local domain="${1}"

    local record_name
    local root_domain
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
            echo "Get record details failed" && return 1

        else

            # Return JSON
            echo "{ \"cloudflare_data\": ${record} }" && return 0

        fi

    fi

}

################################################################################
# Private: Check if package is installed
#
# Arguments:
#  ${1} = ${package}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _is_pkg_installed() {

    local package="${1}"

    if [[ "$(dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -c "ok installed")" == "1" ]]; then

        # Return
        echo "true" && return 0

    else

        # Return
        echo "false" && return 1

    fi

}

################################################################################
# Private: Check phyton installed version
#
# Arguments:
#  none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _python_check_installed_version() {

    local python_installed_pkg
    local python_installed_version

    # Installed versions
    python_installed_pkg="$(sudo dpkg --list | grep -oh ' python[0-9]\.[0-9] ')"

    if [[ -n ${python_installed_pkg} ]]; then
        # Installed versions
        python_installed_version="$(python3 --version 2>&1)"
        python_installed_version="$(echo "${python_installed_version}" | cut -d " " -f 2 | grep -o '[0-9.]*$')"
        # Return
        echo "{\"name\":\"python\",\"version\":\"${python_installed_version}\",\"default\":\"true\"} , " && return 0
    fi

}

################################################################################
# Private: Check nodejs installed version
#
# Arguments:
#  none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _nodejs_check_installed_version() {

    local nodejs_installed_pkg
    local nodejs_installed_versions

    # Installed versions
    nodejs_installed_pkg="$(which node)"

    if [[ -n ${nodejs_installed_pkg} ]]; then
        # Installed versions
        nodejs_installed_versions="$(node --version 2>&1)"
        nodejs_installed_versions="$(echo "${nodejs_installed_versions}" | cut -d " " -f 2 | grep -o '[0-9.]*$')"
        # Return
        echo "{\"name\":\"nodejs\",\"version\":\"${nodejs_installed_versions}\",\"default\":\"true\"} , " && return 0
    fi

}

################################################################################
# Private: Check php installed version
#
# Arguments:
#  none
#
# Outputs:
#   0 if ok, 1 on error.
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

    if [[ -n ${php_installed_versions} ]]; then

        for php_v in ${php_installed_versions}; do

            # Default versions
            php_default_version="$(php -v | grep -Eo 'PHP [0-9.].[0-9.]' | cut -d " " -f 2)"

            [[ ${php_default_version} == "${php_v}" ]] && php_default=true || php_default=false

            # Json
            phpv_data="{\"name\":\"php\",\"version\":\"${php_v}\",\"default\":\"${php_default}\"}"
            all_php_data="${all_php_data} , ${phpv_data}"

        done

        # Remove 3 first chars
        all_php_data="${all_php_data:3}"

        # Return
        echo "${all_php_data} , " && return 0

    else

        return 1

    fi

}

################################################################################
# Private: Check mysql installed version
#
# Arguments:
#  none
#
# Outputs:
#   0 if mysql is installed, 1 on error.
################################################################################

function _mysql_check_installed_version() {

    local mysql_installed_pkg
    local mysql_installed_version

    # MySQL or MariaDB?
    mysql_installed_pkg="$(apt -qq list mysql-server --installed 2>/dev/null | cut -d "/" -f1)"

    if [[ -n ${mysql_installed_pkg} ]]; then
        # Extract only version numbers
        mysql_installed_version="$(mysql -V | awk -F' ' '{print $3}' | grep -o '[0-9.]*$' | tr '\n' ' ')"

        # Return
        echo "{\"name\":\"${mysql_installed_pkg}\",\"version\":\"${mysql_installed_version}\",\"default\":\"true\"} , " && return 0

    else

        mysql_installed_pkg="$(apt -qq list mariadb-server --installed 2>/dev/null | cut -d "/" -f1)"

        if [[ -n ${mysql_installed_pkg} ]]; then
            # Extract only version numbers
            mysql_installed_version="$(mysql -V | grep -Eo '[+-]?[0-9]+([.][0-9]+)+([.][0-9]+)?-MariaDB' | cut -d "-" -f 1)"

            # Return
            echo "{\"name\":\"${mysql_installed_pkg}\",\"version\":\"${mysql_installed_version}\",\"default\":\"true\"} , " && return 0

        fi

    fi

    # Return
    return 1

}

################################################################################
# Private: Check psql installed version
#
# Arguments:
#  none
#
# Outputs:
#   0 if psql is installed, 1 on error.
################################################################################

function _psql_check_installed_version() {

    local psql_installed_pkg
    local psql_installed_version

    # Check if package is installed
    psql_installed_pkg="$(sudo dpkg --list | grep -Eo 'postgresql')"
    if [[ -n ${psql_installed_pkg} ]]; then

        # Installed versions
        psql_installed_version="$(psql --version 2>&1)"
        psql_installed_version="$(echo "${psql_installed_version}" | cut -d " " -f 3 | grep -o '[0-9.]*$')"

        if [[ -n ${psql_installed_version} ]]; then
            # Return
            echo "{\"name\":\"postgresql\",\"version\":\"${psql_installed_version}\",\"default\":\"true\"} , " && return 0
        else

            echo "{\"name\":\"postgresql\",\"version\":\"unknown\",\"default\":\"true\"} , " && return 1

        fi

    else

        return 1

    fi

}

################################################################################
# Private: Check nginx installed version
#
# Arguments:
#  none
#
# Outputs:
#   0 if nginx is installed, 1 on error.
################################################################################

function _nginx_check_installed_version() {

    local nginx_installed_version

    # Check if package is installed
    nginx_installed_pkg="$(sudo dpkg --list | grep -Eo 'nginx-core')"
    if [[ -n ${nginx_installed_pkg} ]]; then

        # Installed versions
        nginxv="$(nginx -v 2>&1)"
        nginxv="$(_string_remove_spaces "${nginxv}")"
        nginx_installed_version="$(echo "${nginxv}" | cut -d "(" -f 1 | grep -o '[0-9.]*$')"

        if [[ -n ${nginx_installed_version} ]]; then
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
#   0 if apache is installed, 1 on error.
################################################################################

function _apache_check_installed_version() {

    local apache_installed_version

    # Check if package is installed
    apache2_installed_pkg="$(sudo dpkg --list | grep -Eo 'apache2-bin')"
    if [[ -n ${apache2_installed_pkg} ]]; then

        # Installed versions
        apache_installed_version="$(apache2 -v | awk -F' ' '{print $3}' | grep -o '[0-9.]*$' | tr '\n' ' ' | cut -d " " -f 1)"

        if [[ -n ${apache_installed_version} ]]; then
            # Return
            echo "{\"name\":\"apache2\",\"version\":\"${apache_installed_version}\",\"default\":\"true\"} , "
        fi

    fi

}

################################################################################
# Private: Get date from backup file
#
# Arguments:
#  ${1} = ${backup_file}
#
# Outputs:
#   ${backup_date}.
################################################################################

function _backup_get_date() {

    local backup_file="${1}"

    local backup_date

    backup_date="$(echo "${backup_file}" | grep -Eo '[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}')"

    # Return
    echo "${backup_date}"

}

################################################################################
# Private: Get date from backup file
#
# Arguments:
#  ${1} = ${domains} - (domain.com,www.domain.com)
#
# Outputs:
#   ${cert_days}.
################################################################################

function _certbot_certificate_get_valid_days() {

    local domain="${1}"

    local cert_days
    local cert_days_output

    cert_days_output="$(certbot certificates --domain "${domain}" 2>&1)"
    cert_days="$(echo "${cert_days_output}" | grep -Eo 'VALID: [0-9]+[0-9]' | cut -d ' ' -f 2)"

    if [[ -n ${cert_days} ]]; then

        # Return
        echo "${cert_days}" && return 0

    else

        # Return
        echo "no-cert" && return 1

    fi

}

################################################################################
# Private: Check if domain exists on Cloudflare account
#
# Arguments:
#  ${1} = ${root_domain}
#
# Outputs:
#   true or false.
################################################################################

function _cloudflare_domain_exists() {

    local root_domain="${1}"

    local zone_name
    local zone_id

    zone_id="$(_cloudflare_get_zone_id "${root_domain}")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && ${zone_id} != "" ]]; then

        # Return
        echo "true" && return 0

    else

        # Return
        echo "false" && return 1
    fi

}

################################################################################
# Private: Check if record exists on Cloudflare account
#
# Arguments:
#  ${1} = ${domain}
#  ${2} = ${zone_id}
#
# Outputs:
#   true or false.
################################################################################

function _cloudflare_record_exists() {

    local domain="${1}"
    local zone_id="${2}"

    # Only for better readibility
    record_name="${domain}"

    # Retrieve record_id
    record_id="$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records?name=${record_name}" -H "X-Auth-Email: ${SUPPORT_CLOUDFLARE_EMAIL}" -H "X-Auth-Key: ${SUPPORT_CLOUDFLARE_API_KEY}" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*')"

    #exitstatus=$?
    [[ -z ${record_id} ]] && return 1

    # Clean output
    record_id="$(echo "${record_id}" | tr -d '\n')"

    # Return
    echo "${record_id}"

}

################################################################################
# Private: Get domain extension from domain
#
# Arguments:
#  ${1} = ${domain}
#
# Outputs:
#   ${domain_ext}
################################################################################

function _get_domain_extension() {

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
        echo "${domain_ext}" && return 0

    else

        return 1

    fi

}

################################################################################
# Private: Get subdomain part from domain
#
# Arguments:
#  ${1} = ${domain}
#
# Outputs:
#   ${subdomain_part}
################################################################################

function _get_subdomain_part() {

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
            echo "${subdomain_part}" && return 0

        else

            # Return
            echo "" && return 0

        fi

    else

        return 1

    fi

}

################################################################################
# Private: Get root domain from domain
#
# Arguments:
#  ${1} = ${domain}
#
# Outputs:
#   ${root_domain}
################################################################################

function _get_root_domain() {

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
        echo "${root_domain}" && return 0

    else

        return 1

    fi

}

################################################################################
# Private: Extract domain extension from domain
#
# Arguments:
#  ${1} = ${domain}
#
# Outputs:
#   ${domain_no_ext}
################################################################################

function _extract_domain_extension() {

    local domain="${1}"

    local domain_no_ext
    local domain_extension
    local domain_extension_output

    domain_extension="$(_get_domain_extension "${domain}")"
    domain_extension_output=$?
    if [[ ${domain_extension_output} -eq 0 ]]; then

        domain_no_ext=${domain%"$domain_extension"}

        # Return
        echo "${domain_no_ext}" && return 0

    else

        return 1

    fi

}

################################################################################
# Private: Get Wordpress config path
#
# Arguments:
#  ${1} = ${dir_to_search}
#
# Outputs:
#   ${find_output}
################################################################################

function _wp_config_path() {

    local dir_to_search="${1}"

    local find_output

    if [[ -n "${dir_to_search}" && -d "${dir_to_search}" ]]; then

        # Find where wp-config.php is
        find_output="$(find "${dir_to_search}" -name "wp-config.php" | sed 's|/[^/]*$||')"

        # Check if directory exists
        if [[ -d "${find_output}" ]]; then

            # Return
            echo "${find_output}" && return 0

        else

            return 1

        fi

    else

        echo "Error: Can't get project type, directory '${dir_to_search}' doesn't exist." "false"
        return 1

    fi

}

################################################################################
# Check if project is listed as ignored on config
#
# Arguments:
#   ${1} = ${project}
#
# Outputs:
#   true or false
################################################################################

function _project_is_ignored() {

    local project="${1}" #string

    local ignored="false"

    local ignored_list
    local excluded_projects_array

    IGNORED_PROJECTS_LIST="$(_json_read_field "${BROLIT_CONFIG_FILE}" "BACKUPS.config[].projects[].ignored[]")"

    ignored_list="$(_string_remove_spaces "${IGNORED_PROJECTS_LIST}")"
    ignored_list="$(echo "${ignored_list}" | tr '\n' ',')"

    # String to Array
    IFS="," read -r -a excluded_projects_array <<<"${ignored_list}"
    for i in "${excluded_projects_array[@]}"; do
        :

        [[ ${project} == "${i}" ]] && ignored="true" && break

    done

    # Return
    echo "${ignored}"

}

################################################################################
# Private: Get project type
#
# Arguments:
#   ${1} = ${dir_path}
#
# Outputs:
#   ${project_type}
################################################################################

function _project_get_type() {

    local dir_path="${1}"

    local project_type
    local wp_path
    local laravel

    # TODO: if brolit_conf exists, should check this file and get project type

    # Ensure the directory exists
    if [[ -n ${dir_path} && -d ${dir_path} ]]; then

        # Check for WordPress
        wp_path="$(_wp_config_path "${dir_path}")"
        if [[ -n ${wp_path} ]]; then

            project_type="wordpress"

            # Return
            echo "${project_type}" && return 0

        fi

        # Check for Laravel
        composer="$(find "${dir_path}" -maxdepth 2 -name "composer.json" -type f)"
        if [[ -n ${composer} ]]; then

            laravel="$(cat "${composer}" | grep "laravel/framework")"

            if [[ -n ${laravel} ]]; then

                project_type="laravel"

                # Return
                echo "${project_type}" && return 0

            fi

        fi

        # Check for React by looking for specific react-scripts in package.json
        if [[ -f "${dir_path}/package.json" ]] && grep -q "react-scripts" "${dir_path}/package.json"; then

            project_type="react"

            # Return
            echo "${project_type}" && return 0

        fi

        # Check for Node.js by looking for server.js or app.js files which are common entry points
        if [[ -f "${dir_path}/package.json" && (-f "${dir_path}/server.js" || -f "${dir_path}/app.js") ]]; then

            project_type="nodejs"

            # Return
            echo "${project_type}" && return 0

        fi

        # Check for Python
        if [[ -f "${dir_path}/setup.py" || -f "${dir_path}/Pipfile" || -f "${dir_path}/pyproject.toml" ]]; then

            project_type="python"

            # Return
            echo "${project_type}" && return 0

        fi

        # Check for simple PHP
        if [[ $(find "${dir_path}" -maxdepth 1 -type f -name "*.php" | wc -l) -gt 0 ]]; then

            project_type="php"

            # Return
            echo "${project_type}" && return 0

        fi

        # Check for simple HTML
        if [[ $(find "${dir_path}" -maxdepth 1 -type f -name "*.html" | wc -l) -gt 0 && $(find "${dir_path}" -maxdepth 1 -type f \( -name "*.php" -o -name "*.py" \) | wc -l) -eq 0 ]]; then

            project_type="html"

            # Return
            echo "${project_type}" && return 0

        fi

        # Return
        echo "other" && return 0

    else

        echo "Can't get project type, directory '${dir_path}' doesn't exist."

        return 1

    fi

}

################################################################################
# Private: Get project installation type
#
# Arguments:
#   ${1} = ${dir_path}
#
# Outputs:
#   ${project_installation_type}
################################################################################

function _project_get_install_type() {

    local dir_path="${1}"

    local project_install_type

    if [[ -n ${dir_path} ]]; then

        # docker-compose?
        docker="$(
            find "${dir_path}" -maxdepth 2 -name "docker-compose.yml" -type f
            find "${dir_path}" -maxdepth 2 -name "docker-compose.yaml" -type f
        )"
        if [[ -n ${docker} ]]; then

            project_install_type="docker-compose"

            # Return
            echo "${project_install_type}" && return 0

        else

            # Return
            echo "default" && return 0

        fi

    else

        # TODO: get from brolit project config?

        return 1

    fi

}

################################################################################
# Private: Get project name from domain
#
# Arguments:
#   ${1} = ${project_domain}
#
# Outputs:
#   ${project_type}
################################################################################

function _project_get_name_from_domain() {

    local project_domain="${1}"

    local project_stages
    local possible_project_name

    declare -a possible_project_stages_on_subdomain=("www" "demo" "stage" "test" "beta" "dev")

    # Extract project name from domain
    possible_project_name="$(_extract_domain_extension "${project_domain}")"

    # Remove stage from domain
    for p in "${possible_project_stages_on_subdomain[@]}"; do

        possible_project_name="$(echo "${possible_project_name}" | sed -r "s/${p}.//g")"

    done

    # Remove "-" and replace '.' with '_'
    possible_project_name="$(echo "${possible_project_name}" | sed -r 's/[-]+//g' | sed -r 's/[.]+/_/g')"

    # Return
    echo "${possible_project_name}"

}

################################################################################
# Private: Get project stage from domain
#
# Arguments:
#   ${1} = ${project_domain}
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
    subdomain_part="$(_get_subdomain_part "${project_domain}")"
    possible_project_stage="$(echo "${subdomain_part}" | cut -d "." -f 1)"

    if [[ ${project_stages} != *"${possible_project_stage}"* || ${possible_project_stage} == "" ]]; then

        possible_project_stage="prod"

    fi

    # Return
    echo "${possible_project_stage}"

}

################################################################################
# Get project config
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${config_field}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _project_get_brolit_config_file() {

    local project_path="${1}"

    local project_domain
    local project_name
    local project_config_file

    project_domain="$(basename "${project_path}")"

    project_name="$(_project_get_name_from_domain "${project_domain}")"

    project_config_file="${BROLIT_CONFIG_PATH}/${project_name}_conf.json"

    if [[ -e ${project_config_file} ]]; then

        # Return
        echo "${project_config_file}" && return 0

    else

        # Return
        echo "false" && return 1

    fi

}

################################################################################
# Get project config var
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${config_field}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _project_get_brolit_config_var() {

    local project_path="${1}"
    local config_field="${2}"

    local config_value
    local project_config_file

    project_config_file="$(_project_get_brolit_config_file "${project_path}")"

    if [[ ${project_config_file} != "false" ]]; then

        config_value="$(cat "${project_config_file}" | jq -r ".${config_field}")"

        # Return
        echo "${config_value}"

        return 0

    else

        return 1

    fi

}

################################################################################
# Get WordPress config option
#
# Arguments:
#  ${1} = ${project_dir}
#  ${2} = ${wp_option}
#
# Outputs:
#  ${wp_value} if ok, 1 on error.
################################################################################

function _wp_config_get_option() {

    local wp_project_dir="${1}"
    local wp_option="${2}"

    local wp_value

    # Update wp-config.php
    wp_value="$(cat "${wp_project_dir}/wp-config.php" | grep "${wp_option}" | cut -d \' -f 4)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && -n ${wp_value} ]]; then

        # Return
        echo "${wp_value}"

        return 0

    else

        return 1

    fi

}

################################################################################
# Get project config option from env file
#
# Arguments:
#  ${1} = ${file}
#  ${2} = ${variable}
#
# Outputs:
#  ${content} if ok, 1 on error.
################################################################################

function _project_get_config_var() {

    local file="${1}"
    local variable="${2}"

    local content

    [[ ! -f ${file} ]] && exit 1

    # Read "${file}"/.env to extract ${variable}
    content="$(grep -oP "^${variable}=\K.*" "${file}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        content="$(_string_remove_quotes "${content}")"

        # Return
        echo "${content}" && return 0

    else

        return 1

    fi

}

################################################################################
# Get project config file
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${project_type}
#  ${3} = ${project_install_type}
#
# Outputs:
#  ${content} if ok, 1 on error.
################################################################################

function _project_get_config_file() {

    local project_path="${1}"
    local project_type="${2}"
    local project_install_type="${3}"

    if [[ ${project_install_type} == "docker"* ]]; then

        # Get WWW_DATA_DIR value from .env file
        project_dir="$(cat "${project_path}/.env" | grep WWW_DATA_DIR | cut -d "=" -f 2)"

        # Check exitstatus
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Overwrite ${project_path}
            project_path="${PROJECTS_PATH}${project_dir}"

        else

            return 1

        fi

    fi

    [[ ${project_type} == "wordpress" ]] && project_config_file="${project_path}/wp-config.php" || project_config_file="${project_path}/.env"

    if [[ -f "${project_config_file}" ]]; then

        # Return
        echo "${project_config_file}" && return 0

    else

        # Return
        return 1

    fi

}

################################################################################
# Get configured database
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${project_type}
#
# Outputs:
#   ${db_name} if ok, 1 on error.
################################################################################

function _project_get_configured_database() {

    local project_path="${1}"
    local project_type="${2}"
    local project_install_type="${3}"

    local project_config_file
    local database_name
    local wpconfig_path

    # Get project config file
    project_config_file="$(_project_get_config_file "${project_path}" "${project_type}" "${project_install_type}")"

    # Check project config file
    if [[ -n "${project_config_file}" ]]; then

        case ${project_type} in

        wordpress)

            wpconfig_path=$(_wp_config_path "${project_config_file}")

            database_name="$(_wp_config_get_option "${wpconfig_path}" "DB_NAME")"

            # Return
            [[ -z ${database_name} ]] && return 1
            echo "${database_name}" && return 0

            ;;

        laravel)

            database_name="$(_project_get_config_var "${project_config_file}" "DB_DATABASE")"

            # Return
            [[ -z ${database_name} ]] && return 1
            echo "${database_name}" && return 0

            ;;

        php)

            database_name="$(_project_get_config_var "${project_config_file}" "DB_DATABASE")"

            # Return
            [[ -z ${database_name} ]] && return 1
            echo "${database_name}" && return 0

            ;;

        nodejs)

            database_name="$(_project_get_config_var "${project_config_file}" "DB_DATABASE")"

            # Return
            [[ -z ${database_name} ]] && return 1
            echo "${database_name}" && return 0

            ;;

        *)

            echo "no-database" && return 0

            ;;

        esac

    else

        ## Project has database?
        db_status="$(_project_get_config_var "${project_path}" "project[].database[].status")"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${db_status} == "disabled" ]]; then
                echo "no-database" && return 0
            else
                ## Get database name
                database_name="$(_project_get_config_var "${project_path}" "project[].database[].config[].name")"

                # Return
                [[ -z ${database_name} ]] && return 1
                echo "${database_name}" && return 0

            fi

        fi

    fi

}

######################### UTILS FOR BROLIT-ADMIN ###############################

################################################################################
# Private: Check if a script is installed as a cron job
#
# Arguments:
#   ${1} = ${script}
#   ${2} = ${cron_file}
#
# Outputs:
#   0 if not found, 1 if found
################################################################################

function _cronjob_check() {

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
        echo "BROLIT_RESULT => { Cronjob not found }" && return 0

    else
        # Return JSON
        echo "BROLIT_RESULT => { Cronjob found }" && return 1

    fi

}

################################################################################
# Private: Install script as a cron job
#
# Arguments:
#   ${1} = ${script}
#   ${2} = ${scheduled_time}
#
# Outputs:
#   0 if script was installed ok, 1 on error
################################################################################

function _cronjob_install() {

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
        echo "BROLIT_RESULT => { Cronjob installed }" && return 0

    else

        # Return JSON
        echo "BROLIT_RESULT => { Cronjob already exists }" && return 1

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

# Should be deprecated?
function _brolit_shell_config() {

    # Read brolit_conf.json

    ## Netdata subdomain
    netdata_status="$(_json_read_field "${BROLIT_CONFIG_FILE}" "PACKAGES.netdata[].status")"
    if [[ ${netdata_status} == "enabled" ]]; then
        netdata_subdomain="$(_json_read_field "${BROLIT_CONFIG_FILE}" "PACKAGES.netdata[].config[].subdomain")"
        netdata_status="true"
    else
        netdata_subdomain="false"
        netdata_status="false"
    fi

    ## Mail notification config
    mail_notification_status="$(_json_read_field "${BROLIT_CONFIG_FILE}" "NOTIFICATIONS.email[].status")"
    if [[ ${mail_notification_status} == "enabled" ]]; then
        mail_notification_config="$(_json_read_field "${BROLIT_CONFIG_FILE}" "NOTIFICATIONS.email[].config[].maila")"
        mail_notification_smtp="$(_json_read_field "${BROLIT_CONFIG_FILE}" "NOTIFICATIONS.email[].config[].smtp_server")"
        mail_notification_status="true"
    else
        mail_notification_config="false"
        mail_notification_smtp="false"
        mail_notification_status="false"
    fi

    ## Telegram notification config
    telegram_notification_status="$(_json_read_field "${BROLIT_CONFIG_FILE}" "NOTIFICATIONS.telegram[].status")"
    if [[ ${telegram_notification_status} == "enabled" ]]; then
        telegram_notification_status="true"
    else
        telegram_notification_status="false"
    fi

    ## Ntfy notification config
    ntfy_status="$(_json_read_field "${BROLIT_CONFIG_FILE}" "NOTIFICATIONS.ntfy[].status")"
    if [[ ${ntfy_status} == "enabled" ]]; then
        ntfy_status="true"
    else
        ntfy_status="false"
    fi

    ## Discord notification config
    discord_status="$(_json_read_field "${BROLIT_CONFIG_FILE}" "NOTIFICATIONS.discord[].status")"
    if [[ ${discord_status} == "enabled" ]]; then
        discord_webhook="$(_json_read_field "${BROLIT_CONFIG_FILE}" "NOTIFICATIONS.discord[].config[].webhook")"
        discord_status="true"
    else
        discord_webhook="false"
        discord_status="false"
    fi

    ## Dropbox config
    backup_dropbox_status="$(_json_read_field "${BROLIT_CONFIG_FILE}" "BACKUPS.methods[].dropbox[].status")"
    if [[ ${backup_dropbox_status} == "enabled" ]]; then
        backup_dropbox_status="true"
    else
        backup_dropbox_status="false"
    fi

    ## Borg backup method
    backup_borg_status="$(_json_read_field "${BROLIT_CONFIG_FILE}" "BACKUPS.methods[].borg[].status")"
    if [[ ${backup_borg_status} == "enabled" ]]; then
        backup_borg_status="true"
    else
        backup_borg_status="false"
    fi

    ## Cloudflare config
    cloudflare_status="$(_json_read_field "${BROLIT_CONFIG_FILE}" "DNS.cloudflare[].status")"
    if [[ ${cloudflare_status} == "enabled" ]]; then
        cloudflare_status="true"
    else
        cloudflare_status="false"
    fi

    ## SMTP Server config
    #smtp_status="$(_json_read_field "${BROLIT_CONFIG_FILE}" "BACKUPS.config[].methods[].smtp[].status")"

    # Return JSON part
    echo "\"script_version\": \"${BROLIT_VERSION}\" , \"netdata_url\": \"${netdata_subdomain}\" , \"mail_notif\": \"${mail_notification_config}\" , \"telegram_notif\": \"${telegram_notification_status}\" , \"ntfy_notif\": \"${ntfy_status}\" , \"discord_notif\": \"${discord_status}\" , \"dropbox_enable\": \"${backup_dropbox_status}\" , \"borg_enable\": \"${backup_borg_status}\" , \"cloudflare_enable\": \"${cloudflare_status}\" , \"smtp_server\": \"${mail_notification_smtp}\""

}

################################################################################
# Private: Server disks information
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _server_disks_info() {

    # Return JSON
    df -hP | grep '^/dev' | awk 'BEGIN {printf"\"disks_info\":["}{if($1=="Filesystem")next;if(a)printf",";print"{\"mount\":\""$6"\",\"size\":\""$2"\",\"used\":\""$3"\",\"avail\":\""$4"\",\"use%\":\""$5"\"}";a++;}END{printf"]";}'

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
    local disks_info
    local public_ip
    local public_ipv6
    local local_ip

    local_ip="$(ip route get 1 | awk '{print $(NF-2);exit}')"

    # Get public IP (ref: https://www.ipify.org)
    public_ip="$(curl --silent https://api.ipify.org)"
    if [[ -z ${public_ip} ]]; then
        # Alternative method
        public_ip="$(curl --silent http://ipv4.icanhazip.com)"
    else
        # If api.apify.org works, get IPv6 too
        public_ipv6="$(curl --silent 'https://api64.ipify.org')"
    fi

    distro="$(lsb_release -d | awk -F"\t" '{print $2}')"

    # Hardware info
    cpu_cores="$(grep -c "processor" /proc/cpuinfo)"
    ram_amount="$(grep MemTotal /proc/meminfo | cut -d ":" -f 2)"
    ram_amount="$(_string_remove_spaces "${ram_amount}")"
    disks_info="$(_server_disks_info)"

    if [[ -z ${public_ip} ]]; then

        # Return JSON part
        echo "\"server_name\": \"${SERVER_NAME}\" , \"distro\": \"${distro}\" , \"cpu_cores\": \"${cpu_cores}\" , \"ram_avail\": \"${ram_amount}\" , ${disks_info}"

    else

        # Return JSON part
        echo "\"server_name\": \"${SERVER_NAME}\" , \"floating_ip\": \"${local_ip}\" , \"distro\": \"${distro}\" , \"cpu_cores\": \"${cpu_cores}\" , \"ram_avail\": \"${ram_amount}\" , ${disks_info}"

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

function _mysql_databases() {

    local database
    local databases
    local all_databases
    local database_bl

    # Database blacklist
    database_bl="$(_json_read_field "${BROLIT_CONFIG_FILE}" "BACKUPS.config[].databases[].exclude[]")"

    # Run command
    all_databases="$(mysql -Bse 'show databases')"

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 && ${all_databases} != "error" ]]; then

        for database in ${all_databases}; do
            [[ ${database_bl} != *"${database}"* ]] && databases="${databases} ${database}"
        done

        # Return
        echo "${databases}" && return 0

    else

        # Return
        echo "Error: Something went wrong listing MySQL databases!" && return 1

    fi

}

################################################################################
# Private: Postgresql databases
#
# Arguments:
#   none
#
# Outputs:
#   ${databases} if ok, 1 on error.
################################################################################

function _psql_databases() {

    local database
    local databases
    local all_databases
    local database_bl

    # Database blacklist
    database_bl="$(_json_read_field "${BROLIT_CONFIG_FILE}" "BACKUPS.config[].databases[].exclude[]")"

    # Get PostgreSQL databases
    all_databases="$(sudo -u postgres -i psql --quiet -c "SELECT datname FROM pg_database WHERE datistemplate = false;" -t)"

    # Check result
    psql_result=$?
    if [[ ${psql_result} -eq 0 && ${all_databases} != "error" ]]; then

        for database in ${all_databases}; do
            [[ ${database_bl} != *"${database}"* ]] && databases="${databases} ${database}"
        done

        # Return
        echo "${databases}" && return 0

    else

        # Return
        echo "Error: Something went wrong listing PostgreSQL databases!" && return 1

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

    local mysql_v_installed
    local psql_v_installed
    local lang_v_installed
    local python_v_installed
    local php_v_installed
    local nodejs_v_installed
    local all_php_data
    local php_default

    ## webserver
    apache_v_installed="$(_apache_check_installed_version)"
    nginx_v_installed="$(_nginx_check_installed_version)"
    webservers_v_installed="${nginx_v_installed}${apache_v_installed}"
    if [[ -z ${webservers_v_installed} ]]; then
        webservers_v_installed="\"no-webserver\""
    else
        # Remove 3 last chars
        webservers_v_installed="${webservers_v_installed::-3}"
    fi

    ## databases
    mysql_v_installed="$(_mysql_check_installed_version)"
    psql_v_installed="$(_psql_check_installed_version)"
    dbs_v_installed="${mysql_v_installed}${psql_v_installed}"
    if [[ -z ${dbs_v_installed} ]]; then
        # empty
        dbs_v_installed=""
    else
        # Remove 3 last chars
        dbs_v_installed="${dbs_v_installed::-3}"
    fi

    ## languages
    php_v_installed="$(_php_check_installed_version)"
    python_v_installed="$(_python_check_installed_version)"
    nodejs_v_installed="$(_nodejs_check_installed_version)"
    lang_v_installed="${php_v_installed}${python_v_installed}${nodejs_v_installed}"
    if [[ -z ${lang_v_installed} ]]; then
        # empty
        lang_v_installed=""
    else
        # Remove 3 last chars
        lang_v_installed="${lang_v_installed::-3}"
    fi

    # Return JSON part
    echo "\"webservers\":[ ${webservers_v_installed} ], \"databases\": [ ${dbs_v_installed} ], \"languages\": [ ${lang_v_installed} ]"

}

################################################################################
# Private: Sites directories
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function _sites_directories() {

    local site
    local site_path
    local directories
    local all_directories
    local site_cert
    local site_size_du
    local site_size

    ## List only directories
    all_directories="$(find "${PROJECTS_PATH}" -maxdepth 1 -mindepth 1 -type d -not -path '*/.*')"

    for site_path in ${all_directories}; do

        site="$(basename "${site_path}")"

        if [[ $(_project_is_ignored "${site}") == "false" ]]; then

            # Size in MBs
            site_size_du="$(du --human-readable --block-size=1M --max-depth=0 "${PROJECTS_PATH}/${site}")"
            site_size="$(echo "${site_size_du}" | awk '{print $1;}')"

            # Project Type
            site_type="$(_project_get_type "${PROJECTS_PATH}/${site}")"

            # Project Installation Type
            install_type="$(_project_get_install_type "${PROJECTS_PATH}/${site}")"

            # Cert
            site_cert="$(_certbot_certificate_get_valid_days "${site}")"

            # Cloudflare
            root_domain="$(_get_root_domain "${site}")"
            site_cf="$(_cloudflare_domain_exists "${root_domain}")"

            # Json
            site_data="{\"name\":\"${site}\" , \"install_type\":\"${install_type}\", \"type\":\"${site_type}\" , \"size\":\"${site_size}\" , \"certificate_days_to_expire\":\"${site_cert}\" , \"domain_on_cloudflare\":\"${site_cf}\"}"

            directories="${directories} , ${site_data}"

        fi

    done

    if [[ ${directories} != "" ]]; then

        # Remove 3 first chars
        directories="${directories:3}"

        # Return
        echo "${directories}" && return 0

    else

        # Return
        echo "\"no-sites\"" && return 0

    fi

}

################################################################################
# Get site backups
#
# Arguments:
#   ${1} = ${chosen_project}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function dropbox_get_site_backups() {

    local chosen_project="${1}"
    local backup_type="${2:-site}"
    local backup_status="${3:-online}"

    local dropbox_chosen_backup_path
    local dropbox_backup_list

    local backup_files

    # Get dropbox backup list
    dropbox_chosen_backup_path="${SERVER_NAME}/projects-${backup_status}/${backup_type}/${chosen_project}"
    dropbox_backup_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_chosen_backup_path}")"

    for backup_file in ${dropbox_backup_list}; do
        # Append
        backup_files="\"${backup_file}\" , ${backup_files}"
    done

    if [[ -n ${backup_files} ]]; then
        # Remove 3 last chars
        backup_files="${backup_files::3}"
    else
        backup_files="\"empty-response\""
    fi

    # Return
    echo "${backup_files}" && return 0

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

    [[ -z ${project_domain} ]] && return 1

    # Check if project is ignored
    if [[ $(_project_is_ignored "${project_domain}") == "true" ]]; then
        backup_date="2022-11-14" # Hardcoded date for ignored projects
        backups_string="\"${backup_date}\":{\"files\":\"project-listed-as-ignored\",\"database\":\"project-listed-as-ignored\"}"
    else
        # Extract project name (adjusted to get the second part of the domain)
        project_name="$(echo "${project_domain}" | cut -d'.' -f2)"

        # Get dropbox backup list for site
        dropbox_site_backup_path="${SERVER_NAME}/projects-online/site/${project_domain}"
        dropbox_site_backup_list="$("${DROPBOX_UPLOADER}" -hq list "${dropbox_site_backup_path}" | grep -Eo "${project_domain}_site-files_[[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2}.*")"

        # Array of project types
        local project_types=("prod" "dev" "stage" "test" "beta" "demo")

        for backup_file in ${dropbox_site_backup_list}; do
            backup_date="$(_backup_get_date "${backup_file}")"

            # Loop through possible project types to find the right database
            for project_type in "${project_types[@]}"; do

                project_db="${project_name}_${project_type}"  
                backup_to_search="${project_db}_database_${backup_date}"

                # Search for database backup
                search_backup_db=$("${DROPBOX_UPLOADER}" -hq list "${SERVER_NAME}/projects-online/database/${project_db}/" | grep "${backup_to_search}" | awk '{print $NF}' || ret="$?")
                backup_db="$(basename "${search_backup_db}")"

                if [[ -z ${backup_db} ]]; then

                    search_backup_db=$("${DROPBOX_UPLOADER}" -hq list "${SERVER_NAME}/projects-online/database/${project_name}_dev/" | grep "${backup_to_search}" | awk '{print $NF}' || ret="$?")
                    backup_db="$(basename "${search_backup_db}")"

                fi

                # If we find a valid database backup, stop looking further
                if [[ -n ${backup_db} ]]; then
                    backups_string="${backups_string}\"${backup_date}\":{\"files\":\"${backup_file}\",\"database\":\"${backup_db}\"} , "
                    break
                fi
            done

            # If no valid database is found after checking all types, mark as not-found
            if [[ -z ${backup_db} ]]; then
                backups_string="${backups_string}\"${backup_date}\":{\"files\":\"${backup_file}\",\"database\":\"not-found\"} , "
            fi
        done

        if [[ -n ${backups_string} ]]; then
            # Remove the last 3 characters
            backups_string="${backups_string::-3}"
        fi
    fi

    # Return JSON
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

    local force="${1}"

    local dropbox_chosen_backup_path
    local dropbox_backup_list
    local backup_files

    local backup_type="site"
    local backup_project=""
    local backup_projects=""

    local timestamp

    local json_output_file="${BROLIT_LITE_OUTPUT_DIR}/dropbox_get_sites_backups.json"

    if [[ ${force} == "true" || ! -f "${json_output_file}" ]]; then

        timestamp="$(_timestamp)"

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

        if [[ -n ${backup_projects} ]]; then
            backup_projects="${backup_projects::-1}" # Remove last char
        else
            backup_projects="\"empty-response\""
        fi

        # Write JSON file
        echo "{ \"check_date\": \"${timestamp}\", ${backup_projects} }" >"${json_output_file}"


    fi

    # Return JSON
    cat "${json_output_file}"

}

################################################################################
#
# Var declarations
#
################################################################################

## Server Name
declare -g SERVER_NAME="${HOSTNAME}"

## Dirs
declare -g BROLIT_MAIN_DIR="/root/brolit-shell"
declare -g BROLIT_PROJECT_CONFIG_PATH="/etc/brolit"

declare -g BROLIT_CONFIG_FILE=~/.brolit_conf.json

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

declare -g PROJECTS_PATH
PROJECTS_PATH="$(_json_read_field "${BROLIT_CONFIG_FILE}" "PROJECTS.path")"

# Version
BROLIT_VERSION="3.3.8"
BROLIT_LITE_VERSION="3.3.8-132"

################################################################################
# Show backups information
#
# Arguments:
#   none
#
# Outputs:
#   json file with backup information
################################################################################

function show_backup_information() {

    local timestamp
    local check_date
    local backup_method
    local projects_backup

    local json_output_file
    local json_config_file="/root/.brolit_conf.json"
    local storage_box_directory="/mnt/storage-box"

    source /root/brolit-shell/libs/borg_storage_controller.sh
    source /root/brolit-shell/libs/local/log_and_display_helper.sh
    source /root/brolit-shell/utils/brolit_configuration_manager.sh
    source /root/brolit-shell/libs/local/json_helper.sh

    _brolit_configuration_load_backup_borg "/root/.brolit_conf.json"

    # Get number of Borg configurations
    local borg_configs_count
    borg_configs_count=$(jq '.BACKUPS.methods[].borg[].config | length' "${json_config_file}")

    # Initialize JSON string
    local json_string="{ \"check_date\": \"$(date -u +"%Y-%m-%dT%H:%M:%S")\", \"backup_method\": \"borg\", \"projects_backup\": { "

    # Loop through each Borg configuration
    for (( i=0; i<"${borg_configs_count}"; i++ )); do

        # Get Borg configuration details
        BACKUP_BORG_USER=$(_json_read_field "${json_config_file}" "BACKUPS.methods[].borg[].config[${i}].user")
        BACKUP_BORG_SERVER=$(_json_read_field "${json_config_file}" "BACKUPS.methods[].borg[].config[${i}].server")
        BACKUP_BORG_PORT=$(_json_read_field "${json_config_file}" "BACKUPS.methods[].borg[].config[${i}].port")
        BACKUP_BORG_GROUP=$(_json_read_field "${json_config_file}" "BACKUPS.methods[].borg[].group")

        # Mount storage box
        mount_storage_box "${storage_box_directory}"

        # Loop through project directories in the mounted storage box
        for project_directory in $(ls --color=never "${storage_box_directory}/${BACKUP_BORG_GROUP}/${HOSTNAME}/projects-online/site"); do

            local project_backup=""
            local backup_files=""
            local backup_date=""
            local last_backup_file=""
            local last_db_backup_file=""
            local backup_db=""

            # Get the last backup file for site files
            last_backup_file=$(borgmatic list --last 1 --format '{archive}{NL}' --match-archives "*" | grep "${project_directory}_site-files" | head -n 1 | sed -r "s/\x1B\[[0-9;]*[mG]//g")

            if [[ -n "${last_backup_file}" ]]; then
                backup_date=$(echo "${last_backup_file}" | grep -Eo '[0-9]{4}-[0-9]{2}-[0-9]{2}')
                backup_files="\"${backup_date}\": { \"files\": \"${last_backup_file}\", \"database\": \"not-found\" }"
            else
                backup_files="\"not-found\": { \"files\": \"not-found\", \"database\": \"not-found\" }"
            fi

            # Get the last database backup file
            last_db_backup_file=$(ls -t "${storage_box_directory}/${BACKUP_BORG_GROUP}/${HOSTNAME}/projects-online/database/${project_directory}/"*.tar.bz2 | head -n 1)

            if [[ -n "${last_db_backup_file}" ]]; then
                backup_db=$(basename "${last_db_backup_file}")
            else
                backup_db="not-found"
            fi

            backup_files="\"${backup_date}\": { \"files\": \"${last_backup_file}\", \"database\": \"${backup_db}\" }"

            if [[ -z ${project_backup} ]]; then
                project_backup="${backup_files}"
            else
                project_backup="${project_backup}, ${backup_files}"
            fi

            if [[ -n ${project_backup} ]]; then
                json_string="${json_string}\"${project_directory}\": { ${project_backup} },"
            fi

        done

        # Unmount storage box
        umount_storage_box "${storage_box_directory}"

    done

    # Finalize JSON string
    json_string="${json_string::-1} } }"

    # Save JSON output to file
    json_output_file="${BROLIT_LITE_OUTPUT_DIR}/show_backups_information.json"
    echo "${json_string}" > "${json_output_file}"

    # Return JSON
    cat "${json_output_file}"

}

################################################################################
# Show firewall status
#
# Arguments:
#   none
#
# Outputs:
#   A json string with ufw status and details.
################################################################################

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

    if [[ -n ${ufw_status_details} ]]; then

        json_string_d="$(_jsonify_output "value-list" "${ufw_status_details}")"

        # Return JSON
        echo "${json_string},{\"ufw-details\": ${json_string_d}}"

    else

        # Return JSON
        echo "${json_string},{\"ufw-details\": \"empty-response\"}"

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

# TODO: read all projects configs and return JSON

function read_project_config() {

    local project_domain="${1}"

    local project_config
    local project_config_file

    local timestamp

    timestamp="$(_timestamp)"

    project_config_file="${BROLIT_PROJECT_CONFIG_PATH}/${project_name}_conf.json"

    if [[ -f ${project_config_file} ]]; then

        project_config="$(<"${project_config_file}")"

        # Write JSON file
        echo "{ \"${timestamp}\" : ${project_config} }" >"${BROLIT_LITE_OUTPUT_DIR}/read_project_config.json"

        # Return JSON
        cat "${BROLIT_LITE_OUTPUT_DIR}/read_project_config.json"

    else

        # Write JSON file
        echo "{ \"${timestamp}\" : { no-site-config } }" >"${BROLIT_LITE_OUTPUT_DIR}/firewall_app_list.json"

        # Return JSON
        cat "${BROLIT_LITE_OUTPUT_DIR}/read_project_config.json"

    fi

}

################################################################################
# Get app details, return JSON
#
# Arguments:
#   nothing
#
# Outputs:
#   json output with firewall apps details
################################################################################

function firewall_get_apps_details() {

    local timestamp

    # ufw app list, replace space with "-" and "/n" with space
    app_list="$(ufw app list | cut -d ":" -f 2 | tr " " "-" | sed -z 's/\n/ /g' | sed -z 's/--//g')"

    # String to JSON
    json_string="$(_jsonify_output "value-list" "${app_list}")"

    timestamp="$(_timestamp)"

    # Write JSON file
    echo "{ \"check_date\": \"${timestamp}\", \"firewall_apps\": ${json_string} }" > "${BROLIT_LITE_OUTPUT_DIR}/firewall_apps_details.json"

    # Return JSON
    cat "${BROLIT_LITE_OUTPUT_DIR}/firewall_apps_details.json"

}

################################################################################
# List package to upgrade, return JSON
#
# Arguments:
#   ${1} = ${force}
#
# Outputs:
#   json output with packages to upgrade
################################################################################

function list_packages_ready_to_upgrade() {

    local force="${1}"

    local timestamp

    local json_output_file="${BROLIT_LITE_OUTPUT_DIR}/list_packages_ready_to_upgrade.json"

    if [[ ${force} == "true" || ! -f "${json_output_file}" ]]; then

        # apt commands
        pkgs="$(apt list --upgradable 2>/dev/null | awk -F/ "{print \$1}" | sed -e '1,/.../ d')"

        pkgs="$(_string_replace_newline_with_spaces "${pkgs}")"

        json_string="$(_jsonify_output "value-list" ${pkgs})" #${pkgs} should pass it without quotes to make it works

        timestamp="$(_timestamp)"

        # Write JSON file
        echo "{ \"check_date\": \"${timestamp}\", \"packages_ready_to_upgrade\": ${json_string} }" > "${json_output_file}"
    fi

    # Return JSON
    cat "${json_output_file}"

}

################################################################################
# Mysql get database size
#
# Arguments:
#   $1 - ${database}
#
# Outputs:
#   ${database_size}
################################################################################

function _mysql_get_database_size() {

    local database="${1}"
    local query

    local database_size

    query="SELECT table_schema, (SUM(data_length)+SUM(index_length)) / 1024 / 1024 FROM information_schema.TABLES WHERE table_schema LIKE \"${database}\" GROUP BY table_schema;"

    # Get database size in MBs
    database_size="$(mysql -Bse "${query}")"
    database_size="$(echo "${database_size}" | awk '{ print $2 }')"

    # Round number
    database_size="$(printf "%.2f\n" "${database_size}")"

    echo "${database_size}"

}

################################################################################
# Show server data
#
# Arguments:
#   ${1} - ${force}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function show_server_data() {

    local force="${1}"

    local server_info
    local server_config
    local mysql_databases
    local mysql_databases_json
    local psql_databases
    local psql_databases_json
    local depends_on
    local server_databases
    local server_sites
    local server_pkgs
    local timestamp

    local json_output_file="${BROLIT_LITE_OUTPUT_DIR}/show_server_data.json"

    if [[ ${force} == "true" || ! -f "${json_output_file}" ]]; then

        timestamp="$(_timestamp)"

        server_info="$(_serverinfo)"

        server_config="$(_brolit_shell_config)"

        server_pkgs="$(_packages_get_data)"

        server_sites="$(_sites_directories)"

        [[ "$(_is_pkg_installed "mysql-server")" == "true" || "$(_is_pkg_installed "mariadb-server")" == "true" ]] && mysql_databases="$(_mysql_databases)"

        # Loop Mysql databases
        db_type="mysql"
        for database in ${mysql_databases}; do

            # Get file size
            db_size="$(_mysql_get_database_size "${database}")"

            # TODO
            depends_on="none"

            mysql_databases_json="{\"name\":\"${database}\" , \"type\":\"${db_type}\", \"size\":\"${db_size}\" , \"depends_on\":\"${depends_on}\"},${mysql_databases_json}"

        done

        [[ "$(_is_pkg_installed "postgresql")" == "true" ]] && psql_databases="$(_psql_databases)"

        # Loop Psql databases
        db_type="postgresql"
        for database in ${psql_databases}; do

            # Get file size
            # TODO: should return only number on KBs
            db_size="$(sudo -u postgres -i psql --quiet -c "SELECT pg_size_pretty( pg_database_size('${database}') );" -t)"
            #db_size="$(_psql_get_database_size "${database}")"

            # TODO
            depends_on="none"

            psql_databases_json="{\"name\":\"${database}\" , \"type\":\"${db_type}\", \"size\":\"${db_size}\" , \"depends_on\":\"${depends_on}\"},${psql_databases_json}"

        done

        mysql_databases_json="$(printf "%s" "${mysql_databases_json%,}")"
        psql_databases_json="$(printf "%s" "${psql_databases_json%,}")"

        server_databases="${mysql_databases_json},${psql_databases_json}"
        # Remove last comma
        server_databases="$(printf "%s" "${server_databases%,}")"
        # Remove first comma
        server_databases="$(printf "%s" "${server_databases#,}")"

        # empty
        [[ -z ${server_databases} ]] && server_databases=""

        # Write JSON file
        echo "{ \"check_date\": \"${timestamp}\", \"server_info\": { ${server_info} }, \"server_pkgs\": { ${server_pkgs} }, \"server_config\": { ${server_config} }, \"databases\": [ ${server_databases} ], \"sites\": [ ${server_sites} ] }" >"${json_output_file}"
        # Remove new lines
        echo "$(tr -d "\n\r" <"${json_output_file}")" >"${json_output_file}"

    fi

    # Return JSON
    cat "${json_output_file}"

}

################################################################################
# Retrieve cron jobs
#
# Argments:
#   none
#
# Outputs:
#   JSON array of cron jobs with schedule, command, and type (user or system)
################################################################################
function retrieve_cron_jobs() {

    local cron_jobs
    local user_cron
    local system_cron

    cron_jobs="["

    user_cron=$(crontab -l 2>/dev/null | grep -v '^\s*#' | grep -v '^\s*$')

    #system_cron=$(grep -v '^\s*#' /etc/crontab /etc/cron.d/* 2>/dev/null | grep -v '^\s*$')

    if [[ ! -z "${user_cron}" ]]; then

        while IFS= read -r cron_line; do
        
            cron_jobs+="{\"schedule\": \"$(echo "${cron_line}" | awk '{print $1,$2,$3,$4,$5}')\", \"command\": \"$(echo "${cron_line}" | cut -d ' ' -f6-)\", \"type\": \"user\"},"
        
        done <<< "$user_cron"
    
    fi


    #if [[ ! -z "${system_cron}" ]]; then
        
        #while IFS= read -r cron_line; do

            #clean_schedule=$(echo "${cron_line}" | sed -E 's/^\/etc\/[^:]*://')
            
            #if [[ $(echo "${clean_schedule}" | awk '{print NF}') -ge 6 ]]; then
                
                #cron_jobs+="{\"schedule\": \"$(echo "${clean_schedule}" | awk '{print $1,$2,$3,$4,$5}')\", \"command\": \"$(echo "${clean_schedule}" | awk '{for(i=6;i<=NF;i++) printf $i" "; print ""}')\", \"type\": \"system\"},"
            
            #fi
        
        #done <<< "$system_cron"
    
    #fi


    cron_jobs="${cron_jobs%,}]"

    echo "${cron_jobs}"
}
