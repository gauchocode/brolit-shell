#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.6
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

    log_subsection "Portainer Agent Installer"

    package_update

    # Check if docker package are installed
    docker="$(package_is_installed "docker-ce")"
    docker_installed="$?"
    if [[ ${docker_installed} -eq 1 ]]; then
        docker_installer
    fi

    # Force update brolit_conf.json
    PACKAGES_DOCKER_STATUS="enabled"
    json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.docker[].status" "${PACKAGES_DOCKER_STATUS}"
    export PACKAGES_DOCKER_STATUS

    # Check if portainer_agent is running
    portainer_agent="$(docker_get_container_id "agent_portainer")"

    if [[ -z ${portainer_agent} ]]; then                                               0

        # Create project directory
        mkdir -p "${PORTAINER_AGENT_PATH}"

        # Copy docker-compose.yml and .env files to project directory
        cp "${BROLIT_MAIN_DIR}/utils/installers/docker-compose/portainer_agent/docker-compose.yml" "${PORTAINER_AGENT_PATH}"
        cp "${BROLIT_MAIN_DIR}/utils/installers/docker-compose/portainer_agent/.env" "${PORTAINER_AGENT_PATH}"

        # Configure .env file
        project_set_config_var "${PORTAINER_AGENT_PATH}/.env" "PORTAINER_AGENT_PORT" "${PACKAGES_PORTAINER_AGENT_CONFIG_PORT}" "none"

        # Enable port in firewall
        firewall_allow "${PACKAGES_PORTAINER_AGENT_CONFIG_PORT}"

        # Run docker-compose
        docker_compose_pull "${PORTAINER_AGENT_PATH}/docker-compose.yml"
        docker_compose_up "${PORTAINER_AGENT_PATH}/docker-compose.yml"

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
    rm --recursive "${PORTAINER_AGENT_PATH}"

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
