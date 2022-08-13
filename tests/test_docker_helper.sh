#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.0
#############################################################################

################################################################################
# Docker WordPress install.
#
# Arguments:
#   $1 = ${project_path}
#   $2 = ${project_domain}
#   $3 = ${project_name}
#   $4 = ${project_stage}
#   $5 = ${project_root_domain}         # Optional
#   $6 = ${docker_compose_template}     # Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_docker_helper_functions() {

    # TODO: create a function that change WP_PORT (always assign a new port that is not in use)

    # Docker Wordpress Install
    docker_wordpress_install "/var/www/dockertest.broobe.net" "dockertest.broobe.net" "dockertest" "prod" "broobe.net" ""

    # Docker MySQL database import
    docker_mysql_database_import "mariadb_dockertest" "db_user" "db_user_pass" "db_name" "assets/dump.sql"

    # Docker MySQL database backup
    docker_mysql_database_backup "mariadb_dockertest" "db_user" "db_user_pass" "db_name" "assets/dump.sql"

    # Docker list images
    docker_list_images

    # Docker project files import
    # TODO: should only import wp-content? how about wp-config.php?
    docker_project_files_import "/root/backup.tar.bz2" "/var/www/dockertest.broobe.net" "wordpress"

    # Create nginx proxy
    ## TODO: read port from docker-compose .env file
    nginx_server_create "dockertest.broobe.net" "proxy" "single" "" "88"

    # TODO: run wp-cli commands?

    # TODO: generate certbot certificates and install it.

}
