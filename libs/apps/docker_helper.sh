#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.3
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
    docker exec -i "${container_name}" mysql -u"${mysql_user}" -p"${mysql_user_passw}" "${mysql_database}" <"${dump_file}"

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
    docker exec -i "${container_name}" mysqldump -u"${mysql_user}" -p"${mysql_user_passw}" "${mysql_database}" >"${dump_file}"

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

    decompress "${project_backup_file}" "${project_backup_path}" "${BACKUP_CONFIG_COMPRESSION_TYPE}"

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

function docker_restore_project() {

    local backup_to_restore="${1}"
    local backup_status="${2}"
    local backup_server="${3}"
    local project_domain="${4}"
    local project_domain_new="${5}"

    # Extract backup
    decompress "${BROLIT_TMP_DIR}/${backup_to_restore}" "${BROLIT_TMP_DIR}" "${BACKUP_CONFIG_COMPRESSION_TYPE}"
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
    if [[ -z ${project_domain} ]]; then
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
    if [[ -z ${project_stage} ]]; then

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

    if [[ -z ${project_name} ]]; then

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
    php_versions="7.4 8.0 8.1 8.2"
    php_version="$(whiptail_selection_menu "PHP Version" "Choose a PHP version for the Docker container:" "${php_versions}" "7.4")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 1 ]]; then
        # Log
        log_event "info" "Operation cancelled!" "false"
        display --indent 2 --text "- Asking php version" --result SKIPPED --color YELLOW
        return 1
    fi

    [[ ${project_domain} == "${project_root_domain}" ]] && project_domain="www.${project_domain}" && project_secondary_subdomain="${project_root_domain}"

    case ${project_type} in

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
        docker_compose_up "${compose_file}"
        [[ $? -eq 1 ]] && return 1
        docker_compose_build "${compose_file}"
        [[ $? -eq 1 ]] && return 1

        # Check exitcode
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Log
            wait 2
            #clear_previous_lines "7"
            clear_previous_lines "22"
            log_event "info" "Downloading docker images." "false"
            log_event "info" "Building docker images." "false"
            display --indent 6 --text "- Downloading docker images" --result "DONE" --color GREEN
            display --indent 6 --text "- Building docker images" --result "DONE" --color GREEN

            # Add .htaccess
            echo "# PHP Values" >"${project_path}/wordpress/.htaccess"
            echo "php_value upload_max_filesize 500M" >>"${project_path}/wordpress/.htaccess"
            echo "php_value post_max_size 500M" >>"${project_path}/wordpress/.htaccess"

            # Log
            log_event "info" "Creating .htaccess with needed php parameters." "false"
            display --indent 6 --text "- Creating .htaccess on project" --result "DONE" --color GREEN

            # Rename wp-config-sample.php to wp-config.php
            mv "${project_path}/wordpress/wp-config-sample.php" "${project_path}/wordpress/wp-config.php"

            # Update wp-config.php
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

            # TODO: change wp table prefix

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
        rm "${project_path}/.enve"

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

    # Startup Script for WordPress installation
    #if [[ ${https_enable} == "true" ]]; then
    #    project_site_url="https://${project_domain}"
    #else
    #    project_site_url="http://${project_domain}"
    #fi

    #[[ ${BROLIT_EXEC_TYPE} == "default" && ${project_type} == "wordpress" ]] && wpcli_run_startup_script "${project_path}" "${project_site_url}"

    # Post-restore/install tasks
    #project_post_install_tasks "${project_path}" "${project_type}" "${project_name}" "${project_stage}" "${database_user_passw}" "" ""

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
    project_update_brolit_config "${project_path}" "${project_name}" "${project_stage}" "${project_type} " "enabled" "mysql" "${database_name}" "localhost" "${database_user}" "${database_user_passw}" "${project_domain}" "${project_secondary_subdomain}" "/etc/nginx/sites-available/${project_domain}" "" "${cert_path}"

    # Log
    log_event "info" "New ${project_type} project installation for '${project_domain}' finished ok." "false"
    display --indent 6 --text "- ${project_type} project installation" --result "DONE" --color GREEN
    display --indent 8 --text "for domain ${project_domain}"

    # Send notification
    send_notification "${SERVER_NAME}" "New ${project_type} project (docker) installation for '${project_domain}' finished ok!" "success"

}
