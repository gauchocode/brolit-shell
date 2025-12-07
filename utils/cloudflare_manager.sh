#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.4
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
    "10)" "WAF CONFIGURATION"
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

    if [[ ${chosen_cf_options} == *"10"* ]]; then

      # WAF CONFIGURATION
      cloudflare_waf_configuration_menu

    fi

    prompt_return_or_finish
    cloudflare_manager_menu

  fi

  menu_main_options

}

function cloudflare_waf_configuration_menu() {

  local waf_options
  local chosen_waf_option
  local root_domain

  log_subsection "Cloudflare WAF Configuration"

  waf_options=(
    "01)" "VIEW ALL WAF SETTINGS"
    "02)" "SECURITY LEVEL"
    "03)" "BOT FIGHT MODE"
    "04)" "BROWSER INTEGRITY CHECK"
    "05)" "CHALLENGE PASSAGE TIME"
    "06)" "WAF MANAGED RULESET (FREE)"
    "07)" "CUSTOM FIREWALL RULES"
    "08)" "IP ACCESS RULES"
  )

  chosen_waf_option="$(whiptail --title "WAF CONFIGURATION" --menu "Choose an option:" 20 78 10 "${waf_options[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?

  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_waf_option} == *"01"* ]]; then

      # VIEW ALL WAF SETTINGS
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Verify domain exists first
        if ! cloudflare_domain_exists "${root_domain}"; then
          display --indent 6 --text "- Verifying domain" --result "FAIL" --color RED
          display --indent 8 --text "Domain not found in Cloudflare account" --tcolor RED
        else
          cloudflare_view_all_waf_settings "${root_domain}"
          prompt_return_or_finish
        fi

      fi

    fi

    if [[ ${chosen_waf_option} == *"02"* ]]; then

      # SECURITY LEVEL
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Verify domain exists first
        if ! cloudflare_domain_exists "${root_domain}"; then
          display --indent 6 --text "- Verifying domain" --result "FAIL" --color RED
          display --indent 8 --text "Domain not found in Cloudflare account" --tcolor RED
        else

          # Show current value first
          local current_security_level
          current_security_level="$(cloudflare_get_security_level "${root_domain}")"
          if [[ $? -eq 0 ]]; then
            display --indent 6 --text "- Current Security Level: ${current_security_level}" --tcolor YELLOW
          fi

          local security_levels=(
            "01)" "off - No security checking"
            "02)" "essentially_off - Minimal security"
            "03)" "low - Low security"
            "04)" "medium - Medium security (default)"
            "05)" "high - High security"
            "06)" "under_attack - Under attack mode (I'm Under Attack!)"
          )

          local chosen_security_level

          chosen_security_level="$(whiptail --title "SECURITY LEVEL" --menu "Current: ${current_security_level}\n\nSelect new security level:" 20 78 10 "${security_levels[@]}" 3>&1 1>&2 2>&3)"

          if [[ $? -eq 0 ]]; then
            # Extract the value from the selection
            local security_value
            case ${chosen_security_level} in
              *"01"*) security_value="off" ;;
              *"02"*) security_value="essentially_off" ;;
              *"03"*) security_value="low" ;;
              *"04"*) security_value="medium" ;;
              *"05"*) security_value="high" ;;
              *"06"*) security_value="under_attack" ;;
            esac

            cloudflare_set_security_level "${root_domain}" "${security_value}"
          fi

        fi

      fi

    fi

    if [[ ${chosen_waf_option} == *"03"* ]]; then

      # BOT FIGHT MODE
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Verify domain exists first
        if ! cloudflare_domain_exists "${root_domain}"; then
          display --indent 6 --text "- Verifying domain" --result "FAIL" --color RED
          display --indent 8 --text "Domain not found in Cloudflare account" --tcolor RED
        else

          # Show current value first
          local current_bot_fight
          current_bot_fight="$(cloudflare_get_bot_fight_mode "${root_domain}")"
          if [[ $? -eq 0 ]]; then
            display --indent 6 --text "- Current Bot Fight Mode: ${current_bot_fight}" --tcolor YELLOW
          fi

          local bot_fight_options=(
            "01)" "on - Enable Bot Fight Mode"
            "02)" "off - Disable Bot Fight Mode"
          )

          local chosen_bot_fight

          chosen_bot_fight="$(whiptail --title "BOT FIGHT MODE" --menu "Current: ${current_bot_fight}\n\nSelect new status:" 20 78 10 "${bot_fight_options[@]}" 3>&1 1>&2 2>&3)"

          if [[ $? -eq 0 ]]; then
            local bot_fight_value
            case ${chosen_bot_fight} in
              *"01"*) bot_fight_value="on" ;;
              *"02"*) bot_fight_value="off" ;;
            esac

            cloudflare_set_bot_fight_mode "${root_domain}" "${bot_fight_value}"
          fi

        fi

      fi

    fi

    if [[ ${chosen_waf_option} == *"04"* ]]; then

      # BROWSER INTEGRITY CHECK
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Verify domain exists first
        if ! cloudflare_domain_exists "${root_domain}"; then
          display --indent 6 --text "- Verifying domain" --result "FAIL" --color RED
          display --indent 8 --text "Domain not found in Cloudflare account" --tcolor RED
        else

          # Show current value first
          local current_browser_check
          current_browser_check="$(cloudflare_get_browser_check "${root_domain}")"
          if [[ $? -eq 0 ]]; then
            display --indent 6 --text "- Current Browser Integrity Check: ${current_browser_check}" --tcolor YELLOW
          fi

          local browser_check_options=(
            "01)" "on - Enable Browser Integrity Check"
            "02)" "off - Disable Browser Integrity Check"
          )

          local chosen_browser_check

          chosen_browser_check="$(whiptail --title "BROWSER INTEGRITY CHECK" --menu "Current: ${current_browser_check}\n\nSelect new status:" 20 78 10 "${browser_check_options[@]}" 3>&1 1>&2 2>&3)"

          if [[ $? -eq 0 ]]; then
            local browser_check_value
            case ${chosen_browser_check} in
              *"01"*) browser_check_value="on" ;;
              *"02"*) browser_check_value="off" ;;
            esac

            cloudflare_set_browser_check "${root_domain}" "${browser_check_value}"
          fi

        fi

      fi

    fi

    if [[ ${chosen_waf_option} == *"05"* ]]; then

      # CHALLENGE PASSAGE TIME
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Verify domain exists first
        if ! cloudflare_domain_exists "${root_domain}"; then
          display --indent 6 --text "- Verifying domain" --result "FAIL" --color RED
          display --indent 8 --text "Domain not found in Cloudflare account" --tcolor RED
        else

          # Show current value first
          local current_challenge_ttl
          current_challenge_ttl="$(cloudflare_get_challenge_ttl "${root_domain}")"
          if [[ $? -eq 0 ]]; then
            display --indent 6 --text "- Current Challenge TTL: ${current_challenge_ttl} seconds" --tcolor YELLOW
          fi

          local challenge_ttl_options=(
            "01)" "300 - 5 minutes"
            "02)" "900 - 15 minutes"
            "03)" "1800 - 30 minutes"
            "04)" "2700 - 45 minutes"
            "05)" "3600 - 1 hour"
            "06)" "7200 - 2 hours"
            "07)" "10800 - 3 hours"
            "08)" "14400 - 4 hours"
            "09)" "28800 - 8 hours"
            "10)" "43200 - 12 hours"
            "11)" "86400 - 24 hours"
          )

          local chosen_challenge_ttl

          chosen_challenge_ttl="$(whiptail --title "CHALLENGE PASSAGE TIME" --menu "Current: ${current_challenge_ttl} seconds\n\nSelect new value:" 20 78 12 "${challenge_ttl_options[@]}" 3>&1 1>&2 2>&3)"

          if [[ $? -eq 0 ]]; then
            local challenge_ttl_value
            case ${chosen_challenge_ttl} in
              *"01"*) challenge_ttl_value="300" ;;
              *"02"*) challenge_ttl_value="900" ;;
              *"03"*) challenge_ttl_value="1800" ;;
              *"04"*) challenge_ttl_value="2700" ;;
              *"05"*) challenge_ttl_value="3600" ;;
              *"06"*) challenge_ttl_value="7200" ;;
              *"07"*) challenge_ttl_value="10800" ;;
              *"08"*) challenge_ttl_value="14400" ;;
              *"09"*) challenge_ttl_value="28800" ;;
              *"10"*) challenge_ttl_value="43200" ;;
              *"11"*) challenge_ttl_value="86400" ;;
            esac

            cloudflare_set_challenge_ttl "${root_domain}" "${challenge_ttl_value}"
          fi

        fi

      fi

    fi

    if [[ ${chosen_waf_option} == *"06"* ]]; then

      # WAF MANAGED RULESET
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Verify domain exists first
        if ! cloudflare_domain_exists "${root_domain}"; then
          display --indent 6 --text "- Verifying domain" --result "FAIL" --color RED
          display --indent 8 --text "Domain not found in Cloudflare account" --tcolor RED
        else

          # Show current value first
          local current_waf_status
          current_waf_status="$(cloudflare_get_waf_managed_ruleset "${root_domain}")"
          if [[ $? -eq 0 ]]; then
            display --indent 6 --text "- Current WAF Managed Ruleset: ${current_waf_status}" --tcolor YELLOW
          fi

          local waf_ruleset_options=(
            "01)" "on - Enable WAF Free Managed Ruleset"
            "02)" "off - Disable WAF Free Managed Ruleset"
          )

          local chosen_waf_ruleset

          chosen_waf_ruleset="$(whiptail --title "WAF MANAGED RULESET" --menu "Current: ${current_waf_status}\n\nSelect new status:" 20 78 10 "${waf_ruleset_options[@]}" 3>&1 1>&2 2>&3)"

          if [[ $? -eq 0 ]]; then
            local waf_ruleset_value
            case ${chosen_waf_ruleset} in
              *"01"*) waf_ruleset_value="on" ;;
              *"02"*) waf_ruleset_value="off" ;;
            esac

            cloudflare_set_waf_managed_ruleset "${root_domain}" "${waf_ruleset_value}"
          fi

        fi

      fi

    fi

    if [[ ${chosen_waf_option} == *"07"* ]]; then

      # CUSTOM FIREWALL RULES
      cloudflare_custom_rules_menu

    fi

    if [[ ${chosen_waf_option} == *"08"* ]]; then

      # IP ACCESS RULES
      cloudflare_ip_access_rules_menu

    fi

    prompt_return_or_finish
    cloudflare_waf_configuration_menu

  fi

}

function cloudflare_custom_rules_menu() {

  local custom_rules_options
  local chosen_custom_rule_option
  local root_domain

  custom_rules_options=(
    "01)" "LIST CUSTOM RULES"
    "02)" "CREATE CUSTOM RULE"
    "03)" "DELETE CUSTOM RULE"
  )

  chosen_custom_rule_option="$(whiptail --title "CUSTOM FIREWALL RULES" --menu "Choose an option (max 5 rules on Free plan):" 20 78 10 "${custom_rules_options[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?

  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_custom_rule_option} == *"01"* ]]; then

      # LIST CUSTOM RULES
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        if ! cloudflare_domain_exists "${root_domain}"; then
          display --indent 6 --text "- Verifying domain" --result "FAIL" --color RED
          display --indent 8 --text "Domain not found in Cloudflare account" --tcolor RED
        else
          cloudflare_list_custom_rules "${root_domain}"
        fi
      fi

    fi

    if [[ ${chosen_custom_rule_option} == *"02"* ]]; then

      # CREATE CUSTOM RULE
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Verify domain exists first
        if ! cloudflare_domain_exists "${root_domain}"; then
          display --indent 6 --text "- Verifying domain" --result "FAIL" --color RED
          display --indent 8 --text "Domain not found in Cloudflare account" --tcolor RED
        else

          local rule_name
          local rule_expression
          local rule_action

          rule_name="$(whiptail_input "Rule Name" "Enter a name for this rule:" "")"
          exitstatus=$?

          if [[ ${exitstatus} -eq 0 ]]; then

            rule_expression="$(whiptail_input "Rule Expression" "Enter the rule expression (e.g., ip.src eq 1.2.3.4):" "")"
            exitstatus=$?

            if [[ ${exitstatus} -eq 0 ]]; then

              local action_options=(
                "01)" "block - Block the request"
                "02)" "challenge - Legacy CAPTCHA challenge"
                "03)" "js_challenge - JavaScript challenge"
                "04)" "managed_challenge - Managed challenge (recommended)"
                "05)" "allow - Allow the request"
                "06)" "log - Log only (no action)"
              )

              local chosen_action
              chosen_action="$(whiptail --title "RULE ACTION" --menu "Select the action:" 20 78 10 "${action_options[@]}" 3>&1 1>&2 2>&3)"

              if [[ $? -eq 0 ]]; then
                case ${chosen_action} in
                  *"01"*) rule_action="block" ;;
                  *"02"*) rule_action="challenge" ;;
                  *"03"*) rule_action="js_challenge" ;;
                  *"04"*) rule_action="managed_challenge" ;;
                  *"05"*) rule_action="allow" ;;
                  *"06"*) rule_action="log" ;;
                esac

                cloudflare_create_custom_rule "${root_domain}" "${rule_name}" "${rule_expression}" "${rule_action}"
              fi

            fi

          fi

        fi

      fi

    fi

    if [[ ${chosen_custom_rule_option} == *"03"* ]]; then

      # DELETE CUSTOM RULE
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Verify domain exists first
        if ! cloudflare_domain_exists "${root_domain}"; then
          display --indent 6 --text "- Verifying domain" --result "FAIL" --color RED
          display --indent 8 --text "Domain not found in Cloudflare account" --tcolor RED
        else

          local rule_id
          rule_id="$(whiptail_input "Rule ID" "Enter the rule ID to delete:" "")"
          [[ $? -eq 0 ]] && cloudflare_delete_custom_rule "${root_domain}" "${rule_id}"

        fi

      fi

    fi

    prompt_return_or_finish
    cloudflare_custom_rules_menu

  fi

}

function cloudflare_ip_access_rules_menu() {

  local ip_rules_options
  local chosen_ip_rule_option
  local root_domain

  ip_rules_options=(
    "01)" "LIST IP ACCESS RULES"
    "02)" "ADD IP ACCESS RULE"
    "03)" "DELETE IP ACCESS RULE"
  )

  chosen_ip_rule_option="$(whiptail --title "IP ACCESS RULES" --menu "Choose an option:" 20 78 10 "${ip_rules_options[@]}" 3>&1 1>&2 2>&3)"
  exitstatus=$?

  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_ip_rule_option} == *"01"* ]]; then

      # LIST IP ACCESS RULES
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        if ! cloudflare_domain_exists "${root_domain}"; then
          display --indent 6 --text "- Verifying domain" --result "FAIL" --color RED
          display --indent 8 --text "Domain not found in Cloudflare account" --tcolor RED
        else
          cloudflare_list_ip_access_rules "${root_domain}"
        fi
      fi

    fi

    if [[ ${chosen_ip_rule_option} == *"02"* ]]; then

      # ADD IP ACCESS RULE
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Verify domain exists first
        if ! cloudflare_domain_exists "${root_domain}"; then
          display --indent 6 --text "- Verifying domain" --result "FAIL" --color RED
          display --indent 8 --text "Domain not found in Cloudflare account" --tcolor RED
        else

          local ip_address
          local ip_action
          local ip_note

          ip_address="$(whiptail_input "IP Address" "Enter the IP address (e.g., 1.2.3.4):" "")"
          exitstatus=$?

          if [[ ${exitstatus} -eq 0 ]]; then

            local ip_action_options=(
              "01)" "block - Block the IP"
              "02)" "challenge - Challenge the IP"
              "03)" "whitelist - Allow the IP (bypass security)"
              "04)" "js_challenge - JavaScript challenge"
              "05)" "managed_challenge - Managed challenge"
            )

            local chosen_ip_action
            chosen_ip_action="$(whiptail --title "IP ACTION" --menu "Select the action:" 20 78 10 "${ip_action_options[@]}" 3>&1 1>&2 2>&3)"

            if [[ $? -eq 0 ]]; then
              case ${chosen_ip_action} in
                *"01"*) ip_action="block" ;;
                *"02"*) ip_action="challenge" ;;
                *"03"*) ip_action="whitelist" ;;
                *"04"*) ip_action="js_challenge" ;;
                *"05"*) ip_action="managed_challenge" ;;
              esac

              ip_note="$(whiptail_input "Note (optional)" "Enter a note for this rule:" "")"
              cloudflare_add_ip_access_rule "${root_domain}" "${ip_address}" "${ip_action}" "${ip_note}"
            fi

          fi

        fi

      fi

    fi

    if [[ ${chosen_ip_rule_option} == *"03"* ]]; then

      # DELETE IP ACCESS RULE
      root_domain="$(whiptail_input "Root Domain" "Insert the root domain, example: mydomain.com" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Verify domain exists first
        if ! cloudflare_domain_exists "${root_domain}"; then
          display --indent 6 --text "- Verifying domain" --result "FAIL" --color RED
          display --indent 8 --text "Domain not found in Cloudflare account" --tcolor RED
        else

          local rule_id
          rule_id="$(whiptail_input "Rule ID" "Enter the rule ID to delete:" "")"
          [[ $? -eq 0 ]] && cloudflare_delete_ip_access_rule "${root_domain}" "${rule_id}"

        fi

      fi

    fi

    prompt_return_or_finish
    cloudflare_ip_access_rules_menu

  fi

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
