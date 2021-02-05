#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.13
################################################################################

# shellcheck source=${SFOLDER}/libs/packages_helper.sh
source "${SFOLDER}/libs/packages_helper.sh"

################################################################################

function certbot_installer() {

  the_ppa=certbot

  if ! grep -q "^deb .*$the_ppa" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
    
    # Deprecated
    #echo -e ${GREEN}" > Adding ppa:certbot/certbot ..."${ENDCOLOR}
    #echo " > Adding ppa:certbot/certbot ..." >>$LOG
    #add-apt-repository ppa:certbot/certbot

    # Updating Repos
    display --indent 2 --text "- Updating repositories"
    apt-get --yes update -qq > /dev/null
    clear_last_line
    display --indent 2 --text "- Updating repositories" --result "DONE" --color GREEN

    # Installing Certbot
    display --indent 2 --text "- Installing certbot and dependencies"
    log_event "info" "Installing python3-certbot-dns-cloudflare and python3-certbot-nginx"
    
    # apt command
    apt-get --yes install python3-certbot-dns-cloudflare python3-certbot-nginx -qq > /dev/null
  
    # Log
    clear_last_line
    display --indent 2 --text "- Installing certbot and dependencies" --result "DONE" --color GREEN
    log_event "info" "certbot installation finished"

  else

    log_event "warning" "ppa:certbot/certbot already added!"
    
    while true; do
    
      echo -e "${YELLOW}${ITALIC} > Do you want to remove the ppa:certbot/certbot?${ENDCOLOR}"
      read -p "Please type 'y' or 'n'" yn

      case $yn in

        [Yy]*)

          log_event "warning" "\nRemoving ppa:certbot/certbot and packages provided ...\n" "false"
          # This will uninstall packages provided by the PPA, but not those provided by the official repositories
          ppa-purge ppa:certbot/certbot

          break
        ;;

        [Nn]*)

          log_event "warning" "Aborting script ..." "true"
          break

        ;;

        *) echo " > Please answer yes or no." ;;

      esac

    done

  fi

}