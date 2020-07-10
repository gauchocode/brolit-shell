#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc06
################################################################################

wpcli_install_if_not_installed() {

    # Check if wp-cli is installed
    WPCLI="$(which wp)"
    if [ ! -x "${WPCLI}" ]; then
        wpcli_install
    fi

}

wpcli_install() {

    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

    chmod +x wp-cli.phar
    sudo mv wp-cli.phar "/usr/local/bin/wp"

}

wpcli_update() {
    wp cli update

}

wpcli_uninstall() {
    rm "/usr/local/bin/wp"

}

wpcli_install_needed_extensions() {

    # Rename DB Prefix
    wp --allow-root package install "iandunn/wp-cli-rename-db-prefix"
    # Image Optimization
    wp --allow-root package install "typisttech/image-optimize-command:@stable"
    # Salts
    wp --allow-root package install "sebastiaandegeus/wp-cli-salts-comman"
    # Vulnerability Scanner
    wp --allow-root package install "git@github.com:10up/wp-vulnerability-scanner.git"
    # Doctor
    wp --allow-root package install "wp-cli/doctor-command"

}

wpcli_check_if_installed() {

    WPCLI_INSTALLED="true"

    WPCLI_V=$(wpcli_check_version)

    if [[ -z "${WPCLI_V}" ]]; then
        WPCLI_INSTALLED="false"

    fi

    echo ${WPCLI_INSTALLED}

}

wpcli_check_version() {

    WPCLI_V=$(sudo -u www-data wp --info | grep "WP-CLI version:" | cut -d ':' -f2)

    echo "${WPCLI_V}"

}

wpcli_core_update() {

    local verify_core_update

    verify_core_update=$(sudo -u www-data wp core check-update | grep ":" | cut -d ':' -f1)

    echo "${verify_core_update}" #if ok, return "Success"

}

wpcli_core_verify() {

    local verify_core

    verify_core=$(sudo -u www-data wp core verify-checksums | grep ":" | cut -d ':' -f1)

    echo "${verify_core}" #if ok, return "Success"

}

wpcli_plugin_verify() {

    # $1 = ${plugin} could be --all?

    local verify_plugin plugin

    plugin=$1

    verify_plugin=$(sudo -u www-data wp plugin verify-checksums "${plugin}" | grep ":" | cut -d ':' -f1)

    echo "${verify_plugin}" #if ok, return "Success"

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

wpcli_verify_wp_core_installation() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    sudo -u www-data wp --path="${wp_site}" core verify-checksums --allow-root

}

wpcli_verify_wp_plugins_installation() {

    # $1 = ${wp_site} (site path)

    local wp_site=$1

    sudo -u www-data wp --path="${wp_site}" plugin verify-checksums --all --allow-root

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

    sudo -u www-data wp --path="${wp_site}" theme install "${theme}" --activate

}

wpcli_delete_theme() {

    # $1 = ${wp_site} (site path)
    # $2 = ${theme} (theme to delete)

    local wp_site=$1
    local theme=$2

    sudo -u www-data wp --path="${wp_site}" theme delete "${theme}"

}

wpcli_change_wp_seo_visibility() {

    # $1 = ${wp_site} (site path)
    # $2 = ${visibility} (0=off or 1=on)

    local wp_site=$1
    local visibility=$2

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

        echo "Running: wp --allow-root --path=${wp_site} search-replace ${search} ${replace} --network"
        wp --allow-root --path="${wp_site}" search-replace "${search}" "${replace}" --network

    else

        echo "Running: wp --allow-root --path=${wp_site} search-replace ${search} ${replace}"
        wp --allow-root --path="${wp_site}" search-replace "${search}" "${replace}"

    fi

}

wpcli_export_db(){

    # $1 = ${wp_site} (site path)
    # $2 = ${db}

    local wp_site=$1
    local db=$2

    wp --allow-root --path="${wp_site}" db export "${db}"

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

# The idea is that when you update wordpress or a plugin, get the actual version,
# then run a dry-run update, if success, update but show a message if you want to
# persist the update or want to do a rollback

wpcli_rollback_plugin_version(){

    # TODO: implement this
    # $1= wp_site
    # $2= wp_plugin
    # $3= wp_plugin_v (version to install)

    #sudo -u www-data wp --path="${wp_site}" plugin update "${wp_plugin}" --version="${wp_plugin_v}" --dry-run
    #sudo -u www-data wp --path="${wp_site}" plugin update "${wp_plugin}" --version="${wp_plugin_v}"

    wpcli_get_plugin_version "" ""

}

wpcli_rollback_wpcore_version(){

    # TODO: implement this

    wpcli_get_wp_version

}