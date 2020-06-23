#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc05
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi

################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################


change_current_ssh_port() {

  #$1 = ${NEW_SSH_PORT}

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

#change_current_ssh_port "922"