#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc03
#############################################################################
#
# Ref: https://certbot.eff.org/docs/using.html
#

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source "${SFOLDER}/libs/certbot_helper.sh"

################################################################################

################################################################################

certbot_helper_menu