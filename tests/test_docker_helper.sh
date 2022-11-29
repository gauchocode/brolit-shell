#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.3.0-beta
#############################################################################

################################################################################
# Docker WordPress install.
#
# Arguments:
#   ${1} = ${project_path}
#   ${2} = ${project_domain}
#   ${3} = ${project_name}
#   ${4} = ${project_stage}
#   ${5} = ${project_root_domain}         # Optional
#   ${6} = ${docker_compose_template}     # Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function test_docker_helper_functions() {

    # TODO: create a function that change WP_PORT (always assign a new port that is not in use)

    local project_port

    project_port=88

    network_port_is_use "${project_port}"
    [[ $? -eq 0 ]] && return 1

    # Ask project stage
    project_stage="$(project_ask_stage "prod")"
    [[ $? -eq 1 ]] && return 1

    # Project domain
    project_domain="$(project_ask_domain "")"
    [[ $? -eq 1 ]] && return 1

    root_domain="$(domain_get_root "${project_domain}")"

    project_name="$(project_get_name_from_domain "${project_domain}")"

    # Docker Wordpress Install
    docker_wordpress_install "/var/www/${project_domain}" "${project_domain}" "${project_name}" "${project_stage}" "${root_domain}" "${project_port}" "default"

    # TODO: read .env to get mysql pass

    # Docker MySQL database import
    docker_mysql_database_import "mariadb_${project_name}" "${project_name}_user" "db_user_pass" "${project_name}_prod" "assets/dump.sql"

    # Docker MySQL database backup
    docker_mysql_database_export "mariadb_${project_name}" "${project_name}_user" "db_user_pass" "${project_name}_prod" "assets/dump.sql"

    # Docker list images
    #docker_list_images

    # Docker project files import
    # TODO: should only import wp-content? how about wp-config.php?
    # docker_project_files_import "/root/backup.tar.bz2" "/var/www/${project_domain}" "wordpress"

    # Create nginx proxy if nginx is installed
    ## TODO: read port from docker-compose .env file
    nginx_server_create "dockertest.broobe.net" "proxy" "single" "" "${project_port}"

    # TODO: run wp-cli commands?

    # TODO: generate certbot certificates and install it.

}
