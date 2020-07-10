
#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc06
################################################################################
#
# https://www.cyberciti.biz/faq/ubuntu-20-04-lts-change-hostname-permanently/
#

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi

################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################


it_utils_menu() {

  local it_util_options chosen_it_util_options new_ssh_port

  it_util_options="01 SECURITY_TOOLS 02 SERVER_OPTIMIZATIONS 03 BLACKLIST_CHECKER 04 BENCHMARK_SERVER 05 CHANGE_SSH_PORT 06 CHANGE_HOSTNAME 07 ADD_FLOATING_IP"
  chosen_it_util_options=$(whiptail --title "IT UTILS MENU" --menu "Choose a script to Run" 20 78 10 $(for x in ${it_util_options}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${chosen_it_util_options} == *"01"* ]]; then
      security_utils_menu

    fi
    if [[ ${chosen_it_util_options} == *"02"* ]]; then
      # shellcheck source=${SFOLDER}/server_and_image_optimizations.sh
      source "${SFOLDER}/server_and_image_optimizations.sh"

    fi
    if [[ ${chosen_it_util_options} == *"03"* ]]; then

      URL_TO_TEST=$(whiptail --title "GTMETRIX TEST" --inputbox "Insert test URL including http:// or https://" 10 60 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        # shellcheck source=${SFOLDER}/utils/third-party/google-insights-api-tools/gitools_v5.sh
        source "${SFOLDER}/utils/third-party/google-insights-api-tools/gitools_v5.sh" gtmetrix "${URL_TO_TEST}"
      fi

    fi
    if [[ ${chosen_it_util_options} == *"04"* ]]; then
    
      IP_TO_TEST=$(whiptail --title "BLACKLIST CHECKER" --inputbox "Insert the IP or the domain you want to check." 10 60 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        # shellcheck source=${SFOLDER}/utils/third-party/blacklist-checker/bl.sh
        source "${SFOLDER}/utils/third-party/blacklist-checker/bl.sh" "${IP_TO_TEST}"
      fi
    fi
    if [[ ${chosen_it_util_options} == *"05"* ]]; then
    
      new_ssh_port=$(whiptail --title "CHANGE SSH PORT" --inputbox "Insert the new SSH port:" 10 60 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        change_current_ssh_port "${new_ssh_port}"

      fi
    fi
       if [[ ${chosen_it_util_options} == *"06"* ]]; then
    
      new_server_hostname=$(whiptail --title "CHANGE SERVER HOSTNAME" --inputbox "Insert the new hostname:" 10 60 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        echo "TODO: IMPLEMENT change_server_hostname"
        #change_server_hostname "${new_server_hostname}"

      fi
    fi
       if [[ ${chosen_it_util_options} == *"07"* ]]; then
    
      floating_IP=$(whiptail --title "ADD FLOATING IP" --inputbox "Insert the floating IP:" 10 60 3>&1 1>&2 2>&3)
      exitstatus=$?
      if [ ${exitstatus} = 0 ]; then
        echo "TODO: IMPLEMENT add_floating_IP"
        #add_floating_IP "${floating_IP}"

      fi
    fi

  else
    exit 1

  fi
}

change_current_ssh_port() {

  #$1 = ${new_ssh_port}

  local new_ssh_port=$1

  # get current ssh port
  #CURRENT_SSH_PORT=$(grep "Port" /etc/ssh/sshd_config | awk -F " " '{print $2}')

  # download secure sshd_config
  sudo cp -f "assets/ssh/sshd_config" "/etc/ssh/sshd_config"

  # change ssh default port
  sudo sed -i "s/Port 22/Port ${new_ssh_port}/" "/etc/ssh/sshd_config"

  # restart ssh service
  sudo service ssh restart

}

################################################################################

it_utils_menu
