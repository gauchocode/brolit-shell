#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc12
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

    # Docker Wordpress Install
    docker_wordpress_install "/var/www/dockertest.broobe.net" "dockertest.broobe.net" "dockertest" "prod" "broobe.net" ""

    # Docker MySQL database import
    docker_mysql_database_import "mariadb_dockertest" "db_user" "db_user_pass" "db_name" "assets/dump.sql"

    # Docker MySQL database backup
    docker_mysql_database_backup "mariadb_dockertest" "db_user" "db_user_pass" "db_name" "assets/dump.sql"

    # Docker list images
    docker_list_images

}
