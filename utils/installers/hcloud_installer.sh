#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.67
################################################################################

function hcloud_check_if_installed() {

    local hcloud_installed
    local hcloud

    hcloud="$(command -v hcloud)"
    if [[ ! -x "${hcloud}" ]]; then
        hcloud_installed="false"

    else
        hcloud_installed="true"

    fi

    log_event "debug" "hcloud_installed=${hcloud_installed}"

    # Return
    echo "${hcloud_installed}"

}

function hcloud_installer() {

    log_subsection "HCloud Installer"

    log_event "info" "Updating packages before installation ..."
    apt-get --yes update -qq >/dev/null

    # Installing packages
    log_event "info" "Installing hcloud-cli ..."
    apt-get --yes install hcloud-cli -qq >/dev/null

}

function hcloud_purge() {

    log_subsection "HCloud Installer"

    # Installing packages
    log_event "info" "Uninstalling hcloud-cli ..."
    apt-get --yes purge hcloud-cli -qq >/dev/null

}

# TODO: make a hcloud_installer_menu

# TODO: make a hcloud helper
function hcloud_configure() {

    local project_name=$1

    hcloud context create "${project_name}"

}

function hcloud_server_list() {

    #local project_name=$1

    hcloud server list

}