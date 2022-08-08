#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc12
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

function docker_wordpress_install() {

    local project_path="${1}"
    local project_domain="${2}"
    local project_name="${3}"
    local project_stage="${4}"
    local project_root_domain="${5}"
    local docker_compose_template="${6}"

    local env_file

    log_subsection "WordPress Install (Docker)"

    log_event "info" "Working directory: ${PROJECT_FILES_CONFIG_PATH}/${project_domain}" "false"

    # Create directory structure
    mkdir -p "${project_path}"
    # Copy docker-compose template files
    cp "${BROLIT_MAIN_DIR}/config/docker-compose/wordpress/.env" "${project_path}"
    cp "${BROLIT_MAIN_DIR}/config/docker-compose/wordpress/docker-compose.yml" "${project_path}"
    # Replace variables on .env file
    env_file="${project_path}/.env"
    compose_file="${project_path}/docker-compose.yml"
    # Setting PROJECT_NAME
    log_event "debug" "Setting PROJECT_NAME=${project_name}" "false"
    sed -ie "s|^PROJECT_NAME=.*$|PROJECT_NAME=${project_name}|g" "${env_file}"
    # Setting CERT_EMAIL
    log_event "debug" "Setting CERT_EMAIL=${PACKAGES_CERTBOT_CONFIG_MAILA}" "false"
    sed -ie "s|^CERT_EMAIL=.*$|CERT_EMAIL=${PACKAGES_CERTBOT_CONFIG_MAILA}|g" "${env_file}"
    # Setting PROJECT_DOMAIN
    log_event "debug" "Setting PROJECT_DOMAIN=${project_domain}" "false"
    sed -ie "s|^PROJECT_DOMAIN=.*$|PROJECT_DOMAIN=${project_domain}|g" "${env_file}"
    # Setting PHPMYADMIN_DOMAIN
    log_event "debug" "Setting PHPMYADMIN_DOMAIN=db.${project_domain}" "false"
    sed -ie "s|^PHPMYADMIN_DOMAIN=.*$|PHPMYADMIN_DOMAIN=db.${project_domain}|g" "${env_file}"

    # Run docker-compose commands
    docker-compose -f "${compose_file}" pull
    docker-compose -f "${compose_file}" up -d

    # TODO:
    ## 1- Create new nginx with proxy config
    ## 2- Update cloudflare DNS entries
    ## 3- Run certbot
    ## 4- Create brolit project config.

}

################################################################################
# Docker MySQL database import
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_mysql_database_import() {

    local container_name="${1}"
    local mysql_user="${2}"
    local mysql_user_passw="${3}"
    local mysql_database="${4}"
    local dump_file="${5}"

    # TODO: 
    # 1- List container names
    # 2- Select container name to work with

    # Docker run
    # Example: docker exec -i db mysql -uroot -pexample wordpress < dump.sql
    log_event "debug" "Running: docker exec -i \"${container_name}\" mysql -u\"${mysql_user}\" -p\"${mysql_user_passw}\" ${mysql_database} < ${dump_file}" "false"
    docker exec -i "${container_name}" mysql -u"${mysql_user}" -p"${mysql_user_passw}" "${mysql_database}" <"${dump_file}"

    # Docker logs
    #docker logs wordpress

}

################################################################################
# Docker MySQL database backup
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_mysql_database_backup() {

    local container_name="${1}"
    local mysql_user="${2}"
    local mysql_user_passw="${3}"
    local mysql_database="${4}"
    local dump_file="${5}"

    # Docker run
    # Example: docker exec -i db mysqldump -uroot -pexample wordpress > dump.sql
    log_event "debug" "Running: docker exec -i \"${container_name}\" mysql -u\"${mysql_user}\" -p\"${mysql_user_passw}\" ${mysql_database} > ${dump_file}" "false"
    docker exec -i "${container_name}" mysqldump -u"${mysql_user}" -p"${mysql_user_passw}" "${mysql_database}" >"${dump_file}"

    # Docker logs
    #docker logs wordpress

}
