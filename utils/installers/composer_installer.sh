#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc06
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
#
# Ref: https://linuxize.com/post/how-to-install-and-use-composer-on-ubuntu-20-04/
#

composer_install () {
  
  if [[ -z "${DOMAIN}" || -z "${ROOT_DOMAIN}" || -z "${PROJECT_NAME}" ]]; then
    echo -e ${B_RED}"Error: DOMAIN, ROOT_DOMAIN and PROJECT_NAME must be set! Exiting..."${ENDCOLOR}
    exit 0
  fi

  EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

  if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
      >&2 echo 'ERROR: Invalid installer signature' >>$LOG
      rm composer-setup.php
      exit 1

  fi
  
  php composer-setup.php --quiet
  RESULT=$?
  rm composer-setup.php
  
  exit $RESULT

}

################################################################################

DOMAIN=""                                    # Domain for WP installation. Example: landing.broobe.com
ROOT_DOMAIN=""                               # Only for Cloudflare API. Example: broobe.com
PROJECT_NAME=""                              # Project Name. Example: landing_broobe

composer_install "" "" ""

echo -e ${GREEN}" > Everything is DONE! ..."${ENDCOLOR}
