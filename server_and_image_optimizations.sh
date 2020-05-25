#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc03
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

source "${SFOLDER}/libs/commons.sh"
source "${SFOLDER}/libs/packages_helper.sh"
source "${SFOLDER}/libs/mail_notification_helper.sh"

################################################################################

# TODO: extract this to an option
JPG_COMPRESS='90'

# Remove old packages from system
remove_old_packages

# Install image optimize packages
install_image_optimize_packages

# TODO: First need to run without the parameter -mtime -7

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

# TODO: pdf optimization

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
echo -e ${CYAN}" > Fixing ownership ..."${ENDCOLOR}
chown -R www-data:www-data *

# Restarting services
echo " > Restarting services ..." >>$LOG
echo -e ${CYAN}" > Restarting services ..."${ENDCOLOR}
service php"${PHP_V}"-fpm restart

# Cleanning Swap
echo " > Cleanning Swap ..." >>$LOG
echo -e ${CYAN}" > Cleanning Swap ..."${ENDCOLOR}
swapoff -a && swapon -a

# Cleanning RAM
echo " > Cleanning RAM ..." >>$LOG
echo -e ${CYAN}" > Cleanning RAM ..."${ENDCOLOR}
sync
echo 1 >/proc/sys/vm/drop_caches
