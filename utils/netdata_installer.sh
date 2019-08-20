#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9
################################################################################

### Checking some things...
if [[ -z "${MPASS}" ]]; then
  echo -e ${RED}" > Error: MPASS must be set! Exiting..."${ENDCOLOR}
  exit 0
fi

################################################################################

install_netdata() {

  echo -e ${YELLOW}"\nInstalling Netdata...\n"${ENDCOLOR}
  apt --yes install zlib1g-dev uuid-dev libuv1-dev liblz4-dev libjudy-dev libssl-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config curl python python-mysqldb lm-sensors libmnl netcat nodejs python-ipaddress python-dnspython iproute2 python-beanstalkc libuv liblz4 Judy openssl
  bash <(curl -Ss https://my-netdata.io/kickstart.sh) all --dont-wait

  killall netdata && cp system/netdata.service /etc/systemd/system/

}

configure_netdata() {

  # TODO: agregar soporte a config de Discord: https://docs.netdata.cloud/health/notifications/discord/

  # TODO: creo que ya creando el usuario en la BD tocar el mysql.conf no es necesario
  # TODO: Acá hay que hacer un sed para agregar el pass de root (quiza hasta sea menor ni copiar el mysql.conf)
  #cat ${SFOLDER}/confs/netdata/python.d/mysql.conf > /usr/lib/netdata/conf.d/python.d/mysql.conf

  # TODO: Agregar otras confs y la config de las notificaciones

  # Ojo, fijarse si funciona o probar con /usr/lib/netdata/conf.d si no se pisa con cada update de netdata
  cat ${SFOLDER}/confs/netdata/python.d/monit.conf >/usr/lib/netdata/conf.d/python.d/monit.conf

  # Esto parece que anda OK
  #cat ${SFOLDER}/confs/netdata/health_alarm_notify.conf >/etc/netdata/health_alarm_notify.conf

  netdata_discord_config

  create_netdata_db_user

  systemctl daemon-reload && systemctl enable netdata && service netdata start

  echo -e ${GREEN}" > DONE"${ENDCOLOR}

}

netdata_alarm_level() {
  NETDATA_ALARM_LEVELS="warning critical"
  NETDATA_ALARM_LEVEL=$(whiptail --title "NETDATA ALARM LEVEL" --menu "Chose the Alarm Level for Notifications" 20 78 10 $(for x in ${NETDATA_ALARM_LEVELS}; do echo "$x [X]"; done) 3>&1 1>&2 2>&3)
  exitstatus=$?
  if [ $exitstatus = 0 ]; then
    echo "NETDATA_ALARM_LEVEL="${NETDATA_ALARM_LEVEL} >>/root/.broobe-utils-options
    echo -e ${YELLOW}"Alarm Level for Notifications: ${NETDATA_ALARM_LEVEL} ..."${ENDCOLOR}

  else
    exit 1
  fi
}

netdata_discord_config() {

  DELIMITER="="

  KEY="SEND_TELEGRAM"
  SEND_TELEGRAM=$(cat "/etc/netdata/health_alarm_notify.conf" | grep "^${KEY}${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="TELEGRAM_BOT_TOKEN"
  TELEGRAM_BOT_TOKEN=$(cat "/etc/netdata/health_alarm_notify.conf" | grep "^${KEY}${DELIMITER}" | cut -f2- -d"$DELIMITER")

  KEY="DEFAULT_RECIPIENT_TELEGRAM"
  DEFAULT_RECIPIENT_TELEGRAM=$(cat "/etc/netdata/health_alarm_notify.conf" | grep "^${KEY}${DELIMITER}" | cut -f2- -d"$DELIMITER")

  echo -e ${RED}"****************** OLD DISCORD CONF ***************"${ENDCOLOR}
  echo -e ${RED}"***************************************************"${ENDCOLOR}
  echo -e ${RED}"SEND_TELEGRAM=${SEND_TELEGRAM}"${ENDCOLOR}
  echo -e ${RED}"TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}"${ENDCOLOR}
  echo -e ${RED}"DEFAULT_RECIPIENT_TELEGRAM=${DEFAULT_RECIPIENT_TELEGRAM}"${ENDCOLOR}
  echo -e ${RED}"**************************************************"${ENDCOLOR}

  NETDATA_CONFIG_1_STRING+= "\n . \n"
  NETDATA_CONFIG_1_STRING+=" Configure Telegram Notifications? You will need:\n"
  NETDATA_CONFIG_1_STRING+=" 1) Get a bot token. Contact @BotFather (https://t.me/BotFather) and send the command /newbot.\n"
  NETDATA_CONFIG_1_STRING+=" Follow the instructions and paste the token to access the HTTP API:\n"

  TELEGRAM_BOT_TOKEN=$(whiptail --title "Netdata: Telegram Configuration" --inputbox "${NETDATA_CONFIG_1_STRING}" 15 60 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    SEND_TELEGRAM="YES"
    sed -i "s/^\(SEND_TELEGRAM\s*=\s*\).*\$/\1\"$SEND_TELEGRAM\"/" /etc/netdata/health_alarm_notify.conf
    sed -i "s/^\(TELEGRAM_BOT_TOKEN\s*=\s*\).*\$/\1\"$TELEGRAM_BOT_TOKEN\"/" /etc/netdata/health_alarm_notify.conf

    NETDATA_CONFIG_2_STRING+= "\n . \n"
    NETDATA_CONFIG_2_STRING+=" 2) Contact the @myidbot (https://t.me/myidbot) bot and send the command /getid to get \n"
    NETDATA_CONFIG_2_STRING+=" your personal chat id or invite him into a group and issue the same command to get the group chat id.\n"
    NETDATA_CONFIG_2_STRING+=" 3) Paste the ID here:\n"

    DEFAULT_RECIPIENT_TELEGRAM=$(whiptail --title "Netdata: Telegram Configuration" --inputbox "${NETDATA_CONFIG_2_STRING}" 15 60 3>&1 1>&2 2>&3)
    exitstatus=$?
    if [ $exitstatus = 0 ]; then

      netdata_alarm_level

      sed -i "s/^\(DEFAULT_RECIPIENT_TELEGRAM\s*=\s*\).*\$/\1\"$DEFAULT_RECIPIENT_TELEGRAM|$NETDATA_ALARM_LEVEL\"/" /etc/netdata/health_alarm_notify.conf

    else
      exit 1
    fi

  else
    exit 1
  fi

  echo -e ${GREEN}"***************** NEW CONF ****************"${ENDCOLOR}
  echo -e ${GREEN}"*******************************************"${ENDCOLOR}
  echo -e ${GREEN}"SEND_TELEGRAM=${SEND_TELEGRAM}"${ENDCOLOR}
  echo -e ${GREEN}"TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}"${ENDCOLOR}
  echo -e ${GREEN}"DEFAULT_RECIPIENT_TELEGRAM=${DEFAULT_RECIPIENT_TELEGRAM}"${ENDCOLOR}
  echo -e ${GREEN}"*******************************************"${ENDCOLOR}

}

create_netdata_db_user() {

  # TODO: Checkear si el usuario ya existe
  SQL1="CREATE USER 'netdata'@'localhost';"
  SQL2="GRANT USAGE on *.* to 'netdata'@'localhost';"
  SQL3="FLUSH PRIVILEGES;"

  echo "Creating netdata user in MySQL ..." >>$LOG
  mysql -u root -p${MPASS} -e "${SQL1}${SQL2}${SQL3}" >>$LOG

}

################################################################################

if [[ -z "${NETDATA_SUBDOMAIN}" ]]; then

  NETDATA_SUBDOMAIN=$(whiptail --title "Netdata Installer" --inputbox "Please insert the subdomain you want to install Netdata. Ex: monitor.broobe.com" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    echo "NETDATA_SUBDOMAIN="${NETDATA_SUBDOMAIN} >>/root/.broobe-utils-options

  else
    exit 1

  fi
fi

# Only for Cloudflare API
ROOT_DOMAIN=${NETDATA_SUBDOMAIN#[[:alpha:]]*.}

### Checking if Netdata is installed
NETDATA="$(which netdata)"

if [ ! -x "${NETDATA}" ]; then

  while true; do

    echo -e ${YELLOW}"> Do you really want to install netdata?"${ENDCOLOR}
    read -p "Please type 'y' or 'n'" yn

    case $yn in
    [Yy]*)

      echo " > Updating packages before installation ..." >>$LOG
      echo -e ${YELLOW}" > Updating packages before installation ..."${ENDCOLOR}
      apt --yes update

      install_netdata

      # Netdata nginx proxy configuration
      cp ${SFOLDER}/confs/nginx/sites-available/monitor /etc/nginx/sites-available
      sed -i "s#dominio.com#${NETDATA_SUBDOMAIN}#" /etc/nginx/sites-available/monitor
      ln -s /etc/nginx/sites-available/monitor /etc/nginx/sites-enabled/monitor

      configure_netdata

      # Cloudflare API
      echo " > Trying to access Cloudflare API and change record ${NETDATA_SUBDOMAIN} ..." >>$LOG
      echo -e ${YELLOW}" > Trying to access Cloudflare API and change record ${NETDATA_SUBDOMAIN} ..."${ENDCOLOR}
      zone_name=${ROOT_DOMAIN}
      record_name=${NETDATA_SUBDOMAIN}
      export zone_name record_name
      ${SFOLDER}/utils/cloudflare_update_IP.sh

      # TODO: correr el certbot_manager.sh
      DOMAIN=${NETDATA_SUBDOMAIN}
      CHOSEN_CB_OPTION="1"
      export CHOSEN_CB_OPTION DOMAIN
      ${SFOLDER}/utils/certbot_manager.sh

      break
      ;;
    [Nn]*)
      echo -e ${RED}"Aborting netdata installation script ..."${ENDCOLOR}
      break
      ;;
    *) echo " > Please answer yes or no." ;;
    esac
  done

else

  NETDATA_OPTIONS="01 UPDATE_NETDATA 02 CONFIGURE_NETDATA 03 UNINSTALL_NETDATA 04 SEND_ALARM_TEST"
  NETDATA_CHOSEN_OPTION=$(whiptail --title "Netdata Installer" --menu "Netdata is already installed." 20 78 10 $(for x in ${NETDATA_OPTIONS}; do echo "$x"; done) 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${NETDATA_CHOSEN_OPTION} == *"01"* ]]; then
      cd netdata && git pull && ./netdata-installer.sh --dont-wait
      configure_netdata

    fi
    if [[ ${NETDATA_CHOSEN_OPTION} == *"02"* ]]; then
      configure_netdata

    fi
    if [[ ${NETDATA_CHOSEN_OPTION} == *"03"* ]]; then

      while true; do
        echo -e ${YELLOW}"> Do you really want to uninstall netdata?"${ENDCOLOR}
        read -p "Please type 'y' or 'n'" yn
        case $yn in
        [Yy]*)

          echo -e ${YELLOW}"\nUninstalling Netdata...\n"${ENDCOLOR}
          # TODO: Borrar usuario de la base de datos
          rm /etc/nginx/sites-enabled/monitor
          rm /etc/nginx/sites-available/monitor

          rm -R /etc/netdata
          rm /etc/systemd/system/netdata.service
          rm /usr/sbin/netdata

          source /usr/libexec/netdata-uninstaller.sh --yes --dont-wait

          break
          ;;
        [Nn]*)
          echo -e ${RED}"Aborting netdata script ..."${ENDCOLOR}
          break
          ;;
        *) echo " > Please answer yes or no." ;;
        esac
      done

    fi
    if [[ ${NETDATA_CHOSEN_OPTION} == *"04"* ]]; then
      /usr/libexec/netdata/plugins.d/alarm-notify.sh test

    fi

  fi

fi
