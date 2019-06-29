#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9
#############################################################################
#
# HTTPS with Certbot
DOMAIN=$(whiptail --title "CERTBOT MANAGER" --inputbox "Please insert the domain or subdomain where you want to install the certificate. Example: dev.broobe.com" 10 60 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
  echo -e ${YELLOW}" > Trying to execute certbot for ${DOMAIN} ..."${ENDCOLOR}
  # TODO: Multiple domains/subdomains
  # certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}
  certbot --nginx -d ${DOMAIN}

  echo -e ${GREEN}" > Everything is DONE! ..."${ENDCOLOR}
fi
