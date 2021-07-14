#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.44
################################################################################

function extract_domain_extension() {

  # Parameters
  # $1 = ${domain}

  local domain=$1

  local domain_extension
  local domain_no_ext

  domain_extension="$(get_domain_extension "${domain}")"
  domain_extension_output=$?
  if [[ ${domain_extension_output} -eq 0 ]]; then

    domain_no_ext=${domain%"$domain_extension"}

    # Logging
    log_event "debug" "domain_no_ext: ${domain_no_ext}"

    # Return
    echo "${domain_no_ext}"

  else

    log_break "true"
    return 1

  fi

}

function ask_root_domain() {

  # Parameters
  # $1 = ${suggested_root_domain}

  local suggested_root_domain=$1
  local root_domain

  root_domain="$(whiptail --title "Root Domain" --inputbox "Confirm the root domain of the project." 10 60 "${suggested_root_domain}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Return
    echo "${root_domain}"

  fi

}

function get_root_domain() {

  # Parameters
  # $1 = ${domain}

  local domain=$1

  local domain_extension
  local domain_no_ext

  # Get Domain Ext
  domain_extension="$(get_domain_extension "${domain}")"

  # Check result
  domain_extension_output=$?
  if [[ ${domain_extension_output} -eq 0 ]]; then

    # Remove domain extension
    domain_no_ext=${domain%"$domain_extension"}

    root_domain=${domain_no_ext##*.}${domain_extension}

    # Return
    echo "${root_domain}"

  else

    return 1

  fi

}

function get_subdomain_part() {

  # Parameters
  # $1 = ${domain}

  local domain=$1

  local domain_extension
  local domain_no_ext
  local subdomain_part

  # Get Domain Ext
  domain_extension="$(get_domain_extension "${domain}")"

  # Check result
  domain_extension_output=$?
  if [[ ${domain_extension_output} -eq 0 ]]; then

    # Remove domain extension
    domain_no_ext=${domain%"$domain_extension"}

    root_domain=${domain_no_ext##*.}${domain_extension}

    if [[ ${root_domain} != "${domain}" ]]; then

      subdomain_part=${domain//.$root_domain/}

      # Return
      echo "${subdomain_part}"

    else

      # Return
      echo ""

    fi

  else

    return 1

  fi

}

function get_domain_extension() {

  # Parameters
  # $1 = ${domain}

  local domain=$1

  local first_lvl
  local next_lvl
  local domain_ext

  log_event "info" "Working with domain: ${domain}" "false"

  # Get first_lvl domain name
  first_lvl="$(cut -d'.' -f1 <<<"${domain}")"

  # Extract first_lvl
  domain_ext=${domain#"$first_lvl."}

  next_lvl="${first_lvl}"

  local -i count=0
  while ! grep --word-regexp --quiet ".${domain_ext}" "${SFOLDER}/config/domain_extension-list" && [ ! "${domain_ext#"$next_lvl"}" = "" ]; do

    # Remove next level domain-name
    domain_ext=${domain_ext#"$next_lvl."}
    next_lvl="$(cut -d'.' -f1 <<<"${domain_ext}")"

    count=("$count"+1)

  done

  if grep --word-regexp --quiet ".${domain_ext}" "${SFOLDER}/config/domain_extension-list"; then

    domain_ext=.${domain_ext}

    # Logging
    log_event "debug" "Extracting domain extension from ${domain}."
    log_event "debug" "Domain extension extracted: ${domain_ext}"

    # Return
    echo "${domain_ext}"

  else

    # Logging
    log_event "error" "Extracting domain extension from ${domain}"

    return 1

  fi

}