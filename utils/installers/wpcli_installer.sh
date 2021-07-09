#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.42
################################################################################

function wpcli_installer_menu() {

    WPCLI_INSTALLED="$(wpcli_check_if_installed)"

    if [[ ${WPCLI_INSTALLED} == "true" ]]; then

        wpcli_options_title="WP-CLI INSTALLER"

        wp_cli_installer_options=(
            "01)" "UPDATE WP-CLI"
            "02)" "UNINSTALL WP-CLI"
        )

        chosen_wp_cli_installer_option="$(whiptail --title "${wpcli_options_title}" --menu "Choose an option:" 20 78 10 $(for x in ${wp_cli_installer_options}; do echo "$x"; done) 3>&1 1>&2 2>&3)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_wp_cli_installer_option} == *"01"* ]]; then
                wpcli_update

            fi
            if [[ ${chosen_wp_cli_installer_option} == *"02"* ]]; then
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
