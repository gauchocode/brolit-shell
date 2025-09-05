#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.12
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

  log_subsection "Image Optimization"
  log_event "info" "Starting image optimization process for WordPress projects" "false"
  
  # Process only WordPress projects
  for project_path in "${PROJECTS_PATH}"/*/; do
  
    if [[ -f "${project_path}wp-config.php" ]]; then
    
      log_event "info" "Found WordPress project at ${project_path}" "false"

      local uploads_path="${project_path}wp-content/uploads"
      
      # Verify uploads directory exists
      if [[ -d "${uploads_path}" ]]; then
        log_event "info" "Processing uploads directory: ${uploads_path}" "false"
        # Optimize images only in uploads directory
        optimize_image_size "${uploads_path}" "jpg" "1920" "1080"
        optimize_images "${uploads_path}" "jpg" "80"
        optimize_images "${uploads_path}" "png" ""
      fi

    fi

  done
  
  log_event "info" "Image optimization process completed" "false"

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

  # Cleanning Swap
  clean_swap

  # Cleanning RAM
  clean_ram_cache

}

################################################################################
# Optimize images sizes
#
# Arguments:
#  ${1} = ${path}
#  ${2} = ${file_extension}
#  ${3} = ${img_max_width}
#  ${4} = ${img_max_height}
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

  log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${MOGRIFY} -resize ${img_max_width}x${img_max_height}\> {} \;" "false"
  ${FIND} "${path}" -type f -name "*.${file_extension}" -exec "${MOGRIFY}" -resize "${img_max_width}"x"${img_max_height}"\> {} \;

  else

  log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${MOGRIFY} -resize ${img_max_width}x${img_max_height}\> {} \;" "false"
  ${FIND} "${path}" -mtime -7 -type f -name "*.${file_extension}" -exec "${MOGRIFY}" -resize "${img_max_width}"x"${img_max_height}"\> {} \;

  fi

  # Next time will run the find command with -mtime -7 parameter
  _update_last_optimization_date

}

################################################################################
# Optimize images compression
#
# Arguments:
#  ${1} = ${path}
#  ${2} = ${file_extension}
#  ${3} = ${img_compress}
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
  if [[ "${last_run}" == "never" ]]; then

    log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -regex .*\.\(jpg\|jpeg\) -exec ${JPEGOPTIM} --max=${img_compress} --strip-all --all-progressive {} \;" "false"
    ${FIND} "${path}" -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${img_compress}" --strip-all --all-progressive {} \;

  else

    log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -regex .*\.\(jpg\|jpeg\) -exec ${JPEGOPTIM} --max=${img_compress} --strip-all --all-progressive {} \;" "false"
    ${FIND} "${path}" -mtime -7 -type f -regex ".*\.\(jpg\|jpeg\)" -exec "${JPEGOPTIM}" --max="${img_compress}" --strip-all --all-progressive {} \;

  fi

  elif [[ ${file_extension} == "png" ]]; then

    # Run optipng
    log_event "info" "Running optipng to optimize images ..."
  if [[ "${last_run}" == "never" ]]; then

    log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${OPTIPNG} -strip-all {} \;" "false"
    ${FIND} "${path}" -type f -name "*.${file_extension}" -exec "${OPTIPNG}" -o7 -strip all {} \;

  else

    log_event "info" "Executing: ${FIND} ${path} -mtime -7 -type f -name *.${file_extension} -exec ${OPTIPNG} -strip-all {} \;" "false"
    ${FIND} "${path}" -mtime -7 -type f -name "*.${file_extension}" -exec "${OPTIPNG}" -o7 -strip all {} \;

  fi

  else

    log_event "warning" "Unsupported file extension ${file_extension}" "false"

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
  local pdf_files=()

  last_run=$(_check_last_optimization_date)
  log_subsection "PDF Optimizer"

  # Find PDF files in WordPress uploads directories
  while IFS= read -r -d $'\0' project_path; do
    if [[ -f "${project_path}wp-config.php" ]]; then
      local uploads_path="${project_path}wp-content/uploads"
      
      if [[ -d "${uploads_path}" ]]; then
        while IFS= read -r -d $'\0' pdf_file; do
          pdf_files+=("$pdf_file")
        done < <(${FIND} "${uploads_path}" -type f -name "*.pdf" -print0)
      fi
    fi
  done < <(${FIND} "${PROJECTS_PATH}" -maxdepth 1 -type d -print0)

  if [[ ${#pdf_files[@]} -gt 0 ]]; then
  for pdf_file in "${pdf_files[@]}"; do
    local compressed_file="${pdf_file}.compressed"
      
    # Optimize PDF
    gs -sDEVICE=pdfwrite \
       -dCompatibilityLevel=1.4 \
       -dPDFSETTINGS=/screen \
       -dNOPAUSE \
       -dBATCH \
       -sOutputFile="${compressed_file}" \
       "${pdf_file}" >/dev/null 2>&1
      
    # Replace original if successful
    if [[ -s "${compressed_file}" ]] && [[ $(wc -c < "${compressed_file}") -lt $(wc -c < "${pdf_file}") ]]; then
      mv "${compressed_file}" "${pdf_file}"
    else
      rm -f "${compressed_file}"
    fi
  done
  fi

  # Next time will run the find command with -mtime -7 parameter
  _update_last_optimization_date
}

################################################################################
# Truncate large Docker container logs
#
# Arguments:
#  none
#
# Outputs:
#   nothing
################################################################################

function truncate_large_docker_logs() {
  # Log
  log_event "info" "Truncating large Docker container logs ..." "false"

  # Find and truncate Docker container logs larger than 1GB
  ${FIND} /var/lib/docker/containers/ -name "*-json.log" -exec du -sh {} + | awk '$1 ~ /^[0-9.]+G/ {print $2}' | while read -r log; do
    log_event "info" "Truncating large log: $log" "false"
    truncate -s 0 "$log"
  done

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

  # Truncate large Docker container logs
  truncate_large_docker_logs
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
  log_event "info" "Cleaning Swap" "false"

  # Command
  swapoff -a && swapon -a

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
  log_event "info" "Cleaning RAM cache" "false"

  # Cleanning RAM
  sync
  echo 1 >/proc/sys/vm/drop_caches

}

################################################################################
# Fix WordPress permissions
#
# Arguments:
#  none
#
# Outputs:
#   nothing
################################################################################

function fix_wordpress_permissions() {
  log_subsection "WordPress Permissions Fix"
  
  for project_path in "${PROJECTS_PATH}"/*/; do
    if [[ -f "${project_path}wp-config.php" ]]; then
      # Directories: 755
      find "${project_path}" -type d -exec chmod 755 {} \; >/dev/null 2>&1
      
      # Files: 644
      find "${project_path}" -type f -exec chmod 644 {} \; >/dev/null 2>&1
      
      # Specific for uploads
      local uploads_path="${project_path}wp-content/uploads"
      if [[ -d "${uploads_path}" ]]; then
        chown -R www-data:www-data "${uploads_path}" >/dev/null 2>&1
      fi
    fi
  done
}
