#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.12
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

function _netdata_alerts_configuration() {

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

  # RAM
  cp "${BROLIT_MAIN_DIR}/config/netdata/health.d/ram-usage.conf" "${netdata_config_dir}/ram-usage.conf"

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

function _netdata_required_packages() {

  local ubuntu_version
  local install_log="/var/log/brolit/netdata_install.log"

  ubuntu_version="$(get_ubuntu_version)"

  display --indent 6 --text "- Installing netdata required packages"

  if [[ ${ubuntu_version} == "2004" || ${ubuntu_version} == "2204" ]]; then

    # Redirect all package management output to log file
    {
      apt-get -y remove netdata >/dev/null 2>&1 || true
      apt-get -y autoremove >/dev/null 2>&1 || true
      apt-get -y update >/dev/null 2>&1
      apt-get -y install netdata-repo >/dev/null 2>&1
      apt-get -y update >/dev/null 2>&1
      apt-get -y install netdata >/dev/null 2>&1
    } >> "${install_log}" 2>&1

    display --indent 6 --text "- Installing netdata required packages" --result "DONE" --color GREEN

  else

    return 1

  fi

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

function _netdata_email_config() {

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
  default_recipient_email="$(grep "^${KEY}${delimiter}" "${health_alarm_notify_notify_conf}" | cut -f2- -d"${delimiter}")"

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

function _netdata_telegram_config() {

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
# Netdata installer
#
# Arguments:
#  none
#
# Outputs:
#  nothing
################################################################################

function netdata_installer() {

  declare -g NETDATA_INSTALL_DIR
  local claim_token=""
  local claim_rooms=""

  log_subsection "Netdata Installer"

  # Create log directory if it doesn't exist
  mkdir -p "/var/log/brolit" >/dev/null 2>&1
  local install_log="/var/log/brolit/netdata_install.log"

  # Clear the screen and show initial message
  clear_previous_lines "2"
  printf "\e[34m    [·] Netdata Installer\e[0m\n"
  echo "    —————————————————————————————————————————————————————"

  # Cleanup existing installation
  {
    systemctl stop netdata >/dev/null 2>&1 || true
    apt-get -y remove netdata >/dev/null 2>&1 || true
    apt-get -y autoremove >/dev/null 2>&1 || true
    rm -rf /opt/netdata
    rm -rf /etc/netdata
    rm -rf /var/log/netdata
    rm -rf /var/cache/netdata
    rm -rf /var/lib/netdata
    rm -rf /usr/lib/netdata
    rm -rf /usr/libexec/netdata
    rm -rf /usr/share/netdata
    rm -rf /usr/lib/systemd/system/netdata.service
    systemctl daemon-reload
  } >> "${install_log}" 2>&1

  # Install required packages
  display --indent 6 --text "- Installing netdata required packages"
  {
    _netdata_required_packages
  } >> "${install_log}" 2>&1
  display --indent 6 --text "- Installing netdata required packages" --result "DONE" --color GREEN

  # Ask for claim token if not set in config
  if [[ -z "${PACKAGES_NETDATA_CONFIG_CLAIM_TOKEN}" ]]; then
    echo ""
    echo "To connect this node to Netdata Cloud, you need a claim token."
    echo "You can get this token from: https://app.netdata.cloud"
    echo ""
    read -p "Enter your Netdata claim token (press Enter to skip): " claim_token
    
    if [[ ! -z "$claim_token" ]]; then
      echo ""
      echo "Enter your Netdata claim room ID (not the room name)."
      echo "You can find the room ID in the URL when viewing the room in Netdata Cloud:"
      echo "Example: https://app.netdata.cloud/spaces/...</space-id>/rooms/<room-id>"
      echo "Just enter the <room-id> part"
      echo ""
      read -p "Room ID: " claim_rooms
    fi
  else
    claim_token="${PACKAGES_NETDATA_CONFIG_CLAIM_TOKEN}"
    claim_rooms="${PACKAGES_NETDATA_CONFIG_CLAIM_ROOMS}"
  fi

  display --indent 6 --text "- Downloading and installing netdata"

  # Download and run installation with output redirected to log
  {
    # Download the kickstart script
    wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh >> "${install_log}" 2>&1

    # Prepare installation command
    local install_cmd="bash /tmp/netdata-kickstart.sh --non-interactive --stable-channel"
    
    # Add claim parameters if token is provided
    if [[ ! -z "$claim_token" ]]; then
      install_cmd+=" --claim-token ${claim_token}"
      if [[ ! -z "$claim_rooms" ]]; then
        install_cmd+=" --claim-rooms ${claim_rooms}"
      fi
      install_cmd+=" --claim-url https://app.netdata.cloud"
    fi

    # Run the installation command
    eval "${install_cmd}" >> "${install_log}" 2>&1
  }

  # Determine the installation directory
  if [[ -d "/etc/netdata" ]]; then
    NETDATA_INSTALL_DIR="/etc/netdata"
  elif [[ -d "/opt/netdata/etc/netdata" ]]; then
    NETDATA_INSTALL_DIR="/opt/netdata/etc/netdata"
  else
    log_event "error" "Netdata installation directory not found" "false"
    display --indent 6 --text "- Netdata installation" --result "ERROR" --color RED
    return 1
  fi

  # Configure MySQL monitoring
  display --indent 6 --text "- Creating MySQL user: netdata"
  if create_mysql_user "netdata" "netdata" >> "${install_log}" 2>&1; then
    display --indent 6 --text "- Creating MySQL user: netdata" --result "DONE" --color GREEN
  else
    display --indent 6 --text "- Creating MySQL user: netdata" --result "WARNING" --color YELLOW
    log_event "warning" "MySQL user might already exist" "false"
  fi

  display --indent 6 --text "- Granting privileges to netdata"
  if grant_mysql_privileges "netdata" "netdata" >> "${install_log}" 2>&1; then
    display --indent 6 --text "- Granting privileges to netdata" --result "DONE" --color GREEN
  fi

  display --indent 6 --text "- MySQL configuration"
  if configure_mysql_netdata >> "${install_log}" 2>&1; then
    display --indent 6 --text "- MySQL configuration" --result "DONE" --color GREEN
  fi

  # Check if mysql or mariadb are enabled
  if [[ ${PACKAGES_MARIADB_STATUS} == "enabled" ]] || [[ ${PACKAGES_MYSQL_STATUS} == "enabled" ]]; then
    ## MySQL
    mysql_user_create "netdata" "" "localhost" || true  # Continue even if user exists
    mysql_user_grant_privileges "netdata" "*" "localhost"

    ## Copy mysql config if the source file exists
    if [[ -f "${BROLIT_MAIN_DIR}/config/netdata/python.d/mysql.conf" ]]; then
      cp "${BROLIT_MAIN_DIR}/config/netdata/python.d/mysql.conf" "${NETDATA_INSTALL_DIR}/python.d/mysql.conf"
    fi

    log_event "info" "MySQL config done!" "false"
    display --indent 6 --text "- MySQL configuration" --result "DONE" --color GREEN
  fi

  # Configure web log if nginx is installed
  nginx_command="$(command -v nginx)"
  if [[ -x ${nginx_command} ]]; then
    {
      if [[ -f "${BROLIT_MAIN_DIR}/config/netdata/python.d/web_log.conf" ]]; then
        cp "${BROLIT_MAIN_DIR}/config/netdata/python.d/web_log.conf" "${NETDATA_INSTALL_DIR}/python.d/web_log.conf"
      fi
    } >> "${install_log}" 2>&1
    display --indent 6 --text "- Nginx Web Log configuration" --result "DONE" --color GREEN
  fi

  # Copy health configuration files
  {
    for health_conf in cpu web_log mysql php-fpm ram-usage; do
      if [[ -f "${BROLIT_MAIN_DIR}/config/netdata/health.d/${health_conf}.conf" ]]; then
        cp "${BROLIT_MAIN_DIR}/config/netdata/health.d/${health_conf}.conf" "${NETDATA_INSTALL_DIR}/health.d/${health_conf}.conf"
      fi
    done
  } >> "${install_log}" 2>&1
  display --indent 6 --text "- Health alarm configuration" --result "DONE" --color GREEN

  # Configure email notifications
  {
    configure_email_notifications
  } >> "${install_log}" 2>&1
  display --indent 6 --text "- Configuring Email notifications" --result "DONE" --color GREEN

  # Final configuration
  {
    if [[ ! -z "$claim_token" ]]; then
      # Download and run installation with output redirected to log
      wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh
      
      # Prepare installation command
      local install_cmd="bash /tmp/netdata-kickstart.sh --non-interactive --stable-channel"
      install_cmd+=" --claim-token ${claim_token}"
      if [[ ! -z "$claim_rooms" ]]; then
        install_cmd+=" --claim-rooms ${claim_rooms}"
      fi
      install_cmd+=" --claim-url https://app.netdata.cloud"
      
      # Run the installation command
      eval "${install_cmd}"
    fi
    
    # Ensure netdata service is enabled and running
    systemctl enable netdata >/dev/null 2>&1
    systemctl restart netdata >/dev/null 2>&1
  } >> "${install_log}" 2>&1
  display --indent 6 --text "- Configuring netdata" --result "DONE" --color GREEN

  export NETDATA_INSTALL_DIR
  return 0

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

function netdata_uninstaller() {

  log_subsection "Netdata Installer"

  # Log
  log_event "warning" "Uninstalling Netdata ..." "false"

  # Stop netdata service
  service netdata stop

  package_purge "netdata"

  # Deleting mysql user
  if [[ ${PACKAGES_MARIADB_STATUS} == "enabled" ]] || [[ ${PACKAGES_MYSQL_STATUS} == "enabled" ]]; then
    mysql_user_delete "netdata" "localhost"
  fi

  # Deleting nginx server files
  if [[ ${PACKAGES_NGINX_STATUS} == "enabled" ]]; then

    ## Search for netdata nginx server file
    netdata_server_file="$(grep "proxy_pass http://127.0.0.1:19999/" /etc/nginx/sites-available/* | cut -d ":" -f1)"
    netdata_server_file_name="$(basename "${netdata_server_file}")"

    nginx_server_delete "${netdata_server_file_name}"

  fi

  # Deleting installation files
  rm --force --recursive "/etc/netdata"
  rm --force --recursive "/opt/netdata"
  rm --force --recursive "/usr/lib/netdata"
  rm --force --recursive "/usr/share/netdata"
  rm --force --recursive "/usr/libexec/netdata"
  rm --force "/usr/sbin/netdata"
  rm --force "/etc/logrotate.d/netdata"
  rm --force "/etc/systemd/system/netdata.service"
  rm --force "/lib/systemd/system/netdata.service"
  rm --force "/usr/lib/systemd/system/netdata.service"
  rm --force "/etc/systemd/system/netdata-updater.service"
  rm --force "/lib/systemd/system/netdata-updater.service"
  rm --force "/usr/lib/systemd/system/netdata-updater.service"
  rm --force "/etc/systemd/system/netdata-updater.timer"
  rm --force "/lib/systemd/system/netdata-updater.timer"
  rm --force "/usr/lib/systemd/system/netdata-updater.timer"
  rm --force "/etc/init.d/netdata"
  rm --force "/etc/periodic/daily/netdata-updater"
  rm --force "/etc/cron.daily/netdata-updater"
  rm --force "/etc/cron.d/netdata-updater"

  # New config value
  NETDATA_CONFIG_STATUS="disabled"

  log_event "info" "Netdata uninstalled" "false"
  display --indent 6 --text "- Uninstalling netdata" --result "DONE" --color GREEN

  export NETDATA_CONFIG_STATUS

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

function netdata_configuration() {

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
  _netdata_alerts_configuration

  _netdata_email_config

  # Telegram notification status
  if [[ ${PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_STATUS} == "enabled" ]]; then

    # Telegram notification config
    _netdata_telegram_config

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
