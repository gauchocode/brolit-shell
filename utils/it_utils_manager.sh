#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.4
################################################################################

function it_utils_menu() {

  local it_util_options
  local chosen_it_util_options

  log_section "IT Utils"

  it_util_options=(
    "01)" "INSTALLERS AND CONFIGURATORS"
    "02)" "SECURITY TOOLS"
    "03)" "SERVER OPTIMIZATIONS"
    "04)" "SYSTEM CONFIGURATION"
    "05)" "SSH & USER MANAGEMENT"
    "06)" "MONITORING & DIAGNOSTICS"
    "07)" "CUSTOMIZATION & INTEGRATION"
    "08)" "BACKUP TOOLS"
  )
  chosen_it_util_options="$(whiptail --title "IT UTILS" --menu "Choose a script to Run" 20 78 10 "${it_util_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # INSTALLERS AND CONFIGURATORS
    [[ ${chosen_it_util_options} == *"01"* ]] && installers_and_configurators

    # SECURITY TOOLS
    [[ ${chosen_it_util_options} == *"02"* ]] && menu_security_utils

    # SERVER OPTIMIZATIONS
    if [[ ${chosen_it_util_options} == *"03"* ]]; then
      # shellcheck source=${BROLIT_MAIN_DIR}/utils/server_and_image_optimizations.sh
      source "${BROLIT_MAIN_DIR}/utils/server_and_image_optimizations.sh"
      server_optimizations_menu
    fi

    # SYSTEM CONFIGURATION
    [[ ${chosen_it_util_options} == *"04"* ]] && menu_system_configuration

    # SSH & USER MANAGEMENT
    [[ ${chosen_it_util_options} == *"05"* ]] && menu_ssh_user_management

    # MONITORING & DIAGNOSTICS
    [[ ${chosen_it_util_options} == *"06"* ]] && menu_monitoring_diagnostics

    # CUSTOMIZATION & INTEGRATION
    [[ ${chosen_it_util_options} == *"07"* ]] && menu_customization_integration

    # BACKUP TOOLS
    [[ ${chosen_it_util_options} == *"08"* ]] && menu_backup_tools

    prompt_return_or_finish
    it_utils_menu

  fi

  menu_main_options

}

function menu_security_utils() {

  # TODO: new options? https://upcloud.com/community/tutorials/scan-ubuntu-server-malware/

  local security_options chosen_security_options

  security_options=(
    "01)" "WORFENCE-CLI MALWARE SCAN"
    "02)" "CLAMAV MALWARE SCAN"
    "03)" "CUSTOM MALWARE SCAN"
    "04)" "LYNIS SYSTEM AUDIT"
  )
  chosen_security_options=$(whiptail --title "SECURITY TOOLS" --menu "Choose an option to run" 20 78 10 "${security_options[@]}" 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    package_install_security_utils

    # WORFENCE-CLI MALWARE SCAN
    [[ ${chosen_security_options} == *"01"* ]] && menu_security_wordfencecli_scan

    # CLAMAV MALWARE SCAN
    [[ ${chosen_security_options} == *"02"* ]] && menu_security_clamav_scan

    # CUSTOM MALWARE SCAN
    [[ ${chosen_security_options} == *"03"* ]] && menu_security_custom_scan

    # LYNIS SYSTEM AUDIT
    [[ ${chosen_security_options} == *"04"* ]] && menu_security_system_audit

    prompt_return_or_finish
    menu_security_utils

  fi

  menu_main_options

}

function menu_security_wordfencecli_scan() {

  local to_scan
  local include_all_files

  wordfencecli_installer

  startdir="${PROJECTS_PATH}"
  directory_browser "${menutitle}" "${startdir}"

  # If directory browser was cancelled
  if [[ -z ${filename} ]]; then

    # Return
    menu_security_utils

  else

    to_scan=$filepath"/"$filename

    whiptail --title "WORFENCE-CLI MALWARE SCAN" --yesno "Do you want to include all files?" 10 60 3>&1 1>&2 2>&3

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      include_all_files="true"
    else
      include_all_files="false"
    fi

    wordfencecli_malware_scan "${to_scan}" "${include_all_files}"

  fi

}

function menu_security_clamav_scan() {

  local to_scan

  startdir="${PROJECTS_PATH}"
  directory_browser "${menutitle}" "${startdir}"

  # If directory browser was cancelled
  if [[ -z ${filename} ]]; then

    # Return
    menu_security_utils

  else

    to_scan=$filepath"/"$filename

    log_event "info" "Starting clamav scan on: ${to_scan}" "false"

    security_clamav_scan "${to_scan}"

  fi

}

function menu_security_custom_scan() {

  local to_scan

  startdir="${PROJECTS_PATH}"
  directory_browser "${menutitle}" "${startdir}"

  # If directory browser was cancelled
  if [[ -z ${filename} ]]; then

    # Return
    menu_security_utils

  else

    to_scan=$filepath"/"$filename

    log_event "info" "Starting custom scan on: ${to_scan}" "false"

    security_custom_scan "${to_scan}"

  fi

}

################################################################################
# System Configuration Menu
################################################################################

function menu_system_configuration() {

  local system_config_options
  local chosen_system_config_option

  system_config_options=(
    "01)" "CHANGE HOSTNAME"
    "02)" "ADD FLOATING IP"
    "03)" "RESET MYSQL ROOT PSW"
  )

  chosen_system_config_option="$(whiptail --title "SYSTEM CONFIGURATION" --menu "Choose an option" 20 78 10 "${system_config_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # CHANGE HOSTNAME
    if [[ ${chosen_system_config_option} == *"01"* ]]; then
      new_server_hostname="$(whiptail --title "CHANGE SERVER HOSTNAME" --inputbox "Insert the new hostname:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && system_change_server_hostname "${new_server_hostname}"
    fi

    # ADD FLOATING IP
    if [[ ${chosen_system_config_option} == *"02"* ]]; then
      floating_IP="$(whiptail --title "ADD FLOATING IP" --inputbox "Insert the floating IP:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && system_add_floating_IP "${floating_IP}"
    fi

    # RESET MYSQL ROOT_PSW
    if [[ ${chosen_system_config_option} == *"03"* ]]; then
      db_root_psw="$(whiptail --title "MYSQL ROOT PASSWORD" --inputbox "Insert the new root password for MySQL:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/libs/mysql_helper.sh
        source "${BROLIT_MAIN_DIR}/libs/mysql_helper.sh"
        mysql_root_psw_change "${db_root_psw}"
      fi
    fi

    prompt_return_or_finish
    menu_system_configuration

  fi

  it_utils_menu

}

################################################################################
# SSH & User Management Menu
################################################################################

function menu_ssh_user_management() {

  local ssh_user_options
  local chosen_ssh_user_option

  ssh_user_options=(
    "01)" "CHANGE SSH PORT"
    "02)" "ENABLE SSH ROOT ACCESS"
    "03)" "CREATE SFTP USER"
    "04)" "DELETE SFTP USER"
  )

  chosen_ssh_user_option="$(whiptail --title "SSH & USER MANAGEMENT" --menu "Choose an option" 20 78 10 "${ssh_user_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # CHANGE SSH PORT
    if [[ ${chosen_ssh_user_option} == *"01"* ]]; then
      new_ssh_port="$(whiptail --title "CHANGE SSH PORT" --inputbox "Insert the new SSH port:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && system_change_current_ssh_port "${new_ssh_port}"
    fi

    # ENABLE SSH ROOT ACCESS
    if [[ ${chosen_ssh_user_option} == *"02"* ]]; then
      log_subsection "Enable ssh root access"

      sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        log_event "info" "Permit ssh root login" "false"
        display --indent 6 --text "- Permit ssh root login" --result "DONE" --color GREEN

        systemctl restart ssh

        # Change root password
        sudo passwd

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
          clear_previous_lines "3"
          log_event "info" "root password changed" "false"
          display --indent 6 --text "- Changing root password" --result "DONE" --color GREEN
        fi
      fi
    fi

    # CREATE SFTP USER
    if [[ ${chosen_ssh_user_option} == *"03"* ]]; then
      log_subsection "SFTP Manager"

      sftp_user="$(whiptail --title "CREATE SFTP USER" --inputbox "Insert the username:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        # Select project to work with
        directory_browser "Select a project to work with" "${PROJECTS_PATH}"
        # Directory_broser returns: $filepath and $filename
        if [[ ${filename} != "" && ${filepath} != "" ]]; then
          # Create and add folder permission
          project_path="${filepath}/${filename}"
        fi

        sftp_create_user "${sftp_user}" "" "www-data" "${project_path}" "no"
      fi
    fi

    # DELETE SFTP USER
    if [[ ${chosen_ssh_user_option} == *"04"* ]]; then
      log_subsection "SFTP Manager"

      sftp_user="$(whiptail --title "DELETE SFTP USER" --inputbox "Insert the username:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        sftp_delete_user "${sftp_user}"
      fi
    fi

    prompt_return_or_finish
    menu_ssh_user_management

  fi

  it_utils_menu

}

################################################################################
# Monitoring & Diagnostics Menu
################################################################################

function menu_monitoring_diagnostics() {

  local monitoring_options
  local chosen_monitoring_option

  monitoring_options=(
    "01)" "BLACKLIST CHECKER"
    "02)" "BENCHMARK SERVER"
  )

  chosen_monitoring_option="$(whiptail --title "MONITORING & DIAGNOSTICS" --menu "Choose an option" 20 78 10 "${monitoring_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # BLACKLIST CHECKER
    if [[ ${chosen_monitoring_option} == *"01"* ]]; then
      IP_TO_TEST="$(whiptail --title "BLACKLIST CHECKER" --inputbox "Insert the IP or the domain you want to check." 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/tools/third-party/blacklist-checker/bl.sh
        source "${BROLIT_MAIN_DIR}/tools/third-party/blacklist-checker/bl.sh" "${IP_TO_TEST}"
      fi
    fi

    # BENCHMARK SERVER
    if [[ ${chosen_monitoring_option} == *"02"* ]]; then
      # shellcheck source=${BROLIT_MAIN_DIR}/tools/bench_scripts.sh
      source "${BROLIT_MAIN_DIR}/tools/third-party/bench_scripts.sh"
    fi

    prompt_return_or_finish
    menu_monitoring_diagnostics

  fi

  it_utils_menu

}

################################################################################
# Customization & Integration Menu
################################################################################

function menu_customization_integration() {

  local customization_options
  local chosen_customization_option

  customization_options=(
    "01)" "INSTALL ALIASES"
    "02)" "INSTALL WELCOME MESSAGE"
    "03)" "ADD BROLIT UI INTEGRATION"
  )

  chosen_customization_option="$(whiptail --title "CUSTOMIZATION & INTEGRATION" --menu "Choose an option" 20 78 10 "${customization_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # INSTALL ALIASES
    [[ ${chosen_customization_option} == *"01"* ]] && install_script_aliases

    # INSTALL WELCOME MESSAGE
    [[ ${chosen_customization_option} == *"02"* ]] && customize_ubuntu_login_message

    # ADD BROLIT UI INTEGRATION
    [[ ${chosen_customization_option} == *"03"* ]] && brolit_ssh_keygen "/root/pem"

    prompt_return_or_finish
    menu_customization_integration

  fi

  it_utils_menu

}

################################################################################
# Backup Tools Menu
################################################################################

function menu_backup_tools() {

  local backup_tools_options
  local chosen_backup_tool_option

  backup_tools_options=(
    "01)" "REGENERATE BORGMATIC TEMPLATES"
  )

  chosen_backup_tool_option="$(whiptail --title "BACKUP TOOLS" --menu "Choose an option" 20 78 10 "${backup_tools_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # REGENERATE BORGMATIC TEMPLATES
    if [[ ${chosen_backup_tool_option} == *"01"* ]]; then
      # shellcheck source=${BROLIT_MAIN_DIR}/libs/borg_storage_controller.sh
      source "${BROLIT_MAIN_DIR}/libs/borg_storage_controller.sh"
      borg_update_templates
    fi

    # TODO: Add more backup tools options:
    # - TEST BORGMATIC CONFIGURATION (borgmatic_test_config)
    # - LIST BORGMATIC ARCHIVES (borg_list_archives)
    # - TEST STORAGE CONNECTION (storage_test_connection)
    # - VERIFY BACKUP INTEGRITY (storage_verify_backup_integrity)
    # - PRUNE OLD BACKUPS (borg_prune_archives)

    prompt_return_or_finish
    menu_backup_tools

  fi

  it_utils_menu

}
