#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc06
################################################################################

configure_monit(){

  if [ ! -x "${PHP_V}" ]; then
    PHP_V=$(php -r "echo PHP_VERSION;" | grep --only-matching --perl-regexp "7.\d+")
  
  fi

  # Configuring monit
  echo -e ${CYAN}" > Configuring monit ..."${ENDCOLOR}
  cat "${SFOLDER}/confs/monit/lemp-services" > /etc/monit/conf.d/lemp-services
  cat "${SFOLDER}/confs/monit/monitrc" > /etc/monit/monitrc

  sed -i "s#HOSTNAME#${VPSNAME}#" /etc/monit/conf.d/lemp-services

  # Run five times to cober all var appearance
  sed -i "s#PHP_V#${PHP_V}#" /etc/monit/conf.d/lemp-services
  sed -i "s#PHP_V#${PHP_V}#" /etc/monit/conf.d/lemp-services
  sed -i "s#PHP_V#${PHP_V}#" /etc/monit/conf.d/lemp-services
  sed -i "s#PHP_V#${PHP_V}#" /etc/monit/conf.d/lemp-services
  sed -i "s#PHP_V#${PHP_V}#" /etc/monit/conf.d/lemp-services

  sed -i "s#SMTP_SERVER#${SMTP_SERVER}#" /etc/monit/conf.d/lemp-services
  sed -i "s#SMTP_PORT#${SMTP_PORT}#" /etc/monit/conf.d/lemp-services
  
  # Run two times to cober all var appearance
  sed -i "s#SMTP_U#${SMTP_U}#" /etc/monit/conf.d/lemp-services
  sed -i "s#SMTP_U#${SMTP_U}#" /etc/monit/conf.d/lemp-services

  sed -i "s#SMTP_P#${SMTP_P}#" /etc/monit/conf.d/lemp-services
  sed -i "s#MAILA#${MAILA}#" /etc/monit/conf.d/lemp-services

  echo -e ${CYAN}" > Restarting services ..."${ENDCOLOR}
  systemctl restart "php${PHP_V}-fpm"
  systemctl restart nginx.service
  service monit restart

  echo -" > Monit configure OK!">>$LOG
  echo -e ${GREEN}" > Monit configure OK!"${ENDCOLOR}

}

### Checking if Netdata is installed
MONIT="$(which monit)"

if [ ! -x "${MONIT}" ]; then

  while true; do

      echo -e ${YELLOW}"> Do you really want to install monit?"${ENDCOLOR}
      read -p "Please type 'y' or 'n'" yn

      case $yn in
          [Yy]* )

          echo " > Updating packages before installation ..." >>$LOG
          echo -e ${CYAN}" > Updating packages before installation ..."${ENDCOLOR}
          apt --yes update

          # Installing packages
          echo -e ${CYAN}" > Installing monit ..."${ENDCOLOR}
          echo " > Installing monit ..." >>$LOG
          apt --yes install monit

          configure_monit

          break;;
          [Nn]* )
          echo -e ${B_RED}"Aborting monit installation script ..."${ENDCOLOR};
          break;;
          * ) echo " > Please answer yes or no.";;
      esac
  done

else
  while true; do

      echo -e ${YELLOW}"> Monit is already installed. Do you want to reconfigure monit?"${ENDCOLOR}
      read -p "Please type 'y' or 'n'" yn

      case $yn in
          [Yy]* )

          configure_monit

          break;;
          [Nn]* )
          echo -e ${B_RED}"Aborting monit installation script ..."${ENDCOLOR};
          break;;
          * ) echo " > Please answer yes or no.";;
      esac
  done

fi
