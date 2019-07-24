#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Version: 2.9
################################################################################

Configure_netdata(){

  # TODO: creo que ya creando el usuario en la BD tocar el mysql.conf no es necesario
  # TODO: Acá hay que hacer un sed para agregar el pass de root (quiza hasta sea menor ni copiar el mysql.conf)
  #cat ${SFOLDER}/confs/netdata/python.d/mysql.conf > /usr/lib/netdata/conf.d/python.d/mysql.conf

  # TODO: Agregar otras confs y la config de las notificaciones

  # Ojo, fijarse si funciona o probar con /usr/lib/netdata/conf.d si no se pisa con cada update de netdata
  cat ${SFOLDER}/confs/netdata/python.d/monit.conf > /usr/lib/netdata/conf.d/python.d/monit.conf

  # Esto parece que anda OK
  cat ${SFOLDER}/confs/netdata/health_alarm_notify.conf > /etc/netdata/health_alarm_notify.conf

  # TODO: Checkear si el usuario ya existe
  SQL1="CREATE USER 'netdata'@'localhost';"
  SQL2="GRANT USAGE on *.* to 'netdata'@'localhost';"
  SQL3="FLUSH PRIVILEGES;"

  echo "Creating netdata user in MySQL ..." >> $LOG
  mysql -u root -p${MPASS} -e "${SQL1}${SQL2}${SQL3}" >> $LOG

  systemctl daemon-reload && systemctl enable netdata && service netdata start

  echo -e ${GREEN}" > DONE"${ENDCOLOR}
}

### Checking some things...
if [[ -z "${MPASS}" ]]; then
  echo -e ${RED}" > Error: MPASS must be set! Exiting..."${ENDCOLOR}
  exit 0
fi

if [[ -z "${NETDATA_SUBDOMAIN}" ]]; then

  NETDATA_SUBDOMAIN=$(whiptail --title "Netdata Installer" --inputbox "Please insert the subdomain you want to install Netdata. Ex: monitor.broobe.com" 10 60 3>&1 1>&2 2>&3)
  exitstatus=$?

  if [ $exitstatus = 0 ]; then
    echo "NETDATA_SUBDOMAIN="${NETDATA_SUBDOMAIN} >> /root/.broobe-utils-options

  else
    exit 1;

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
          [Yy]* )

          echo " > Updating packages before installation ..." >>$LOG
          echo -e ${YELLOW}" > Updating packages before installation ..."${ENDCOLOR}
          apt --yes update

          echo -e ${YELLOW}"\nInstalling Netdata...\n"${ENDCOLOR}
          apt --yes install zlib1g-dev uuid-dev libuv1-dev liblz4-dev libjudy-dev libssl-dev libmnl-dev gcc make git autoconf autoconf-archive autogen automake pkg-config curl python python-mysqldb lm-sensors libmnl netcat nodejs python-ipaddress python-dnspython iproute2 python-beanstalkc libuv liblz4 Judy openssl
          bash <(curl -Ss https://my-netdata.io/kickstart.sh) all --dont-wait

          killall netdata && cp system/netdata.service /etc/systemd/system/

          # Netdata nginx proxy configuration
          cp ${SFOLDER}/confs/monitor /etc/nginx/sites-available
          sed -i "s#dominio.com#${NETDATA_SUBDOMAIN}#" /etc/nginx/sites-available/monitor
          ln -s /etc/nginx/sites-available/monitor /etc/nginx/sites-enabled/monitor

          Configure_netdata

          # Cloudflare API
          echo " > Trying to access Cloudflare API and change record ${NETDATA_SUBDOMAIN} ..."  >> $LOG
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

          break;;
          [Nn]* )
          echo -e ${RED}"Aborting netdata installation script ..."${ENDCOLOR};
          break;;
          * ) echo " > Please answer yes or no.";;
      esac
  done

else

  NETDATA_OPTIONS="01 UPDATE_NETDATA 02 CONFIGURE_NETDATA 03 UNINSTALL_NETDATA 04 SEND_ALARM_TEST"
  NETDATA_CHOSEN_OPTION=$(whiptail --title "Netdata Installer" --menu "Netdata is already installed." 20 78 10 `for x in ${NETDATA_OPTIONS}; do echo "$x"; done` 3>&1 1>&2 2>&3)

  exitstatus=$?
  if [ $exitstatus = 0 ]; then

    if [[ ${NETDATA_CHOSEN_OPTION} == *"01"* ]]; then
      cd netdata && git pull && ./netdata-installer.sh --dont-wait
      Configure_netdata

    fi
    if [[ ${NETDATA_CHOSEN_OPTION} == *"02"* ]]; then
      Configure_netdata

    fi
    if [[ ${NETDATA_CHOSEN_OPTION} == *"03"* ]]; then

      while true; do
          echo -e ${YELLOW}"> Do you really want to uninstall netdata?"${ENDCOLOR}
          read -p "Please type 'y' or 'n'" yn
          case $yn in
              [Yy]* )

              echo -e ${YELLOW}"\nUninstalling Netdata...\n"${ENDCOLOR}
              # TODO: Borrar usuario de la base de datos
              rm /etc/nginx/sites-enabled/monitor
              rm /etc/nginx/sites-available/monitor

              rm -R /etc/netdata
              rm /etc/systemd/system/netdata.service
              rm /usr/sbin/netdata

              source /usr/libexec/netdata-uninstaller.sh --yes --dont-wait

              break;;
              [Nn]* )
              echo -e ${RED}"Aborting netdata script ..."${ENDCOLOR};
              break;;
              * ) echo " > Please answer yes or no.";;
          esac
      done

    fi
    if [[ ${NETDATA_CHOSEN_OPTION} == *"04"* ]]; then
      /usr/libexec/netdata/plugins.d/alarm-notify.sh test

    fi

  fi

fi
