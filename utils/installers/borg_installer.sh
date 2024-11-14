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
    local borg_installed
    local borg

    borg="$(command -v borg)"
    if [[ ! -x "${borg}" ]]; then
        borg_installed="false"
    else
        borg_installed="true"
    fi

    log_event "debug" "borg_installed=${borg_installed}" "false"Borgnatic

    # Return
    echo "${borg_installed}"
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

    # Installing borg
    display --indent 6 --text "- Installing borg and dependencies"

    package_install "borgbackup"
    package_install "pipx"
    borgmatic_installer

    install_ssh_key_on_storages

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
    local borg_is_installed

    borg_is_installed=$(borg_check_if_installed)

    if [[ ${borg_is_installed} == "false" ]]; then

        borg_installer_title="BORG INSTALLER"
        borg_installer_message="Choose an option to run:"
        borg_installer_options=(
            "01)" "INSTALL BORG"
        )

        chosen_certbot_installer_options="$(whiptail --title "${borg_installer_title}" --menu "${borg_installer_message}" 20 78 10 "${borg_installer_options[@]}" 3>&1 1>&2 2>&3)"
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

        chosen_certbot_installer_options="$(whiptail --title "${borg_installer_title}" --menu "${borg_installer_message}" 20 78 10 "${borg_installer_options[@]}" 3>&1 1>&2 2>&3)"
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

    display --indent 6 --text "- Updating repositories"

    sudo apt install python3-venv -y > /dev/null 2>&1

    wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq > /dev/null 2>&1

    # Update repositories
    sudo pipx install borgmatic > /dev/null 2>&1

    if [[ $exitstatus -eq 0 ]]; then

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

##############################################################################
# Install SSH public key on storage box using configuration from .brolit_conf.json
#
# Arguments:
#   none
#
# Outputs:
#   0 if the key is installed successfully, 1 on error.
##############################################################################

function install_ssh_key_on_storages() {
    local config_file="/root/.brolit_conf.json"
    local ssh_key_path="~/.ssh/id_rsa.pub"

    if [[ ! -f ~/.ssh/id_rsa ]]; then
        log_event "warning" "RSA key pair not found. Please generate one using ssh-keygen." "true"
        display --indent 6 --text "- RSA key check" --result "MISSING" --color RED
        return 1
    else
        display --indent 6 --text "- RSA key check" --result "EXISTS" --color GREEN
    fi

    if [[ -f "${config_file}" ]]; then
        storages=$(jq -r '.storages[] | @base64' "${config_file}")

        for storage in ${storages}; do
            _jq() {
                echo "${storage}" | base64 --decode | jq -r "${1}"
            }

            local ssh_user=$(_jq '.user')
            local ssh_host=$(_jq '.host')
            local ssh_port=$(_jq '.port')

            cat "${ssh_key_path}" | ssh -p"${ssh_port}" "${ssh_user}@${ssh_host}" install-ssh-key
            local exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then
                log_event "info" "RSA public key installed on ${ssh_host}" "false"
                display --indent 6 --text "- Installing public key on ${ssh_host}" --result "DONE" --color GREEN
            else
                log_event "error" "Failed to install RSA public key on ${ssh_host}" "true"
                display --indent 6 --text "- Installing public key on ${ssh_host}" --result "FAILED" --color RED
            fi
        done
    else
        log_event "error" "Configuration file ${config_file} not found" "true"
        display --indent 6 --text "- Loading configuration file" --result "FAILED" --color RED
        return 1
    fi
}