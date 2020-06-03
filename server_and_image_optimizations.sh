#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc04
################################################################################

### Checking some things
if [[ -z "${SFOLDER}" ]]; then
  echo -e ${B_RED}" > Error: The script can only be runned by runner.sh! Exiting ..."${ENDCOLOR}
  exit 0
fi
################################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/packages_helper.sh
source "${SFOLDER}/libs/packages_helper.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"

################################################################################

optimize_image_size() {

  # $1 = ${PATH}
  # $2 = ${FILE_EXTENSION}
  # $3 = ${IMG_MAX_WIDTH}
  # $4 = ${IMG_MAX_HEIGHT}

  local PATH=$1
  local FILE_EXTENSION=$2
  local IMG_MAX_WIDTH=$3
  local IMG_MAX_HEIGHT=$4

  # Run ImageMagick mogrify
  echo " > Running mogrify ..." >>$LOG
  echo -e ${CYAN}" > Running mogrify ..."${ENDCOLOR}

  echo " > Executing: ${FIND} ${PATH} -mtime -7 -type f -name *.${FILE_EXTENSION} -exec ${MOGRIFY} -resize ${IMG_MAX_WIDTH}x${IMG_MAX_HEIGHT}\> {} \;">>$LOG
  #echo -e ${B_MAGENTA}" > Executing: ${FIND} ${PATH} -mtime -7 -type f -name "*.${FILE_EXTENSION}" -exec ${MOGRIFY} -resize "${IMG_MAX_WIDTH}"x"${IMG_MAX_HEIGHT}"\> {} \;"${ENDCOLOR}
  ${FIND} "${PATH}" -mtime -7 -type f -name "*.${FILE_EXTENSION}" -exec "${MOGRIFY}" -resize "${IMG_MAX_WIDTH}"x"${IMG_MAX_HEIGHT}"\> {} \;

}

optimize_images() {

  # $1 = ${PATH}
  # $2 = ${FILE_EXTENSION}
  # $3 = ${JPG_COMPRESS}

  local PATH=$1
  local FILE_EXTENSION=$2
  local JPG_COMPRESS=$3

  if [ "${FILE_EXTENSION}" == "jpg" ]; then

    # Run jpegoptim
    echo " > Running jpegoptim ..." >>$LOG
    echo -e ${CYAN}" > Running jpegoptim ..."${ENDCOLOR}

    echo " > Executing: ${FIND} ${PATH} -mtime -7 -type f -regex .*\.\(jpg\|jpeg\) -exec ${JPEGOPTIM} --max=${JPG_COMPRESS} --strip-all --all-progressive {} \;">>$LOG
    #echo -e ${B_MAGENTA}" > Executing: ${FIND} ${PATH} -mtime -7 -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${JPG_COMPRESS}" --strip-all --all-progressive {} \;"${ENDCOLOR}
    ${FIND} "${PATH}" -mtime -7 -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${JPG_COMPRESS}" --strip-all --all-progressive {} \;

  elif [ "${FILE_EXTENSION}" == "png" ]; then

    # Run optipng
    echo " > Running optipng ..." >>$LOG
    echo -e ${CYAN}" > Running optipng ..."${ENDCOLOR}
    
    echo " > Executing: ${FIND} ${PATH} -mtime -7 -type f -name *.${FILE_EXTENSION} -exec ${OPTIPNG} -strip-all {} \;">>$LOG
    #echo -e ${B_MAGENTA}" > Executing: ${FIND} ${PATH} -mtime -7 -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${JPG_COMPRESS}" --strip-all --all-progressive {} \;"${ENDCOLOR}
    ${FIND} "${PATH}" -mtime -7 -type f -name "*.${FILE_EXTENSION}" -exec "${OPTIPNG}" -o7 -strip all {} \;

    else

    echo " > Unsopported file extension ${FILE_EXTENSION} ..."
    echo -e ${YELLOW}" > Unsopported file extension ${FILE_EXTENSION} ..."${ENDCOLOR}

  fi

}

################################################################################

# TODO: extract this to an option
JPG_COMPRESS='80'
IMG_MAX_WIDTH='1920'
IMG_MAX_HEIGHT='1080'

# mogrify
MOGRIFY="$(which mogrify)"

# jpegoptim
JPEGOPTIM="$(which jpegoptim)"

# optipng
OPTIPNG="$(which optipng)"

# Remove old packages from system
remove_old_packages

# Install image optimize packages
install_image_optimize_packages

# TODO: First need to run without the parameter -mtime -7

# Remove old log files from system
echo " > Deleting old system logs..." >>$LOG
echo -e ${YELLOW}" > Deleting old system logs ..."${ENDCOLOR}
${FIND} /var/log/ -mtime +7 -type f -delete

# Ref: https://github.com/centminmod/optimise-images
# Ref: https://stackoverflow.com/questions/6384729/only-shrink-larger-images-using-imagemagick-to-a-ratio

optimize_image_size "${SITES}" "jpg" "${IMG_MAX_WIDTH}" "${IMG_MAX_HEIGHT}"

optimize_images "${SITES}" "jpg" "${JPG_COMPRESS}"

optimize_images "${SITES}" "png" ""

# TODO: pdf optimization
# Ref: https://github.com/or-yarok/reducepdf

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
change_ownership "www-data" "www-data" "${SITES}"

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
