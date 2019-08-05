#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9.7
################################################################################

# TODO: Primero correr sin los parametros -mtime -7 y luego setear un option
# para correrlo solo en archivos modificados los ultimos -7 días

SCRIPT_V="2.9.7"

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

### VARS
JPG_COMPRESS='90'

### Remove old packages from system
echo " > Cleanning old system packages ..." >> $LOG
echo -e ${YELLOW}" > Cleanning old system packages ..."${ENDCOLOR}
apt clean
apt-get -y autoremove
apt-get -y autoclean

### Remove old log files from system
echo " > Deleting old system logs..." >> $LOG
echo -e ${YELLOW}" > Deleting old system logs ..."${ENDCOLOR}
find /var/log/ -mtime +7 -type f -delete

echo " > Running jpegoptim ..." >> $LOG
echo -e ${YELLOW}" > Running jpegoptim ..."${ENDCOLOR}
cd ${SITES}
find -mtime -7 -type f -name "*.jpg" -exec jpegoptim --max=${JPG_COMPRESS} --strip-all {} \;

echo " > Running optipng..." >> $LOG
echo -e ${YELLOW}" > Running optipng ..."${ENDCOLOR}
find -mtime -7 -type f -name "*.png" -exec optipng -o7 -strip all {} \;

echo " > Fixing ownership ..." >> $LOG
echo -e ${YELLOW}" > Fixing ownership ..."${ENDCOLOR}
chown -R www-data:www-data *

# Cleanning Swap
swapoff -a && swapon -a

#Cleanning RAM
sync; echo 1 > /proc/sys/vm/drop_caches
