#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.35
#############################################################################

function cockpit_installer() {

    log_subsection "Cockpit Installer"

    # Log
    log_event "info" "Installing cockpit" "false"
    display --indent 2 --text "- Installing cockpit"

    # apt command
    apt-get --yes update -qq > /dev/null
    apt-get --yes install cockpit cockpit-docker cockpit-networkmanager cockpit-storaged cockpit-system cockpit-packagekit cockpit-shell -qq > /dev/null

    # Firewall config
    ufw allow 9090

    # Log
    log_event "info" "Cockpit must be running on port 9090" "false"
    clear_last_line
    display --indent 2 --text "- Installing cockpit" --result "DONE" --color GREEN
    display --indent 4 --text "Running on port 9090"

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
