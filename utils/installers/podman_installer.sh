#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.11
################################################################################
#
# Podman Installer
#
#   Refs:
#       https://podman.io/getting-started/installation
#
################################################################################

################################################################################
# Podman installer
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function podman_installer() {

    local podman_bin

    # Skip if container engine is not podman
    if [[ "${CONTAINER_ENGINE}" != "podman" ]]; then
        log_event "info" "Skipping podman installation, using docker" "false"
        return 0
    fi

    podman_bin="$(package_is_installed "podman")"

    exitstatus=$?
    if [ ${exitstatus} -eq 0 ]; then

        log_event "info" "Podman is already installed" "false"
        log_event "debug" "Podman binary: ${podman_bin}" "false"

        return 1

    else

        log_subsection "Podman Installer"

        # Install dependencies
        package_install_if_not "podman"
        package_install_if_not "podman-compose"
        package_install_if_not "container-selinux"

    fi

}

################################################################################
# Podman purge
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function podman_purge() {

    # Remove podman and dependencies
    for pkg in podman podman-compose container-selinux; do
        package_purge ${pkg}
    done

    # Remove old podman files
    rm -rf /var/lib/containers /etc/containers

}

################################################################################
# Check podman installed version
#
# Arguments:
#  none
#
# Outputs:
#  podman version
################################################################################

function podman_check_installed_version() {

    podman --version

}

################################################################################
# Private: Install Official Podman Repo
#
# Arguments:
#  none
#
# Outputs:
#  podman version
################################################################################

function _podman_add_official_repo() {

    # Update the package database
    apt-get update -qq >/dev/null

    # Log
    log_event "info" "Podman official repo added" "false"
    display --indent 6 --text "- Adding Podman official repo" --result "DONE" --color GREEN

}
