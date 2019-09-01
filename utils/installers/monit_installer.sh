#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9
################################################################################

# TODO: adentro de lemp-services está la version de php, checkear cualtenemos instalado antes de configurar
# TODO: consultar por el monit user y pass y almacernarlo para que lo levante el netdata_installer

configure_monit(){

  # Configuring monit
  echo -e ${YELLOW}" > Configuring monit ..."${ENDCOLOR}
  cat ${SFOLDER}/confs/monit/lemp-services > /etc/monit/conf.d/lemp-services
  cat ${SFOLDER}/confs/monit/monitrc > /etc/monit/monitrc

  sed -i "s#HOSTNAME#${VPSNAME}#" /etc/monit/conf.d/lemp-services
  sed -i "s#SMTP_SERVER#${SMTP_SERVER}#" /etc/monit/conf.d/lemp-services
  sed -i "s#SMTP_PORT#${SMTP_PORT}#" /etc/monit/conf.d/lemp-services
  sed -i "s#SMTP_U#${SMTP_U}#" /etc/monit/conf.d/lemp-services
  sed -i "s#SMTP_U#${SMTP_U}#" /etc/monit/conf.d/lemp-services                    # twice to cober double appearance
  sed -i "s#SMTP_P#${SMTP_P}#" /etc/monit/conf.d/lemp-services
  sed -i "s#MAILA#${MAILA}#" /etc/monit/conf.d/lemp-services

  echo -e ${YELLOW}" > Restarting services ..."${ENDCOLOR}
  systemctl restart php${PHP_V}-fpm
  systemctl restart nginx.service
  service monit restart

  echo -" > DONE">>$LOG
  echo -e ${GREEN}" > DONE"${ENDCOLOR}

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
          echo -e ${YELLOW}" > Updating packages before installation ..."${ENDCOLOR}
          apt --yes update

          # Installing packages
          echo -e ${YELLOW}" > Installing monit ..."${ENDCOLOR}
          echo " > Installing monit ..." >>$LOG
          apt --yes install monit

          configure_monit

          break;;
          [Nn]* )
          echo -e ${RED}"Aborting monit installation script ..."${ENDCOLOR};
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
          echo -e ${RED}"Aborting monit installation script ..."${ENDCOLOR};
          break;;
          * ) echo " > Please answer yes or no.";;
      esac
  done

fi
