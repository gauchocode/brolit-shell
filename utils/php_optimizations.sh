#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc09
################################################################################

### Checking some things
#if [[ -z "${SFOLDER}" ]]; then
#  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
#  exit 0
#fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

php_fpm_optimizations() {

  # TODO: need to check php versions installed (could be more than one)

  #DISTRO_V=$(get_ubuntu_version)
  #if [ "$DISTRO_V" = "1804" ]; then
  #  PHP_V="7.2"  #Ubuntu 18.04 LTS Default
  #else
  #  PHP_V="7.4"  #Ubuntu 20.04 LTS Default
  #fi

  RAM_BUFFER="512"

  # Getting server info
  CPUS=$(grep -c "processor" /proc/cpuinfo)
  RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}' | xargs -I {} echo "scale=0; {}/1024^2" | bc)

  # Calculating avg ram used by this process
  PHP_AVG_RAM=$(ps --no-headers -o "rss,cmd" -C php-fpm"${PHP_V}" | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"") }')
  MYSQL_AVG_RAM=$(ps --no-headers -o "rss,cmd" -C mysqld | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"") }')
  NGINX_AVG_RAM=$(ps --no-headers -o "rss,cmd" -C nginx | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"") }')
  REDIS_AVG_RAM=$(ps --no-headers -o "rss,cmd" -C redis-server | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"") }')
  NETDATA_AVG_RAM=$(ps --no-headers -o "rss,cmd" -C netdata | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"") }')

  # Show/Log Server Info
  log_event "" "**************************************************" "true"
  log_event "" "****************** SERVER INFO  ******************" "true"
  log_event "" "**************************************************" "true"
  log_event "info" "PHP_V: ${PHP_V}" "true"
  log_event "info" "RAM_BUFFER: ${RAM_BUFFER}" "true"
  log_event "info" "CPUS: ${CPUS}" "true"
  log_event "info" "RAM: ${RAM}" "true"
  log_event "info" "PHP_AVG_RAM: ${PHP_AVG_RAM}" "true"
  log_event "info" "MYSQL_AVG_RAM: ${MYSQL_AVG_RAM}" "true"
  log_event "info" "NGINX_AVG_RAM: ${NGINX_AVG_RAM}" "true"
  log_event "info" "REDIS_AVG_RAM: ${REDIS_AVG_RAM}" "true"
  log_event "info" "NETDATA_AVG_RAM: ${NETDATA_AVG_RAM}" "true"
  
  #Settings	Value Explanation
  #max_children	(Total RAM - Memory used for Linux, DB, etc.) / process size
  #start_servers	Number of CPU cores x 4
  #min_spare_servers	Number of CPU cores x 2
  #max_spare_servers	Same as start_servers

  PM_MAX_CHILDREN=$(( ("${RAM}"*1024-("${MYSQL_AVG_RAM}"-"${NGINX_AVG_RAM}"-"${REDIS_AVG_RAM}"-"${NETDATA_AVG_RAM}"-"${RAM_BUFFER}"))/"${PHP_AVG_RAM}" ))
  PM_START_SERVERS=$(("${CPUS}"*4))
  PM_MIN_SPARE_SERVERS=$(("${CPUS}*2"))
  PM_MAX_SPARE_SERVERS=$(("${PM_START_SERVERS}"*2))
  PM_MAX_REQUESTS=500
  PM_PROCESS_IDDLE_TIMEOUT="10s"

  # Show/Log PHP-FPM optimal config
  log_event "" "**************************************************" "true"
  log_event "" "************* PHP-FPM OPTIMAL CONFIG *************" "true"
  log_event "" "**************************************************" "true"
  log_event "info" "PM_MAX_CHILDREN: ${PM_MAX_CHILDREN}" "true"
  log_event "info" "PM_START_SERVERS: ${PM_START_SERVERS}" "true"
  log_event "info" "PM_MIN_SPARE_SERVERS: ${PM_MIN_SPARE_SERVERS}" "true"
  log_event "info" "PM_MAX_SPARE_SERVERS: ${PM_MAX_SPARE_SERVERS}" "true"
  log_event "info" "PM_MAX_REQUESTS: ${PM_MAX_REQUESTS}" "true"
  log_event "info" "PM_PROCESS_IDDLE_TIMEOUT: ${PM_PROCESS_IDDLE_TIMEOUT}" "true"

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
  log_event "" "**************************************************" "true"
  log_event "" "************* PHP-FPM ACTUAL CONFIG **************" "true"
  log_event "" "**************************************************" "true"
  log_event "info" "PM_MAX_CHILDREN: ${PM_MAX_CHILDREN_ORIGIN}" "true"
  log_event "info" "PM_START_SERVERS: ${PM_START_SERVERS_ORIGIN}" "true"
  log_event "info" "PM_MIN_SPARE_SERVERS: ${PM_MIN_SPARE_SERVERS_ORIGIN}" "true"
  log_event "info" "PM_MAX_SPARE_SERVERS: ${PM_MAX_SPARE_SERVERS_ORIGIN}" "true"
  log_event "info" "PM_MAX_REQUESTS: ${PM_MAX_REQUESTS_ORIGIN}" "true"
  log_event "info" "PM_PROCESS_IDDLE_TIMEOUT: ${PM_PROCESS_IDDLE_TIMEOUT_ORIGIN}" "true"

  while true; do
    echo -e ${YELLOW}"> Do you want to apply this optimizations?"${ENDCOLOR}
    read -p "Please type 'y' or 'n'" yn

    case $yn in

    [Yy]*)
      
      sed -ie "s|^pm\.max_children =.*$|pm\.max_children = ${PM_MAX_CHILDREN}|g" "/etc/php/${PHP_V}/fpm/pool.d/www.conf"
      sed -ie "s|^pm\.start_servers =.*$|pm\.start_servers = ${PM_START_SERVERS}|g" "/etc/php/${PHP_V}/fpm/pool.d/www.conf"
      sed -ie "s|^pm\.min_spare_servers =.*$|pm\.min_spare_servers = ${PM_MIN_SPARE_SERVERS}|g" "/etc/php/${PHP_V}/fpm/pool.d/www.conf"
      sed -ie "s|^pm\.max_spare_servers =.*$|pm\.max_spare_servers = ${PM_MAX_SPARE_SERVERS}|g" "/etc/php/${PHP_V}/fpm/pool.d/www.conf"
      sed -ie "s|^pm\.max_requests =.*$|pm\.max_requests = ${PM_MAX_REQUESTS}|g" "/etc/php/${PHP_V}/fpm/pool.d/www.conf"
      
      log_event "info" "PHP optimizations applied ..." "true"

      #Test the validity of your php-fpm configuration
      result=$(php-fpm"${PHP_V}" -t 2>&1 | grep -w "test" | cut -d"." -f3 | cut -d" " -f4)

      if [ "${result}" = "successful" ];then
        log_event "success" "PHP optimizations applied!" "true"
      else
        debug=$(php-fpm"${PHP_V}" -t 2>&1)
        log_event "error" "PHP optimizations fail: $debug" "true"
      fi

      break
      ;;

    [Nn]*)
      log_event "info" "Skipping optimization ..." "true"
      break
      ;;

    *) echo " > Please answer yes or no." ;;

    esac

  done

}

################################################################################

log_event "" "********* RUNNING PHP OPTIMIZATION TOOL  *********" "true"

php_fpm_optimizations