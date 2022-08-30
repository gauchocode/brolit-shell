#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.1
################################################################################
#
# WP-CLI Helper: Perform wpcli tasks.
#
# Refs: https://developer.wordpress.org/cli/commands/
#
################################################################################

################################################################################
# Installs wpcli if not installed
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

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            return 0

        else

            return 1

        fi
    fi

}

################################################################################
# Check if wpcli is installed
#
# Arguments:
#   None
#
# Outputs:
#   "true" if wpcli is installed, "false" if not.
################################################################################

function wpcli_check_if_installed() {

    local wpcli_installed wpcli_v

    wpcli_installed="true"

    wpcli_v="$(wpcli_check_version)"

    if [[ -z "${wpcli_v}" ]]; then

        wpcli_installed="false"

    fi

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

    local wpcli_v

    wpcli_v="$(sudo -u www-data wp --info | grep "WP-CLI version:" | cut -d ':' -f2)"

    # Return
    echo "${wpcli_v}"

}

################################################################################
# Install wpcli
#
# Arguments:
#   None
#
# Outputs:
#   0 if wpcli was installed, 1 on error.
################################################################################

function wpcli_install() {

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
# Update wpcli
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
# Uninstall wpcli
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
#   $1 = ${wpcli_package}
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

    if [[ ${wpcli_package} == *"${wpcli_packages_installed}"* ]]; then

        is_installed="true"

    fi

    # Return
    echo "${is_installed}"

}

################################################################################
# Install some wp-cli extensions
#
# Arguments:
#   none
#
# Outputs:
#   none
################################################################################

function wpcli_install_needed_extensions() {

    # Rename DB Prefix
    wp --allow-root package install "iandunn/wp-cli-rename-db-prefix"

    # Salts
    wp --allow-root package install "sebastiaandegeus/wp-cli-salts-comman"

    # Vulnerability Scanner
    wp --allow-root package install "git@github.com:10up/wp-vulnerability-scanner.git"

    # WP-Rocket
    wp --allow-root package install "wp-media/wp-rocket-cli:1.3"

}

################################################################################
# Download WordPress core.
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${wp_version} - optional
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
            sudo -u www-data wp --path="${wp_site}" core download --version="${wp_version}" --quiet

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
            sudo -u www-data wp --path="${wp_site}" core download --quiet

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
        #display --indent 6 --text "- Wordpress installation for ${wp_site}" --result "FAIL" --color RED
        #display --indent 8 --text "${error_msg}"

        # Return
        return 1

    fi

}

################################################################################
# Re-install WordPress core (it will not delete others files).
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${wp_version} - optional
#
# Outputs:
#   0 if WordPress is downloaded, 1 on error.
################################################################################

function wpcli_core_reinstall() {

    local wp_site="${1}"
    local wp_version="${2}"

    local wpcli_result

    if [[ -n ${wp_site} ]]; then

        log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} core download --skip-content --force" "false"

        wpcli_result=$(sudo -u www-data wp --path="${wp_site}" core download --skip-content --force 2>&1 | grep "Success" | cut -d ":" -f1)

        if [[ "${wpcli_result}" = "Success" ]]; then

            # Log Success
            log_event "info" "Wordpress re-installed" "false"
            display --indent 6 --text "- Wordpress re-install for ${wp_site}" --result "DONE" --color GREEN

            return 0

        else

            # Log failure
            log_event "fail" "Something went wrong installing WordPress" "false"
            display --indent 6 --text "- Wordpress re-install for ${wp_site}" --result "FAIL" --color RED

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
# Update WordPress core.
#
# Arguments:
#   $1 = ${wp_site}
#
# Outputs:
#   0 if option was configured, 1 on error.
################################################################################

function wpcli_core_update() {

    local wp_site="${1}"

    local verify_core_update

    log_section "WordPress Updater"

    # Command
    verify_core_update="$(sudo -u www-data wp --path="${wp_site}" core update | grep ":" | cut -d ':' -f1)"

    if [[ ${verify_core_update} == "Success" ]]; then

        display --indent 6 --text "- Download new WordPress version" --result "DONE" --color GREEN

        # Translations update
        sudo -u www-data wp --path="${wp_site}" language core update
        display --indent 6 --text "- Language update" --result "DONE" --color GREEN

        # Update database
        sudo -u www-data wp --path="${wp_site}" core update-db
        display --indent 6 --text "- Database update" --result "DONE" --color GREEN

        # Cache Flush
        sudo -u www-data wp --path="${wp_site}" cache flush
        display --indent 6 --text "- Flush cache" --result "DONE" --color GREEN

        # Rewrite Flush
        sudo -u www-data wp --path="${wp_site}" rewrite flush
        display --indent 6 --text "- Flush rewrite" --result "DONE" --color GREEN

        log_event "info" "Wordpress core updated" "false"
        display --indent 6 --text "- Finishing update" --result "DONE" --color GREEN

        return 0

    else

        # Log
        log_event "error" "WordPress update failed" "false"
        log_event "error" "Last command executed: sudo -u www-data wp --path=\"${wp_site}\" core update" "false"
        display --indent 6 --text "- Download new WordPress version" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Verify WordPress core checksum
#
# Arguments:
#   $1 = ${wp_site}
#
# Outputs:
#   "true" if wpcli package is installed, "false" if not.
################################################################################

function wpcli_core_verify() {

    local wp_site="${1}"

    local verify_core

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} core verify-checksums" "false"

    mapfile verify_core < <(sudo -u www-data wp --path="${wp_site}" core verify-checksums 2>&1)

    display --indent 6 --text "- WordPress verify-checksums" --result "DONE" --color GREEN

    # Return an array with wp-cli output
    echo "${verify_core[@]}"

}

### wpcli plugins

################################################################################
# Verify installation plugins checksum
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${plugin} could be --all?
#
# Outputs:
#   "true" if wpcli package is installed, "false" if not.
################################################################################

function wpcli_plugin_verify() {

    local wp_site="${1}"
    local plugin="${2}"

    local verify_plugin

    if [[ -z ${plugin} || ${plugin} == "all" ]]; then
        plugin="--all"
    fi

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin verify-checksums ${plugin}" "false"

    mapfile verify_plugin < <(sudo -u www-data wp --path="${wp_site}" plugin verify-checksums "${plugin}" 2>&1)

    display --indent 6 --text "- WordPress plugin verify-checksums" --result "DONE" --color GREEN

    # Return an array with wp-cli output
    echo "${verify_plugin[@]}"

}

################################################################################
# Install WordPress plugin
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)
#
# Outputs:
#   0 if plugin was installed, 1 if not.
################################################################################

function wpcli_install_plugin() {

    local wp_site="${1}"
    local plugin="${2}"

    # Log
    display --indent 6 --text "- Installing plugin ${plugin}"
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin install ${plugin}" "false"

    # Command
    sudo -u www-data wp --path="${wp_site}" plugin install "${plugin}" --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Installing plugin ${plugin}" --result "DONE" --color GREEN
        log_event "info" "Plugin ${plugin} installed ok" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Installing plugin ${plugin}" --result "FAIL" --color RED
        log_event "info" "Something went wrong when trying to install plugin: ${plugin}" "false"

        return 1

    fi

}

################################################################################
# Update WordPress plugin
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file) could be --all
#
# Outputs:
#   0 if plugin was installed, 1 if not.
################################################################################

function wpcli_plugin_update() {

    local wp_site="${1}"
    local plugin="${2}"

    local plugin_update

    if [[ ${plugin} == "" ]]; then
        plugin="--all"
    fi

    mapfile plugin_update < <(sudo -u www-data wp --path="${wp_site}" plugin update "${plugin}" --format=json --quiet 2>&1)

    # Return an array with wp-cli output
    echo "${plugin_update[@]}"

}

################################################################################
# Get WordPress plugin version
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${plugin}
#
# Outputs:
#   ${plugin_version}
################################################################################

function wpcli_plugin_get_version() {

    local wp_site="${1}"
    local plugin="${2}"

    local plugin_version

    plugin_version="$(sudo -u www-data wp --path="${wp_site}" plugin get "${plugin}" --format=json | cut -d "," -f 4 | cut -d ":" -f 2)"

    # Return
    echo "${plugin_version}"

}

################################################################################
# Activate WordPress plugin
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)
#
# Outputs:
#   0 if plugin was activated, 1 if not.
################################################################################

function wpcli_plugin_activate() {

    local wp_site="${1}"
    local plugin="${2}"

    # Log
    display --indent 6 --text "- Activating plugin ${plugin}"
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin activate ${plugin}"

    # Command
    sudo -u www-data wp --path="${wp_site}" plugin activate "${plugin}" --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        clear_previous_lines "1"
        display --indent 6 --text "- Activating plugin ${plugin}" --result "DONE" --color GREEN

    else

        clear_previous_lines "1"
        display --indent 6 --text "- Activating plugin ${plugin}" --result "FAIL" --color RED

    fi

}

################################################################################
# Deactivate WordPress plugin
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)
#
# Outputs:
#   0 if plugin was deactivated, 1 if not.
################################################################################

function wpcli_plugin_deactivate() {

    local wp_site="${1}"
    local plugin="${2}"

    # Log
    display --indent 6 --text "- Deactivating plugin ${plugin}"
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin deactivate ${plugin}"

    # Command
    sudo -u www-data wp --path="${wp_site}" plugin deactivate "${plugin}" --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        clear_previous_lines "1"
        display --indent 6 --text "- Deactivating plugin ${plugin}" --result "DONE" --color GREEN

    else

        clear_previous_lines "1"
        display --indent 6 --text "- Deactivating plugin ${plugin}" --result "FAIL" --color RED

    fi

}

################################################################################
# Delete WordPress plugin
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)
#
# Outputs:
#   0 if plugin was deleted, 1 if not.
################################################################################

function wpcli_plugin_delete() {

    local wp_site="${1}"
    local plugin="${2}"

    # Log
    display --indent 6 --text "- Deleting plugin ${plugin}" --result "DONE" --color GREEN
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin delete ${plugin}" "false"

    # Command
    sudo -u www-data wp --path="${wp_site}" plugin delete "${plugin}" --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Deleting plugin ${plugin}" --result "DONE" --color GREEN
        log_event "info" "Deleting plugin ${plugin} finished ok" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Deleting plugin ${plugin}" --result "FAIL" --color RED
        log_event "debug" "Something went wrong trying to delete plugin: ${plugin}" "false"

        return 1

    fi

}

################################################################################
# Check if plugin is active
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)
#
# Outputs:
#   0 if plugin was active, 1 if not.
################################################################################

function wpcli_plugin_is_active() {

    local wp_site="${1}"
    local plugin="${2}"

    # Log
    display --indent 6 --text "- Checking plugin ${plugin} status"
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin is-active ${plugin}" "false"

    # Command
    sudo -u www-data wp --path="${wp_site}" plugin is-active "${plugin}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Plugin status" --result "ACTIVE" --color GREEN
        log_event "info" "Plugin ${plugin} is active" "false"

        return 0

    else

        # Log
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
#   $1 = ${wp_site}
#   $2 = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)
#
# Outputs:
#   0 if plugin was deleted, 1 if not.
################################################################################

function wpcli_plugin_is_installed() {

    local wp_site="${1}"
    local plugin="${2}"

    sudo -u www-data wp --path="${wp_site}" plugin is-installed "${plugin}"

    # Return
    echo $?

}

################################################################################
# Force plugin reinstall
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)
#
# Outputs:
#   0 if plugin was deleted, 1 if not.
################################################################################

function wpcli_plugin_reinstall() {

    local wp_site="${1}"
    local plugin="${2}"

    local verify_plugin

    if [[ -z ${plugin} || ${plugin} == "all" ]]; then

        log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin install $(sudo -u www-data wp --path="${wp_site}" plugin list --field=name | tr '\n' ' ') --force"

        sudo -u www-data wp --path="${wp_site}" plugin install "$(sudo -u www-data wp --path="${wp_site}" plugin list --field=name | tr '\n' ' ')" --force

    else

        log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin install ${plugin} --force"

        sudo -u www-data wp --path="${wp_site}" plugin install "${plugin}" --force

        display --indent 6 --text "- Plugin force install ${plugin}" --result "DONE" --color GREEN

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
    # $2= wp_plugin
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
#   $1 = ${wp_site}
#   $2 = ${theme}
#
# Outputs:
#   0 if plugin was deleted, 1 if not.
################################################################################

function wpcli_theme_install() {

    local wp_site="${1}"
    local theme="${2}"

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} theme install ${theme} --activate"

    # Command
    sudo -u www-data wp --path="${wp_site}" theme install "${theme}" --activate

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        display --indent 6 --text "- Installing and activating theme ${theme}" --result "DONE" --color GREEN
        return 0

    else

        display --indent 6 --text "- Installing and activating theme ${theme}" --result "FAIL" --color RED
        return 1

    fi

}

################################################################################
# Delete WordPress theme
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${theme}
#
# Outputs:
#   0 if plugin was deleted, 1 if not.
################################################################################

function wpcli_theme_delete() {

    local wp_site="${1}"
    local theme="${2}"

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} theme delete ${theme}" "false"

    # Command
    sudo -u www-data wp --path="${wp_site}" theme delete "${theme}" --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        display --indent 6 --text "- Deleting theme ${theme}" --result "DONE" --color GREEN

        return 0

    else

        display --indent 6 --text "- Deleting theme ${theme}" --result "FAIL" --color RED

        return 1

    fi

}

### wpcli scripts

################################################################################
# Startup script (post-install actions)
#
# Arguments:
#   $1 = ${wp_site}           - Site path
#   $1 = ${site_url}          - Site URL
#   $2 = ${site_name}         - Site Display Name
#   $3 = ${wp_user_name}
#   $4 = ${wp_user_passw}
#   $5 = ${wp_user_mail}
#
# Outputs:
#   0 if plugin was deleted, 1 if not.
################################################################################

function wpcli_run_startup_script() {

    local wp_site="${1}"
    local site_url="${2}"
    local site_name="${3}"
    local wp_user_name="${4}"
    local wp_user_passw="${5}"
    local wp_user_mail="${6}"

    if [[ -z ${site_name} ]]; then
        site_name="$(whiptail --title "Site Name" --inputbox "Insert the site name. Example: My Website" 10 60 3>&1 1>&2 2>&3)"
    fi
    exitstatus=$?
    if [[ ${exitstatus} == "" ]]; then
        # Return
        return 1

    fi
    # TODO: check if receive a domain or a url like: https://siteurl.com
    if [[ -z ${site_url} ]]; then
        site_url="$(whiptail --title "Site URL" --inputbox "Insert the site URL. Example: https://mydomain.com" 10 60 3>&1 1>&2 2>&3)"
    fi
    exitstatus=$?
    if [[ ! ${exitstatus} -eq 0 ]]; then
        # Return
        return 1

    fi
    if [[ -z ${wp_user_name} ]]; then
        wp_user_name="$(whiptail --title "Wordpress User" --inputbox "Insert a username for admin." 10 60 3>&1 1>&2 2>&3)"
    fi
    exitstatus=$?
    if [[ ! ${exitstatus} -eq 0 ]]; then
        # Return
        return 1

    fi
    if [[ -z ${wp_user_passw} ]]; then
        local suggested_passw
        suggested_passw="$(openssl rand -hex 12)"
        wp_user_passw="$(whiptail --title "Site Name" --inputbox "Select this random generated password or insert a new one: " 20 78 10 "${suggested_passw}" 3>&1 1>&2 2>&3)"
    fi
    exitstatus=$?
    if [[ ! ${exitstatus} -eq 0 ]]; then
        # Return
        return 1

    fi
    if [[ ${wp_user_mail} == "" ]]; then
        wp_user_mail="$(whiptail --title "WordPress User Mail" --inputbox "Insert the user email." 10 60 3>&1 1>&2 2>&3)"
    fi
    exitstatus=$?
    if [[ ! ${exitstatus} -eq 0 ]]; then
        # Return
        return 1

    fi

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} core install --url=${site_url} --title=${site_name} --admin_user=${wp_user_name} --admin_password=${wp_user_passw} --admin_email=${wp_user_mail}"

    # Install WordPress Site
    sudo -u www-data wp --path="${wp_site}" core install --url="${site_url}" --title="${site_name}" --admin_user="${wp_user_name}" --admin_password="${wp_user_passw}" --admin_email="${wp_user_mail}"

    clear_previous_lines "2"
    display --indent 6 --text "- WordPress site creation" --result "DONE" --color GREEN

    # Delete default post, page, and comment
    sudo -u www-data wp --path="${wp_site}" site empty --yes --quiet
    display --indent 6 --text "- Deleting default content" --result "DONE" --color GREEN

    # Delete default themes
    sudo -u www-data wp --path="${wp_site}" theme delete twentyseventeen --quiet
    sudo -u www-data wp --path="${wp_site}" theme delete twentynineteen --quiet
    display --indent 6 --text "- Deleting default themes" --result "DONE" --color GREEN

    # Delete default plugins
    sudo -u www-data wp --path="${wp_site}" plugin delete akismet --quiet
    sudo -u www-data wp --path="${wp_site}" plugin delete hello --quiet
    display --indent 6 --text "- Deleting default plugins" --result "DONE" --color GREEN

    # Changing permalinks structure
    sudo -u www-data wp --path="${wp_site}" rewrite structure '/%postname%/' --quiet
    display --indent 6 --text "- Changing rewrite structure" --result "DONE" --color GREEN

    # Changing comment status
    sudo -u www-data wp --path="${wp_site}" option update default_comment_status closed --quiet
    display --indent 6 --text "- Setting comments off" --result "DONE" --color GREEN
    #wp post create --post_type=page --post_status=publish --post_title='Home' --allow-root

    wp_change_permissions "${wp_site}"

}

################################################################################
# Create new config
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${database}
#   $3 = ${db_user_name}
#   $4 = ${db_user_passw}
#   $4 = ${wp_locale}
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
    sudo -u www-data wp --path="${wp_site}" config create --dbname="${database}" --dbuser="${db_user_name}" --dbpass="${db_user_passw}" --locale="${wp_locale}" --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        display --indent 6 --text "- Creating wp-config" --result "DONE" --color GREEN

        return 0
    else

        display --indent 6 --text "- Creating wp-config" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Set/shuffle salts
#
# Arguments:
#   $1 = ${wp_site}
#
# Outputs:
#   0 if salts where set/shuffle, 1 if not.
################################################################################

function wpcli_set_salts() {

    local wp_site="${1}"

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} config shuffle-salts" "false"

    # Command
    sudo -u www-data wp --path="${wp_site}" config shuffle-salts --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        display --indent 6 --text "- Shuffle salts" --result "DONE" --color GREEN
        return 0

    else

        display --indent 6 --text "- Shuffle salts" --result "FAIL" --color RED
        return 1

    fi

}

################################################################################
# Delete not core files
#
# Arguments:
#   $1 = ${wp_site}
#
# Outputs:
#   0 if core files were deleted, 1 if not.
################################################################################

function wpcli_delete_not_core_files() {

    local wp_site="${1}"

    display --indent 6 --text "- Scanning for suspicious WordPress files" --result "DONE" --color GREEN

    mapfile -t wpcli_core_verify_results < <(wpcli_core_verify "${wp_site}")

    for wpcli_core_verify_result in "${wpcli_core_verify_results[@]}"; do
        # Check results
        wpcli_core_verify_result_file=$(echo "${wpcli_core_verify_result}" | grep "should not exist" | cut -d ":" -f3)

        # Remove white space
        wpcli_core_verify_result_file=${wpcli_core_verify_result_file//[[:blank:]]/}

        if [[ -f "${wp_site}/${wpcli_core_verify_result_file}" ]]; then

            rm "${wp_site}/${wpcli_core_verify_result_file}"

            log_event "info" "Deleting not core file: ${wp_site}/${wpcli_core_verify_result_file}"
            display --indent 8 --text "Suspicious file: ${wpcli_core_verify_result_file}"

        fi

    done

    log_event "info" "All unknown files in WordPress core deleted!"
    display --indent 6 --text "- Deleting suspicious WordPress files" --result "DONE" --color GREEN

}

################################################################################
# Get maintenance mode status
#
# Arguments:
#   $1 = ${wp_site}
#
# Outputs:
#   ${maintenance_mode_status}
################################################################################

function wpcli_maintenance_mode_status() {

    local wp_site="${1}"

    local maintenance_mode_status

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} maintenance-mode status" "false"

    # Command
    maintenance_mode_status="$(sudo -u www-data wp --path="${wp_site}" maintenance-mode status)"

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
#   $1 = ${wp_site}
#   $2 = ${mode} - activate/deactivate
#
# Outputs:
#   ${maintenance_mode_status}
################################################################################

function wpcli_maintenance_mode_set() {

    local wp_site="${1}"
    local mode="${2}"

    local maintenance_mode

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} maintenance-mode ${mode}" "false"

    # Command
    maintenance_mode="$(sudo -u www-data wp --path="${wp_site}" maintenance-mode "${mode}")"

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
#   $1 = ${wp_site}
#
# Outputs:
#   0 if the reindex was successful, 1 if not.
################################################################################

function wpcli_seoyoast_reindex() {

    local wp_site="${1}"

    # Log
    display --indent 6 --text "- Running yoast re-index"
    log_event "info" "Running yoast re-index" "false"

    # Command
    sudo -u www-data wp --path="${wp_site}" yoast index --reindex

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
        log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} yoast index --reindex" "false"

        return 1

    fi

}

################################################################################
# Plugin installer menu
#
# Arguments:
#   $1 = ${wp_site}
#
# Outputs:
#   none
################################################################################

function wpcli_default_plugins_installer() {

    local wp_site="${1}"

    local wp_plugins
    local chosen_plugin_option
    local plugin_zip

    # TODO: install from default options, install from zip or install from external config file.
    # TODO: config file should contain something like this:
    # Structure: "PLUGIN_NAME" , "PLUGIN_SOURCE", "PLUGIN_SLUG or PUBLIC_URL", "ACTIVATE_AFTER_INSTALL" (true or false)
    # Example 1: "WP Rocket", "private", "https://example.com/plugin.zip", "false"
    # Example 2: "SEO Yoast", "public-repo", "wordpress-seo", "true"

    # Array of plugin slugs to install
    wp_plugins=(
        "wordpress-seo" " " off
        "seo-by-rank-math" " " off
        "duracelltomi-google-tag-manager" " " off
        "ewww-image-optimizer" " " off
        "post-smtp" " " off
        "contact-form-7" " " off
        "advanced-custom-fields" " " off
        "acf-vc-integrator" " " off
        "wp-asset-clean-up" " " off
        "w3-total-cache" " " off
        "iwp-client" " " off
        "wordfence" " " off
        "better-wp-security" " " off
        "quttera-web-malware-scanner" " " off
        "zip-file" " " off
    )

    # INSTALL_PLUGINS
    chosen_plugin_option="$(whiptail --title "Plugin Selection" --checklist "Select the plugins you want to install." 20 78 15 "${wp_plugins[@]}" 3>&1 1>&2 2>&3)"

    log_subsection "WP Plugin Installer"

    for plugin in ${chosen_plugin_option}; do

        if [[ ${plugin} == *"zip-file"* ]]; then

            plugin_zip="$(whiptail --title "WordPress Plugin" --inputbox "Please insert a public url with a plugin zip file." 10 60 "https://domain.com/plugin.zip" 3>&1 1>&2 2>&3)"
            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then

                plugin="${plugin_zip}"

            fi

        fi

        wpcli_install_plugin "${wp_site}" "${plugin}"

    done

}

################################################################################
# Get WordPress version
#
# Arguments:
#   $1 = ${wp_site}
#
# Outputs:
#   ${core_version}
################################################################################

function wpcli_get_wpcore_version() {

    local wp_site="${1}"

    local core_version

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} core version" "false"

    # Command
    core_version="$(sudo -u www-data wp --path="${wp_site}" core version)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${core_version}"

        return 0

    else

        return 1

    fi

}

################################################################################
# Get database prefix
#
# Arguments:
#   $1 = ${wp_site}
#
# Outputs:
#   ${db_prefix}
################################################################################

function wpcli_db_get_prefix() {

    local wp_site="${1}"

    local db_prefix

    # Log
    display --indent 6 --text "- Getting database prefix"

    # Command
    db_prefix="$(sudo -u www-data wp --path="${wp_site}" db prefix)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${db_prefix}"

        return 0

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
#   $1 = ${wp_site}
#
# Outputs:
#   ${db_check}
################################################################################

function wpcli_db_check() {

    local wp_site="${1}"

    local db_check

    # Log
    display --indent 6 --text "- Checking database credentials"

    # Command
    db_check="$(sudo -u www-data wp --path="${wp_site}" db check)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${db_check}"

    else

        # Log
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
#   $1 = ${wp_site}
#   $2 = ${db_prefix}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_db_change_tables_prefix() {

    local wp_site="${1}"
    local db_prefix="${2}"

    # Log
    display --indent 6 --text "- Changing tables prefix"
    log_event "debug" "Running: wp --allow-root --path=${wp_site} rename-db-prefix ${db_prefix}" "false"

    # Command
    wp --allow-root --path="${wp_site}" rename-db-prefix "${db_prefix}" --no-confirm

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
#   $1 = ${wp_site}
#   $2 = ${search}
#   $3 = ${replace}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_search_and_replace() {

    local wp_site="${1}"
    local search="${2}"
    local replace="${3}"

    local wp_site_url

    # Folder Name need to be the Site URL
    wp_site_url="$(basename "${wp_site}")"

    # Command
    wp --allow-root --path="${wp_site}" core is-installed --network

    is_network=$?
    if [[ ${is_network} -eq 0 ]]; then

        log_event "debug" "Running: wp --allow-root --path=${wp_site} search-replace --url=https://${wp_site_url} ${search} ${replace} --network" "false"

        wpcli_result="$(wp --allow-root --path="${wp_site}" search-replace --url=https://"${wp_site_url}" "${search}" "${replace}" --network)"

    else

        log_event "debug" "Running: wp --allow-root --path=${wp_site} search-replace ${search} ${replace}" "false"

        wpcli_result="$(wp --allow-root --path="${wp_site}" search-replace "${search}" "${replace}")"

    fi

    #exitstatus=$?
    #if [[ $exitstatus -eq 0 ]]; then
    error_found="$(echo "${wpcli_result}" | grep "Error")"
    if [[ ${error_found} == "" ]]; then

        # Log
        log_event "info" "Search and replace finished ok" "false"
        display --indent 6 --text "- Running search and replace" --result "DONE" --color GREEN
        display --indent 8 --text "${search} was replaced by ${replace}" --tcolor YELLOW

        # Cache Flush
        sudo -u www-data wp --path="${wp_site}" cache flush --quiet
        display --indent 6 --text "- Flush cache" --result "DONE" --color GREEN

        # Rewrite Flush
        sudo -u www-data wp --path="${wp_site}" rewrite flush --quiet
        display --indent 6 --text "- Flush rewrite" --result "DONE" --color GREEN

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
#   $1 = ${wp_site}
#   $2 = ${search}
#   $3 = ${replace}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_clean_database() {

    local wp_site="${1}"

    log_event "info" "Executing: wp --path=${wp_site} transient delete --expired --allow-root" "false"

    # Command
    wp --path="${wp_site}" transient delete --expired --allow-root --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        display --indent 2 --text "- Deleting transient" --result "DONE" --color GREEN

        # Command
        wp --path="${wp_site}" cache flush --allow-root --quiet

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
#   $1 = ${wp_site} (site path)
#   $2 = ${dump_file}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_export_database() {

    local wp_site="${1}"
    local dump_file="${2}"

    # Log
    log_event "debug" "Running: wp --allow-root --path=${wp_site} db export ${dump_file}" "false"

    # Command
    wp --allow-root --path="${wp_site}" db export "${dump_file}" --quiet

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
# Create WordPress user
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${user}
#   $3 = ${mail}
#   $4 = ${role}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_user_create() {

    local wp_site="${1}"
    local user="${2}"
    local mail="${3}"
    local role="${4}"

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} user create ${user} ${mail} --role=${role}" "false"

    # Command
    sudo -u www-data wp --path="${wp_site}" user create "${user}" "${mail}" --role="${role}"

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
#   $1 = ${wp_site} (site path)
#   $2 = ${wp_user}
#   $3 = ${wp_user_pass}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_user_reset_passw() {

    local wp_site="${1}"
    local wp_user="${2}"
    local wp_user_pass="${3}"

    # Log
    log_event "info" "User password reset for ${wp_user}. New password: ${wp_user_pass}" "false"
    log_event "debug" "Running: wp --allow-root --path=\"${wp_site}\" user update \"${wp_user}\" --user_pass=\"${wp_user_pass}\"" "false"

    # Command
    wp --allow-root --path="${wp_site}" user update "${wp_user}" --user_pass="${wp_user_pass}" --skip-email

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Password reset for ${wp_user}" --result "DONE" --color GREEN
        display --indent 8 --text "New password ${wp_user_pass}"
        log_event "error" "New password for user ${user} on site ${wp_site}" "false"

        return 0

    else

        # Log
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
#   $1 = ${wp_site} (site path)
#   $2 = ${visibility} (0=off or 1=on)
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_change_wp_seo_visibility() {

    local wp_site="${1}"
    local visibility="${2}"

    log_event "debug" "Running: sudo -u www-data wp --path=\"${wp_site}\" option set blog_public ${visibility}" "false"

    # Command
    sudo -u www-data wp --path="${wp_site}" option set blog_public "${visibility}" --quiet

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
#   $1 = ${wp_site} (site path)
#   $2 = ${upload_path}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_update_upload_path() {

    local wp_site="${1}"
    local upload_path="${2}"

    local wp_command

    log_event "debug" "Running: wp --allow-root --path=\"${wp_site}\" option update upload_path \"${upload_path}\"" "false"

    # wp-cli command
    wp_command="$(wp --allow-root --path="${wp_site}" option update upload_path "${upload_path}")"

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
#   $1 = ${wp_site} (site path)
#   $2 = ${debug_mode} (true or false)
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_set_debug_mode() {

    local wp_site="${1}"
    local debug_mode="${2}"

    # Log
    log_event "debug" "Running: wp --allow-root --path=\"${wp_site}\" config set --raw WP_DEBUG \"${debug_mode}\"" "false"
    log_event "debug" "Running: wp --allow-root --path=\"${wp_site}\" config set --raw WP_DEBUG_LOG \"${debug_mode}\"" "false"
    log_event "debug" "Running: wp --allow-root --path=\"${wp_site}\" config set --raw WP_DEBUG_DISPLAY \"${debug_mode}\"" "false"

    # Command
    wp --allow-root --path="${wp_site}" config set --raw WP_DEBUG "${debug_mode}" --quiet
    wp --allow-root --path="${wp_site}" config set --raw WP_DEBUG_LOG "${debug_mode}" --quiet
    wp --allow-root --path="${wp_site}" config set --raw WP_DEBUG_DISPLAY "${debug_mode}" --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "3"
        display --indent 6 --text "- Set debug mode: ${debug_mode}" --result "DONE" --color GREEN
        log_event "error" "Set debug mode: ${debug_mode}" "false"

        return 0

    else

        # Log
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
#   $1 = ${wp_site} (site path)
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_cache_flush() {

    local wp_site="${1}"

    # Log
    log_event "debug" "Running: wp --allow-root --path=\"${wp_site}\" cache flush" "false"

    # Command
    wp --allow-root --path="${wp_site}" cache flush

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Flush cache" --result "DONE" --color GREEN
        log_event "error" "Cache flush for ${wp_site}" "false"

        return 0

    else

        # Log
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
#   $1 = ${wp_site} (site path)
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_rocket_cache_clean() {

    local wp_site="${1}"

    # Log
    log_event "debug" "Running: wp --allow-root --path=\"${wp_site}\" rocket clean --confirm" "false"

    # Command
    wp --allow-root --path="${wp_site}" rocket clean --confirm

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
#   $1 = ${wp_site} (site path)
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_rocket_cache_activate() {

    local wp_site="${1}"

    # Log
    log_event "debug" "Running: wp --allow-root --path=\"${wp_site}\" rocket activate-cache" "false"

    # Command
    wp --allow-root --path="${wp_site}" rocket activate-cache

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Cache activated for ${wp_site}" --result "DONE" --color GREEN
        log_event "error" "Cache activated for ${wp_site}" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Cache activated for ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Cache activated for ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# WP Rocket: Deactivate cache
#
# Arguments:
#   $1 = ${wp_site} (site path)
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_rocket_cache_deactivate() {

    local wp_site="${1}"

    # Log
    log_event "debug" "Running: wp --allow-root --path=\"${wp_site}\" rocket deactivate-cache" "false"

    # Command
    wp --allow-root --path="${wp_site}" rocket deactivate-cache

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Cache deactivated for ${wp_site}" --result "DONE" --color GREEN
        log_event "error" "Cache deactivated for ${wp_site}" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Cache deactivated for ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Cache deactivated for ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# WP Rocket: Export settings
#
# Arguments:
#   $1 = ${wp_site} (site path)
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_rocket_settings_export() {

    local wp_site="${1}"

    # Log
    log_event "debug" "Running: wp --allow-root --path=\"${wp_site}\" rocket export" "false"

    # Command
    wp --allow-root --path="${wp_site}" rocket export

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Settings exported for ${wp_site}" --result "DONE" --color GREEN
        log_event "error" "Settings exported for ${wp_site}" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Settings exported for ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Settings exported for ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# WP Rocket: Import settings
#
# Arguments:
#   $1 = ${wp_site} (site path)
#   $2 = ${settings_json}
#
# Outputs:
#   0 on success, 1 on error
################################################################################

function wpcli_rocket_settings_import() {

    local wp_site="${1}"
    local settings_json="${2}"

    log_event "debug" "Running: wp --allow-root --path=\"${wp_site}\" rocket import --file=\"${settings_json}\"" "false"

    # Command
    wp --allow-root --path="${wp_site}" rocket import --file="${settings_json}"

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
#   $1 = ${wp_site}
#
# Outputs:
#   ${wp_option_home}
################################################################################

function wpcli_option_get_home() {

    local wp_site="${1}"

    local wp_option_home

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} option get home" "false"

    # Command
    wp_option_home="$(sudo -u www-data wp --path="${wp_site}" option get home)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Getting home for ${wp_site}" --result "DONE" --color GREEN
        display --indent 6 --text "Result: ${wp_option_home}"
        log_event "debug" "wp_option_home:${wp_option_home}" "false"

        # Return
        echo "${wp_option_home}"

        return 0

    else

        # Log
        display --indent 6 --text "- Getting home for ${wp_site}" --result "FAIL" --color RED
        log_event "error" "Getting home for ${wp_site}" "false"

        return 1

    fi

}

################################################################################
# Get configured site url from WordPress installation options
#
# Arguments:
#   $1 = ${wp_site}
#
# Outputs:
#   ${wp_option_siteurl}
################################################################################

function wpcli_option_get_siteurl() {

    local wp_site="${1}"

    local wp_option_siteurl

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} option get siteurl" "false"

    # Command
    wp_option_siteurl="$(sudo -u www-data wp --path="${wp_site}" option get siteurl)"

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
#   $1 = ${wp_site}
#   $2 = ${wp_config_option}
#
# Outputs:
#   0 if option was configured, 1 on error.
################################################################################

function wpcli_config_get() {

    local wp_site="${1}"
    local wp_config_option="${2}"

    # wp-cli command
    wp_config="$(sudo -u www-data wp --path="${wp_site}" config get "${wp_config_option}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "debug" "Command executed: sudo -u www-data wp --path=${wp_site} config get ${wp_config_option}" "false"
        log_event "debug" "wp config get return:${wp_config}" "false"

        return 0

    else

        log_event "debug" "Command executed: sudo -u www-data wp --path=${wp_site} config get ${wp_config_option}" "false"
        log_event "error" "wp config get return:${wp_config}" "false"

        return 1

    fi

}

################################################################################
# Set a configuration option on a WordPress installation.
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${wp_config_option}
#   $3 = ${wp_config_option_value}
#
# Outputs:
#   0 if option was configured, 1 on error.
################################################################################

function wpcli_config_set() {

    local wp_site="${1}"
    local wp_config_option="${2}"
    local wp_config_option_value="${3}"

    # wp-cli command
    wp_config="$(sudo -u www-data wp --path="${wp_site}" config set "${wp_config_option}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "debug" "Command executed: sudo -u www-data wp --path=${wp_site} config set ${wp_config_option} ${wp_config_option_value}" "false"
        log_event "debug" "wp config get return:${wp_config}" "false"

        return 0

    else

        log_event "debug" "Command executed: sudo -u www-data wp --path=${wp_site} config set ${wp_config_option} ${wp_config_option_value}" "false"
        log_event "error" "wp config get return:${wp_config}" "false"

        return 1

    fi

}

################################################################################
# Delete all comments marked as an specific status.
#
# Arguments:
#   $1 = ${wp_site}
#   $2 = ${wp_comment_status} - spam or hold
#
# Outputs:
#   0 if option was configured, 1 on error.
################################################################################

function wpcli_delete_comments() {

    local wp_site="${1}"
    local wp_comment_status="${2}"

    # List comments ids
    comments_ids="$(wp --allow-root --path="${wp_site}" comment list --status="${wp_comment_status}" --format=ids)"

    if [[ -z "${comments_ids}" ]]; then

        # Log
        log_event "info" "There are no comments marked as ${wp_comment_status} for ${wp_site}" "false"
        display --indent 6 --text "- Deleting comments marked as ${wp_comment_status}" --result "0" --color WHITE

        return 0

    else

        # Delete all comments listed as "${wp_comment_status}"
        wpcli_result="$(wp --allow-root --path="${wp_site}" comment delete "${comments_ids}" --force)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Log
            log_event "info" "Comments marked as ${wp_comment_status} deleted for ${wp_site}" "false"
            log_event "debug" "Command result: ${wpcli_result}" "false"
            display --indent 6 --text "- Deleting comments marked as ${wp_comment_status}" --result "DONE" --color GREEN

            return 0

        else

            # Log
            log_event "error" "Deleting comments marked as ${wp_comment_status} for ${wp_site}" "false"
            log_event "debug" "Las command executed: wp --allow-root --path=${wp_site} comment delete \"${comments_ids}\" --format=ids) --force" "false"
            display --indent 6 --text "- Deleting comments marked as ${wp_comment_status}" --result "FAIL" --color RED

            return 1

        fi

    fi

}

function wpcli_rollback_wpcore_version() {

    # TODO: implement this

    wpcli_get_wp_version

}
