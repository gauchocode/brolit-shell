#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.32
################################################################################
#
# Ref: https://linuxize.com/post/how-to-install-and-use-composer-on-ubuntu-20-04/
#
################################################################################

function composer_installer() {

  local composer_result
  local expected_signature
  local actual_signature

  log_event "info" "Running composer installer"

  expected_signature="$(wget -q -O - https://composer.github.io/installer.sig)"
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  actual_signature="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

  if [[ ${expected_signature} != "${actual_signature}" ]]; then
    log_event "error" "Invalid installer signature"
    rm composer-setup.php
    return 1

  fi

  composer_result="$(${PHP} composer-setup.php --quiet --install-dir=/usr/local/bin --filename=composer)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    rm composer-setup.php

    log_event "info" "Composer Installer finished"

  else
    log_event "error" "Composer Installer failed"
    log_event "debug" "composer_result=${composer_result}"

  fi

  # Return
  echo "${exitstatus}"

}

function composer_update_version() {

  composer self-update

}

function composer_update() {

  composer update

}

################################################################################

#DOMAIN=""                                    # Domain for WP installation. Example: landing.broobe.com
#ROOT_DOMAIN=""                               # Only for Cloudflare API. Example: broobe.com
#PROJECT_NAME=""                              # Project Name. Example: landing_broobe
