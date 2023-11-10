#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.5
################################################################################
#
# Docker Installer
#
#   Refs:
#       https://docs.docker.com/engine/install/ubuntu/
#
################################################################################

################################################################################
# Docker installer
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function docker_installer() {

    local docker_bin

    docker_bin="$(package_is_installed "docker-ce")"

    exitstatus=$?
    if [ ${exitstatus} -eq 0 ]; then

        log_event "info" "Docker is already installed" "false"
        log_event "debug" "Docker binary: ${docker_bin}" "false"

        return 1

    else

        log_subsection "Docker Installer"

        # Add official repo
        _docker_add_official_repo

        # Install dependencies
        package_install_if_not "docker-ce"
        package_install_if_not "docker-ce-cli"
        package_install_if_not "containerd.io"
        package_install_if_not "docker-buildx-plugin"
        package_install_if_not "docker-compose-plugin"

    fi

}

################################################################################
# Docker purge
#
# Arguments:
#  none
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function docker_purge() {

    # Remove docker and dependencies
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        sudo apt-get remove ${pkg}
    done

}

################################################################################
# Check docker installed version
#
# Arguments:
#  none
#
# Outputs:
#  docker version
################################################################################

function docker_check_installed_version() {

    docker --version | awk '{ print $5 }' | awk -F\, '{ print $1 }'

}

################################################################################
# Private: Install Official Docker Repo
#
# Arguments:
#  none
#
# Outputs:
#  docker version
################################################################################

function _docker_add_official_repo() {

    # Install dependencies
    package_install_if_not "ca-certificates"
    package_install_if_not "curl"
    package_install_if_not "gnupg"

    # Add Docker's official GPG key:
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add the repository to Apt sources:
    echo \
        "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" |
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    
    # Update the package database
    apt-get update -qq >/dev/null

}
