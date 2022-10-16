#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.3
################################################################################

function redis_installer() {

  log_subsection "Redis Installer"

  # Install redis
  package_install_if_not "redis"
  package_install_if_not "redis-server"

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

  log_subsection "Redis Installer"

  # Remove  redis.conf
  rm "${redis_conf}"

  # Log
  display --indent 6 --text "- Removing redis and libraries"
  log_event "info" "Removing redis and libraries..." "false"

  # Remove packages
  package_purge "redis redis-server redis-tools"

  exitstatus=$?
  if [[ ${exitstatus} -ne 0 ]]; then

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Removing redis and libraries" --result "FAILED" --color RED
    log_event "error" "Removing redis and libraries..." "false"

    return 1

  else

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Removing redis and libraries" --result "DONE" --color GREEN
    log_event "info" "redis removed" "false"

    return 0

  fi

}
