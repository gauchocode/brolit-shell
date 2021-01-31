#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.11
################################################################################

#
#################################################################################
#
# * Main functions
#
#################################################################################
#

function optimize_images_complete() {

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

function optimize_ram_usage() {

    # Restarting services
    log_event "info" "Restarting php-fpm service"
    
    service php"${PHP_V}"-fpm restart

    display --indent 6 --text "- Restarting php-fpm service" --result "DONE" --color GREEN

    # Cleanning Swap
    clean_swap

    # Cleanning RAM
    clean_ram_cache

}

function optimize_image_size() {

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
  log_event "info" "Running mogrify to optimize image sizes ..."
  log_subsection "Image Resizer"

  last_run=$(check_last_optimization_date)
  
  if [[ "${last_run}" == "never" ]]; then

    display --indent 6 --text "- Optimizing images sizes for first time"
  
    log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${MOGRIFY} -resize ${img_max_width}x${img_max_height}\> {} \;"
    ${FIND} "${path}" -type f -name "*.${file_extension}" -exec "${MOGRIFY}" -resize "${img_max_width}"x"${img_max_height}"\> {} \;

    display --indent 6 --text "- Optimizing images sizes for first time" --result "DONE" --color GREEN
  
  else

    display --indent 6 --text "- Optimizing images of last 7 days"
  
    log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${MOGRIFY} -resize ${img_max_width}x${img_max_height}\> {} \;"
    ${FIND} "${path}" -mtime -7 -type f -name "*.${file_extension}" -exec "${MOGRIFY}" -resize "${img_max_width}"x"${img_max_height}"\> {} \;

    display --indent 6 --text "- Optimizing images of last 7 days" --result "DONE" --color GREEN
  
  fi

  # Next time will run the find command with -mtime -7 parameter
  update_last_optimization_date

}

function optimize_images() {

  # $1 = ${path}
  # $2 = ${file_extension}
  # $3 = ${img_compress}

  local path=$1
  local file_extension=$2
  local img_compress=$3

  local last_run

  log_subsection "Image Optimizer"

  last_run="$(check_last_optimization_date)"

  if [[ ${file_extension} == "jpg" ]]; then

    # Run jpegoptim
    log_event "info" "Running jpegoptim to optimize images"
    display --indent 6 --text "- Optimizing jpg images"

    if [[ "${last_run}" == "never" ]]; then

      log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -regex .*\.\(jpg\|jpeg\) -exec ${JPEGOPTIM} --max=${img_compress} --strip-all --all-progressive {} \;"
      ${FIND} "${path}" -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${img_compress}" --strip-all --all-progressive {} \;

    else

      log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -regex .*\.\(jpg\|jpeg\) -exec ${JPEGOPTIM} --max=${img_compress} --strip-all --all-progressive {} \;"
      ${FIND} "${path}" -mtime -7 -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${img_compress}" --strip-all --all-progressive {} \;

    fi

    display --indent 6 --text "- Optimizing jpg images" --result "DONE" --color GREEN

  elif [[ ${file_extension} == "png" ]]; then

    # Run optipng
    log_event "info" "Running optipng to optimize images ..."
    display --indent 6 --text "- Optimizing png images"

    if [[ "${last_run}" == "never" ]]; then
    
      log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${OPTIPNG} -strip-all {} \;"
      ${FIND} "${path}" -type f -name "*.${file_extension}" -exec "${OPTIPNG}" -o7 -strip all {} \;
    
    else

      log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${OPTIPNG} -strip-all {} \;"
      ${FIND} "${path}" -mtime -7 -type f -name "*.${file_extension}" -exec "${OPTIPNG}" -o7 -strip all {} \;
    
    fi

    display --indent 6 --text "- Optimizing png images" --result "DONE" --color GREEN

  else

    log_event "warning" "Unsopported file extension ${file_extension}"
    display --indent 6 --text "- Optimizing images" --result "FAIL" --color RED
    display --indent 8 --text "Unsopported file extension: ${file_extension}"

  fi

  # Next time will run the find command with -mtime -7 parameter
  update_last_optimization_date

}

function optimize_pdfs() {

  # $1 = ${path}
  # $2 = ${file_extension}
  # $3 = ${img_max_width}
  # $4 = ${img_max_height}

  local last_run

  last_run=$(check_last_optimization_date)

  # Run pdf optimizer
  log_event "error" "TODO: Running pdfwrite ..."

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

function check_last_optimization_date() {

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

function update_last_optimization_date() {

  server_opt_info=~/.server_opt-info

  echo "last_run=${NOW}">>"${server_opt_info}"

}

function delete_old_logs() {

  # Remove old log files from system
  log_event "info" "Deleting old system logs ..."
  ${FIND} /var/log/ -mtime +7 -type f -delete

  display --indent 6 --text "- Deleting old system logs" --result "DONE" --color GREEN

}

function clean_swap() {

  # Cleanning Swap
  log_event "info" "Cleanning Swap"
  swapoff -a && swapon -a

  display --indent 6 --text "- Cleanning Swap" --result "DONE" --color GREEN

}

function clean_ram_cache() {

  # Cleanning RAM
  log_event "info" "Cleanning RAM cache"
  sync
  echo 1 >/proc/sys/vm/drop_caches

  display --indent 6 --text "- Cleanning RAM cache" --result "DONE" --color GREEN

}