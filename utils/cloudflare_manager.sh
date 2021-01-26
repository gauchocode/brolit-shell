#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.10
#############################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/cloudflare_helper.sh
source "${SFOLDER}/libs/cloudflare_helper.sh"

################################################################################

cloudflare_helper_menu() {

    local cf_options 
    local chosen_cf_options 
    local root_domain

    cf_options=("01)" "SET DEVELOPMENT MODE" "02)" "DELETE CACHE" "03)" "SET SSL MODE")
    chosen_cf_options=$(whiptail --title "CLOUDFLARE MANAGER" --menu " " 20 78 10 "${cf_options[@]}" 3>&1 1>&2 2>&3)
    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        log_section "Cloudflare Manager"

        if [[ ${chosen_cf_options} == *"01"* ]]; then

            # SET DEVELOPMENT MODE

            root_domain=$(whiptail --title "Root Domain" --inputbox "Insert the root domain, example: mydomain.com" 10 60 3>&1 1>&2 2>&3)
            exitstatus=$?

            if [ ${exitstatus} = 0 ]; then
           
                cloudflare_development_mode "${root_domain}" "on"

            fi

        fi

        if [[ ${chosen_cf_options} == *"02"* ]]; then

            # DELETE CACHE

            root_domain=$(whiptail --title "Root Domain" --inputbox "Insert the root domain, example: mydomain.com" 10 60 3>&1 1>&2 2>&3)
            exitstatus=$?

            if [ ${exitstatus} = 0 ]; then
           
                cloudflare_clear_cache "${root_domain}"

            fi

        fi

        if [[ ${chosen_cf_options} == *"03"* ]]; then

            # SET SSL MODE

            root_domain=$(whiptail --title "Root Domain" --inputbox "Insert the root domain, example: mydomain.com" 10 60 3>&1 1>&2 2>&3)
            exitstatus=$?

            if [ ${exitstatus} = 0 ]; then

                # Define array of SSL modes
                local -n ssl_modes=(
                    "off" " " off
                    "flexible" " " off
                    "full" " " off
                    "strict" " " off
                )

                local ssl_mode

                ssl_mode=$(whiptail --title "CLOUDFLARE SSL MODE" --radiolist "Select the new SSL mode:" 20 78 15 "${ssl_modes[@]}" 3>&1 1>&2 2>&3)

                log_event "info" "SSL Mode selected: ${ssl_mode}" "true"

                cloudflare_ssl_mode "${root_domain}" "${ssl_mode}"

            fi

        fi

        prompt_return_or_finish
        cloudflare_helper_menu

    fi

    menu_main_options

}

################################################################################

cloudflare_helper_menu