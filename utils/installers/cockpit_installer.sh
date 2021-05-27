#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.26
#############################################################################

function cockpit_installer() {

    log_event "info" "Installing cockpit" "false"
    display --indent 2 --text "- Installing cockpit"

    apt-get --yes update -qq > /dev/null
    apt-get --yes install cockpit cockpit-docker cockpit-networkmanager cockpit-storaged cockpit-system cockpit-packagekit cockpit-shell -qq > /dev/null

    ufw allow 9090

    log_event "info" "Cockpit must be running on port 9090" "false"
    clear_last_line
    display --indent 2 --text "- Installing cockpit" --result "DONE" --color GREEN
    display --indent 4 --text "Running on port 9090"

}