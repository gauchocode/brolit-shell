#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.71
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

  # CPU
  cp "${SFOLDER}/config/netdata/health.d/cpu.conf" "/etc/netdata/health.d/cpu.conf"

  # Web_log
  cp "${SFOLDER}/config/netdata/health.d/web_log.conf" "/etc/netdata/health.d/web_log.conf"

  # MySQL
  cp "${SFOLDER}/config/netdata/health.d/mysql.conf" "/etc/netdata/health.d/mysql.conf"

  # PHP-FPM
  cp "${SFOLDER}/config/netdata/health.d/php-fpm.conf" "/etc/netdata/health.d/php-fpm.conf"

  # Anomalies
  #cp "${SFOLDER}/config/netdata/health.d/anomalies.conf" "/etc/netdata/health.d/anomalies.conf"

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
  clear_last_line
  clear_last_line
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

function _netdata_alarm_level() {

  local netdata_alarm_levels
  local netdata_alarm_level

  netdata_alarm_levels="warning critical"
  netdata_alarm_level=$(whiptail --title "NETDATA ALARM LEVEL" --menu "Choose the Alarm Level for Notifications" 20 78 10 "$(for x in ${netdata_alarm_levels}; do echo "$x [X]"; done)" 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Brolit config
    config_file="/root/.brolit_conf.json"

    config_field="SUPPORT.netdata[].config[].netdata_alarm_level"
    config_value="${netdata_alarm_level}"

    json_write_field "${config_file}" "${config_field}" "${config_value}"

    log_event "info" "Alarm Level for Notifications: ${netdata_alarm_level}" "false"

    echo "${netdata_alarm_level}"

  else

    return 1

  fi

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
  local netdata_config_1_string
  local netdata_config_2_string

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

  netdata_config_1_string+="\n . \n"
  netdata_config_1_string+=" Configure Telegram Notifications? You will need:\n"
  netdata_config_1_string+=" 1) Get a bot token. Contact @BotFather (https://t.me/BotFather) and send the command /newbot.\n"
  netdata_config_1_string+=" Follow the instructions and paste the token to access the HTTP API:\n"

  telegram_bot_token="$(whiptail --title "Netdata: Telegram Configuration" --inputbox "${netdata_config_1_string}" 15 60 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    send_telegram="YES"
    sed -i "s/^\(SEND_TELEGRAM\s*=\s*\).*\$/\1\"$send_telegram\"/" $health_alarm_notify_conf
    sed -i "s/^\(TELEGRAM_BOT_TOKEN\s*=\s*\).*\$/\1\"$telegram_bot_token\"/" $health_alarm_notify_conf

    netdata_config_2_string+="\n . \n"
    netdata_config_2_string+=" 2) Contact the @myidbot (https://t.me/myidbot) bot and send the command /getid to get \n"
    netdata_config_2_string+=" your personal chat id or invite him into a group and issue the same command to get the group chat id.\n"
    netdata_config_2_string+=" 3) Paste the ID here:\n"

    default_recipient_telegram="$(whiptail --title "Netdata: Telegram Configuration" --inputbox "${netdata_config_2_string}" 15 60 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Choose the netdata alarm level
      netdata_alarm_level="$(_netdata_alarm_level)"

      log_event "debug" "Running: sed -i \"s/^\(DEFAULT_RECIPIENT_TELEGRAM\s*=\s*\).*\$/\1\"${default_recipient_telegram}|${netdata_alarm_level}\"/" $health_alarm_notify_conf\" "false"

      # Making changes on health_alarm_notify.conf
      sed -i "s/^\(DEFAULT_RECIPIENT_TELEGRAM\s*=\s*\).*\$/\1\"${default_recipient_telegram}|${netdata_alarm_level}\"/" $health_alarm_notify_conf

      # Uncomment the clear_alarm_always='YES' parameter on health_alarm_notify.conf
      if grep -q '^#.*clear_alarm_always' ${health_alarm_notify_conf}; then

        sed -i '/^#.*clear_alarm_always/ s/^#//' $health_alarm_notify_conf

      fi

      display --indent 6 --text "- Telegram configuration" --result "DONE" --color GREEN

    else

      return 1

    fi

  else

    return 1

  fi

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

  log_event "info" "Installing Netdata ..." "false"
  display --indent 6 --text "- Downloading and compiling netdata"

  # Download and run
  bash <(curl -Ss https://my-netdata.io/kickstart.sh) all --dont-wait --disable-telemetry &>/dev/null

  # Kill netdata and copy service
  killall netdata && cp system/netdata.service /etc/systemd/system/

  if [[ $? -eq 0 ]]; then

    NETDATA_CONFIG_STATUS="enabled"
    
    json_write_field "${BROLIT_CONFIG_FILE}" "SUPPORT.netdata[].status" "${NETDATA_CONFIG_STATUS}"

    # new global value ("enabled")
    export NETDATA_CONFIG_STATUS

    return 0

  else

    return 1

  fi

  # Log
  clear_last_line
  clear_last_line
  log_event "info" "Netdata installation finished" "false"
  display --indent 6 --text "- Downloading and compiling netdata" --result "DONE" --color GREEN

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

  while true; do

    echo -e "${YELLOW}${ITALIC} > Do you really want to uninstall netdata?${ENDCOLOR}"
    read -p "Please type 'y' or 'n'" yn

    case $yn in

    [Yy]*)

      # Log
      clear_last_line
      clear_last_line
      log_event "warning" "Uninstalling Netdata ..." "false"

      # Deleting mysql user
      mysql_user_delete "netdata" "localhost"

      # Search for netdata nginx server file
      netdata_server_file="$(grep "proxy_pass http://127.0.0.1:19999/" /etc/nginx/sites-available/* | cut -d ":" -f1)"
      netdata_server_file="$(basename "${netdata_server_file}")"

      # Deleting nginx server files
      nginx_server_delete "${netdata_server_file}"

      # Deleting installation files
      rm --force --recursive "/etc/netdata"
      rm --force "/etc/systemd/system/netdata.service"
      rm --force "/usr/sbin/netdata"

      # Running uninstaller
      if [[ -f "/usr/libexec/netdata-uninstaller.sh" ]]; then
        source "/usr/libexec/netdata-uninstaller.sh" --yes --dont-wait
      fi

      # new config
      config_file="/root/.brolit_conf.json"
      config_field="SUPPORT.netdata[].status"
      config_value="disable"
      json_write_field "${config_file}" "${config_field}" "${config_value}"

      log_event "info" "Netdata removed ok!" "false"
      display --indent 6 --text "- Uninstalling netdata" --result "DONE" --color GREEN

      break
      ;;

    [Nn]*)

      log_event "warning" "Aborting netdata installer script ..." "false"

      break
      ;;

    *) echo " > Please answer yes or no." ;;

    esac

  done

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

  # MySQL
  mysql_user_create "netdata" "" "localhost"
  mysql_user_grant_privileges "netdata" "*" "localhost"

  # Copy mysql config
  cat "${SFOLDER}/config/netdata/python.d/mysql.conf" >"/etc/netdata/python.d/mysql.conf"

  log_event "info" "MySQL config done!" "false"
  display --indent 6 --text "- MySQL configuration" --result "DONE" --color GREEN

  # Monit
  cat "${SFOLDER}/config/netdata/python.d/monit.conf" >"/etc/netdata/python.d/monit.conf"

  log_event "info" "Monit config done!" "false"
  display --indent 6 --text "- Monit configuration" --result "DONE" --color GREEN

  # Web log
  cat "${SFOLDER}/config/netdata/python.d/web_log.conf" >"/etc/netdata/python.d/web_log.conf"

  log_event "info" "Nginx Web Log config done!" "false"
  display --indent 6 --text "- Nginx Web Log configuration" --result "DONE" --color GREEN

  # Health alarm notify
  cat "${SFOLDER}/config/netdata/health_alarm_notify.conf" >"/etc/netdata/health_alarm_notify.conf"

  log_event "info" "Health alarm config done!" "false"
  display --indent 6 --text "- Health alarm configuration" --result "DONE" --color GREEN

  # Alerts
  _netdata_alerts_configuration

  # Anomalies
  _netdata_anomalies_configuration

  # Telegram
  _netdata_telegram_config

  # Reload service
  systemctl daemon-reload && systemctl enable netdata && service netdata start

  # Log
  log_event "info" "Netdata Configuration finished" "false"
  display --indent 6 --text "- Configuring netdata" --result "DONE" --color GREEN

}

################################################################################
# Netdata installer menu
#
# Arguments:
#  none
#
# Outputs:
#  nothing
################################################################################

function netdata_installer_menu() {

  local netdata_subdomain
  local netdata_options
  local netdata_chosen_option

  # Checking if Netdata is installed
  NETDATA="$(which netdata)"

  if [[ ! -x "${NETDATA}" ]]; then

    if [[ -z "${PACKAGE_NETDATA_CONFIG_SUBDOMAIN}" ]]; then

      netdata_subdomain="$(whiptail --title "Netdata Installer" --inputbox "Please insert the subdomain you want to install Netdata. Ex: monitor.domain.com" 10 60 3>&1 1>&2 2>&3)"
      
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # new config
        config_file="/root/.brolit_conf.json"

        config_field="PACKAGE.netdata[].status"
        config_value="enable"
        json_write_field "${config_file}" "${config_field}" "${config_value}"

        config_field="PACKAGE.netdata[].config[].subdomain"
        config_value="${netdata_subdomain}"
        json_write_field "${config_file}" "${config_field}" "${config_value}"

      else

        return 1

      fi

    fi

    # Only for Cloudflare API
    possible_root_domain="$(get_root_domain "${netdata_subdomain}")"

    mysql_command="$(command -v mysql)"
    if [[ -x ${mysql_command} ]]; then
      mysql_ask_root_psw
    fi

    while true; do

      echo -e "${YELLOW}${ITALIC} > Do you really want to install netdata?${ENDCOLOR}"
      read -p "Please type 'y' or 'n'" yn

      case $yn in

      [Yy]*)

        clear_last_line
        clear_last_line

        log_subsection "Netdata Installer"

        log_event "info" "Updating packages before installation ..." "false"

        # Update
        apt-get --yes update -qq >/dev/null

        display --indent 6 --text "- Updating packages before installation" --result "DONE" --color GREEN

        # Install required packages
        _netdata_required_packages

        # Installe netdata
        netdata_installer

        # If nginx is installed
        nginx_command="$(command -v nginx)"
        if [[ -x ${nginx_command} ]]; then

          # Netdata nginx proxy configuration
          nginx_server_create "${PACKAGE_NETDATA_CONFIG_SUBDOMAIN}" "netdata" "single" ""

          # Nginx Auth
          nginx_netdata_user="netdata"
          nginx_netdata_pass=$(whiptail_imput "Netdata Installer" "Please, insert a password for netdata user:")
          nginx_generate_auth "${nginx_netdata_user}" "${nginx_netdata_pass}"

          config_field="SUPPORT.netdata[].config[].netdata_user"
          config_value="${nginx_netdata_user}"
          json_write_field "${config_file}" "${config_field}" "${config_value}"

          config_field="SUPPORT.netdata[].config[].netdata_pass"
          config_value="${nginx_netdata_pass}"
          json_write_field "${config_file}" "${config_field}" "${config_value}"

        fi

        # Configuration
        netdata_configuration

        # Confirm ROOT_DOMAIN
        root_domain="$(ask_root_domain "${possible_root_domain}")"

        # Cloudflare API
        cloudflare_set_record "${root_domain}" "${netdata_subdomain}" "A"

        # HTTPS with Certbot
        certbot_certificate_install "${NOTIFICATION_EMAIL_MAILA}" "${netdata_subdomain}"

        display --indent 6 --text "- Netdata installation" --result "DONE" --color GREEN

        break
        ;;

      [Nn]*)

        log_event "warning" "Aborting netdata installer script ..." "true"
        break
        ;;

      *) echo " > Please answer yes or no." ;;

      esac

    done

  else

    netdata_options=(
      "01)" "UPDATE NETDATA"
      "02)" "CONFIGURE NETDATA"
      "03)" "UNINSTALL NETDATA"
      "04)" "SEND ALARM TEST"
    )

    netdata_chosen_option="$(whiptail --title "Netdata Installer" --menu "Netdata is already installed." 20 78 10 "${netdata_options[@]}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      log_subsection "Netdata Installer"

      if [[ ${netdata_chosen_option} == *"01"* ]]; then
        cd netdata && git pull && ./netdata-installer.sh --dont-wait
        netdata_configuration

      fi
      if [[ ${netdata_chosen_option} == *"02"* ]]; then
        _netdata_required_packages
        netdata_configuration

      fi
      if [[ ${netdata_chosen_option} == *"03"* ]]; then

        netdata_uninstaller

      fi
      if [[ ${netdata_chosen_option} == *"04"* ]]; then
        /usr/libexec/netdata/plugins.d/alarm-notify.sh test

      fi

    fi

  fi

}
