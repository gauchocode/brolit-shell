#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.5
################################################################################
#
# Dtop Installer
#
#   Refs:
#       https://github.com/amir20/dtop
#
################################################################################

################################################################################
# Check if dtop is installed
#
# Arguments:
#   none
#
# Outputs:
#   0 if dtop is installed, 1 on error.
################################################################################

function dtop_check_if_installed() {

    if command -v dtop >/dev/null 2>&1; then
        log_event "debug" "dtop is installed" "false"
        echo "true"
    else
        log_event "debug" "dtop is not installed" "false"
        echo "false"
    fi

}

################################################################################
# Dtop installer
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function dtop_installer() {

    local dtop_installed

    dtop_installed="$(dtop_check_if_installed)"

    if [[ ${dtop_installed} == "true" ]]; then

        log_event "info" "dtop is already installed" "false"
        display --indent 6 --text "- dtop is already installed" --result "DONE" --color GREEN

        return 0

    else

        log_subsection "Dtop Installer"

        display --indent 6 --text "- Installing dtop"

        # Install dtop using the official installer
        if curl --proto '=https' --tlsv1.2 -LsSf https://github.com/amir20/dtop/releases/latest/download/dtop-installer.sh | sh >/dev/null 2>&1; then

            # Log
            clear_previous_lines "1"
            display --indent 6 --text "- Installing dtop" --result "DONE" --color GREEN
            log_event "info" "dtop installed successfully" "false"

            return 0

        else

            # Log
            clear_previous_lines "1"
            display --indent 6 --text "- Installing dtop" --result "FAILED" --color RED
            display --indent 8 --text "Read the log file for more information" --tcolor RED
            log_event "error" "Failed to install dtop" "false"

            return 1

        fi

    fi

}

################################################################################
# Dtop purge
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function dtop_purge() {

    log_subsection "Dtop Uninstaller"

    display --indent 6 --text "- Uninstalling dtop"

    local _home="${HOME:-}"
    local _binary_removed=false

    # Remove dtop binary from default install location
    if [[ -n "$_home" && -f "$_home/.local/bin/dtop" ]]; then
        rm -f "$_home/.local/bin/dtop" && _binary_removed=true
    fi

    # Remove dtop binary from /usr/local/bin (if installed there)
    if [[ -f "/usr/local/bin/dtop" ]]; then
        rm -f /usr/local/bin/dtop && _binary_removed=true
    fi

    # Remove dtop binary from cargo bin (legacy install method)
    if [[ -n "$_home" && -f "$_home/.cargo/bin/dtop" ]]; then
        rm -f "$_home/.cargo/bin/dtop" && _binary_removed=true
    fi

    # Remove env script
    if [[ -n "$_home" && -f "$_home/.local/bin/env" ]]; then
        rm -f "$_home/.local/bin/env"
    fi

    # Remove receipt directory
    if [[ -n "$_home" && -d "$_home/.config/dtop" ]]; then
        rm -rf "$_home/.config/dtop"
    fi

    # Remove PATH modifications from rc files
    if [[ -n "$_home" ]]; then
        local _env_script_expr='".local/bin/env"'
        local _robust_line=". \"$_home/$_env_script_expr\""
        local _pretty_line="source \"$_home/$_env_script_expr\""

        for _rcfile in "$_home/.profile" "$_home/.bashrc" "$_home/.bash_profile" "$_home/.bash_login" "$_home/.zshrc" "$_home/.zshenv"; do
            if [[ -f "$_rcfile" ]]; then
                # Remove both robust and pretty line variants
                grep -vF "$_robust_line" "$_rcfile" > "${_rcfile}.tmp" 2>/dev/null && mv "${_rcfile}.tmp" "$_rcfile"
                grep -vF "$_pretty_line" "$_rcfile" > "${_rcfile}.tmp" 2>/dev/null && mv "${_rcfile}.tmp" "$_rcfile"
            fi
        done

        # Remove fish config
        local _fish_env_script="$_home/.local/bin/env.fish"
        if [[ -f "$_home/.config/fish/conf.d/dtop.env.fish" ]]; then
            rm -f "$_home/.config/fish/conf.d/dtop.env.fish"
        fi
    fi

    # Log
    clear_previous_lines "1"

    if [[ "$_binary_removed" == "true" ]]; then
        display --indent 6 --text "- Uninstalling dtop" --result "DONE" --color GREEN
        log_event "info" "dtop uninstalled successfully" "false"
    else
        display --indent 6 --text "- Uninstalling dtop" --result "WARNING" --color YELLOW
        display --indent 8 --text "dtop binary not found (already removed?)" --tcolor YELLOW
        log_event "warning" "dtop binary not found for removal" "false"
    fi

    return 0

}

################################################################################
# Dtop installer menu
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function dtop_installer_menu() {

    local dtop_installed
    local dtop_installer_title
    local dtop_installer_message
    local dtop_installer_options
    local chosen_dtop_installer_options

    dtop_installed="$(dtop_check_if_installed)"

    if [[ ${dtop_installed} == "false" ]]; then

        dtop_installer_title="DTOP INSTALLER"
        dtop_installer_message="Choose an option to run:"
        dtop_installer_options=(
            "01)" "INSTALL DTOP"
        )

        chosen_dtop_installer_options="$(whiptail --title "${dtop_installer_title}" --menu "${dtop_installer_message}" 20 78 10 "${dtop_installer_options[@]}" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_dtop_installer_options} == *"01"* ]]; then
                dtop_installer
            fi

        fi

    else

        dtop_installer_title="DTOP INSTALLER"
        dtop_installer_message="Choose an option to run:"
        dtop_installer_options=(
            "01)" "UNINSTALL DTOP"
        )

        chosen_dtop_installer_options="$(whiptail --title "${dtop_installer_title}" --menu "${dtop_installer_message}" 20 78 10 "${dtop_installer_options[@]}" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_dtop_installer_options} == *"01"* ]]; then
                dtop_purge
            fi

        fi

    fi

}

################################################################################
# Check dtop installed version
#
# Arguments:
#  none
#
# Outputs:
#  dtop version
################################################################################

function dtop_check_installed_version() {

    if command -v dtop >/dev/null 2>&1; then
        dtop --version | awk '{ print $2 }'
    else
        echo "not installed"
    fi

}
