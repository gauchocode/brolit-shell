#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc2
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

    log_subsection "Portainer Installer"

    package_update

    package_install_if_not "docker.io"
    package_install_if_not "docker-compose"

    # Check if portainer is running
    portainer="$(docker_get_container_id "portainer")"

    if [[ -z ${portainer} ]]; then

        project_domain="$(project_ask_domain)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            mkdir -p "${PROJECTS_PATH}/${project_domain}"

            cd "${PROJECTS_PATH}/${project_domain}"

            docker-compose pull

            docker-compose up -d

            nginx_server_create "${project_domain}" "single" "portainer" ""

            if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

                # Extract root domain
                root_domain="$(domain_get_root "${project_domain}")"

                cloudflare_set_record "${root_domain}" "${project_domain}" "A" "false" "${SERVER_IP}"

            fi

            PACKAGES_PORTAINER_STATUS="enabled"

            json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.portainer[].status" "${PACKAGES_GRAFANA_STATUS}"

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

    log_event "info" "Configuring portainer ..."

    # Check if firewall is enabled
    if [ "$(ufw status | grep -c "Status: active")" -eq "1" ]; then
        firewall_allow "${PACKAGES_PORTAINER_CONFIG_PORT}"
    fi

    if [[ ${PACKAGES_NGINX_STATUS} == "enabled" ]]; then

        nginx_server_create "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}" "portainer" "single" ""

        # Replace port on nginx server config
        sed -i "s/PORTAINER_PORT/${PACKAGES_PORTAINER_CONFIG_PORT}/g" "${WSERVER}/sites-available/${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}"
    fi

    if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

        local root_domain

        root_domain="$(domain_get_root "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}")"

        cloudflare_set_record "${root_domain}" "${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN}" "A" "false" "${SERVER_IP}"

    fi

    # TODO: if Cloudflare update OK, then run certbot

    # Log
    display --indent 6 --text "- Portainer configuration" --result "DONE" --color GREEN
    log_event "info" "Portainer configured" "false"

}
