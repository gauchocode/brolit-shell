#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc5
################################################################################

function redis_installer() {

  # Install redis
  package_install_if_not "redis-server"

  systemctl enable redis-server.service

  # Creating config file
  cp "${BROLIT_MAIN_DIR}/config/redis/redis.conf" "/etc/redis/redis.conf"

  # Service restart
  service redis-server restart

}

function redis_configure() {

  local redis_conf
  local redis_pass

  redis_conf="/etc/redis/redis.conf"

  redis_pass="$(openssl rand 60 | openssl base64 -A)"

  # Write redis_pass on redis.conf
  sed -i "s/^# requirepass.*/requirepass ${redis_pass}/" "${redis_conf}"

  # Service restart
  service redis-server restart

}
