#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.60-beta
################################################################################
#
# Certbot Helper: Certbot functions.
#
# Ref: https://certbot.eff.org/docs/using.html#certbot-commands
#
################################################################################

################################################################################
# Install certificate with certbot
#
# Arguments:
#  $1 = ${email}
#  $2 = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_install() {

  local email=$1
  local domains=$2

  local certbot_result

  log_event "debug" "Running: certbot --nginx --non-interactive --agree-tos --redirect -m ${email} -d ${domains}" "false"

  certbot --nginx --non-interactive --agree-tos --redirect -m "${email}" -d "${domains}" --quiet

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
    certbot --nginx --non-interactive --agree-tos --redirect -m "${email}" -d "${domains}" --quiet

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

################################################################################
# Delete old certificate config
#
# Arguments:
#  $1 = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_delete_old_config() {

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

################################################################################
# Expand certificate
#
# Arguments:
#  $1 = ${email}
#  $2 = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_expand() {

  local email=$1
  local domains=$2

  log_event "debug" "Running: certbot --nginx --non-interactive --agree-tos --expand --redirect -m ${email} -d ${domains}" "false"

  certbot --nginx --non-interactive --agree-tos --expand --redirect -m "${email}" -d "${domains}" --quiet

  certbot_result=$?
  if [[ ${certbot_result} -eq 0 ]]; then

    log_event "info" "Certificate installation for ${domains} ok" "false"
    display --indent 6 --text "- Certificate installation" --result "DONE" --color GREEN

  else

    log_event "error" "Certificate installation for ${domains} failed!" "false"
    display --indent 6 --text "- Installing certificate on domains" --result "FAIL" --color RED

  fi

}

################################################################################
# Expand certificate
#
# Arguments:
#  $1 = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_renew() {

  local domains=$1

  log_event "debug" "Running: certbot renew -d ${domains}" "false"

  certbot renew -d "${domains}"

}

################################################################################
# Test certificate renew
#
# Arguments:
#  $1 = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_renew_test() {

  local domains=$1

  # Test renew for all installed certificates

  log_event "debug" "Running: certbot renew --dry-run -d ${domains}" "false"

  certbot renew --dry-run -d "${domains}"

}

################################################################################
# Certificate force renew
#
# Arguments:
#  $1 = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_force_renew() {

  local domains=$1

  log_event "debug" "Running: certbot --nginx --non-interactive --agree-tos --force-renewal --redirect -m ${email} -d ${domains}" "false"

  certbot --nginx --non-interactive --agree-tos --force-renewal --redirect -m "${email}" -d "${domains}"

}

################################################################################
# Certbot installer menu
#
# Arguments:
#  $1 = ${email}
#  $2 = ${domains}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function certbot_helper_installer_menu() {

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
      #root_domain=$(cloudflare_ask_rootdomain "${domains}")

      # TODO: list entries to add proxy on cloudflare records
      #cloudflare_set_record "${root_domain}" "" "true"

      # Changing SSL Mode flor Cloudflare record
      #cloudflare_set_ssl_mode "${root_domain}" "full"

    fi

    prompt_return_or_finish

  fi

}

################################################################################
# Certbot install certificate with cloudflare
#
# Arguments:
#  $1 = ${email}
#  $2 = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certonly_cloudflare() {

  # IMPORTANT: maybe we could create a certbot_cloudflare_certificate that runs first the nginx certbot
  # and then the certonly with cloudflare credentials

  # Ref: https://mangolassi.it/topic/18355/setup-letsencrypt-certbot-with-cloudflare-dns-authentication-ubuntu/2

  local email=$1
  local domains=$2

  log_event "debug" "Running: certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf -m ${email} -d ${domains} --preferred-challenges dns-01" "false"

  certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf -m "${email}" -d "${domains}" --preferred-challenges dns-01

  # Maybe add a non interactive mode?
  # certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf --non-interactive --agree-tos --redirect -m ${EMAIL} -d ${DOMAINS} --preferred-challenges dns-01

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
    certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.cloudflare.conf -m "${email}" -d "${domains}" --preferred-challenges dns-01

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

################################################################################
# Show certificates info
#
# Arguments:
#  $1 = ${domains}
#
# Outputs:
#   certificates info.
################################################################################

function certbot_show_certificates_info() {

  log_event "debug" "Running: certbot certificates" "false"

  certbot certificates

}

################################################################################
# Show certificates expiration date
#
# Arguments:
#  $1 = ${domains}
#
# Outputs:
#   list with certificates expiration dates.
################################################################################

function certbot_show_domain_certificates_expiration_date() {

  local domains=$1

  log_event "debug" "Running: certbot certificates --cert-name ${domains}" "false"

  certbot certificates --cert-name "${domains}" | grep 'Expiry' | cut -d ':' -f2 | cut -d ' ' -f2

}

################################################################################
# Show certificates valid days
#
# Arguments:
#  $1 = ${domains} - (domain.com,www.domain.com)
#
# Outputs:
#   ${cert_days} if ok, "no-cert" on error.
################################################################################

# TODO: Awful code, need a refactor
function certbot_certificate_valid_days() {

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

  log_event "info" "Certificate valid for: ${cert_days} days" "false"

  # Return
  echo "${cert_days}"

}

################################################################################
# Get certificate valid days
#
# Arguments:
#  $1 = ${domains}
#
# Outputs:
#  ${cert_days} if ok, "no-cert" on error.
################################################################################

function certbot_certificate_get_valid_days() {

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

################################################################################
# Delete certificate with certbot
#
# Arguments:
#  $1 = ${domains}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function certbot_certificate_delete() {

  local domains=$1

  if [[ -z "${domains}" ]]; then

    #Run certbot delete wizard
    certbot --nginx delete

  else

    certbot --nginx delete --cert-name "${domains}" --quiet

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Log
      clear_last_line
      clear_last_line
      clear_last_line
      clear_last_line
      clear_last_line
      log_event "debug" "Running: certbot delete --cert-name ${domains}" "false"
      display --indent 6 --text "- Deleting certificate for ${domains}" --result "DONE" --color GREEN

    else

      # Log
      log_event "error" "Running: certbot delete --cert-name ${domains}" "false"
      display --indent 6 --text "- Deleting certificate for ${domains}" --result "FAIL" --color RED
      display --indent 8 --text "Please read the log file" --tcolor RED

      return 1

    fi

  fi

}

################################################################################
# Certbot ask domains
#
# Arguments:
#  none
#
# Outputs:
#  ${domains} if ok, 1 on error.
################################################################################

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
