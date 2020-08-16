#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
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

    echo "${wpcli_installed}"

}

wpcli_check_version() {

    local wpcli_v

    wpcli_v=$(sudo -u www-data wp --info | grep "WP-CLI version:" | cut -d ':' -f2)

    echo "${wpcli_v}"

}

wpcli_install() {

    log_event "info" "Installing wp-cli ..." "true"

    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

    chmod +x wp-cli.phar
    sudo mv wp-cli.phar "/usr/local/bin/wp"

    log_event "success" "wp-cli installed" "true"

}

wpcli_update() {

    log_event "info" "Running: wp-cli update" "true"

    wp cli update

}

wpcli_uninstall() {

    log_event "warning" "Uninstalling wp-cli ..." "true"

    rm "/usr/local/bin/wp"

    log_event "warning" "wp-cli uninstalled" "true"

}

wpcli_run_startup_script(){

    # $1 = ${site_name}
    # $2 = ${site_url}
    # $3 = ${wp_user_name}
    # $4 = ${wp_user_passw}
    # $5 = ${wp_user_mail}

    local site_name=$1
    local site_url=$2
    local wp_user_name=$3
    local wp_user_passw=$4
    local wp_user_mail=$5

    wp core install --url="${site_url}" --title="${site_name}" --admin_user="${wp_user_name}" --admin_password="${wp_user_passw}" --admin_email="${wp_user_mail}" --allow-root

    # Delete default post, page, and comment
    wp site empty --yes --allow-root

    # Delete default themes
    wp theme delete twentyseventeen --allow-root
    wp theme delete twentynineteen --allow-root

    wp site empty --yes --allow-root
    
    # Delete default plugins
    wp plugin delete akismet --allow-root
    wp plugin delete hello --allow-root
    
    wp rewrite structure '/%postname%/' --allow-root
    wp option update default_comment_status closed --allow-root
    #wp post create --post_type=page --post_status=publish --post_title='Home' --allow-root

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

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} config create --dbname=${database} --dbuser=${db_user_name} --dbpass=${db_user_passw} --locale=${wp_locale}" "true"

    sudo -u www-data wp --path="${wp_site}" config create --dbname="${database}" --dbuser="${db_user_name}" --dbpass="${db_user_passw}" --locale="${wp_locale}"

}

wpcli_install_needed_extensions() {

    # Rename DB Prefix
    wp --allow-root package install "iandunn/wp-cli-rename-db-prefix"
    
    # Salts
    wp --allow-root package install "sebastiaandegeus/wp-cli-salts-comman"
    
    # Vulnerability Scanner
    wp --allow-root package install "git@github.com:10up/wp-vulnerability-scanner.git"

}

wpcli_core_install() {

    # $1 = ${wp_site}
    # $2 = ${wp_version} optional

    local wp_site=$1
    local wp_version=$2

    local wpcli_result

    if [ "${wp_site}" != "" ]; then

        if [ "${wp_version}" != "" ];then

            log_event "info" "Running: sudo -u www-data wp --path=${wp_site} core download --skip-content --version=${wp_version}" "true"

            sudo -u www-data wp --path="${wp_site}" core download --skip-content --version="${wp_version}"

        else

            log_event "info" "Running: sudo -u www-data wp --path=${wp_site} core download --skip-content" "true"

            sudo -u www-data wp --path="${wp_site}" core download --skip-content

        fi

    else
        # Log failure
        log_event "fail" "wp_site can't be empty!" "true"

        # Return
        echo "fail"

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

        log_event "info" "Running: sudo -u www-data wp --path=${wp_site} core download --skip-content --force" "true"

        wpcli_result=$(sudo -u www-data wp --path="${wp_site}" core download --skip-content --force 2>&1 | grep "Success" | cut -d ":" -f1)

        if [ "${wpcli_result}" = "Success" ]; then

            # Log Success
            log_event "success" "Wordpress re-installed" "true"

            # Return
            echo "success"

        else

            # Log failure
            log_event "fail" "Something went wrong installing WordPress" "true"

            # Return
            echo "fail"

        fi
        
    else
        # Log failure
        log_event "fail" "wp_site can't be empty!" "true"

        # Return
        echo "fail"

    fi

}

wpcli_core_update() {

    # $1 = ${wp_site}

    local wp_site=$1
    local verify_core_update

    verify_core_update=$(sudo -u www-data wp --path="${wp_site}" update | grep ":" | cut -d ':' -f1)

    if [ "${verify_core_update}" = "Success" ];then

        # Translations update
        sudo -u www-data wp --path="${wp_site}" language core update

        # Update database
        sudo -u www-data wp --path="${wp_site}" core update-db

        # Cache Flush
        sudo -u www-data wp --path="${wp_site}" cache flush

        # Rewrite Flush
        sudo -u www-data wp --path="${wp_site}" rewrite flush

        log_event "success" "Wordpress core updated" "true"

    else

        log_event "error" "Wordpress core failed" "true"
    
    fi

    echo "${verify_core_update}" #if ok, return "Success"

}

wpcli_core_verify() {

    # $1 = ${wp_site}

    local wp_site=$1
    local verify_core

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} core verify-checksums" "true"
    mapfile verify_core < <(sudo -u www-data wp --path="${wp_site}" core verify-checksums 2>&1)

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

    log_event "info" "Running: sudo -u www-data wp --path="${wp_site}" plugin verify-checksums ${plugin}" "true"
    mapfile verify_plugin < <(sudo -u www-data wp --path="${wp_site}" plugin verify-checksums "${plugin}" 2>&1)

    # Return an array with wp-cli output
    echo "${verify_plugin[@]}"

}

wpcli_delete_not_core_files() {

    # $1 = ${wp_site}

    local wp_site=$1

    mapfile -t wpcli_core_verify_results < <( wpcli_core_verify "${wp_site}" )

    for wpcli_core_verify_result in "${wpcli_core_verify_results[@]}"
    do
        # Check results
        wpcli_core_verify_result_file=$(echo "${wpcli_core_verify_result}" |  grep "should not exist" | cut -d ":" -f3)
        
        # Remove white space
        wpcli_core_verify_result_file=${wpcli_core_verify_result_file//[[:blank:]]/}
        
        if test -f "${wp_site}/${wpcli_core_verify_result_file}"; then

            log_event "info" "Deleting not core file: ${wp_site}/${wpcli_core_verify_result_file}" "true"
            rm "${wp_site}/${wpcli_core_verify_result_file}"

        fi

    done

    log_event "info" "All unknown files in WordPress core deleted!" "true"

}

wpcli_maintenance_mode_status() {

    WPCLI_V=$(sudo -u www-data wp --info | grep "WP-CLI version:" | cut -d ':' -f2)

    echo "${WPCLI_V}"

}

wpcli_maintenance_mode() {

    # $1 = ${mode} (activate or deactivate)

    local mode=$1

    local maintenance_mode

    maintenance_mode=$(sudo -u www-data wp maintenance-mode "${mode}")

    echo "${maintenance_mode}"

}

wpcli_seoyoast_reindex() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    sudo -u www-data wp --path="${wp_site}" yoast index --reindex

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

    echo "${plugin_version}"

}

wpcli_get_wpcore_version(){

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    local core_version

    core_version=$(sudo -u www-data wp --path="${wp_site}" core version)

    echo "${core_version}"

}

wpcli_install_plugin() {

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to delete)

    local wp_site=$1
    local plugin=$2

    sudo -u www-data wp --path="${wp_site}" plugin install "${plugin}" --activate

}

wpcli_delete_plugin() {

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to delete)

    local wp_site=$1
    local plugin=$2

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} plugin delete ${plugin}" "true"
    sudo -u www-data wp --path="${wp_site}" plugin delete "${plugin}"

}

wpcli_is_active_plugin() {

    # Check whether plugin is active; exit status 0 if active, otherwise 1

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to delete)

    local wp_site=$1
    local plugin=$2

    sudo -u www-data wp --path="${wp_site}" plugin is-installed "${plugin}"
    echo $?

}

wpcli_is_installed_plugin() {

    # Check whether plugin is installed; exit status 0 if installed, otherwise 1

    # $1 = ${wp_site} (site path)
    # $2 = ${plugin} (plugin to delete)

    local wp_site=$1
    local plugin=$2

    sudo -u www-data wp --path="${wp_site}" plugin is-installed "${plugin}"
    echo $?

}

wpcli_install_theme() {

    # $1 = ${wp_site} (site path)
    # $2 = ${theme} (theme to delete)

    local wp_site=$1
    local theme=$2

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} theme install ${theme} --activate" "true"
    sudo -u www-data wp --path="${wp_site}" theme install "${theme}" --activate

}

wpcli_delete_theme() {

    # $1 = ${wp_site} (site path)
    # $2 = ${theme} (theme to delete)

    local wp_site=$1
    local theme=$2

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} theme delete ${theme}" "true"
    sudo -u www-data wp --path="${wp_site}" theme delete "${theme}"

}

wpcli_change_wp_seo_visibility() {

    # $1 = ${wp_site} (site path)
    # $2 = ${visibility} (0=off or 1=on)

    local wp_site=$1
    local visibility=$2

    log_event "info" "Running: sudo -u www-data wp --path=${wp_site} option set blog_public ${visibility}" "true"
    sudo -u www-data wp --path="${wp_site}" option set blog_public "${visibility}"

}

wpcli_get_db_prefix() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    DB_PREFIX=$(sudo -u www-data wp --path="${wp_site}" db prefix)

    echo "${DB_PREFIX}"

}

wpcli_change_tables_prefix() {

    # $1 = ${wp_site} (site path)
    # $2 = ${db_prefix}

    local wp_site=$1
    local db_prefix=$2

    log_event "info" "Running: wp --allow-root --path=${wp_site} rename-db-prefix ${db_prefix}" "true"
    wp --allow-root --path="${wp_site}" rename-db-prefix "${db_prefix}"

}

wpcli_search_and_replace() {

    # $1 = ${wp_site} (site path)
    # $2 = ${search}
    # $3 = ${replace}

    local wp_site=$1
    local search=$2
    local replace=$3

    local wp_site_url

    # Folder Name need to be the Site URL
    wp_site_url=$(basename "${wp_site}")

    # TODO: for some reason when it's run with --url always fails
    if $(wp --allow-root --url=http://${wp_site_url} core is-installed --network); then

        log_event "info" "Running: wp --allow-root --path=${wp_site} search-replace ${search} ${replace} --network" "true"
        wp --allow-root --path="${wp_site}" search-replace "${search}" "${replace}" --network

    else

        log_event "info" "Running: wp --allow-root --path=${wp_site} search-replace ${search} ${replace}" "true"
        wp --allow-root --path="${wp_site}" search-replace "${search}" "${replace}"

    fi

    log_event "info" "Running: wp --allow-root --path="${wp_site}" cache flush" "true"
    wp --allow-root --path="${wp_site}" cache flush

}

wpcli_export_database(){

    # $1 = ${wp_site} (site path)
    # $2 = ${dump_file}

    local wp_site=$1
    local dump_file=$2

    log_event "info" "Running: wp --allow-root --path=${wp_site} db export ${dump_file}" "true"
    wp --allow-root --path="${wp_site}" db export "${dump_file}"

}

wpcli_reset_user_passw(){

    # $1 = ${wp_site} (site path)
    # $2 = ${wp_user}
    # $3 = ${wp_user_pass}

    local wp_site=$1
    local wp_user=$2
    local wp_user_pass=$3

    wp --allow-root --path="${wp_site}" user update "${wp_user}" --user_pass="${wp_user_pass}"
    
}

wpcli_force_reinstall_plugins() {

   # $1 = ${wp_site}
   # $2 = ${plugin}

    local wp_site=$1
    local plugin=$2

    local verify_plugin   

    if [ "${plugin}" = "" ]; then
        echo -e ${B_GREEN}" > Running: sudo -u www-data wp --path="${wp_site}" plugin install $(ls -1p ${wp_site}/wp-content/plugins | grep '/$' | sed 's/\/$//') --force"${ENDCOLOR} >&2
        sudo -u www-data wp --path="${wp_site}" plugin install $(ls -1p ${wp_site}/wp-content/plugins | grep '/$' | sed 's/\/$//') --force
    
    else
        echo -e ${B_GREEN}" > Running: sudo -u www-data wp --path="${wp_site}" plugin install "${plugin}" --force"${ENDCOLOR} >&2
        sudo -u www-data wp --path="${wp_site}" plugin install "${plugin}" --force
    
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