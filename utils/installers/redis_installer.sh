#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.4
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

  redis_pass="$(openssl rand 60 | openssl base64 -A)"

  # Write redis_pass on redis.conf
  sed -i "requirepass ${redis_pass}" >>"${redis_conf}"

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
  package_purge "redis redis-server redis-tools"

  return $?

}
