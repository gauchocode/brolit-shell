#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.3
################################################################################
#
# Mailcow Installer
#
################################################################################

################################################################################
# Mailcow install
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function mailcow_installer() {

    local mailcow
    #local mailcow_config_output

    log_subsection "Mailcow Installer"

    package_update

    package_install_if_not "docker.io"
    package_install_if_not "docker-compose"

    # Check if mailcow is running
    mailcow="$(docker_get_container_id "mailcow")"

    if [[ -z ${mailcow} ]]; then

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Create project directory
            mkdir -p "${PROJECTS_PATH}/${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN}"

            # Clone repo in to project directory
            git clone https://github.com/mailcow/mailcow-dockerized "${PROJECTS_PATH}/${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN}"

            # Configure Mailcow
            ./"${PROJECTS_PATH}/${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN}"/generate_config.sh

            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then

                # Run docker-compose pull on specific directory
                docker-compose -f "${PROJECTS_PATH}/${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN}/docker-compose.yml" pull

                # Run docker-compose up -d on specific directory
                docker-compose -f "${PROJECTS_PATH}/${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN}/docker-compose.yml" up -d

                log_event "info" "You can now access https://${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN} with the default credentials: admin + password moohoo." "true"

                return 0

            fi

        else

            return 1

        fi

    else
        log_event "warning" "Mailcow is already installed" "false"

    fi

}

################################################################################
# Mailcow purge/remove
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function mailcow_purge() {

    local docker_compose_file="${PROJECTS_PATH}/${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN}/docker-compose.yml"

    log_subsection "Mailcow Installer"

    # Get Mailcow container ID
    #container_id="$(docker ps | grep mailcow | awk '{print $1;}')"

    # Stop Mailcow container
    #docker stop "${container_id}"

    # Remove Mailcow container
    #docker rm -f mailcow

    # Stop Mailcow containers
    docker-compose -f "${docker_compose_file}" stop

    # Remove Mailcow container
    docker-compose -f "${docker_compose_file}" rm

    # Remove Mailcow Volume
    #volume rm mailcow_data

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        PACKAGES_MAILCOW_STATUS="disabled"

        #json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.mailcow[].status" "${PACKAGES_MAILCOW_STATUS}"

        # new global value ("disabled")
        export PACKAGES_MAILCOW_STATUS

        return 0

    else

        return 1

    fi

}

################################################################################
# Configure Mailcow service
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function mailcow_configure() {

    log_event "info" "Configuring mailcow ..." "false"

    # Check if firewall is enabled
    #if [ "$(ufw status | grep -c "Status: active")" -eq "1" ]; then
    # TODO: check ports: https://mailcow.github.io/mailcow-dockerized-docs/prerequisite/prerequisite-system/#default-ports
    #    firewall_allow "${PACKAGES_MAILCOW_CONFIG_PORT}"
    #fi

    #if [[ ${PACKAGES_NGINX_STATUS} == "enabled" ]]; then
    #    nginx_server_create "${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN}" "mailcow" "single" "" "${PACKAGES_MAILCOW_CONFIG_PORT}"
    #    # Replace port on nginx server config
    #    sed -i "s/PORTAINER_PORT/${PACKAGES_MAILCOW_CONFIG_PORT}/g" "${WSERVER}/sites-available/${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN}"
    #fi

    if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

        local root_domain

        root_domain="$(domain_get_root "${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN}")"

        cloudflare_set_record "${root_domain}" "${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN}" "A" "false" "${SERVER_IP}"

    fi

    # TODO: if Cloudflare update OK, then run certbot

    # Log
    display --indent 6 --text "- Mailcow configuration" --result "DONE" --color GREEN
    log_event "info" "Mailcow configured" "false"

}
