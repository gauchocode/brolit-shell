#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc10
################################################################################
#
# Optimizations Helper: Optimizations tasks.
#
################################################################################

################################################################################
# Private: check last optimization date
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function _check_last_optimization_date() {

  server_opt_info=~/.server_opt-info
  if [[ -e ${server_opt_info} ]]; then
    # shellcheck source=~/.server_opt-info
    source "${server_opt_info}"
    echo "${last_run}"

  else
    echo "last_run=never" >>"${server_opt_info}"
    echo "never"

  fi

}

################################################################################
# Private: update last optimization date
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function _update_last_optimization_date() {

  server_opt_info=~/.server_opt-info

  echo "last_run=${NOW}" >>"${server_opt_info}"

}

################################################################################
# Execute some image optimization tasks
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function optimize_images_complete() {

  # Check package required
  package_install_optimization_utils

  # TODO: extract this to an option
  img_compress='80'
  img_max_width='1920'
  img_max_height='1080'

  # Ref: https://github.com/centminmod/optimise-images
  # Ref: https://stackoverflow.com/questions/6384729/only-shrink-larger-images-using-imagemagick-to-a-ratio

  # TODO: First need to run without the parameter -mtime -7

  optimize_image_size "${PROJECTS_PATH}" "jpg" "${img_max_width}" "${img_max_height}"

  optimize_images "${PROJECTS_PATH}" "jpg" "${img_compress}"

  optimize_images "${PROJECTS_PATH}" "png" ""

  # Change ownership
  change_ownership "www-data" "www-data" "${PROJECTS_PATH}"

}

################################################################################
# Optimize ram usage
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function optimize_ram_usage() {

  # Restarting services
  log_event "info" "Restarting php-fpm service" "false"

  service php"${PHP_V}"-fpm restart

  display --indent 6 --text "- Restarting php-fpm service" --result "DONE" --color GREEN

  # Cleanning Swap
  clean_swap

  # Cleanning RAM
  clean_ram_cache

}

################################################################################
# Optimize images sizes
#
# Arguments:
#  $1 = ${path}
#  $2 = ${file_extension}
#  $3 = ${img_max_width}
#  $4 = ${img_max_height}
#
# Outputs:
#   nothing
################################################################################

function optimize_image_size() {

  local path="${1}"
  local file_extension="${2}"
  local img_max_width="${3}"
  local img_max_height="${4}"

  local last_run

  log_subsection "Image Resizer"

  # Run ImageMagick mogrify
  log_event "info" "Running mogrify to optimize image sizes ..." "false"

  last_run=$(_check_last_optimization_date)

  if [[ "${last_run}" == "never" ]]; then

    display --indent 6 --text "- Optimizing images sizes for first time"

    log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${MOGRIFY} -resize ${img_max_width}x${img_max_height}\> {} \;" "false"
    ${FIND} "${path}" -type f -name "*.${file_extension}" -exec "${MOGRIFY}" -resize "${img_max_width}"x"${img_max_height}"\> {} \;

    display --indent 6 --text "- Optimizing images sizes for first time" --result "DONE" --color GREEN

  else

    display --indent 6 --text "- Optimizing images of last 7 days"

    log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${MOGRIFY} -resize ${img_max_width}x${img_max_height}\> {} \;" "false"
    ${FIND} "${path}" -mtime -7 -type f -name "*.${file_extension}" -exec "${MOGRIFY}" -resize "${img_max_width}"x"${img_max_height}"\> {} \;

    display --indent 6 --text "- Optimizing images of last 7 days" --result "DONE" --color GREEN

  fi

  # Next time will run the find command with -mtime -7 parameter
  _update_last_optimization_date

}

################################################################################
# Optimize images compression
#
# Arguments:
#  $1 = ${path}
#  $2 = ${file_extension}
#  $3 = ${img_compress}
#
# Outputs:
#   nothing
################################################################################

function optimize_images() {

  local path="${1}"
  local file_extension="${2}"
  local img_compress="${3}"

  local last_run

  log_subsection "Image Optimizer"

  last_run="$(_check_last_optimization_date)"

  if [[ ${file_extension} == "jpg" ]]; then

    # Run jpegoptim
    log_event "info" "Running jpegoptim to optimize images"
    display --indent 6 --text "- Optimizing jpg images"

    if [[ "${last_run}" == "never" ]]; then

      log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -regex .*\.\(jpg\|jpeg\) -exec ${JPEGOPTIM} --max=${img_compress} --strip-all --all-progressive {} \;" "false"
      ${FIND} "${path}" -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${img_compress}" --strip-all --all-progressive {} \;

    else

      log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -regex .*\.\(jpg\|jpeg\) -exec ${JPEGOPTIM} --max=${img_compress} --strip-all --all-progressive {} \;" "false"
      ${FIND} "${path}" -mtime -7 -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${img_compress}" --strip-all --all-progressive {} \;

    fi

    display --indent 6 --text "- Optimizing jpg images" --result "DONE" --color GREEN

  elif [[ ${file_extension} == "png" ]]; then

    # Run optipng
    log_event "info" "Running optipng to optimize images ..."
    display --indent 6 --text "- Optimizing png images"

    if [[ "${last_run}" == "never" ]]; then

      log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${OPTIPNG} -strip-all {} \;" "false"
      ${FIND} "${path}" -type f -name "*.${file_extension}" -exec "${OPTIPNG}" -o7 -strip all {} \;

    else

      log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${OPTIPNG} -strip-all {} \;" "false"
      ${FIND} "${path}" -mtime -7 -type f -name "*.${file_extension}" -exec "${OPTIPNG}" -o7 -strip all {} \;

    fi

    display --indent 6 --text "- Optimizing png images" --result "DONE" --color GREEN

  else

    log_event "warning" "Unsopported file extension ${file_extension}" "false"
    display --indent 6 --text "- Optimizing images" --result "FAIL" --color RED
    display --indent 8 --text "Unsopported file extension: ${file_extension}"

  fi

  # Next time will run the find command with -mtime -7 parameter
  _update_last_optimization_date

}

################################################################################
# Optimize pdfs
#
# Arguments:
#  none
#
# Outputs:
#   nothing
################################################################################

function optimize_pdfs() {

  local last_run

  last_run=$(_check_last_optimization_date)

  # Run pdf optimizer
  log_event "error" "TODO: Running pdfwrite ..." "false"

  #Here is a solution for getting the output of find into a bash array:
  #array=()
  #while IFS=  read -r -d $'\0'; do
  #    array+=("$REPLY")
  #done < <(find . -name "${input}" -print0)
  #for %f in (*) do gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/screen -dNOPAUSE -dQUIET -dBATCH -sOutputFile=%f %f
  #find -mtime -7 -type f -name "*.pdf" -exec gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.3 -dPDFSETTINGS=/screen -dNOPAUSE -dPrinted=false -dQUIET -sOutputFile=compressed.%f %f

  # Change ownership
  change_ownership "www-data" "www-data" "${PROJECTS_PATH}"

}

################################################################################
# Delete old logs
#
# Arguments:
#  none
#
# Outputs:
#   nothing
################################################################################

function delete_old_logs() {

  # Log
  log_event "info" "Deleting old system logs ..." "false"

  # Command
  ${FIND} /var/log/ -mtime +7 -type f -delete

  # Log
  display --indent 6 --text "- Deleting old system logs" --result "DONE" --color GREEN

}

################################################################################
# Clean swap
#
# Arguments:
#  none
#
# Outputs:
#   nothing
################################################################################

function clean_swap() {

  # Log
  log_event "info" "Cleanning Swap" "false"

  # Command
  swapoff -a && swapon -a

  # Log
  display --indent 6 --text "- Cleanning Swap" --result "DONE" --color GREEN

}

################################################################################
# Clean ram cache
#
# Arguments:
#  none
#
# Outputs:
#   nothing
################################################################################

function clean_ram_cache() {

  # Log
  log_event "info" "Cleanning RAM cache" "false"

  # Cleanning RAM
  sync
  echo 1 >/proc/sys/vm/drop_caches

  # Log
  display --indent 6 --text "- Cleanning RAM cache" --result "DONE" --color GREEN

}
