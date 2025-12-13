#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.4
################################################################################
#
# WP-CLI Helper: Perform wpcli tasks.
#
# Refs: https://developer.wordpress.org/cli/commands/
#
################################################################################

################################################################################
# Installs wpcli if not installed (only for not dockerize installation)
#
# Arguments:
#   None
#
# Outputs:
#   0 if wpcli was installed, 1 on error.
################################################################################

function wpcli_install_if_not_installed() {

    local wpcli

    wpcli="$(command -v wp)"

    if [[ ! -x "${wpcli}" ]]; then

        # Install wp-cli
        wpcli_install

        return $?
        
    fi

}

################################################################################
# Check if wpcli is installed (only for not dockerize installation)
#
# Arguments:
#   None
#
# Outputs:
#   "true" if wpcli is installed, "false" if not.
################################################################################

function wpcli_check_if_installed() {

    local wpcli_installed
    local wpcli_v

    wpcli_installed="true"

    wpcli_v="$(wpcli_check_version "default")"

    [[ -z "${wpcli_v}" ]] && wpcli_installed="false"

    # Return
    echo "${wpcli_installed}"

}

################################################################################
# Check wpcli version
#
# Arguments:
#   None
#
# Outputs:
#   wpcli version.
################################################################################

function wpcli_check_version() {

    local install_type="${1}"

    local wpcli_v

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T --rm wordpress-cli wp"

    wpcli_v="$(${wpcli_cmd} --info | grep "WP-CLI version:" | cut -d ':' -f2)"

    # Return
    echo "${wpcli_v}"

}

################################################################################
# Install wpcli (default installation)
#
# Arguments:
#   None
#
# Outputs:
#   0 if wpcli was installed, 1 on error.
################################################################################

function wpcli_install() {

    # Log
    log_event "info" "Installing wp-cli ..." "false"
    display --indent 6 --text "- Installing wp-cli"

    # Download wp-cli
    curl --silent -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        chmod +x wp-cli.phar
        mv wp-cli.phar "/usr/local/bin/wp"

        # Update brolit_conf.json
        json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.php[].extensions[].wpcli" "enabled"

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Installing wp-cli" --result "DONE" --color GREEN
        log_event "info" "wp-cli installed" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Installing wp-cli" --result "FAIL" --color RED
        log_event "error" "wp-cli was not installed!" "false"

        return 1

    fi

}

################################################################################
# Create WordPress user application password
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${user}
#   ${4} = ${app_name}
#
# Outputs:
#   password on success, 1 on error
################################################################################

function wpcli_user_create_application_password() {

    local wp_site="${1}"
    local install_type="${2}"
    local user="${3}"
    local app_name="${4}"

    local app_pass

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    log_event "debug" "Running: ${wpcli_cmd} user application-password create ${user} ${app_name} --porcelain" "false"

    # Command
    app_pass="$(${wpcli_cmd} user application-password create "${user}" "${app_name}" --porcelain)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Creating WP user application password for ${user}" --result "DONE" --color GREEN
        log_event "info" "Creating WordPress user application password for ${user} on site ${wp_site}" "false"

        # Return
        echo "${app_pass}" && return 0

    else

        # Log
        display --indent 6 --text "- Creating WP user application password: ${user}" --result "FAIL" --color RED
        log_event "error" "Creating WordPress user application password for ${user} on site ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# List WordPress user application passwords
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${user}
#   ${4} = ${format}
#
# Outputs:
#   list on success, 1 on error
################################################################################

function wpcli_user_list_application_passwords() {

    local wp_site="${1}"
    local install_type="${2}"
    local user="${3}"
    local format="${4}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    [[ -z ${format} ]] && format="table"

    log_event "debug" "Running: ${wpcli_cmd} user application-password list ${user} --format=${format}" "false"

    # Command
    ${wpcli_cmd} user application-password list "${user}" --format="${format}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Listing WP user application passwords: ${user}" --result "DONE" --color GREEN
        log_event "info" "Listing WordPress user application passwords for ${user} on site ${wp_site}" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Listing WP user application passwords: ${user}" --result "FAIL" --color RED
        log_event "error" "Listing WordPress user application passwords for ${user} on site ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# Delete WordPress user application password
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${user}
#   ${4} = ${uuid}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_user_delete_application_password() {

    local wp_site="${1}"
    local install_type="${2}"
    local user="${3}"
    local uuid="${4}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    log_event "debug" "Running: ${wpcli_cmd} user application-password delete ${user} ${uuid}" "false"

    # Command
    ${wpcli_cmd} user application-password delete "${user}" "${uuid}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Deleting WP user application password: ${uuid}" --result "DONE" --color GREEN
        log_event "info" "Deleting WordPress user application password ${uuid} for ${user} on site ${wp_site}" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Deleting WP user application password: ${uuid}" --result "FAIL" --color RED
        log_event "error" "Deleting WordPress user application password ${uuid} for ${user} on site ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# Update wpcli (default installation)
#
# Arguments:
#   None
#
# Outputs:
#   0 if wpcli was updated, 1 on error.
################################################################################

function wpcli_update() {

    log_event "debug" "Running: wp-cli update" "false"

    wp cli update --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "wp-cli updated" "false"
        display --indent 2 --text "- Updating wp-cli" --result "DONE" --color GREEN

        return 0

    else

        log_event "error" "wp-cli was not updated!" "false"
        display --indent 2 --text "- Updating wp-cli" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Uninstall wpcli (default installation)
#
# Arguments:
#   None
#
# Outputs:
#   0 if wpcli was uninstalled, 1 on error.
################################################################################

function wpcli_uninstall() {

    # Log
    log_event "warning" "Uninstalling wp-cli ..." "false"

    # Command
    rm --recursive --force "/usr/local/bin/wp"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        log_event "info" "wp-cli uninstalled" "false"
        display --indent 6 --text "- Uninstalling wp-cli" --result "DONE" --color GREEN

        return 0

    else

        # Log
        log_event "error" "wp-cli was not uninstalled!" "false"
        display --indent 6 --text "- Uninstalling wp-cli" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Check if a wpcli package is installed
#
# Arguments:
#   ${1} = ${wpcli_package}
#
# Outputs:
#   "true" if wpcli package is installed, "false" if not.
################################################################################

function wpcli_check_if_package_is_installed() {

    local wp_site="${1}"
    local install_type="${2}"
    local wpcli_package="${3}"

    local is_installed="false"
    local wpcli_cmd
    local package_list

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="wp --allow-root"
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T --rm wordpress-cli wp --allow-root"

    package_list="$(${wpcli_cmd} package list --format=json)"

    if echo "${package_list}" | grep -q "\"name\":\"${wpcli_package}\""; then
        is_installed="true"
    fi

    # Return
    echo "${is_installed}"

}

################################################################################
# Install some wp-cli extensions
#
# Arguments:
#   ${1} = ${install_type}
#
# Outputs:
#   none
################################################################################

function wpcli_install_needed_extensions() {

    local install_type="${1}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="wp --allow-root"
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T --rm wordpress-cli wp --allow-root"

    # Rename DB Prefix
    ${wpcli_cmd} package install "iandunn/wp-cli-rename-db-prefix > /dev/null 2>&1"

    # Salts
    ${wpcli_cmd} package install "sebastiaandegeus/wp-cli-salts-comman > /dev/null 2>&1"

    # Vulnerability Scanner
    ${wpcli_cmd} package install "git@github.com:10up/wp-vulnerability-scanner.git > /dev/null 2>&1"

    # WP-Rocket
    ${wpcli_cmd} package install "wp-media/wp-rocket-cli:1.3 > /dev/null 2>&1"

}

################################################################################
# Download WordPress core
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${wp_version} - optional
#
# Outputs:
#   0 if WordPress is downloaded, 1 on error.
################################################################################

function wpcli_core_download() {

    local wp_site="${1}"
    local wp_version="${2}"

    local wpcli_result

    if [[ -n ${wp_site} ]]; then

        if [[ -n ${wp_version} ]]; then

            # wp-cli command
            sudo -u www-data wp --path="${wp_site}" core download --version="${wp_version}" --quiet > /dev/null 2>&1

            # Log
            log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} core download --version=${wp_version}"
            display --indent 6 --text "- Downloading WordPress ${wp_version}"

            sleep 15

            clear_previous_lines "1"

            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then
                display --indent 6 --text "- Downloading WordPress ${wp_version}" --result "DONE" --color GREEN
                display --indent 8 --text "${wp_site}" --tcolor GREEN
                return 0

            else
                display --indent 6 --text "- Downloading WordPress ${wp_version}" --result "FAIL" --color RED
                display --indent 8 --text "${wp_site}" --result "FAIL" --color RED
                return 1
            fi

        else

            # wp-cli command
            sudo -u www-data wp --path="${wp_site}" core download --quiet > /dev/null 2>&1

            # Log
            log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} core download"
            display --indent 6 --text "- Downloading WordPress ${wp_version}"

            sleep 15

            clear_previous_lines "1"

            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then
                display --indent 6 --text "- Downloading WordPress ${wp_version}" --result "DONE" --color GREEN
                return 0

            else
                display --indent 6 --text "- Downloading WordPress ${wp_version}" --result "FAIL" --color RED
                return 1
            fi

        fi

    else

        # Log failure
        error_msg="wp_site can't be empty!"
        log_event "fail" "${error_msg}" "true"

        # Return
        return 1

    fi

}

################################################################################
# Re-install WordPress core (it will not delete others files).
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${wp_version} - optional
#
# Outputs:
#   0 if WordPress is downloaded, 1 on error.
################################################################################

function wpcli_core_reinstall() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_version="${3}"

    local wpcli_result
    local wpcli_cmd
    local wp_version

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    if [[ -n ${wp_site} ]]; then

        # Get wp version
        wp_version="$(wpcli_get_wpcore_version "${wp_site}" "${install_type}")"

        # Log
        log_event "debug" "Running: ${wpcli_cmd} core download --version=${wp_version} --skip-content --force" "false"
        display --indent 6 --text "- WordPress re-install for ${wp_site}"

        # Command
        wpcli_result=$(${wpcli_cmd} core download --version="${wp_version}" --skip-content --force 2>&1 | grep "Success" | cut -d ":" -f1)

        if [[ "${wpcli_result}" = "Success" ]]; then

            # Log Success
            clear_previous_lines "1"
            log_event "info" "WordPress re-installed" "false"
            display --indent 6 --text "- WordPress re-install for ${wp_site}" --result "DONE" --color GREEN

            return 0

        else

            # Log failure
            clear_previous_lines "1"
            log_event "fail" "Something went wrong installing WordPress" "false"
            display --indent 6 --text "- WordPress re-install for ${wp_site}" --result "FAIL" --color RED

            return 1

        fi

    else
        # Log failure
        log_event "fail" "wp_site can't be empty!" "false"
        display --indent 6 --text "- Wordpress re-install for ${wp_site}" --result "FAIL" --color RED
        display --indent 8 --text "wp_site can't be empty"

        return 1

    fi

}

################################################################################
# Update WordPress core
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#
# Outputs:
#   0 if option was configured, 1 on error.
################################################################################

function wpcli_core_update() {

    local wp_site="${1}"
    local install_type="${2}"

    local verify_core_update

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    log_subsection "WP Core Update"

    # Command
    verify_core_update="$(${wpcli_cmd} core update | grep ":" | cut -d ':' -f1)"

    if [[ ${verify_core_update} == "Success" ]]; then

        display --indent 6 --text "- Download new WordPress version" --result "DONE" --color GREEN

        # Translations update
        ${wpcli_cmd} language core update > /dev/null 2>&1
        display --indent 6 --text "- Language update" --result "DONE" --color GREEN

        # Update database
        ${wpcli_cmd} core update-db > /dev/null 2>&1
        display --indent 6 --text "- Database update" --result "DONE" --color GREEN

        # Cache Flush
        ${wpcli_cmd} cache flush > /dev/null 2>&1
        display --indent 6 --text "- Flush cache" --result "DONE" --color GREEN

        # Rewrite Flush
        ${wpcli_cmd} rewrite flush > /dev/null 2>&1
        display --indent 6 --text "- Flush rewrite" --result "DONE" --color GREEN

        # Log success
        log_event "info" "WordPress core updated" "false"
        display --indent 6 --text "- Finishing update" --result "DONE" --color GREEN

        return 0

    else

        # Log failure
        log_event "error" "WordPress update failed" "false"
        log_event "error" "Last command executed: ${wpcli_cmd} core update" "false"
        display --indent 6 --text "- Download new WordPress version" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Verify WordPress core checksum
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#
# Outputs:
#   ${wp_verify_checksum_output_file} if checksum is not ok.
################################################################################

function wpcli_core_verify() {

    local wp_site="${1}"
    local install_type="${2}"

    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"

    local wp_verify_checksum_output_file="${BROLIT_MAIN_DIR}/tmp/wp_verify_checksum_${timestamp}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site} --no-color"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    display --indent 6 --text "- WordPress verify-checksums"
    log_event "debug" "Running: ${wpcli_cmd} core verify-checksums" "false"

    # Verify WordPress Checksums
    ${wpcli_cmd} core verify-checksums 2>&1 | awk -F": " '/File (doesn'\''t|should not) exist/ {print $3}' >"${wp_verify_checksum_output_file}"

    # Replace new lines with ","
    sed -i 's/\r//g; :a;N;$!ba;s/\n/,/g' ${wp_verify_checksum_output_file}

    # Check if file is not empty
    if [[ -s "${wp_verify_checksum_output_file}" ]]; then

        # Log failure
        clear_previous_lines "2"
        display --indent 6 --text "- WordPress verify-checksums" --result "FAIL" --color RED
        display --indent 8 --text "Read the log file for details" --tcolor YELLOW
        display --indent 8 --text "Log file: ${wp_verify_checksum_output_file}" --tcolor YELLOW

        echo "${wp_verify_checksum_output_file}"

        return 1

    else
        # Log success
        clear_previous_lines "1"
        display --indent 6 --text "- WordPress verify-checksums" --result "DONE" --color GREEN

        # Return
        return 0

    fi

}

### wpcli plugins

################################################################################
# Verify installation plugins checksum
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${wp_plugin} could be --all?
#
# Outputs:
#   "true" if wpcli package is installed, "false" if not.
################################################################################

function wpcli_plugin_verify() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_plugin="${3}"

    local wpcli_cmd
    local verify_plugin

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site} --no-color"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color > /dev/null 2>&1"

    [[ -z ${wp_plugin} || ${wp_plugin} == "all" ]] && wp_plugin="--all"

    log_event "debug" "Running: ${wpcli_cmd} plugin verify-checksums ${wp_plugin}" "false"

    mapfile verify_plugin < <(${wpcli_cmd} plugin verify-checksums "${wp_plugin}" 2>&1)

    display --indent 6 --text "- WordPress plugin verify-checksums" --result "DONE" --color GREEN

    # Return an array with wp-cli output
    echo "${verify_plugin[@]}"

}

################################################################################
# Install WordPress plugin
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)
#
# Outputs:
#   0 if plugin was installed, 1 if not.
################################################################################

function wpcli_plugin_install() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_plugin="${3}"

    local wpcli_cmd

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site} --no-color"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    display --indent 6 --text "- Installing plugin ${wp_plugin}"

    # Command
    ${wpcli_cmd} plugin install "${wp_plugin}" --quiet > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Installing plugin ${wp_plugin}" --result "DONE" --color GREEN
        log_event "info" "Plugin ${wp_plugin} installed ok" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Installing plugin ${wp_plugin}" --result "FAIL" --color RED
        log_event "info" "Something went wrong when trying to install plugin: ${wp_plugin}" "false"
        log_event "error" "Last command executed: \"${wpcli_cmd}\" plugin install ${wp_plugin}" "false"

        return 1

    fi

}

################################################################################
# Update WordPress plugin
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file) could be --all
#
# Outputs:
#   0 if plugin was installed, 1 if not.
################################################################################

function wpcli_plugin_update() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_plugin="${3}"

    local wpcli_cmd
    local plugin_update

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site} --no-color"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    [[ -z ${wp_plugin} ]] && plugin="--all"

    mapfile plugin_update < <(${wpcli_cmd} plugin update "${wp_plugin}" --format=json --quiet 2>&1)

    # Return an array with wp-cli output
    echo "${plugin_update[@]}"

}

################################################################################
# Get WordPress plugin version
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${plugin}
#
# Outputs:
#   ${plugin_version}
################################################################################

function wpcli_plugin_get_version() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_plugin="${3}"

    local wpcli_cmd
    local plugin_update

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site} --no-color"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    local plugin_version

    plugin_version="$(${wpcli_cmd} plugin get "${wp_plugin}" --format=json | cut -d "," -f 4 | cut -d ":" -f 2)"

    # Return
    echo "${plugin_version}"

}

################################################################################
# Activate WordPress plugin
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)
#
# Outputs:
#   0 if plugin was activated, 1 if not.
################################################################################

function wpcli_plugin_activate() {

    local wp_site="${1}"
    local install_type="${2}"
    local plugin="${3}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site} --no-color"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    display --indent 6 --text "- Activating plugin ${plugin}"

    # Command
    ${wpcli_cmd} plugin activate "${plugin}" --quiet > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        clear_previous_lines "1"
        display --indent 6 --text "- Activating plugin ${plugin}" --result "DONE" --color GREEN

        return 0

    else
        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Activating plugin ${plugin}" --result "FAIL" --color RED
        log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin activate ${plugin}"

        return 1

    fi

}

################################################################################
# Deactivate WordPress plugin
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)
#
# Outputs:
#   0 if plugin was deactivated, 1 if not.
################################################################################

function wpcli_plugin_deactivate() {

    local wp_site="${1}"
    local install_type="${2}"
    local plugin="${3}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site} --no-color"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    display --indent 6 --text "- Deactivating plugin ${plugin}"
    log_event "debug" "Running: ${wpcli_cmd} plugin deactivate ${plugin}"

    # Command
    ${wpcli_cmd} plugin deactivate "${plugin}" --quiet > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        clear_previous_lines "1"
        display --indent 6 --text "- Deactivating plugin ${plugin}" --result "DONE" --color GREEN

        return 0

    else

        # Log failure
        clear_previous_lines "2"
        display --indent 6 --text "- Deactivating plugin ${plugin}" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Delete WordPress plugin
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)
#
# Outputs:
#   0 if plugin was deleted, 1 if not.
################################################################################

function wpcli_plugin_delete() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_plugin="${3}"

    local wpcli_cmd

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    display --indent 6 --text "- Deleting plugin ${wp_plugin}" --result "DONE" --color GREEN
    log_event "debug" "Running: ${wpcli_cmd} plugin delete ${wp_plugin}" "false"

    # Command
    ${wpcli_cmd} plugin delete "${wp_plugin}" --quiet > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Deleting plugin ${wp_plugin}" --result "DONE" --color GREEN
        log_event "info" "Deleting plugin ${wp_plugin} finished ok" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Deleting plugin ${wp_plugin}" --result "FAIL" --color RED
        log_event "debug" "Something went wrong trying to delete plugin: ${wp_plugin}" "false"

        return 1

    fi

}

################################################################################
# Check if plugin is active
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)
#
# Outputs:
#   0 if plugin was active, 1 if not.
################################################################################

function wpcli_plugin_is_active() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_plugin="${3}"

    local wpcli_cmd

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    display --indent 6 --text "- Checking plugin ${wp_plugin} status"
    log_event "debug" "Running: ${wpcli_cmd} plugin is-active ${wp_plugin}" "false"

    # Command
    ${wpcli_cmd} plugin is-active "${wp_plugin}" > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        clear_previous_lines "1"
        display --indent 6 --text "- Plugin status" --result "ACTIVE" --color GREEN
        log_event "info" "Plugin ${wp_plugin} is active" "false"

        return 0

    else

        # Log failure
        clear_previous_lines "1"
        display --indent 6 --text "- Plugin status" --result "DEACTIVE" --color RED
        log_event "info" "Plugin ${plugin} is deactive" "false"

        return 1

    fi

}

################################################################################
# Check if plugin is installed
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${plugin}
#
# Outputs:
#   0 if plugin is installed, 1 if not.
################################################################################

function wpcli_plugin_is_installed() {

    local wp_site="${1}"
    local install_type="${2}"
    local plugin="${3}"

    local wpcli_cmd

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # wp-cli command
    ${wpcli_cmd} plugin is-installed "${plugin}" > /dev/null 2>&1

    # Return
    echo $?

}

################################################################################
# List installed plugins
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${status} (active, inactive, active-network, must-use, dropin)
#   ${4} = ${format} (table, csv, count, json, yaml)
#
# Outputs:
#   0 if plugin is installed, 1 if not.
################################################################################

function wpcli_plugin_list() {

    local wp_site="${1}"
    local install_type="${2}"
    local status="${3}"
    local format="${4}"

    local wpcli_cmd

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    [[ -z ${status} ]] && status="active"
    [[ -z ${format} ]] && format="table"

    local plugin_list_output
    local exitstatus

    # Log
    log_subsection "WP Plugins List"
    log_event "debug" "Running: ${wpcli_cmd} plugin list --status=${status} --format=${format}" "false"

    # Command - capture output and suppress PHP warnings
    plugin_list_output=$(${wpcli_cmd} plugin list --status="${status}" --format="${format}" 2>/dev/null)
    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then
        # Display the clean output
        echo "${plugin_list_output}"
        log_event "info" "Plugin list retrieved successfully" "false"
        return 0
    else
        display --indent 6 --text "- Getting plugin list" --result "FAIL" --color RED
        log_event "error" "Failed to retrieve plugin list" "false"
        return 1
    fi

}

################################################################################
# Force plugin reinstall
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)
#
# Outputs:
#   0 if plugin was deleted, 1 if not.
################################################################################

function wpcli_plugin_reinstall() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_plugin="${3}"

    local verify_plugin
    local wpcli_cmd

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    log_subsection "WP Re-install Plugins"

    if [[ -z ${wp_plugin} || ${wp_plugin} == "all" ]]; then

        # Get list of plugins first
        local plugin_list_output
        local plugin
        local exitstatus
        local success_count=0
        local fail_count=0
        local plugins_array

        plugin_list_output=$(eval "${wpcli_cmd}" plugin list --field=name 2>/dev/null)

        # Store plugins in array to avoid stdin conflicts
        mapfile -t plugins_array <<< "${plugin_list_output}"

        # Loop through each plugin and reinstall individually
        for plugin in "${plugins_array[@]}"; do

            [[ -z ${plugin} ]] && continue

            display --indent 6 --text "- Re-installing ${plugin}"
            log_event "debug" "Running: ${wpcli_cmd} plugin install ${plugin} --force --quiet" "false"

            eval "${wpcli_cmd}" plugin install "${plugin}" --force --quiet < /dev/null > /dev/null 2>&1

            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then
                clear_previous_lines "1"
                display --indent 6 --text "- Re-installing ${plugin}" --result "DONE" --color GREEN
                log_event "info" "Plugin ${plugin} re-installed successfully" "false"
                ((success_count++))
            else
                clear_previous_lines "1"
                display --indent 6 --text "- Re-installing ${plugin}" --result "FAIL" --color RED
                log_event "error" "Error re-installing plugin ${plugin}" "false"
                ((fail_count++))
            fi

        done

        # Summary
        log_event "info" "Re-install summary: ${success_count} successful, ${fail_count} failed" "false"

    else

        local exitstatus

        log_event "debug" "Running: ${wpcli_cmd} plugin install ${wp_plugin} --force --quiet"
        display --indent 6 --text "- Re-installing plugin ${wp_plugin}"

        eval "${wpcli_cmd}" plugin install "${wp_plugin}" --force --quiet > /dev/null 2>&1

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
            clear_previous_lines "1"
            display --indent 6 --text "- Re-installing plugin ${wp_plugin}" --result "DONE" --color GREEN
            log_event "info" "Plugin ${wp_plugin} re-installed successfully" "false"
        else
            clear_previous_lines "1"
            display --indent 6 --text "- Re-installing plugin ${wp_plugin}" --result "FAIL" --color RED
            log_event "error" "Error re-installing plugin ${wp_plugin}" "false"
        fi

    fi

}

# The idea is that when you update WordPress or a plugin, get the actual version,
# then run a dry-run update, if success, update but show a message if you want to
# persist the update or want to do a rollback

function wpcli_plugin_version_rollback() {

    # TODO: implement this
    # ${1}= wp_site
    # ${2} = wp_plugin
    # ${3}= wp_plugin_v (version to install)

    #sudo -u www-data wp --path="${wp_site}" plugin update "${wp_plugin}" --version="${wp_plugin_v}" --dry-run
    #sudo -u www-data wp --path="${wp_site}" plugin update "${wp_plugin}" --version="${wp_plugin_v}"

    wpcli_plugin_get_version "" ""

}

### wpcli themes

################################################################################
# Install WordPress theme
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${theme}
#
# Outputs:
#   0 if plugin was deleted, 1 if not.
################################################################################

function wpcli_theme_install() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_theme="${3}"

    local wpcli_cmd

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} theme install ${wp_theme} --activate"

    # Command
    ${wpcli_cmd} theme install "${wp_theme}" --activate > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        log_event "info" "Theme ${wp_theme} installed" "false"
        display --indent 6 --text "- Installing and activating theme ${wp_theme}" --result "DONE" --color GREEN
        
        return 0

    else

        # Log failure
        log_event "error" "Something went wrong when trying to install theme: ${wp_theme}" "false"
        display --indent 6 --text "- Installing and activating theme ${wp_theme}" --result "FAIL" --color RED
        
        return 1

    fi

}

################################################################################
# Delete WordPress theme
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${theme}
#
# Outputs:
#   0 if plugin was deleted, 1 if not.
################################################################################

function wpcli_theme_delete() {

    local wp_site="${1}"
    local install_type="${2}"
    local theme="${3}"

    local wpcli_cmd

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} theme delete ${theme}" "false"

    # Command
    ${wpcli_cmd} theme delete "${theme}" --quiet > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        log_event "info" "Theme ${theme} deleted" "false"
        display --indent 6 --text "- Deleting theme ${theme}" --result "DONE" --color GREEN

        return 0

    else

        # Log failure
        log_event "error" "Something went wrong when trying to delete theme: ${theme}" "false"
        display --indent 6 --text "- Deleting theme ${theme}" --result "FAIL" --color RED

        return 1

    fi

}

### wpcli scripts

################################################################################
# Startup script (post-install actions)
#
# Arguments:
#   ${1} = ${wp_site}           - Site path
#   ${2} = ${install_type}      - Install type
#   ${3} = ${site_url}          - Site URL
#   ${4} = ${site_name}         - Site Display Name
#   ${5} = ${wp_user_name}
#   ${6} = ${wp_user_passw}
#   ${7} = ${wp_user_mail}
#
# Outputs:
#   0 if plugin was deleted, 1 if not.
################################################################################

function wpcli_run_startup_script() {

    local wp_site="${1}"
    local install_type="${2}"
    local site_url="${3}"
    local site_name="${4}"
    local wp_user_name="${5}"
    local wp_user_passw="${6}"
    local wp_user_mail="${7}"

    local wpcli_cmd

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Site Name
    if [[ -z ${site_name} ]]; then
        site_name="$(whiptail_input "Site Name" "Insert a site name for the website. Example: My Website" "")"
        [[ $? -eq 1 || -z ${site_name} ]] && return 1
    fi

    # Site URL
    # TODO: check if receive a domain or a url like: https://siteurl.com
    if [[ -z ${site_url} ]]; then
        site_url="$(whiptail_input "Site URL" "Insert the site URL. Example: https://mydomain.com" "")"
        [[ $? -eq 1 || -z ${site_url} ]] && return 1
    fi

    # First WordPress Admin user
    if [[ -z ${wp_user_name} ]]; then
        wp_user_name="$(whiptail_input "WordPress User" "Insert a name for the WordPress administrator:" "")"
        [[ $? -eq 1 || -z ${wp_user_name} ]] && return 1
    fi

    # WordPress User Password
    if [[ -z ${wp_user_passw} ]]; then
        local suggested_passw
        suggested_passw="$(openssl rand -hex 12)"
        wp_user_passw="$(whiptail_input "WordPress User Password" "Select this random generated password or insert a new one: " "${suggested_passw}")"
        [[ $? -eq 1 || -z ${wp_user_passw} ]] && return 1
    fi

    # WordPress User Email
    if [[ -z ${wp_user_mail} ]]; then
        wp_user_mail_status="1"
        # $wp_user_mail_status = 1 ask user again
        while [[ ${wp_user_mail_status} -eq 1 ]]; do
            wp_user_mail="$(whiptail_input "WordPress User Mail" "Insert a valid user email:" "")"
            [[ $? -eq 1 ]] && return 1
            validator_email_format "${wp_user_mail}"
            wp_user_mail_status=$?
        done

    fi

    log_event "debug" "Running: ${wpcli_cmd} core install --url=${site_url} --title=${site_name} --admin_user=${wp_user_name} --admin_password=${wp_user_passw} --admin_email=${wp_user_mail}"

    # Install WordPress Site
    ${wpcli_cmd} core install --url="${site_url}" --title="${site_name}" --admin_user="${wp_user_name}" --admin_password="${wp_user_passw}" --admin_email="${wp_user_mail}"

    if [[ ${exitstatus} -eq 0 ]]; then

        clear_previous_lines "2"
        display --indent 6 --text "- WordPress site creation" --result "DONE" --color GREEN

        # Force siteurl and home options value
        ${wpcli_cmd} option update home "${site_url}" --quiet
        ${wpcli_cmd} option update siteurl "${site_url}" --quiet
        display --indent 6 --text "- Updating URL on database" --result "DONE" --color GREEN

        # Delete default post, page, and comment
        ${wpcli_cmd} site empty --yes --quiet
        display --indent 6 --text "- Deleting default content" --result "DONE" --color GREEN

        # Delete default themes
        ${wpcli_cmd} theme delete twentyseventeen --quiet
        ${wpcli_cmd} theme delete twentynineteen --quiet
        display --indent 6 --text "- Deleting default themes" --result "DONE" --color GREEN

        # Delete default plugins
        ${wpcli_cmd} plugin delete akismet --quiet
        ${wpcli_cmd} plugin delete hello --quiet
        display --indent 6 --text "- Deleting default plugins" --result "DONE" --color GREEN

        # Changing permalinks structure
        ${wpcli_cmd} rewrite structure '/%postname%/' --quiet
        display --indent 6 --text "- Changing rewrite structure" --result "DONE" --color GREEN

        # Changing comment status
        ${wpcli_cmd} option update default_comment_status closed --quiet
        display --indent 6 --text "- Setting comments off" --result "DONE" --color GREEN

        wp_change_permissions "${wp_site}"

        return 0

    else

        clear_previous_lines "2"
        display --indent 6 --text "- WordPress site creation" --result "FAIL" --color RED
        display --indent 8 --text "Please, read the log file." --tcolor RED

        # Return
        return 1

    fi

}

################################################################################
# Create new config
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${database}
#   ${3} = ${db_user_name}
#   ${4} = ${db_user_passw}
#   ${4} = ${wp_locale}
#
# Outputs:
#   0 if plugin was deleted, 1 if not.
################################################################################

function wpcli_create_config() {

    local wp_site="${1}"
    local database="${2}"
    local db_user_name="${3}"
    local db_user_passw="${4}"
    local wp_locale="${5}"
    local install_type="${6}"
    local wpcli_cmd

    # Default locale
    [[ -z ${wp_locale} ]] && wp_locale="es_ES"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} config create --dbname=${database} --dbuser=${db_user_name} --dbpass=${db_user_passw} --locale=${wp_locale}" "false"

    # wp-cli command
    ${wpcli_cmd} config create --dbname="${database}" --dbuser="${db_user_name}" --dbpass="${db_user_passw}" --locale="${wp_locale}" --quiet > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        log_event "info" "wp-config.php created" "false"
        display --indent 6 --text "- Creating wp-config" --result "DONE" --color GREEN

        return 0

    else

        # Log failure
        log_event "error" "Something went wrong when trying to create wp-config.php" "false"
        display --indent 6 --text "- Creating wp-config" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Set/shuffle salts
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#
# Outputs:
#   0 if salts where set/shuffle, 1 if not.
################################################################################

function wpcli_shuffle_salts() {

    local wp_site="${1}"
    local install_type="${2}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp"

    local error_output
    local exitstatus
    local wp_config_path
    local original_permissions
    local original_owner
    local permissions_changed=false

    # Determine wp-config.php path
    # For both docker and default installations, wp-config.php is in the wp_site directory
    wp_config_path="${wp_site}/wp-config.php"

    log_event "debug" "Looking for wp-config.php at: ${wp_config_path}" "false"

    log_event "debug" "Running: ${wpcli_cmd} config shuffle-salts" "false"
    display --indent 6 --text "- Shuffle salts"

    # Command - capture stderr to get error messages
    error_output=$(${wpcli_cmd} config shuffle-salts 2>&1)
    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        log_event "info" "Salts shuffled successfully" "false"
        clear_previous_lines "1"
        display --indent 6 --text "- Shuffle salts" --result "DONE" --color GREEN

        return 0

    else

        # Check if error is due to wp-config.php not being writable
        if echo "${error_output}" | grep -qi "not writable"; then

            log_event "info" "wp-config.php is not writable, attempting to fix permissions temporarily" "false"
            clear_previous_lines "1"
            display --indent 6 --text "- Shuffle salts (fixing permissions)"

            # Check if wp-config.php exists
            if [[ ! -f ${wp_config_path} ]]; then
                log_event "error" "wp-config.php not found at ${wp_config_path}" "false"
                clear_previous_lines "1"
                display --indent 6 --text "- Shuffle salts" --result "FAIL" --color RED
                display --indent 8 --text "wp-config.php not found" --tcolor YELLOW
                return 1
            fi

            # Save original permissions and owner
            original_permissions=$(stat -c "%a" "${wp_config_path}")
            original_owner=$(stat -c "%U:%G" "${wp_config_path}")
            log_event "debug" "Original permissions: ${original_permissions}, owner: ${original_owner}" "false"

            # Make wp-config.php writable by changing owner to www-data or setting 666
            if [[ ${install_type} == "docker"* ]]; then
                # For Docker, change owner to 33:33 (www-data inside container)
                chown 33:33 "${wp_config_path}"
                log_event "debug" "Changed owner to 33:33 for shuffle operation" "false"
            else
                # For default installation, ensure it's writable by www-data
                chown www-data:www-data "${wp_config_path}"
                log_event "debug" "Changed owner to www-data:www-data for shuffle operation" "false"
            fi

            # Also ensure permissions allow writing
            chmod 644 "${wp_config_path}"
            permissions_changed=true
            log_event "debug" "Changed permissions to 644 for shuffle operation" "false"

            # Try shuffle again
            error_output=$(${wpcli_cmd} config shuffle-salts 2>&1)
            exitstatus=$?

            # Restore original permissions and owner
            chmod "${original_permissions}" "${wp_config_path}"
            chown "${original_owner}" "${wp_config_path}"
            log_event "debug" "Restored original permissions: ${original_permissions} and owner: ${original_owner}" "false"

            if [[ ${exitstatus} -eq 0 ]]; then
                # Log success
                log_event "info" "Salts shuffled successfully after fixing permissions" "false"
                clear_previous_lines "1"
                display --indent 6 --text "- Shuffle salts" --result "DONE" --color GREEN
                return 0
            else
                # Still failed after permission fix
                log_event "error" "Failed to shuffle salts even after fixing permissions" "false"
                log_event "error" "Error output: ${error_output}" "false"
                clear_previous_lines "1"
                display --indent 6 --text "- Shuffle salts" --result "FAIL" --color RED
                display --indent 8 --text "Failed even with correct permissions" --tcolor YELLOW
                return 1
            fi

        else

            # Extract the error reason if present
            local error_reason=""
            if echo "${error_output}" | grep -q "Reason:"; then
                error_reason=$(echo "${error_output}" | grep "Reason:" | sed 's/^Reason: //')
            fi

            # Log failure with details
            log_event "error" "Failed to shuffle salts" "false"
            log_event "error" "Error output: ${error_output}" "false"

            clear_previous_lines "1"
            display --indent 6 --text "- Shuffle salts" --result "FAIL" --color RED

            # Show error reason to user
            if [[ -n ${error_reason} ]]; then
                display --indent 8 --text "${error_reason}" --tcolor YELLOW
            fi

            return 1

        fi

    fi

}

################################################################################
# Delete not core files
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#
# Outputs:
#   0 if core files were deleted, 1 if not.
################################################################################

function wpcli_delete_not_core_files() {

    local wp_site="${1}"
    local install_type="${2}"

    local count=0
    local wpcli_core_verify_results
    local wpcli_core_verify_result_file

    display --indent 6 --text "- Scanning for suspicious WordPress files" --result "DONE" --color GREEN

    wpcli_core_verify_results="$(wpcli_core_verify "${wp_site}" "${install_type}")"

    # Check if there are suspicious files
    if [[ -n ${wpcli_core_verify_results} ]]; then

        while IFS=, read -ra path_array; do

            for wpcli_core_verify_result_file in "${path_array[@]}"; do

                # Delete file
                rm --force "${wp_site}/${wpcli_core_verify_result_file//$'\r'/}"

                # Increment counter
                count=$((count + 1))

                # Log
                log_event "info" "Deleting not core file: ${wp_site}/${wpcli_core_verify_result_file}" "false"
                display --indent 8 --text "Suspicious file: ${wpcli_core_verify_result_file}"

            done

        done <"${wpcli_core_verify_results}"

        # Log
        log_event "info" "${count} unknown files in WordPress deleted!" "false"
        display --indent 6 --text "- Deleting suspicious WordPress files" --result "DONE" --color GREEN
        display --indent 8 --text "${count} unknown files in WordPress deleted!" --color YELLOW

    else

        display --indent 8 --text "No suspicious files found" --color GREEN

        return 0

    fi

}

################################################################################
# Clean non-core files and reinstall WordPress core
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function wpcli_clean_and_reinstall_core() {

    local wp_site="${1}"
    local install_type="${2}"

    local wp_version
    local delete_result

    # Step 1: Get current WordPress version
    display --indent 6 --text "- Getting current WordPress version"
    wp_version="$(wpcli_get_wpcore_version "${wp_site}" "${install_type}")"

    exitstatus=$?
    if [[ ${exitstatus} -ne 0 || -z ${wp_version} ]]; then
        log_event "error" "Failed to get WordPress version" "false"
        display --indent 6 --text "- Getting WordPress version" --result "FAIL" --color RED
        return 1
    fi

    log_event "info" "Current WordPress version: ${wp_version}" "false"

    # Step 2: Delete non-core files
    wpcli_delete_not_core_files "${wp_site}" "${install_type}"
    delete_result=$?

    # Step 3: Reinstall WordPress core with the same version
    if [[ ${delete_result} -eq 0 ]]; then
        echo ""
        log_event "info" "Re-installing WordPress core version ${wp_version}" "false"

        wpcli_core_reinstall "${wp_site}" "${install_type}" "${wp_version}"
        exitstatus=$?

        if [[ ${exitstatus} -eq 0 ]]; then
            echo ""
            log_event "success" "WordPress core cleaned and reinstalled successfully" "false"
            display --indent 6 --text "- Clean & Reinstall WordPress Core" --result "DONE" --color GREEN
            display --indent 8 --text "WordPress ${wp_version} reinstalled successfully" --tcolor GREEN
            return 0
        else
            log_event "error" "Failed to reinstall WordPress core" "false"
            display --indent 6 --text "- Reinstalling WordPress Core" --result "FAIL" --color RED
            return 1
        fi
    else
        log_event "warning" "Skipping WordPress reinstall due to deletion errors" "false"
        return 1
    fi

}

################################################################################
# Get maintenance mode status
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#
# Outputs:
#   ${maintenance_mode_status}
################################################################################

function wpcli_maintenance_mode_status() {

    local wp_site="${1}"
    local install_type="${2}"

    local wpcli_cmd
    local maintenance_mode_status

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color > /dev/null 2>&1"

    log_event "debug" "Running: ${wpcli_cmd} maintenance-mode status" "false"

    # Command
    maintenance_mode_status="$(${wpcli_cmd} maintenance-mode status)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${maintenance_mode_status}"

        return 0

    else

        return 1

    fi

}

################################################################################
# Set maintenance mode status
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${mode} - activate/deactivate
#
# Outputs:
#   ${maintenance_mode_status}
################################################################################

function wpcli_maintenance_mode_set() {

    local wp_site="${1}"
    local install_type="${2}"
    local mode="${3}"

    local wpcli_cmd
    local maintenance_mode

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color > /dev/null 2>&1"

    log_event "debug" "Running: ${wpcli_cmd} maintenance-mode ${mode}" "false"

    # Command
    maintenance_mode="$(${wpcli_cmd} maintenance-mode "${mode}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${maintenance_mode}"

        return 0

    else

        return 1

    fi

}

################################################################################
# Seo-yoast reindex
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#
# Outputs:
#   0 if the reindex was successful, 1 if not.
################################################################################

function wpcli_seoyoast_reindex() {

    local wp_site="${1}"
    local install_type="${2}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    log_subsection "WP SEO Yoast Re-index"

    # Log
    display --indent 6 --text "- Running yoast re-index"
    log_event "debug" "Running: ${wpcli_cmd} yoast index --reindex" "false"

    # Command
    ${wpcli_cmd} yoast index --reindex > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Running yoast re-index" --result "DONE" --color GREEN
        log_event "info" "Yoast re-index done!" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Running yoast re-index" --result "FAIL" --color RED
        log_event "error" "Yoast re-index failed!" "false"

        return 1

    fi

}

################################################################################
# Plugin installer menu
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#
# Outputs:
#   none
################################################################################

function wpcli_default_plugins_installer() {

    local wp_site="${1}"
    local install_type="${2}"

    local wp_defaults_file="/root/.brolit_wp_defaults.json"

    # Check if wp_defaults_file exists
    if [[ ! -f "${wp_defaults_file}" ]]; then

        # Log
        log_event "warning" "File ${wp_defaults_file} not found!" "false"

        # Make a copy of the default file
        cp "${BROLIT_MAIN_DIR}/config/brolit/brolit_wp_defaults.json" "${wp_defaults_file}"

        # Whiptail message
        whiptail_message "WP Plugin Installer" "The file ${wp_defaults_file} was not found. A copy of the default file was created. Please edit the file and press enter."
        [[ $? -eq 1 ]] && return 1

    fi

    whiptail_message "WP Plugin Installer" "This installer will install and activate the WordPress plugins configured on the file: ${wp_defaults_file}"
    [[ $? -eq 1 ]] && return 1

    _load_brolit_wp_defaults "${wp_site}" "${install_type}" "${wp_defaults_file}"

}

################################################################################
# Plugin installer
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${wp_defaults_file}
#
# Outputs:
#   none
################################################################################

function _load_brolit_wp_defaults() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_defaults_file="${3}"

    local plugin
    local plugin_source
    local plugin_url
    local plugin_activate

    local index=0

    local plugins_count

    log_subsection "WP Plugin Installer"

    # Count json_read_field "${wp_defaults_file}" "PLUGINS[].slug
    plugins_count="$(json_read_field "${wp_defaults_file}" "PLUGINS[].slug" | wc -l)"
    plugins="$(json_read_field "${wp_defaults_file}" "PLUGINS[].slug")"

    log_event "debug" "Plugins found: ${plugins_count}" "false"

    # For each plugin
    for plugin in ${plugins}; do

        log_event "debug" "Working with plugin: ${plugin}" "false"

        # Get plugin source
        plugin_source="$(json_read_field "${wp_defaults_file}" "PLUGINS[$index].source[].type")"

        # If source is != official
        if [[ "${plugin_source}" == "official" ]]; then

            # Install plugin
            wpcli_plugin_install "${wp_site}" "${install_type}" "${plugin}"

        else

            # Get plugin url
            plugin_url="$(json_read_field "${wp_defaults_file}" "PLUGINS[$index].source[].config[].url")"

            # Install plugin
            wpcli_plugin_install "${wp_site}" "${install_type}" "${plugin_url}"

        fi

        # Get plugin activate
        plugin_activate="$(json_read_field "${wp_defaults_file}" "PLUGINS[$index].activated")"

        # Activate plugin
        [[ "${plugin_activate}" == "true" ]] && wpcli_plugin_activate "${wp_site}" "${install_type}" "${plugin}"

        # Increment
        index=$((index + 1))

    done

}

################################################################################
# Get WordPress Core version
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#
# Outputs:
#   ${core_version}
################################################################################

function wpcli_get_wpcore_version() {

    local wp_site="${1}"
    local install_type="${2}"

    local core_version

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} core version" "false"
    display --indent 6 --text "- Getting WordPress core version"

    # Command
    core_version="$(${wpcli_cmd} core version)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        clear_previous_lines "1"
        log_event "debug" "WordPress core version: ${core_version}" "false"
        display --indent 6 --text "- Getting WordPress core version" --result "DONE" --color GREEN
        display --indent 8 --text "WordPress core version: ${core_version}"

        # Return
        echo "${core_version//$'\r'/}" && return 0

    else

        # Log failure
        clear_previous_lines "1"
        log_event "error" "Getting WordPress core version" "false"
        display --indent 6 --text "- Getting WordPress core version" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Get database prefix
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#
# Outputs:
#   ${db_prefix}
################################################################################

function wpcli_db_get_prefix() {

    local wp_site="${1}"
    local install_type="${2}"

    local wpcli_cmd
    local db_prefix

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    display --indent 6 --text "- Getting database prefix"

    # Command
    db_prefix="$(${wpcli_cmd} db prefix)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${db_prefix}" && return 0

    else

        # Log
        display --indent 6 --text "- Getting database prefix" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Check database credentials
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#
# Outputs:
#   ${db_check}
################################################################################

function wpcli_db_check() {

    local wp_site="${1}"
    local install_type="${2}"

    local db_check

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    display --indent 6 --text "- Checking database credentials"

    # Command
    db_check="$(sudo -u www-data "${wpcli_cmd}" --path="${wp_site}" db check)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${db_check}" && return 0

    else

        # Log failure
        display --indent 6 --text "- Checking database credentials" --result "FAIL" --color RED
        display --indent 8 --text "Can't connect to database."
        log_event "error" "Running: sudo -u www-data wp --path=${wp_site} db check" "false"

        return 1

    fi

}

################################################################################
# Check database credentials
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${db_prefix}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_db_change_tables_prefix() {

    local wp_site="${1}"
    local install_type="${2}"
    local db_prefix="${3}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    display --indent 6 --text "- Changing tables prefix"
    log_event "debug" "Running: ${wpcli_cmd} rename-db-prefix ${db_prefix}" "false"

    # Command
    ${wpcli_cmd} rename-db-prefix "${db_prefix}" --no-confirm > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        display --indent 6 --text "- Changing tables prefix" --result "DONE" --color GREEN
        display --indent 8 --text "New tables prefix ${TABLES_PREFIX}"

        return 0

    else

        display --indent 6 --text "- Changing tables prefix" --result "FAIL" --color RED
        log_event "error" "Changing tables prefix for site ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# Search and replace
#
#   Ref: https://developer.wordpress.org/cli/commands/search-replace/
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${search}
#   ${4} = ${replace}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_search_and_replace() {

    local wp_site="${1}"
    local install_type="${2}"
    local search="${3}"
    local replace="${4}"

    local wp_site_url

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Folder Name need to be the Site URL
    wp_site_url="$(basename "${wp_site}")"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} core is-installed --network" "false"

    # Command
    ${wpcli_cmd} core is-installed --network

    is_network=$?
    if [[ ${is_network} -eq 0 ]]; then

        log_event "debug" "Running: ${wpcli_cmd} search-replace ${search} ${replace} --network" "false"

        wpcli_result="$(${wpcli_cmd} search-replace --url=https://"${wp_site_url}" "${search}" "${replace}" --network)"

    else

        log_event "debug" "Running: ${wpcli_cmd} search-replace ${search} ${replace}" "false"

        wpcli_result="$(${wpcli_cmd} search-replace "${search}" "${replace}")"

    fi

    error_found="$(echo "${wpcli_result}" | grep "Error")"
    if [[ ${error_found} == "" ]]; then

        # Log
        log_event "info" "Search and replace finished ok" "false"
        display --indent 6 --text "- Running search and replace" --result "DONE" --color GREEN
        display --indent 8 --text "${search} was replaced by ${replace}" --tcolor YELLOW

        # Cache Flush
        ${wpcli_cmd} cache flush --quiet
        display --indent 6 --text "- Flush cache" --result "DONE" --color GREEN

        # Rewrite Flush
        ${wpcli_cmd} rewrite flush --quiet
        display --indent 6 --text "- Flush rewrite" --result "DONE" --color GREEN

        return 0

    else

        # Log
        log_event "error" "Something went wrong running search and replace!" "false"
        display --indent 6 --text "- Running search and replace" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Clean Database
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${search}
#   ${3} = ${replace}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_clean_database() {

    local wp_site="${1}"
    local install_type="${2}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    log_subsection "WP Clean Database"

    log_event "info" "Executing: ${wpcli_cmd} transient delete --expired --allow-root" "false"

    # Command
    ${wpcli_cmd} transient delete --expired --allow-root --quiet > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        display --indent 2 --text "- Deleting transient" --result "DONE" --color GREEN

        # Command
        ${wpcli_cmd} cache flush --allow-root --quiet

        display --indent 2 --text "- Flushing cache" --result "DONE" --color GREEN

        return 0

    else

        display --indent 2 --text "- Deleting transient" --result "FAIL" --color RED
        log_event "error" "Deleting transient for site ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# Database export
#
# Arguments:
#   ${1} = ${wp_site} (site path)
#   ${2} = ${install_type}
#   ${3} = ${dump_file}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_export_database() {

    local wp_site="${1}"
    local install_type="${2}"
    local dump_file="${3}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} db export ${dump_file}" "false"

    # Command
    ${wpcli_cmd} db export "${dump_file}" --quiet > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        display --indent 6 --text "- Exporting database ${wp_site}" --result "DONE" --color GREEN

        return 0

    else

        display --indent 6 --text "- Exporting database ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Exporting database for site ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# List WordPress users
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${role} (optional - filter by role: administrator, editor, author, contributor, subscriber, or 'all')
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_user_list() {

    local wp_site="${1}"
    local install_type="${2}"
    local role="${3}"
    local role_filter=""
    local user_list

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error:
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Add role filter if specified
    [[ -n ${role} && ${role} != "all" ]] && role_filter="--role=${role}"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} user list --fields=user_login,user_email,roles --format=csv ${role_filter}" "false"

    # Command - capture output and suppress PHP warnings (2>/dev/null redirects stderr)
    # Using CSV format and then formatting with column for better readability
    user_list=$(${wpcli_cmd} user list --fields=user_login,user_email,roles --format=csv --quiet ${role_filter} 2>/dev/null | column -t -s ",")

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Display the user list with proper indentation
        echo ""
        echo "      USERNAME          EMAIL                    ROLE"
        echo "      ────────────────  ───────────────────────  ──────────────"
        while IFS= read -r line; do
            # Skip the header line from CSV output
            if [[ "${line}" != "user_login"* ]]; then
                echo "      ${line}"
            fi
        done <<< "${user_list}"
        echo ""

        if [[ -n ${role} && ${role} != "all" ]]; then
            display --indent 6 --text "- Listing ${role} users" --result "DONE" --color GREEN
        else
            display --indent 6 --text "- Listing users" --result "DONE" --color GREEN
        fi

        return 0

    else

        display --indent 6 --text "- Listing users" --result "FAIL" --color RED
        log_event "error" "Listing users for site ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# Create WordPress user
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${user}
#   ${4} = ${mail}
#   ${5} = ${role}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_user_create() {

    local wp_site="${1}"
    local install_type="${2}"
    local user="${3}"
    local mail="${4}"
    local role="${5}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    log_event "debug" "Running: ${wpcli_cmd} user create ${user} ${mail} --role=${role}" "false"

    # Command
    ${wpcli_cmd} user create "${user}" "${mail}" --role="${role}" > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Creating WP user: ${user}" --result "DONE" --color GREEN
        log_event "info" "Creating WordPress user ${user} for site ${wp_site}" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Creating WP user: ${user}" --result "FAIL" --color RED
        log_event "error" "Creating WordPress user ${user} for site ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# Reset WordPress user password
#
# Arguments:
#   ${1} = ${wp_site} (site path)
#   ${2} = ${install_type}
#   ${3} = ${wp_user}
#   ${4} = ${wp_user_pass}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_user_reset_passw() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_user="${3}"
    local wp_user_pass="${4}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "info" "User password reset for ${wp_user}. New password: ${wp_user_pass}" "false"
    log_event "debug" "Running: ${wpcli_cmd} user update \"${wp_user}\" --user_pass=\"${wp_user_pass}\"" "false"

    # Command
    ${wpcli_cmd} user update "${wp_user}" --user_pass="${wp_user_pass}" --skip-email > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        clear_previous_lines "1"
        display --indent 6 --text "- Password reset for ${wp_user}" --result "DONE" --color GREEN
        display --indent 8 --text "New password ${wp_user_pass}"
        log_event "error" "New password for user ${user} on site ${wp_site}" "false"

        return 0

    else

        # Log failure
        clear_previous_lines "1"
        display --indent 6 --text "- Password reset for ${wp_user}" --result "FAIL" --color RED
        log_event "error" "Trying to reset password for user ${user} on site ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# Delete WordPress user
#
# Arguments:
#   ${1} = ${wp_site} (site path)
#   ${2} = ${install_type}
#   ${3} = ${wp_user} (username to delete)
#
# Outputs:
#   0 if user was deleted, 1 if not.
################################################################################

function wpcli_user_delete() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_user="${3}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "info" "Deleting user ${wp_user}" "false"
    log_event "debug" "Running: ${wpcli_cmd} user delete \"${wp_user}\" --yes" "false"

    # Command - --yes to skip confirmation, --reassign to reassign posts if needed
    ${wpcli_cmd} user delete "${wp_user}" --yes --reassign=1 > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        #clear_previous_lines "1"
        display --indent 6 --text "- User ${wp_user} deleted" --result "DONE" --color GREEN
        log_event "info" "User ${wp_user} deleted from site ${wp_site}" "false"

        return 0

    else

        # Log failure
        #clear_previous_lines "1"
        display --indent 6 --text "- User ${wp_user} deleted" --result "FAIL" --color RED
        log_event "error" "Failed to delete user ${wp_user} from site ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# Change seo visibility
#
# Arguments:
#   ${1} = ${wp_site} (site path)
#   ${2} = ${install_type}
#   ${3} = ${visibility} (0=off or 1=on)
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_change_wp_seo_visibility() {

    local wp_site="${1}"
    local install_type="${2}"
    local visibility="${3}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T --rm wordpress-cli wp"

    log_event "debug" "Running: ${wpcli_cmd} option set blog_public ${visibility}" "false"

    # Command
    ${wpcli_cmd} option set blog_public "${visibility}" --quiet > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Changing site visibility to ${visibility}" --result "DONE" --color GREEN
        log_event "error" "Changing site visibility to ${visibility} on site ${wp_site}" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Changing site visibility to ${visibility}" --result "FAIL" --color RED
        log_event "error" "Changing site visibility to ${visibility} on site ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# Update upload_path
#
# Arguments:
#   ${1} = ${wp_site} (site path)
#   ${2} = ${upload_path}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_update_upload_path() {

    local wp_site="${1}"
    local install_type="${2}"
    local upload_path="${3}"

    local wpcli_cmd
    local wp_command

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    log_event "debug" "Running: wp --allow-root --path=\"${wp_site}\" option update upload_path \"${upload_path}\"" "false"

    # wp-cli command
    wp_command="$(${wpcli_cmd} option update upload_path "${upload_path}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Updating project upload path" --result "DONE" --color GREEN
        log_event "error" "New upload path: ${upload_path}" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Updating upload path for ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Updating upload path: ${upload_path}" "false"
        log_event "error" "wp-cli command output: ${wp_command}" "false"

        return 1

    fi
}

################################################################################
# Set Debug mode
#
# Arguments:
#   ${1} = ${wp_site} (site path)
#   ${2} = ${debug_mode} (true or false)
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_set_debug_mode() {

    local wp_site="${1}"
    local install_type="${2}"
    local debug_mode="${3}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} config set --raw WP_DEBUG \"${debug_mode}\"" "false"
    log_event "debug" "Running: ${wpcli_cmd} config set --raw WP_DEBUG_LOG \"${debug_mode}\"" "false"
    log_event "debug" "Running: ${wpcli_cmd} config set --raw WP_DEBUG_DISPLAY \"${debug_mode}\"" "false"

    # Command
    ${wpcli_cmd} config set --raw WP_DEBUG "${debug_mode}" --quiet > /dev/null 2>&1
    ${wpcli_cmd} config set --raw WP_DEBUG_LOG "${debug_mode}" --quiet > /dev/null 2>&1
    ${wpcli_cmd} config set --raw WP_DEBUG_DISPLAY "${debug_mode}" --quiet > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        clear_previous_lines "3"
        display --indent 6 --text "- Set debug mode: ${debug_mode}" --result "DONE" --color GREEN
        log_event "error" "Set debug mode: ${debug_mode}" "false"

        return 0

    else

        # Log failure
        clear_previous_lines "3"
        display --indent 6 --text "- Set debug mode: ${debug_mode}" --result "FAIL" --color RED
        log_event "error" "Set debug mode: ${debug_mode}" "false"

        return 1

    fi

}

################################################################################
# Flush WordPress cache (core)
#
# Arguments:
#   ${1} = ${wp_site} (site path)
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_cache_flush() {

    local wp_site="${1}"
    local install_type="${2}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} cache flush" "false"

    # Command
    ${wpcli_cmd} cache flush > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        clear_previous_lines "1"
        display --indent 6 --text "- Flush cache" --result "DONE" --color GREEN
        log_event "error" "Cache flush for ${wp_site}" "false"

        return 0

    else

        # Log failure
        clear_previous_lines "1"
        display --indent 6 --text "- Cache flush for ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Cache flush for ${wp_site}" "false"

        return 1

    fi

}

### wpcli plugins specific functions

################################################################################
# WP Rocket: Clean cache
#
# Arguments:
#   ${1} = ${wp_site} (site path)
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_rocket_cache_clean() {

    local wp_site="${1}"
    local install_type="${2}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} rocket clean --confirm" "false"

    # Command
    ${wpcli_cmd} rocket clean --confirm > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Cache purge for ${wp_site}" --result "DONE" --color GREEN
        log_event "error" "Cache purge for ${wp_site}" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Cache purge for ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Cache purge for ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# WP Rocket: Activate cache
#
# Arguments:
#   ${1} = ${wp_site} (site path)
#   ${2} = ${install_type}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_rocket_cache_activate() {

    local wp_site="${1}"
    local install_type="${2}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} rocket activate-cache" "false"

    # Command
    ${wpcli_cmd} rocket activate-cache > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        display --indent 6 --text "- Cache activated for ${wp_site}" --result "DONE" --color GREEN
        log_event "error" "Cache activated for ${wp_site}" "false"

        return 0

    else

        # Log failure
        display --indent 6 --text "- Cache activated for ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Cache activated for ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# WP Rocket: Deactivate cache
#
# Arguments:
#   ${1} = ${wp_site} (site path)
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_rocket_cache_deactivate() {

    local wp_site="${1}"
    local install_type="${2}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} rocket deactivate-cache" "false"

    # Command
    ${wpcli_cmd} rocket deactivate-cache > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        display --indent 6 --text "- Cache deactivated for ${wp_site}" --result "DONE" --color GREEN
        log_event "error" "Cache deactivated for ${wp_site}" "false"

        return 0

    else

        # Log failure
        display --indent 6 --text "- Cache deactivated for ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Cache deactivated for ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# WP Rocket: Export settings
#
# Arguments:
#   ${1} = ${wp_site} (site path)
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_rocket_settings_export() {

    local wp_site="${1}"
    local install_type="${2}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} --allow-root --path=\"${wp_site}\" rocket export" "false"

    # Command
    ${wpcli_cmd} --allow-root --path="${wp_site}" rocket export > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        display --indent 6 --text "- Settings exported for ${wp_site}" --result "DONE" --color GREEN
        log_event "info" "Settings exported for ${wp_site}" "false"

        return 0

    else

        # Log failure
        display --indent 6 --text "- Settings exported for ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Settings exported for ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# WP Rocket: Import settings
#
# Arguments:
#   ${1} = ${wp_site} (site path)
#   ${2} = ${install_type}
#   ${3} = ${settings_json}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_rocket_settings_import() {

    local wp_site="${1}"
    local install_type="${2}"
    local settings_json="${3}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    log_event "debug" "Running: ${wpcli_cmd} rocket import --file=\"${settings_json}\"" "false"

    # Command
    ${wpcli_cmd} rocket import --file="${settings_json}" > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Settings imported for ${wp_site}" --result "DONE" --color GREEN
        log_event "error" "Settings imported for ${wp_site}" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Settings imported for ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Settings imported for ${wp_site}" "false"

        return 1

    fi

}

################################################################################

# TODO: maybe a single function to get all options?
# Ref: https://codex.wordpress.org/Option_Reference

################################################################################
# Get configured site home from WordPress installation options
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#
# Outputs:
#   ${wp_option_home}
################################################################################

function wpcli_option_get_home() {

    local wp_site="${1}"
    local install_type="${2}"

    local wpcli_cmd
    local wp_option_home

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} option get home" "false"

    # Command
    wp_option_home="$(sudo -u www-data wp --path="${wp_site}" option get home)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        display --indent 6 --text "- Getting home for ${wp_site}" --result "DONE" --color GREEN
        display --indent 6 --text "Result: ${wp_option_home}"
        log_event "debug" "wp_option_home:${wp_option_home}" "false"

        # Return
        echo "${wp_option_home}"

        return 0

    else

        # Log failure
        display --indent 6 --text "- Getting home for ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Getting home for ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# Get configured site url from WordPress installation options
#
# Arguments:
#   ${1} = ${wp_site}
#
# Outputs:
#   ${wp_option_siteurl}
################################################################################

function wpcli_option_get_siteurl() {

    local wp_site="${1}"
    local install_type="${2}"

    local wp_option_siteurl

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    log_event "debug" "Running: ${wpcli_cmd} option get siteurl" "false"

    # Command
    wp_option_siteurl="$(${wpcli_cmd} option get siteurl)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Getting siteurl for ${wp_site}" --result "DONE" --color GREEN
        display --indent 6 --text "Result: ${wp_option_home}"
        log_event "info" "wp_option_siteurl:${wp_option_siteurl}" "false"

        # Return
        echo "${wp_option_siteurl}"

        return 0

    else

        # Log
        display --indent 6 --text "- Getting siteurl for ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Getting siteurl for ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# Get a configuration option on a WordPress installation.
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${wp_config_option}
#
# Outputs:
#   0 if option was configured, 1 on error.
################################################################################

function wpcli_config_get() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_config_option="${3}"

    local wpcli_cmd

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # wp-cli command
    wp_config="$(${wpcli_cmd} config get "${wp_config_option}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "debug" "Command executed: ${wpcli_cmd} config get ${wp_config_option}" "false"
        log_event "debug" "wp config get return:${wp_config}" "false"

        return 0

    else

        log_event "debug" "Command executed: ${wpcli_cmd} config get ${wp_config_option}" "false"
        log_event "error" "wp config get return:${wp_config}" "false"

        return 1

    fi

}

################################################################################
# Set a configuration option on a WordPress installation.
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${wp_config_option}
#   ${4} = ${wp_config_option_value}
#
# Outputs:
#   0 if option was configured, 1 on error.
################################################################################

function wpcli_config_set() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_config_option="${3}"
    local wp_config_option_value="${4}"

    local wpcli_cmd

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} config set ${wp_config_option} ${wp_config_option_value}" "false"

    # wp-cli command
    wp_config="$(${wpcli_cmd} config set "${wp_config_option}" "${wp_config_option_value}")"

    # get exit status
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        [[ ${install_type} == "docker"* ]] && clear_previous_lines "1"
        log_event "debug" "Command executed: ${wpcli_cmd} config set ${wp_config_option} ${wp_config_option_value}" "false"
        log_event "debug" "wp config set return:${wp_config}" "false"

        return 0

    else

        # Log failure
        [[ ${install_type} == "docker"* ]] && clear_previous_lines "1"
        log_event "debug" "Command executed: ${wpcli_cmd} config set ${wp_config_option} ${wp_config_option_value}" "false"
        log_event "error" "wp config set return:${wp_config}" "false"

        return 1

    fi

}

################################################################################
# Delete all comments marked as an specific status.
#
# Arguments:
#   ${1} = ${wp_site}
#   ${2} = ${install_type}
#   ${3} = ${wp_comment_status} - spam or hold
#
# Outputs:
#   0 if option was configured, 1 on error.
################################################################################

function wpcli_delete_comments() {

    local wp_site="${1}"
    local install_type="${2}"
    local wp_comment_status="${3}"

    local wpcli_cmd

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error: https://github.com/docker-library/wordpress/issues/417
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose --progress=quiet -f ${wp_site}/../docker-compose.yml run -T -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # List comments ids
    display --indent 6 --text "- Deleting comments marked as ${wp_comment_status}"
    comments_ids="$(${wpcli_cmd} comment list --status="${wp_comment_status}" --format=ids 2>/dev/null)"

    if [[ -z "${comments_ids}" ]]; then

        # Log success
        log_event "info" "There are no comments marked as ${wp_comment_status} for ${wp_site}" "false"
        clear_previous_lines "1"
        display --indent 6 --text "- Deleting comments marked as ${wp_comment_status}" --result "0" --color WHITE

        return 0

    else

        # Delete all comments listed as "${wp_comment_status}"
        wpcli_result="$(${wpcli_cmd} comment delete "${comments_ids}" --force 2>/dev/null)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Log success
            log_event "info" "Comments marked as ${wp_comment_status} deleted for ${wp_site}" "false"
            log_event "debug" "Command result: ${wpcli_result}" "false"
            clear_previous_lines "1"
            display --indent 6 --text "- Deleting comments marked as ${wp_comment_status}" --result "DONE" --color GREEN

            return 0

        else

            # Log
            log_event "error" "Deleting comments marked as ${wp_comment_status} for ${wp_site}" "false"
            log_event "debug" "Last command executed: ${wpcli_cmd} comment delete \"${comments_ids}\" --format=ids) --force" "false"
            clear_previous_lines "1"
            display --indent 6 --text "- Deleting comments marked as ${wp_comment_status}" --result "FAIL" --color RED

            return 1

        fi

    fi

}

################################################################################
# Scan WordPress database for malicious code using WP-CLI
#
# Arguments:
#  ${1} = ${wp_path}
#
# Outputs:
#  Scan results, 1 on error.
################################################################################

function wpcli_wordpress_malware_scan() {

    local wp_path="${1}"
    local project_install_type="${2}"

    local wpcli_result
    local results_found=0

    # Check project_install_type and set wp command
    local wpcli_cmd
    if [[ ${project_install_type} == "docker" ]]; then
        wpcli_cmd="docker compose -f ${wp_path}/docker-compose.yml exec -T wordpress-${WP_SITE_NAME} wp"
    else
        wpcli_cmd="sudo -u www-data wp --path=${wp_path}"
    fi

    # Get WordPress table prefix using WP-CLI
    local wp_prefix
    wp_prefix=$(${wpcli_cmd} config get table_prefix 2>/dev/null | tr -d '\r')
    [[ -z ${wp_prefix} ]] && wp_prefix="wp_"

    # Get database name
    local db_name
    db_name=$(${wpcli_cmd} config get DB_NAME 2>/dev/null | tr -d '\r')

    # Ensure malware scan results directory exists
    mkdir -p "${BROLIT_TMP_DIR}/malware_scan_results"
    local detailed_results_file="${BROLIT_TMP_DIR}/malware_scan_results/wpcli_${db_name}_$$.txt"

    # Clean up any previous results file
    [[ -f ${detailed_results_file} ]] && rm -f "${detailed_results_file}"

    # Malware patterns to search for (same as Database Manager)
    local malware_patterns=(
        "base64_decode"
        "eval("
        "exec("
        "system("
        "assert("
        "shell_exec"
        "passthru"
        "proc_open"
        "popen"
        "curl_exec"
        "curl_multi_exec"
        "parse_ini_file"
        "show_source"
        "file_get_contents"
        "file_put_contents"
        "preg_replace"
        "create_function"
        "call_user_func"
        "\$_POST["
        "\$_GET["
        "\$_REQUEST["
        "\$_COOKIE["
        "RewriteCond"
        "RewriteRule"
        "set_time_limit(0)"
        "error_reporting(0)"
        "ini_restore"
        "ini_set"
        "<script"
        "document.write"
        "fromCharCode"
        "unescape("
        "String.fromCharCode"
        "atob("
        "btoa("
        ".ini_set("
        "phpinfo("
        "chmod("
        "onerror="
        "onload="
        "onclick="
        "onfocus="
        "onmouseover="
        "<iframe src=\"data:"
        "<iframe src=\"javascript:"
    )

    log_event "info" "Scanning WordPress database for malware at '${wp_path}'" "false"
    log_event "debug" "WP-CLI command: ${wpcli_cmd}" "false"
    log_event "debug" "Database name: ${db_name}" "false"
    display --indent 6 --text "- Scanning WordPress database for malware" --tcolor YELLOW
    display --indent 8 --text "Using table prefix: ${wp_prefix}" --tcolor CYAN

    # Get ALL tables from database
    local all_tables
    all_tables=$(${wpcli_cmd} db query "SHOW TABLES" --skip-column-names 2>&1 | tr -d '\r')

    log_event "debug" "SHOW TABLES output: '${all_tables}'" "false"

    local total_tables
    total_tables=$(echo "${all_tables}" | grep -c .)
    display --indent 6 --text "- Total tables found: ${total_tables}" --tcolor CYAN

    local tables_processed=0

    # Scan ALL tables
    while IFS= read -r table; do
        [[ -z ${table} ]] && continue

        ((tables_processed++))

        # Get all TEXT/VARCHAR columns from this table
        local text_columns
        text_columns=$(${wpcli_cmd} db query "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = '${db_name}' AND TABLE_NAME = '${table}' AND DATA_TYPE IN ('text', 'mediumtext', 'longtext', 'varchar', 'char', 'tinytext')" --skip-column-names 2>/dev/null | tr -d '\r')

        # Skip table if no text columns
        if [[ -z ${text_columns} ]]; then
            display --indent 8 --text "[${tables_processed}/${total_tables}] Scanning table: ${table}" --result "SKIPPED" --color GRAY
            continue
        fi

        # Track if table has any findings
        local table_has_findings=0

        for pattern in "${malware_patterns[@]}"; do

            local matches=0

            # Build WHERE clause for all text columns
            local where_clause=""
            while IFS= read -r col; do
                [[ -z ${col} ]] && continue
                if [[ -z ${where_clause} ]]; then
                    where_clause="\`${col}\` LIKE '%${pattern}%'"
                else
                    where_clause="${where_clause} OR \`${col}\` LIKE '%${pattern}%'"
                fi
            done <<< "${text_columns}"

            # Execute search query
            if [[ -n ${where_clause} ]]; then
                matches=$(${wpcli_cmd} db query "SELECT COUNT(*) FROM \`${table}\` WHERE ${where_clause}" --skip-column-names 2>/dev/null | tr -d '\r' | xargs || echo "0")
            fi

            if [[ ${matches} -gt 0 ]]; then
                results_found=1

                # Show table name only on first finding for this table
                if [[ ${table_has_findings} -eq 0 ]]; then
                    display --indent 8 --text "[${tables_processed}/${total_tables}] Scanning table: ${table}" --result "WARNING" --color RED
                    table_has_findings=1
                fi

                display --indent 10 --text "⚠ SUSPICIOUS: '${pattern}' found ${matches} times" --tcolor RED
                log_event "warning" "Malware pattern '${pattern}' found ${matches} times in ${table}" "false"

                # Add to detailed report
                echo "========================================" >> "${detailed_results_file}"
                echo "Pattern: ${pattern}" >> "${detailed_results_file}"
                echo "Table: ${table}" >> "${detailed_results_file}"
                echo "Occurrences: ${matches}" >> "${detailed_results_file}"
                echo "Columns scanned: $(echo "${text_columns}" | tr '\n' ', ' | sed 's/,$//')" >> "${detailed_results_file}"
                echo "----------------------------------------" >> "${detailed_results_file}"

                # Get primary key column name for this table
                local pk_column
                pk_column=$(${wpcli_cmd} db query "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = '${db_name}' AND TABLE_NAME = '${table}' AND COLUMN_KEY = 'PRI' LIMIT 1" --skip-column-names 2>/dev/null | tr -d '\r')
                [[ -z ${pk_column} ]] && pk_column="id"

                # Get records that match the pattern (limit to first 10)
                ${wpcli_cmd} db query "SELECT \`${pk_column}\` FROM \`${table}\` WHERE ${where_clause} LIMIT 10" --skip-column-names 2>/dev/null | while IFS=$'\t' read -r record_id; do
                    [[ -z ${record_id} ]] && continue
                    record_id=$(echo "${record_id}" | tr -d '\r')

                    echo "  ---" >> "${detailed_results_file}"
                    echo "  Record ID (${pk_column}): ${record_id}" >> "${detailed_results_file}"

                    # Show which columns contain the pattern
                    while IFS= read -r col; do
                        [[ -z ${col} ]] && continue
                        local col_value
                        col_value=$(${wpcli_cmd} db query "SELECT LEFT(\`${col}\`, 200) FROM \`${table}\` WHERE \`${pk_column}\` = '${record_id}' AND \`${col}\` LIKE '%${pattern}%' LIMIT 1" --skip-column-names 2>/dev/null | tr -d '\r')
                        if [[ -n ${col_value} ]]; then
                            echo "  Column '${col}': ${col_value}..." >> "${detailed_results_file}"
                        fi
                    done <<< "${text_columns}"

                    # Generate SQL delete command
                    local delete_sql="DELETE FROM \`${table}\` WHERE \`${pk_column}\` = '${record_id}';"
                    echo "  SQL: ${delete_sql}" >> "${detailed_results_file}"

                    # Add WP-CLI delete commands with full bash syntax
                    if [[ ${table} == *"posts" ]]; then
                        if [[ ${project_install_type} == "docker" ]]; then
                            echo "  WP-CLI (Docker): docker compose -f ${wp_path}/docker-compose.yml exec -T wordpress-${WP_SITE_NAME} wp post delete ${record_id} --force" >> "${detailed_results_file}"
                        else
                            echo "  WP-CLI (Host): sudo -u www-data wp --path=${wp_path} post delete ${record_id} --force" >> "${detailed_results_file}"
                        fi
                    elif [[ ${table} == *"options" ]]; then
                        local opt_name
                        opt_name=$(${wpcli_cmd} db query "SELECT option_name FROM \`${table}\` WHERE \`${pk_column}\` = '${record_id}' LIMIT 1" --skip-column-names 2>/dev/null | tr -d '\r')
                        if [[ ${project_install_type} == "docker" ]]; then
                            echo "  WP-CLI (Docker): docker compose -f ${wp_path}/docker-compose.yml exec -T wordpress-${WP_SITE_NAME} wp option delete '${opt_name}'" >> "${detailed_results_file}"
                        else
                            echo "  WP-CLI (Host): sudo -u www-data wp --path=${wp_path} option delete '${opt_name}'" >> "${detailed_results_file}"
                        fi
                    fi

                    # Add bash command for SQL deletion
                    if [[ ${project_install_type} == "docker" ]]; then
                        echo "  Bash (Docker): docker compose -f ${wp_path}/docker-compose.yml exec -T wordpress-${WP_SITE_NAME} wp db query \"${delete_sql}\"" >> "${detailed_results_file}"
                    else
                        echo "  Bash (Host): sudo -u www-data wp --path=${wp_path} db query \"${delete_sql}\"" >> "${detailed_results_file}"
                    fi
                    echo "" >> "${detailed_results_file}"
                done
            fi
        done

        # If no findings in this table, show OK
        if [[ ${table_has_findings} -eq 0 ]]; then
            display --indent 8 --text "[${tables_processed}/${total_tables}] Scanning table: ${table}" --result "OK" --color GREEN
        fi
    done <<< "${all_tables}"

    # Check for suspicious admin users
    display --indent 8 --text "Checking for suspicious admin users..." --tcolor WHITE
    local admin_count
    admin_count=$(${wpcli_cmd} user list --role=administrator --field=ID --format=count 2>/dev/null)

    if [[ ${admin_count} -gt 5 ]]; then
        results_found=1
        display --indent 10 --text "⚠ WARNING: ${admin_count} administrator users found (may be suspicious)" --result "WARNING" --color YELLOW
        log_event "warning" "${admin_count} administrator users found" "false"
    fi

    # Check for inactive plugins
    display --indent 8 --text "Checking for inactive plugins..." --tcolor WHITE
    local inactive_plugins
    inactive_plugins=$(${wpcli_cmd} plugin list --status=inactive --field=name --format=count 2>/dev/null)

    if [[ ${inactive_plugins} -gt 10 ]]; then
        display --indent 10 --text "INFO: ${inactive_plugins} inactive plugins (clean up recommended)" --tcolor CYAN
    fi

    if [[ ${results_found} -eq 0 ]]; then
        display --indent 6 --text "- No suspicious patterns found" --result "CLEAN" --color GREEN
        log_event "info" "No malware patterns found in WordPress database" "false"
        # Clean up results file if no results
        [[ -f ${detailed_results_file} ]] && rm -f "${detailed_results_file}"
    else
        display --indent 6 --text "- Scan completed - SUSPICIOUS CONTENT FOUND" --result "WARNING" --color RED
        display --indent 6 --text "⚠ Manual review recommended!" --tcolor RED
        echo ""
        display --indent 6 --text "📄 Detailed report saved to:" --tcolor CYAN
        display --indent 8 --text "${detailed_results_file}" --tcolor WHITE
        echo ""
        display --indent 6 --text "To view the report, run:" --tcolor YELLOW
        display --indent 8 --text "less ${detailed_results_file}" --tcolor WHITE
        display --indent 8 --text "or" --tcolor WHITE
        display --indent 8 --text "cat ${detailed_results_file}" --tcolor WHITE
        echo ""

        # Ask if user wants to view the report now
        if whiptail --title "Malware Scan Results" --yesno "Suspicious content found!\n\nDetailed report saved to:\n${detailed_results_file}\n\nThe report contains:\n- Specific IDs of affected records\n- WP-CLI commands to delete\n- SQL commands as alternative\n\nDo you want to view the report now?" 18 78; then
            less "${detailed_results_file}"
        fi
    fi

    return 0

}
