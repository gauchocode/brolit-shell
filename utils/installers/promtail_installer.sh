#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.6
#############################################################################

################################################################################
# Check if Promtail is installed
#
# Arguments:
#
# Outputs:
#   nothing
################################################################################

function promtail_check_if_installed() {

    # Check if promtail is installed (could be installed but not running)
    if [[ -f "/opt/promtail/promtail-linux-amd64" ]] && [[ -f "/opt/promtail/config-promtail.yml" ]]; then

        log_event "debug" "Promtail is already installed" "false"

        return 0

    else

        log_event "debug" "Promtail is not installed" "false"

        return 1

    fi

}

################################################################################
# Install Promtail
#
# Arguments:
#
# Outputs:
#   nothing
################################################################################

function promtail_installer() {

    # If promtail is already installed, then exit
    promtail_check_if_installed
    [[ $? -eq 0 ]] && return 1

    log_subsection "Promtail Installer"

    # Add the Loki repository
    curl -O -L "https://github.com/grafana/loki/releases/download/v${PACKAGES_PROMTAIL_VERSION}/promtail-linux-amd64.zip"

    # Install the Promtail package
    ### Create directory
    mkdir -p /opt/promtail

    ### Unzip force (expanded flags)
    decompress "promtail-linux-amd64.zip" "/opt/promtail" ""

    ### Remove zip file
    rm -f "promtail-linux-amd64.zip"

    ### Set permissions
    chmod a+x /opt/promtail/promtail-linux-amd64

    # Create the Promtail configuration file
    promtail_create_configuration_file

    # Create the Promtail service file
    promtail_create_service

    # Confirm directory ownership
    chown -R promtail:promtail /opt/promtail

    # Start the Promtail service
    systemctl start promtail.service

    display --indent 6 --text "- Promtail installation" --result "DONE" --color GREEN

    return 0

}

################################################################################
# Create the Promtail configuration file
#
# Arguments:
#
# Outputs:
#   nothing
################################################################################

function promtail_create_configuration_file() {

    # Promtail configuration file
    local promtail_config_file="/opt/promtail/config-promtail.yml"

    # Copy the Promtail configuration file
    cp "${BROLIT_MAIN_DIR}/config/promtail/config-promtail.yml" "${promtail_config_file}"

    # Replace VARIABLES in the Promtail configuration file
    ## PROMTAIL_PORT
    sed -i "s/PROMTAIL_PORT/${PACKAGES_PROMTAIL_CONFIG_PORT}/g" "${promtail_config_file}"

    ## LOKI_URL
    sed -i "s/LOKI_HOST_URL/${PACKAGES_PROMTAIL_CONFIG_LOKI_URL}/g" "${promtail_config_file}"

    ## LOKI_PORT
    sed -i "s/LOKI_HOST_PORT/${PACKAGES_PROMTAIL_CONFIG_LOKI_PORT}/g" "${promtail_config_file}"

    ## HOSTNAME
    ### if $HOSTNAME == default, then use actual HOSTNAME
    if [[ "${HOSTNAME}" == "default" ]]; then
        sed -i "s/HOSTNAME/${HOSTNAME}/g" "${promtail_config_file}"
    else
        sed -i "s/HOSTNAME/${PACKAGES_PROMTAIL_CONFIG_HOSTNAME}/g" "${promtail_config_file}"
    fi

    display --indent 6 --text "- Promtail configuration file" --result "DONE" --color GREEN

}

################################################################################
# Create the Promtail service file
#
# Arguments:
#
# Outputs:
#   nothing
################################################################################

function promtail_create_service() {

    useradd --system promtail

    cp "${BROLIT_MAIN_DIR}/config/promtail/promtail.service" "/etc/systemd/system/promtail.service"

    # Reload systemctl
    systemctl daemon-reload

    # Enable the Promtail service
    systemctl enable promtail.service

}

################################################################################
# Delete the Promtail service file
#
# Arguments:
#
# Outputs:
#   nothing
################################################################################

function promtail_delete_service() {

    # Delete the Promtail service file
    rm -f "/etc/systemd/system/promtail.service"

    # Reload systemctl
    systemctl daemon-reload

}

################################################################################
# Purge Promtail
#
# Arguments:
#
# Outputs:
#   nothing
################################################################################

function promtail_purge() {

    log_subsection "Promtail Purge"

    promtail_check_if_installed
    if [[ $? -eq 1 ]]; then

        log_event "info" "Promtail is not installed" "false"
        return 1

    else

        # Stop the Promtail service
        systemctl stop promtail.service

        # Remove the Promtail service
        promtail_delete_service

        # Remove the Promtail directory
        rm -rf /opt/promtail

        # Log
        display --indent 6 --text "- Promtail purge" --result "DONE" --color GREEN
        log_event "info" "Promtail uninstalled" "false"

        return 0

    fi

}
