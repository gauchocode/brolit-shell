#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.11
################################################################################

function php_reconfigure() {

  log_subsection "PHP Reconfigure"
  
  log_event "info" "Moving php.ini configuration file"
  cat "${SFOLDER}/config/php/php.ini" >"/etc/php/${PHP_V}/fpm/php.ini"
  display --indent 6 --text "- Moving php.ini configuration file" --result "DONE" --color GREEN

  log_event "info" "Moving php-fpm.conf configuration file"
  cat "${SFOLDER}/config/php/php-fpm.conf" >"/etc/php/${PHP_V}/fpm/php-fpm.conf"
  display --indent 6 --text "- Moving php-fpm.conf configuration file" --result "DONE" --color GREEN

  # Replace string to match PHP version
  log_event "info" "Replacing string to match PHP version"
  php_set_version_on_config "${PHP_V}" "/etc/php/${PHP_V}/fpm/php-fpm.conf"
  display --indent 6 --text "- Replacing string to match PHP version" --result "DONE" --color GREEN

  # Uncomment /status from fpm configuration
  log_event "debug" "Uncommenting /status from fpm configuration"
  sed -i '/status_path/s/^;//g' "/etc/php/${PHP_V}/fpm/pool.d/www.conf"

  service php"${PHP_V}"-fpm reload
  display --indent 6 --text "- Reloading php${PHP_V}-fpm" --result "DONE" --color GREEN

}

function php_set_version_on_config() {

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

function php_opcode_config() {

  #$1 = ${status}            // enable or disable
  #$1 = ${config_file}       // optional

  local status=$1
  local config_file=$2

  if [[ -z ${config_file} || ${config_file} == "" ]] ; then
  
    config_file="/etc/php/${PHP_V}/fpm/php.ini"

  fi

  if [[ $status == "enable" ]] ; then

    # Settings needed:
    #   opcache.enable=1
    #   opcache.memory_consumption=128
    #   opcache.max_accelerated_files=200
    #   opcache_revalidate_freq = 240
    #   opcache.error_log= /var/log/nginx/opcahce_error.log
    #   opcache.file_cache=/var/www/html/.opcache;

    # Uncomment "opcache.enable" from fpm configuration
    log_event "debug" "Uncommenting opcache.enable from fpm configuration ..."
    sed -i '/opcache.enable/s/^;//g' "${config_file}"

    log_event "info" "Setting opcache.enable=1 from fpm configuration ..."
    sed -i "s#opcache.enable#1#" "${config_file}"

    # Append config
    echo "opcache.memory_consumption=128"                       >> "${config_file}"
    echo "opcache.max_accelerated_files=200"                    >> "${config_file}"
    echo "opcache_revalidate_freq=240"                          >> "${config_file}"
    echo "opcache.error_log=/var/log/nginx/opcache_error.log"   >> "${config_file}"
    #echo "opcache.file_cache=/var/www/html/.opcache"           >> "${config_file}"

    display --indent 6 --text "- Enabling Opcode" --result "DONE" --color GREEN

  else

    log_event "info" "Setting opcache.enable=0 from fpm configuration ..."
    sed -i "s#opcache.enable#0#" "${config_file}"

    display --indent 6 --text "- Disabling Opcode" --result "DONE" --color GREEN

  fi

  service php"${PHP_V}"-fpm reload
  display --indent 6 --text "- Reloading php${PHP_V}-fpm" --result "DONE" --color GREEN

}

function php_count_installed_versions() {

  echo $(ls -d /etc/php/*/fpm/pool.d 2>/dev/null |wc -l)

}

function php_installed_versions() {
  
  local -a php_versions_list;
  local php_ver;

  if [[ "$(php_count_installed_versions)" -gt 0 ]] ; then

      for php_ver in $(ls -v /etc/php/); do
        [ ! -d "/etc/php/${php_ver}/fpm/pool.d/" ] && continue
        php_versions_list+=("${php_ver}")
      done

      echo "${php_versions_list[@]}"

  fi

}