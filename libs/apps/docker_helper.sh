#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.72
################################################################################
#
# Docker Helper: Perform docker actions.
#
################################################################################

function docker_version() {

    echo "Docker version: $(docker --version)"

}

function docker_list_containers() {

    echo "Docker containers: $(docker ps -a)"

}

function docker_list_images() {

    echo "Docker images: $(docker images)"

}

function docker_system_prune() {

    echo "Docker system prune: $(docker system prune)"

}

function docker_wordpress_install() {

    local docker_image="wordpress:latest"
    local docker_port="8088"
    #local php_version="7.4"

    local wordpress_database_host="localhost"
    local wordpress_database_name="wordpress"
    local wordpress_database_user="wordpress"
    local wordpress_database_password="wordpress"
    local wordpress_database_prefix="wp_"

    local wordpress_user="wordpress"
    local wordpress_user_password="wordpress"
    local wordpress_user_email="wordpress@localhost"

    # Docker run
    docker run --name wordpress -d -p "$docker_port":80 -e WORDPRESS_DB_HOST="$wordpress_database_host" -e WORDPRESS_DB_NAME="$wordpress_database_name" -e WORDPRESS_DB_USER="$wordpress_database_user" -e WORDPRESS_DB_PASSWORD="$wordpress_database_password" -e WORDPRESS_DB_PREFIX="$wordpress_database_prefix" -e WORDPRESS_USER="$wordpress_user" -e WORDPRESS_USER_PASSWORD="$wordpress_user_password" -e WORDPRESS_USER_EMAIL="$wordpress_user_email" "$docker_image"

    # Docker logs
    #docker logs wordpress

}
