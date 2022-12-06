#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.3.0-beta
################################################################################
#
# Portainer Agent Installer
#
################################################################################

################################################################################
# Portainer Agent install
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function portainer_agent_installer() {

    local portainer_agent
    local portainer_agent_path="/root/agent_portainer"

    log_subsection "Portainer Agent Installer"

    package_update

    package_install_if_not "docker.io"
    package_install_if_not "docker-compose"

    # Force update brolit_conf.json
    PACKAGES_DOCKER_STATUS="enabled"
    PACKAGES_DOCKER_COMPOSE_STATUS="enabled"
    json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.docker[].status" "${PACKAGES_DOCKER_STATUS}"
    json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.docker[].compose[].status" "${PACKAGES_DOCKER_COMPOSE_STATUS}"
    export PACKAGES_DOCKER_STATUS PACKAGES_DOCKER_COMPOSE_STATUS

    # Check if portainer_agent is running
    portainer_agent="$(docker_get_container_id "portainer_agent")"

    exitstatus=$?
    if [[ -z ${portainer_agent} ]]; then

        # Create project directory
        mkdir -p "${portainer_agent_path}"

        # Copy docker-compose.yml and .env files to project directory
        cp "${BROLIT_MAIN_DIR}/utils/installers/docker-compose/portainer_agent/docker-compose.yml" "${portainer_agent_path}"
        cp "${BROLIT_MAIN_DIR}/utils/installers/docker-compose/portainer_agent/.env" "${portainer_agent_path}"

        # Configure .env file
        project_set_config_var "${portainer_agent_path}/.env" "PORTAINER_AGENT_PORT" "${PACKAGES_PORTAINER_AGENT_CONFIG_PORT}" "none"

        # Enable port in firewall
        firewall_allow "${PACKAGES_PORTAINER_AGENT_CONFIG_PORT}"

        # Run docker-compose pull on specific directory
        docker-compose -f "${portainer_agent_path}/docker-compose.yml" pull

        # Run docker-compose up -d on specific directory
        docker-compose -f "${portainer_agent_path}/docker-compose.yml" up -d

        clear_previous_lines "3"

        return 0

    else

        log_event "warning" "Portainer Agent is already installed" "false"

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

function portainer_agent_purge() {

    log_subsection "Portainer Agent Installer"

    # Get Portainer Container ID
    container_id="$(docker ps | grep portainer | awk '{print $1;}')"

    # Stop Portainer Container
    result_stop="$(docker stop "${container_id}")"
    if [[ -z ${result_stop} ]]; then
        display --indent 6 --text "- Stopping Portainer Agent container" --result "FAIL" --color RED
        log_event "error" "Portainer Agent container not found." "true"
        return 1
    fi

    display --indent 6 --text "- Stopping Portainer Agent container" --result "DONE" --color GREEN

    # Remove Portainer Container
    result_remove="$(docker rm -f portainer)"
    if [[ -z ${result_remove} ]]; then
        display --indent 6 --text "- Deleting Portainer Agent container" --result "FAIL" --color RED
        log_event "error" "Deleting Portainer Agent container." "true"
        return 1
    fi

    # Remove Portainer Data
    rm --recursive "${PROJECTS_PATH}/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN:?}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && ${PACKAGES_PORTAINER_AGENT_STATUS} == "enabled" ]]; then

        PACKAGES_PORTAINER_AGENT_STATUS="disabled"

        json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.portainer_agent[].status" "${PACKAGES_PORTAINER_AGENT_STATUS}"

        # new global value ("disabled")
        export PACKAGES_PORTAINER_AGENT_STATUS

        return 0

    else

        return 1

    fi

}

################################################################################
# Configure Portainer Agent service
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function portainer_agent_configure() {

    log_event "info" "Configuring Portainer Agent ..." "false"

    # Check if firewall is enabled
    if [[ "$(ufw status | grep -c "Status: active")" -eq "1" ]]; then
        firewall_allow "${PACKAGES_PORTAINER_AGENT_CONFIG_PORT}"
    fi

    # Log
    display --indent 6 --text "- Portainer Agent configuration" --result "DONE" --color GREEN
    log_event "info" "Portainer Agent configured" "false"

}
