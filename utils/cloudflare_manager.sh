#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.27
#############################################################################

function cloudflare_helper_menu() {

    local cf_options
    local chosen_cf_options
    local root_domain

    cf_options=(
        "01)" "SET DEVELOPMENT MODE"
        "02)" "DELETE CACHE"
        "03)" "SET SSL MODE"
        "04)" "SET CACHE TTL VALUE"
    )
    chosen_cf_options="$(whiptail --title "CLOUDFLARE MANAGER" --menu " " 20 78 10 "${cf_options[@]}" 3>&1 1>&2 2>&3)"
    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        if [[ ${chosen_cf_options} == *"01"* ]]; then

            # SET DEVELOPMENT MODE

            root_domain="$(whiptail --title "Root Domain" --inputbox "Insert the root domain, example: mydomain.com" 10 60 3>&1 1>&2 2>&3)"
            exitstatus=$?

            if [[ ${exitstatus} = 0 ]]; then

                cloudflare_set_development_mode "${root_domain}" "on"

            fi

        fi

        if [[ ${chosen_cf_options} == *"02"* ]]; then

            # DELETE CACHE

            root_domain="$(whiptail --title "Root Domain" --inputbox "Insert the root domain, example: mydomain.com" 10 60 3>&1 1>&2 2>&3)"
            exitstatus=$?

            if [[ ${exitstatus} = 0 ]]; then

                cloudflare_clear_cache "${root_domain}"

            fi

        fi

        if [[ ${chosen_cf_options} == *"03"* ]]; then

            # SET SSL MODE

            root_domain="$(whiptail --title "Root Domain" --inputbox "Insert the root domain, example: mydomain.com" 10 60 3>&1 1>&2 2>&3)"
            exitstatus=$?

            if [[ ${exitstatus} = 0 ]]; then

                # Define array of SSL modes
                local ssl_modes=(
                    "01)" "off"
                    "02)" "flexible"
                    "03)" "full"
                    "04)" "strict"
                )

                local chosen_ssl_mode

                chosen_ssl_mode="$(whiptail --title "CLOUDFLARE SSL MODE" --menu "Select the new SSL mode:" 20 78 10 "${ssl_modes[@]}" 3>&1 1>&2 2>&3)"
                exitstatus=$?
                if [[ ${exitstatus} = 0 ]]; then

                    log_event "info" "SSL Mode selected: ${chosen_ssl_mode}" "true"

                    cloudflare_set_ssl_mode "${root_domain}" "${chosen_ssl_mode}"

                fi

            fi

        fi

        if [[ ${chosen_cf_options} == *"04"* ]]; then

            # SET CACHE TTL VALUE

            root_domain="$(whiptail --title "Root Domain" --inputbox "Insert the root domain, example: mydomain.com" 10 60 3>&1 1>&2 2>&3)"
            exitstatus=$?

            if [[ ${exitstatus} = 0 ]]; then

                cloudflare_set_cache_ttl_value "${root_domain}" "0"

            fi

        fi

        prompt_return_or_finish
        cloudflare_helper_menu

    fi

    menu_main_options

}
