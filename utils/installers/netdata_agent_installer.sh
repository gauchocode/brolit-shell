#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.4
################################################################################
#
# Netdata Installer
#
#   Ref: https://github.com/nextcloud/vm/blob/master/apps/netdata.sh
#
################################################################################

################################################################################
# Private: netdata alerts configuration
#
# Arguments:
#  none
#
# Outputs:
#  nothing
################################################################################

# TODO: need update

function _netdata_agent_alerts_configuration() {

  local netdata_config_dir

  netdata_config_dir="${NETDATA_INSTALL_DIR}/health.d/"

  # CPU
  cp "${BROLIT_MAIN_DIR}/config/netdata/health.d/cpu.conf" "${netdata_config_dir}/cpu.conf"

  # Web_log
  cp "${BROLIT_MAIN_DIR}/config/netdata/health.d/web_log.conf" "${netdata_config_dir}/web_log.conf"

  # MySQL
  cp "${BROLIT_MAIN_DIR}/config/netdata/health.d/mysql.conf" "${netdata_config_dir}/mysql.conf"

  # PHP-FPM
  cp "${BROLIT_MAIN_DIR}/config/netdata/health.d/php-fpm.conf" "${netdata_config_dir}/php-fpm.conf"

}

################################################################################
# Private: install netdata required packages
#
# Arguments:
#  none
#
# Outputs:
#  nothing
################################################################################

# TODO: needs update

function _netdata_agent_required_packages() {

  # Netdata agent requires docker and docker-compose
  package_update

  package_install_if_not "docker.io"
  package_install_if_not "docker-compose"

  # Force update brolit_conf.json
  PACKAGES_DOCKER_STATUS="enabled"

  json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.docker[].status" "${PACKAGES_DOCKER_STATUS}"

  export PACKAGES_DOCKER_STATUS

}

################################################################################
# Private: configure netdata alarm level
#
# Arguments:
#  none
#
# Outputs:
#  nothing
################################################################################

# TODO: need update

function _netdata_agent_email_config() {

  local netdata_alarm_level
  local health_alarm_notify_conf
  local delimiter

  # Telegram
  local send_email
  local default_recipient_email

  # Netdata health alarms config
  health_alarm_notify_conf="${NETDATA_INSTALL_DIR}/health_alarm_notify.conf"

  delimiter="="

  KEY="SEND_EMAIL"
  send_email="$(grep "^${KEY}${delimiter}" "${health_alarm_notify_conf}" | cut -f2- -d"${delimiter}")"

  KEY="DEFAULT_RECIPIENT_EMAIL"
  default_recipient_email="$(grep "^${KEY}${delimiter}" "${health_alarm_notify_conf}" | cut -f2- -d"${delimiter}")"

  send_email="YES"
  sed -i "s/^\(SEND_EMAIL\s*=\s*\).*\$/\1\"${send_email}\"/" ${health_alarm_notify_conf}

  default_recipient_email="${NOTIFICATION_EMAIL_MAILA}"

  # Choose the netdata alarm level
  netdata_alarm_level="${PACKAGES_NETDATA_NOTIFICATION_ALARM_LEVEL}"

  # Making changes on health_alarm_notify.conf
  sed -i "s/^\(DEFAULT_RECIPIENT_EMAIL\s*=\s*\).*\$/\1\"${default_recipient_email}|${netdata_alarm_level}\"/" $health_alarm_notify_conf

  # Uncomment the clear_alarm_always='YES' parameter on health_alarm_notify.conf
  if grep -q '^#.*clear_alarm_always' ${health_alarm_notify_conf}; then

    sed -i '/^#.*clear_alarm_always/ s/^#//' ${health_alarm_notify_conf}

  fi

  display --indent 6 --text "- Configuring Email notifications" --result "DONE" --color GREEN

}

################################################################################
# Private: netdata telegram configuration
#
# Arguments:
#  none
#
# Outputs:
#  nothing
################################################################################

# TODO: need update

function _netdata_agent_telegram_config() {

  local netdata_alarm_level
  local health_alarm_notify_conf
  local delimiter

  # Telegram
  local send_telegram
  local telegram_bot_token
  local default_recipient_telegram

  # Netdata health alarms config
  health_alarm_notify_conf="${NETDATA_INSTALL_DIR}/health_alarm_notify.conf"

  delimiter="="

  KEY="SEND_TELEGRAM"
  send_telegram="$(grep "^${KEY}${delimiter}" "${health_alarm_notify_conf}" | cut -f2- -d"${delimiter}")"

  KEY="TELEGRAM_BOT_TOKEN"
  telegram_bot_token="$(grep "^${KEY}${delimiter}" "${health_alarm_notify_conf}" | cut -f2- -d"${delimiter}")"

  KEY="DEFAULT_RECIPIENT_TELEGRAM"
  default_recipient_telegram="$(grep "^${KEY}${delimiter}" "${health_alarm_notify_conf}" | cut -f2- -d"${delimiter}")"

  telegram_bot_token="${PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_BOT_TOKEN}"

  send_telegram="YES"
  sed -i "s/^\(SEND_TELEGRAM\s*=\s*\).*\$/\1\"${send_telegram}\"/" ${health_alarm_notify_conf}
  sed -i "s/^\(TELEGRAM_BOT_TOKEN\s*=\s*\).*\$/\1\"${telegram_bot_token}\"/" ${health_alarm_notify_conf}

  default_recipient_telegram="${PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_CHAT_ID}"

  # Choose the netdata alarm level
  netdata_alarm_level="${PACKAGES_NETDATA_NOTIFICATION_ALARM_LEVEL}"

  # Making changes on health_alarm_notify.conf
  sed -i "s/^\(DEFAULT_RECIPIENT_TELEGRAM\s*=\s*\).*\$/\1\"${default_recipient_telegram}|${netdata_alarm_level}\"/" $health_alarm_notify_conf

  # Uncomment the clear_alarm_always='YES' parameter on health_alarm_notify.conf
  if grep -q '^#.*clear_alarm_always' ${health_alarm_notify_conf}; then

    sed -i '/^#.*clear_alarm_always/ s/^#//' ${health_alarm_notify_conf}

  fi

  display --indent 6 --text "- Configuring Telegram notifications" --result "DONE" --color GREEN

}

################################################################################
# Netdata Agent Installer
#
# Arguments:
#  none
#
# Outputs:
#  nothing
################################################################################

function netdata_agent_installer() {

  local netdata_agent

  log_subsection "Portainer Agent Installer"

  package_update

  package_install_if_not "docker.io"
  package_install_if_not "docker-compose"

  # Force update brolit_conf.json
  PACKAGES_DOCKER_STATUS="enabled"
  json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.docker[].status" "${PACKAGES_DOCKER_STATUS}"
  export PACKAGES_DOCKER_STATUS

  # Check if netdata_agent is running
  netdata_agent="$(docker_get_container_id "agent_netdata")"

  if [[ -z ${netdata_agent} ]]; then

    # Create project directory
    mkdir -p "${NETDATA_AGENT_PATH}"

    # Copy docker-compose.yml and .env files to project directory
    cp "${BROLIT_MAIN_DIR}/utils/installers/docker-compose/netdata_agent/docker-compose.yml" "${NETDATA_AGENT_PATH}"
    cp "${BROLIT_MAIN_DIR}/utils/installers/docker-compose/netdata_agent/.env" "${NETDATA_AGENT_PATH}"

    # Configure .env file
    project_set_config_var "${NETDATA_AGENT_PATH}/.env" "NETDATA_AGENT_PORT" "${PACKAGES_NETDATA_AGENT_CONFIG_PORT}" "none"

    # Enable port in firewall
    firewall_allow "${PACKAGES_NETDATA_AGENT_CONFIG_PORT}"

    # Run docker-compose pull on specific directory
    docker-compose -f "${NETDATA_AGENT_PATH}/docker-compose.yml" pull

    # Run docker-compose up -d on specific directory
    docker-compose -f "${NETDATA_AGENT_PATH}/docker-compose.yml" up -d

    clear_previous_lines "3"

    return 0

  else

    log_event "warning" "Netdata Agent is already installed" "false"

    return 1

  fi

}

################################################################################
# Netdata uninstaller
#
# Arguments:
#  none
#
# Outputs:
#  nothing
################################################################################

# TODO: Netdata and Netdata agent use same docker image, 
# so we need to check if there is another container using the same image before unninstalling it

function netdata_agent_uninstaller() {

    log_subsection "Netdata Agent Installer"

    # Get Netdata Container ID
    container_id="$(docker ps | grep agent_netdata | awk '{print $1;}')"

    # Stop Netdata Container
    result_stop="$(docker stop "${container_id}")"
    if [[ -z ${result_stop} ]]; then
        display --indent 6 --text "- Stopping Netdata Agent container" --result "FAIL" --color RED
        log_event "error" "Netdata Agent container not found." "true"
        return 1
    fi

    display --indent 6 --text "- Stopping Netdata Agent container" --result "DONE" --color GREEN

    # Remove Netdata Container
    result_remove="$(docker rm -f agent_netdata)"
    if [[ -z ${result_remove} ]]; then
        display --indent 6 --text "- Deleting Netdata Agent container" --result "FAIL" --color RED
        log_event "error" "Deleting Netdata Agent container." "true"
        return 1
    fi

    # If firewall enable, deny netdata agent port
    firewall_deny "${PACKAGES_NETDATA_AGENT_CONFIG_PORT}"

    # Remove Netdata Data
    rm --recursive "${NETDATA_AGENT_PATH}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && ${PACKAGES_NETDATA_AGENT_STATUS} == "enabled" ]]; then

        # Change global var value to "disabled"
        PACKAGES_NETDATA_AGENT_STATUS="disabled"

        json_write_field "${BROLIT_CONFIG_FILE}" "PACKAGES.netdata_agent[].status" "${PACKAGES_NETDATA_AGENT_STATUS}"

        export PACKAGES_NETDATA_AGENT_STATUS

        return 0

    else

        return 1

    fi

}

################################################################################
# Netdata configuration
#  Ref: netdata config dir https://github.com/netdata/netdata/issues/4182
#
# Arguments:
#  none
#
# Outputs:
#  nothing
################################################################################

# TODO: need update

function netdata_agent_configuration() {

  # Check if mysql or mariadb are enabled
  if [[ ${PACKAGES_MARIADB_STATUS} == "enabled" ]] || [[ ${PACKAGES_MYSQL_STATUS} == "enabled" ]]; then

    ## MySQL
    mysql_user_create "netdata" "" "localhost"
    mysql_user_grant_privileges "netdata" "*" "localhost"

    ## Copy mysql config
    cat "${BROLIT_MAIN_DIR}/config/netdata/python.d/mysql.conf" >"${NETDATA_INSTALL_DIR}/python.d/mysql.conf"

    log_event "info" "MySQL config done!" "false"
    display --indent 6 --text "- MySQL configuration" --result "DONE" --color GREEN

  fi

  # Check if monit is installed
  if [[ ${PACKAGES_MONIT_STATUS} == "enabled" ]]; then

    ## Monit
    cat "${BROLIT_MAIN_DIR}/config/netdata/python.d/monit.conf" >"${NETDATA_INSTALL_DIR}/python.d/monit.conf"

    ## Log
    log_event "info" "Monit configuration for netdata done." "false"
    display --indent 6 --text "- Monit configuration" --result "DONE" --color GREEN

  fi

  # Web log
  cat "${BROLIT_MAIN_DIR}/config/netdata/python.d/web_log.conf" >"${NETDATA_INSTALL_DIR}/python.d/web_log.conf"

  log_event "info" "Nginx Web Log config done!" "false"
  display --indent 6 --text "- Nginx Web Log configuration" --result "DONE" --color GREEN

  # Health alarm notify
  cat "${BROLIT_MAIN_DIR}/config/netdata/health_alarm_notify.conf" >"${NETDATA_INSTALL_DIR}/health_alarm_notify.conf"

  log_event "info" "Health alarm config done!" "false"
  display --indent 6 --text "- Health alarm configuration" --result "DONE" --color GREEN

  # Alerts
  _netdata_agent_alerts_configuration

  _netdata_agent_email_config

  # Telegram notification status
  if [[ ${PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_STATUS} == "enabled" ]]; then

    # Telegram notification config
    _netdata_agent_telegram_config

    # Send test alarms to sysadmin
    display --indent 8 --text "Now you can test notifications running:" --tcolor YELLOW
    display --indent 8 --text "/usr/libexec/netdata/plugins.d/alarm-notify.sh test" --tcolor YELLOW

  fi

  # Reload service
  systemctl daemon-reload && systemctl enable netdata --quiet && service netdata start

  # Log
  log_event "info" "Netdata configuration finished" "false"
  display --indent 6 --text "- Configuring netdata" --result "DONE" --color GREEN

}
