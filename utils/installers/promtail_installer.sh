#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.2
#############################################################################

function promtail_installer() {

    log_subsection "Monit Installer"

    promtail_bin="$(package_is_installed "promtail")"

    exitstatus=$?
    if [ ${exitstatus} -eq 0 ]; then
        log_event "info" "Promtail is already installed" "false"
        return 1

    else

        log_subsection "Promtail Installer"

        # Add the Loki repository
        curl -s https://packagecloud.io/install/repositories/grafana/loki/script.deb.sh | sudo bash

        # Install the Promtail package
        apt-get --yes install promtail -qq >/dev/null

        # Create the Promtail configuration file
        promtail_create_configuration_file

        # Create the Promtail service file
        promtail_create_service

        # Start the Promtail service
        systemctl start promtail.service

        display --indent 6 --text "- Promtail installation" --result "DONE" --color GREEN

        return 0

    fi

}

function promtail_create_configuration_file() {

    # Copy the Promtail configuration file
    cp "${BROLIT_MAIN_DIR}/config/promtail/config-promtail.yml" "/opt/promtail/config-promtail.yml"

    # Replace VARIABLES in the Promtail configuration file
    ## PROMTAIL_PORT
    sed -i "s/PROMTAIL_PORT/${PACKAGES_PROMTAIL_CONFIG_PORT}/g" "/opt/promtail/config-promtail.yml"
    ## HOSTNAME
    sed -i "s/HOSTNAME/${HOSTNAME}/g" "/opt/promtail/config-promtail.yml"
    ## LOKI_URL
    sed -i "s/LOKI_HOST_URL/${PACKAGES_PROMTAIL_CONFIG_LOKI_URL}/g" "/opt/promtail/config-promtail.yml"
    ## LOKI_PORT
    sed -i "s/LOKI_HOST_PORT/${PACKAGES_PROMTAIL_CONFIG_LOKI_PORT}/g" "/opt/promtail/config-promtail.yml"

    display --indent 6 --text "- Promtail configuration file" --result "DONE" --color GREEN

}

function promtail_create_service() {

    useradd --system promtail

    cp "${BROLIT_MAIN_DIR}/config/promtail/promtail.service" "/etc/systemd/system/promtail.service"

    # Reload systemctl
    systemctl daemon-reload
    # Enable the Promtail service
    systemctl enable promtail.service

}

function promtail_check_if_installed() {

    PROMTAIL="$(which promtail)"
    if [[ ! -x "${PROMTAIL}" ]]; then
        promtail_installed="false"
    fi

}

function promtail_purge() {

    log_subsection "Promtail Purge"

    promtail_check_if_installed

    if [[ ${promtail_installed} == "false" ]]; then

        log_event "info" "Promtail is not installed" "false"
        return 1

    else

        # Stop the Promtail service
        systemctl stop promtail.service

        # Remove the Promtail service file
        rm -f "/etc/systemd/system/promtail.service"

        # Remove the Promtail package
        apt-get --yes purge promtail -qq >/dev/null

        display --indent 6 --text "- Promtail purge" --result "DONE" --color GREEN

        return 0

    fi

}