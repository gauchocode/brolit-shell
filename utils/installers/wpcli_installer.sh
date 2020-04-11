#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-beta11
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/wpcli_helper.sh

################################################################################

WPCLI_INSTALLED=$(wpcli_check_if_installed)

if [ ${WPCLI_INSTALLED} = "true" ]; then

    WPCLI_INSTALLER_OPTIONS="01 UPDATE_WPCLI 02 UNINSTALL_WPCLI"
    CHOSEN_WPCLI_INSTALLER_OPTION=$(whiptail --title "WPCLI INSTALLER" --menu "Choose an option:" 20 78 10 $(for x in ${WPCLI_INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then

        if [[ ${CHOSEN_WPCLI_INSTALLER_OPTION} == *"01"* ]]; then
            wpcli_update

        fi
        if [[ ${CHOSEN_WPCLI_INSTALLER_OPTION} == *"02"* ]]; then

            echo -e ${CYAN}" > Uninstalling wp-cli ..."${ENDCOLOR}
            wpcli_uninstall

        fi

    else
        echo -e ${YELLOW}" > Operation cancelled ..."${ENDCOLOR}
        exit 1

    fi

else

    echo -e ${CYAN}" > Installing wp-cli ..."${ENDCOLOR}
    wpcli_install

fi
