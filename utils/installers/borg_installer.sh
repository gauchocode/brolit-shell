#!/usr/bin/env bash
#
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
################################################################################
#
# Borg installer: borg installer functions
#
################################################################################

################################################################################
# Chech if borg is installer
#
# Arguments:
#   none
#
# Outputs:
#   0 if borg was installed, 1 on error.
################################################################################

function borg_check_if_installed() {
    local installed="false"

    if command -v borg >/dev/null 2>&1; then
        # Prefer pipx status to detect borgmatic installation; fallback to PATH or known location
        if command -v pipx >/dev/null 2>&1; then
            if pipx list 2>/dev/null | grep -qi '\bborgmatic\b'; then
                installed="true"
            fi
        fi

        if [[ "${installed}" == "false" ]]; then
            if command -v borgmatic >/dev/null 2>&1 || [[ -x "/root/.local/bin/borgmatic" ]]; then
                installed="true"
            fi
        fi
    fi

    log_event "debug" "borg_and_borgmatic_installed=${installed}" "false"
    echo "${installed}"
}

# Check only borgmatic installation status (robust to manual uninstalls)
function borgmatic_is_installed() {
    local installed="false"

    if command -v pipx >/dev/null 2>&1; then
        if pipx list 2>/dev/null | grep -qi '\bborgmatic\b'; then
            installed="true"
        fi
    fi

    if [[ "${installed}" == "false" ]]; then
        if command -v borgmatic >/dev/null 2>&1 || [[ -x "/root/.local/bin/borgmatic" ]]; then
            installed="true"
        fi
    fi

    log_event "debug" "borgmatic_installed=${installed}" "false"
    echo "${installed}"
}

#############################################################################
# Borg installer.
#
# Arguments:
#   none
#
# Outputs:
#   0 if borg was installed, 1 on error.
#############################################################################

function borg_installer() {

    log_subsection "Borg Installer"

    display --indent 6 --text "- Updating repositories"

    # Update repositories
    package_update

    clear_previous_lines "1"
    display --indent 6 --text "- Updating repositories" --result "DONE" --color GREEN

    # Installing dependencies
    display --indent 6 --text "- Installing borg and dependencies"

    package_install "borgbackup"
    package_install "pipx"
    package_install "python3-venv"

    # Installing borgmatic
    borgmatic_installer

    exitstatus=$?

    if [[ ${exitstatus} -ne 0 ]]; then

        # Log
        clear_previous_lines "2"
        display --indent 6 --text "- Installing borg and dependencies" --result "FAILED" --color RED
        log_event "error" "Installing borg and dependencies" "false"

        return 1
    else
        # Log
        clear_previous_lines "2"
        display --indent 6 --text "- Installing borg and dependencies" --result "DONE" --color GREEN
        log_event "info" "Installing borg and dependencies" "false"

        return 0
    fi

}

##############################################################################
# Uninstall Borg.
#
# Arguments:
#   none
#
# Outputs:
#   0 if borg was uninstalled, 1 on error.
##############################################################################

function borg_purge() {

    log_subsection "Borg Uninstaller"

    package_purge "borgbackup"

    sudo pipx uninstall borgmatic
    
    clear_previous_lines "1"
    
    package_purge "pipx"

    return $?
}

##############################################################################
# Borg installer menu.
#
# Arguments:
#   none
#
# Outputs:
#   0 if borg was installed, 1 on error.
##############################################################################

function borg_installer_menu() {
    
    local both_installed
    #local only_borg_installed="false"

    both_installed=$(borg_check_if_installed)

    # Auto-install borgmatic if borg is present but borgmatic is missing
    if command -v borg >/dev/null 2>&1 && [[ "$(borgmatic_is_installed)" == "false" ]]; then
        display --indent 6 --text "- Borg detected, Borgmatic missing. Installing Borgmatic"
        package_install "pipx"
        package_install "python3-venv"
        borgmatic_installer
        return $?
    fi

    if [[ ${both_installed} == "false" ]]; then

        borg_installer_title="BORG INSTALLER"
        borg_installer_message="Choose an option to run:"
        borg_installer_options=(
            "01)" "INSTALL BORG"
        )

        chosen_borg_installer_options="$(whiptail --title "${borg_installer_title}" --menu "${borg_installer_message}" 20 78 10 "${borg_installer_options[@]}" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_borg_installer_options} == *"01"* ]]; then

                borg_installer
            fi

        fi
    
    else
        borg_installer_title="BORG INSTALLER"
        borg_installer_message="Choose an option to run:"
        borg_installer_options=(
            "01)" "UNINSTALL BORG"
        )

        chosen_borg_installer_options="$(whiptail --title "${borg_installer_title}" --menu "${borg_installer_message}" 20 78 10 "${borg_installer_options[@]}" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_borg_installer_options} == *"01"* ]]; then

                borg_purge
            
            fi

        fi

    fi
}

##############################################################################
# Install borgmatic.
#
# Arguments:
#   none
#
# Outputs:
#   0 if borg was installed, 1 on error.
##############################################################################

function borgmatic_installer() {

    display --indent 6 --text "- Installing borgmatic"

    # Install borgmatic
    if sudo pipx install borgmatic > /dev/null 2>&1; then

        # Log
        clear_previous_lines "1"
        log_event "info" "Borgmatic installed" "false"
        display --indent 6 --text "- Installing borgmatic" --result "DONE" --color GREEN
        pipx ensurepath >/dev/null
        return 0
    
    else

        # Log   
        clear_previous_lines "1"
        log_event "info" "Borgmatic not installed" "false"
        display --indent 6 --text "- Installing borgmatic" --result "FAILED" --color RED
        display --indent 8 --text "Read the log file for more information" --tcolor RED
        log_event "error" "Borgmatic not installed" "false"

        return 1
    
    fi
}
