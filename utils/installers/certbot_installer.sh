#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9.9
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/packages_helper.sh

################################################################################

the_ppa=certbot

if ! grep -q "^deb .*$the_ppa" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
  echo -e ${GREEN}" > Adding ppa:certbot/certbot ..."${ENDCOLOR}
  echo " > Adding ppa:certbot/certbot ..." >>$LOG
  add-apt-repository ppa:certbot/certbot

else
  echo -e ${GREEN}" > ppa:certbot/certbot already added ..."${ENDCOLOR}

fi

apt --yes update

echo -e ${GREEN}" > Installing python3-certbot-dns-cloudflare and python3-certbot-nginx ..."${ENDCOLOR}
echo " > Installing python3-certbot-dns-cloudflare and python3-certbot-nginx ..." >>$LOG

apt --yes install python3-certbot-dns-cloudflare python3-certbot-nginx

echo " > DONE" >>$LOG
echo -e ${GREEN}" > DONE"${ENDCOLOR}
