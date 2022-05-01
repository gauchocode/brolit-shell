#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc4
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

  local netdata_install_dir
  local netdata_config_dir

  #netdata_install_dir="/etc/netdata"
  netdata_install_dir="/etc/netdata"
  netdata_config_dir="${netdata_install_dir}/health.d/"

  # CPU
  cp "${BROLIT_MAIN_DIR}/config/netdata/health.d/cpu.conf" "${netdata_config_dir}/cpu.conf"

  # Web_log
  cp "${BROLIT_MAIN_DIR}/config/netdata/health.d/web_log.conf" "${netdata_config_dir}/web_log.conf"

  # MySQL
  cp "${BROLIT_MAIN_DIR}/config/netdata/health.d/mysql.conf" "${netdata_config_dir}/mysql.conf"

  # PHP-FPM
  cp "${BROLIT_MAIN_DIR}/config/netdata/health.d/php-fpm.conf" "${netdata_config_dir}/php-fpm.conf"

  # Anomalies
  #cp "${BROLIT_MAIN_DIR}/config/netdata/health.d/anomalies.conf" "${netdata_config_dir}/anomalies.conf"

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

  ubuntu_version="$(get_ubuntu_version)"

  display --indent 6 --text "- Installing netdata required packages"

  if [[ ${ubuntu_version} == "1804" ]]; then

    apt-get --yes install zlib1g-dev uuid-dev libuv1-dev liblz4-dev libjudy-dev libssl-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config curl python python-mysqldb lm-sensors libmnl netcat nodejs python-ipaddress python-dnspython iproute2 python-beanstalkc libuv liblz4 Judy openssl -qq >/dev/null

  elif [[ ${ubuntu_version} == "2004" ]]; then

    apt-get --yes install curl python3-mysqldb python3-pip lm-sensors libmnl-dev netcat openssl -qq >/dev/null

  else

    return 1

  fi

  # Log
  clear_previous_lines "2"
  display --indent 6 --text "- Installing netdata required packages" --result "DONE" --color GREEN

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
  health_alarm_notify_conf="/etc/netdata/health_alarm_notify.conf"

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

function _netdata_telegram_config() {

  local netdata_alarm_level
  local health_alarm_notify_conf
  local delimiter

  # Telegram
  local send_telegram
  local telegram_bot_token
  local default_recipient_telegram

  # Netdata health alarms config
  health_alarm_notify_conf="/etc/netdata/health_alarm_notify.conf"

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

  _netdata_required_packages

  log_event "info" "Installing Netdata ..." "false"
  display --indent 6 --text "- Downloading and compiling netdata"

  # Download and run
  bash <(curl -Ss https://my-netdata.io/kickstart.sh) all --dont-wait --disable-telemetry &>/dev/null

  # Kill netdata and copy service
  #killall netdata && cp system/netdata.service /etc/systemd/system/

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Log
    clear_previous_lines "2"
    log_event "info" "Netdata installation finished" "false"
    display --indent 6 --text "- Downloading and compiling netdata" --result "DONE" --color GREEN

    # If nginx is installed
    nginx_command="$(command -v nginx)"
    if [[ -x ${nginx_command} ]]; then

      # Netdata nginx proxy configuration
      nginx_server_create "${PACKAGES_NETDATA_CONFIG_SUBDOMAIN}" "netdata" "single" ""

      # Nginx Auth
      nginx_generate_encrypted_auth "${PACKAGES_NETDATA_CONFIG_USER}" "${PACKAGES_NETDATA_CONFIG_USER_PASS}"

      if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

        # Confirm ROOT_DOMAIN
        root_domain="$(domain_get_root "${PACKAGES_NETDATA_CONFIG_SUBDOMAIN}")"

        # Cloudflare API
        cloudflare_set_record "${root_domain}" "${PACKAGES_NETDATA_CONFIG_SUBDOMAIN}" "A" "false" "${SERVER_IP}"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then

            # HTTPS with Certbot
            certbot_certificate_install "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${PACKAGES_NETDATA_CONFIG_SUBDOMAIN}"

          fi

        fi

      fi

      display --indent 6 --text "- Netdata installation" --result "DONE" --color GREEN

    fi

  else

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

function netdata_uninstaller() {

  # Log
  clear_previous_lines "2"
  log_event "warning" "Uninstalling Netdata ..." "false"

  # Stop netdata service
  service netdata stop

  package_purge "netdata"

  # Deleting mysql user
  mysql_user_delete "netdata" "localhost"

  # Remove nginx server config files

  ## Search for netdata nginx server file
  netdata_server_file="$(grep "proxy_pass http://127.0.0.1:19999/" /etc/nginx/sites-available/* | cut -d ":" -f1)"
  netdata_server_file_name="$(basename "${netdata_server_file}")"

  ## Deleting nginx server files
  nginx_server_delete "${netdata_server_file_name}"

  # Deleting installation files
  rm --force --recursive "/etc/netdata"
  rm --force --recursive "/opt/netdata"
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

function _netdata_anomalies_configuration() {

  # New: anomalies support
  ## Ref: https://learn.netdata.cloud/docs/agent/collectors/python.d.plugin/anomalies

  ## need to make this trick
  sudo su -s /bin/bash netdata <<EOF
pip3 install --quiet --user netdata-pandas==0.0.38 numba==0.50.1 scikit-learn==0.23.2 pyod==0.8.3
EOF

  cp "/usr/lib/netdata/conf.d/python.d.conf" "/etc/netdata/python.d.conf"
  cp "/usr/lib/netdata/conf.d/python.d/anomalies.conf" "/etc/netdata/python.d/anomalies.conf"

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
    cat "${BROLIT_MAIN_DIR}/config/netdata/python.d/mysql.conf" >"/etc/netdata/python.d/mysql.conf"

    log_event "info" "MySQL config done!" "false"
    display --indent 6 --text "- MySQL configuration" --result "DONE" --color GREEN

  fi

  # Check if monit is installed
  if [[ ${PACKAGES_MONIT_STATUS} == "enabled" ]]; then

    ## Monit
    cat "${BROLIT_MAIN_DIR}/config/netdata/python.d/monit.conf" >"/etc/netdata/python.d/monit.conf"

    ## Log
    log_event "info" "Monit configuration for netdata done." "false"
    display --indent 6 --text "- Monit configuration" --result "DONE" --color GREEN

  fi

  # Web log
  cat "${BROLIT_MAIN_DIR}/config/netdata/python.d/web_log.conf" >"/etc/netdata/python.d/web_log.conf"

  log_event "info" "Nginx Web Log config done!" "false"
  display --indent 6 --text "- Nginx Web Log configuration" --result "DONE" --color GREEN

  # Health alarm notify
  cat "${BROLIT_MAIN_DIR}/config/netdata/health_alarm_notify.conf" >"/etc/netdata/health_alarm_notify.conf"

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
    /usr/libexec/netdata/plugins.d/alarm-notify.sh test

  fi

  # Anomalies
  #_netdata_anomalies_configuration

  # Reload service
  systemctl daemon-reload && systemctl enable netdata && service netdata start

  # Log
  log_event "info" "Netdata configuration finished" "false"
  display --indent 6 --text "- Configuring netdata" --result "DONE" --color GREEN

}
