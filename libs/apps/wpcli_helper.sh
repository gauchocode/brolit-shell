#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.39
################################################################################
#
# WP-CLI Helper: Perform wpcli actions.
#
# Refs: https://developer.wordpress.org/cli/commands/
#
################################################################################

################################################################################
# Installs wpcli if not installed.
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
# Check if wpcli is installed.
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
# Check wpcli version.
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
# Install wpcli.
#
# Arguments:
#   None
#
# Outputs:
#   0 if wpcli was installed, 1 on error.
################################################################################

function wpcli_install() {

    log_event "info" "Installing wp-cli ..."
    display --indent 6 --text "- Installing wp-cli"

    # Download wp-cli
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        chmod +x wp-cli.phar
        mv wp-cli.phar "/usr/local/bin/wp"

        # Log
        clear_last_line
        clear_last_line
        clear_last_line
        clear_last_line
        display --indent 6 --text "- Installing wp-cli" --result "DONE" --color GREEN
        log_event "info" "wp-cli installed" "false"

        return 0

    else

        # Log
        clear_last_line
        clear_last_line
        clear_last_line
        clear_last_line
        display --indent 6 --text "- Installing wp-cli" --result "FAIL" --color RED
        log_event "error" "wp-cli was not installed!" "false"

        return 1

    fi

}

################################################################################
# Update wpcli.
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
# Uninstall wpcli.
#
# Arguments:
#   None
#
# Outputs:
#   0 if wpcli was uninstalled, 1 on error.
################################################################################

function wpcli_uninstall() {

    log_event "warning" "Uninstalling wp-cli ..."

    rm --recursive --force "/usr/local/bin/wp"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "info" "wp-cli uninstalled" "false"
        display --indent 6 --text "- Uninstalling wp-cli" --result "DONE" --color GREEN

        return 0

    else

        log_event "error" "wp-cli was not uninstalled!" "false"
        display --indent 6 --text "- Uninstalling wp-cli" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Check if a wpcli package is installed.
#
# Arguments:
#   $1 = ${wpcli_package}
#
# Outputs:
#   "true" if wpcli package is installed, "false" if not.
################################################################################

function wpcli_check_if_package_is_installed() {

    local wpcli_package=$1

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

### wpcli core

function wpcli_core_download() {

    # $1 = ${wp_site}
    # $2 = ${wp_version} optional

    local wp_site=$1
    local wp_version=$2

    local wpcli_result

    if [[ ${wp_site} != "" ]]; then

        if [[ ${wp_version} != "" ]]; then

            # wp-cli command
            sudo -u www-data wp --path="${wp_site}" core download --version="${wp_version}" --quiet

            # Log
            log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} core download --version=${wp_version}"
            display --indent 6 --text "- Downloading WordPress ${wp_version}"

            sleep 15

            clear_last_line

            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then
                display --indent 6 --text "- Downloading WordPress ${wp_version}" --result "DONE" --color GREEN
                display --indent 8 --text "${wp_site}" --tcolor GREEN

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

            clear_last_line

            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then
                display --indent 6 --text "- Wordpress installation for ${wp_site}" --result "DONE" --color GREEN

            else
                display --indent 6 --text "- Wordpress installation for ${wp_site}" --result "FAIL" --color RED
                return 1
            fi

        fi

    else
        # Log failure
        error_msg="wp_site can't be empty!"
        log_event "fail" "${error_msg}" "true"
        display --indent 6 --text "- Wordpress installation for ${wp_site}" --result "FAIL" --color RED
        display --indent 8 --text "${error_msg}"

        # Return
        return 1

    fi

}

function wpcli_core_reinstall() {

    # This will replace wordpress core files (didnt delete other files)
    # Ref: https://github.com/wp-cli/wp-cli/issues/221

    # $1 = ${wp_site}
    # $2 = ${wp_version} optional

    local wp_site=$1
    local wp_version=$2

    local wpcli_result

    if [[ ${wp_site} != "" ]]; then

        log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} core download --skip-content --force"

        wpcli_result=$(sudo -u www-data wp --path="${wp_site}" core download --skip-content --force 2>&1 | grep "Success" | cut -d ":" -f1)

        if [[ "${wpcli_result}" = "Success" ]]; then

            # Log Success
            log_event "info" "Wordpress re-installed"
            display --indent 6 --text "- Wordpress re-install for ${wp_site}" --result "DONE" --color GREEN

            # Return
            echo "success"

        else

            # Log failure
            log_event "fail" "Something went wrong installing WordPress"
            display --indent 6 --text "- Wordpress re-install for ${wp_site}" --result "FAIL" --color RED

            # Return
            echo "fail"

        fi

    else
        # Log failure
        log_event "fail" "wp_site can't be empty!"
        display --indent 6 --text "- Wordpress re-install for ${wp_site}" --result "FAIL" --color RED
        display --indent 8 --text "wp_site can't be empty"

        # Return
        echo "fail"

    fi

}

function wpcli_core_update() {

    # $1 = ${wp_site}

    local wp_site=$1
    local verify_core_update

    log_section "WordPress Updater"

    verify_core_update="$(sudo -u www-data wp --path="${wp_site}" update | grep ":" | cut -d ':' -f1)"

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

    else

        log_event "error" "Wordpress update failed" "false"
        display --indent 6 --text "- Download new WordPress version" --result "FAIL" --color RED

    fi

    echo "${verify_core_update}" #if ok, return "Success"

}

function wpcli_core_verify() {

    # $1 = ${wp_site}

    local wp_site=$1
    local verify_core

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} core verify-checksums" "false"

    mapfile verify_core < <(sudo -u www-data wp --path="${wp_site}" core verify-checksums 2>&1)

    display --indent 6 --text "- WordPress verify-checksums" --result "DONE" --color GREEN

    # Return an array with wp-cli output
    echo "${verify_core[@]}"

}

### wpcli plugins

function wpcli_plugin_verify() {

    # $1 = ${wp_site}
    # $2 = ${plugin} could be --all?

    local wp_site=$1
    local plugin=$2

    local verify_plugin

    if [ "${plugin}" = "" ]; then
        plugin="--all"
    fi

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin verify-checksums ${plugin}"

    mapfile verify_plugin < <(sudo -u www-data wp --path="${wp_site}" plugin verify-checksums "${plugin}" 2>&1)

    display --indent 6 --text "- WordPress plugin verify-checksums" --result "DONE" --color GREEN

    # Return an array with wp-cli output
    echo "${verify_plugin[@]}"

}

function wpcli_install_plugin() {

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)

    local wp_site=$1
    local plugin=$2

    # Log
    display --indent 6 --text "- Installing plugin ${plugin}"
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin install ${plugin}"

    # Command
    sudo -u www-data wp --path="${wp_site}" plugin install "${plugin}" --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        clear_last_line
        display --indent 6 --text "- Installing plugin ${plugin}" --result "DONE" --color GREEN

    else

        clear_last_line
        display --indent 6 --text "- Installing plugin ${plugin}" --result "FAIL" --color RED

    fi

}

function wpcli_plugin_update() {

    # $1 = ${wp_site}
    # $2 = ${plugin} could be --all?

    local wp_site=$1
    local plugin=$2

    local plugin_update

    if [[ ${plugin} == "" ]]; then
        plugin="--all"
    fi

    mapfile plugin_update < <(sudo -u www-data wp --path="${wp_site}" plugin update "${plugin}" --format=json --quiet 2>&1)

    # Return an array with wp-cli output
    echo "${plugin_update[@]}"

}

function wpcli_plugin_get_version() {

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin}

    local wp_site=$1
    local plugin=$2

    local plugin_version

    plugin_version="$(sudo -u www-data wp --path="${wp_site}" plugin get "${plugin}" --format=json | cut -d "," -f 4 | cut -d ":" -f 2)"

    # Return
    echo "${plugin_version}"

}

function wpcli_plugin_activate() {

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)

    local wp_site=$1
    local plugin=$2

    # Log
    display --indent 6 --text "- Activating plugin ${plugin}"
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin activate ${plugin}"

    # Command
    sudo -u www-data wp --path="${wp_site}" plugin activate "${plugin}" --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        clear_last_line
        display --indent 6 --text "- Activating plugin ${plugin}" --result "DONE" --color GREEN

    else

        clear_last_line
        display --indent 6 --text "- Activating plugin ${plugin}" --result "FAIL" --color RED

    fi

}

function wpcli_plugin_deactivate() {

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to install, it could the plugin slug or a public access to the zip file)

    local wp_site=$1
    local plugin=$2

    # Log
    display --indent 6 --text "- Deactivating plugin ${plugin}"
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin deactivate ${plugin}"

    # Command
    sudo -u www-data wp --path="${wp_site}" plugin deactivate "${plugin}" --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        clear_last_line
        display --indent 6 --text "- Deactivating plugin ${plugin}" --result "DONE" --color GREEN

    else

        clear_last_line
        display --indent 6 --text "- Deactivating plugin ${plugin}" --result "FAIL" --color RED

    fi

}

function wpcli_plugin_delete() {

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to delete)

    local wp_site=$1
    local plugin=$2

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin delete ${plugin}"
    display --indent 6 --text "- Deleting plugin ${plugin}" --result "DONE" --color GREEN

    sudo -u www-data wp --path="${wp_site}" plugin delete "${plugin}" --quiet

    clear_last_line
    display --indent 6 --text "- Deleting plugin ${plugin}" --result "DONE" --color GREEN

}

function wpcli_plugin_is_active() {

    # Check whether plugin is active; exit status 0 if active, otherwise 1

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to delete)

    local wp_site=$1
    local plugin=$2

    sudo -u www-data wp --path="${wp_site}" plugin is-installed "${plugin}"

    # Return
    echo $?

}

function wpcli_plugin_is_installed() {

    # Check whether plugin is installed; exit status 0 if installed, otherwise 1

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to delete)

    local wp_site=$1
    local plugin=$2

    sudo -u www-data wp --path="${wp_site}" plugin is-installed "${plugin}"

    # Return
    echo $?

}

function wpcli_force_reinstall_plugins() {

    # $1 = ${wp_site}
    # $2 = ${plugin}

    local wp_site=$1
    local plugin=$2

    local verify_plugin

    if [ "${plugin}" = "" ]; then

        log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin install $(ls -1p "${wp_site}"/wp-content/plugins | grep '/$' | sed 's/\/$//') --force"
        sudo -u www-data wp --path="${wp_site}" plugin install "$(ls -1p "${wp_site}"/wp-content/plugins | grep '/$' | sed 's/\/$//')" --force

    else
        log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} plugin install ${plugin} --force"
        sudo -u www-data wp --path="${wp_site}" plugin install "${plugin}" --force

        display --indent 6 --text "- Plugin force install ${plugin}" --result "DONE" --color GREEN

    fi

    # TODO: save ouput on array with mapfile
    #mapfile verify_plugin < <(sudo -u www-data wp --path="${wp_site}" plugin verify-checksums "${plugin}" 2>&1)
    #echo "${verify_plugin[@]}"

}

# The idea is that when you update wordpress or a plugin, get the actual version,
# then run a dry-run update, if success, update but show a message if you want to
# persist the update or want to do a rollback

function wpcli_rollback_plugin_version() {

    # TODO: implement this
    # $1= wp_site
    # $2= wp_plugin
    # $3= wp_plugin_v (version to install)

    #sudo -u www-data wp --path="${wp_site}" plugin update "${wp_plugin}" --version="${wp_plugin_v}" --dry-run
    #sudo -u www-data wp --path="${wp_site}" plugin update "${wp_plugin}" --version="${wp_plugin_v}"

    wpcli_plugin_get_version "" ""

}

### wpcli themes

function wpcli_theme_install() {

    # $1 = ${wp_site} (site path)
    # $2 = ${theme} (theme to delete)

    local wp_site=$1
    local theme=$2

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} theme install ${theme} --activate"

    sudo -u www-data wp --path="${wp_site}" theme install "${theme}" --activate

    display --indent 6 --text "- Installing and activating theme ${theme}" --result "DONE" --color GREEN

}

function wpcli_theme_delete() {

    # $1 = ${wp_site} (site path)
    # $2 = ${theme} (theme to delete)

    local wp_site=$1
    local theme=$2

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} theme delete ${theme}"

    sudo -u www-data wp --path="${wp_site}" theme delete "${theme}" --quiet

    display --indent 6 --text "- Deleting theme ${theme}" --result "DONE" --color GREEN

}

### wpcli scripts

function wpcli_run_startup_script() {

    # $1 = ${wp_site}           - Site path
    # $1 = ${site_url}          - Site URL
    # $2 = ${site_name}         - Site Display Name
    # $3 = ${wp_user_name}
    # $4 = ${wp_user_passw}
    # $5 = ${wp_user_mail}

    local wp_site=$1
    local site_url=$2
    local site_name=$3
    local wp_user_name=$4
    local wp_user_passw=$5
    local wp_user_mail=$6

    if [[ ${site_name} == "" ]]; then
        site_name="$(whiptail --title "Site Name" --inputbox "Insert the site name. Example: My Website" 10 60 3>&1 1>&2 2>&3)"
    fi
    exitstatus=$?
    if [[ ${exitstatus} == "" ]]; then
        # Return
        return 1

    fi
    # TODO: check if receive a domain or a url like: http://siteurl.com
    if [[ ${site_url} == "" ]]; then
        site_url="$(whiptail --title "Site URL" --inputbox "Insert the site URL. Example: mydomain.com" 10 60 3>&1 1>&2 2>&3)"
    fi
    exitstatus=$?
    if [[ ! ${exitstatus} -eq 0 ]]; then
        # Return
        return 1

    fi
    if [[ ${wp_user_name} == "" ]]; then
        wp_user_name="$(whiptail --title "Wordpress User" --inputbox "Insert a username for admin." 10 60 3>&1 1>&2 2>&3)"
    fi
    exitstatus=$?
    if [[ ! ${exitstatus} -eq 0 ]]; then
        # Return
        return 1

    fi
    if [[ ${wp_user_passw} == "" ]]; then
        wp_user_passw="$(whiptail --title "Site Name" --inputbox "Insert the user password." 10 60 3>&1 1>&2 2>&3)"
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

    # Install WordPress Site
    sudo -u www-data wp --path="${wp_site}" core install --url="${site_url}" --title="${site_name}" --admin_user="${wp_user_name}" --admin_password="${wp_user_passw}" --admin_email="${wp_user_mail}"
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} core install --url=${site_url} --title=${site_name} --admin_user=${wp_user_name} --admin_password=${wp_user_passw} --admin_email=${wp_user_mail}"

    clear_last_line
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

function wpcli_create_config() {

    # $1 = ${wp_site}
    # $2 = ${database}
    # $3 = ${db_user_name}
    # $4 = ${db_user_passw}
    # $4 = ${wp_locale}

    local wp_site=$1
    local database=$2
    local db_user_name=$3
    local db_user_passw=$4
    local wp_locale=$5

    if [[ ${wp_locale} == "" ]]; then
        wp_locale="es_ES"
    fi

    # Log
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} config create --dbname=${database} --dbuser=${db_user_name} --dbpass=${db_user_passw} --locale=${wp_locale}"

    # wp-cli command
    sudo -u www-data wp --path="${wp_site}" config create --dbname="${database}" --dbuser="${db_user_name}" --dbpass="${db_user_passw}" --locale="${wp_locale}" --quiet

    exitstatus=$?
    if [[ ! ${exitstatus} -eq 0 ]]; then

        display --indent 6 --text "- Creating wp-config" --result "DONE" --color GREEN
    else

        display --indent 6 --text "- Creating wp-config" --result "FAIL" --color RED
        return 1

    fi

}

function wpcli_set_salts() {

    # $1 = ${wp_site}

    local wp_site=$1

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} config shuffle-salts" "false"

    # Command
    sudo -u www-data wp --path="${wp_site}" config shuffle-salts --quiet

    exitstatus=$?
    if [[ ! ${exitstatus} -eq 0 ]]; then

        display --indent 6 --text "- Shuffle salts" --result "DONE" --color GREEN
    else

        display --indent 6 --text "- Shuffle salts" --result "FAIL" --color RED
        return 1

    fi

}

function wpcli_delete_not_core_files() {

    # $1 = ${wp_site}

    local wp_site=$1

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

function wpcli_maintenance_mode_status() {

    WPCLI_V="$(sudo -u www-data wp --info | grep "WP-CLI version:" | cut -d ':' -f2)"

    # Return
    echo "${WPCLI_V}"

}

function wpcli_maintenance_mode() {

    # $1 = ${mode} (activate or deactivate)

    local mode=$1

    local maintenance_mode

    maintenance_mode="$(sudo -u www-data wp maintenance-mode "${mode}")"

    # Return
    echo "${maintenance_mode}"

}

function wpcli_seoyoast_reindex() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    # Log
    display --indent 6 --text "- Running yoast re-index"
    log_event "info" "Running yoast re-index"
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} yoast index --reindex"

    # Command
    sudo -u www-data wp --path="${wp_site}" yoast index --reindex

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_last_line
        display --indent 6 --text "- Running yoast re-index" --result "DONE" --color GREEN
        log_event "info" "Yoast re-index done!"

    else

        # Log
        clear_last_line
        display --indent 6 --text "- Running yoast re-index" --result "FAIL" --color RED
        log_event "error" "Yoast re-index failed!"

    fi

}

function wpcli_get_wpcore_version() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    local core_version

    core_version="$(sudo -u www-data wp --path="${wp_site}" core version)"

    # Return
    echo "${core_version}"

}

function wpcli_get_db_prefix() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    DB_PREFIX=$(sudo -u www-data wp --path="${wp_site}" db prefix)

    # Return
    echo "${DB_PREFIX}"

}

function wpcli_change_tables_prefix() {

    # $1 = ${wp_site} (site path)
    # $2 = ${db_prefix}

    local wp_site=$1
    local db_prefix=$2

    log_event "debug" "Running: wp --allow-root --path=${wp_site} rename-db-prefix ${db_prefix}" "false"
    display --indent 6 --text "- Changing tables prefix"

    wp --allow-root --path="${wp_site}" rename-db-prefix "${db_prefix}" --no-confirm

    #clear_last_line
    display --indent 6 --text "- Changing tables prefix" --result "DONE" --color GREEN
    display --indent 8 --text "New tables prefix ${TABLES_PREFIX}"

}

function wpcli_search_and_replace() {

    # Ref: https://developer.wordpress.org/cli/commands/search-replace/

    # $1 = ${wp_site} (site path)
    # $2 = ${search}
    # $3 = ${replace}

    local wp_site=$1
    local search=$2
    local replace=$3

    #local wp_site_url

    # Folder Name need to be the Site URL
    wp_site_url=$(basename "${wp_site}")

    wp --allow-root --path="${wp_site}" core is-installed --network
    is_network=$?
    if [ "${is_network}" -eq 0 ]; then

        log_event "debug" "Running: wp --allow-root --path=${wp_site} search-replace --url=https://${wp_site_url} ${search} ${replace} --network" "false"

        wp --allow-root --path="${wp_site}" search-replace --url=https://"${wp_site_url}" "${search}" "${replace}" --network --quiet

        display --indent 6 --text "- Running search and replace" --result "DONE" --color GREEN
        display --indent 8 --text "${search} was replaced by ${replace}"

    else

        log_event "debug" "Running: wp --allow-root --path=${wp_site} search-replace ${search} ${replace}" "false"

        wp --allow-root --path="${wp_site}" search-replace "${search}" "${replace}" --quiet

        display --indent 6 --text "- Running search and replace" --result "DONE" --color GREEN
        display --indent 8 --text "${search} was replaced by ${replace}"

    fi

    log_event "debug" "Running: wp --allow-root --path=${wp_site} cache flush" "false"

    wp --allow-root --path="${wp_site}" cache flush --quiet

    display --indent 6 --text "- Flushing cache" --result "DONE" --color GREEN

}

function wpcli_clean_database() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    log_event "info" "Executing: wp --path=${wp_site} transient delete --expired --allow-root" "false"
    wp --path="${wp_site}" transient delete --expired --allow-root --quiet

    display --indent 2 --text "- Deleting transient" --result "DONE" --color GREEN

    log_event "info" "Executing: wp --path=${wp_site} cache flush --allow-root" "false"
    wp --path="${wp_site}" cache flush --allow-root --quiet

    display --indent 2 --text "- Flushing cache" --result "DONE" --color GREEN

}

function wpcli_export_database() {

    # $1 = ${wp_site} (site path)
    # $2 = ${dump_file}

    local wp_site=$1
    local dump_file=$2

    log_event "debug" "Running: wp --allow-root --path=${wp_site} db export ${dump_file}" "false"
    wp --allow-root --path="${wp_site}" db export "${dump_file}" --quiet

    display --indent 6 --text "- Exporting database ${wp_site}" --result "DONE" --color GREEN

}

function wpcli_rollback_wpcore_version() {

    # TODO: implement this

    wpcli_get_wp_version

}

function wpcli_user_create() {

    # $1 = ${wp_site}
    # $2 = ${user}
    # $3 = ${mail}
    # $3 = ${role}

    local wp_site=$1
    local user=$2
    local mail=$3
    local role=$4

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} user create ${user} ${mail} --role=${role}"

    sudo -u www-data wp --path="${wp_site}" user create "${user}" "${mail}" --role="${role}"

    display --indent 6 --text "- Adding WP user: ${user}" --result "DONE" --color GREEN

}

function wpcli_user_reset_passw() {

    # $1 = ${wp_site} (site path)
    # $2 = ${wp_user}
    # $3 = ${wp_user_pass}

    local wp_site=$1
    local wp_user=$2
    local wp_user_pass=$3

    log_event "info" "User password reset for ${wp_user}. New password: ${wp_user_pass}" "false"
    wp --allow-root --path="${wp_site}" user update "${wp_user}" --user_pass="${wp_user_pass}"

    display --indent 6 --text "- Password reset for ${wp_user}" --result "DONE" --color GREEN
    display --indent 8 --text "New password ${wp_user_pass}"

}

### wpcli plugins specific functions

function wpcli_change_wp_seo_visibility() {

    # $1 = ${wp_site} (site path)
    # $2 = ${visibility} (0=off or 1=on)

    local wp_site=$1
    local visibility=$2

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} option set blog_public ${visibility}"
    sudo -u www-data wp --path="${wp_site}" option set blog_public "${visibility}" --quiet

    display --indent 6 --text "- Changing site visibility to ${visibility}" --result "DONE" --color GREEN

}
function wpcli_rocket_cache_clean() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    wp --allow-root --path="${wp_site}" rocket clean --confirm

    display --indent 6 --text "- Cache purge for ${wp_site}" --result "DONE" --color GREEN

}

function wpcli_rocket_cache_activate() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    wp --allow-root --path="${wp_site}" rocket activate-cache

    display --indent 6 --text "- Cache activated for ${wp_site}" --result "DONE" --color GREEN

}

function wpcli_rocket_cache_deactivate() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    wp --allow-root --path="${wp_site}" rocket deactivate-cache

    display --indent 6 --text "- Cache deactivated for ${wp_site}" --result "DONE" --color GREEN

}

function wpcli_rocket_settings_export() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    wp --allow-root --path="${wp_site}" rocket export

    display --indent 6 --text "- Settings exported for ${wp_site}" --result "DONE" --color GREEN

}

function wpcli_rocket_settings_import() {

    # $1 = ${wp_site} (site path)
    # $2 = ${settings_json}

    local wp_site=$1
    local settings_json=$2

    wp --allow-root --path="${wp_site}" rocket import --file="${settings_json}"

    display --indent 6 --text "- Settings imported for ${wp_site}" --result "DONE" --color GREEN

}

################################################################################

# TODO: maybe a single function to get all options?
# Ref: https://codex.wordpress.org/Option_Reference

function wpcli_option_get_home() {

    # $1 = ${wp_site}

    local wp_site=$1
    local wp_option_home

    # wp-cli command
    wp_option_home="$(sudo -u www-data wp --path="${wp_site}" option get home)"

    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} option get home"
    log_event "info" "wp_option_home:${wp_option_home}"

    # Return
    echo "${wp_option_home}"

}

function wpcli_option_get_siteurl() {

    # $1 = ${wp_site}

    local wp_site=$1
    local wp_option_siteurl

    # wp-cli command
    wp_option_siteurl="$(sudo -u www-data wp --path="${wp_site}" option get siteurl)"

    # Log
    log_event "debug" "Running: sudo -u www-data wp --path=${wp_site} option get siteurl" "false"
    log_event "info" "wp_option_siteurl:${wp_option_siteurl}" "false"

    # Return
    echo "${wp_option_siteurl}"

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

    # $1 = ${wp_site}
    # $2 = ${wp_config_option}

    local wp_site=$1
    local wp_config_option=$2

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

    # $1 = ${wp_site}
    # $2 = ${wp_config_option}
    # $3 = ${wp_config_option_value}

    local wp_site=$1
    local wp_config_option=$2
    local wp_config_option_value=$3

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
