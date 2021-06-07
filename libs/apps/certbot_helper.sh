#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.32
################################################################################
#
# Ref: https://certbot.eff.org/docs/using.html#certbot-commands
#
################################################################################

function certbot_certificate_install() {

  #$1 = ${email}
  #$2 = ${domains}

  local email=$1
  local domains=$2

  local certbot_result

  log_event "debug" "Running: certbot --nginx --non-interactive --agree-tos --redirect -m ${email} -d ${domains}"

  certbot --nginx --non-interactive --agree-tos --redirect -m "${email}" -d "${domains}"

  certbot_result=$?
  if [[ ${certbot_result} -eq 0 ]]; then
    log_event "info" "Certificate installation for ${domains} ok" "false"
    display --indent 6 --text "- Certificate installation" --result "DONE" --color GREEN

  else
    log_event "warning" "Certificate installation failed, trying force-install ..." "false"
    display --indent 6 --text "- Installing certificate on domains" --result "FAIL" --color RED

    # Deleting old config
    certbot_certificate_delete_old_config "${domains}"

    # Running certbot again
    certbot --nginx --non-interactive --agree-tos --redirect -m "${email}" -d "${domains}"

    certbot_result=$?
    if [[ ${certbot_result} -eq 0 ]]; then
      log_event "info" "Certificate installation for ${domains} ok" "false"
      display --indent 6 --text "- Certificate installation" --result "DONE" --color GREEN

    else
      log_event "error" "Certificate installation for ${domains} failed!" "false"
      display --indent 6 --text "- Installing certificate on domains" --result "FAIL" --color RED

    fi

  fi

}

function certbot_certificate_delete_old_config() {

  # $1 = ${domains}

  local domains=$1

  for domain in ${domains}; do

    # Check if directories exist
    if [[ -d "/etc/letsencrypt/archive/${domain}" ]]; then
      # Delete
      rm --recursive --force "/etc/letsencrypt/archive/${domain}"
      display --indent 6 --text "- Deleting /etc/letsencrypt/archive/${domain}" --result "DONE" --color GREEN

    fi
    if [[ -d "/etc/letsencrypt/live/${domain}" ]]; then
      # Delete
      rm --recursive --force "/etc/letsencrypt/live/${domain}"
      display --indent 6 --text "- Deleting /etc/letsencrypt/live/${domain}" --result "DONE" --color GREEN
    fi
    if [[ -f "/etc/letsencrypt/renewal/${domain}.conf" ]]; then
      # Delete
      rm --force"/etc/letsencrypt/renewal/${domain}.conf"
      display --indent 6 --text "- Deleting /etc/letsencrypt/renewal/${domain}.conf" --result "DONE" --color GREEN
    fi

  done

}

function certbot_certificate_expand() {

  #$1 = ${email}
  #$2 = ${domains}

  local email=$1
  local domains=$2

  log_event "debug" "Running: certbot --nginx --non-interactive --agree-tos --expand --redirect -m ${email} -d ${domains}"

  certbot --nginx --non-interactive --agree-tos --expand --redirect -m "${email}" -d "${domains}"

}

function certbot_certificate_renew() {

  #$1 = ${domains}

  local domains=$1

  log_event "debug" "Running: certbot renew -d ${domains}"

  certbot renew -d "${domains}"

}

function certbot_certificate_renew_test() {

  # Test renew for all installed certificates

  log_event "debug" "Running: certbot renew --dry-run -d ${domains}"

  certbot renew --dry-run -d "${domains}"

}

function certbot_certificate_force_renew() {

  #$1 = ${domains}

  local domains=$1

  log_event "debug" "Running: certbot --nginx --non-interactive --agree-tos --force-renewal --redirect -m ${email} -d ${domains}"

  certbot --nginx --non-interactive --agree-tos --force-renewal --redirect -m "${email}" -d "${domains}"

}

function certbot_helper_installer_menu() {

  #$1 = ${email}
  #$2 = ${domains}

  local email=$1
  local domains=$2

  local cb_installer_options
  local chosen_cb_installer_option
  local cb_warning_text
  local certbot_result

  cb_installer_options=(
    "01)" "INSTALL WITH NGINX"
    "02)" "INSTALL WITH CLOUDFLARE"
  )

  chosen_cb_installer_option="$(whiptail --title "CERTBOT INSTALLER OPTIONS" --menu "Please choose an installation method:" 20 78 10 "${cb_installer_options[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_cb_installer_option} == *"01"* ]]; then

      # INSTALL_WITH_NGINX

      log_subsection "Certificate Installation with Certbot Nginx"

      certbot_certificate_install "${email}" "${domains}"

    fi
    if [[ ${chosen_cb_installer_option} == *"02"* ]]; then

      # INSTALL_WITH_CLOUDFLARE

      log_subsection "Certificate Installation with Certbot Cloudflare"

      certbot_certonly_cloudflare "${email}" "${domains}"

      cb_warning_text+="\n Now you need to follow the next steps: \n"
      cb_warning_text+="1- Login to your Cloudflare account and select the domain we want to work. \n"
      cb_warning_text+="2- Go to de 'DNS' option panel and Turn ON the proxy Cloudflare setting over the domain/s \n"
      cb_warning_text+="3- Go to 'SSL/TLS' option panel and change the SSL setting from 'Flexible' to 'Full'. \n"

      whiptail_message "CERTBOT MANAGER" "${cb_warning_text}"
      #root_domain=$(ask_rootdomain_for_cloudflare_config "${domains}")

      # TODO: list entries to add proxy on cloudflare records
      #cloudflare_set_record "${root_domain}" "" "true"

      # Changing SSL Mode flor Cloudflare record
      #cloudflare_set_ssl_mode "${root_domain}" "full"

    fi

    prompt_return_or_finish

  fi

}

function certbot_certonly_cloudflare() {

  # IMPORTANT: maybe we could create a certbot_cloudflare_certificate that runs first the nginx certbot
  # and then the certonly with cloudflare credentials

  # Ref: https://mangolassi.it/topic/18355/setup-letsencrypt-certbot-with-cloudflare-dns-authentication-ubuntu/2

  # $1 = email
  # $2 = domains (domain.com,www.domain.com)

  local email=$1
  local domains=$2

  log_event "debug" "Running: certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf -m ${email} -d ${domains} --preferred-challenges dns-01"

  certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf -m "${email}" -d "${domains}" --preferred-challenges dns-01

  # Maybe add a non interactive mode?
  # certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf --non-interactive --agree-tos --redirect -m ${EMAIL} -d ${DOMAINS} --preferred-challenges dns-01

  certbot_result=$?
  if [[ ${certbot_result} -eq 0 ]]; then
    log_event "info" "Certificate installation for ${domains} ok"
    display --indent 6 --text "- Certificate installation" --result "DONE" --color GREEN

  else
    log_event "warning" "Certificate installation failed, trying force-install ..."
    display --indent 6 --text "- Installing certificate on domains" --result "FAIL" --color RED

    # Deleting old config
    certbot_certificate_delete_old_config "${domains}"

    # Running certbot again
    certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf -m "${email}" -d "${domains}" --preferred-challenges dns-01

    certbot_result=$?
    if [[ ${certbot_result} -eq 0 ]]; then
      log_event "info" "Certificate installation for ${domains} ok"
      display --indent 6 --text "- Certificate installation" --result "DONE" --color GREEN

    else
      log_event "error" "Certificate installation for ${domains} failed!"
      display --indent 6 --text "- Installing certificate on domains" --result "FAIL" --color RED

    fi

  fi

}

function certbot_show_certificates_info() {

  log_event "debug" "Running: certbot certificates"

  certbot certificates

}

function certbot_show_domain_certificates_expiration_date() {

  # $1 = domains (domain.com,www.domain.com)

  local domains=$1

  log_event "debug" "Running: certbot certificates --cert-name ${domains}"

  certbot certificates --cert-name "${domains}" | grep 'Expiry' | cut -d ':' -f2 | cut -d ' ' -f2

}

# TODO: Awful code, need a refactor
function certbot_certificate_valid_days() {

  # $1 = domains (domain.com,www.domain.com)

  local domain=$1

  local cert_days
  local root_domain
  local subdomain_part

  root_domain="$(get_root_domain "${domain}")"
  subdomain_part="$(get_subdomain_part "${domain}")"

  cert_days=$(certbot certificates --cert-name "${domain}" | grep 'VALID' | cut -d '(' -f2 | cut -d ' ' -f2)

  if [[ ${cert_days} == "" ]]; then

    if [[ ${subdomain_part} == "www" ]]; then

      cert_days=$(certbot certificates --cert-name "${root_domain}" | grep 'VALID' | cut -d '(' -f2 | cut -d ' ' -f2)

      if [[ "${cert_days}" == "" ]]; then
        # New try with -0001
        cert_days=$(certbot certificates --cert-name "${root_domain}-0001" | grep 'VALID' | cut -d '(' -f2 | cut -d ' ' -f2)

      fi

    else

      cert_days=$(certbot certificates --cert-name "www.${root_domain}" | grep 'VALID' | cut -d '(' -f2 | cut -d ' ' -f2)

      if [[ "${cert_days}" == "" ]]; then
        cert_days=$(certbot certificates --cert-name "${domain}-0001" | grep 'VALID' | cut -d '(' -f2 | cut -d ' ' -f2)

      fi

    fi

  fi

  log_event "info" "Certificate valid for: ${cert_days} days"

  # Return
  echo "${cert_days}"

}

function cerbot_certificate_get_valid_days() {
  # $1 = domains (domain.com,www.domain.com)

  local domain=$1

  local cert_days

  cert_days_output="$(certbot certificates --domain "${domain}")"
  cert_days="$(echo "${cert_days_output}" | grep -Eo 'VALID: [0-9]+[0-9]' | cut -d ' ' -f 2)"

  if [[ ${cert_days} == "" ]]; then

    # Return
    echo "no-cert"

  else

    # Return
    echo "${cert_days}"

  fi

}

function certbot_certificate_delete() {

  # $1 = DOMAINS (domain.com,www.domain.com)

  local domains=$1

  if [[ -z "${domains}" ]]; then

    #Run certbot delete wizard
    certbot --nginx delete

  else

    while true; do
      echo -e "${YELLOW}${ITALIC} > Do you really want to delete de certificates for ${domains}?${ENDCOLOR}"
      read -p -r "Please type 'y' or 'n'" yn

      case $yn in

      [Yy]*)

        log_event "debug" "Running: certbot delete --cert-name ${domains}" "false"
        certbot --nginx delete --cert-name "${domains}"
        break

        ;;

      [Nn]*)

        log_event "info" "Aborting ..." "true"
        break
        ;;

      *) echo " > Please answer yes or no." ;;

      esac

    done

  fi

}

function certbot_helper_ask_domains() {

  local domains

  domains="$(whiptail --title "CERTBOT MANAGER" --inputbox "Insert the domain and/or subdomains that you want to work with. Ex: broobe.com,www.broobe.com" 10 60 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Return
    echo "${domains}"

  else

    return 1

  fi

}

function certbot_helper_menu() {

  local domains
  local certbot_options
  local chosen_cb_options

  certbot_options=(
    "01)" "INSTALL CERTIFICATE"
    "02)" "EXPAND CERTIFICATE"
    "03)" "TEST RENEW ALL CERTIFICATES"
    "04)" "FORCE RENEW CERTIFICATE"
    "05)" "DELETE CERTIFICATE"
    "06)" "SHOW INSTALLED CERTIFICATES"
  )
  chosen_cb_options="$(whiptail --title "CERTBOT MANAGER" --menu " " 20 78 10 "${certbot_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} = 0 ]]; then

    if [[ ${chosen_cb_options} == *"01"* ]]; then

      # INSTALL-CERTIFICATE
      domains="$(certbot_helper_ask_domains)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        certbot_helper_installer_menu "${MAILA}" "${domains}"
      fi

    fi

    if [[ ${chosen_cb_options} == *"02"* ]]; then
      # EXPAND-CERTIFICATE
      domains="$(certbot_helper_ask_domains)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        certbot_certificate_expand "${MAILA}" "${domains}"
      fi

    fi

    if [[ ${chosen_cb_options} == *"03"* ]]; then
      # TEST-RENEW-ALL-CERTIFICATES
      certbot_certificate_renew_test

    fi

    if [[ ${chosen_cb_options} == *"04"* ]]; then
      # FORCE-RENEW-CERTIFICATE
      domains="$(certbot_helper_ask_domains)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        certbot_certificate_force_renew "${domains}"
      fi

    fi

    if [[ ${chosen_cb_options} == *"05"* ]]; then
      # DELETE-CERTIFICATE
      certbot_certificate_delete "${domains}"

    fi

    if [[ ${chosen_cb_options} == *"06"* ]]; then
      # SHOW-INSTALLED-CERTIFICATES
      certbot_show_certificates_info

    fi

    prompt_return_or_finish
    certbot_helper_menu

  fi

  menu_main_options

}
