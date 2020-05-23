#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc03
#############################################################################

echo " > Installing cockpit" >> $LOG

apt-get --yes update && apt-get --yes install cockpit cockpit-docker cockpit-networkmanager cockpit-storaged cockpit-system cockpit-packagekit cockpit-shell

ufw allow 9090

echo " > DONE: Cockpit must be running on port 9090" >> $LOG
echo -e ${GREEN}" > DONE: Cockpit must be running on port 9090"${ENDCOLOR}
