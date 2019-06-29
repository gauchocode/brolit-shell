#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9
#############################################################################
#
apt-get --yes update && apt-get --yes install cockpit cockpit-docker cockpit-networkmanager cockpit-storaged cockpit-system cockpit-packagekit cockpit-shell

ufw allow 9090

echo -e ${GREEN}" > DONE: Cockpit must be running on port 9090"${ENDCOLOR}
