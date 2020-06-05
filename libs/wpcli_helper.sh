#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc04
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

wpcli_verify_wp_core_installation() {

    # $1 = ${WP_SITE} (site path)

    local wp_site=$1

    sudo -u www-data wp --path="${wp_site}" core verify-checksums --allow-root

}

wpcli_verify_wp_plugins_installation() {

    # $1 = ${WP_SITE} (site path)

    local wp_site=$1

    sudo -u www-data wp --path="${wp_site}" plugin verify-checksums --all --allow-root

}

wpcli_install_plugin() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${PLUGIN} (plugin to delete)

    local wp_site=$1
    local plugin=$2

    sudo -u www-data wp --path="${wp_site}" plugin install "${plugin}" --activate

}

wpcli_delete_plugin() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${PLUGIN} (plugin to delete)

    local wp_site=$1
    local plugin=$2

    sudo -u www-data wp --path="${wp_site}" plugin delete "${plugin}"

}

wpcli_install_theme() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${THEME} (theme to delete)

    local wp_site=$1
    local theme=$2

    sudo -u www-data wp --path="${wp_site}" theme install "${theme}" --activate

}

wpcli_delete_theme() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${THEME} (theme to delete)

    local wp_site=$1
    local theme=$2

    sudo -u www-data wp --path="${wp_site}" theme delete "${theme}"

}

wpcli_change_wp_seo_visibility() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${VISIBILITY} (0=off or 1=on)

    local wp_site=$1
    local visibility=$2

    sudo -u www-data wp --path="${wp_site}" option set blog_public "${visibility}"

}

wpcli_get_db_prefix() {

    # $1 = ${WP_SITE} (site path)

    local wp_site=$1

    DB_PREFIX=$(sudo -u www-data wp --path="${wp_site}" db prefix)

    echo "${DB_PREFIX}"

}

wpcli_change_tables_prefix() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${DB_PREFIX}

    local wp_site=$1
    local db_prefix=$2

    wp --allow-root --path="${wp_site}" rename-db-prefix "${db_prefix}"

}

wpcli_search_and_replace() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${SEARCH}
    # $3 = ${REPLACE}

    local wp_site=$1
    local search=$2
    local replace=$3

    local wp_site_url

    # Folder Name need to be the Site URL
    wp_site_url=$(basename "${wp_site}")

    # TODO: por algún motivo cuando tiro comandos con el parametro --url siempre falla
    # entonces o ver que pasa o checkear si es multisite de otra manera.
    if $(wp --allow-root --url=http://${wp_site_url} core is-installed --network); then

        echo "Running: wp --allow-root --path=${wp_site} search-replace ${search} ${replace} --network"
        wp --allow-root --path="${wp_site}" search-replace "${search}" "${replace}" --network

    else

        echo "Running: wp --allow-root --path=${wp_site} search-replace ${search} ${replace}"
        wp --allow-root --path="${wp_site}" search-replace "${search}" "${replace}"

    fi

}

wpcli_export_db(){

    # $1 = ${WP_SITE} (site path)
    # $2 = ${DB}

    local wp_site=$1
    local db=$2

    wp --allow-root --path="${wp_site}" db export "${db}"
}