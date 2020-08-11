#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
################################################################################
#
# Ref: https://certbot.eff.org/docs/using.html#certbot-commands
#
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

certbot_certificate_install() {

  #$1 = ${email}
  #$2 = ${domains}

  local email=$1
  local domains=$2

  log_event "info" "Running: certbot --nginx --non-interactive --agree-tos --redirect -m ${email} -d ${domains}" "true"
  
  certbot --nginx --non-interactive --agree-tos --redirect -m "${email}" -d "${domains}"

}

certbot_certificate_expand(){
  
  #$1 = ${email}
  #$2 = ${domains}

  local email=$1
  local domains=$2

  log_event "info" "Running: certbot --nginx --non-interactive --agree-tos --expand --redirect -m ${email} -d ${domains}" "true"

  certbot --nginx --non-interactive --agree-tos --expand --redirect -m "${email}" -d "${domains}"

}

certbot_certificate_renew() {

  #$1 = ${domains}

  local domains=$1

  log_event "info" "Running: certbot renew -d ${domains}" "true"

  certbot renew -d "${domains}"

}

certbot_certificate_renew_test() {

  # Test renew for all installed certificates

  log_event "info" "Running: certbot renew --dry-run -d "${domains}"" "true"
  
  certbot renew --dry-run -d "${domains}"

}

certbot_certificate_force_renew() {

  #$1 = ${domains}

  local domains=$1

  log_event "info" "Running: certbot --nginx --non-interactive --agree-tos --force-renewal --redirect -m ${email} -d ${domains}" "true"
  
  certbot --nginx --non-interactive --agree-tos --force-renewal --redirect -m "${email}" -d "${domains}"

}

certbot_helper_installer_menu() {

  #$1 = ${email}
  #$2 = ${domains}

  local email=$1
  local domains=$2

  local cb_installer_options chosen_cb_installer_option cb_warning_text

  cb_installer_options="01 INSTALL_WITH_NGINX 02 INSTALL_WITH_CLOUDFLARE"
  chosen_cb_installer_option=$(whiptail --title "CERTBOT INSTALLER OPTIONS" --menu "Please choose an installation method:" 20 78 10 $(for x in ${cb_installer_options}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${chosen_cb_installer_option} == *"01"* ]]; then
      certbot_certificate_install "${email}" "${domains}"

    fi
    if [[ ${chosen_cb_installer_option} == *"02"* ]]; then
      certbot_certonly_cloudflare "${email}" "${domains}"

      cb_warning_text+="\n Now you need to follow the next steps: \n"
      cb_warning_text+="1- Login to your Cloudflare account and select the domain we want to work. \n"
      cb_warning_text+="2- Go to de 'DNS' option panel and Turn ON the proxy Cloudflare setting over the domain/s \n"
      cb_warning_text+="3- Go to 'SSL/TLS' option panel and change the SSL setting from 'Flexible' to 'Full'. \n"

      whiptail_event "${cb_warning_text}"
      #root_domain=$(ask_rootdomain_for_cloudflare_config "${domains}")
      # TODO: list entries to add proxy on cloudflare records
      #cloudflare_change_a_record "${root_domain}" "" "true"

      # Changing SSL Mode flor Cloudflare record
      #cloudflare_ssl_mode "${root_domain}" "full"

    fi

    prompt_return_or_finish
    certbot_helper_installer_menu

  fi

  main_menu

}

certbot_certonly_cloudflare() {

  # IMPORTANT: maybe we could create a certbot_cloudflare_certificate that runs first the nginx certbot
  # and then the certonly with cloudflare credentials

  # Ref: https://mangolassi.it/topic/18355/setup-letsencrypt-certbot-with-cloudflare-dns-authentication-ubuntu/2

  # $1 = email
  # $2 = domains (domain.com,www.domain.com)

  local email=$1
  local domains=$2

  log_event "info" "Running: certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf -m ${email} -d ${domains} --preferred-challenges dns-01" "true"
  
  certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf -m "${email}" -d "${domains}" --preferred-challenges dns-01

  # Maybe add a non interactive mode?
  # certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf --non-interactive --agree-tos --redirect -m ${EMAIL} -d ${DOMAINS} --preferred-challenges dns-01

}

certbot_show_certificates_info() {

  log_event "info" "Running: certbot certificates" "true"

  certbot certificates

}

certbot_show_domain_certificates_expiration_date() {

  # $1 = domains (domain.com,www.domain.com)

  local domains=$1

  log_event "info" "Running: certbot certificates --cert-name ${domains}" "true"

  certbot certificates --cert-name "${domains}" | grep 'Expiry' | cut -d ':' -f2 | cut -d ' ' -f2

}

certbot_certificate_valid_days() {

  # $1 = domains (domain.com,www.domain.com)

  local domain=$1

  local cert_days

  log_event "info" "Running: certbot certificates --cert-name ${domain}" "true"

  cert_days=$(certbot certificates --cert-name "${domain}" | grep 'VALID' | cut -d '(' -f2 | cut -d ' ' -f2)

  if [ "${cert_days}" == "" ]; then
      #new try with www on it
      cert_days=$(certbot certificates --cert-name "www.${domain}" | grep 'VALID' | cut -d '(' -f2 | cut -d ' ' -f2)
      if [ "${cert_days}" == "" ]; then
          #new try with -0001
          cert_days=$(certbot certificates --cert-name "${domain}-0001" | grep 'VALID' | cut -d '(' -f2 | cut -d ' ' -f2)
          if [ "${cert_days}" == "" ]; then
            #new try with www and -0001
            cert_days=$(certbot certificates --cert-name "www.${domain}-0001" | grep 'VALID' | cut -d '(' -f2 | cut -d ' ' -f2)
          fi
      fi
  fi

  log_event "info" "Certificate valid for: ${cert_days} days" "true"

  # Return
  echo "${cert_days}"

}

certbot_certificate_delete() {

  # $1 = DOMAINS (domain.com,www.domain.com)

  local domains=$1

  if [[ -z "${domains}" ]]; then

    #Run certbot delete wizard
    certbot --nginx delete

  else

    while true; do
      echo -e ${YELLOW}"> Do you really want to delete de certificates for ${domains}?"${ENDCOLOR}
      read -p "Please type 'y' or 'n'" yn

      case $yn in
      [Yy]*)
        certbot delete --cert-name "${domains}"
        break
        ;;
      [Nn]*)
        echo -e ${YELLOW}"Aborting ..."${ENDCOLOR}
        break
        ;;
      *) echo " > Please answer yes or no." ;;
      esac

    done

fi

}

certbot_helper_ask_domains() {

  local domains

  domains=$(whiptail --title "CERTBOT MANAGER" --inputbox "Insert the domain and/or subdomains that you want to work with. Ex: broobe.com,www.broobe.com" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    echo "${domains}"
    #exit 0;

  else

    exit 1;

  fi

}

certbot_helper_menu() {

  local domains certbot_options chosen_cb_options

  certbot_options="01 INSTALL_CERTIFICATE 02 EXPAND_CERTIFICATE 03 TEST_RENEW_ALL_CERTIFICATES 04 FORCE_RENEW_CERTIFICATE 05 DELETE_CERTIFICATE 06 SHOW_INSTALLED_CERTIFICATES"
  chosen_cb_options=$(whiptail --title "CERTBOT MANAGER" --menu "Please choose an option:" 20 78 10 $(for x in ${certbot_options}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${chosen_cb_options} == *"01"* ]]; then
      domains=$(certbot_helper_ask_domains)
      certbot_helper_installer_menu "${MAILA}" "${domains}"

    fi
    if [[ ${chosen_cb_options} == *"02"* ]]; then
      domains=$(certbot_helper_ask_domains)
      certbot_certificate_expand "${MAILA}" "${domains}"

    fi
    if [[ ${chosen_cb_options} == *"03"* ]]; then
      certbot_certificate_renew_test

    fi
    if [[ ${chosen_cb_options} == *"04"* ]]; then
      domains=$(certbot_helper_ask_domains)
      certbot_certificate_force_renew "${domains}"

    fi
    if [[ ${chosen_cb_options} == *"05"* ]]; then
      domains=$(certbot_helper_ask_domains)
      certbot_certificate_delete "${domains}"

    fi
    if [[ ${chosen_cb_options} == *"06"* ]]; then
      certbot_show_certificates_info
      #read -n 1 -p "Press any key to return to the certbot menu" "mainmenuinput"

    fi

    prompt_return_or_finish
    certbot_helper_menu

  fi

  main_menu

}