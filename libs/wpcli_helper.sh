#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc03
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

wpcli_verify_wp_core_installation() {

    # $1 = ${WP_SITE} (site path)

    WP_SITE=$1

    sudo -u www-data wp --path="${WP_SITE}" core verify-checksums --allow-root

}

wpcli_verify_wp_plugins_installation() {

    # $1 = ${WP_SITE} (site path)

    WP_SITE=$1

    sudo -u www-data wp --path="${WP_SITE}" plugin verify-checksums --all --allow-root

}

wpcli_install_plugin() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${PLUGIN} (plugin to delete)

    WP_SITE=$1
    PLUGIN=$2

    sudo -u www-data wp --path="${WP_SITE}" plugin install "${PLUGIN}" --activate

}

wpcli_delete_plugin() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${PLUGIN} (plugin to delete)

    WP_SITE=$1
    PLUGIN=$2

    sudo -u www-data wp --path="${WP_SITE}" plugin delete "${PLUGIN}"

}

wpcli_install_theme() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${THEME} (theme to delete)

    WP_SITE=$1
    THEME=$2

    sudo -u www-data wp --path="${WP_SITE}" theme install "${THEME}" --activate

}

wpcli_delete_theme() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${THEME} (theme to delete)

    WP_SITE=$1
    THEME=$2

    sudo -u www-data wp --path="${WP_SITE}" theme delete "${THEME}"

}

wpcli_change_wp_seo_visibility() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${VISIBILITY} (0=off or 1=on)

    WP_SITE=$1
    VISIBILITY=$2

    sudo -u www-data wp --path="${WP_SITE}" option set blog_public "${VISIBILITY}"

}

wpcli_get_db_prefix() {

    # $1 = ${WP_SITE} (site path)

    WP_SITE=$1

    DB_PREFIX=$(sudo -u www-data wp --path=${WP_SITE} db prefix)

    echo "${DB_PREFIX}"

}

wpcli_change_tables_prefix() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${DB_PREFIX}

    WP_SITE=$1
    DB_PREFIX=$2

    wp --allow-root --path="${WP_SITE}" rename-db-prefix "${DB_PREFIX}"

}

wpcli_search_and_replace() {

    # $1 = ${WP_SITE} (site path)
    # $2 = ${SEARCH}
    # $3 = ${REPLACE}

    WP_SITE=$1
    SEARCH=$2
    REPLACE=$3

    # Folder Name need to be the Site URL
    WP_SITE_URL=$(basename "${WP_SITE}")

    # TODO: por algún motivo cuando tiro comandos con el parametro --url siempre falla
    # entonces o ver que pasa o checkear si es multisite de otra manera.
    if $(wp --allow-root --url=http://${WP_SITE_URL} core is-installed --network); then

        echo "Running: wp --allow-root --path=${WP_SITE} search-replace ${SEARCH} ${REPLACE} --network"
        wp --allow-root --path="${WP_SITE}" search-replace "${SEARCH}" "${REPLACE}" --network

    else

        echo "Running: wp --allow-root --path=${WP_SITE} search-replace ${SEARCH} ${REPLACE}"
        wp --allow-root --path="${WP_SITE}" search-replace "${SEARCH}" "${REPLACE}"

    fi

}

wpcli_export_db(){

    # $1 = ${WP_SITE} (site path)
    # $2 = ${DB}

    WP_SITE=$1
    DB=$2

    wp --allow-root --path="${WP_SITE}" db export "${DB}"
}