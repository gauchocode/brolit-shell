#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.9
################################################################################
#
# PHP Helper: Perform php configuration tasks.
#
################################################################################

################################################################################
# Check php activated version
#
# Arguments:
#   None
#
# Outputs:
#   String with default version.
################################################################################

function php_check_activated_version() {

  local php_default

  # Activated default version
  php_default=$(php -version | grep -Po '^PHP \K([0-9]*.[0-9]*.[0-9]*)' | tr ' ' -)

  if [[ -n ${php_default} ]]; then

    # Return
    echo "${php_default}" && return 0

  else

    return 1

  fi

}

################################################################################
# Set/Update php version on config
#
# Arguments:
#  ${1} = ${php_v}
#  ${2} = ${config_file}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function php_set_version_on_config() {

  local php_v="${1}"
  local config_file="${2}"

  local php_installed_versions

  if [[ ${config_file} != "" ]]; then

    if [[ -z ${php_v} ]]; then

      # Get array with installed versions
      php_installed_versions="$(php_check_installed_version)"

      # Select version to work
      php_v="$(php_select_version_to_work_with "${php_installed_versions}")"

    fi

    # Replacing PHP_V with PHP version number
    sed -i "s+PHP_V+${php_v}+g" "${config_file}"

    # Log
    log_event "debug" "Running: s+PHP_V+${php_v}+g ${config_file}" "false"

  else

    # Log
    log_event "error" "Setting PHP version on config file, fails." "false"
    log_event "debug" "Destination file '${config_file}' does not exists" "false"

    return 1

  fi

}

################################################################################
# Set/Update php opcode config
#
# Arguments:
#  ${1} = ${php_v}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function php_opcode_config() {

  local php_v="${1}"

  local config_file
  local val

  [[ -z ${php_v} ]] && return 1

  log_subsection "PHP Opcode Config"

  config_file="/etc/php/${php_v}/fpm/php.ini"

  if [[ ${PACKAGES_PHP_CONFIG_OPCODE} == "enabled" ]]; then

    val=1

    # Settings needed:
    #   opcache.enable=1
    #   opcache.memory_consumption=128
    #   opcache.max_accelerated_files=200
    #   opcache_revalidate_freq = 240
    #   opcache.error_log= /var/log/nginx/opcahce_error.log
    #   opcache.file_cache=/var/www/html/.opcache;
    #
    # More info: https://raazkumar.com/tutorials/php/opcache-settings/

    # Uncomment "opcache.enable" from fpm configuration
    log_event "debug" "Uncommenting opcache.enable from fpm configuration ..."
    sed -i '/opcache.enable/s/^;//g' "${config_file}"
    # Setting opcache.enable=1
    log_event "info" "Setting opcache.enable=1 from fpm configuration ..."
    sed -i "s/^\(opcache\.enable\s*=\s*\).*\$/\1$val/" "${config_file}"

    # Uncomment "opcache.memory_consumption" from fpm configuration
    log_event "debug" "Uncommenting opcache.memory_consumption from fpm configuration ..."
    sed -i '/opcache.memory_consumption/s/^;//g' "${config_file}"
    # Setting memory_consumption.enable=128
    opcode_mem="128"
    sed -i "s/^\(opcache\.memory_consumption\s*=\s*\).*\$/\1$opcode_mem/" "${config_file}"

    # Uncomment "opcache.max_accelerated_files" from fpm configuration
    log_event "debug" "Uncommenting opcache.max_accelerated_files from fpm configuration ..."
    sed -i '/opcache.max_accelerated_files/s/^;//g' "${config_file}"
    # Setting opcache.max_accelerated_files=200
    opcode_maf="200"
    sed -i "s/^\(opcache\.max_accelerated_files\s*=\s*\).*\$/\1$opcode_maf/" "${config_file}"

    # Uncomment "opcache.revalidate_freq" from fpm configuration
    log_event "debug" "Uncommenting opcache.revalidate_freq from fpm configuration ..."
    sed -i '/opcache.revalidate_freq/s/^;//g' "${config_file}"
    # Setting opcache.revalidate_freq=240
    opcode_rf="240"
    sed -i "s/^\(opcache\.revalidate_freq\s*=\s*\).*\$/\1$opcode_rf/" "${config_file}"

    # Uncomment "opcache.error_log" from fpm configuration
    #log_event "debug" "Uncommenting opcache.error_log from fpm configuration ..."
    #sed -i '/opcache.error_log/s/^;//g' "${config_file}"
    # Setting opcache.error_log
    #opcode_log="/var/log/nginx/opcache_error.log"
    #sed -i "s/^\(opcache\.error_log\s*=\s*\).*\$/\1$opcode_log/" "${config_file}"

    display --indent 6 --text "- Enabling Opcode" --result "DONE" --color GREEN

  else

    val=0

    log_event "info" "Setting opcache.enable=0 from fpm configuration ..."

    sed -i "s/^\(opcache\.enable\s*=\s*\).*\$/\1$val/" "${config_file}"

    display --indent 6 --text "- Disabling Opcode" --result "DONE" --color GREEN

  fi

  service php"${php_v}"-fpm reload
  display --indent 6 --text "- Reloading php${php_v}-fpm service" --result "DONE" --color GREEN

}

################################################################################
# Count php installed versions
#
# Arguments:
#  none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function php_count_installed_versions() {

  echo "$(ls -d /etc/php/*/fpm/pool.d 2>/dev/null | wc -l)"

}

################################################################################
# PHP-FPM optimizations
#
# Arguments:
#  ${1} = ${php_v}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function php_fpm_optimizations() {

  local php_v="${1}"

  local ram_reserved
  local ram_dedicated

  log_subsection "PHP-FPM Optimization Tool"

  # TODO: Should be a % of total RAM
  RAM_BUFFER="1024"

  # Getting server info
  CPUS="$(grep -c "processor" /proc/cpuinfo)"
  RAM="$(grep MemTotal /proc/meminfo | awk '{print $2}' | xargs -I {} echo "scale=1; {}/1024" | bc | cut -d "." -f1)"

  # Calculating avg ram used by this process
  PHP_AVG_RAM="90"
  #PHP_AVG_RAM="$(ps ax --no-headers -o "%mem,cmd" | grep '[f]'pm | awk 'NR != 1 {x[$2] += $1} END{ for(z in x) {print x[z]""}}')"
  MYSQL_AVG_RAM="$(ps ax --no-headers -o "%mem,cmd" | grep mysqld | awk 'NR != 2 {x[$2] += $1} END{ for(z in x) {print x[z]""}}')"
  NGINX_AVG_RAM="$(ps --no-headers -o "%mem,cmd" -C nginx | awk 'NR != 1 {x[$2] += $1} END{ for(z in x) {print x[z]""}}')"

  # Show/Log Server Info
  #display --indent 6 --text "Getting server info ..."
  log_subsection "Server specs and Mem info"
  display --indent 6 --text "PHP_V: ${php_v}"
  display --indent 6 --text "RAM_BUFFER: ${RAM_BUFFER}"
  display --indent 6 --text "CPUS: ${CPUS}"
  display --indent 6 --text "RAM: ${RAM}"
  #display --indent 6 --text "PHP_AVG_RAM: ${PHP_AVG_RAM}"
  display --indent 6 --text "MYSQL_AVG_RAM: ${MYSQL_AVG_RAM}"
  display --indent 6 --text "NGINX_AVG_RAM: ${NGINX_AVG_RAM}"

  log_event "info" "PHP_V: ${php_v}" "false"
  log_event "info" "RAM_BUFFER: ${RAM_BUFFER}" "false"
  log_event "info" "CPUS: ${CPUS}" "false"
  log_event "info" "RAM: ${RAM}" "false"
  #log_event "info" "PHP_AVG_RAM: ${PHP_AVG_RAM}" "false"
  log_event "info" "MYSQL_AVG_RAM: ${MYSQL_AVG_RAM}" "false"
  log_event "info" "NGINX_AVG_RAM: ${NGINX_AVG_RAM}" "false"

  DELIMITER="="

  KEY="pm.max_children"
  PM_MAX_CHILDREN_ORIGIN=$(cat "/etc/php/${php_v}/fpm/pool.d/www.conf" | grep "^${KEY} ${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="pm.start_servers"
  PM_START_SERVERS_ORIGIN=$(cat "/etc/php/${php_v}/fpm/pool.d/www.conf" | grep "^${KEY} ${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="pm.min_spare_servers"
  PM_MIN_SPARE_SERVERS_ORIGIN=$(cat "/etc/php/${php_v}/fpm/pool.d/www.conf" | grep "^${KEY} ${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="pm.max_spare_servers"
  PM_MAX_SPARE_SERVERS_ORIGIN=$(cat "/etc/php/${php_v}/fpm/pool.d/www.conf" | grep "^${KEY} ${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="pm.max_requests"
  PM_MAX_REQUESTS_ORIGIN=$(cat "/etc/php/${php_v}/fpm/pool.d/www.conf" | grep "^${KEY} ${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="pm.process_idle_timeout"
  PM_PROCESS_IDDLE_TIMEOUT_ORIGIN=$(cat "/etc/php/${php_v}/fpm/pool.d/www.conf" | grep "^${KEY} ${DELIMITER}" | cut -f2- -d"$DELIMITER")

  # Show/Log PHP-FPM actual config
  # display --indent 6 --text "Getting PHP actual configuration ..."
  log_subsection "PHP actual configuration"
  display --indent 6 --text "PM_MAX_CHILDREN_ORIGIN: ${PM_MAX_CHILDREN_ORIGIN}"
  display --indent 6 --text "PM_START_SERVERS_ORIGIN: ${PM_START_SERVERS_ORIGIN}"
  display --indent 6 --text "PM_MIN_SPARE_SERVERS_ORIGIN: ${PM_MIN_SPARE_SERVERS_ORIGIN}"
  display --indent 6 --text "PM_MAX_SPARE_SERVERS_ORIGIN: ${PM_MAX_SPARE_SERVERS_ORIGIN}"
  display --indent 6 --text "PM_MAX_REQUESTS_ORIGIN: ${PM_MAX_REQUESTS_ORIGIN}"
  display --indent 6 --text "PM_PROCESS_IDDLE_TIMEOUT_ORIGIN: ${PM_PROCESS_IDDLE_TIMEOUT_ORIGIN}"

  log_event "debug" "PM_MAX_CHILDREN: ${PM_MAX_CHILDREN_ORIGIN}" "false"
  log_event "debug" "PM_START_SERVERS: ${PM_START_SERVERS_ORIGIN}" "false"
  log_event "debug" "PM_MIN_SPARE_SERVERS: ${PM_MIN_SPARE_SERVERS_ORIGIN}" "false"
  log_event "debug" "PM_MAX_SPARE_SERVERS: ${PM_MAX_SPARE_SERVERS_ORIGIN}" "false"
  log_event "debug" "PM_MAX_REQUESTS: ${PM_MAX_REQUESTS_ORIGIN}" "false"
  log_event "debug" "PM_PROCESS_IDDLE_TIMEOUT: ${PM_PROCESS_IDDLE_TIMEOUT_ORIGIN}" "false"

  # Settings	Value Explanation
  # max_children	(Total RAM - Memory used for Linux, DB, etc.) / process size
  # start_servers	Number of CPU cores x 4
  # min_spare_servers	Number of CPU cores x 2
  # max_spare_servers	Same as start_servers

  ram_reserved="$(echo "(${MYSQL_AVG_RAM} + ${NGINX_AVG_RAM} + ${RAM_BUFFER})" | bc)"
  ram_dedicated="$(echo "(${RAM} - ${ram_reserved})" | bc)"

  # Log
  log_event "debug" "ram_reserved=(${MYSQL_AVG_RAM} + ${NGINX_AVG_RAM} + ${RAM_BUFFER})" "false"
  log_event "debug" "ram_dedicated=(${RAM} - ${ram_reserved})" "false"
  log_event "debug" "PM_MAX_CHILDREN=(${ram_dedicated} / ${PHP_AVG_RAM})" "false"

  PM_MAX_CHILDREN="$(echo "${ram_dedicated} / ${PHP_AVG_RAM}" | bc | cut -d "." -f1)"
  PM_START_SERVERS=$(("${CPUS}" * 4))
  PM_MIN_SPARE_SERVERS=$(("${CPUS} * 2"))

  # This fix:
  # ALERT: [pool www] pm.min_spare_servers(8) and pm.max_spare_servers(32) cannot be greater than pm.max_children(30)
  PM_MAX_SPARE_SERVERS=$(("${PM_START_SERVERS}" * 2))
  [[ ${PM_MAX_CHILDREN} < ${PM_MAX_SPARE_SERVERS} ]] && PM_MAX_SPARE_SERVERS=${PM_MAX_CHILDREN}

  PM_MAX_REQUESTS=500
  PM_PROCESS_IDDLE_TIMEOUT="10s"

  # Show/Log PHP-FPM optimal config
  #display --indent 6 --text "Calculating PHP optimal configuration ..."
  log_subsection "PHP optimal configuration"
  display --indent 6 --text "PM_MAX_CHILDREN: ${PM_MAX_CHILDREN}"
  display --indent 6 --text "PM_START_SERVERS: ${PM_START_SERVERS}"
  display --indent 6 --text "PM_MIN_SPARE_SERVERS: ${PM_MIN_SPARE_SERVERS}"
  display --indent 6 --text "PM_MAX_SPARE_SERVERS: ${PM_MAX_SPARE_SERVERS}"
  display --indent 6 --text "PM_MAX_REQUESTS: ${PM_MAX_REQUESTS}"
  display --indent 6 --text "PM_PROCESS_IDDLE_TIMEOUT: ${PM_PROCESS_IDDLE_TIMEOUT}"

  log_event "info" "PM_MAX_CHILDREN: ${PM_MAX_CHILDREN}" "false"
  log_event "info" "PM_START_SERVERS: ${PM_START_SERVERS}" "false"
  log_event "info" "PM_MIN_SPARE_SERVERS: ${PM_MIN_SPARE_SERVERS}" "false"
  log_event "info" "PM_MAX_SPARE_SERVERS: ${PM_MAX_SPARE_SERVERS}" "false"
  log_event "info" "PM_MAX_REQUESTS: ${PM_MAX_REQUESTS}" "false"
  log_event "info" "PM_PROCESS_IDDLE_TIMEOUT: ${PM_PROCESS_IDDLE_TIMEOUT}" "false"

  log_break "true"

  while true; do

    echo -e "${YELLOW}${ITALIC} > Do you want to apply this optimizations?${ENDCOLOR}"
    read -p "Please type 'y' or 'n'" yn

    case $yn in

    [Yy]*)

      clear_previous_lines "2"

      sed -ie "s|^pm\.max_children =.*$|pm\.max_children = ${PM_MAX_CHILDREN}|g" "/etc/php/${php_v}/fpm/pool.d/www.conf"
      sed -ie "s|^pm\.start_servers =.*$|pm\.start_servers = ${PM_START_SERVERS}|g" "/etc/php/${php_v}/fpm/pool.d/www.conf"
      sed -ie "s|^pm\.min_spare_servers =.*$|pm\.min_spare_servers = ${PM_MIN_SPARE_SERVERS}|g" "/etc/php/${php_v}/fpm/pool.d/www.conf"
      sed -ie "s|^pm\.max_spare_servers =.*$|pm\.max_spare_servers = ${PM_MAX_SPARE_SERVERS}|g" "/etc/php/${php_v}/fpm/pool.d/www.conf"
      sed -ie "s|^pm\.max_requests =.*$|pm\.max_requests = ${PM_MAX_REQUESTS}|g" "/etc/php/${php_v}/fpm/pool.d/www.conf"

      #Test the validity of your php-fpm configuration
      result="$(php-fpm"${php_v}" -t 2>&1 | grep -w "test" | cut -d"." -f3 | cut -d" " -f4)"

      if [[ ${result} == "successful" ]]; then
        log_event "info" "PHP optimizations applied!" "false"
        display --indent 6 --text "- Applying optimizations" --result "DONE" --color GREEN

      else
        debug="$(php-fpm"${php_v}" -t 2>&1)"
        log_event "error" "PHP optimizations fail: ${debug}" "false"
        display --indent 6 --text "- Applying optimizations" --result "FAIL" --color RED

      fi

      break
      ;;

    [Nn]*)

      clear_previous_lines "2"
      log_event "info" "Skipping php-fpm optimization..." "false"
      display --indent 6 --text "- Applying optimizations" --result "SKIPPED" --color YELLOW

      break
      ;;

    *) echo " > Please answer yes or no." ;;

    esac

  done

}

function php_select_version_to_work_with() {

  local php_v="${1}"

  # String to array
  IFS=' ' read -r -a php_v_array <<<"$php_v"

  # Get length of $php_v array
  len=${#php_v_array[@]}

  if [[ $len != 1 ]]; then

    local chosen_php_v

    chosen_php_v="$(whiptail --title "PHP Version Selection" --menu "Select the version of PHP you want to work with:" 20 78 10 $(for x in ${php_v}; do echo "${x} [X]"; done) 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      log_event "debug" "Working with php${php_v}-fpm" "false"

      # Return
      echo "${chosen_php_v}"

    else

      log_event "debug" "PHP version selection skipped" "false"

      return 1

    fi

  else

    # Return
    echo "${php_v}"

  fi

}
