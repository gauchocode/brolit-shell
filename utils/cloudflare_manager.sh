#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.2-beta
#############################################################################

function cloudflare_manager_menu() {

  local cf_options
  local chosen_cf_options
  local root_domain

  cf_options=(
    "01)" "SET DEVELOPMENT MODE"
    "02)" "DELETE CACHE"
    "03)" "ENABLE CF PROXY"
    "04)" "DISABLE CF PROXY"
    "05)" "SET SSL MODE"
    "06)" "SET CACHE TTL VALUE"
    "07)" "ADD/UPDATE A RECORD"
    "08)" "ADD/UPDATE CNAME RECORD"
    "09)" "DELETE RECORD"
  )
  chosen_cf_options="$(whiptail --title "CLOUDFLARE MANAGER" --menu " " 20 78 10 "${cf_options[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?

  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_cf_options} == *"01"* ]]; then

      # SET DEVELOPMENT MODE
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"
      [[ $? -eq 0 ]] && cloudflare_set_development_mode "${root_domain}" "on"

    fi

    if [[ ${chosen_cf_options} == *"02"* ]]; then

      # DELETE CACHE
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"
      [[ $? -eq 0 ]] && cloudflare_clear_cache "${root_domain}"

    fi

    if [[ ${chosen_cf_options} == *"03"* ]]; then

      # ENABLE CF PROXY
      dns_entry="$(whiptail_input "DNS Entry" "Insert the entry you want to work with, example: www.mydomain.com" "")"
      exitstatus=$?

      if [[ ${exitstatus} -eq 0 ]]; then

        root_domain="$(domain_get_root "${dns_entry}")"
        cloudflare_update_record "${root_domain}" "${dns_entry}" "A" "enable" "${SERVER_IP}"

      fi

    fi

    if [[ ${chosen_cf_options} == *"04"* ]]; then

      # DISABLE CF PROXY
      dns_entry="$(whiptail_input "DNS Entry" "Insert the entry you want to work with, example: www.mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        root_domain="$(domain_get_root "${dns_entry}")"
        cloudflare_update_record "${root_domain}" "${dns_entry}" "A" "disable" "${SERVER_IP}"

      fi

    fi

    if [[ ${chosen_cf_options} == *"05"* ]]; then

      # SET SSL MODE
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Define array of SSL modes
        local ssl_modes=(
          "01)" "off"
          "02)" "flexible"
          "03)" "full"
          "04)" "strict"
        )

        local chosen_ssl_mode

        chosen_ssl_mode="$(whiptail --title "CLOUDFLARE SSL MODE" --menu "Select the new SSL mode:" 20 78 10 "${ssl_modes[@]}" 3>&1 1>&2 2>&3)"
        [[ $? -eq 0 ]] && cloudflare_set_ssl_mode "${root_domain}" "${chosen_ssl_mode}"

      fi

    fi

    if [[ ${chosen_cf_options} == *"06"* ]]; then

      # SET CACHE TTL VALUE
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"
      [[ $? -eq 0 ]] && cloudflare_set_cache_ttl_value "${root_domain}" "0"

    fi

    if [[ ${chosen_cf_options} == *"07"* ]]; then

      # ADD/UPDATE A RECORD
      local dns_entry
      local ip_entry
      dns_entry="$(whiptail_input "DNS Entry" "Insert the entry you want to work with, example: www.mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        ip_entry="$(whiptail --title "IP Entry" --inputbox "Insert the IP you want to work with. Default: current server IP." 20 78 10 "${SERVER_IP}" 3>&1 1>&2 2>&3)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          root_domain="$(domain_get_root "${dns_entry}")"

          cloudflare_set_record "${root_domain}" "${dns_entry}" "A" "enable" "${ip_entry}"
          #cloudflare_update_record "${root_domain}" "${dns_entry}" "A" "disabled" "${ip_entry}"

        fi

      fi

    fi

    if [[ ${chosen_cf_options} == *"08"* ]]; then

      # ADD/UPDATE CNAME RECORD
      local dns_entry content_entry

      dns_entry="$(whiptail_input "DNS Entry" "Insert the entry you want to work with, example: www.mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        content_entry="$(whiptail_input "DNS Entry" "Insert the entry you want to work with, example: www.mydomain.com" "")"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          root_domain="$(domain_get_root "${dns_entry}")"
          cloudflare_set_record "${root_domain}" "${dns_entry}" "A" "enable" "${content_entry}"
          #cloudflare_update_record "${root_domain}" "${dns_entry}" "CNAME" "disabled" "${content_entry}"

        fi

      fi

    fi

    if [[ ${chosen_cf_options} == *"09"* ]]; then

      # DELETE ENTRY
      dns_entry="$(whiptail_input "DNS Entry" "Insert the entry you want to work with, example: www.mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        root_domain="$(domain_get_root "${dns_entry}")"
        cloudflare_delete_record "${root_domain}" "${dns_entry}" "A"

      fi

    fi

    prompt_return_or_finish
    cloudflare_manager_menu

  fi

  menu_main_options

}

function cloudflare_tasks_handler() {

  local subtask="${1}"

  log_subsection "Cloudflare Manager"

  case ${subtask} in

  clear_cache)

    cloudflare_clear_cache "${DOMAIN}"

    exit
    ;;

  dev_mode)

    cloudflare_set_development_mode "${DOMAIN}" "${TVALUE}"

    exit
    ;;

  ssl_mode)

    cloudflare_set_ssl_mode "${DOMAIN}" "${TVALUE}"

    exit
    ;;

  *)

    log_event "error" "INVALID SUBTASK: ${subtask}" "true"

    exit
    ;;

  esac

}

function cloudflare_ask_rootdomain() {

  # TODO: check with CF API if root domain exists

  # Parameters
  # ${1} = ${suggested_root_domain} (could be empty)

  local suggested_root_domain="${1}"

  local root_domain

  root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "${suggested_root_domain}")"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 && -n ${root_domain} ]]; then

    # Return
    echo "${root_domain}" && return 0

  else

    return 1

  fi

}

function cloudflare_ask_subdomains() {

  # TODO: MAKE IT WORKS

  # Parameters
  # ${1} = ${subdomains} optional to select default option (could be empty)

  local subdomains="${1}"

  subdomains="$(whiptail_input "Cloudflare Subdomains" "Insert the subdomains you want to update in Cloudflare (comma separated). Example: www.gauchocode.com,gauchocode.com" "${DOMAIN}")"
  
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    log_event "info" "Setting subdomains: ${subdomains}" "false"

    # Return
    echo "${subdomains}" && return 0

  else

    return 1

  fi

}
