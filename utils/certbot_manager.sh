#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9
################################################################################

# https://www.linode.com/community/questions/17616/how-do-i-renew-my-lets-encrypt-cert-with-a-newer-validation-method
# https://stackoverflow.com/questions/50219577/lets-encrypt-repair-broken-certificate-with-certbot

# HTTPS with Certbot

# TODO: opciones de instalar en dominio o varios dominios (normal o forzando), de renovar certificado (normal o forzando)

DOMAIN=$(whiptail --title "CERTBOT MANAGER" --inputbox "Please insert the domain or subdomain where you want to install the certificate. Example: dev.broobe.com" 10 60 3>&1 1>&2 2>&3)
exitstatus=$?
if [ $exitstatus = 0 ]; then
  echo -e ${YELLOW}" > Trying to execute certbot for ${DOMAIN} ..."${ENDCOLOR}

  # TODO: Multiple domains/subdomains
  # certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}

  # TODO: opcion para forzar renovación
  # certbot renew --force-renewal --nginx --dry-run --preferred-challenges http

  certbot --nginx -d ${DOMAIN}

  echo -e ${GREEN}" > Everything is DONE! ..."${ENDCOLOR}
fi
