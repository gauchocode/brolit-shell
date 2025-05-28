#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.10
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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose -f ${wp_site}/../docker-compose.yml run --rm wordpress-cli wp"

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

    local wpcli_package="${1}"

    local is_installed
    local wpcli_packages_installed

    is_installed="false"

    wpcli_packages_installed="$(wp package list --allow-root | grep 'wp-cli' | cut -d '/' -f2)"

    [[ ${wpcli_package} == *"${wpcli_packages_installed}"* ]] && is_installed="true"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose -f ${wp_site}/../docker-compose.yml run --rm wordpress-cli wp --allow-root"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    display --indent 6 --text "- WordPress verify-checksums"
    log_event "debug" "Running: ${wpcli_cmd} core verify-checksums" "false"

    # Verify WordPress Checksums
    ${wpcli_cmd} core verify-checksums | awk -F": " '/File (doesn'\''t|should not) exist/ {print $3}' >"${wp_verify_checksum_output_file}"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color > /dev/null 2>&1"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    [[ -z ${status} ]] && status="active"
    [[ -z ${format} ]] && format="table"

    # Log
    display --indent 6 --text "- Listing plugins"
    log_event "debug" "Running: ${wpcli_cmd} plugin list --status=${status} --format=${format}" "false"

    # Command
    ${wpcli_cmd} plugin list --status="${status}" --format="${format}"

    # Return
    echo $?

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    log_subsection "WP Re-install Plugins"

    if [[ -z ${wp_plugin} || ${wp_plugin} == "all" ]]; then

        log_event "debug" "Running: ${wpcli_cmd} plugin install $(${wpcli_cmd} plugin list --field=name | tr '\n' ' ') --force"

        ${wpcli_cmd} plugin install "$(${wpcli_cmd} plugin list --field=name | tr '\n' ' ')" --force

    else

        log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin install ${wp_plugin} --force"

        ${wpcli_cmd} plugin install "${wp_plugin}" --force

        display --indent 6 --text "- Plugin force install ${wp_plugin}" --result "DONE" --color GREEN

    fi

    # TODO: save ouput on array with mapfile
    #mapfile verify_plugin < <(sudo -u www-data wp --path="${wp_site}" plugin verify-checksums "${plugin}" 2>&1)
    #echo "${verify_plugin[@]}"

}

# The idea is that when you update WordPress or a plugin, get the actual version,
# then run a dry-run update, if success, update but show a message if you want to
# persist the update or want to do a rollback

function wpcli_plugin_version_rollback() {

    # TODO: implement this
    # $1= wp_site
    # ${2} = wp_plugin
    # $3= wp_plugin_v (version to install)

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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

    # Default locale
    [[ -z ${wp_locale} ]] && wp_locale="es_ES"

    # Log
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} config create --dbname=${database} --dbuser=${db_user_name} --dbpass=${db_user_passw} --locale=${wp_locale}"

    # wp-cli command
    sudo -u www-data wp --path="${wp_site}" config create --dbname="${database}" --dbuser="${db_user_name}" --dbpass="${db_user_passw}" --locale="${wp_locale}" --quiet > /dev/null 2>&1

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose -f ${wp_site}/../docker-compose.yml run --rm wordpress-cli wp"

    log_event "debug" "Running: ${wpcli_cmd} config shuffle-salts" "false"

    # Command
    ${wpcli_cmd} config shuffle-salts --quiet > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        log_event "info" "Salts shuffled" "false"
        display --indent 6 --text "- Shuffle salts" --result "DONE" --color GREEN

        return 0

    else

        # Log failure
        log_event "error" "Something went wrong when trying to shuffle salts" "false"
        display --indent 6 --text "- Shuffle salts" --result "FAIL" --color RED

        return 1

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color > /dev/null 2>&1"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color > /dev/null 2>&1"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} core version" "false"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_user_list() {

    local wp_site="${1}"
    local install_type="${2}"

    # Check project_install_type
    [[ ${install_type} == "default" ]] && wpcli_cmd="sudo -u www-data wp --path=${wp_site}"
    ## -u 33 -e HOME=/tmp to avoid permission denied error:
    ## --no-color added to avoid unwanted wp-cli output
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} user list --fields=user_login,user_email,roles --format=csv" "false"

    # Command
    ${wpcli_cmd} user list --fields=user_login,user_email,roles --format=csv --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        display --indent 6 --text "- Listing users" --result "DONE" --color GREEN

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker compose -f ${wp_site}/../docker-compose.yml run --rm wordpress-cli wp"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # Log
    log_event "debug" "Running: ${wpcli_cmd} config set ${wp_config_option} ${wp_config_option_value}" "false"

    # wp-cli command
    wp_config="$(${wpcli_cmd} config set "${wp_config_option} ${wp_config_option_value}")"

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
        #[[ ${install_type} == "docker"* ]] && clear_previous_lines "1"
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
    [[ ${install_type} == "docker"* ]] && wpcli_cmd="docker --log-level=error compose -f ${wp_site}/../docker-compose.yml run -u 33 -e HOME=/tmp --rm wordpress-cli wp --no-color"

    # List comments ids
    comments_ids="$(${wpcli_cmd} comment list --status="${wp_comment_status}" --format=ids)"

    if [[ -z "${comments_ids}" ]]; then

        # Log success
        log_event "info" "There are no comments marked as ${wp_comment_status} for ${wp_site}" "false"
        display --indent 6 --text "- Deleting comments marked as ${wp_comment_status}" --result "0" --color WHITE

        return 0

    else

        # Delete all comments listed as "${wp_comment_status}"
        wpcli_result="$(${wpcli_cmd} comment delete "${comments_ids}" --force)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Log failure
            log_event "info" "Comments marked as ${wp_comment_status} deleted for ${wp_site}" "false"
            log_event "debug" "Command result: ${wpcli_result}" "false"
            display --indent 6 --text "- Deleting comments marked as ${wp_comment_status}" --result "DONE" --color GREEN

            return 0

        else

            # Log
            log_event "error" "Deleting comments marked as ${wp_comment_status} for ${wp_site}" "false"
            log_event "debug" "Las command executed: ${wpcli_cmd} comment delete \"${comments_ids}\" --format=ids) --force" "false"
            display --indent 6 --text "- Deleting comments marked as ${wp_comment_status}" --result "FAIL" --color RED

            return 1

        fi

    fi

}
