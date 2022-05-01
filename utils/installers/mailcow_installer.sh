#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc3
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

            if [[ ${PACKAGES_PORTAINER_CONFIG_NGINX} == "enabled" ]]; then

                nginx_server_create "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}" "portainer" "single" "" "${PACKAGES_PORTAINER_CONFIG_PORT}"

                if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

                    # Extract root domain
                    root_domain="$(domain_get_root "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}")"

                    cloudflare_set_record "${root_domain}" "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}" "A" "false" "${SERVER_IP}"

                fi

            fi

            PACKAGES_MAILCOW_STATUS="enabled"

            json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.portainer[].status" "${PACKAGES_MAILCOW_STATUS}"

            # new global value ("enabled")
            export PACKAGES_MAILCOW_STATUS

            return 0

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

    log_subsection "Mailcow Installer"

    # Get Mailcow Container ID
    container_id="$(docker ps | grep mailcow | awk '{print $1;}')"

    # Stop Mailcow Container
    docker stop "${container_id}"

    # Remove Mailcow Container
    docker rm -f mailcow

    # Remove Mailcow Volume
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
    if [ "$(ufw status | grep -c "Status: active")" -eq "1" ]; then
        firewall_allow "${PACKAGES_MAILCOW_CONFIG_PORT}"
    fi

    if [[ ${PACKAGES_NGINX_STATUS} == "enabled" ]]; then

        nginx_server_create "${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN}" "mailcow" "single" "" "${PACKAGES_MAILCOW_CONFIG_PORT}"

        # Replace port on nginx server config
        sed -i "s/PORTAINER_PORT/${PACKAGES_MAILCOW_CONFIG_PORT}/g" "${WSERVER}/sites-available/${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN}"
    fi

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
