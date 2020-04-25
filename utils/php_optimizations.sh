#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc01
################################################################################
#
# Ref: https://serverfault.com/questions/939436/understand-correctly-pm-max-children-tuning
#
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

SFOLDER="/root/broobe-utils-scripts"
source "${SFOLDER}/libs/commons.sh"

################################################################################

# TODO: need to check php versions installed (could be more than one)

DISTRO_V=$(get_ubuntu_version)
if [ "$DISTRO_V" = "1804" ]; then
  PHP_V="7.2"  #Ubuntu 18.04 LTS Default
else
  PHP_V="7.4"  #Ubuntu 20.04 LTS Default
fi

RAM_BUFFER="512"

# Getting server info
CPUS=$(grep -c "processor" /proc/cpuinfo)
RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}' | xargs -I {} echo "scale=0; {}/1024^2" | bc)

# Calculating avg ram used by this process
PHP_AVG_RAM=$(ps --no-headers -o "rss,cmd" -C php-fpm7.2 | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"") }')
MYSQL_AVG_RAM=$(ps --no-headers -o "rss,cmd" -C mysqld | awk '{ sum+=$1 } END { printf ("%d%s\n", sum/NR/1024,"") }')

# MOCK
#PHP_AVG_RAM=50
#MYSQL_AVG_RAM=1500

echo -e ${CYAN}"*******************************************"${ENDCOLOR}
echo -e ${CYAN}"**************** VPS STATS ****************"${ENDCOLOR}
echo -e ${CYAN}"*******************************************"${ENDCOLOR}
echo -e ${CYAN}"PHP_V: ${PHP_V}"${ENDCOLOR}
echo -e ${CYAN}"RAM_BUFFER: ${RAM_BUFFER}"${ENDCOLOR}
echo -e ${CYAN}"CPUS: ${CPUS}"${ENDCOLOR}
echo -e ${CYAN}"RAM: ${RAM}"${ENDCOLOR}
echo -e ${CYAN}"PHP_AVG_RAM: ${PHP_AVG_RAM}"${ENDCOLOR}
echo -e ${CYAN}"MYSQL_AVG_RAM: ${MYSQL_AVG_RAM}"${ENDCOLOR}
echo -e ${CYAN}"*******************************************"${ENDCOLOR}

# php.ini broobe standard configuration
#echo " > Moving php configuration file ..." >>$LOG
#cat confs/php.ini > /etc/php/${PHP_V}/fpm/php.ini

# fpm broobe standard configuration
#echo " > Moving fpm configuration file ..." >>$LOG
#cat confs/php/${SERVER_MODEL}/www.conf > /etc/php/${PHP_V}/fpm/pool.d/www.conf

PM_MAX_CHILDREN=$(( (${RAM}*1024-(${MYSQL_AVG_RAM}-${RAM_BUFFER}))/${PHP_AVG_RAM} ))
PM_START_SERVERS=$((${PM_MAX_CHILDREN}/4))
PM_MIN_SPARE_SERVERS=$((${PM_START_SERVERS}))
PM_MAX_SPARE_SERVERS=$((${PM_START_SERVERS}*2))
PM_MAX_REQUESTS=500

echo -e ${GREEN}"************** OPTIMAL CONF ***************"${ENDCOLOR}
echo -e ${GREEN}"*******************************************"${ENDCOLOR}
echo -e ${GREEN}"PM_MAX_CHILDREN: ${PM_MAX_CHILDREN}"${ENDCOLOR}
echo -e ${GREEN}"PM_START_SERVERS: ${PM_START_SERVERS}"${ENDCOLOR}
echo -e ${GREEN}"PM_MIN_SPARE_SERVERS: ${PM_MIN_SPARE_SERVERS}"${ENDCOLOR}
echo -e ${GREEN}"PM_MAX_SPARE_SERVERS: ${PM_MAX_SPARE_SERVERS}"${ENDCOLOR}
echo -e ${GREEN}"PM_MAX_REQUESTS: ${PM_MAX_REQUESTS}"${ENDCOLOR}
echo -e ${GREEN}"*******************************************"${ENDCOLOR}

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

echo -e ${RED}"*************** ACTUAL CONF ***************"${ENDCOLOR}
echo -e ${RED}"*******************************************"${ENDCOLOR}
echo -e ${RED}"PM_MAX_CHILDREN: ${PM_MAX_CHILDREN_ORIGIN}"${ENDCOLOR}
echo -e ${RED}"PM_START_SERVERS: ${PM_START_SERVERS_ORIGIN}"${ENDCOLOR}
echo -e ${RED}"PM_MIN_SPARE_SERVERS: ${PM_MIN_SPARE_SERVERS_ORIGIN}"${ENDCOLOR}
echo -e ${RED}"PM_MAX_SPARE_SERVERS: ${PM_MAX_SPARE_SERVERS_ORIGIN}"${ENDCOLOR}
echo -e ${RED}"PM_MAX_REQUESTS: ${PM_MAX_REQUESTS_ORIGIN}"${ENDCOLOR}
echo -e ${RED}"*******************************************"${ENDCOLOR}

#
# PROBAR ESTO
#sed -ie "s|^pm\.max_children =.*$|pm\.max_children = ${PM_MAX_CHILDREN}|g" /etc/php/${PHP_V}/fpm/pool.d/www.conf
#sed -ie "s|^pm\.start_servers =.*$|pm\.start_servers = ${PM_START_SERVERS}|g" /etc/php/${PHP_V}/fpm/pool.d/www.conf
#sed -ie "s|^pm\.min_spare_servers =.*$|pm\.min_spare_servers = ${PM_MIN_SPARE_SERVERS}|g" /etc/php/${PHP_V}/fpm/pool.d/www.conf
#sed -ie "s|^pm\.max_spare_servers =.*$|pm\.max_spare_servers = ${PM_MAX_SPARE_SERVERS}|g" /etc/php/${PHP_V}/fpm/pool.d/www.conf
#sed -ie "s|^pm\.max_requests =.*$|pm\.max_requests = ${PM_MAX_REQUESTS}|g" /etc/php/${PHP_V}/fpm/pool.d/www.conf
#

#Test the validity of your php-fpm configuration syntax
php-fpm${PHP_V} -t