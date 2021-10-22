#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.67
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
      # shellcheck source=${SFOLDER}/utils/server_and_image_optimizations.sh
      source "${SFOLDER}/utils/server_and_image_optimizations.sh"
      server_optimizations_menu
    fi
    # CHANGE SSH PORT
    if [[ ${chosen_it_util_options} == *"03"* ]]; then

      new_ssh_port="$(whiptail --title "CHANGE SSH PORT" --inputbox "Insert the new SSH port:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        change_current_ssh_port "${new_ssh_port}"
      fi
    fi
    # CHANGE HOSTNAME
    if [[ ${chosen_it_util_options} == *"04"* ]]; then

      new_server_hostname="$(whiptail --title "CHANGE SERVER HOSTNAME" --inputbox "Insert the new hostname:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        change_server_hostname "${new_server_hostname}"
      fi
    fi
    # ADD FLOATING IP
    if [[ ${chosen_it_util_options} == *"05"* ]]; then

      floating_IP="$(whiptail --title "ADD FLOATING IP" --inputbox "Insert the floating IP:" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        add_floating_IP "${floating_IP}"
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
        # shellcheck source=${SFOLDER}/libs/mysql_helper.sh
        source "${SFOLDER}/libs/mysql_helper.sh" "${IP_TO_TEST}"
        mysql_root_psw_change "${db_root_psw}"
      fi
    fi
    # BLACKLIST CHECKER
    if [[ ${chosen_it_util_options} == *"09"* ]]; then

      IP_TO_TEST="$(whiptail --title "BLACKLIST CHECKER" --inputbox "Insert the IP or the domain you want to check." 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then
        # shellcheck source=${SFOLDER}/tools/third-party/blacklist-checker/bl.sh
        source "${SFOLDER}/tools/third-party/blacklist-checker/bl.sh" "${IP_TO_TEST}"
      fi
    fi
    # BENCHMARK SERVER
    if [[ ${chosen_it_util_options} == *"10"* ]]; then
      # shellcheck source=${SFOLDER}/tools/bench_scripts.sh
      source "${SFOLDER}/tools/third-party/bench_scripts.sh"

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

    packages_install_security_utils

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

  startdir="${SITES}"
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

  startdir="${SITES}"
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

function change_current_ssh_port() {

  #$1 = ${new_ssh_port}

  local new_ssh_port=$1

  local current_ssh_port

  log_subsection "Change SSH Port"
  log_event "info" "Trying to change current SSH port" "false"

  # Get current ssh port
  current_ssh_port=$(grep "Port" /etc/ssh/sshd_config | awk -F " " '{print $2}')
  log_event "info" "Current SSH port: ${current_ssh_port}" "false"
  display --indent 6 --text "- Current SSH port: ${current_ssh_port}"

  # Download secure sshd_config
  cp -f "${SFOLDER}/config/sshd_config" "/etc/ssh/sshd_config"

  # Change ssh default port
  sed -i "s/Port 22/Port ${new_ssh_port}/" "/etc/ssh/sshd_config"
  log_event "info" "Changes made on /etc/ssh/sshd_config" "false"
  display --indent 6 --text "- Making changes on sshd_config" --result "DONE" --color GREEN

  # Restart ssh service
  service ssh restart

  log_event "info" "SSH service restarted" "false"
  display --indent 6 --text "- Restarting ssh service" --result "DONE" --color GREEN

  log_event "info" "New SSH port: ${new_ssh_port}" "false"
  display --indent 8 --text "- New SSH port: ${new_ssh_port}"

}

function change_server_hostname() {

  #$1 = ${new_hostname}

  local new_hostname=$1

  local cur_hostname

  log_subsection "Change Hostname"

  cur_hostname=$(cat /etc/hostname)

  # Display the current hostname
  log_event "info" "Current hostname: ${cur_hostname}" "false"
  display --indent 6 --text "- Current hostname: ${cur_hostname}"

  # Change the hostname
  hostnamectl set-hostname "${new_hostname}"
  hostname "${new_hostname}"

  # Change hostname in /etc/hosts & /etc/hostname
  sed -i "s/${cur_hostname}/${new_hostname}/g" /etc/hosts
  sed -i "s/${cur_hostname}/${new_hostname}/g" /etc/hostname

  # Display new hostname
  log_event "info" "New hostname: ${new_hostname}" "false"
  display --indent 6 --text "- Changing hostname" --result "DONE" --color GREEN
  display --indent 8 --text "New hostname: ${new_hostname}"

}

function add_floating_IP() {

  #$1 = ${floating_IP}

  local floating_IP=$1

  local ubuntu_v

  ubuntu_v=$(get_ubuntu_version)

  log_subsection "Adding Floating IP"
  log_event "info" "Trying to add ${floating_IP} as floating ip on Ubuntu ${ubuntu_v}" "false"

  if [[ "${ubuntu_v}" == "1804" ]]; then

    cp "${SFOLDER}/config/networking/60-my-floating-ip.cfg" /etc/network/interfaces.d/60-my-floating-ip.cfg
    sed -i "s#your.float.ing.ip#${floating_IP}#" /etc/network/interfaces.d/60-my-floating-ip.cfg
    display --indent 6 --text "- Making network config changes" --result "DONE" --color GREEN

    service networking restart

    log_event "info" "New IP ${floating_IP} added" "false"
    display --indent 6 --text "- Restarting networking service" --result "DONE" --color GREEN
    display --indent 8 --text "New IP ${floating_IP} added"

  else

    if [[ "${ubuntu_v}" == "2004" ]]; then

      cp "${SFOLDER}/config/networking/60-floating-ip.yaml" /etc/netplan/60-floating-ip.yaml
      sed -i "s#your.float.ing.ip#${floating_IP}#" /etc/netplan/60-floating-ip.yaml
      display --indent 6 --text "- Making network config changes" --result "DONE" --color GREEN

      netplan apply

      log_event "info" "New IP ${floating_IP} added" "false"
      display --indent 6 --text "- Restarting networking service" --result "DONE" --color GREEN
      display --indent 8 --text "New IP ${floating_IP} added"

    else

      log_event "error" "This script only works on Ubuntu 20.04 or 18.04 ... Exiting" "false"
      display --indent 6 --text "- Making network config changes" --result "FAIL" --color RED
      display --indent 8 --text "This script works on Ubuntu 20.04 or 18.04"
      return 1

    fi

  fi

  # TODO: reboot prompt
  #log_event "info" "Is recommended reboot, do you want to do it now?" "true"

}
