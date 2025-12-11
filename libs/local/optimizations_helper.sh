#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.4
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
# Private: Get the correct uploads path for a WordPress project
#
# Arguments:
#   ${1} = ${project_path} - Base project path
#   ${2} = ${project_install_type} - Installation type (default or docker-compose)
#
# Outputs:
#   The uploads directory path
################################################################################

function _get_wordpress_uploads_path() {

  local project_path="${1}"
  local project_install_type="${2}"

  local uploads_path

  # For Docker projects, get the correct data directory
  if [[ ${project_install_type} == "docker"* ]]; then
    local docker_data_dir
    docker_data_dir="$(project_get_configured_docker_data_dir "${project_path}")"

    if [[ -n "${docker_data_dir}" ]]; then
      uploads_path="${docker_data_dir}/wp-content/uploads"
    else
      log_event "warning" "Could not determine Docker data directory for ${project_path}" "false"
      uploads_path="${project_path}/wp-content/uploads"
    fi
  else
    # Default installation
    uploads_path="${project_path}/wp-content/uploads"
  fi

  echo "${uploads_path}"

}

################################################################################
# Execute some image optimization tasks
#
# Arguments:
#   ${1} = ${project_path} (optional) - Specific project path to optimize
#
# Outputs:
#   nothing
################################################################################

function optimize_images_complete() {

  local specific_project="${1}"

  log_subsection "Image Optimization"
  log_event "info" "Starting image optimization process for WordPress projects" "false"

  # Debug: Check if PROJECTS_PATH is set
  if [[ -z "${PROJECTS_PATH}" ]]; then
    log_event "error" "PROJECTS_PATH is not set. Cannot proceed with image optimization." "false"
    return 1
  fi

  log_event "info" "PROJECTS_PATH is set to: ${PROJECTS_PATH}" "false"

  # Check if PROJECTS_PATH exists
  if [[ ! -d "${PROJECTS_PATH}" ]]; then
    log_event "error" "PROJECTS_PATH directory does not exist: ${PROJECTS_PATH}" "false"
    return 1
  fi

  # Count WordPress projects
  local wp_projects_count=0

  # If a specific project was provided, process only that one
  if [[ -n "${specific_project}" ]]; then

    log_event "info" "Processing specific project: ${specific_project}" "false"

    # Determine install type
    local project_install_type
    project_install_type="$(project_get_install_type "${specific_project}")"

    log_event "info" "Project install type: ${project_install_type}" "false"

    # Get correct uploads path
    local uploads_path
    uploads_path="$(_get_wordpress_uploads_path "${specific_project}" "${project_install_type}")"

    # Verify uploads directory exists
    if [[ -d "${uploads_path}" ]]; then
      ((wp_projects_count++))
      log_event "info" "Processing uploads directory: ${uploads_path}" "false"
      # Optimize images only in uploads directory
      optimize_image_size "${uploads_path}" "jpg" "1920" "1080"
      optimize_images "${uploads_path}" "jpg" "80"
      optimize_images "${uploads_path}" "png" ""
    else
      log_event "warning" "Uploads directory not found: ${uploads_path}" "false"
    fi

  else

    # Process all WordPress projects
    log_event "info" "Processing all WordPress projects in ${PROJECTS_PATH}" "false"

    for project_path in "${PROJECTS_PATH}"/*/; do
      # Skip if the glob didn't match anything (bash returns the pattern itself)
      [[ ! -d "${project_path}" ]] && continue

      log_event "debug" "Checking directory: ${project_path}" "false"

      # Determine install type
      local project_install_type
      project_install_type="$(project_get_install_type "${project_path}")"

      # Check for WordPress based on install type
      local is_wordpress=false

      if [[ ${project_install_type} == "docker"* ]]; then
        # For Docker, check in the data directory
        local docker_data_dir
        docker_data_dir="$(project_get_configured_docker_data_dir "${project_path}")"

        if [[ -f "${docker_data_dir}/wp-config.php" ]]; then
          is_wordpress=true
        fi
      else
        # For default installations
        if [[ -f "${project_path}wp-config.php" ]]; then
          is_wordpress=true
        fi
      fi

      if [[ ${is_wordpress} == true ]]; then

        ((wp_projects_count++))
        log_event "info" "Found WordPress project at ${project_path} (type: ${project_install_type})" "false"

        # Get correct uploads path
        local uploads_path
        uploads_path="$(_get_wordpress_uploads_path "${project_path}" "${project_install_type}")"

        # Verify uploads directory exists
        if [[ -d "${uploads_path}" ]]; then
          log_event "info" "Processing uploads directory: ${uploads_path}" "false"
          # Optimize images only in uploads directory
          optimize_image_size "${uploads_path}" "jpg" "1920" "1080"
          optimize_images "${uploads_path}" "jpg" "80"
          optimize_images "${uploads_path}" "png" ""
        else
          log_event "warning" "Uploads directory not found: ${uploads_path}" "false"
        fi

      else
        log_event "debug" "Not a WordPress project: ${project_path}" "false"
      fi

    done

  fi

  if [[ ${wp_projects_count} -eq 0 ]]; then
    log_event "warning" "No WordPress projects found" "false"
  else
    log_event "info" "Processed ${wp_projects_count} WordPress project(s)" "false"
  fi

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
#  ${1} = ${project_path} (optional) - Specific project path to optimize
#
# Outputs:
#   nothing
################################################################################

function optimize_pdfs() {
  local specific_project="${1}"
  local last_run
  local pdf_files=()
  local wp_projects_count=0

  last_run=$(_check_last_optimization_date)
  log_subsection "PDF Optimizer"

  # Debug: Check if PROJECTS_PATH is set
  if [[ -z "${PROJECTS_PATH}" ]]; then
    log_event "error" "PROJECTS_PATH is not set. Cannot proceed with PDF optimization." "false"
    return 1
  fi

  log_event "info" "PROJECTS_PATH is set to: ${PROJECTS_PATH}" "false"

  # Check if PROJECTS_PATH exists
  if [[ ! -d "${PROJECTS_PATH}" ]]; then
    log_event "error" "PROJECTS_PATH directory does not exist: ${PROJECTS_PATH}" "false"
    return 1
  fi

  # If a specific project was provided, process only that one
  if [[ -n "${specific_project}" ]]; then

    log_event "info" "Processing specific project: ${specific_project}" "false"

    # Determine install type
    local project_install_type
    project_install_type="$(project_get_install_type "${specific_project}")"

    log_event "info" "Project install type: ${project_install_type}" "false"

    # Get correct uploads path
    local uploads_path
    uploads_path="$(_get_wordpress_uploads_path "${specific_project}" "${project_install_type}")"

    # Verify uploads directory exists and find PDFs
    if [[ -d "${uploads_path}" ]]; then
      ((wp_projects_count++))
      log_event "info" "Searching for PDFs in: ${uploads_path}" "false"

      while IFS= read -r -d $'\0' pdf_file; do
        pdf_files+=("$pdf_file")
      done < <(${FIND} "${uploads_path}" -type f -name "*.pdf" -print0)
    else
      log_event "warning" "Uploads directory not found: ${uploads_path}" "false"
    fi

  else

    # Process all WordPress projects
    log_event "info" "Processing all WordPress projects in ${PROJECTS_PATH}" "false"

    for project_path in "${PROJECTS_PATH}"/*/; do
      # Skip if the glob didn't match anything
      [[ ! -d "${project_path}" ]] && continue

      log_event "debug" "Checking directory: ${project_path}" "false"

      # Determine install type
      local project_install_type
      project_install_type="$(project_get_install_type "${project_path}")"

      # Check for WordPress based on install type
      local is_wordpress=false

      if [[ ${project_install_type} == "docker"* ]]; then
        # For Docker, check in the data directory
        local docker_data_dir
        docker_data_dir="$(project_get_configured_docker_data_dir "${project_path}")"

        if [[ -f "${docker_data_dir}/wp-config.php" ]]; then
          is_wordpress=true
        fi
      else
        # For default installations
        if [[ -f "${project_path}wp-config.php" ]]; then
          is_wordpress=true
        fi
      fi

      if [[ ${is_wordpress} == true ]]; then

        ((wp_projects_count++))
        log_event "info" "Found WordPress project at ${project_path} (type: ${project_install_type})" "false"

        # Get correct uploads path
        local uploads_path
        uploads_path="$(_get_wordpress_uploads_path "${project_path}" "${project_install_type}")"

        # Verify uploads directory exists and find PDFs
        if [[ -d "${uploads_path}" ]]; then
          log_event "info" "Searching for PDFs in: ${uploads_path}" "false"

          while IFS= read -r -d $'\0' pdf_file; do
            pdf_files+=("$pdf_file")
          done < <(${FIND} "${uploads_path}" -type f -name "*.pdf" -print0)
        else
          log_event "warning" "Uploads directory not found: ${uploads_path}" "false"
        fi

      else
        log_event "debug" "Not a WordPress project: ${project_path}" "false"
      fi

    done

  fi

  # Optimize found PDFs
  if [[ ${#pdf_files[@]} -gt 0 ]]; then
    log_event "info" "Found ${#pdf_files[@]} PDF file(s) to optimize" "false"

    for pdf_file in "${pdf_files[@]}"; do
      local compressed_file="${pdf_file}.compressed"

      log_event "info" "Optimizing: ${pdf_file}" "false"

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
        log_event "info" "PDF optimized successfully: ${pdf_file}" "false"
        mv "${compressed_file}" "${pdf_file}"
      else
        log_event "warning" "PDF optimization did not reduce size, keeping original: ${pdf_file}" "false"
        rm -f "${compressed_file}"
      fi
    done
  else
    log_event "warning" "No PDF files found to optimize" "false"
  fi

  if [[ ${wp_projects_count} -eq 0 ]]; then
    log_event "warning" "No WordPress projects found" "false"
  else
    log_event "info" "Processed ${wp_projects_count} WordPress project(s)" "false"
  fi

  # Next time will run the find command with -mtime -7 parameter
  _update_last_optimization_date

  log_event "info" "PDF optimization process completed" "false"
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
