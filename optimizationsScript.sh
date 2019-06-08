#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.3
#############################################################################

SCRIPT_V="2.3"

### VARS ###
JPG_COMPRESS='80'

### Setup Colours ###
BLACK='\E[30;40m'
RED='\E[31;40m'
GREEN='\E[32;40m'
YELLOW='\E[33;40m'
BLUE='\E[34;40m'
MAGENTA='\E[35;40m'
CYAN='\E[36;40m'
WHITE='\E[37;40m'

### Checking some things... ###
if [ ${USER} != root ]; then
  echo -e ${RED}"Error: must be root! Exiting..."${ENDCOLOR}
  exit 0
fi
#if [[ -z "${MUSER}" || -z "${MPASS}" ]]; then
#  echo -e ${RED}"Error: MUSER and MPASS must be set! Exiting..."${ENDCOLOR}
#  exit 0
#fi

### Remove old packages from system ###
echo " > Cleanning old system packages ..." >> $LOG
echo -e ${YELLOW}" > Cleanning old system packages ..."${ENDCOLOR}
apt clean
apt-get -y autoremove
apt-get -y autoclean

### Remove old log files from system ###
echo " > Deleting old system logs..." >> $LOG
echo -e ${YELLOW}" > Deleting old system logs ..."${ENDCOLOR}
find /var/log/ -mtime +7 -type f -delete

# Optimización de imágenes (.jpg) para archivos modificados en los últimos 7 días
echo " > Running jpegoptim ..." >> $LOG
echo -e ${YELLOW}" > Running jpegoptim ..."${ENDCOLOR}
cd ${SITES}
find -mtime -7 -type f -name "*.jpg" -exec jpegoptim --max=${JPG_COMPRESS} --strip-all {} \;

# Optimización de imágenes (.png) para archivos modificados en los últimos 7 días
echo " > Running optipng..." >> $LOG
echo -e ${YELLOW}" > Running optipng ..."${ENDCOLOR}
find -mtime -7 -type f -name "*.png" -exec optipng -o7 -strip all {} \;

#fix files ownership
echo " > Fixing ownership ..." >> $LOG
echo -e ${YELLOW}" > Fixing ownership ..."${ENDCOLOR}
chown -R www-data:www-data *
