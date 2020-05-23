#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc03
################################################################################
#
# Refs: 
#       https://certbot.eff.org/docs/using.html
#       https://certbot.eff.org/docs/using.html#certbot-commands
#
################################################################################

source "${SFOLDER}/libs/commons.sh"

################################################################################

certbot_certificate_install() {

  #$1 = EMAIL
  #$2 = DOMAINS

  EMAIL=$1
  DOMAINS=$2

  echo -e ${CYAN}" > Running: certbot --nginx --non-interactive --agree-tos --redirect -m ${EMAIL} -d ${DOMAINS}"${ENDCOLOR}
  echo " > Running: certbot --nginx --non-interactive --agree-tos --redirect -m ${EMAIL} -d ${DOMAINS}" >>$LOG
  certbot --nginx --non-interactive --agree-tos --redirect -m ${EMAIL} -d ${DOMAINS}

}

certbot_certificate_force_install() {

  #$1 = EMAIL
  #$2 = DOMAINS

  EMAIL=$1
  DOMAINS=$2

  echo -e ${CYAN}" > Running: certbot --nginx --non-interactive --agree-tos --redirect -m ${EMAIL} -d ${DOMAINS}"${ENDCOLOR}
  echo " > Running: certbot --nginx --non-interactive --agree-tos --redirect -m ${EMAIL} -d ${DOMAINS}" >>$LOG
  certbot --nginx --non-interactive --agree-tos --redirect -m ${EMAIL} -d ${DOMAINS}

}

certbot_certificate_renew() {

  #$1 = DOMAINS

  DOMAINS=$1

  echo -e ${CYAN}" > Running: certbot renew -d ${DOMAINS}"${ENDCOLOR}
  echo " > Running: certbot renew -d ${DOMAINS}" >>$LOG
  certbot renew -d ${DOMAINS}

}

certbot_certificate_force_renew() {

  #$1 = DOMAINS

  DOMAINS=$1

  echo -e ${CYAN}" > Running: certbot renew --force-renewal -d ${DOMAINS}"${ENDCOLOR}
  echo " > Running: certbot renew --force-renewal -d ${DOMAINS}" >>$LOG
  certbot renew --force-renewal -d ${DOMAINS}

}

# TODO: habria que ver como implementar las pruebas con dry-run
certbot_renew_test() {

  #$1 = DOMAINS

  DOMAINS=$1

  certbot renew --dry-run -d "${DOMAINS}"

}

certbot_helper_installer_menu() {

  #$1 = DOMAINS

  DOMAINS=$1

  CB_INSTALLER_OPTIONS="01 INSTALL_WITH_NGINX 02 INSTALL_WITH_CLOUDFLARE"
  CHOSEN_CB_INSTALLER_OPTION=$(whiptail --title "CERTBOT INSTALLER OPTIONS" --menu "Please choose an option:" 20 78 10 $(for x in ${CB_INSTALLER_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${CHOSEN_CB_INSTALLER_OPTION} == *"01"* ]]; then
      certbot_certificate_install "${MAILA}" "${DOMAINS}"
      #certbot_helper_installer_menu

    fi
    if [[ ${CHOSEN_CB_INSTALLER_OPTION} == *"02"* ]]; then
      certbot_certonly "${MAILA}" "${DOMAINS}"
      #certbot_helper_installer_menu

    fi

  fi

}

certbot_helper_menu() {

  CERTBOT_OPTIONS="01 INSTALL_CERTIFICATE 02 FORCE_INSTALL_CERTIFICATE 03 RECONFIGURE_CERTIFICATE 04 RENEW_CERTIFICATE 05 FORCE_RENEW_CERTIFICATE 06 DELETE_CERTIFICATE 07 SHOW_INSTALLED_CERTIFICATES"
  CHOSEN_CB_OPTION=$(whiptail --title "CERTBOT MANAGER" --menu "Please choose an option:" 20 78 10 $(for x in ${CERTBOT_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    DOMAINS=$(whiptail --title "CERTBOT MANAGER" --inputbox "Insert the domain and/or subdomains that you want to work with. Ex: broobe.com,www.broobe.com" 10 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then

      if [[ ${CHOSEN_CB_OPTION} == *"01"* ]]; then
        certbot_helper_installer_menu "${DOMAINS}"
        #certbot_helper_menu

      fi
      if [[ ${CHOSEN_CB_OPTION} == *"02"* ]]; then
        certbot_certificate_force_install "${MAILA}" "${DOMAINS}"
        #certbot_helper_menu

      fi
      if [[ ${CHOSEN_CB_OPTION} == *"03"* ]]; then
        # TODO: en teoria instalando normal y luego apretando 1 lo reconfigurás...
        certbot --nginx --non-interactive --agree-tos --redirect -m ${MAILA} -d ${DOMAINS}
        #certbot_helper_menu

      fi
      if [[ ${CHOSEN_CB_OPTION} == *"04"* ]]; then
        certbot_certificate_renew "${DOMAINS}"
        #certbot_helper_menu

      fi
      if [[ ${CHOSEN_CB_OPTION} == *"05"* ]]; then
        certbot_certificate_force_renew "${DOMAINS}"
        #certbot_helper_menu

      fi
      if [[ ${CHOSEN_CB_OPTION} == *"06"* ]]; then
        certbot_certificate_delete "${DOMAINS}"
        #certbot_helper_menu

      fi
      if [[ ${CHOSEN_CB_OPTION} == *"07"* ]]; then
        certbot_show_certificates_info
        #certbot_helper_menu

      fi

    fi

  else
    prompt_return_or_finish
    certbot_helper_menu

  fi

}

certbot_certonly() {

  # ATENCION: creo que el mejor camino es correr primero el certbot --nginx y luego el certbot certonly
  # por que el certbot --nginx ya te modifica los archivos de configuracion de nginx y agrega los .pem etc
  # entonces al quedar ya agregados luego el certonly solo pisa esos .pem pero las referencias a esos archivos
  # ya quedaron en los archivos de conf de nginx

  # Ref: https://mangolassi.it/topic/18355/setup-letsencrypt-certbot-with-cloudflare-dns-authentication-ubuntu/2

  # $1 = EMAIL
  # $2 = DOMAINS (domain.com,www.domain.com)

  EMAIL=$1
  DOMAINS=$2

  echo -e ${B_CYAN}"Running: certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf -m ${EMAIL} -d ${DOMAINS} --preferred-challenges dns-01"${ENDCOLOR}
  certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf -m ${EMAIL} -d ${DOMAINS} --preferred-challenges dns-01

  # Maybe add a non interactive mode?
  # certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf --non-interactive --agree-tos --redirect -m ${EMAIL} -d ${DOMAINS} --preferred-challenges dns-01

  echo -e ${MAGENTA}"Now you need to follow the next steps:"${ENDCOLOR}
  echo -e ${MAGENTA}"1- Login to your Cloudflare account and select the domain we want to work."${ENDCOLOR}
  echo -e ${MAGENTA}"2- Go to de 'DNS' option panel and Turn ON the proxy Cloudflare setting over the domain/s"${ENDCOLOR}
  echo -e ${MAGENTA}"3- Go to 'SSL/TLS' option panel and change the SSL setting from 'Flexible' to 'Full'."${ENDCOLOR}

}

certbot_show_certificates_info() {

  echo -e ${B_CYAN}"Running: certbot certificates"${ENDCOLOR}
  certbot certificates

}

certbot_show_domain_certificates_expiration_date() {

  # $1 = DOMAINS (domain.com,www.domain.com)

  DOMAINS=$1

  #echo -e ${CYAN}"Running: certbot certificates --cert-name ${DOMAINS}"${ENDCOLOR}
  certbot certificates --cert-name ${DOMAINS} | grep 'Expiry' | cut -d ':' -f2 | cut -d ' ' -f2

}

certbot_show_domain_certificates_valid_days() {

  # $1 = DOMAINS (domain.com,www.domain.com)

  DOMAINS=$1

  #echo -e ${CYAN}"Running: certbot certificates --cert-name ${DOMAINS}"${ENDCOLOR}
  certbot certificates --cert-name ${DOMAINS} | grep 'VALID' | cut -d '(' -f2 | cut -d ' ' -f2
}

certbot_certificate_delete() {

  # $1 = DOMAINS (domain.com,www.domain.com)

  DOMAINS=$1

  while true; do
    echo -e ${YELLOW}"> Do you really want to delete de certificates for ${DOMAINS}?"${ENDCOLOR}
    read -p "Please type 'y' or 'n'" yn

    case $yn in
    [Yy]*)
      certbot delete --cert-name ${DOMAINS}
      break
      ;;
    [Nn]*)
      echo -e ${YELLOW}"Aborting ..."${ENDCOLOR}
      break
      ;;
    *) echo " > Please answer yes or no." ;;
    esac

  done

}