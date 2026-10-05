#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
################################################################################
#
# Domains Helper: useful utils to work with domains.
#
################################################################################

################################################################################
# Extract domain extension (from domain)
#
# Arguments:
#   ${1} = ${domain}
#
# Outputs:
#   ${domain_no_ext}
################################################################################

function domain_extract_extension() {

  local domain="${1}"

  local domain_extension
  local domain_no_ext

  domain_extension="$(domain_get_extension "${domain}")"
  domain_extension_output=$?
  if [[ ${domain_extension_output} -eq 0 ]]; then

    domain_no_ext=${domain%"$domain_extension"}

    # Log
    log_event "debug" "domain_no_ext: ${domain_no_ext}" "false"

    # Return
    echo "${domain_no_ext}"
    return 0

  else

    log_break "true"
    return 1

  fi

}

################################################################################
# Get root domain
#
# Arguments:
#   ${1} = ${domain}
#
# Outputs:
#   ${root_domain}
################################################################################

function domain_get_root() {

  local domain="${1}"

  local domain_extension
  local domain_no_ext

  # Get domain extension
  domain_extension="$(domain_get_extension "${domain}")"

  # Check result
  domain_extension_output=$?
  if [[ ${domain_extension_output} -eq 0 ]]; then

    # Remove domain extension
    domain_no_ext=${domain%"$domain_extension"}

    root_domain=${domain_no_ext##*.}${domain_extension}

    log_event "debug" "root_domain=${root_domain}" "false"

    # Return
    echo "${root_domain}"

    return 0

  else

    return 1

  fi

}

################################################################################
# Get subdomain part of domain
#
# Arguments:
#   ${1} = ${domain}
#
# Outputs:
#   ${subdomain_part}
################################################################################

function domain_get_subdomain_part() {

  local domain="${1}"

  local domain_extension
  local domain_no_ext
  local subdomain_part

  # Get Domain Ext
  domain_extension="$(domain_get_extension "${domain}")"

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

################################################################################
# Check if a name is a valid domain
#
# Arguments:
#   ${1} = ${name}
#
# Outputs:
#   0 if it is a domain with a supported TLD, 1 otherwise.
#
# Note: silent by design. Project directories under PROJECTS_PATH are not
# always domains: a folder may hold a docker-compose project with no public
# name. Reports like the certificate section must label those as "not a
# domain" instead of failing with an unsupported-TLD error.
################################################################################

function domain_is_valid() {

  local domain="${1}"

  # A domain always has at least one dot
  if [[ -z "${domain}" ]] || [[ "${domain}" != *.* ]]; then

    return 1

  fi

  # Quiet: no red FAIL display and no ERROR log for non-domain names
  domain_get_extension "${domain}" "quiet" > /dev/null 2>&1

}

################################################################################
# Get domain extension
#
# Arguments:
#   ${1} = ${domain}
#   ${2} = quiet (optional) - suppress the FAIL display and log the
#         unsupported-TLD message at debug level instead of error. Used by
#         read-only reports that iterate over PROJECTS_PATH, where folders
#         that are not domains are expected and must not raise an error.
#
# Outputs:
#   ${domain_ext}
################################################################################

function domain_get_extension() {

  local domain="${1}"
  local quiet="${2:-}"

  local first_lvl
  local next_lvl
  local domain_ext

  # Skipped in quiet mode: domain_is_valid() is a pure predicate, and one INFO
  # line per non-domain project folder on every report run is just noise.
  [[ "${quiet}" != "quiet" ]] && log_event "info" "Working with domain: ${domain}" "false"

  # Get first_lvl domain name
  first_lvl="$(cut -d'.' -f1 <<<"${domain}")"

  # Extract first_lvl
  domain_ext=${domain#"$first_lvl."}

  next_lvl="${first_lvl}"

  local -i count=0
  while ! grep --word-regexp --quiet ".${domain_ext}" "${BROLIT_MAIN_DIR}/config/domain_extension-list" && [ ! "${domain_ext#"$next_lvl"}" = "" ]; do

    # Remove next level domain-name
    domain_ext=${domain_ext#"$next_lvl."}
    next_lvl="$(cut -d'.' -f1 <<<"${domain_ext}")"

    count=("$count"+1)

  done

  if grep --word-regexp --quiet ".${domain_ext}" "${BROLIT_MAIN_DIR}/config/domain_extension-list"; then

    domain_ext=.${domain_ext}

    # Logging
    log_event "debug" "Extracting domain extension from ${domain}" "false"
    log_event "debug" "Domain extension extracted: ${domain_ext}" "false"

    # Return
    echo "${domain_ext}"

  else

    if [[ "${quiet}" == "quiet" ]]; then

      log_event "debug" "Domain extension not supported for '${domain}' (not a domain)." "false"

    else

      # Logging
      log_event "error" "Domain extension not supported for '${domain}'. If this is a valid TLD, add it to ${BROLIT_MAIN_DIR}/config/domain_extension-list and retry." "false"
      display --indent 6 --text "- Domain extension for ${domain}" --result "FAIL" --color RED
      display --indent 8 --text "TLD not in config/domain_extension-list, add it and retry"

    fi

    return 1

  fi

}

################################################################################
# Ask root domain
#
# Arguments:
#   ${1} = ${suggested_root_domain}
#
# Outputs:
#   ${root_domain}
################################################################################

function ask_root_domain() {

  local suggested_root_domain="${1}"

  local root_domain

  root_domain="$(whiptail --title "Root Domain" --inputbox "Confirm the root domain of the project." 10 60 "${suggested_root_domain}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Return
    echo "${root_domain}"

  fi

}