#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc3
#############################################################################
#
# Cockpit Installer
#
#   Refs:
#       https://www.linuxtechi.com/how-to-install-cockpit-on-ubuntu-20-04/
#
################################################################################

################################################################################
# Cockpit installer
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function cockpit_installer() {

    local cockpit_bin

    cockpit_bin="$(package_is_installed "cockpit")"

    exitstatus=$?
    if [ ${exitstatus} -eq 0 ]; then

        log_event "info" "Cockpit is already installed" "false"

        return 0

    else

        log_subsection "Cockpit Installer"

        # Package update
        package_update

        # Install cockpit
        package_install "cockpit"

        # Install cockpit extensions
        package_install "cockpit-dashboard"
        package_install "cockpit-bridge"
        package_install "cockpit-networkmanager"
        package_install "cockpit-storaged"
        package_install "cockpit-packagekit"
        package_install "cockpit-system"

        # Firewall config
        firewall_allow "9090"

        # Log
        log_event "info" "Cockpit should be running on port 9090" "false"
        display --indent 4 --text "Running on port 9090" --tcolor YELLOW

    fi

}

function cockpit_purge() {

    log_subsection "Cockpit Installer"

    # Log
    display --indent 6 --text "- Removing cockpit and libraries"
    log_event "info" "Removing cockpit and libraries ..." "false"

    # apt command
    package_purge "cockpit-dashboard"
    package_purge "cockpit-bridge"
    package_purge "cockpit-networkmanager"
    package_purge "cockpit-storaged"
    package_purge "cockpit-packagekit"
    package_purge "cockpit-system"

    package_purge "cockpit"

    # Log
    clear_previous_lines "1"

}
