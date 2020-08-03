#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc07
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

    local cf_options chosen_cf_options root_domain

    cf_options="01 SET_DEVELOPMENT_MODE 02 DELETE_CF_CACHE"
    chosen_cf_options=$(whiptail --title "CLOUDFLARE HELPER" --menu "Choose an option to run" 20 78 10 $(for x in ${cf_options}; do echo "$x"; done) 3>&1 1>&2 2>&3)
    exitstatus=$?

    if [ $exitstatus = 0 ]; then

        if [[ ${chosen_cf_options} == *"01"* ]]; then

            # SET_DEVELOPMENT_MODE

            root_domain=$(whiptail --title "Root Domain" --inputbox "Insert the root domain, example: mydomain.com" 10 60 3>&1 1>&2 2>&3)
            exitstatus=$?

            if [ ${exitstatus} = 0 ]; then
           
                cloudflare_development_mode "${root_domain}" "on"

            fi

        fi

        if [[ ${chosen_cf_options} == *"02"* ]]; then

            # DELETE_CF_CACHE

            root_domain=$(whiptail --title "Root Domain" --inputbox "Insert the root domain, example: mydomain.com" 10 60 3>&1 1>&2 2>&3)
            exitstatus=$?

            if [ ${exitstatus} = 0 ]; then
           
                cloudflare_clear_cache "${root_domain}"

            fi

        fi

    fi

}

################################################################################

cloudflare_helper_menu