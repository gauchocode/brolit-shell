#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.3
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

        # Check if firewall is enabled
        if [ "$(ufw status | grep -c "Status: active")" -eq "1" ]; then
            ufw allow 3000
        fi

        # Start grafana server service
        sudo /bin/systemctl start grafana-server

        PACKAGES_GRAFANA_CONFIG_STATUS="enabled"

        json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.grafana[].status" "${PACKAGES_GRAFANA_CONFIG_STATUS}"

        # new global value ("enabled")
        export PACKAGES_GRAFANA_CONFIG_STATUS

        return 0

    else

        return 1

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

    if [[ $? -eq 0 ]]; then

        PACKAGES_GRAFANA_CONFIG_STATUS="disabled"

        json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.grafana[].status" "${PACKAGES_GRAFANA_CONFIG_STATUS}"

        # new global value ("disabled")
        export PACKAGES_GRAFANA_CONFIG_STATUS

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

    # Service restart
    systemctl restart grafana

    # Log
    display --indent 6 --text "- Restarting services" --result "DONE" --color GREEN

    log_event "info" "Grafana configured" "false"
    display --indent 6 --text "- Grafana configuration" --result "DONE" --color GREEN

}

################################################################################
# Grafana installer menu
#
# Arguments:
#   none
#
# Outputs:
#   none
################################################################################

function grafana_installer_menu() {

    # TODO: Add a menu to reconfigure or uninstall if grafana is installed

    # Check if Grafana is installed
    GRAFANA="$(command -v grafana)"

    if [[ ! -x "${GRAFANA}" ]]; then

        grafana_installer
        #grafana_configure

    else

        while true; do

            echo -e "${YELLOW}${ITALIC} > Grafana is already installed. Do you want to reconfigure grafana?${ENDCOLOR}"
            read -p "Please type 'y' or 'n'" yn

            case $yn in

            [Yy]*)

                log_subsection "Grafana Configurator"

                grafana_configure

                break
                ;;

            [Nn]*)

                log_event "warning" "Aborting grafana configuration script ..." "false"

                break
                ;;

            *) echo " > Please answer yes or no." ;;

            esac

        done

        # Called twice to remove last messages
        clear_previous_lines "2"

    fi

}
