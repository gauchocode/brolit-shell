#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.10
################################################################################

function it_utils_menu() {

  local it_util_options
  local chosen_it_util_options
  local new_ssh_port

  log_section "IT Utils"

  it_util_options=(
    "01)" "INSTALLERS AND CONFIGURATORS"
    "02)" "SECURITY TOOLS"
    "03)" "SERVER OPTIMIZATIONS"
    "04)" "CHANGE SSH PORT"
    "05)" "CHANGE HOSTNAME"
    "06)" "ADD FLOATING IP"
    "07)" "CREATE SFTP USER"
    "08)" "DELETE SFTP USER"
    "09)" "RESET MYSQL ROOT PSW"
    "10)" "BLACKLIST CHECKER"
    "11)" "BENCHMARK SERVER"
    "12)" "INSTALL ALIASES"
    "13)" "INSTALL WELCOME MESSAGE"
    "14)" "ADD BROLIT UI INTEGRATION"
    "15)" "ENABLE SSH ROOT ACCESS"
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

    # CHANGE SSH PORT
    if [[ ${chosen_it_util_options} == *"04"* ]]; then
      new_ssh_port="$(whiptail --title "CHANGE SSH PORT" --inputbox "Insert the new SSH port:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && system_change_current_ssh_port "${new_ssh_port}"
    fi

    # CHANGE HOSTNAME
    if [[ ${chosen_it_util_options} == *"05"* ]]; then
      new_server_hostname="$(whiptail --title "CHANGE SERVER HOSTNAME" --inputbox "Insert the new hostname:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && system_change_server_hostname "${new_server_hostname}"
    fi

    # ADD FLOATING IP
    if [[ ${chosen_it_util_options} == *"06"* ]]; then
      floating_IP="$(whiptail --title "ADD FLOATING IP" --inputbox "Insert the floating IP:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      [[ ${exitstatus} -eq 0 ]] && system_add_floating_IP "${floating_IP}"
    fi

    # CREATE SFTP USER
    if [[ ${chosen_it_util_options} == *"07"* ]]; then

      log_subsection "SFTP Manager"

      sftp_user="$(whiptail --title "CREATE SFTP USER" --inputbox "Insert the username:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        # Select project to work with
        directory_browser "Select a project to work with" "${PROJECTS_PATH}" #return $filename
        # Directory_broser returns: $filepath and $filename
        if [[ ${filename} != "" && ${filepath} != "" ]]; then
          # Create and add folder permission
          project_path="${filepath}/${filename}"
        fi

        sftp_create_user "${sftp_user}" "" "www-data" "${project_path}" "no"

      fi
    fi

    # DELETE SFTP USER
    if [[ ${chosen_it_util_options} == *"08"* ]]; then

      log_subsection "SFTP Manager"

      sftp_user="$(whiptail --title "DELETE SFTP USER" --inputbox "Insert the username:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        sftp_delete_user "${sftp_user}"
      fi
    fi

    # RESET MYSQL ROOT_PSW
    if [[ ${chosen_it_util_options} == *"09"* ]]; then

      db_root_psw="$(whiptail --title "MYSQL ROOT PASSWORD" --inputbox "Insert the new root password for MySQL:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/libs/mysql_helper.sh
        source "${BROLIT_MAIN_DIR}/libs/mysql_helper.sh" "${IP_TO_TEST}"
        mysql_root_psw_change "${db_root_psw}"
      fi
    fi

    # BLACKLIST CHECKER
    if [[ ${chosen_it_util_options} == *"10"* ]]; then

      IP_TO_TEST="$(whiptail --title "BLACKLIST CHECKER" --inputbox "Insert the IP or the domain you want to check." 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/tools/third-party/blacklist-checker/bl.sh
        source "${BROLIT_MAIN_DIR}/tools/third-party/blacklist-checker/bl.sh" "${IP_TO_TEST}"
      fi
    fi

    # BENCHMARK SERVER
    if [[ ${chosen_it_util_options} == *"11"* ]]; then
      # shellcheck source=${BROLIT_MAIN_DIR}/tools/bench_scripts.sh
      source "${BROLIT_MAIN_DIR}/tools/third-party/bench_scripts.sh"

    fi

    # INSTALL ALIASES
    [[ ${chosen_it_util_options} == *"12"* ]] && install_script_aliases

    # INSTALL WELCOME MESSAGE
    [[ ${chosen_it_util_options} == *"13"* ]] && customize_ubuntu_login_message

    # ADD BROLIT UI INTEGRATION
    [[ ${chosen_it_util_options} == *"14"* ]] && brolit_ssh_keygen "/root/pem"

    # ENABLE SSH ROOT ACCESS
    if [[ ${chosen_it_util_options} == *"15"* ]]; then

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

    include_all_files=$(whiptail --title "WORFENCE-CLI MALWARE SCAN" --yesno "Do you want to include all files?" 10 60 3>&1 1>&2 2>&3)

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      wordfencecli_malware_scan "${to_scan}" "${include_all_files}"

    fi

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
