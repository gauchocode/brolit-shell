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
        # Only rely on pipx to detect borgmatic installation (no PATH/binary fallbacks)
        if command -v pipx >/dev/null 2>&1; then
            log_event "debug" "pipx detected for borg/borgmatic combined check" "false"
            if pipx list 2>/dev/null | grep -qi '\bborgmatic\b'; then
                log_event "debug" "pipx list reports borgmatic installed" "false"
                installed="true"
            else
                log_event "debug" "pipx list reports borgmatic NOT installed" "false"
            fi
        else
            log_event "debug" "pipx not found; treating borgmatic as NOT installed (combined check)" "false"
        fi
    fi

    log_event "debug" "borg_and_borgmatic_installed=${installed}" "false"
    echo "${installed}"
}

# Check only borgmatic installation status (robust to manual uninstalls)
function borgmatic_is_installed() {

    local installed="false"
    local borgmatic_bin=""

    if command -v pipx >/dev/null 2>&1 && pipx list 2>/dev/null | grep -qi '\bborgmatic\b'; then
        log_event "debug" "pipx list reports borgmatic installed" "false"
    else
        log_event "debug" "pipx not found or does not list borgmatic" "false"
    fi

    if command -v borgmatic >/dev/null 2>&1; then
        borgmatic_bin="borgmatic"
    elif [[ -x "/root/.local/bin/borgmatic" ]]; then
        borgmatic_bin="/root/.local/bin/borgmatic"
    fi

    # A binary being findable (via pipx's registry or PATH) isn't enough --
    # pipx can report an app as installed while its venv is corrupted (e.g. a
    # partial upgrade left site-packages without the borgmatic module
    # itself, `ModuleNotFoundError: No module named 'borgmatic'` on every
    # invocation). That silently breaks every backup on the host with
    # nothing ever detecting or repairing it, since this was the only check
    # anything used to decide "does borgmatic need installing". Only trust a
    # binary that actually runs.
    if [[ -n "${borgmatic_bin}" ]]; then
        if "${borgmatic_bin}" --version >/dev/null 2>&1; then
            log_event "debug" "borgmatic binary (${borgmatic_bin}) verified working" "false"
            installed="true"
        else
            log_event "warning" "borgmatic binary found (${borgmatic_bin}) but failed to run -- treating as NOT installed (broken venv)" "false"
        fi
    else
        log_event "debug" "borgmatic not found in PATH nor /root/.local/bin/borgmatic" "false"
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

    # yq: needed to generate borgmatic configs
    yq_installer || log_event "warning" "yq could not be installed; borgmatic config generation will fail" "false"

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
# Install yq (mikefarah, v4), required by the borgmatic config generation
# (`generate_borg_config` in cron/backups_tasks.sh) and the Borg storage
# controller. Pinned version, SHA-256 verified; idempotent.
#
# Arguments:
#   none
#
# Outputs:
#   0 if yq v4 is available, 1 on error.
##############################################################################

BROLIT_YQ_VERSION="v4.45.4"
BROLIT_YQ_SHA256_AMD64="b96de04645707e14a12f52c37e6266832e03c29e95b9b139cddcae7314466e69"
BROLIT_YQ_SHA256_ARM64="b25d814d8708d7df047874f65bb66e0ee946d53a1bcd9a513ea5d06a153777c1"

function yq_installer() {

    local arch
    local expected_sha
    local tmp_file

    # Already a mikefarah yq v4 (the python-yq wrapper is a different tool)
    if command -v yq >/dev/null 2>&1 && yq --version 2>&1 | grep -q "mikefarah.*version v\?4"; then
        log_event "debug" "yq v4 already installed" "false"
        return 0
    fi

    case "$(uname -m)" in
    x86_64) arch="amd64"; expected_sha="${BROLIT_YQ_SHA256_AMD64}" ;;
    aarch64 | arm64) arch="arm64"; expected_sha="${BROLIT_YQ_SHA256_ARM64}" ;;
    *)
        log_event "error" "yq: unsupported architecture $(uname -m)" "false"
        return 1
        ;;
    esac

    tmp_file="$(mktemp)"

    if ! curl -fsSL --retry 3 -o "${tmp_file}" "https://github.com/mikefarah/yq/releases/download/${BROLIT_YQ_VERSION}/yq_linux_${arch}"; then
        rm -f "${tmp_file}"
        log_event "error" "yq: download failed" "false"
        return 1
    fi

    if [[ "$(sha256sum "${tmp_file}" | awk '{print $1}')" != "${expected_sha}" ]]; then
        rm -f "${tmp_file}"
        log_event "error" "yq: checksum mismatch, refusing to install" "false"
        return 1
    fi

    install -m 0755 "${tmp_file}" /usr/local/bin/yq
    rm -f "${tmp_file}"

    log_event "info" "yq ${BROLIT_YQ_VERSION} installed" "false"
    return 0

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

        # Log
        display --indent 6 --text "- Borg detected, Borgmatic missing. Installing Borgmatic"
        log_event "info" "Borg detected, Borgmatic missing. Installing Borgmatic" "false"
        
        # Install dependencies
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

    # --force: this is only called when borgmatic_is_installed() already
    # found no *working* binary. Without --force, `pipx install` on an app
    # pipx still has registered (even with a corrupted venv) just prints
    # "already seems to be installed" and does nothing -- leaving a broken
    # install broken. --force always gives a fresh venv.
    if sudo pipx install borgmatic --force > /dev/null 2>&1; then

        # Log
        clear_previous_lines "1"
        log_event "info" "Borgmatic installed" "false"
        display --indent 6 --text "- Installing borgmatic" --result "DONE" --color GREEN

        # Ensure pipx binaries are in PATH
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
