#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
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

    # Purging the engine stops every container. A server that has containers
    # running is using Docker whatever its configuration says, so never purge
    # it from here: an operator who really wants that sets the override.
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        local running
        running="$(docker ps -q 2>/dev/null | wc -l)"
        if [[ ${running} -gt 0 && "${BROLIT_ALLOW_DOCKER_PURGE:-false}" != "true" ]]; then
            log_event "error" "Refusing to purge Docker: ${running} container(s) are running. Set BROLIT_ALLOW_DOCKER_PURGE=true to override." "false"
            display --indent 6 --text "- Docker uninstall" --result "REFUSED" --color RED
            display --indent 8 --text "${running} container(s) running; Docker is left as it is" --tcolor YELLOW
            return 1
        fi
    fi

    log_subsection "Docker CE Uninstaller"

    # Remove docker and dependencies
    for pkg in docker docker-ce docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
        package_purge ${pkg}
    done

    # Remove old docker files
    #rm -rf /var/lib/docker /etc/docker /etc/apparmor.d/docker /etc/systemd/system/docker.service /etc/systemd/system/docker.socket /usr/lib/systemd/system/docker.service.d /usr/lib/systemd/system/docker.socket.d /usr/bin/docker /usr/bin/docker-containerd /usr/bin/docker-containerd-ctr /usr/bin/docker-containerd-shim /usr/bin/docker-runc /usr/bin/dockerd /usr/bin/docker-init /usr/bin/docker-proxy /usr/bin/docker-compose /usr/bin/docker-compose-v2 /usr/bin/docker-buildx /usr/bin/docker-buildx-v2 /usr/bin/docker-buildx-v2.0.0-beta.6 /usr/bin/docker-buildx-v2.0.0-beta.7 /usr/bin/docker-buildx-v2.0.0-rc.1 /usr/bin/docker-buildx-v2.0.0-rc.2 /usr/bin/docker-buildx-v2.0.0-rc.3 /usr/bin/docker-buildx-v2.0.0-rc.4 /usr/bin/docker-buildx-v2.0.0-rc.5 /usr/bin/docker-buildx-v2.0.0-rc.6 /usr/bin/docker-buildx-v2.0.0-rc.7 /usr/bin/docker-buildx-v2.0.0-rc.8 /usr/bin/docker-buildx-v2.0.0-rc.9 /usr/bin/docker-buildx-v2.0.0-rc.10 /usr/bin/docker-buildx-v2.0.0-rc.11 /usr/bin/docker-buildx-v2.0.0-rc.12 /usr/bin/docker-buildx-v2.0.0-rc.13 /usr/bin/docker-buildx-v2.0.0-rc.14 /usr/bin/docker-buildx-v2.0.0-rc.15 /usr/bin/docker-buildx-v2.0.0-rc.16 /usr/bin/docker-buildx-v2.0.0-rc.17 /usr/bin/docker-buildx-v2.0.0-rc.18 /usr/bin/docker-buildx-v2.0.0-rc.19 /usr/bin/docker-buildx-v2.0.0-rc.20 /usr/bin/docker-buildx-v2.0.0-rc.21 /usr/bin/docker-buildx-v2.0.
    rm -rf /etc/docker/daemon.json

}

################################################################################
# Apply the PACKAGES.docker setting.
#
# enabled: install Docker when it is absent. When docker-ce is present in any
#   state other than fully installed (an interrupted upgrade), do nothing: purging
#   and reinstalling over a half-configured engine, and restarting it, takes every
#   container down. The operator repairs dpkg first.
# anything else: purge Docker, which docker_purge refuses while containers run.
#
# Arguments:
#  ${1} = ${status} - the value of PACKAGES.docker.status
#
# Outputs:
#  0 if ok or nothing to do, 1 if it declined to act.
################################################################################

function docker_apply_configuration() {

    local status="${1}"
    local state

    if [[ "${status}" != "enabled" ]]; then
        docker_purge
        return $?
    fi

    state="$(package_dpkg_state "docker-ce")"

    case "${state}" in
    installed)
        return 0
        ;;
    absent)
        # Remove old docker packages, install, restart.
        docker_purge || return 1
        docker_installer
        service docker restart
        return 0
        ;;
    *)
        log_event "error" "docker-ce is in an inconsistent dpkg state; Docker is left untouched. Repair with: dpkg --configure -a" "false"
        display --indent 6 --text "- Docker" --result "SKIPPED" --color YELLOW
        display --indent 8 --text "docker-ce is half-installed: run 'dpkg --configure -a'" --tcolor YELLOW
        return 1
        ;;
    esac

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

    # Check if /etc/apt/keyrings/docker.gpg exists
    if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
        # Add Docker's official GPG key
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
    fi

    # Add the repository to Apt sources:
    echo "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu "$(. /etc/os-release && echo "${VERSION_CODENAME}")" stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

    # Log
    log_event "info" "Docker official repo added" "false"
    display --indent 6 --text "- Adding Docker official repo" --result "DONE" --color GREEN
    
    # Update the package database
    apt-get update -qq >/dev/null

}
