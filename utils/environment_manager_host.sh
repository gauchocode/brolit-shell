#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.6
################################################################################
#
# Host Environment Manager: Manage host-based services, optimizations, and utilities.
#
################################################################################

################################################################################
# Host Environment Main Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function environment_manager_host_menu() {

  local host_env_options
  local chosen_host_env_option

  log_section "Host Environment Manager"

  host_env_options=(
    "01)" "INSTALLERS AND CONFIGURATORS"
    "02)" "OPTIMIZATIONS"
    "03)" "SECURITY TOOLS"
    "04)" "SYSTEM UTILITIES"
  )

  chosen_host_env_option="$(whiptail --title "HOST ENVIRONMENT MANAGER" --menu "\nManage host-based services:\n" 20 78 10 "${host_env_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # INSTALLERS AND CONFIGURATORS
    [[ ${chosen_host_env_option} == *"01"* ]] && host_installers_and_configurators_menu

    # OPTIMIZATIONS
    [[ ${chosen_host_env_option} == *"02"* ]] && host_optimizations_menu

    # SECURITY TOOLS
    [[ ${chosen_host_env_option} == *"03"* ]] && host_security_tools_menu

    # SYSTEM UTILITIES
    [[ ${chosen_host_env_option} == *"04"* ]] && host_system_utilities_menu

    # Return to this menu
    prompt_return_or_finish
    environment_manager_host_menu

  fi

  # Return to environment manager menu
  environment_manager_menu

}

################################################################################
# Host Installers and Configurators Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function host_installers_and_configurators_menu() {

  # shellcheck source=${BROLIT_MAIN_DIR}/utils/installers_and_configurators.sh
  source "${BROLIT_MAIN_DIR}/utils/installers_and_configurators.sh"

  installers_and_configurators

}

################################################################################
# Host Optimizations Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function host_optimizations_menu() {

  local host_opt_options
  local chosen_host_opt_option

  log_subsection "Host Optimizations"

  host_opt_options=(
    "01)" "OPTIMIZE PHP-FPM"
    "02)" "OPTIMIZE NGINX"
    "03)" "OPTIMIZE MYSQL"
    "04)" "OPTIMIZE RAM USAGE"
    "05)" "DELETE OLD LOGS"
    "06)" "REMOVE OLD PACKAGES"
  )

  chosen_host_opt_option="$(whiptail --title "HOST OPTIMIZATIONS" --menu "\nSelect optimization:\n" 20 78 10 "${host_opt_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # OPTIMIZE PHP-FPM
    if [[ ${chosen_host_opt_option} == *"01"* ]]; then
      php_installed_versions="$(php_check_installed_version)"
      if [[ -n ${php_installed_versions} ]]; then
        php_v="$(php_select_version_to_work_with "${php_installed_versions}")"
        if [[ -n ${php_v} ]]; then
          php_fpm_optimizations "${php_v}"
          php_opcode_config "${php_v}"
        fi
      else
        display --indent 6 --text "- No PHP versions installed" --result "FAIL" --color RED
      fi
    fi

    # OPTIMIZE NGINX
    if [[ ${chosen_host_opt_option} == *"02"* ]]; then
      # TODO: Implement nginx_optimize_config function
      display --indent 6 --text "- Nginx optimization" --result "TODO" --color YELLOW
      display --indent 8 --text "Coming soon in next version" --tcolor YELLOW
    fi

    # OPTIMIZE MYSQL
    if [[ ${chosen_host_opt_option} == *"03"* ]]; then
      # TODO: Implement mysql_optimize_config function
      display --indent 6 --text "- MySQL optimization" --result "TODO" --color YELLOW
      display --indent 8 --text "Coming soon in next version" --tcolor YELLOW
    fi

    # OPTIMIZE RAM USAGE
    if [[ ${chosen_host_opt_option} == *"04"* ]]; then
      optimize_ram_usage
    fi

    # DELETE OLD LOGS
    if [[ ${chosen_host_opt_option} == *"05"* ]]; then
      delete_old_logs
    fi

    # REMOVE OLD PACKAGES
    if [[ ${chosen_host_opt_option} == *"06"* ]]; then
      packages_remove_old
    fi

    prompt_return_or_finish
    host_optimizations_menu

  fi

}

################################################################################
# Host Security Tools Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function host_security_tools_menu() {

  local security_options
  local chosen_security_option

  log_subsection "Security Tools"

  security_options=(
    "01)" "WORDFENCE-CLI MALWARE SCAN"
    "02)" "CLAMAV MALWARE SCAN"
    "03)" "CUSTOM MALWARE SCAN"
    "04)" "LYNIS SYSTEM AUDIT"
  )

  chosen_security_option="$(whiptail --title "SECURITY TOOLS" --menu "\nChoose a security tool:\n" 20 78 10 "${security_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    package_install_security_utils

    # WORDFENCE-CLI MALWARE SCAN
    [[ ${chosen_security_option} == *"01"* ]] && security_wordfence_scan_menu

    # CLAMAV MALWARE SCAN
    [[ ${chosen_security_option} == *"02"* ]] && security_clamav_scan_menu

    # CUSTOM MALWARE SCAN
    [[ ${chosen_security_option} == *"03"* ]] && security_custom_scan_menu

    # LYNIS SYSTEM AUDIT
    [[ ${chosen_security_option} == *"04"* ]] && security_system_audit_menu

    prompt_return_or_finish
    host_security_tools_menu

  fi

}

################################################################################
# Security: Wordfence Scan Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function security_wordfence_scan_menu() {

  local to_scan
  local include_all_files

  wordfencecli_installer

  startdir="${PROJECTS_PATH}"
  directory_browser "Select directory to scan" "${startdir}"

  if [[ -z ${filename} ]]; then
    return 1
  else
    to_scan="${filepath}/${filename}"

    whiptail --title "WORDFENCE-CLI MALWARE SCAN" --yesno "Do you want to include all files?" 10 60 3>&1 1>&2 2>&3
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      include_all_files="true"
    else
      include_all_files="false"
    fi

    wordfencecli_malware_scan "${to_scan}" "${include_all_files}"
  fi

}

################################################################################
# Security: ClamAV Scan Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function security_clamav_scan_menu() {

  local to_scan

  startdir="${PROJECTS_PATH}"
  directory_browser "Select directory to scan" "${startdir}"

  if [[ -z ${filename} ]]; then
    return 1
  else
    to_scan="${filepath}/${filename}"
    log_event "info" "Starting ClamAV scan on: ${to_scan}" "false"
    security_clamav_scan "${to_scan}"
  fi

}

################################################################################
# Security: Custom Scan Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function security_custom_scan_menu() {

  local to_scan

  startdir="${PROJECTS_PATH}"
  directory_browser "Select directory to scan" "${startdir}"

  if [[ -z ${filename} ]]; then
    return 1
  else
    to_scan="${filepath}/${filename}"
    log_event "info" "Starting custom scan on: ${to_scan}" "false"
    security_custom_scan "${to_scan}"
  fi

}

################################################################################
# Security: System Audit Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function security_system_audit_menu() {

  # shellcheck source=${BROLIT_MAIN_DIR}/libs/local/security_helper.sh
  source "${BROLIT_MAIN_DIR}/libs/local/security_helper.sh"

  security_lynis_audit

}

################################################################################
# Host System Utilities Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function host_system_utilities_menu() {

  local sys_util_options
  local chosen_sys_util_option

  log_subsection "System Utilities"

  sys_util_options=(
    "01)" "CHANGE SSH PORT"
    "02)" "CHANGE HOSTNAME"
    "03)" "ADD FLOATING IP"
    "04)" "CREATE SFTP USER"
    "05)" "DELETE SFTP USER"
    "06)" "RESET MYSQL ROOT PASSWORD"
    "07)" "BLACKLIST CHECKER"
    "08)" "BENCHMARK SERVER"
    "09)" "INSTALL ALIASES"
    "10)" "INSTALL WELCOME MESSAGE"
    "11)" "ADD BROLIT UI INTEGRATION"
    "12)" "ENABLE SSH ROOT ACCESS"
    "13)" "REGENERATE BORGMATIC TEMPLATES"
  )

  chosen_sys_util_option="$(whiptail --title "SYSTEM UTILITIES" --menu "\nSelect utility:\n" 20 78 10 "${sys_util_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # CHANGE SSH PORT
    if [[ ${chosen_sys_util_option} == *"01"* ]]; then
      new_ssh_port="$(whiptail --title "CHANGE SSH PORT" --inputbox "Insert the new SSH port:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && system_change_current_ssh_port "${new_ssh_port}"
    fi

    # CHANGE HOSTNAME
    if [[ ${chosen_sys_util_option} == *"02"* ]]; then
      new_server_hostname="$(whiptail --title "CHANGE SERVER HOSTNAME" --inputbox "Insert the new hostname:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && system_change_server_hostname "${new_server_hostname}"
    fi

    # ADD FLOATING IP
    if [[ ${chosen_sys_util_option} == *"03"* ]]; then
      floating_IP="$(whiptail --title "ADD FLOATING IP" --inputbox "Insert the floating IP:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && system_add_floating_IP "${floating_IP}"
    fi

    # CREATE SFTP USER
    if [[ ${chosen_sys_util_option} == *"04"* ]]; then
      log_subsection "SFTP Manager"
      sftp_user="$(whiptail --title "CREATE SFTP USER" --inputbox "Insert the username:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        directory_browser "Select a project to work with" "${PROJECTS_PATH}"
        if [[ ${filename} != "" && ${filepath} != "" ]]; then
          project_path="${filepath}/${filename}"
        fi
        sftp_create_user "${sftp_user}" "" "www-data" "${project_path}" "no"
      fi
    fi

    # DELETE SFTP USER
    if [[ ${chosen_sys_util_option} == *"05"* ]]; then
      log_subsection "SFTP Manager"
      sftp_user="$(whiptail --title "DELETE SFTP USER" --inputbox "Insert the username:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && sftp_delete_user "${sftp_user}"
    fi

    # RESET MYSQL ROOT PASSWORD
    if [[ ${chosen_sys_util_option} == *"06"* ]]; then
      db_root_psw="$(whiptail --title "MYSQL ROOT PASSWORD" --inputbox "Insert the new root password for MySQL:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        mysql_root_psw_change "${db_root_psw}"
      fi
    fi

    # BLACKLIST CHECKER
    if [[ ${chosen_sys_util_option} == *"07"* ]]; then
      IP_TO_TEST="$(whiptail --title "BLACKLIST CHECKER" --inputbox "Insert the IP or domain to check:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/tools/third-party/blacklist-checker/bl.sh
        source "${BROLIT_MAIN_DIR}/tools/third-party/blacklist-checker/bl.sh" "${IP_TO_TEST}"
      fi
    fi

    # BENCHMARK SERVER
    if [[ ${chosen_sys_util_option} == *"08"* ]]; then
      # shellcheck source=${BROLIT_MAIN_DIR}/tools/third-party/bench_scripts.sh
      source "${BROLIT_MAIN_DIR}/tools/third-party/bench_scripts.sh"
    fi

    # INSTALL ALIASES
    [[ ${chosen_sys_util_option} == *"09"* ]] && install_script_aliases

    # INSTALL WELCOME MESSAGE
    [[ ${chosen_sys_util_option} == *"10"* ]] && customize_ubuntu_login_message

    # ADD BROLIT UI INTEGRATION
    [[ ${chosen_sys_util_option} == *"11"* ]] && brolit_ssh_keygen "/root/pem"

    # ENABLE SSH ROOT ACCESS
    if [[ ${chosen_sys_util_option} == *"12"* ]]; then
      log_subsection "Enable SSH root access"
      sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        log_event "info" "Permit SSH root login" "false"
        display --indent 6 --text "- Permit SSH root login" --result "DONE" --color GREEN
        systemctl restart ssh
        sudo passwd
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
          clear_previous_lines "3"
          log_event "info" "Root password changed" "false"
          display --indent 6 --text "- Changing root password" --result "DONE" --color GREEN
        fi
      fi
    fi

    # REGENERATE BORGMATIC TEMPLATES
    if [[ ${chosen_sys_util_option} == *"13"* ]]; then
      borg_update_templates
    fi

    prompt_return_or_finish
    host_system_utilities_menu

  fi

}
