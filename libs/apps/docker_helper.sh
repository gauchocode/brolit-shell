#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc5
################################################################################
#
# Docker Helper: Perform docker actions.
#
################################################################################

################################################################################
# Get docker version.
#
# Arguments:
#   none
#
# Outputs:
#   ${docker_version} if ok, 1 on error.
################################################################################

function docker_version() {

    local docker_version
    local docker

    docker="$(package_is_installed "docker")"
    if [[ -n ${docker} ]]; then

        docker_version="$(docker version --format '{{.Server.Version}}')"

        echo "${docker_version}"

        return 0
    else

        return 1

    fi

}

################################################################################
# Get docker-compose version.
#
# Arguments:
#   none
#
# Outputs:
#   ${docker_compose_version} if ok, 1 on error.
################################################################################

function docker_compose_version() {

    local docker_compose_version
    local docker_compose

    docker_compose="$(package_is_installed "docker-compose")"
    if [[ -n ${docker_compose} ]]; then

        docker_compose_version="$(docker-compose --version | awk '{print $3}' | cut -d ',' -f1)"

        echo "${docker_compose_version}"

        return 0
    else

        return 1

    fi

}

################################################################################
# List docker containers.
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_list_containers() {

    local docker_containers

    # List docker containers.
    docker_containers="$(docker ps -a --format '{{.Names}}')"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        echo "${docker_containers}"

        return 0

    else

        return 1

    fi

}

################################################################################
# Stop docker container.
#
# Arguments:
#   $1 = ${container_to_stop}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_stop_container() {

    local container_to_stop="${1}"

    local docker_stop_container

    # Stop docker container.
    docker_stop_container="$(docker stop "${container_to_stop}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        echo "${docker_stop_container}"

        return 0

    else

        return 1

    fi

}

################################################################################
# List docker images.
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_list_images() {

    local docker_images

    # Docker list images
    docker_images="$(docker images --format '{{.Repository}}:{{.Tag}}')"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        echo "${docker_images}"

        return 0

    else

        return 1

    fi

}

################################################################################
# Get container id
#
# Arguments:
#   $1 = ${image_name}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_get_container_id() {

    local image_name="${1}"

    local container_id

    container_id="$(docker ps | grep "${image_name}" | awk '{print $1;}')"

    if [[ -n ${container_id} ]]; then

        echo "${container_id}"

        return 0

    else

        return 1

    fi

}

################################################################################
# Docker delete image.
#
# Arguments:
#   $1 = ${image_to_delete}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_delete_image() {

    local image_to_delete="${1}"

    local docker_delete_image

    # Docker delete image
    docker_delete_image="$(docker rmi "${image_to_delete}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        echo "${docker_delete_image}"

        return 0

    else

        return 1

    fi

}

################################################################################
# Docker system prune.
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_system_prune() {

    echo "Docker system prune: $(docker system prune)"

}

################################################################################
# Docker WordPress install.
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# TODO: maybe it should be better use docker-compose

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
    docker run --name wordpress -d -p "${docker_port}":80 -e WORDPRESS_DB_HOST="${wordpress_database_host}" -e WORDPRESS_DB_NAME="${wordpress_database_name}" -e WORDPRESS_DB_USER="${wordpress_database_user}" -e WORDPRESS_DB_PASSWORD="${wordpress_database_password}" -e WORDPRESS_DB_PREFIX="${wordpress_database_prefix}" -e WORDPRESS_USER="${wordpress_user}" -e WORDPRESS_USER_PASSWORD="${wordpress_user_password}" -e WORDPRESS_USER_EMAIL="${wordpress_user_email}" "${docker_image}"

    # Docker logs
    #docker logs wordpress

}
