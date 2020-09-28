#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.4
################################################################################

#
#################################################################################
#
# * Main functions
#
#################################################################################
#

optimize_images_complete() {

    # TODO: extract this to an option
    img_compress='80'
    img_max_width='1920'
    img_max_height='1080'
    
    # Ref: https://github.com/centminmod/optimise-images
    # Ref: https://stackoverflow.com/questions/6384729/only-shrink-larger-images-using-imagemagick-to-a-ratio

    # TODO: First need to run without the parameter -mtime -7

    optimize_image_size "${SITES}" "jpg" "${img_max_width}" "${img_max_height}"

    optimize_images "${SITES}" "jpg" "${img_compress}"

    optimize_images "${SITES}" "png" ""

    # Fix ownership
    change_ownership "www-data" "www-data" "${SITES}"

}

optimize_ram_usage() {

    # Restarting services
    log_event "info" "Restarting php-fpm service" "false"
    service php"${PHP_V}"-fpm restart
    display --indent 2 --text "- Restarting php-fpm service" --result "DONE" --color GREEN

    # Cleanning Swap
    clean_swap

    # Cleanning RAM
    clean_ram_cache

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
  log_event "info" "Running mogrify to optimize image sizes ..." "false"

  last_run=$(check_last_optimization_date)
  
  if [[ "${last_run}" == "never" ]]; then
  
    log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${MOGRIFY} -resize ${img_max_width}x${img_max_height}\> {} \;" "false"
    ${FIND} "${path}" -type f -name "*.${file_extension}" -exec "${MOGRIFY}" -resize "${img_max_width}"x"${img_max_height}"\> {} \;
  
  else
  
    log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${MOGRIFY} -resize ${img_max_width}x${img_max_height}\> {} \;" "false"
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
    log_event "info" "Running jpegoptim to optimize images ..." "false"

    if [[ "${last_run}" == "never" ]]; then

      log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -regex .*\.\(jpg\|jpeg\) -exec ${JPEGOPTIM} --max=${img_compress} --strip-all --all-progressive {} \;" "false"
      ${FIND} "${path}" -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${img_compress}" --strip-all --all-progressive {} \;

    else

      log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -regex .*\.\(jpg\|jpeg\) -exec ${JPEGOPTIM} --max=${img_compress} --strip-all --all-progressive {} \;" "false"
      ${FIND} "${path}" -mtime -7 -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${img_compress}" --strip-all --all-progressive {} \;

    fi

  elif [ "${file_extension}" == "png" ]; then

    # Run optipng
    log_event "info" "Running optipng to optimize images ..." "false"

    if [[ "${last_run}" == "never" ]]; then
    
      log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${OPTIPNG} -strip-all {} \;" "false"
      ${FIND} "${path}" -type f -name "*.${file_extension}" -exec "${OPTIPNG}" -o7 -strip all {} \;
    
    else

      log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${OPTIPNG} -strip-all {} \;" "false"
      ${FIND} "${path}" -mtime -7 -type f -name "*.${file_extension}" -exec "${OPTIPNG}" -o7 -strip all {} \;
    
    fi

  else

    log_event "warning" "Unsopported file extension ${file_extension}" "true"    

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
  log_event "error" "TODO: Running pdfwrite ..." "false"    

  #Here is a solution for getting the output of find into a bash array:
  #array=()
  #while IFS=  read -r -d $'\0'; do
  #    array+=("$REPLY")
  #done < <(find . -name "${input}" -print0)
  #for %f in (*) do gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile=%f %f
  #find -mtime -7 -type f -name "*.pdf" -exec gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.3 -dPDFSETTINGS=/screen -dNOPAUSE -dPrinted=false -dQUIET -sOutputFile=compressed.%f %f

  # Fix ownership
  change_ownership "www-data" "www-data" "${SITES}"

}

#
#################################################################################
#
# * Utils
#
#################################################################################
#

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

delete_old_logs() {

  # Remove old log files from system
  log_event "info" "Deleting old system logs ..." "false"
  ${FIND} /var/log/ -mtime +7 -type f -delete

}

clean_swap() {

  # Cleanning Swap
  log_event "info" "Cleanning Swap" "false"
  swapoff -a && swapon -a

  display --indent 2 --text "- Cleanning Swap" --result "DONE" --color GREEN

}

clean_ram_cache() {

  # Cleanning RAM
  log_event "info" "Cleanning RAM cache" "false"
  sync
  echo 1 >/proc/sys/vm/drop_caches

  display --indent 2 --text "- Cleanning RAM cache" --result "DONE" --color GREEN

}