#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc05
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

#TODO: better date control

check_last_optimization_date() {

  server_opt_info=~/.server_opt-info
  if [[ -e ${server_opt_info} ]]; then
    # shellcheck source=${server_opt_info}
    source "${server_opt_info}"
    echo "${last_run}"

  else
    echo "last_run=never">>"${server_opt_info}"
    echo "never"

  fi

}

update_last_optimization_date() {

  server_opt_info=~/.server_opt-info

  echo "last_run=${NOW}">>"${server_opt_info}"

}

optimize_image_size() {

  # $1 = ${path}
  # $2 = ${file_extension}
  # $3 = ${img_max_width}
  # $4 = ${img_max_height}

  local path=$1
  local file_extension=$2
  local img_max_width=$3
  local img_max_height=$4

  local last_run

  # Run ImageMagick mogrify
  echo " > Running mogrify ..." >>$LOG
  echo -e ${CYAN}" > Running mogrify ..."${ENDCOLOR}

  last_run=$(check_last_optimization_date)
  
  if [[ "${last_run}" == "never" ]]; then
  
    echo " > Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${MOGRIFY} -resize ${img_max_width}x${img_max_height}\> {} \;">>$LOG
    ${FIND} "${path}" -type f -name "*.${file_extension}" -exec "${MOGRIFY}" -resize "${img_max_width}"x"${img_max_height}"\> {} \;
  
  else
  
    echo " > Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${MOGRIFY} -resize ${img_max_width}x${img_max_height}\> {} \;">>$LOG
    ${FIND} "${path}" -mtime -7 -type f -name "*.${file_extension}" -exec "${MOGRIFY}" -resize "${img_max_width}"x"${img_max_height}"\> {} \;
  
  fi

  # Next time will run the find command with -mtime -7 parameter
  update_last_optimization_date

}

optimize_images() {

  # $1 = ${path}
  # $2 = ${file_extension}
  # $3 = ${img_compress}

  local path=$1
  local file_extension=$2
  local img_compress=$3

  local last_run

  last_run=$(check_last_optimization_date)

  if [ "${file_extension}" == "jpg" ]; then

    # Run jpegoptim
    echo " > Running jpegoptim ..." >>$LOG
    echo -e ${CYAN}" > Running jpegoptim ..."${ENDCOLOR}

    if [[ "${last_run}" == "never" ]]; then

      echo " > Executing: ${FIND} ${path} -mtime -7 -type f -regex .*\.\(jpg\|jpeg\) -exec ${JPEGOPTIM} --max=${img_compress} --strip-all --all-progressive {} \;">>$LOG
      ${FIND} "${path}" -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${img_compress}" --strip-all --all-progressive {} \;

    else

      echo " > Executing: ${FIND} ${path} -mtime -7 -type f -regex .*\.\(jpg\|jpeg\) -exec ${JPEGOPTIM} --max=${img_compress} --strip-all --all-progressive {} \;">>$LOG
      ${FIND} "${path}" -mtime -7 -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${img_compress}" --strip-all --all-progressive {} \;

    fi

  elif [ "${file_extension}" == "png" ]; then

    # Run optipng
    echo " > Running optipng ..." >>$LOG
    echo -e ${CYAN}" > Running optipng ..."${ENDCOLOR}

    if [[ "${last_run}" == "never" ]]; then
    
      echo " > Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${OPTIPNG} -strip-all {} \;">>$LOG
      ${FIND} "${path}" -type f -name "*.${file_extension}" -exec "${OPTIPNG}" -o7 -strip all {} \;
    
    else

      echo " > Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${OPTIPNG} -strip-all {} \;">>$LOG
      ${FIND} "${path}" -mtime -7 -type f -name "*.${file_extension}" -exec "${OPTIPNG}" -o7 -strip all {} \;
    
    fi

  else

    echo " > Unsopported file extension ${file_extension} ..."
    echo -e ${YELLOW}" > Unsopported file extension ${file_extension} ..."${ENDCOLOR}

  fi

  # Next time will run the find command with -mtime -7 parameter
  update_last_optimization_date

}

optimize_pdfs() {

  # $1 = ${path}
  # $2 = ${file_extension}
  # $3 = ${img_max_width}
  # $4 = ${img_max_height}

  local last_run

  last_run=$(check_last_optimization_date)

  # Run pdf optimizer
  echo " > TODO: Running pdfwrite ..." >>$LOG
  echo -e ${YELLOW}" > TODO: Running pdfwrite ..."${ENDCOLOR}

  #Here is a solution for getting the output of find into a bash array:
  #array=()
  #while IFS=  read -r -d $'\0'; do
  #    array+=("$REPLY")
  #done < <(find . -name "${input}" -print0)
  #for %f in (*) do gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile=%f %f
  #find -mtime -7 -type f -name "*.pdf" -exec gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.3 -dPDFSETTINGS=/screen -dNOPAUSE -dPrinted=false -dQUIET -sOutputFile=compressed.%f %f

}

delete_old_logs() {

  # Remove old log files from system
  echo " > Deleting old system logs..." >>$LOG
  echo -e ${YELLOW}" > Deleting old system logs ..."${ENDCOLOR}
  ${FIND} /var/log/ -mtime +7 -type f -delete

}

clean_swap() {

  # Cleanning Swap
  echo " > Cleanning Swap ..." >>$LOG
  echo -e ${CYAN}" > Cleanning Swap ..."${ENDCOLOR}
  swapoff -a && swapon -a

}

clean_ram_cache() {

  # Cleanning RAM
  echo " > Cleanning RAM ..." >>$LOG
  echo -e ${CYAN}" > Cleanning RAM ..."${ENDCOLOR}
  sync
  echo 1 >/proc/sys/vm/drop_caches

}


################################################################################

# TODO: extract this to an option
img_compress='80'
img_max_width='1920'
img_max_height='1080'

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

# Remove old log files from system
delete_old_logs

# Ref: https://github.com/centminmod/optimise-images
# Ref: https://stackoverflow.com/questions/6384729/only-shrink-larger-images-using-imagemagick-to-a-ratio

# TODO: First need to run without the parameter -mtime -7

optimize_image_size "${SITES}" "jpg" "${img_max_width}" "${img_max_height}"

optimize_images "${SITES}" "jpg" "${img_compress}"

optimize_images "${SITES}" "png" ""

# TODO: pdf optimization
# Ref: https://github.com/or-yarok/reducepdf

optimize_pdfs

# Fix ownership
change_ownership "www-data" "www-data" "${SITES}"

# Restarting services
echo " > Restarting services ..." >>$LOG
echo -e ${CYAN}" > Restarting services ..."${ENDCOLOR}
service php"${PHP_V}"-fpm restart

# Cleanning Swap
clean_swap

# Cleanning RAM
clean_ram_cache
