#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.10
################################################################################

function redis_installer() {

  log_subsection "Redis Installer"

  # Install redis
  package_install "redis"
  package_install "redis-server"

  systemctl enable redis-server.service --quiet

  # Creating config file
  cp "${BROLIT_MAIN_DIR}/config/redis/redis.conf" "/etc/redis/redis.conf"

  # Service restart
  service redis-server restart

}

function redis_configure() {

  local redis_conf
  local redis_pass

  redis_conf="/etc/redis/redis.conf"

  redis_pass="$(openssl rand 10 | openssl base64 -A)"

  # Write redis_pass on redis.conf
  sed -i "s/TO_CHANGE/${redis_pass}/g" "${redis_conf}"

  # Log
  log_event "info" "Configuring redis-server" "false"
  log_event "info" "Redis server config on ${redis_conf}" "false"
  display --indent 6 --text "- Configuring redis-server" --result "DONE" --color GREEN
  display --indent 8 --text "Password set on ${redis_conf}" --tcolor yellow

  # Service restart
  service redis-server restart

}

function redis_purge() {

  local redis_conf

  log_subsection "Redis Installer"

  # Remove  redis.conf
  redis_conf="/etc/redis/redis.conf"
  rm "${redis_conf}"

  # Remove packages
  package_purge "redis"
  package_purge "redis-server"
  package_purge "redis-tools"

  return $?

}
