#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.22
################################################################################

function wpcli_installer_menu() {

    WPCLI_INSTALLED=$(wpcli_check_if_installed)

    if [[ ${WPCLI_INSTALLED} == "true" ]]; then

        WPCLI_INSTALLER_OPTIONS="01 UPDATE_WPCLI 02 UNINSTALL_WPCLI"
        CHOSEN_WPCLI_INSTALLER_OPTION=$(whiptail --title "WPCLI INSTALLER" --menu "Choose an option:" 20 78 10 $(for x in ${WPCLI_INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${CHOSEN_WPCLI_INSTALLER_OPTION} == *"01"* ]]; then
                wpcli_update

            fi
            if [[ ${CHOSEN_WPCLI_INSTALLER_OPTION} == *"02"* ]]; then
                wpcli_uninstall

            fi

        else
            log_event "info" "Operation cancelled ..." "true"
            return 1

        fi

    else

        wpcli_install

    fi

}