#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.5
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

    docker="$(package_is_installed "docker-ce")"
    if [[ -n ${docker} ]]; then

        docker_version="$(docker version --format '{{.Server.Version}}')"

        echo "${docker_version}" && return 0

    else

        return 1

    fi

}

################################################################################
# Execute a docker compose pull
#
# Arguments:
#   ${1} - ${compose_file}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_compose_pull() {

    local compose_file="${1}"

    # Log
    display --indent 6 --text "- Pulling docker stack images"
    log_event "debug" "Running: docker compose -f ${compose_file} pull" "false"

    # Execute docker compose command
    ## Options:
    ##    -f, --force   Don't ask to confirm removal
    ##    -s, --stop    Stop the containers, if required, before removing
    ##    -v            Remove any anonymous volumes attached to containers
    docker compose -f "${compose_file}" pull >/dev/null 2>&1
    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Pulling docker stack images" --result "DONE" --color GREEN
        log_event "info" "Docker stack pulled ok" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Pulling docker stack images" --result "FAIL" --color RED
        log_event "error" "Docker stack pull failed" "false"

        return 1

    fi

}

################################################################################
# Execute a docker compose up
#
# Arguments:
#   ${1} - ${compose_file}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_compose_up() {

    local compose_file="${1}"

    local exitstatus

    # Log
    display --indent 6 --text "- Starting docker stack ..."
    log_event "debug" "Running: docker compose -f ${compose_file} up --detach" "false"

    # Execute docker compose command
    docker compose -f "${compose_file}" up --detach >/dev/null 2>&1
    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Starting docker stack ..." --result "DONE" --color GREEN
        log_event "info" "Docker stack started" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Starting docker stack ..." --result "FAIL" --color RED
        log_event "error" "Docker stack start failed" "false"

        return 1

    fi

}

################################################################################
# Execute a docker compose build
#
# Arguments:
#   ${1} - ${compose_file}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_compose_build() {

    local compose_file="${1}"

    local exitstatus

    # Log
    display --indent 6 --text "- Pulling docker stack ..."
    log_event "debug" "Running: docker compose -f ${compose_file} pull" "false"

    # Execute docker compose command
    docker compose -f "${compose_file}" pull >/dev/null 2>&1
    [[ $? -eq 1 ]] && display --indent 6 --text "- Pulling docker stack ..." --result "FAIL" --color RED && return 1

    # Log
    clear_previous_lines "2"
    spinner_start "- Building docker stack ..."
    log_event "debug" "Running: docker compose -f ${compose_file} up --detach --build" "false"

    # Execute docker compose command
    docker compose -f "${compose_file}" up --detach --build >/dev/null 2>&1
    
    exitstatus=$?
    spinner_stop "${exitstatus}"

    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Building docker stack" --result "DONE" --color GREEN
        log_event "info" "Docker stack restored" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Building docker stack" --result "FAIL" --color RED
        log_event "error" "Docker stack restore failed" "false"

        return 1

    fi

}

################################################################################
# Execute a docker compose stop
#
# Arguments:
#   ${1} - ${compose_file}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_compose_stop() {

    local compose_file="${1}"
    
    # Log
    display --indent 6 --text "- Stopping docker stack ..."
    log_event "debug" "Running: docker compose -f ${compose_file} stop" "false" 

    # Execute docker compose command
    docker compose -f "${compose_file}" stop >/dev/null 2>&1
    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Stopping docker stack" --result "DONE" --color GREEN
        log_event "info" "Docker stack stopped" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Stopping docker stack" --result "FAIL" --color RED
        log_event "error" "Docker stack stop failed" "false"

        return 1

    fi

}

################################################################################
# Execute a docker compose rm
#
# Arguments:
#   ${1} - ${compose_file}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_compose_rm() {

    local compose_file="${1}"

    # Log
    display --indent 6 --text "- Deleting docker stack ..."
    log_event "debug" "Running: docker compose -f ${compose_file} rm --force --volumes" "false"

    # Execute docker compose command
    ## Options:
    ##    -f, --force   Don't ask to confirm removal
    ##    -s, --stop    Stop the containers, if required, before removing
    ##    -v            Remove any anonymous volumes attached to containers
    docker compose -f "${compose_file}" rm --stop --force --volumes >/dev/null 2>&1
    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        # Log success
        clear_previous_lines "1"
        display --indent 6 --text "- Deleting docker stack ..." --result "DONE" --color GREEN
        log_event "info" "Docker stack deleted" "false"

        return 0

    else

        # Log failure
        clear_previous_lines "1"
        display --indent 6 --text "- Deleting docker stack ..." --result "FAIL" --color RED
        log_event "error" "Docker stack delete failed" "false"

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

        echo "${docker_containers}" && return 0

    else

        return 1

    fi

}

################################################################################
# Stop docker container.
#
# Arguments:
#   ${1} = ${container_to_stop}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_stop_container() {

    local container_to_stop="${1}"

    local docker_stop_container

    # Stop docker container
    docker_stop_container="$(docker stop "${container_to_stop}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        echo "${docker_stop_container}" && return 0

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

        echo "${docker_images}" && return 0

    else

        return 1

    fi

}

################################################################################
# Get container id
#
# Arguments:
#   ${1} = ${image_name}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_get_container_id() {

    local image_name="${1}"

    local container_id

    container_id="$(docker ps | grep "${image_name}" | awk '{print $1;}')"

    if [[ -n ${container_id} ]]; then

        # Return
        echo "${container_id}" && return 0

    else

        return 1

    fi

}

################################################################################
# Docker delete image.
#
# Arguments:
#   ${1} = ${image_to_delete}
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

        echo "${docker_delete_image}" && return 0

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

    # Log
    display --indent 6 --text "- Importing database"
    log_event "debug" "Running: docker exec -i \"${container_name}\" mysql -u\"${mysql_user}\" -p\"${mysql_user_passw}\" ${mysql_database} < ${dump_file}" "false"

    # Docker run
    # Example: docker exec -i db mysql -uroot -pexample wordpress < dump.sql
    docker exec -i "${container_name}" mysql -u"${mysql_user}" -p"${mysql_user_passw}" "${mysql_database}" < "${dump_file}"

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Importing database" --result "DONE" --color GREEN

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

function docker_mysql_database_export() {

    local container_name="${1}"
    local mysql_user="${2}"
    local mysql_user_passw="${3}"
    local mysql_database="${4}"
    local dump_file="${5}"

    # Docker run
    # Example: docker exec -i db mysqldump -uroot -pexample wordpress > dump.sql
    log_event "debug" "Running: docker exec -i \"${container_name}\" mysql -u\"${mysql_user}\" -p\"${mysql_user_passw}\" ${mysql_database} > ${dump_file}" "false"

    # Docker command
    docker exec -i "${container_name}" mysqldump -u"${mysql_user}" -p"${mysql_user_passw}" "${mysql_database}" > "${dump_file}"

}

################################################################################
# Docker project files import on volume
#
# Arguments:
#   ${1} = ${project_files}
#   ${2} = ${project_path}
#   ${3} = ${project_type}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_project_files_import() {

    local project_backup_file="${1}"
    local project_path="${2}"
    local project_type="${3}"

    local project_backup_path
    local project_volume_path
    local delimiter
    local key
    local rand

    rand="$(cat /dev/urandom | tr -dc 'a-z' | fold -w 3 | head -n 1)"
    project_backup_path="${BROLIT_MAIN_DIR}/tmp/${rand}"

    mkdir -p "${project_backup_path}"

    decompress "${project_backup_file}" "${project_backup_path}" "${BACKUP_CONFIG_COMPRESSION_TYPE}" ""

    # Get inner directory (should be only one)
    inner_dir="$(get_all_directories "${project_backup_path}")"

    # Read ${project_path}/.env on root?
    if [[ -f "${project_path}/.env" ]]; then

        delimiter="="
        key="WWW_DATA_DIR"
        project_volume_path=$(cat "${project_path}/.env" | grep "^${key} ${delimiter}" | cut -f2- -d"${delimiter}")

        if [[ -n ${project_volume_path} ]]; then

            # TODO: check if volume is created? check if container is running?
            copy_files "${project_backup_path}/${inner_dir}" "${project_volume_path}"

        fi

    fi

}

################################################################################
# Docker restore project
#
# Arguments:
#   ${1} = ${backup_to_restore}
#   ${2} = ${backup_status}
#   ${3} = ${backup_server}
#   ${4} = ${project_domain}
#   ${5} = ${project_domain_new}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_restore_project() {

    local backup_to_restore="${1}"
    local backup_status="${2}"
    local backup_server="${3}"
    local project_domain="${4}"
    local project_domain_new="${5}"

    # Extract backup
    decompress "${BROLIT_TMP_DIR}/${backup_to_restore}" "${BROLIT_TMP_DIR}" "${BACKUP_CONFIG_COMPRESSION_TYPE}" ""
    [[ $? -eq 1 ]] && display --indent 6 --text "- Extracting Project Backup" --result "ERROR" --color RED && return 1

    # Check project install type
    project_install_type="$(project_get_install_type "${BROLIT_TMP_DIR}/${project_domain}")"
    [[ -z ${project_install_type} ]] && display --indent 6 --text "- Checking Project Install Type" --result "ERROR" --color RED && return 1

    # If project_install_type="default" ...
    if [[ ${project_install_type} == "docker"* ]]; then
        # Log error
        log_event "error" "Downloaded project already is a docker project" "false"
        display --indent 6 --text "- Downloaded project already is a docker project" --result "ERROR" --color RED
        return 1
    fi

    # Get project type
    project_type="$(project_get_type "${BROLIT_TMP_DIR}/${project_domain}")"
    [[ -z ${project_type} ]] && display --indent 6 --text "- Checking Project Type" --result "ERROR" --color RED && return 1

    # If directory already exist
    if [[ -d ${PROJECTS_PATH}/${project_domain} ]]; then

        # Warning message
        whiptail --title "Warning" --yesno "A docker project already exist for this domain. Do you want to restore the current backup on this docker stack? A backup of current directory will be stored on BROLIT tmp folder." 10 60 3>&1 1>&2 2>&3

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Backup old project
            _create_tmp_copy "${PROJECTS_PATH}/${project_domain}" "copy"
            got_error=$?
            [[ ${got_error} -eq 1 ]] && return 1

        else

            # Log
            log_event "info" "The project directory already exist. User skipped operation." "false"
            display --indent 6 --text "- Restore files" --result "SKIPPED" --color YELLOW

            return 1

        fi

    fi

    # Create new docker compose stack for the ${project_domain} and ${project_type}
    docker_project_install "${PROJECTS_PATH}" "${project_type}" "${project_domain}"
    exitstatus=$?
    [[ ${exitstatus} -eq 1 ]] && return 1

    # TODO
    # WARNING: ONLY WORKS ON WORDPRESS PROJECTS
    if [[ ${project_type} == "wordpress" ]]; then
        # Make a copy of wp-config.php
        cp "${PROJECTS_PATH}/${project_domain}/wordpress/wp-config.php" "${PROJECTS_PATH}/${project_domain}/wp-config.php"

        # Remove actual WordPress files
        rm -R "${PROJECTS_PATH}/${project_domain}/wordpress"

        # Move project files to wordpress folder
        move_files "${BROLIT_TMP_DIR}/${project_domain}" "${PROJECTS_PATH}/${project_domain}/wordpress"
        [[ $? -eq 1 ]] && display --indent 6 --text "- Import files into docker volume" --result "ERROR" --color RED && return 1
        display --indent 6 --text "- Import files into docker volume" --result "DONE" --color GREEN

        # Make a copy of wp-config.php
        cp "${PROJECTS_PATH}/${project_domain}/wordpress/wp-config.php" "${PROJECTS_PATH}/${project_domain}/wordpress/wp-config.php.bak"
        # Move previous wp-config.php to project root
        mv "${PROJECTS_PATH}/${project_domain}/wp-config.php" "${PROJECTS_PATH}/${project_domain}/wordpress/wp-config.php"

        # If .user.ini found, rename it (Wordfence issue workaround)
        [[ -f "${PROJECTS_PATH}/${project_domain}/wordpress/.user.ini" ]] && mv "${PROJECTS_PATH}/${project_domain}/wordpress/.user.ini" "${PROJECTS_PATH}/${project_domain}/wordpress/.user.ini.bak"
    fi

    # Need refactor
    if [[ ${project_type} != "wordpress" ]]; then

        # Remove actual files
        rm -R "${PROJECTS_PATH}/${project_domain}/application"

        # Move project files to application folder
        move_files "${BROLIT_TMP_DIR}/${project_domain}" "${PROJECTS_PATH}/${project_domain}/application"

    fi

    # TODO: update this to match monthly and weekly backups
    project_name="$(project_get_name_from_domain "${project_domain}")"
    project_stage="$(project_get_stage_from_domain "${project_domain}")"

    db_name="${project_name}_${project_stage}"
    #new_project_domain="${project_domain}"

    # TODO: same code as in restore_project_backup! Maybe create a function for this

    # Get backup rotation type (daily, weekly, monthly)
    backup_rotation_type="$(backup_get_rotation_type "${backup_to_restore}")"

    # Get backup date
    project_backup_date="$(backup_get_date "${backup_to_restore}")"

    ## Check ${backup_rotation_type}
    if [[ ${backup_rotation_type} == "daily" ]]; then
        db_to_restore="${db_name}_database_${project_backup_date}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
    else
        db_to_restore="${db_name}_database_${project_backup_date}-${backup_rotation_type}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
    fi

    # Database backup full remote path
    db_to_download="${backup_server}/projects-${backup_status}/database/${db_name}/${db_to_restore}"

    db_to_restore="${db_name}_database_${project_backup_date}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
    project_backup="${db_to_restore%%.*}.sql"

    # Downloading Database Backup
    if ! storage_download_backup "${db_to_download}" "${BROLIT_TMP_DIR}"; then
      log_event "error" "Failed to download database backup from ${db_to_download}" "true"
      return 1
    fi

    # Decompress
    if ! decompress "${BROLIT_TMP_DIR}/${db_to_restore}" "${BROLIT_TMP_DIR}" "${BACKUP_CONFIG_COMPRESSION_TYPE}"; then
      log_event "error" "Failed to decompress database backup" "true"
      return 1
    fi

    # Change permissions
    wp_change_permissions "${PROJECTS_PATH}/${project_domain}/wordpress"

    # Read .env to get mysql pass
    db_user_pass="$(project_get_config_var "${PROJECTS_PATH}/${project_domain}/.env" "MYSQL_PASSWORD")"

    # Read wp-config to get WP DATABASE PREFIX and replace on docker .env file
    #database_prefix_to_restore="$(wp_config_get_option "${BROLIT_TMP_DIR}/${chosen_project}" "table_prefix")"
    database_prefix_to_restore="$(cat "${PROJECTS_PATH}/${project_domain}/wordpress/wp-config.php.bak" | grep "\$table_prefix" | cut -d \' -f 2)"
    if [[ -n ${database_prefix_to_restore} ]]; then
       
        # Set restored $table_prefix on wp-config.php file
        sed -i "s/\$table_prefix = 'wp_'/\$table_prefix = '${database_prefix_to_restore}'/g" "${PROJECTS_PATH}/${project_domain}/wordpress/wp-config.php"
       
        # Stop & Remove Containers
        docker_compose_stop "${PROJECTS_PATH}/${project_domain}/docker-compose.yml"
        docker_compose_rm "${PROJECTS_PATH}/${project_domain}/docker-compose.yml"

        # Pull
        docker_compose_pull "${PROJECTS_PATH}/${project_domain}/docker-compose.yml"

        # Rebuild docker image
        docker_compose_build "${PROJECTS_PATH}/${project_domain}/docker-compose.yml"

    fi

    # Docker MySQL database import
    docker_mysql_database_import "${project_name}_mysql" "${project_name}_user" "${db_user_pass}" "${project_name}_${project_stage}" "${BROLIT_TMP_DIR}/${project_backup}"

    display --indent 6 --text "- Import database into docker volume" --result "DONE" --color GREEN

    # Show final console message
    display --indent 6 --text "- Restore and dockerize project" --result "DONE" --color GREEN
    display --indent 8 --text "Project: ${project_domain}"
    #display --indent 8 --text "Now you can delete the project from the old server."

}

################################################################################
# Docker create new project install
# Arguments:
#   ${1} = ${project_domain}
#   ${2} = ${project_type}
#   ${3} = ${dir_path}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function docker_wait_for_mysql_ready() {
    
    local compose_file="${1}"
    local mysql_user="${2}"
    local mysql_pass="${3}"

    local max_attempts=10
    local attempt=0
    local env_file="${compose_file%/*}/.env"
    local root_pass

    # Extract root password from .env
    if [[ -f "${env_file}" ]]; then
        root_pass=$(grep '^MYSQL_ROOT_PASSWORD=' "${env_file}" | cut -d'=' -f2- | tr -d '[:space:]')
    else
        log_event "error" "Could not find .env file at ${env_file}" "true"
        return 1
    fi

    if [[ -z "${root_pass}" ]]; then
        log_event "error" "MYSQL_ROOT_PASSWORD not found in .env" "true"
        return 1
    fi

    log_event "info" "Waiting for MySQL container and service to be ready..." "false"
    display --indent 6 --text "- Waiting for MySQL to be ready..."

    while [ $attempt -lt $max_attempts ]; do
        # Stage 1: Check if mysql container is running
        if ! docker compose -f "${compose_file}" ps mysql | grep -q "Up"; then
            log_event "debug" "MySQL container not running (attempt $((attempt + 1)))" "false"
            sleep 2
            attempt=$((attempt + 1))
            continue
        fi
        log_event "debug" "MySQL container is up (attempt $((attempt + 1)))" "false"

        # Stage 2: Test MySQL service with mysqladmin ping as root
        local ping_result
        ping_result=$(docker compose -f "${compose_file}" exec mysql mysqladmin ping -uroot -p"${root_pass}" 2>&1)
        local ping_exit=$?
        if [[ ${ping_exit} -eq 0 && "${ping_result}" == *"mysqld is alive"* ]]; then
            log_event "debug" "Root ping successful (attempt $((attempt + 1)))" "false"

            # Stage 3: Quick sequential check for app user (up to 3 attempts)
            local app_ready=false
            local app_ping_result
            for app_try in {1..3}; do
                app_ping_result=$(docker compose -f "${compose_file}" exec mysql mysqladmin ping -u"${mysql_user}" -p"${mysql_pass}" 2>&1)
                if [[ $? -eq 0 && "${app_ping_result}" == *"mysqld is alive"* ]]; then
                    app_ready=true
                    break
                fi
                log_event "debug" "App user ping failed (try ${app_try}: ${app_ping_result}" "false"
                sleep 2
            done

            if [[ "${app_ready}" == "true" ]]; then
                clear_previous_lines "1"
                display --indent 6 --text "- Waiting for MySQL to be ready..." --result "DONE" --color GREEN
                log_event "info" "MySQL is fully ready (root and app user). Root ping: ${ping_result}, App ping: ${app_ping_result}" "false"
                return 0
            else
                log_event "warning" "Root ping OK, but app user not ready after quick check. Proceeding with caution." "false"
                clear_previous_lines "1"
                display --indent 6 --text "- Waiting for MySQL to be ready..." --result "WARN" --color YELLOW
                return 0  # Allow continuation, as root confirms service is up
            fi
        fi

        log_event "debug" "Root ping failed (attempt $((attempt + 1)): ${ping_result} (exit: ${ping_exit})" "false"
        sleep 2
        attempt=$((attempt + 1))
    done

    # If timeout, log final error and return 1
    final_error="${ping_result:-Timeout reached without successful root ping}"
    clear_previous_lines "1"
    display --indent 6 --text "- Waiting for MySQL to be ready..." --result "FAIL" --color RED
    log_event "error" "MySQL did not become ready in time. Final error: ${final_error}" "true"
    return 1
}

function docker_project_install() {

    local dir_path="${1}"
    local project_type="${2}"
    local project_domain="${3}"

    local compose_file
    local project_path
    local port_available
    local php_version

    log_section "Project Installer (${project_type} on docker)"

    # Project Domain
    if [[ -z "${project_domain}" ]]; then
        project_domain="$(project_ask_domain "")"
        [[ $? -eq 1 ]] && return 1
    fi

    # If ${dir_path} is empty, use default project path
    [[ -z ${dir_path} ]] && dir_path="${PROJECTS_PATH}"

    # Project Path
    project_path="${dir_path}/${project_domain}"

    # Project root domain
    project_root_domain="$(domain_get_root "${project_domain}")"

    # TODO: check when add www.DOMAIN.com and then select other stage != prod
    if [[ -z "${project_stage}" ]]; then

        suggested_state="$(domain_get_subdomain_part "${project_domain}")"

        # Project stage
        project_stage="$(project_ask_stage "${suggested_state}")"
        exitstatus=$?
        if [[ ${exitstatus} -eq 1 ]]; then
            # Log
            log_event "info" "Operation cancelled!" "false"
            display --indent 2 --text "- Asking project stage" --result SKIPPED --color YELLOW
            return 1
        fi

    fi

    if [[ -z "${project_name}" ]]; then

        possible_project_name="$(project_get_name_from_domain "${project_domain}")"

        # Project Name
        project_name="$(project_ask_name "${possible_project_name}")"
        exitstatus=$?
        if [[ ${exitstatus} -eq 1 ]]; then
            # Log
            log_event "info" "Operation cancelled!" "false"
            display --indent 2 --text "- Asking project name" --result SKIPPED --color YELLOW
            return 1
        fi

    fi

    # Project Port (docker internal)
    ## Will find the next port available from 81 to 250
    port_available="$(network_next_available_port "81" "350")"

    # TODO: Only for wordpress/laravel/php projects
    # PHP Version
    # Whiptail menu to ask php version to work with
    php_versions="7.4 8.0 8.1 8.2 8.3"
    php_version="$(whiptail_selection_menu "PHP Version" "Choose a PHP version for the Docker container:" "${php_versions}" "8.2")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 1 ]]; then
        # Log
        log_event "info" "Operation cancelled!" "false"
        display --indent 2 --text "- Asking php version" --result SKIPPED --color YELLOW
        return 1
    fi

    [[ "${project_domain}" == "${project_root_domain}" ]] && project_domain="www.${project_domain}" && project_secondary_subdomain="${project_root_domain}"

    case "${project_type}" in

    wordpress)

        # Create project directory
        mkdir -p "${project_path}"

        # Copy docker compose files
        copy_files "${BROLIT_MAIN_DIR}/config/docker-compose/wordpress/production-stack-proxy/" "${project_path}"

        # Download Wordpress on project directory
        wp_download "${project_path}" ""
        [[ $? -eq 1 ]] && return 1

        # Decompress Wordpress files
        decompress "${project_path}/wordpress.tar.gz" "${project_path}" ""
        [[ $? -eq 1 ]] && return 1

        # Cleanup: Remove the downloaded tar.gz file
        rm -f "${project_path}/wordpress.tar.gz"
        log_event "debug" "Cleaned up wordpress.tar.gz after decompression" "false"

        # Replace .env vars
        local wp_port="${port_available}"
        local project_database="${project_name}_${project_stage}"
        local project_database_user="${project_name}_user"

        local project_database_user_passw
        local project_database_root_passw

        project_database_user_passw="$(openssl rand -hex 5)"
        project_database_root_passw="$(openssl rand -hex 5)"

        # Setting COMPOSE_PROJECT_NAME (Stack Name)
        log_event "debug" "Setting COMPOSE_PROJECT_NAME=${project_name}_stack" "false"
        sed -ie "s|^COMPOSE_PROJECT_NAME=.*$|COMPOSE_PROJECT_NAME=${project_name}_stack|g" "${project_path}/.env"

        ## PROJECT
        sed -ie "s|^PROJECT_NAME=.*$|PROJECT_NAME=${project_name}|g" "${project_path}/.env"
        sed -ie "s|^PROJECT_DOMAIN=.*$|PROJECT_DOMAIN=${project_domain}|g" "${project_path}/.env"

        ## PHP
        sed -ie "s|^PHP_VERSION=.*$|PHP_VERSION=${php_version}|g" "${project_path}/.env"

        ## WP (Webserver)
        sed -ie "s|^WP_PORT=.*$|WP_PORT=${wp_port}|g" "${project_path}/.env"

        ##  MYSQL
        sed -ie "s|^MYSQL_DATABASE=.*$|MYSQL_DATABASE=${project_database}|g" "${project_path}/.env"
        sed -ie "s|^MYSQL_USER=.*$|MYSQL_USER=${project_database_user}|g" "${project_path}/.env"
        sed -ie "s|^MYSQL_PASSWORD=.*$|MYSQL_PASSWORD=${project_database_user_passw}|g" "${project_path}/.env"
        sed -ie "s|^MYSQL_ROOT_PASSWORD=.*$|MYSQL_ROOT_PASSWORD=${project_database_root_passw}|g" "${project_path}/.env"

        # Remove tmp file
        rm "${project_path}/.enve"

        compose_file="${project_path}/docker-compose.yml"

        # Execute docker compose commands
        docker_compose_build "${compose_file}"
        [[ $? -eq 1 ]] && return 1

        # Wait for MySQL to be ready
        docker_wait_for_mysql_ready "${compose_file}" "${project_database_user}" "${project_database_user_passw}"
        local mysql_wait_status=$?
        if [[ ${mysql_wait_status} -eq 1 ]]; then
            log_event "warning" "MySQL wait failed completely. Proceeding with caution; DB may not be fully ready." "false"
        fi

        # Pre-chown to ensure writable permissions for user 33
        APP_USER_ID="${APP_USER_ID:-33}"
        APP_GROUP_ID="${APP_GROUP_ID:-33}"
        docker compose -f "${compose_file}" run --rm -u 0 php-fpm chown -R "${APP_USER_ID}:${APP_GROUP_ID}" /wordpress >/dev/null 2>&1

        # Create wp-config.php directly with docker compose run and retries (suppressed output)
        max_retries=3
        success=false
        for retry in $(seq 1 $max_retries); do
            if docker compose -f "${compose_file}" run -T -u 33 -e HOME=/tmp -e APP_USER_ID="${APP_USER_ID}" -e APP_GROUP_ID="${APP_GROUP_ID}" --rm wordpress-cli \
                wp config create \
                --dbname="${project_database}" \
                --dbuser="${project_database_user}" \
                --dbpass="${project_database_user_passw}" \
                --dbhost="mysql" \
                --locale="es_ES" \
                --skip-plugins \
                --skip-themes \
                --quiet >/dev/null 2>&1; then
                success=true
                break
            fi
            [[ $retry -lt $max_retries ]] && sleep $((retry * 2))
        done

        if [[ "${success}" != "true" ]]; then
            log_event "warning" "Direct wp config create failed after $max_retries attempts. Trying fallback: create config as root inside wordpress-cli container" "false"
            # Fallback: create as root (suppressed output)
            if docker compose -f "${compose_file}" run -T -u 0 -e HOME=/tmp -e APP_USER_ID="${APP_USER_ID}" -e APP_GROUP_ID="${APP_GROUP_ID}" --rm wordpress-cli \
                wp config create \
                --dbname="${project_database}" \
                --dbuser="${project_database_user}" \
                --dbpass="${project_database_user_passw}" \
                --dbhost="mysql" \
                --locale="es_ES" \
                --allow-root \
                --skip-plugins \
                --skip-themes \
                --quiet >/dev/null 2>&1; then
                log_event "info" "wp-config.php created as root inside wordpress-cli container" "false"
                # Fix ownership in php-fpm container (already suppressed)
                docker compose -f "${compose_file}" exec -T php-fpm chown -R "${APP_USER_ID}":"${APP_GROUP_ID}" /wordpress >/dev/null 2>&1 || log_event "warning" "Failed to chown inside php-fpm container; check ownership manually" "false"
            else
                log_event "warning" "Creating wp-config as root failed. Trying host fallback (move sample + inject DB constants)" "false"
                # Host fallback (no Docker output)
                if [[ -f "${project_path}/wordpress/wp-config-sample.php" ]]; then
                    cp "${project_path}/wordpress/wp-config-sample.php" "${project_path}/wordpress/wp-config.php" || log_event "error" "Host fallback: cp failed" "false"
                    # Apply DB constants via existing functions
                    project_set_configured_database "${project_path}" "wordpress" "docker" "${project_database}"
                    project_set_configured_database_host "${project_path}" "wordpress" "docker" "mysql"
                    project_set_configured_database_user "${project_path}" "wordpress" "docker" "${project_database_user}"
                    project_set_configured_database_userpassw "${project_path}" "wordpress" "docker" "${project_database_user_passw}"
                    log_event "info" "Host fallback applied: wp-config.php created and DB constants set" "false"
                else
                    log_event "error" "Host fallback failed: wp-config-sample.php not found" "false"
                    return 1
                fi
            fi
        fi

        # Check exitcode
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Log
            sleep 2
            clear_previous_lines "7"
            log_event "info" "Downloading docker images." "false"
            log_event "info" "Building docker images." "false"
            display --indent 6 --text "- Downloading docker images" --result "DONE" --color GREEN
            display --indent 6 --text "- Building docker images" --result "DONE" --color GREEN

            # Update wp-config.php with project_set (edits DB details if needed)
            project_set_configured_database "${project_path}" "wordpress" "docker" "${project_database}"
            project_set_configured_database_host "${project_path}" "wordpress" "docker" "mysql"
            project_set_configured_database_user "${project_path}" "wordpress" "docker" "${project_database_user}"
            project_set_configured_database_userpassw "${project_path}" "wordpress" "docker" "${project_database_user_passw}"

            # Add specific docker installation values on wp-config.php
            ## Write wp-config.php after the first line
            sed -ie "2i \
/** Sets up HTTPS and other needed vars to let WordPress works behind a Proxy */\n\
define('FORCE_SSL_ADMIN', true);\n\
define('FORCE_SSL_LOGIN', true);\n\
if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] == 'https') { \n\
    \$_SERVER['HTTPS']='on';\n\
    \$_SERVER['SERVER_PORT']=443;\n\
}\n\
if (isset(\$_SERVER['HTTP_X_FORWARDED_HOST'])) {\n\
    \$_SERVER['HTTP_HOST'] = \$_SERVER['HTTP_X_FORWARDED_HOST'];\n\
}\n\
define('WP_HOME','https://${project_domain}/');\n\
define('WP_SITEURL','https://${project_domain}/');\n\
define('DISALLOW_FILE_EDIT', true);\n\
define('FS_METHOD', 'direct');\n\
define('WP_REDIS_HOST','redis');\n" "${project_path}/wordpress/wp-config.php"

            # Run startup script to install WP core
            wpcli_run_startup_script "${project_path}/wordpress" "docker" "https://${project_domain}"
            [[ $? -eq 1 ]] && return 1

            # Shuffle salts
            wpcli_shuffle_salts "${project_path}/wordpress" "docker"

            # Add .htaccess
            echo "# PHP Values" >"${project_path}/wordpress/.htaccess"
            echo "php_value upload_max_filesize 500M" >>"${project_path}/wordpress/.htaccess"
            echo "php_value post_max_size 500M" >>"${project_path}/wordpress/.htaccess"

            # Log
            log_event "info" "Creating .htaccess with needed php parameters." "false"
            display --indent 6 --text "- Creating .htaccess on project" --result "DONE" --color GREEN

            # Change permissions
            wp_change_permissions "${project_path}/wordpress"

            # Remove tmp file
            rm "${project_path}/wordpress/wp-config.phpe"

            # Log
            log_event "info" "Making changes on wp-config.php to work with nginx proxy on host." "false"
            display --indent 6 --text "- Making changes on wp-config.php" --result "DONE" --color GREEN

        fi

        ;;

        #    laravel)
        #        # Execute function
        #        # laravel_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_stage}" "${project_root_domain}"
        #        # log_event "warning" "Laravel installer should be implemented soon, trying to install like pure php project ..."
        #        project_installer_php "${project_path}" "${project_domain}" "${project_name}" "${project_stage}" "${project_root_domain}"
        #
        #        ;;
        #
    php | laravel)

        # Create project directory
        mkdir -p "${project_path}"

        # Copy docker compose files
        copy_files "${BROLIT_MAIN_DIR}/config/docker-compose/php/production-stack-proxy/" "${project_path}"

        # Replace .env vars
        local webserver_port="${port_available}"
        local project_database="${project_name}_${project_stage}"
        local project_database_user="${project_name}_user"

        local project_database_user_passw
        local project_database_root_passw

        project_database_user_passw="$(openssl rand -hex 5)"
        project_database_root_passw="$(openssl rand -hex 5)"

        ## PROJECT
        sed -ie "s|^PROJECT_NAME=.*$|PROJECT_NAME=${project_name}|g" "${project_path}/.env"
        sed -ie "s|^PROJECT_DOMAIN=.*$|PROJECT_DOMAIN=${project_domain}|g" "${project_path}/.env"

        ## PHP
        sed -ie "s|^PHP_VERSION=.*$|PHP_VERSION=${php_version}|g" "${project_path}/.env"

        ## WEBSERVER
        sed -ie "s|^WEBSERVER_PORT=.*$|WEBSERVER_PORT=${webserver_port}|g" "${project_path}/.env"

        ##  MYSQL
        sed -ie "s|^MYSQL_DATABASE=.*$|MYSQL_DATABASE=${project_database}|g" "${project_path}/.env"
        sed -ie "s|^MYSQL_USER=.*$|MYSQL_USER=${project_database_user}|g" "${project_path}/.env"
        sed -ie "s|^MYSQL_PASSWORD=.*$|MYSQL_PASSWORD=${project_database_user_passw}|g" "${project_path}/.env"
        sed -ie "s|^MYSQL_ROOT_PASSWORD=.*$|MYSQL_ROOT_PASSWORD=${project_database_root_passw}|g" "${project_path}/.env"

        # Remove tmp file
        rm -f "${project_path}/.enve" 2>/dev/null

        compose_file="${project_path}/docker-compose.yml"

        # Execute docker compose commands
        docker_compose_pull "${compose_file}"
        [[ $? -eq 1 ]] && return 1
        docker_compose_up "${compose_file}"
        # Check exitcode
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
            # Log
            clear_previous_lines "7"
            log_event "info" "Downloading docker images" "false"
            log_event "info" "Building docker images" "false"
            display --indent 6 --text "- Downloading docker images" --result "DONE" --color GREEN
            display --indent 6 --text "- Building docker images" --result "DONE" --color GREEN
        fi

        ;;

    *)
        log_event "error" "Project type '${project_type}' unkwnown, aborting ..." "false"
        return 1
        ;;

    esac

    # Project domain configuration (webserver+certbot+DNS)
    https_enable="$(project_update_domain_config "${project_domain}" "proxy" "docker-compose" "${port_available}")"

    # Post-install tasks for docker
    project_post_install_tasks "${project_path}" "${project_type}" "docker" "${project_name}" "${project_stage}" "${project_database_user_passw}" "" "${project_domain}"

    # TODO: refactor this
    # Cert config files
    cert_path=""
    if [[ -d "/etc/letsencrypt/live/${project_domain}" ]]; then
        cert_path="/etc/letsencrypt/live/${project_domain}"
    else
        if [[ -d "/etc/letsencrypt/live/www.${project_domain}" ]]; then
            cert_path="/etc/letsencrypt/live/www.${project_domain}"
        fi
    fi

    # Create project config file
    # Arguments:
    #  ${1} = ${project_path}
    #  ${2} = ${project_name}
    #  ${3} = ${project_stage}
    #  ${4} = ${project_type}
    #  ${5} = ${project_db_status}
    #  ${6} = ${project_db_engine}
    #  ${7} = ${project_db_name}
    #  ${8} = ${project_db_host}
    #  ${9} = ${project_db_user}
    #  $10 = ${project_db_pass}
    #  $11 = ${project_prymary_subdomain}
    #  $12 = ${project_secondary_subdomains}
    #  $13 = ${project_override_nginx_conf}
    #  $14 = ${project_use_http2}
    #  $15 = ${project_certbot_mode}
    project_update_brolit_config "${project_path}" "${project_name}" "${project_stage}" "${project_type}" "enabled" "mysql" "${project_database}" "localhost" "${project_database_user}" "${project_database_user_passw}" "${project_domain}" "${project_secondary_subdomain}" "/etc/nginx/sites-available/${project_domain}" "" "${cert_path}"

    # Log
    log_event "info" "New ${project_type} project installation for '${project_domain}' finished ok." "false"
    display --indent 6 --text "- ${project_type} project installation" --result "DONE" --color GREEN
    display --indent 8 --text "for domain ${project_domain}"

    # Send notification
    send_notification "${SERVER_NAME}" "New ${project_type} project (docker) installation for '${project_domain}' finished ok!" "success"

}

################################################################################
# Detect Git provider from URL
#
# Arguments:
#   ${1} = ${git_url}
#
# Outputs:
#   Provider name (github, gitlab, bitbucket, other)
################################################################################

function git_detect_provider() {

    local git_url="${1}"
    local provider

    if [[ ${git_url} == *"github.com"* ]]; then
        provider="github"
    elif [[ ${git_url} == *"gitlab.com"* ]]; then
        provider="gitlab"
    elif [[ ${git_url} == *"bitbucket.org"* ]]; then
        provider="bitbucket"
    else
        provider="other"
    fi

    echo "${provider}"

}

################################################################################
# Ask for Git repository URL
#
# Arguments:
#   ${1} = ${suggested_url} - optional
#
# Outputs:
#   Repository URL if ok, 1 on error
################################################################################

function git_ask_repository_url() {

    local suggested_url="${1}"
    local git_url

    git_url="$(whiptail --title "Git Repository" --inputbox "Enter the Git repository URL:\n\nExamples:\n- https://github.com/user/repo.git\n- git@github.com:user/repo.git" 15 70 "${suggested_url}" 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && -n ${git_url} ]]; then

        # Validate URL format
        if [[ ! ${git_url} =~ ^(https?://|git@) ]]; then
            log_event "error" "Invalid Git URL format: ${git_url}" "false"
            display --indent 6 --text "- Invalid Git URL format" --result "FAIL" --color RED
            return 1
        fi

        # Return
        echo "${git_url}" && return 0

    else

        log_event "info" "Git repository URL not provided" "false"
        return 1

    fi

}

################################################################################
# Ask for Git branch
#
# Arguments:
#   ${1} = ${suggested_branch} - optional (default: main)
#
# Outputs:
#   Branch name if ok, 1 on error
################################################################################

function git_ask_branch() {

    local suggested_branch="${1}"
    local git_branch

    [[ -z ${suggested_branch} ]] && suggested_branch="main"

    git_branch="$(whiptail --title "Git Branch" --inputbox "Enter the Git branch to clone:" 10 60 "${suggested_branch}" 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && -n ${git_branch} ]]; then

        # Return
        echo "${git_branch}" && return 0

    else

        log_event "info" "Git branch not provided, using default" "false"
        echo "main" && return 0

    fi

}

################################################################################
# Test Git credentials
#
# Arguments:
#   ${1} = ${git_url}
#
# Outputs:
#   0 if credentials work, 1 on error
################################################################################

function git_test_credentials() {

    local git_url="${1}"
    local test_result

    display --indent 6 --text "- Testing Git credentials ..."
    log_event "debug" "Testing Git credentials for: ${git_url}" "false"

    # Test git ls-remote (works for both SSH and HTTPS)
    test_result="$(git ls-remote "${git_url}" HEAD 2>&1)"
    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        clear_previous_lines "1"
        display --indent 6 --text "- Testing Git credentials" --result "DONE" --color GREEN
        log_event "info" "Git credentials validated successfully" "false"

        return 0

    else

        clear_previous_lines "1"
        display --indent 6 --text "- Testing Git credentials" --result "FAIL" --color RED
        log_event "error" "Git credentials validation failed: ${test_result}" "false"

        return 1

    fi

}

################################################################################
# Setup Git credentials wizard
#
# Arguments:
#   ${1} = ${git_url}
#
# Outputs:
#   0 if configured successfully, 1 on error
################################################################################

function git_credentials_setup_wizard() {

    local git_url="${1}"
    local provider
    local is_private
    local auth_method
    local git_token
    local git_username

    provider="$(git_detect_provider "${git_url}")"

    # Ask if repository is private
    if whiptail --title "Git Repository Access" --yesno "Is this a PRIVATE repository that requires authentication?" 10 60; then
        is_private="yes"
    else
        is_private="no"
        log_event "info" "Public repository, no credentials needed" "false"
        return 0
    fi

    # If using SSH, check if key exists
    if [[ ${git_url} == git@* ]]; then

        if [[ ! -f ~/.ssh/id_rsa && ! -f ~/.ssh/id_ed25519 ]]; then

            whiptail --title "SSH Key Not Found" --msgbox "No SSH key found in ~/.ssh/\n\nPlease generate an SSH key first:\n\nssh-keygen -t ed25519 -C \"your_email@example.com\"\n\nThen add the public key to your Git provider." 15 70

            return 1

        else

            # Show public key
            local pubkey_file
            [[ -f ~/.ssh/id_ed25519.pub ]] && pubkey_file=~/.ssh/id_ed25519.pub || pubkey_file=~/.ssh/id_rsa.pub
            local pubkey
            pubkey="$(cat "${pubkey_file}")"

            whiptail --title "SSH Public Key" --msgbox "Add this public key to your Git provider:\n\n${pubkey}\n\nGitHub: https://github.com/settings/keys\nGitLab: https://gitlab.com/-/profile/keys" 20 78

            # Test connection
            if ! git_test_credentials "${git_url}"; then
                return 1
            fi

        fi

    else

        # HTTPS - need token
        local token_instructions

        case ${provider} in
            github)
                token_instructions="GitHub Personal Access Token Setup:\n\n1. Go to: https://github.com/settings/tokens\n2. Click 'Generate new token (classic)'\n3. Name: 'BROLIT Server - $(hostname)'\n4. Select scopes: ☑ repo (full control)\n5. Click 'Generate token'\n6. Copy the token (starts with 'ghp_')"
                ;;
            gitlab)
                token_instructions="GitLab Personal Access Token Setup:\n\n1. Go to: https://gitlab.com/-/profile/personal_access_tokens\n2. Token name: 'BROLIT Server - $(hostname)'\n3. Select scopes: ☑ read_repository, ☑ write_repository\n4. Click 'Create personal access token'\n5. Copy the token (starts with 'glpat-')"
                ;;
            *)
                token_instructions="Personal Access Token Setup:\n\n1. Go to your Git provider settings\n2. Generate a new access token\n3. Grant repository read/write permissions\n4. Copy the generated token"
                ;;
        esac

        whiptail --title "Authentication Required" --msgbox "${token_instructions}" 18 78

        # Ask for token
        git_token="$(whiptail --title "Access Token" --passwordbox "Paste your Personal Access Token:" 10 60 3>&1 1>&2 2>&3)"

        exitstatus=$?
        if [[ ${exitstatus} -ne 0 || -z ${git_token} ]]; then
            log_event "error" "No token provided" "false"
            return 1
        fi

        # Ask for username (for some providers)
        if [[ ${provider} == "gitlab" ]]; then
            git_username="$(whiptail --title "Git Username" --inputbox "Enter your GitLab username:" 10 60 3>&1 1>&2 2>&3)"
        else
            git_username="git"  # Generic for GitHub and others
        fi

        # Configure git credential helper
        display --indent 6 --text "- Configuring Git credentials ..."
        log_event "debug" "Setting up git credential store" "false"

        git config --global credential.helper store

        # Extract base URL and save credentials
        local base_url
        base_url="$(echo "${git_url}" | grep -oP 'https?://[^/]+')"

        # Save credentials to ~/.git-credentials
        echo "${base_url/https:\/\//https://${git_username}:${git_token}@}" >> ~/.git-credentials

        # Set restrictive permissions
        chmod 600 ~/.git-credentials

        clear_previous_lines "1"
        display --indent 6 --text "- Configuring Git credentials" --result "DONE" --color GREEN
        log_event "info" "Git credentials stored in ~/.git-credentials" "false"

        # Update git_url to include token for this clone
        git_url="${git_url/https:\/\//https://${git_username}:${git_token}@}"
        echo "${git_url}"

        # Test credentials
        if ! git_test_credentials "${git_url}"; then
            # Remove failed credentials
            sed -i "\|${base_url}|d" ~/.git-credentials
            return 1
        fi

    fi

    return 0

}

################################################################################
# Detect project type from Git repository
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   Project type (wordpress, laravel, php, nodejs, react, html, custom-docker, unknown)
################################################################################

function docker_detect_project_type_from_git() {

    local project_path="${1}"
    local project_type

    log_event "debug" "Detecting project type in: ${project_path}" "false"

    # 1. Check if docker-compose.yml already exists
    if [[ -f "${project_path}/docker-compose.yml" ]] || [[ -f "${project_path}/docker-compose.yaml" ]]; then
        project_type="custom-docker"
        log_event "info" "Detected project type: ${project_type} (existing docker-compose)" "false"
        echo "${project_type}"
        return 0
    fi

    # 2. WordPress detection
    if [[ -f "${project_path}/wp-config.php" ]] ||
       [[ -d "${project_path}/wp-content" ]] ||
       [[ -f "${project_path}/wp-config-sample.php" ]]; then
        project_type="wordpress"
        log_event "info" "Detected project type: ${project_type}" "false"
        echo "${project_type}"
        return 0
    fi

    # Check composer.json for WordPress
    if [[ -f "${project_path}/composer.json" ]]; then
        if grep -q "wordpress" "${project_path}/composer.json" 2>/dev/null; then
            project_type="wordpress"
            log_event "info" "Detected project type: ${project_type} (from composer.json)" "false"
            echo "${project_type}"
            return 0
        fi

        # 3. Laravel detection
        if grep -q "laravel/framework" "${project_path}/composer.json" 2>/dev/null &&
           [[ -f "${project_path}/artisan" ]]; then
            project_type="laravel"
            log_event "info" "Detected project type: ${project_type}" "false"
            echo "${project_type}"
            return 0
        fi
    fi

    # 4. PHP generic
    if [[ -f "${project_path}/composer.json" ]] ||
       [[ -f "${project_path}/index.php" ]]; then
        project_type="php"
        log_event "info" "Detected project type: ${project_type}" "false"
        echo "${project_type}"
        return 0
    fi

    # 5. NodeJS/React detection
    if [[ -f "${project_path}/package.json" ]]; then
        # Check if it's React
        if grep -q "\"react\"" "${project_path}/package.json" 2>/dev/null; then
            project_type="react"
        else
            project_type="nodejs"
        fi
        log_event "info" "Detected project type: ${project_type}" "false"
        echo "${project_type}"
        return 0
    fi

    # 6. HTML static
    if find "${project_path}" -maxdepth 1 -name "*.html" -type f | grep -q .; then
        project_type="html"
        log_event "info" "Detected project type: ${project_type}" "false"
        echo "${project_type}"
        return 0
    fi

    # Unknown type
    project_type="unknown"
    log_event "warning" "Could not detect project type" "false"
    echo "${project_type}"
    return 1

}

################################################################################
# Clone Git repository with credentials
#
# Arguments:
#   ${1} = ${git_url}
#   ${2} = ${destination_path}
#   ${3} = ${branch} - optional (default: main)
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function git_clone_with_credentials() {

    local git_url="${1}"
    local destination_path="${2}"
    local branch="${3}"

    [[ -z ${branch} ]] && branch="main"

    display --indent 6 --text "- Cloning Git repository ..."
    log_event "debug" "Cloning ${git_url} to ${destination_path}" "false"
    log_event "debug" "Branch: ${branch}" "false"

    # Try to clone with specified branch
    git clone --branch "${branch}" "${git_url}" "${destination_path}" >/dev/null 2>&1
    exitstatus=$?

    # If failed, try with 'master' branch
    if [[ ${exitstatus} -ne 0 && ${branch} == "main" ]]; then
        log_event "debug" "Branch 'main' not found, trying 'master'" "false"
        git clone --branch "master" "${git_url}" "${destination_path}" >/dev/null 2>&1
        exitstatus=$?
    fi

    if [[ ${exitstatus} -eq 0 ]]; then

        clear_previous_lines "1"
        display --indent 6 --text "- Cloning Git repository" --result "DONE" --color GREEN
        log_event "info" "Repository cloned successfully" "false"

        return 0

    else

        clear_previous_lines "1"
        display --indent 6 --text "- Cloning Git repository" --result "FAIL" --color RED
        log_event "error" "Failed to clone repository" "false"

        return 1

    fi

}

################################################################################
# Install Docker project from Git repository
#
# Arguments:
#   ${1} = ${dir_path}        - optional (default: PROJECTS_PATH)
#   ${2} = ${git_url}         - optional (will ask if empty)
#   ${3} = ${project_domain}  - optional (will ask if empty)
#   ${4} = ${git_branch}      - optional (default: main/master)
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function docker_project_install_from_git() {

    local dir_path="${1}"
    local git_url="${2}"
    local project_domain="${3}"
    local git_branch="${4}"

    local tmp_clone_path
    local project_path
    local project_type
    local project_name
    local project_stage
    local project_root_domain
    local project_secondary_subdomain
    local suggested_state
    local possible_project_name
    local git_url_with_credentials

    log_section "Project Installer (from Git Repository)"

    # Check dependencies
    if ! command -v git &>/dev/null; then
        log_event "error" "Git is not installed" "false"
        display --indent 2 --text "- Checking Git installation" --result "FAIL" --color RED
        return 1
    fi

    if ! command -v docker &>/dev/null; then
        log_event "error" "Docker is not installed" "false"
        display --indent 2 --text "- Checking Docker installation" --result "FAIL" --color RED
        return 1
    fi

    # Git Repository URL
    if [[ -z ${git_url} ]]; then
        git_url="$(git_ask_repository_url "")"
        [[ $? -eq 1 ]] && return 1
    fi

    log_event "info" "Git repository: ${git_url}" "false"
    display --indent 2 --text "- Git repository" --result "DONE" --color GREEN
    display --indent 4 --text "${git_url}" --tcolor YELLOW

    # Git Branch
    if [[ -z ${git_branch} ]]; then
        git_branch="$(git_ask_branch "main")"
    fi

    log_event "info" "Git branch: ${git_branch}" "false"
    display --indent 2 --text "- Git branch: ${git_branch}" --result "DONE" --color GREEN

    # Setup Git credentials
    log_subsection "Git Credentials Setup"
    git_url_with_credentials="$(git_credentials_setup_wizard "${git_url}")"
    if [[ $? -eq 1 ]]; then
        log_event "error" "Git credentials setup failed" "false"
        display --indent 2 --text "- Git credentials setup" --result "FAIL" --color RED
        return 1
    fi

    # Use credentials-embedded URL if returned
    [[ -n ${git_url_with_credentials} ]] && git_url="${git_url_with_credentials}"

    # Project Domain
    if [[ -z ${project_domain} ]]; then
        project_domain="$(project_ask_domain "")"
        [[ $? -eq 1 ]] && return 1
    fi

    log_event "info" "Project domain: ${project_domain}" "false"
    display --indent 2 --text "- Project domain" --result "DONE" --color GREEN
    display --indent 4 --text "${project_domain}" --tcolor YELLOW

    # Set paths
    [[ -z ${dir_path} ]] && dir_path="${PROJECTS_PATH}"
    project_path="${dir_path}/${project_domain}"

    # Check if project already exists
    if [[ -d "${project_path}" ]]; then
        log_event "error" "Project directory already exists: ${project_path}" "false"
        display --indent 2 --text "- Project directory check" --result "FAIL" --color RED
        display --indent 4 --text "Directory already exists: ${project_path}" --tcolor RED
        return 1
    fi

    # Clone to temporary location first
    log_subsection "Cloning Repository"
    tmp_clone_path="${BROLIT_TMP_DIR}/git-clone-$(date +%s)"
    mkdir -p "${tmp_clone_path}"

    if ! git_clone_with_credentials "${git_url}" "${tmp_clone_path}" "${git_branch}"; then
        rm -rf "${tmp_clone_path}"
        return 1
    fi

    # Detect project type
    log_subsection "Project Detection"
    project_type="$(docker_detect_project_type_from_git "${tmp_clone_path}")"

    if [[ ${project_type} == "unknown" ]]; then
        whiptail --title "Unknown Project Type" --msgbox "Could not automatically detect project type.\n\nPlease ensure your repository contains:\n- docker-compose.yml (for custom Docker projects)\n- wp-content/ or wp-config.php (for WordPress)\n- artisan + composer.json (for Laravel)\n- composer.json or index.php (for PHP)\n- package.json (for NodeJS/React)\n- *.html files (for static HTML)" 18 70
        rm -rf "${tmp_clone_path}"
        return 1
    fi

    display --indent 2 --text "- Detected project type" --result "${project_type}" --color GREEN

    # Ask user confirmation
    if ! whiptail --title "Project Type Confirmation" --yesno "Detected project type: ${project_type}\n\nIs this correct?" 10 60; then
        # Let user select type manually
        local project_types="wordpress laravel php nodejs react html custom-docker"
        project_type="$(whiptail_selection_menu "Project Type" "Choose the project type:" "${project_types}" "${project_type}")"
        [[ $? -eq 1 ]] && rm -rf "${tmp_clone_path}" && return 1
    fi

    # Project root domain
    project_root_domain="$(domain_get_root "${project_domain}")"

    # Project stage
    suggested_state="$(domain_get_subdomain_part "${project_domain}")"
    project_stage="$(project_ask_stage "${suggested_state}")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 1 ]]; then
        log_event "info" "Operation cancelled!" "false"
        display --indent 2 --text "- Asking project stage" --result SKIPPED --color YELLOW
        rm -rf "${tmp_clone_path}"
        return 1
    fi

    # Project name
    possible_project_name="$(project_get_name_from_domain "${project_domain}")"
    project_name="$(project_ask_name "${possible_project_name}")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 1 ]]; then
        log_event "info" "Operation cancelled!" "false"
        display --indent 2 --text "- Asking project name" --result SKIPPED --color YELLOW
        rm -rf "${tmp_clone_path}"
        return 1
    fi

    # Handle www subdomain
    [[ "${project_domain}" == "${project_root_domain}" ]] && project_domain="www.${project_domain}" && project_secondary_subdomain="${project_root_domain}"

    # Move cloned repository to final location
    log_subsection "Setting Up Project"
    display --indent 2 --text "- Moving repository to final location ..."
    mv "${tmp_clone_path}" "${project_path}"

    clear_previous_lines "1"
    display --indent 2 --text "- Moving repository to final location" --result "DONE" --color GREEN

    # Handle project based on type
    local port_available
    local php_version
    local php_versions
    local project_database
    local project_database_user
    local project_database_user_passw
    local project_database_root_passw
    local compose_file

    case "${project_type}" in

        custom-docker)
            # Project already has docker-compose.yml
            log_event "info" "Using existing docker-compose.yml" "false"
            display --indent 2 --text "- Using existing docker-compose.yml" --result "INFO" --color CYAN

            # Just need to configure .env if it doesn't exist
            if [[ ! -f "${project_path}/.env" && -f "${project_path}/.env.example" ]]; then
                cp "${project_path}/.env.example" "${project_path}/.env"
                display --indent 2 --text "- Created .env from .env.example" --result "DONE" --color GREEN
            fi

            # Get port from existing config
            port_available="$(grep -E '^(WP_PORT|APP_PORT|PHP_PORT|WEBSERVER_PORT|PORT)=' "${project_path}/.env" 2>/dev/null | head -n1 | cut -d'=' -f2)"
            [[ -z ${port_available} ]] && port_available="$(network_next_available_port "81" "350")"

            # Start the stack
            compose_file="${project_path}/docker-compose.yml"
            docker_compose_build "${compose_file}"
            [[ $? -eq 1 ]] && return 1

            # Set default database variables for config
            project_database_user_passw=""
            ;;

        wordpress)
            # Use existing WordPress Docker installation function
            # But we need to adapt it for Git-cloned projects
            log_event "info" "Setting up WordPress Docker project from Git" "false"

            # Copy docker-compose template
            cp -r "${BROLIT_MAIN_DIR}/config/docker-compose/wordpress/production-stack-proxy/docker-compose.yml" "${project_path}/"
            cp -r "${BROLIT_MAIN_DIR}/config/docker-compose/wordpress/production-stack-proxy/.env" "${project_path}/.env.docker"

            # Generate configuration
            port_available="$(network_next_available_port "81" "350")"

            php_versions="7.4 8.0 8.1 8.2 8.3"
            php_version="$(whiptail_selection_menu "PHP Version" "Choose a PHP version for the Docker container:" "${php_versions}" "8.2")"
            [[ $? -eq 1 ]] && return 1

            project_database="${project_name}_${project_stage}"
            project_database_user="${project_name}_user"

            project_database_user_passw="$(openssl rand -hex 5)"
            project_database_root_passw="$(openssl rand -hex 5)"

            # Update .env.docker
            sed -i "s|^COMPOSE_PROJECT_NAME=.*$|COMPOSE_PROJECT_NAME=${project_name}_stack|g" "${project_path}/.env.docker"
            sed -i "s|^PROJECT_NAME=.*$|PROJECT_NAME=${project_name}|g" "${project_path}/.env.docker"
            sed -i "s|^PROJECT_DOMAIN=.*$|PROJECT_DOMAIN=${project_domain}|g" "${project_path}/.env.docker"
            sed -i "s|^PHP_VERSION=.*$|PHP_VERSION=${php_version}|g" "${project_path}/.env.docker"
            sed -i "s|^WP_PORT=.*$|WP_PORT=${port_available}|g" "${project_path}/.env.docker"
            sed -i "s|^MYSQL_DATABASE=.*$|MYSQL_DATABASE=${project_database}|g" "${project_path}/.env.docker"
            sed -i "s|^MYSQL_USER=.*$|MYSQL_USER=${project_database_user}|g" "${project_path}/.env.docker"
            sed -i "s|^MYSQL_PASSWORD=.*$|MYSQL_PASSWORD=${project_database_user_passw}|g" "${project_path}/.env.docker"
            sed -i "s|^MYSQL_ROOT_PASSWORD=.*$|MYSQL_ROOT_PASSWORD=${project_database_root_passw}|g" "${project_path}/.env.docker"

            # Rename for docker-compose
            mv "${project_path}/.env.docker" "${project_path}/.env"

            # Build and start
            local compose_file="${project_path}/docker-compose.yml"
            docker_compose_build "${compose_file}"
            [[ $? -eq 1 ]] && return 1
            ;;

        laravel|php)
            log_event "info" "Setting up ${project_type} Docker project from Git" "false"

            # Copy PHP docker-compose template if doesn't exist
            if [[ ! -f "${project_path}/docker-compose.yml" ]]; then
                cp -r "${BROLIT_MAIN_DIR}/config/docker-compose/php/"* "${project_path}/"
            fi

            # Similar configuration as WordPress
            port_available="$(network_next_available_port "81" "350")"

            php_versions="7.4 8.0 8.1 8.2 8.3"
            php_version="$(whiptail_selection_menu "PHP Version" "Choose a PHP version:" "${php_versions}" "8.2")"
            [[ $? -eq 1 ]] && return 1

            project_database="${project_name}_${project_stage}"
            project_database_user="${project_name}_user"
            project_database_user_passw="$(openssl rand -hex 5)"

            # Configure and start
            # TODO: Implement PHP/Laravel specific configuration
            display --indent 2 --text "- ${project_type} Docker setup" --result "TODO" --color YELLOW
            ;;

        *)
            log_event "error" "Project type '${project_type}' not yet fully implemented for Git installation" "false"
            display --indent 2 --text "- Project type not yet supported" --result "FAIL" --color RED
            return 1
            ;;

    esac

    # Configure domain (NGINX + Certbot + DNS)
    log_subsection "Configuring Domain"

    # Detect port from docker-compose
    local proxy_port
    if [[ -f "${project_path}/.env" ]]; then
        proxy_port="$(grep -E '^(WP_PORT|APP_PORT|PHP_PORT|WEBSERVER_PORT|PORT)=' "${project_path}/.env" | head -n1 | cut -d'=' -f2)"
    fi
    [[ -z ${proxy_port} ]] && proxy_port="${port_available:-81}"

    # Project domain configuration (webserver+certbot+DNS)
    local https_enable
    https_enable="$(project_update_domain_config "${project_domain}" "proxy" "docker-compose" "${proxy_port}")"

    # Post-install tasks for docker
    project_post_install_tasks "${project_path}" "${project_type}" "docker" "${project_name}" "${project_stage}" "${project_database_user_passw:-}" "" "${project_domain}"

    # Create BROLIT project config
    log_subsection "Creating Project Configuration"

    # TODO: refactor this
    # Cert config files
    local cert_path=""
    if [[ -d "/etc/letsencrypt/live/${project_domain}" ]]; then
        cert_path="/etc/letsencrypt/live/${project_domain}"
    else
        if [[ -d "/etc/letsencrypt/live/www.${project_domain}" ]]; then
            cert_path="/etc/letsencrypt/live/www.${project_domain}"
        fi
    fi

    local project_database="${project_name}_${project_stage}"
    local project_database_user="${project_name}_user"

    # Create project config file
    # Arguments:
    #  ${1} = ${project_path}
    #  ${2} = ${project_name}
    #  ${3} = ${project_stage}
    #  ${4} = ${project_type}
    #  ${5} = ${project_db_status}
    #  ${6} = ${project_db_engine}
    #  ${7} = ${project_db_name}
    #  ${8} = ${project_db_host}
    #  ${9} = ${project_db_user}
    #  $10 = ${project_db_pass}
    #  $11 = ${project_prymary_subdomain}
    #  $12 = ${project_secondary_subdomains}
    #  $13 = ${project_override_nginx_conf}
    #  $14 = ${project_use_http2}
    #  $15 = ${project_certbot_mode}
    project_update_brolit_config "${project_path}" "${project_name}" "${project_stage}" "${project_type}" "enabled" "mysql" "${project_database}" "localhost" "${project_database_user}" "${project_database_user_passw:-}" "${project_domain}" "${project_secondary_subdomain}" "/etc/nginx/sites-available/${project_domain}" "" "${cert_path}"

    # Save Git information in project config
    if [[ -f "${project_path}/project-config.json" ]]; then
        # Add Git metadata
        local git_remote_url
        git_remote_url="$(cd "${project_path}" && git remote get-url origin 2>/dev/null)"
        # TODO: Add git metadata to project-config.json
        log_event "debug" "Git remote URL: ${git_remote_url}" "false"
    fi

    # Final messages
    log_event "info" "New ${project_type} project from Git for '${project_domain}' finished ok." "false"
    display --indent 2 --text "- ${project_type} project installation" --result "DONE" --color GREEN
    display --indent 4 --text "Domain: ${project_domain}" --tcolor GREEN
    display --indent 4 --text "Git repository: ${git_url}" --tcolor CYAN
    display --indent 4 --text "Branch: ${git_branch}" --tcolor CYAN

    # Send notification
    send_notification "${SERVER_NAME}" "New ${project_type} project from Git for '${project_domain}' finished ok!" "success"

    # Show useful commands
    whiptail --title "Installation Complete" --msgbox "Project installed successfully!\n\nUseful commands:\n\nView logs:\n  cd ${project_path} && docker-compose logs -f\n\nUpdate from Git:\n  cd ${project_path} && git pull\n\nRebuild containers:\n  cd ${project_path} && docker-compose down && docker-compose up -d --build\n\nProject URL:\n  https://${project_domain}" 20 78

    return 0

}
