#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.10
################################################################################

function config_set_phpv() {

  #$1 = ${php_v}
  #$2 = ${config_file}

  local php_v=$1
  local config_file=$2

  if [ "${config_file}" != "" ];then
    
    if [ "${php_v}" == "" ];then

      php_v=$(php_check_installed_version)
      log_event "debug" "PHP installed version: ${php_v}"

    fi

    log_event "debug" "Running: s+PHP_V+${php_v}+g ${config_file}"

    sed -i "s+PHP_V+${php_v}+g" "${config_file}"

  else

    # Logging
    log_event "error" "Setting PHP version on config file, fails."
    log_event "debug" "Destination file does not exists"

    return 1

  fi

}

function count_php_versions() {

  echo $(ls -d /etc/php/*/fpm/pool.d 2>/dev/null |wc -l)

}

function multiphp_versions() {
  
  local -a php_versions_list;
  local php_ver;

  if [[ "$(count_php_versions)" -gt 0 ]] ; then
      for php_ver in $(ls -v /etc/php/); do
          [ ! -d "/etc/php/${php_ver}/fpm/pool.d/" ] && continue
          php_versions_list+=(${php_ver})
      done
      echo "${php_versions_list[@]}"
  fi

}