#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc1
################################################################################

function it_utils_menu() {

  local it_util_options
  local chosen_it_util_options
  local new_ssh_port

  it_util_options=(
    "01)" "SECURITY TOOLS"
    "02)" "SERVER OPTIMIZATIONS"
    "03)" "CHANGE SSH PORT"
    "04)" "CHANGE HOSTNAME"
    "05)" "ADD FLOATING IP"
    "06)" "CREATE SFTP USER"
    "07)" "DELETE SFTP USER"
    "08)" "RESET MYSQL ROOT PSW"
    "09)" "BLACKLIST CHECKER"
    "10)" "BENCHMARK SERVER"
    "11)" "INSTALL ALIASES"
    "12)" "INSTALL WELCOME MESSAGE"
  )
  chosen_it_util_options="$(whiptail --title "IT UTILS" --menu "Choose a script to Run" 20 78 10 "${it_util_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} = 0 ]]; then

    # SECURITY TOOLS
    if [[ ${chosen_it_util_options} == *"01"* ]]; then
      menu_security_utils
    fi
    # SERVER OPTIMIZATIONS
    if [[ ${chosen_it_util_options} == *"02"* ]]; then
      # shellcheck source=${BROLIT_MAIN_DIR}/utils/server_and_image_optimizations.sh
      source "${BROLIT_MAIN_DIR}/utils/server_and_image_optimizations.sh"
      server_optimizations_menu
    fi
    # CHANGE SSH PORT
    if [[ ${chosen_it_util_options} == *"03"* ]]; then

      new_ssh_port="$(whiptail --title "CHANGE SSH PORT" --inputbox "Insert the new SSH port:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        system_change_current_ssh_port "${new_ssh_port}"
      fi
    fi
    # CHANGE HOSTNAME
    if [[ ${chosen_it_util_options} == *"04"* ]]; then

      new_server_hostname="$(whiptail --title "CHANGE SERVER HOSTNAME" --inputbox "Insert the new hostname:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        system_change_server_hostname "${new_server_hostname}"
      fi
    fi
    # ADD FLOATING IP
    if [[ ${chosen_it_util_options} == *"05"* ]]; then

      floating_IP="$(whiptail --title "ADD FLOATING IP" --inputbox "Insert the floating IP:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        system_add_floating_IP "${floating_IP}"
      fi
    fi
    # CREATE SFTP USER
    if [[ ${chosen_it_util_options} == *"06"* ]]; then

      log_subsection "SFTP Manager"

      sftp_user="$(whiptail --title "CREATE SFTP USER" --inputbox "Insert the username:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        sftp_create_user "${sftp_user}" "www-data" "no"
      fi
    fi
    # DELETE SFTP USER
    if [[ ${chosen_it_util_options} == *"07"* ]]; then

      log_subsection "SFTP Manager"

      sftp_user="$(whiptail --title "DELETE SFTP USER" --inputbox "Insert the username:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        sftp_delete_user "${sftp_user}"
      fi
    fi
    # RESET MYSQL ROOT_PSW
    if [[ ${chosen_it_util_options} == *"08"* ]]; then

      db_root_psw="$(whiptail --title "MYSQL ROOT PASSWORD" --inputbox "Insert the new root password for MySQL:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/libs/mysql_helper.sh
        source "${BROLIT_MAIN_DIR}/libs/mysql_helper.sh" "${IP_TO_TEST}"
        mysql_root_psw_change "${db_root_psw}"
      fi
    fi
    # BLACKLIST CHECKER
    if [[ ${chosen_it_util_options} == *"09"* ]]; then

      IP_TO_TEST="$(whiptail --title "BLACKLIST CHECKER" --inputbox "Insert the IP or the domain you want to check." 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        # shellcheck source=${BROLIT_MAIN_DIR}/tools/third-party/blacklist-checker/bl.sh
        source "${BROLIT_MAIN_DIR}/tools/third-party/blacklist-checker/bl.sh" "${IP_TO_TEST}"
      fi
    fi
    # BENCHMARK SERVER
    if [[ ${chosen_it_util_options} == *"10"* ]]; then
      # shellcheck source=${BROLIT_MAIN_DIR}/tools/bench_scripts.sh
      source "${BROLIT_MAIN_DIR}/tools/third-party/bench_scripts.sh"

    fi
    # INSTALL ALIASES
    if [[ ${chosen_it_util_options} == *"11"* ]]; then
      install_script_aliases

    fi
    # INSTALL WELCOME MESSAGE
    if [[ ${chosen_it_util_options} == *"12"* ]]; then
      customize_ubuntu_login_message

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
    "01)" "CLAMAV MALWARE SCAN"
    "02)" "CUSTOM MALWARE SCAN"
    "03)" "LYNIS SYSTEM AUDIT"
  )
  chosen_security_options=$(whiptail --title "SECURITY TOOLS" --menu "Choose an option to run" 20 78 10 "${security_options[@]}" 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    package_install_security_utils

    if [[ ${chosen_security_options} == *"01"* ]]; then
      menu_security_clamav_scan

    fi
    if [[ ${chosen_security_options} == *"02"* ]]; then
      menu_security_custom_scan

    fi
    if [[ ${chosen_security_options} == *"03"* ]]; then
      menu_security_system_audit

    fi

    prompt_return_or_finish
    menu_security_utils

  fi

  menu_main_options

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

