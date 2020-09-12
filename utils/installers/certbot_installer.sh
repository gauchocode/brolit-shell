#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.1
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/packages_helper.sh
source "${SFOLDER}/libs/packages_helper.sh"

################################################################################

# Check basic installation packages
basic_packages_installation

the_ppa=certbot

if ! grep -q "^deb .*$the_ppa" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
  
  # Deprecated
  #echo -e ${GREEN}" > Adding ppa:certbot/certbot ..."${ENDCOLOR}
  #echo " > Adding ppa:certbot/certbot ..." >>$LOG
  #add-apt-repository ppa:certbot/certbot

  apt --yes update

  log_event "info" "Installing python3-certbot-dns-cloudflare and python3-certbot-nginx" "true"

  apt --yes install python3-certbot-dns-cloudflare python3-certbot-nginx -qq

  log_event "info" "certbot installation done!" "true"

else

  log_event "warning" "ppa:certbot/certbot already added!" "true"
  
  while true; do
  
    echo -e ${YELLOW}"> Do you want to remove the ppa:certbot/certbot?"${ENDCOLOR}
    read -p "Please type 'y' or 'n'" yn
    case $yn in
    [Yy]*)

      log_event "warning" "\nRemoving ppa:certbot/certbot and packages provided ...\n" "true"
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