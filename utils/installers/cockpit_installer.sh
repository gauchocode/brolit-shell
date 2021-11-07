#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.71
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

    package_is_installed "cockpit"

    exitstatus=$?
    if [ ${exitstatus} -eq 0 ]; then

        log_info "info" "Cockpit is already installed" "false"

        return 0

    else

        log_subsection "Cockpit Installer"

        # Package update
        package_update

        # Install cockpit
        package_install "cockpit"

        # Install cockpit extensions
        package_install "cockpit-docker"
        package_install "cockpit-networkmanager"
        package_install "cockpit-storaged"
        package_install "cockpit-packagekit"
        package_install "cockpit-shell"
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
    log_event "info" "Removing cockpit and libraries ..."

    # apt command
    apt-get --yes purge cockpit cockpit-docker cockpit-networkmanager cockpit-storaged cockpit-system cockpit-packagekit cockpit-shell -qq >/dev/null

    # Log
    clear_last_line
    display --indent 6 --text "- Removing cockpit and libraries" --result "DONE" --color GREEN
    log_event "info" "cockpit removed"

}

function cockpit_installer_menu() {

    local cockpit_is_installed

    cockpit_is_installed="$(cockpit_check_if_installed)"

    if [[ ${cockpit_is_installed} == "false" ]]; then

        cockpit_installer_title="COCKPIT INSTALLER"
        cockpit_installer_message="Choose an option to run:"
        cockpit_installer_options=(
            "01)" "INSTALL COCKPIT"
        )

        chosen_cockpit_installer_options="$(whiptail --title "${cockpit_installer_title}" --menu "${cockpit_installer_message}" 20 78 10 "${cockpit_installer_options[@]}" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_cockpit_installer_options} == *"01"* ]]; then

                cockpit_installer

            fi

        fi

    else

        cockpit_installer_title="COCKPIT INSTALLER"
        cockpit_installer_message="Choose an option to run:"
        cockpit_installer_options=(
            "01)" "UNINSTALL COCKPIT"
        )

        chosen_cockpit_installer_options="$(whiptail --title "${cockpit_installer_title}" --menu "${cockpit_installer_message}" 20 78 10 "${cockpit_installer_options[@]}" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_cockpit_installer_options} == *"01"* ]]; then

                cockpit_purge

            fi

        fi

    fi

}
