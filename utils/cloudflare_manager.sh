#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.1
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

      root_domain="$(whiptail --title "Root Domain" --inputbox "Insert the root domain, example: mydomain.com" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?

      if [[ ${exitstatus} -eq 0 ]]; then

        cloudflare_set_development_mode "${root_domain}" "on"

      fi

    fi

    if [[ ${chosen_cf_options} == *"02"* ]]; then

      # DELETE CACHE

      root_domain="$(whiptail --title "Root Domain" --inputbox "Insert the root domain, example: mydomain.com" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?

      if [[ ${exitstatus} -eq 0 ]]; then

        cloudflare_clear_cache "${root_domain}"

      fi

    fi

    if [[ ${chosen_cf_options} == *"03"* ]]; then

      # ENABLE CF PROXY

      dns_entry="$(whiptail --title "DNS Entry" --inputbox "Insert the entry you want to work with, example: www.mydomain.com" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?

      if [[ ${exitstatus} -eq 0 ]]; then

        root_domain="$(domain_get_root "${dns_entry}")"

        cur_ip="${SERVER_IP}"

        cloudflare_update_record "${root_domain}" "${dns_entry}" "A" "enable" "${cur_ip}"

      fi

    fi

    if [[ ${chosen_cf_options} == *"04"* ]]; then

      # DISABLE CF PROXY

      dns_entry="$(whiptail --title "DNS Entry" --inputbox "Insert the entry you want to work with, example: www.mydomain.com" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?

      if [[ ${exitstatus} -eq 0 ]]; then

        root_domain="$(domain_get_root "${dns_entry}")"

        cur_ip="${SERVER_IP}"

        cloudflare_update_record "${root_domain}" "${dns_entry}" "A" "disable" "${cur_ip}"

      fi

    fi

    if [[ ${chosen_cf_options} == *"05"* ]]; then

      # SET SSL MODE

      root_domain="$(whiptail --title "Root Domain" --inputbox "Insert the root domain, example: mydomain.com" 10 60 3>&1 1>&2 2>&3)"
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
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          log_event "info" "SSL Mode selected: ${chosen_ssl_mode}" "true"

          cloudflare_set_ssl_mode "${root_domain}" "${chosen_ssl_mode}"

        fi

      fi

    fi

    if [[ ${chosen_cf_options} == *"06"* ]]; then

      # SET CACHE TTL VALUE

      root_domain="$(whiptail --title "Root Domain" --inputbox "Insert the root domain, example: mydomain.com" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?

      if [[ ${exitstatus} -eq 0 ]]; then

        cloudflare_set_cache_ttl_value "${root_domain}" "0"

      fi

    fi

    if [[ ${chosen_cf_options} == *"07"* ]]; then

      # ADD/UPDATE A RECORD

      local dns_entry ip_entry

      dns_entry="$(whiptail --title "DNS Entry" --inputbox "Insert the subdomain you want to add/update, example: www.mydomain.com" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?

      if [[ ${exitstatus} -eq 0 ]]; then

        ip_entry="$(whiptail --title "DNS Entry" --inputbox "Insert the IP you want to work with. Default: current server IP." 20 78 10 "${SERVER_IP}" 3>&1 1>&2 2>&3)"
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

      dns_entry="$(whiptail --title "DNS Entry" --inputbox "Insert the subdomain you want to add/update, example: www.mydomain.com" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?

      if [[ ${exitstatus} -eq 0 ]]; then

        content_entry="$(whiptail --title "DNS Entry" --inputbox "Insert the sub/domain you want to work with." 10 60 3>&1 1>&2 2>&3)"
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

      dns_entry="$(whiptail --title "DNS Entry" --inputbox "Insert the entry you want to work with, example: www.mydomain.com" 10 60 3>&1 1>&2 2>&3)"
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
  # $1 = ${root_domain} (could be empty)

  local root_domain="${1}"

  if [[ -z "${root_domain}" ]]; then

    root_domain="$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the project (Only for Cloudflare API). Example: broobe.com" 10 60 3>&1 1>&2 2>&3)"

  else

    root_domain="$(whiptail --title "Root Domain" --inputbox "Insert the root domain of the project (Only for Cloudflare API). Example: broobe.com" 10 60 "${root_domain}" 3>&1 1>&2 2>&3)"

  fi

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Return
    echo "${root_domain}"

    return 0

  else

    return 1

  fi

}

function cloudflare_ask_subdomains() {

  # TODO: MAKE IT WORKS

  # Parameters
  # $1 = ${subdomains} optional to select default option (could be empty)

  local subdomains="${1}"

  subdomains="$(whiptail --title "Cloudflare Subdomains" --inputbox "Insert the subdomains you want to update in Cloudflare (comma separated). Example: www.broobe.com,broobe.com" 10 60 "${DOMAIN}" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  
  if [[ ${exitstatus} -eq 0 ]]; then

    log_event "info" "Setting subdomains: ${subdomains}" "false"

    # Return
    echo "${subdomains}"

  else
    return 1

  fi

}
