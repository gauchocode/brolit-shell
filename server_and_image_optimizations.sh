#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc03
################################################################################

# TODO: Primero correr sin los parametros -mtime -7 y luego setear un option
# para correrlo solo en archivos modificados los ultimos -7 días
#
# Ref. de optimizacion de imagenes:
# https://github.com/centminmod/optimise-images/blob/master/examples/examples-optimise-webp-nginx-300417.md
# https://centminmod.com/webp/
# https://ayudawp.com/usar-archivos-webp-wordpress-mejorar-los-tiempos-carga

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/mail_notification_helper.sh

################################################################################

# VARS
JPG_COMPRESS='90'

# Remove old packages from system
remove_old_packages

# Install image optimize packages
install_image_optimize_packages

# Remove old log files from system
echo " > Deleting old system logs..." >>$LOG
echo -e ${YELLOW}" > Deleting old system logs ..."${ENDCOLOR}
find /var/log/ -mtime +7 -type f -delete

# Run jpegoptim
echo " > Running jpegoptim ..." >>$LOG
echo -e ${YELLOW}" > Running jpegoptim ..."${ENDCOLOR}
cd ${SITES}
find -mtime -7 -type f -name "*.jpg" -exec jpegoptim --max=${JPG_COMPRESS} --strip-all --all-progressive {} \;

# Run optipng
echo " > Running optipng ..." >>$LOG
echo -e ${YELLOW}" > Running optipng ..."${ENDCOLOR}
find -mtime -7 -type f -name "*.png" -exec optipng -o7 -strip all {} \;

# Run pdf optimizer
#echo " > Running pdfwrite ..." >>$LOG
#echo -e ${YELLOW}" > Running pdfwrite ..."${ENDCOLOR}

#Here is a solution for getting the output of find into a bash array:
#array=()
#while IFS=  read -r -d $'\0'; do
#    array+=("$REPLY")
#done < <(find . -name "${input}" -print0)
#for %f in (*) do gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile=%f %f
#find -mtime -7 -type f -name "*.pdf" -exec gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.3 -dPDFSETTINGS=/screen -dNOPAUSE -dPrinted=false -dQUIET -sOutputFile=compressed.%f %f

# Fix ownership
echo " > Fixing ownership ..." >>$LOG
echo -e ${YELLOW}" > Fixing ownership ..."${ENDCOLOR}
chown -R www-data:www-data *

# Cleanning Swap
swapoff -a && swapon -a

# Cleanning RAM
sync
echo 1 >/proc/sys/vm/drop_caches
