#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.34
################################################################################

# Ref: https://github.com/nextcloud/vm/blob/master/apps/netdata.sh

function _netdata_required_packages() {

  local ubuntu_version

  ubuntu_version="$(get_ubuntu_version)"

  display --indent 6 --text "- Installing netdata required packages"

  if [[ ${ubuntu_version} == "1804" ]]; then
    apt-get --yes install zlib1g-dev uuid-dev libuv1-dev liblz4-dev libjudy-dev libssl-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config curl python python-mysqldb lm-sensors libmnl netcat nodejs python-ipaddress python-dnspython iproute2 python-beanstalkc libuv liblz4 Judy openssl -qq >/dev/null

  elif [[ ${ubuntu_version} == "2004" ]]; then
    apt-get --yes install curl python3-mysqldb lm-sensors libmnl netcat openssl -qq >/dev/null

  fi

  # Log
  clear_last_line
  clear_last_line
  display --indent 6 --text "- Installing netdata required packages" --result "DONE" --color GREEN

}

function _netdata_alarm_level() {

  NETDATA_ALARM_LEVELS="warning critical"
  NETDATA_ALARM_LEVEL=$(whiptail --title "NETDATA ALARM LEVEL" --menu "Choose the Alarm Level for Notifications" 20 78 10 "$(for x in ${NETDATA_ALARM_LEVELS}; do echo "$x [X]"; done)" 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    echo "NETDATA_ALARM_LEVEL=${NETDATA_ALARM_LEVEL}" >>/root/.broobe-utils-options
    log_event "info" "Alarm Level for Notifications: ${NETDATA_ALARM_LEVEL}" "false"

  else
    return 1

  fi

}

function _netdata_telegram_config() {

  HEALTH_ALARM_NOTIFY_CONF="/etc/netdata/health_alarm_notify.conf"

  DELIMITER="="

  KEY="SEND_TELEGRAM"
  SEND_TELEGRAM=$(cat "/etc/netdata/health_alarm_notify.conf" | grep "^${KEY}${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="TELEGRAM_BOT_TOKEN"
  TELEGRAM_BOT_TOKEN=$(cat "/etc/netdata/health_alarm_notify.conf" | grep "^${KEY}${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="DEFAULT_RECIPIENT_TELEGRAM"
  DEFAULT_RECIPIENT_TELEGRAM=$(cat "/etc/netdata/health_alarm_notify.conf" | grep "^${KEY}${DELIMITER}" | cut -f2- -d"$DELIMITER")

  NETDATA_CONFIG_1_STRING+="\n . \n"
  NETDATA_CONFIG_1_STRING+=" Configure Telegram Notifications? You will need:\n"
  NETDATA_CONFIG_1_STRING+=" 1) Get a bot token. Contact @BotFather (https://t.me/BotFather) and send the command /newbot.\n"
  NETDATA_CONFIG_1_STRING+=" Follow the instructions and paste the token to access the HTTP API:\n"

  TELEGRAM_BOT_TOKEN=$(whiptail --title "Netdata: Telegram Configuration" --inputbox "${NETDATA_CONFIG_1_STRING}" 15 60 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    SEND_TELEGRAM="YES"
    sed -i "s/^\(SEND_TELEGRAM\s*=\s*\).*\$/\1\"$SEND_TELEGRAM\"/" $HEALTH_ALARM_NOTIFY_CONF
    sed -i "s/^\(TELEGRAM_BOT_TOKEN\s*=\s*\).*\$/\1\"$TELEGRAM_BOT_TOKEN\"/" $HEALTH_ALARM_NOTIFY_CONF

    NETDATA_CONFIG_2_STRING+="\n . \n"
    NETDATA_CONFIG_2_STRING+=" 2) Contact the @myidbot (https://t.me/myidbot) bot and send the command /getid to get \n"
    NETDATA_CONFIG_2_STRING+=" your personal chat id or invite him into a group and issue the same command to get the group chat id.\n"
    NETDATA_CONFIG_2_STRING+=" 3) Paste the ID here:\n"

    DEFAULT_RECIPIENT_TELEGRAM=$(whiptail --title "Netdata: Telegram Configuration" --inputbox "${NETDATA_CONFIG_2_STRING}" 15 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # choose the netdata alarm level
      _netdata_alarm_level

      # making changes on health_alarm_notify.conf
      sed -i "s/^\(DEFAULT_RECIPIENT_TELEGRAM\s*=\s*\).*\$/\1\"$DEFAULT_RECIPIENT_TELEGRAM|$NETDATA_ALARM_LEVEL\"/" $HEALTH_ALARM_NOTIFY_CONF

      # Uncomment the clear_alarm_always='YES' parameter on health_alarm_notify.conf
      if grep -q '^#.*clear_alarm_always' $HEALTH_ALARM_NOTIFY_CONF; then
        sed -i '/^#.*clear_alarm_always/ s/^#//' $HEALTH_ALARM_NOTIFY_CONF
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

function netdata_installer() {

  log_event "info" "Installing Netdata ..." "false"
  display --indent 6 --text "- Downloading and compiling netdata"

  bash <(curl -Ss https://my-netdata.io/kickstart.sh) all --dont-wait --disable-telemetry &>/dev/null

  killall netdata && cp system/netdata.service /etc/systemd/system/

  log_event "info" "Netdata Installed" "false"
  clear_last_line
  display --indent 6 --text "- Downloading and compiling netdata" --result "DONE" --color GREEN

}

function netdata_uninstaller() {

  while true; do

    echo -e "${YELLOW}${ITALIC} > Do you really want to uninstall netdata?${ENDCOLOR}"
    read -p "Please type 'y' or 'n'" yn

    case $yn in

    [Yy]*)

      # Log
      clear_line
      clear_line
      log_event "warning" "Uninstalling Netdata ..." "false"

      # Deleting mysql user
      mysql_user_delete "netdata" "localhost"

      # Deleting nginx server files
      rm --force "/etc/nginx/sites-enabled/monitor"
      rm --force "/etc/nginx/sites-available/monitor"

      # Deleting installation files
      rm --force --recursive "/etc/netdata"
      rm --force "/etc/systemd/system/netdata.service"
      rm --force "/usr/sbin/netdata"

      # Running uninstaller
      if [[ -f "/usr/libexec/netdata-uninstaller.sh" ]]; then
        source "/usr/libexec/netdata-uninstaller.sh" --yes --dont-wait
      fi

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

function netdata_configuration() {

  # Ref: netdata config dir https://github.com/netdata/netdata/issues/4182

  # MySQL
  mysql_user_create "netdata"
  mysql_user_grant_privileges "netdata" "*"

  cat "${SFOLDER}/config/netdata/python.d/mysql.conf" >"/etc/netdata/python.d/mysql.conf"

  log_event "info" "MySQL config done!" "false"
  display --indent 6 --text "- MySQL configuration" --result "DONE" --color GREEN

  # monit
  cat "${SFOLDER}/config/netdata/python.d/monit.conf" >"/etc/netdata/python.d/monit.conf"

  log_event "info" "Monit config done!" "false"
  display --indent 6 --text "- Monit configuration" --result "DONE" --color GREEN

  # web_log
  cat "${SFOLDER}/config/netdata/python.d/web_log.conf" >"/etc/netdata/python.d/web_log.conf"

  log_event "info" "Nginx Web Log config done!" "false"
  display --indent 6 --text "- Nginx Web Log configuration" --result "DONE" --color GREEN

  # health_alarm_notify
  cat "${SFOLDER}/config/netdata/health_alarm_notify.conf" >"/etc/netdata/health_alarm_notify.conf"
  log_event "info" "Health alarm config done!" "false"
  display --indent 6 --text "- Health alarm configuration" --result "DONE" --color GREEN

  # telegram
  _netdata_telegram_config

  systemctl daemon-reload && systemctl enable netdata && service netdata start

  log_event "info" "Netdata Configuration finished" "false"

  display --indent 6 --text "- Configuring netdata" --result "DONE" --color GREEN

}

function netdata_installer_menu() {

  local netdata_subdomain
  local netdata_options
  local netdata_chosen_option

  ### Checking if Netdata is installed
  NETDATA="$(which netdata)"

  if [[ ! -x "${NETDATA}" ]]; then

    if [[ -z "${netdata_subdomain}" ]]; then

      netdata_subdomain="$(whiptail --title "Netdata Installer" --inputbox "Please insert the subdomain you want to install Netdata. Ex: monitor.domain.com" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then
        echo "NETDATA_SUBDOMAIN=${netdata_subdomain}" >>"/root/.broobe-utils-options"

      else
        return 1

      fi

    fi

    # Only for Cloudflare API
    possible_root_domain="$(get_root_domain "${netdata_subdomain}")"

    ask_mysql_root_psw

    while true; do

      echo -e "${YELLOW}${ITALIC} > Do you really want to install netdata?${ENDCOLOR}"
      read -p "Please type 'y' or 'n'" yn

      case $yn in

      [Yy]*)

        clear_last_line
        clear_last_line

        log_subsection "Netdata Installer"

        log_event "info" "Updating packages before installation ..."

        apt-get --yes update -qq >/dev/null

        display --indent 6 --text "- Updating packages before installation" --result "DONE" --color GREEN

        _netdata_required_packages

        netdata_installer

        # Netdata nginx proxy configuration
        nginx_server_create "${netdata_subdomain}" "netdata" "tool"

        # Nginx Auth
        nginx_generate_auth "netdata"

        netdata_configuration

        # Confirm ROOT_DOMAIN
        root_domain="$(ask_root_domain "${possible_root_domain}")"

        # Cloudflare API
        cloudflare_set_record "${root_domain}" "${netdata_subdomain}" "A"

        # HTTPS with Certbot
        certbot_certificate_install "${MAILA}" "${netdata_subdomain}"

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
