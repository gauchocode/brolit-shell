#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.38
################################################################################

function php_check_if_installed() {

  local php_installed
  local php

  php="$(command -v php)"
  if [[ ! -x "${php}" ]]; then
    php_installed="false"

  else
    php_installed="true"

  fi

  log_event "debug" "php_installed=${php_installed}"

  # Return
  echo "${php_installed}"

}

function php_check_installed_version() {
  
  local php_fpm_installed_pkg
  local php_installed_versions

  # Installed versions
  php_fpm_installed_pkg="$(sudo dpkg --list | grep -oh 'php[0-9]\.[0-9]\-fpm')"

  # Grep -oh parameters explanation:
  #
  # -h, --no-filename
  #   Suppress the prefixing of file names on output. This is the default
  #   when there is only  one  file  (or only standard input) to search.
  # -o, --only-matching
  #   Print  only  the matched (non-empty) parts of a matching line,
  #   with each such part on a separate output line.
  #
  # In this case, output example: php7.2-fpm php7.3-fpm php7.4-fpm

  # Extract only version numbers
  php_installed_versions="$(echo -n "${php_fpm_installed_pkg}" | grep -Eo '[+-]?[0-9]+([.][0-9]+)?' | tr '\n' ' ')"
  # The "tr '\n' ' '" part, will replace /n with space
  # Return example: 7.4 7.2 7.0

  # Check elements number on string
  count_elements="$(echo "${php_installed_versions}" | wc -w)"

  if [[ $count_elements == "1" ]]; then

    # Remove last space
    php_installed_versions="$(string_remove_spaces "${php_installed_versions}")"

  fi

  log_event "debug" "Setting php_installed_versions=${php_installed_versions}"

  # Return
  echo "${php_installed_versions}"

}

function php_check_activated_version() {
  
  local php_default

  # Activated default version
  php_default=$(php -version | grep -Po '^PHP \K([0-9]*.[0-9]*.[0-9]*)' | tr ' ' -)

  # Return
  echo "${php_default}"

}

function php_reconfigure() {

  #$1 = ${php_v} - Optional

  local php_v=$1

  log_subsection "PHP Reconfigure"

  # If $php_v not set, it will use $PHP_V global
  if [[ ${php_v} == "" ]];then php_v="${PHP_V}"; fi
  
  log_event "info" "Moving php.ini configuration file"
  cat "${SFOLDER}/config/php/php.ini" >"/etc/php/${php_v}/fpm/php.ini"
  display --indent 6 --text "- Moving php.ini configuration file" --result "DONE" --color GREEN

  log_event "info" "Moving php-fpm.conf configuration file"
  cat "${SFOLDER}/config/php/php-fpm.conf" >"/etc/php/${php_v}/fpm/php-fpm.conf"
  display --indent 6 --text "- Moving php-fpm.conf configuration file" --result "DONE" --color GREEN

  # Replace string to match PHP version
  log_event "info" "Replacing string to match PHP version"
  php_set_version_on_config "${php_v}" "/etc/php/${php_v}/fpm/php-fpm.conf"
  display --indent 6 --text "- Replacing string to match PHP version" --result "DONE" --color GREEN

  # Uncomment /status from fpm configuration
  log_event "debug" "Uncommenting /status from fpm configuration"
  sed -i '/status_path/s/^;//g' "/etc/php/${php_v}/fpm/pool.d/www.conf"

  service php"${php_v}"-fpm reload
  display --indent 6 --text "- Reloading php${php_v}-fpm service" --result "DONE" --color GREEN

}

function php_set_version_on_config() {

  #$1 = ${php_v}
  #$2 = ${config_file}

  local php_v=$1
  local config_file=$2

  local php_installed_versions

  if [[ ${config_file} != "" ]];then
    
    if [[ ${php_v} == "" ]];then

      # Get array with installed versions
      php_installed_versions="$(php_check_installed_version)"
      
      # Select version to work
      php_v="$(php_select_version_to_work_with "${php_installed_versions}")"

    fi

    # Replacing PHP_V with PHP version number
    sed -i "s+PHP_V+${php_v}+g" "${config_file}"

    # Log
    log_event "debug" "Running: s+PHP_V+${php_v}+g ${config_file}"

  else

    # Log
    log_event "error" "Setting PHP version on config file, fails."
    log_event "debug" "Destination file '${config_file}' does not exists"

    return 1

  fi

}

function php_opcode_config() {

  #$1 = ${status}            // enable or disable
  #$1 = ${config_file}       // optional

  local status=$1
  local config_file=$2

  local val

  log_subsection "PHP Opcode Config"

  if [[ -z ${config_file} || ${config_file} == "" ]] ; then
  
    config_file="/etc/php/${PHP_V}/fpm/php.ini"

  fi

  if [[ $status == "enable" ]] ; then

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

  service php"${PHP_V}"-fpm reload
  display --indent 6 --text "- Reloading php${PHP_V}-fpm service" --result "DONE" --color GREEN

}

function php_count_installed_versions() {

  echo $(ls -d /etc/php/*/fpm/pool.d 2>/dev/null |wc -l)

}

function php_fpm_optimizations() {

  # TODO: need to check php versions installed (could be more than one)

  log_event "info" "RUNNING PHP-FPM OPTIMIZATION TOOL"

  log_subsection "PHP-FPM Optimization Tool"

  RAM_BUFFER="512"

  # Getting server info
  CPUS="$(grep -c "processor" /proc/cpuinfo)"
  RAM="$(grep MemTotal /proc/meminfo | awk '{print $2}' | xargs -I {} echo "scale=0; {}/1024^2" | bc)"

  # Calculating avg ram used by this process
  PHP_AVG_RAM="$(ps --no-headers -o "rss,cmd" -C php-fpm"${PHP_V}" | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"") }')"
  MYSQL_AVG_RAM="$(ps --no-headers -o "rss,cmd" -C mysqld | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"") }')"
  NGINX_AVG_RAM="$(ps --no-headers -o "rss,cmd" -C nginx | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"") }')"
  REDIS_AVG_RAM="$(ps --no-headers -o "rss,cmd" -C redis-server | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"") }')"
  NETDATA_AVG_RAM="$(ps --no-headers -o "rss,cmd" -C netdata | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"") }')"

  # Show/Log Server Info
  #display --indent 6 --text "- Creating user in MySQL: ${db_user}" --result "DONE" --color GREEN
  #display --indent 6 --text "Getting server info ..."
  log_subsection "Server Specs"
  display --indent 6 --text "PHP_V: ${PHP_V}"
  display --indent 6 --text "RAM_BUFFER: ${RAM_BUFFER}"
  display --indent 6 --text "CPUS: ${CPUS}"
  display --indent 6 --text "RAM: ${RAM}"
  display --indent 6 --text "PHP_AVG_RAM: ${PHP_AVG_RAM}"
  display --indent 6 --text "MYSQL_AVG_RAM: ${MYSQL_AVG_RAM}"
  display --indent 6 --text "NGINX_AVG_RAM: ${NGINX_AVG_RAM}"
  display --indent 6 --text "REDIS_AVG_RAM: ${REDIS_AVG_RAM}"
  display --indent 6 --text "NETDATA_AVG_RAM: ${NETDATA_AVG_RAM}"

  log_event "info" "PHP_V: ${PHP_V}"
  log_event "info" "RAM_BUFFER: ${RAM_BUFFER}"
  log_event "info" "CPUS: ${CPUS}"
  log_event "info" "RAM: ${RAM}"
  log_event "info" "PHP_AVG_RAM: ${PHP_AVG_RAM}"
  log_event "info" "MYSQL_AVG_RAM: ${MYSQL_AVG_RAM}"
  log_event "info" "NGINX_AVG_RAM: ${NGINX_AVG_RAM}"
  log_event "info" "REDIS_AVG_RAM: ${REDIS_AVG_RAM}"
  log_event "info" "NETDATA_AVG_RAM: ${NETDATA_AVG_RAM}"

  DELIMITER="="

  KEY="pm.max_children"
  PM_MAX_CHILDREN_ORIGIN=$(cat "/etc/php/${PHP_V}/fpm/pool.d/www.conf" | grep "^${KEY} ${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="pm.start_servers"
  PM_START_SERVERS_ORIGIN=$(cat "/etc/php/${PHP_V}/fpm/pool.d/www.conf" | grep "^${KEY} ${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="pm.min_spare_servers"
  PM_MIN_SPARE_SERVERS_ORIGIN=$(cat "/etc/php/${PHP_V}/fpm/pool.d/www.conf" | grep "^${KEY} ${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="pm.max_spare_servers"
  PM_MAX_SPARE_SERVERS_ORIGIN=$(cat "/etc/php/${PHP_V}/fpm/pool.d/www.conf" | grep "^${KEY} ${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="pm.max_requests"
  PM_MAX_REQUESTS_ORIGIN=$(cat "/etc/php/${PHP_V}/fpm/pool.d/www.conf" | grep "^${KEY} ${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="pm.process_idle_timeout"
  PM_PROCESS_IDDLE_TIMEOUT_ORIGIN=$(cat "/etc/php/${PHP_V}/fpm/pool.d/www.conf" | grep "^${KEY} ${DELIMITER}" | cut -f2- -d"$DELIMITER")

  # Show/Log PHP-FPM actual config
  #display --indent 6 --text "Getting PHP actual configuration ..."
  log_subsection "PHP actual configuration"
  display --indent 6 --text "PM_MAX_CHILDREN_ORIGIN: ${PM_MAX_CHILDREN_ORIGIN}"
  display --indent 6 --text "PM_START_SERVERS_ORIGIN: ${PM_START_SERVERS_ORIGIN}"
  display --indent 6 --text "PM_MIN_SPARE_SERVERS_ORIGIN: ${PM_MIN_SPARE_SERVERS_ORIGIN}"
  display --indent 6 --text "PM_MAX_SPARE_SERVERS_ORIGIN: ${PM_MAX_SPARE_SERVERS_ORIGIN}"
  display --indent 6 --text "PM_MAX_REQUESTS_ORIGIN: ${PM_MAX_REQUESTS_ORIGIN}"
  display --indent 6 --text "PM_PROCESS_IDDLE_TIMEOUT_ORIGIN: ${PM_PROCESS_IDDLE_TIMEOUT_ORIGIN}"

  log_event "info" "PM_MAX_CHILDREN: ${PM_MAX_CHILDREN_ORIGIN}"
  log_event "info" "PM_START_SERVERS: ${PM_START_SERVERS_ORIGIN}"
  log_event "info" "PM_MIN_SPARE_SERVERS: ${PM_MIN_SPARE_SERVERS_ORIGIN}"
  log_event "info" "PM_MAX_SPARE_SERVERS: ${PM_MAX_SPARE_SERVERS_ORIGIN}"
  log_event "info" "PM_MAX_REQUESTS: ${PM_MAX_REQUESTS_ORIGIN}"
  log_event "info" "PM_PROCESS_IDDLE_TIMEOUT: ${PM_PROCESS_IDDLE_TIMEOUT_ORIGIN}"

  #Settings	Value Explanation
  #max_children	(Total RAM - Memory used for Linux, DB, etc.) / process size
  #start_servers	Number of CPU cores x 4
  #min_spare_servers	Number of CPU cores x 2
  #max_spare_servers	Same as start_servers

  PM_MAX_CHILDREN=$(( ("${RAM}"*1024-("${MYSQL_AVG_RAM}"-"${NGINX_AVG_RAM}"-"${REDIS_AVG_RAM}"-"${NETDATA_AVG_RAM}"-"${RAM_BUFFER}"))/"${PHP_AVG_RAM}" ))
  PM_START_SERVERS=$(("${CPUS}"*4))
  PM_MIN_SPARE_SERVERS=$(("${CPUS}*2"))

  # This fix:
  # ALERT: [pool www] pm.min_spare_servers(8) and pm.max_spare_servers(32) cannot be greater than pm.max_children(30)
  PM_MAX_SPARE_SERVERS=$(("${PM_START_SERVERS}"*2))
  if [[ ${PM_MAX_CHILDREN} < ${PM_MAX_SPARE_SERVERS} ]]; then

    PM_MAX_SPARE_SERVERS=${PM_MAX_CHILDREN}

  fi
  
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

  log_event "info" "PM_MAX_CHILDREN: ${PM_MAX_CHILDREN}"
  log_event "info" "PM_START_SERVERS: ${PM_START_SERVERS}"
  log_event "info" "PM_MIN_SPARE_SERVERS: ${PM_MIN_SPARE_SERVERS}"
  log_event "info" "PM_MAX_SPARE_SERVERS: ${PM_MAX_SPARE_SERVERS}"
  log_event "info" "PM_MAX_REQUESTS: ${PM_MAX_REQUESTS}"
  log_event "info" "PM_PROCESS_IDDLE_TIMEOUT: ${PM_PROCESS_IDDLE_TIMEOUT}"

  log_break "true"

  while true; do

    echo -e "${YELLOW}${ITALIC} > Do you want to apply this optimizations?${ENDCOLOR}"
    read -p "Please type 'y' or 'n'" yn

    case $yn in

      [Yy]*)

        clear_last_line
        clear_last_line
        
        sed -ie "s|^pm\.max_children =.*$|pm\.max_children = ${PM_MAX_CHILDREN}|g" "/etc/php/${PHP_V}/fpm/pool.d/www.conf"
        sed -ie "s|^pm\.start_servers =.*$|pm\.start_servers = ${PM_START_SERVERS}|g" "/etc/php/${PHP_V}/fpm/pool.d/www.conf"
        sed -ie "s|^pm\.min_spare_servers =.*$|pm\.min_spare_servers = ${PM_MIN_SPARE_SERVERS}|g" "/etc/php/${PHP_V}/fpm/pool.d/www.conf"
        sed -ie "s|^pm\.max_spare_servers =.*$|pm\.max_spare_servers = ${PM_MAX_SPARE_SERVERS}|g" "/etc/php/${PHP_V}/fpm/pool.d/www.conf"
        sed -ie "s|^pm\.max_requests =.*$|pm\.max_requests = ${PM_MAX_REQUESTS}|g" "/etc/php/${PHP_V}/fpm/pool.d/www.conf"
        
        #Test the validity of your php-fpm configuration
        result=$(php-fpm"${PHP_V}" -t 2>&1 | grep -w "test" | cut -d"." -f3 | cut -d" " -f4)

        if [[ "${result}" = "successful" ]];then
          log_event "info" "PHP optimizations applied!"
          display --indent 6 --text "- Applying optimizations" --result "DONE" --color GREEN

        else
          debug=$(php-fpm"${PHP_V}" -t 2>&1)
          log_event "error" "PHP optimizations fail: ${debug}"
          display --indent 6 --text "- Applying optimizations" --result "FAIL" --color RED

        fi

        break
      ;;

      [Nn]*)

        log_event "info" "Skipping optimization ..."
        display --indent 6 --text "- Applying optimizations" --result "SKIPPED" --color YELLOW
        break
      ;;

      *) echo " > Please answer yes or no." ;;

    esac

  done

}

function php_select_version_to_work_with() {

  local php_v=$1
  
  local chosen_php_v

  chosen_php_v=$(whiptail --title "PHP Version Selection" --menu "Select the version of PHP you want to work with:" 20 78 10 $(for x in ${php_v}; do echo "${x} [X]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    log_event "debug" "Working with php${php_v}-fpm"

    # Return
    echo "${chosen_php_v}"

  else

    return 1

  fi

}