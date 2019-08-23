#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9
################################################################################
#
# HTTPS with Certbot
# TODO: abria que preguntar si se quiere instalar certificado nginx only o nginx+cloudflare
# TODO: soporte con Cloudflare: https://certbot-dns-cloudflare.readthedocs.io/en/stable/
# TODO: si se elige nginx+cloudflare:
# apt install python3-certbot-dns-cloudflare
# vim /root/.cloudflare.conf
# Adentro del .cloudflare.con (pedir credenciales):
#dns_cloudflare_email = "email@domain.com"
#dns_cloudflare_api_key = "2018c330b45f4ghytr420eaf66b49c5cabie4"
# Corremos el certbot:
# certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf -d domain.com,www.domain.com --preferred-challenges dns-01
# en el sites-avaiable del site en si:
#      listen 443 ssl http2; # managed by Certbot
#      ssl_certificate /etc/letsencrypt/live/DOMAIN.com/fullchain.pem; # managed by Certbot
#      ssl_certificate_key /etc/letsencrypt/live/DOMAIN.com/privkey.pem; # managed by Certbot
#      include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
#      ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot
# Check config:
# nginx -t
# Reiniciamos nginx
# Instalamos un cronjob:
#14 5 * * * certbot renew --quiet --post-hook "service nginx reload" > /dev/null 2>&1
#
################################################################################

certbot_certificate_install() {
  certbot --nginx --non-interactive --agree-tos --redirect -m $1 -d $2
  # TODO: Multiple domains/subdomains
  # certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}
}

certbot_certificate_force_install() {
  certbot --nginx --non-interactive --agree-tos --redirect -m $1 -d $2

}

certbot_certificate_renew() {
  certbot renew --nginx --non-interactive --agree-tos --preferred-challenges http -m $1 -d $2

}

certbot_certificate_force_renew() {
  certbot --nginx --non-interactive --agree-tos --redirect -m $1 -d $2

}

################################################################################

CERTBOT_OPTIONS="01 INSTALL_CERTIFICATE 02 FORCE_INSTALL_CERTIFICATE 03 RECONFIGURE_CERTIFICATE 04 RENEW_CERTIFICATE 05 FORCE_RENEW_CERTIFICATE"

CHOSEN_CB_OPTION=$(whiptail --title "CERTBOT MANAGER" --menu "Please choose an option:" 20 78 10 $(for x in ${CERTBOT_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then

  DOMAIN=$(whiptail --title "CERTBOT MANAGER" --inputbox "Please insert the domain or subdomain where you want to install the certificate. Example: dev.broobe.com" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    echo -e ${YELLOW}" > Trying to execute certbot for ${DOMAIN} ..."${ENDCOLOR}

    if [[ ${CHOSEN_CB_OPTION} == *"01"* ]]; then
      certbot_certificate_install "${MAILA}" "${DOMAIN}"

    fi
    if [[ ${CHOSEN_CB_OPTION} == *"02"* ]]; then
      certbot_certificate_force_install "${MAILA}" "${DOMAIN}"

    fi
    if [[ ${CHOSEN_CB_OPTION} == *"03"* ]]; then
      # TODO: en teoria instalando normal y luego apretando 1 lo reconfigurás...
      certbot --nginx --non-interactive --agree-tos --redirect -m ${MAILA} -d ${DOMAIN}

    fi
    if [[ ${CHOSEN_CB_OPTION} == *"04"* ]]; then
      certbot_certificate_renew "${MAILA}" "${DOMAIN}"

    fi
    if [[ ${CHOSEN_CB_OPTION} == *"05"* ]]; then
      # TODO: testear
      #certbot renew --force-renewal --nginx --dry-run --preferred-challenges http -d ${DOMAIN}
      certbot renew --force-renewal --nginx --preferred-challenges http -d ${DOMAIN}

    fi

    #echo -e ${GREEN}" > Everything is DONE! ..."${ENDCOLOR}

  fi

else
  exit 1

fi
