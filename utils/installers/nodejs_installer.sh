#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.5
################################################################################
#
#   Ref: https://github.com/nodesource/distributions#debinstall
#        https://www.digitalocean.com/community/tutorials/how-to-install-node-js-on-ubuntu-20-04
#
################################################################################

function nodejs_check_if_installed() {

    local nodejs_installed
    local nodejs

    nodejs="$(command -v node)"
    if [[ ! -x "${nodejs}" ]]; then
        nodejs_installed="false"

    else
        nodejs_installed="true"

    fi

    log_event "debug" "nodejs_installed=${nodejs_installed}"

    # Return
    echo "${nodejs_installed}"

}

function nodejs_installer() {

    # ${1} = ${nodejs_version} - optional

    local nodejs_version="${1}"

    local nodejs_installer_title
    local nodejs_installer_message
    local nodejs_installer_options

    log_subsection "NodeJS Installer"

    if [[ ${nodejs_version} == "" ]]; then

        nodejs_installer_title="NODEJS INSTALLER"
        nodejs_installer_message="Choose a version to install:"
        nodejs_installer_options=(
            "01)" "12.x"
            "01)" "14.x"
            "01)" "16.x"
        )

        chosen_nodejs_installer_options="$(whiptail --title "${nodejs_installer_title}" --menu "${nodejs_installer_message}" 20 78 10 "${nodejs_installer_options[@]}" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_nodejs_installer_options} == *"01"* ]]; then

                # Adding PPA
                curl -sL https://deb.nodesource.com/setup_12.x -o nodesource_setup.sh

            fi
            if [[ ${chosen_nodejs_installer_options} == *"02"* ]]; then

                # Adding PPA
                curl -sL https://deb.nodesource.com/setup_14.x -o nodesource_setup.sh

            fi
            if [[ ${chosen_nodejs_installer_options} == *"03"* ]]; then

                # Adding PPA
                curl -sL https://deb.nodesource.com/setup_16.x -o nodesource_setup.sh

            fi

            sudo bash nodesource_setup.sh

        fi

    else

        # Adding PPA
        curl -sL https://deb.nodesource.com/setup_"${nodejs_version}" -o nodesource_setup.sh
        sudo bash nodesource_setup.sh

    fi

    # Updating Repos
    display --indent 6 --text "- Updating repositories"

    apt-get --yes update -qq >/dev/null

    clear_previous_lines "1"
    display --indent 6 --text "- Updating repositories" --result "DONE" --color GREEN

    # Installing nodejs
    display --indent 6 --text "- Installing nodejs and dependencies"
    log_event "info" "Installing nodejs and dependencies"

    # apt command
    apt-get --yes install nodejs npm -qq >/dev/null

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Installing nodejs and dependencies" --result "DONE" --color GREEN
    log_event "info" "nodejs installation finished"

}

function nodejs_purge() {

    log_subsection "NodeJS Installer"

    # Log
    display --indent 6 --text "- Removing nodejs and libraries"
    log_event "info" "Removing nodejs and libraries ..."

    # apt command
    apt-get --yes purge nodejs npm -qq >/dev/null

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Removing nodejs and libraries" --result "DONE" --color GREEN
    log_event "info" "nodejs removed"

}
