#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.9
################################################################################

wpcli_install_if_not_installed() {

    local wpcli 
    
    wpcli="$(which wp)"

    if [ ! -x "${wpcli}" ]; then
        wpcli_install
    fi

}

wpcli_check_if_installed() {

    local wpcli_installed wpcli_v
    
    wpcli_installed="true"

    wpcli_v=$(wpcli_check_version)

    if [[ -z "${wpcli_v}" ]]; then
        wpcli_installed="false"

    fi

    # Return
    echo "${wpcli_installed}"

}

wpcli_check_version() {

    local wpcli_v

    wpcli_v=$(sudo -u www-data wp --info | grep "WP-CLI version:" | cut -d ':' -f2)

    # Return
    echo "${wpcli_v}"

}

wpcli_install() {

    log_event "info" "Installing wp-cli ..."

    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

    chmod +x wp-cli.phar
    sudo mv wp-cli.phar "/usr/local/bin/wp"

    log_event "success" "wp-cli installed"
    display --indent 6 --text "- Installing wp-cli" --result "DONE" --color GREEN
    
}

wpcli_update() {

    log_event "info" "Running: wp-cli update"

    wp cli update --quiet

    log_event "success" "wp-cli installed"
    display --indent 6 --text "- Updating wp-cli" --result "DONE" --color GREEN

}

wpcli_uninstall() {

    log_event "warning" "Uninstalling wp-cli ..."

    rm "/usr/local/bin/wp"

    display --indent 6 --text "- Uninstalling wp-cli" --result "DONE" --color GREEN

}

wpcli_run_startup_script(){

    # $1 = ${site_name}
    # $2 = ${site_url}
    # $3 = ${wp_user_name}
    # $4 = ${wp_user_passw}
    # $5 = ${wp_user_mail}

    local wp_site=$1
    local site_name=$2
    local site_url=$3
    local wp_user_name=$4
    local wp_user_passw=$5
    local wp_user_mail=$6

    if [[ "${site_name}" == "" ]]; then
        site_name=$(whiptail --title "Site Name" --inputbox "Insert the site name. Example: My Website" 10 60 3>&1 1>&2 2>&3)
    fi
    exitstatus=$?
    if [[ ${exitstatus} == "" ]]; then
        # Return
        return 1

    fi
    if [[ "${site_url}" == "" ]]; then
        site_url=$(whiptail --title "Site URL" --inputbox "Insert the site URL. Example: mydomain.com" 10 60 3>&1 1>&2 2>&3)
    fi
    exitstatus=$?
    if [[ ! ${exitstatus} -eq 0 ]]; then
        # Return
        return 1

    fi
    if [[ "${wp_user_name}" == "" ]]; then
        wp_user_name=$(whiptail --title "Wordpress User" --inputbox "Insert a username for admin." 10 60 3>&1 1>&2 2>&3)
    fi
    exitstatus=$?
    if [[ ! ${exitstatus} -eq 0 ]]; then
        # Return
        return 1

    fi
    if [[ "${wp_user_passw}" == "" ]]; then
        wp_user_passw=$(whiptail --title "Site Name" --inputbox "Insert the user password." 10 60 3>&1 1>&2 2>&3)
    fi
    exitstatus=$?
    if [[ ! ${exitstatus} -eq 0 ]]; then
        # Return
        return 1

    fi
    if [[ "${wp_user_mail}" == "" ]]; then
        wp_user_mail=$(whiptail --title "WordPress User Mail" --inputbox "Insert the user email." 10 60 3>&1 1>&2 2>&3)
    fi
    exitstatus=$?
    if [[ ! ${exitstatus} -eq 0 ]]; then
        # Return
        return 1

    fi

    # Create wp-config
    wpcli_create_config "${project_dir}" "${database_name}" "${database_user}" "${database_user_passw}" "es_ES"

    # Install WordPress Site
    sudo -u www-data wp --path="${wp_site}" core install --url="${site_url}" --title="${site_name}" --admin_user="${wp_user_name}" --admin_password="${wp_user_passw}" --admin_email="${wp_user_mail}"
    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} core install --url=${site_url} --title=${site_name} --admin_user=${wp_user_name} --admin_password=${wp_user_passw} --admin_email=${wp_user_mail}" "true"

    display --indent 6 --text "- Deleting default content" --result "DONE" --color GREEN

    # Delete default post, page, and comment
    sudo -u www-data wp --path="${wp_site}" site empty --yes --quiet
    display --indent 6 --text "- Deleting default content" --result "DONE" --color GREEN

    # Delete default themes
    sudo -u www-data wp --path="${wp_site}" theme delete twentyseventeen --quiet
    sudo -u www-data wp --path="${wp_site}" theme delete twentynineteen --quiet
    display --indent 6 --text "- Deleting default themes" --result "DONE" --color GREEN

    # Deleting default content
    sudo -u www-data wp --path="${wp_site}" site empty --yes
    display --indent 6 --text "- Deleting default content" --result "DONE" --color GREEN
    
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

wpcli_create_config(){

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

    if [ "${wp_locale}" = "" ]; then
        wp_locale="es_ES"
    fi

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} config create --dbname=${database} --dbuser=${db_user_name} --dbpass=${db_user_passw} --locale=${wp_locale}"

    sudo -u www-data wp --path="${wp_site}" config create --dbname="${database}" --dbuser="${db_user_name}" --dbpass="${db_user_passw}" --locale="${wp_locale}" --quiet

    display --indent 6 --text "- Creating wp-config" --result "DONE" --color GREEN

}

wpcli_install_needed_extensions() {

    # Rename DB Prefix
    wp --allow-root package install "iandunn/wp-cli-rename-db-prefix"
    
    # Salts
    wp --allow-root package install "sebastiaandegeus/wp-cli-salts-comman"
    
    # Vulnerability Scanner
    wp --allow-root package install "git@github.com:10up/wp-vulnerability-scanner.git"

}

wpcli_set_salts() {

    # $1 = ${wp_site}

    local wp_site=$1

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} config shuffle-salts" "false"

    sudo -u www-data wp --path="${wp_site}" config shuffle-salts --quiet

    display --indent 6 --text "- Shuffle salts" --result "DONE" --color GREEN

}

wpcli_core_install() {

    # $1 = ${wp_site}
    # $2 = ${wp_version} optional

    local wp_site=$1
    local wp_version=$2

    local wpcli_result

    if [ "${wp_site}" != "" ]; then

        if [ "${wp_version}" != "" ];then

            sudo -u www-data wp --path="${wp_site}" core download --version="${wp_version}" --quiet
            log_event "info" "Running: sudo -u www-data wp --path=${wp_site} core download --version=${wp_version}"

            display --indent 6 --text "- Downloading wordpress"

            sleep 10

            clear_last_line

            wpcli_run_startup_script "${wp_site}"
            exitstatus="$?"
            if [[ ${exitstatus} -eq 0 ]]; then
                display --indent 6 --text "- Wordpress ${wp_version} installation for ${wp_site}" --result "DONE" --color GREEN
            else
                display --indent 6 --text "- Wordpress installation for ${wp_site}" --result "FAIL" --color RED
                return 1
            fi

        else

            sudo -u www-data wp --path="${wp_site}" core download --quiet

            log_event "info" "Running: sudo -u www-data wp --path=${wp_site} core download"
            display --indent 6 --text "- Downloading wordpress"

            sleep 10

            clear_last_line

            wpcli_run_startup_script "${wp_site}"
            exitstatus="$?"
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

wpcli_core_reinstall() {

    # This will replace wordpress core files (didnt delete other files)
    # Ref: https://github.com/wp-cli/wp-cli/issues/221

    # $1 = ${wp_site}
    # $2 = ${wp_version} optional

    local wp_site=$1
    local wp_version=$2

    local wpcli_result

    if [ "${wp_site}" != "" ]; then

        log_event "info" "Running: sudo -u www-data wp --path=${wp_site} core download --skip-content --force"

        wpcli_result=$(sudo -u www-data wp --path="${wp_site}" core download --skip-content --force 2>&1 | grep "Success" | cut -d ":" -f1)

        if [ "${wpcli_result}" = "Success" ]; then

            # Log Success
            log_event "success" "Wordpress re-installed"
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

wpcli_core_update() {

    # $1 = ${wp_site}

    local wp_site=$1
    local verify_core_update

    log_section "WordPress Updater"

    verify_core_update=$(sudo -u www-data wp --path="${wp_site}" update | grep ":" | cut -d ':' -f1)
    
    if [ "${verify_core_update}" = "Success" ];then

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

        log_event "success" "Wordpress core updated" "false"
        display --indent 6 --text "- Finishing update" --result "DONE" --color GREEN

    else

        log_event "error" "Wordpress update failed" "false"
        display --indent 6 --text "- Download new WordPress version" --result "FAIL" --color RED
    
    fi

    echo "${verify_core_update}" #if ok, return "Success"

}

wpcli_core_verify() {

    # $1 = ${wp_site}

    local wp_site=$1
    local verify_core

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} core verify-checksums" "false"
    mapfile verify_core < <(sudo -u www-data wp --path="${wp_site}" core verify-checksums 2>&1)

    display --indent 6 --text "- WordPress verify-checksums" --result "DONE" --color GREEN

    # Return an array with wp-cli output
    echo "${verify_core[@]}"

}

wpcli_plugin_verify() {

    # $1 = ${wp_site}
    # $2 = ${plugin} could be --all?

    local wp_site=$1
    local plugin=$2

    local verify_plugin   

    if [ "${plugin}" = "" ]; then
        plugin="--all"
    fi

    log_event "info" "Running: sudo -u www-data wp --path="${wp_site}" plugin verify-checksums ${plugin}" "false"
    mapfile verify_plugin < <(sudo -u www-data wp --path="${wp_site}" plugin verify-checksums "${plugin}" 2>&1)

    display --indent 6 --text "- WordPress plugin verify-checksums" --result "DONE" --color GREEN

    # Return an array with wp-cli output
    echo "${verify_plugin[@]}"

}

wpcli_delete_not_core_files() {

    # $1 = ${wp_site}

    local wp_site=$1

    display --indent 6 --text "- Scanning for suspicious WordPress files" --result "DONE" --color GREEN

    mapfile -t wpcli_core_verify_results < <( wpcli_core_verify "${wp_site}" )

    for wpcli_core_verify_result in "${wpcli_core_verify_results[@]}"
    do
        # Check results
        wpcli_core_verify_result_file=$(echo "${wpcli_core_verify_result}" |  grep "should not exist" | cut -d ":" -f3)
        
        # Remove white space
        wpcli_core_verify_result_file=${wpcli_core_verify_result_file//[[:blank:]]/}
        
        if test -f "${wp_site}/${wpcli_core_verify_result_file}"; then

            log_event "info" "Deleting not core file: ${wp_site}/${wpcli_core_verify_result_file}"
            display --indent 8 --text "Suspicious file: ${wpcli_core_verify_result_file}"
            rm "${wp_site}/${wpcli_core_verify_result_file}"

        fi

    done

    log_event "info" "All unknown files in WordPress core deleted!"
    display --indent 6 --text "- Deleting suspicious WordPress files" --result "DONE" --color GREEN

}

wpcli_maintenance_mode_status() {

    WPCLI_V=$(sudo -u www-data wp --info | grep "WP-CLI version:" | cut -d ':' -f2)

    # Return
    echo "${WPCLI_V}"

}

wpcli_maintenance_mode() {

    # $1 = ${mode} (activate or deactivate)

    local mode=$1

    local maintenance_mode

    maintenance_mode=$(sudo -u www-data wp maintenance-mode "${mode}")

    # Return
    echo "${maintenance_mode}"

}

wpcli_seoyoast_reindex() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    display --indent 6 --text "- Running yoast index"

    sudo -u www-data wp --path="${wp_site}" yoast index --reindex

    clear_last_line
    display --indent 6 --text "- Running yoast index" --result "DONE" --color GREEN

}

wpcli_update_plugin(){

    # $1 = ${wp_site}
    # $2 = ${plugin} could be --all?

    local wp_site=$1
    local plugin=$2

    local plugin_update   

    if [ "${plugin}" = "" ]; then
        plugin="--all"
    fi

    mapfile plugin_update < <(sudo -u www-data wp --path="${wp_site}" plugin update "${plugin}" --format=json --quiet 2>&1)

    # Return an array with wp-cli output
    echo "${plugin_update[@]}"

}

wpcli_get_plugin_version() {

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin}

    local wp_site=$1
    local plugin=$2

    local plugin_version

    plugin_version=$(sudo -u www-data wp --path="${wp_site}" plugin get "${plugin}" --format=json | cut -d "," -f 4 | cut -d ":" -f 2)

    # Return
    echo "${plugin_version}"

}

wpcli_get_wpcore_version(){

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    local core_version

    core_version=$(sudo -u www-data wp --path="${wp_site}" core version)

    # Return
    echo "${core_version}"

}

wpcli_install_plugin() {

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to delete)

    local wp_site=$1
    local plugin=$2

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} plugin install ${plugin} --activate"
    display --indent 6 --text "- Installing and activating plugin ${plugin}"

    sudo -u www-data wp --path="${wp_site}" plugin install "${plugin}" --activate --quiet

    clear_last_line
    display --indent 6 --text "- Installing plugin ${plugin}" --result "DONE" --color GREEN

}

wpcli_delete_plugin() {

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to delete)

    local wp_site=$1
    local plugin=$2

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} plugin delete ${plugin}"
    display --indent 6 --text "- Deleting plugin ${plugin}" --result "DONE" --color GREEN
    
    sudo -u www-data wp --path="${wp_site}" plugin delete "${plugin}" --quiet

    clear_last_line
    display --indent 6 --text "- Deleting plugin ${plugin}" --result "DONE" --color GREEN

}

wpcli_is_active_plugin() {

    # Check whether plugin is active; exit status 0 if active, otherwise 1

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to delete)

    local wp_site=$1
    local plugin=$2

    sudo -u www-data wp --path="${wp_site}" plugin is-installed "${plugin}"

    # Return
    echo $?

}

wpcli_is_installed_plugin() {

    # Check whether plugin is installed; exit status 0 if installed, otherwise 1

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to delete)

    local wp_site=$1
    local plugin=$2

    sudo -u www-data wp --path="${wp_site}" plugin is-installed "${plugin}"

    # Return
    echo $?

}

wpcli_install_theme() {

    # $1 = ${wp_site} (site path)
    # $2 = ${theme} (theme to delete)

    local wp_site=$1
    local theme=$2

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} theme install ${theme} --activate" "false"
    sudo -u www-data wp --path="${wp_site}" theme install "${theme}" --activate

    display --indent 6 --text "- Installing and activating theme ${theme}" --result "DONE" --color GREEN

}

wpcli_delete_theme() {

    # $1 = ${wp_site} (site path)
    # $2 = ${theme} (theme to delete)

    local wp_site=$1
    local theme=$2

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} theme delete ${theme}" "false"
    sudo -u www-data wp --path="${wp_site}" theme delete "${theme}" --quiet

    display --indent 6 --text "- Deleting theme ${theme}" --result "DONE" --color GREEN

}

wpcli_change_wp_seo_visibility() {

    # $1 = ${wp_site} (site path)
    # $2 = ${visibility} (0=off or 1=on)

    local wp_site=$1
    local visibility=$2

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} option set blog_public ${visibility}" "false"
    sudo -u www-data wp --path="${wp_site}" option set blog_public "${visibility}" --quiet

    display --indent 6 --text "- Changing site visibility to ${visibility}" --result "DONE" --color GREEN

}

wpcli_get_db_prefix() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    DB_PREFIX=$(sudo -u www-data wp --path="${wp_site}" db prefix)

    # Return
    echo "${DB_PREFIX}"

}

wpcli_change_tables_prefix() {

    # $1 = ${wp_site} (site path)
    # $2 = ${db_prefix}

    local wp_site=$1
    local db_prefix=$2

    log_event "info" "Running: wp --allow-root --path=${wp_site} rename-db-prefix ${db_prefix}" "false"
    display --indent 6 --text "- Changing tables prefix"

    wp --allow-root --path="${wp_site}" rename-db-prefix "${db_prefix}" --no-confirm

    #clear_last_line
    display --indent 6 --text "- Changing tables prefix" --result "DONE" --color GREEN
    display --indent 8 --text "New tables prefix ${TABLES_PREFIX}"

}

wpcli_search_and_replace() {

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

        log_event "info" "Running: wp --allow-root --path=${wp_site} search-replace --url=https://"${wp_site_url}" ${search} ${replace} --network" "false"
        wp --allow-root --path="${wp_site}" search-replace --url=https://"${wp_site_url}" "${search}" "${replace}" --network --quiet

        display --indent 6 --text "- Running search and replace" --result "DONE" --color GREEN
        display --indent 8 --text "${search} was replaced by ${replace}"

    else

        log_event "info" "Running: wp --allow-root --path=${wp_site} search-replace ${search} ${replace}" "false"
        wp --allow-root --path="${wp_site}" search-replace "${search}" "${replace}" --quiet

        display --indent 6 --text "- Running search and replace" --result "DONE" --color GREEN
        display --indent 8 --text "${search} was replaced by ${replace}"

    fi

    log_event "info" "Running: wp --allow-root --path=${wp_site} cache flush" "false"
    wp --allow-root --path="${wp_site}" cache flush --quiet

    display --indent 6 --text "- Flushing cache" --result "DONE" --color GREEN

}

wpcli_export_database(){

    # $1 = ${wp_site} (site path)
    # $2 = ${dump_file}

    local wp_site=$1
    local dump_file=$2

    log_event "info" "Running: wp --allow-root --path=${wp_site} db export ${dump_file}" "false"
    wp --allow-root --path="${wp_site}" db export "${dump_file}" --quiet

    display --indent 6 --text "- Exporting database ${wp_site}" --result "DONE" --color GREEN

}

wpcli_force_reinstall_plugins() {

   # $1 = ${wp_site}
   # $2 = ${plugin}

    local wp_site=$1
    local plugin=$2

    local verify_plugin   

    if [ "${plugin}" = "" ]; then

        log_event "info" "Running: sudo -u www-data wp --path=${wp_site} plugin install $(ls -1p "${wp_site}"/wp-content/plugins | grep '/$' | sed 's/\/$//') --force"
        sudo -u www-data wp --path="${wp_site}" plugin install "$(ls -1p "${wp_site}"/wp-content/plugins | grep '/$' | sed 's/\/$//')" --force
    
    else
        log_event "info" "Running: sudo -u www-data wp --path=${wp_site} plugin install ${plugin} --force"
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

wpcli_rollback_plugin_version() {

    # TODO: implement this
    # $1= wp_site
    # $2= wp_plugin
    # $3= wp_plugin_v (version to install)

    #sudo -u www-data wp --path="${wp_site}" plugin update "${wp_plugin}" --version="${wp_plugin_v}" --dry-run
    #sudo -u www-data wp --path="${wp_site}" plugin update "${wp_plugin}" --version="${wp_plugin_v}"

    wpcli_get_plugin_version "" ""

}

wpcli_rollback_wpcore_version() {

    # TODO: implement this

    wpcli_get_wp_version

}

wpcli_user_create() {

    # $1 = ${wp_site}
    # $2 = ${user}
    # $3 = ${mail}
    # $3 = ${role}

    local wp_site=$1
    local user=$2
    local mail=$3
    local role=$4

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} user create ${user} ${mail} --role=${role}"

    sudo -u www-data wp --path="${wp_site}" user create "${user}" "${mail}" --role="${role}"

    display --indent 6 --text "- Adding WP user: ${user}" --result "DONE" --color GREEN

}

wpcli_user_reset_passw(){

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