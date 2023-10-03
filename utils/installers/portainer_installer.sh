#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.3
################################################################################
#
# Portainer Installer
#
################################################################################

################################################################################
# Portainer install
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function portainer_installer() {

    local portainer

    log_subsection "Portainer Installer"

    package_update

    package_install_if_not "docker.io"
    package_install_if_not "docker-compose"

    # Force update brolit_conf.json
    PACKAGES_DOCKER_STATUS="enabled"
    json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.docker[].status" "${PACKAGES_DOCKER_STATUS}"
    export PACKAGES_DOCKER_STATUS

    # Check if portainer is running
    portainer="$(docker_get_container_id "portainer")"

    exitstatus=$?

    if [[ -z ${portainer} ]]; then

        # Create project directory
        mkdir -p "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}"

        # Copy docker-compose.yml and .env files to project directory
        cp "${BROLIT_MAIN_DIR}/utils/installers/docker-compose/portainer/docker-compose.yml" "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}"
        cp "${BROLIT_MAIN_DIR}/utils/installers/docker-compose/portainer/.env" "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}"

        # Configure .env file (portainer)
        project_set_config_var "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}/.env" "VIRTUAL_HOST" "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}" "none"
        project_set_config_var "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}/.env" "PORTAINER_PORT" "${PACKAGES_PORTAINER_CONFIG_PORT}" "none"

        # Run docker-compose pull on specific directory
        docker-compose -f "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}/docker-compose.yml" pull

        # Run docker-compose up -d on specific directory
        docker-compose -f "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}/docker-compose.yml" up -d

        clear_previous_lines "3"

        return 0

    else

        log_event "warning" "Portainer is already installed" "false"

        return 1

    fi

}

################################################################################
# Portainer purge/remove
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function portainer_purge() {

    log_subsection "Portainer Installer"

    # Get Portainer Container ID
    container_id="$(docker ps | grep portainer | awk '{print $1;}')"

    # Stop Portainer Container
    result_stop="$(docker stop "${container_id}")"
    if [[ -z ${result_stop} ]]; then
        display --indent 6 --text "- Stopping portainer container" --result "FAIL" --color RED
        log_event "error" "Portainer container not found." "true"
        return 1
    fi

    display --indent 6 --text "- Stopping portainer container" --result "DONE" --color GREEN

    # Remove Portainer Container
    result_remove="$(docker rm -f portainer)"
    if [[ -z ${result_remove} ]]; then
        display --indent 6 --text "- Deleting portainer container" --result "FAIL" --color RED
        log_event "error" "Deleting portainer container." "true"
        return 1
    fi

    # Remove Portainer Data
    rm --recursive "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN:?}"

    # Remove Portainer Volume
    #docker volume rm portainer_data

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && ${PACKAGES_PORTAINER_STATUS} == "enabled" ]]; then

        PACKAGES_PORTAINER_STATUS="disabled"

        json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.portainer[].status" "${PACKAGES_PORTAINER_STATUS}"

        # new global value ("disabled")
        export PACKAGES_PORTAINER_STATUS

        return 0

    else

        return 1

    fi

}

################################################################################
# Configure Portainer service
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function portainer_configure() {

    log_event "info" "Configuring Portainer ..." "false"

    if [[ ${PACKAGES_NGINX_STATUS} == "enabled" && ${PACKAGES_PORTAINER_CONFIG_NGINX} == "enabled" ]]; then

        # Create nginx server block
        nginx_server_create "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}" "portainer" "single" "" "${PACKAGES_PORTAINER_CONFIG_PORT}"

        # Replace port on nginx server config
        sed -i "s/PORTAINER_PORT/${PACKAGES_PORTAINER_CONFIG_PORT}/g" "${WSERVER}/sites-available/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}"

    else # If not use nginx as reverse proxy

        # Check if firewall is enabled
        if [[ "$(ufw status | grep -c "Status: active")" -eq "1" ]]; then
            firewall_allow "${PACKAGES_PORTAINER_CONFIG_PORT}"
        fi

    fi

    if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

        local root_domain

        root_domain="$(domain_get_root "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}")"

        cloudflare_set_record "${root_domain}" "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}" "A" "false" "${SERVER_IP}"

        if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then
            # Wait 2 seconds for DNS update
            sleep 2
            # Let's Encrypt
            certbot_certificate_install "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}"
        fi

    fi

    # Log
    display --indent 6 --text "- Portainer configuration" --result "DONE" --color GREEN
    log_event "info" "Portainer configured" "false"

}
