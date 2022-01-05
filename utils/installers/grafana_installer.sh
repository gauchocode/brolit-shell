#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.7
################################################################################
#
# Grafana Installer
#
#   Ref: https://grafana.com/docs/grafana/latest/installation/debian/
#
################################################################################

################################################################################
# Grafana package install
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function grafana_installer() {

    log_subsection "Grafana Installer"

    # Check if Grafana repository is already installed
    if [[ -z "$(grep "grafana" /etc/apt/sources.list)" ]]; then

        # Add Grafana repository
        apt-get install -y -qq apt-transport-https
        apt-get install -y -qq software-properties-common wget
        wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -

        echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

        clear_previous_lines "2"

        package_update

        package_install_if_not "grafana"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            PACKAGES_GRAFANA_STATUS="enabled"

            json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.grafana[].status" "${PACKAGES_GRAFANA_STATUS}"

            # new global value ("enabled")
            export PACKAGES_GRAFANA_STATUS

            return 0

        else

            return 1

        fi

    else
        log_event "warning" "Grafana repository is already installed" "false"
    fi

}

################################################################################
# Grafana package purge
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function grafana_purge() {

    log_subsection "Grafana Installer"

    package_purge "grafana"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        PACKAGES_GRAFANA_STATUS="disabled"

        json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.grafana[].status" "${PACKAGES_GRAFANA_STATUS}"

        # new global value ("disabled")
        export PACKAGES_GRAFANA_STATUS

        return 0

    else

        return 1

    fi

}

################################################################################
# Configure Grafana service
#
# Arguments:
#   none
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function grafana_configure() {

    log_event "info" "Restarting services ..."

    # TODO: if is nginx installed, then create nginx server and proxy grafana

    # Check if firewall is enabled
    if [ "$(ufw status | grep -c "Status: active")" -eq "1" ]; then
        firewall_allow "3000"
    fi

    # Start grafana server service
    sudo /bin/systemctl start grafana-server

    # Log
    display --indent 6 --text "- Restarting services" --result "DONE" --color GREEN
    display --indent 6 --text "- Grafana configuration" --result "DONE" --color GREEN
    log_event "info" "Grafana configured" "false"

}
