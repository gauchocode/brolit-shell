#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc9
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
    PACKAGES_DOCKER_COMPOSE_STATUS="enabled"
    json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.docker[].status" "${PACKAGES_DOCKER_STATUS}"
    json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.docker[].compose[].status" "${PACKAGES_DOCKER_COMPOSE_STATUS}"
    export PACKAGES_DOCKER_STATUS PACKAGES_DOCKER_COMPOSE_STATUS

    # Check if portainer is running
    portainer="$(docker_get_container_id "portainer")"

    if [[ -z ${portainer} ]]; then

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Create project directory
            mkdir -p "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}"

            # Copy docker-compose file to project directory
            cp "${BROLIT_MAIN_DIR}/utils/installers/docker-compose/portainer/docker-compose.yml" "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}"

            # Replace domain in docker-compose file
            sed -i "s/PORTAINER_SUBDOMAIN/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}/g" "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}/docker-compose.yml"
            # Replace port in docker-compose file
            sed -i "s/PORTAINER_PORT/${PACKAGES_PORTAINER_CONFIG_PORT}/g" "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}/docker-compose.yml"

            # Run docker-compose pull on specific directory
            docker-compose -f "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}/docker-compose.yml" pull

            # Run docker-compose up -d on specific directory
            docker-compose -f "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}/docker-compose.yml" up -d

            clear_previous_lines "3"

            PACKAGES_PORTAINER_STATUS="enabled"

            #json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.portainer[].status" "${PACKAGES_PORTAINER_STATUS}"

            # new global value ("enabled")
            export PACKAGES_PORTAINER_STATUS

            return 0

        else

            return 1

        fi

    else

        log_event "warning" "Portainer is already installed" "false"

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
    docker stop "${container_id}"

    # Remove Portainer Container
    docker rm -f portainer

    # Remove Portainer Volume
    volume rm portainer_data

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

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
        if [ "$(ufw status | grep -c "Status: active")" -eq "1" ]; then
            firewall_allow "${PACKAGES_PORTAINER_CONFIG_PORT}"
        fi

    fi

    if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

        local root_domain

        root_domain="$(domain_get_root "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}")"

        cloudflare_set_record "${root_domain}" "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}" "A" "false" "${SERVER_IP}"

        if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then
            certbot_certificate_install "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}"
        fi

    fi

    # Log
    display --indent 6 --text "- Portainer configuration" --result "DONE" --color GREEN
    log_event "info" "Portainer configured" "false"

}
