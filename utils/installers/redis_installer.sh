#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc3
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