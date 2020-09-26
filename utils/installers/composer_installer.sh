#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.3
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

  local composer_result expected_signature actual_signature

  log_event "info" "Running composer installer" "true"
  
  expected_signature="$(wget -q -O - https://composer.github.io/installer.sig)"
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  actual_signature="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

  if [ "$expected_signature" != "$actual_signature" ]; then
      >&2 echo 'ERROR: Invalid installer signature' >>$LOG
      rm composer-setup.php
      return 1

  fi
  
  php composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer
  composer_result=$?

  if [ "${composer_result}" -eq 0 ]; then
    rm composer-setup.php

    log_event "success" "composer installer finished ok!" "true"

  else
    log_event "error" "composer installer failed" "true"

  fi
  
  return "${composer_result}"

}

composer_update_version () {

  composer self-update

}

composer_update () {

  composer update

}

################################################################################

#DOMAIN=""                                    # Domain for WP installation. Example: landing.broobe.com
#ROOT_DOMAIN=""                               # Only for Cloudflare API. Example: broobe.com
#PROJECT_NAME=""                              # Project Name. Example: landing_broobe

composer_install 