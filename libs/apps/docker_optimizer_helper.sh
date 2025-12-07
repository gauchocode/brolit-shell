#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.6
################################################################################
#
# Docker Optimizer Helper: Optimization tasks for Docker containers.
#
################################################################################

################################################################################
# List all Docker Compose projects
#
# Arguments:
#   none
#
# Outputs:
#   List of project paths (one per line)
################################################################################

function docker_optimizer_list_projects() {

  local project_list=()

  # Scan PROJECTS_PATH for docker-compose.yml files
  while IFS= read -r -d '' project_path; do
    project_dir="$(dirname "${project_path}")"
    # Verify it's a valid project directory
    if [[ -f "${project_dir}/docker-compose.yml" ]]; then
      project_list+=("${project_dir}")
    fi
  done < <(find "${PROJECTS_PATH}" -maxdepth 2 -name "docker-compose.yml" -type f -print0 2>/dev/null)

  # Output project list
  if [[ ${#project_list[@]} -gt 0 ]]; then
    printf '%s\n' "${project_list[@]}"
    return 0
  else
    return 1
  fi

}

################################################################################
# Get container name for a service
#
# Arguments:
#   ${1} = ${project_path}
#   ${2} = ${service_name} (e.g., "php-fpm", "nginx", "mysql", "redis")
#
# Outputs:
#   Container name or empty string
################################################################################

function docker_optimizer_get_container_name() {

  local project_path="${1}"
  local service_name="${2}"
  local compose_file="${project_path}/docker-compose.yml"
  local container_name

  if [[ ! -f ${compose_file} ]]; then
    return 1
  fi

  # Get container name from docker compose
  container_name="$(docker compose -f "${compose_file}" ps -q "${service_name}" 2>/dev/null | xargs docker inspect --format='{{.Name}}' 2>/dev/null | sed 's|^/||')"

  if [[ -n ${container_name} ]]; then
    echo "${container_name}"
    return 0
  else
    return 1
  fi

}

################################################################################
# Detect running services in a Docker project
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   List of running services (one per line)
################################################################################

function docker_optimizer_detect_services() {

  local project_path="${1}"
  local compose_file="${project_path}/docker-compose.yml"

  if [[ ! -f ${compose_file} ]]; then
    return 1
  fi

  # List running services
  docker compose -f "${compose_file}" ps --services --filter "status=running" 2>/dev/null

}

################################################################################
# Optimize PHP-FPM in Docker container
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function docker_php_fpm_optimize() {

  local project_path="${1}"
  local compose_file="${project_path}/docker-compose.yml"
  local container_name
  local php_version
  local config_file
  local ram_dedicated

  # Current settings
  local current_pm_max_children
  local current_pm_start_servers
  local current_pm_min_spare_servers
  local current_pm_max_spare_servers
  local current_pm_max_requests
  local current_pm_process_idle_timeout

  # Suggested settings
  local pm_max_children
  local pm_start_servers
  local pm_min_spare_servers
  local pm_max_spare_servers
  local pm_max_requests=500
  local pm_process_idle_timeout="10s"

  log_subsection "PHP-FPM Optimization (Docker)"

  # Get container name
  log_event "debug" "Getting PHP-FPM container name for project: ${project_path}" "false"
  container_name="$(docker_optimizer_get_container_name "${project_path}" "php-fpm")"

  if [[ -z ${container_name} ]]; then
    log_event "warning" "No PHP-FPM container found for ${project_path}" "false"
    display --indent 6 --text "- PHP-FPM container not found" --result "FAIL" --color RED
    return 1
  fi

  log_event "info" "Optimizing PHP-FPM in container: ${container_name}" "false"

  # Detect PHP version inside container
  log_event "debug" "Running: docker exec -i ${container_name} php -r 'echo PHP_MAJOR_VERSION.\".\" .PHP_MINOR_VERSION;'" "false"
  php_version="$(docker exec -i "${container_name}" php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)"

  if [[ -z ${php_version} ]]; then
    log_event "error" "Could not detect PHP version in container" "false"
    display --indent 6 --text "- Detecting PHP version" --result "FAIL" --color RED
    return 1
  fi

  log_event "info" "PHP version detected: ${php_version}" "false"

  # Find PHP docker directory
  local php_docker_dir
  log_event "debug" "Running: find ${project_path} -type d -name php-${php_version}_docker" "false"
  php_docker_dir="$(find "${project_path}" -type d -name "php-${php_version}_docker" | head -n 1)"

  if [[ -z ${php_docker_dir} ]]; then
    log_event "warning" "PHP docker directory not found: php-${php_version}_docker" "false"
    display --indent 6 --text "- PHP docker directory not found" --result "FAIL" --color RED
    return 1
  fi

  log_event "debug" "PHP docker directory found: ${php_docker_dir}" "false"

  # Read current settings from existing config file (if exists)
  config_file="${php_docker_dir}/php-fpm/z-optimised.conf"

  if [[ -f ${config_file} ]]; then
    log_event "info" "Reading current settings from: ${config_file}" "false"
    log_event "debug" "Running: grep -E '^pm\\.max_children' ${config_file}" "false"
    current_pm_max_children="$(grep -E "^pm\.max_children" "${config_file}" 2>/dev/null | awk '{print $3}')"
    current_pm_start_servers="$(grep -E "^pm\.start_servers" "${config_file}" 2>/dev/null | awk '{print $3}')"
    current_pm_min_spare_servers="$(grep -E "^pm\.min_spare_servers" "${config_file}" 2>/dev/null | awk '{print $3}')"
    current_pm_max_spare_servers="$(grep -E "^pm\.max_spare_servers" "${config_file}" 2>/dev/null | awk '{print $3}')"
    current_pm_max_requests="$(grep -E "^pm\.max_requests" "${config_file}" 2>/dev/null | awk '{print $3}')"
    current_pm_process_idle_timeout="$(grep -E "^pm\.process_idle_timeout" "${config_file}" 2>/dev/null | awk '{print $3}')"
    log_event "debug" "Current settings read: pm.max_children=${current_pm_max_children}, pm.start_servers=${current_pm_start_servers}" "false"
  else
    log_event "info" "No existing config file found, reading from container" "false"
    log_event "debug" "Running: docker exec -i ${container_name} grep -E '^pm\\.max_children' /etc/php/${php_version}/fpm/pool.d/www.conf" "false"
    # Try to read from container's default config
    current_pm_max_children="$(docker exec -i "${container_name}" grep -E "^pm\.max_children" /etc/php/${php_version}/fpm/pool.d/www.conf 2>/dev/null | awk '{print $3}' || echo "5")"
    current_pm_start_servers="$(docker exec -i "${container_name}" grep -E "^pm\.start_servers" /etc/php/${php_version}/fpm/pool.d/www.conf 2>/dev/null | awk '{print $3}' || echo "2")"
    current_pm_min_spare_servers="$(docker exec -i "${container_name}" grep -E "^pm\.min_spare_servers" /etc/php/${php_version}/fpm/pool.d/www.conf 2>/dev/null | awk '{print $3}' || echo "1")"
    current_pm_max_spare_servers="$(docker exec -i "${container_name}" grep -E "^pm\.max_spare_servers" /etc/php/${php_version}/fpm/pool.d/www.conf 2>/dev/null | awk '{print $3}' || echo "3")"
    current_pm_max_requests="$(docker exec -i "${container_name}" grep -E "^pm\.max_requests" /etc/php/${php_version}/fpm/pool.d/www.conf 2>/dev/null | awk '{print $3}' || echo "500")"
    current_pm_process_idle_timeout="$(docker exec -i "${container_name}" grep -E "^pm\.process_idle_timeout" /etc/php/${php_version}/fpm/pool.d/www.conf 2>/dev/null | awk '{print $3}' || echo "10s")"
    log_event "debug" "Container settings read: pm.max_children=${current_pm_max_children}, pm.start_servers=${current_pm_start_servers}" "false"
  fi

  # Get container memory limit
  local container_mem_limit
  log_event "debug" "Running: docker inspect ${container_name} --format='{{.HostConfig.Memory}}'" "false"
  container_mem_limit="$(docker inspect "${container_name}" --format='{{.HostConfig.Memory}}' 2>/dev/null)"
  log_event "debug" "Container memory limit: ${container_mem_limit} bytes" "false"

  # Calculate RAM dedicated to PHP
  if [[ -z ${container_mem_limit} || ${container_mem_limit} == "0" ]]; then
    # No limit, use host RAM
    local total_ram
    log_event "debug" "No container memory limit, using host RAM" "false"
    log_event "debug" "Running: grep MemTotal /proc/meminfo | awk '{print \$2}'" "false"
    total_ram="$(grep MemTotal /proc/meminfo | awk '{print $2}' | xargs -I {} echo "scale=1; {}/1024" | bc | cut -d "." -f1)"
    ram_dedicated=$((total_ram - 512))
    log_event "debug" "Total RAM: ${total_ram}MB, Dedicated: ${ram_dedicated}MB (total - 512MB buffer)" "false"
  else
    # Use container limit
    ram_dedicated=$((container_mem_limit / 1024 / 1024 - 512))
    log_event "debug" "Using container limit: Dedicated RAM: ${ram_dedicated}MB (container limit - 512MB buffer)" "false"
  fi

  # Calculate optimal pool settings
  local php_avg_ram=90
  local cpus
  cpus="$(nproc)"
  log_event "debug" "CPU cores detected: ${cpus}" "false"

  pm_max_children=$((ram_dedicated / php_avg_ram))
  pm_start_servers=${cpus}
  pm_min_spare_servers=$((cpus / 2))
  pm_max_spare_servers=${cpus}

  log_event "debug" "Calculated values: pm.max_children=${pm_max_children} (${ram_dedicated}MB / ${php_avg_ram}MB per process)" "false"
  log_event "debug" "Calculated values: pm.start_servers=${pm_start_servers} (CPU cores)" "false"
  log_event "debug" "Calculated values: pm.min_spare_servers=${pm_min_spare_servers} (CPU cores / 2)" "false"
  log_event "debug" "Calculated values: pm.max_spare_servers=${pm_max_spare_servers} (CPU cores)" "false"

  # Ensure minimum values
  [[ ${pm_max_children} -lt 5 ]] && pm_max_children=5
  [[ ${pm_start_servers} -lt 2 ]] && pm_start_servers=2
  [[ ${pm_min_spare_servers} -lt 1 ]] && pm_min_spare_servers=1
  [[ ${pm_max_spare_servers} -lt 2 ]] && pm_max_spare_servers=2

  log_event "debug" "After applying minimums: pm.max_children=${pm_max_children}, pm.start_servers=${pm_start_servers}" "false"

  # Display system information
  display --indent 6 --text "- System Information" --tcolor CYAN
  display --indent 8 --text "Container: ${container_name}"
  display --indent 8 --text "PHP Version: ${php_version}"
  display --indent 8 --text "Dedicated RAM: ${ram_dedicated} MB"
  display --indent 8 --text "CPU Cores: ${cpus}"

  # Display current settings
  echo ""
  display --indent 6 --text "- Current Settings" --tcolor YELLOW
  display --indent 8 --text "pm.max_children: ${current_pm_max_children}"
  display --indent 8 --text "pm.start_servers: ${current_pm_start_servers}"
  display --indent 8 --text "pm.min_spare_servers: ${current_pm_min_spare_servers}"
  display --indent 8 --text "pm.max_spare_servers: ${current_pm_max_spare_servers}"
  display --indent 8 --text "pm.max_requests: ${current_pm_max_requests}"
  display --indent 8 --text "pm.process_idle_timeout: ${current_pm_process_idle_timeout}"

  # Display suggested settings
  echo ""
  display --indent 6 --text "- Suggested Settings" --tcolor GREEN
  display --indent 8 --text "pm.max_children: ${pm_max_children}"
  display --indent 8 --text "pm.start_servers: ${pm_start_servers}"
  display --indent 8 --text "pm.min_spare_servers: ${pm_min_spare_servers}"
  display --indent 8 --text "pm.max_spare_servers: ${pm_max_spare_servers}"
  display --indent 8 --text "pm.max_requests: ${pm_max_requests}"
  display --indent 8 --text "pm.process_idle_timeout: ${pm_process_idle_timeout}"

  # Ask user for confirmation
  echo ""
  whiptail --title "PHP-FPM OPTIMIZATION" --yesno "Do you want to apply the suggested settings?\n\nSelect 'No' to modify values manually before applying." 12 70 3>&1 1>&2 2>&3

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    # User wants to apply suggested settings
    log_event "info" "User accepted suggested settings" "false"
  else
    # User wants to modify settings manually
    log_event "info" "User wants to modify settings manually" "false"

    # Prompt for each value
    pm_max_children="$(whiptail --title "pm.max_children" --inputbox "Enter pm.max_children value:" 10 60 "${pm_max_children}" 3>&1 1>&2 2>&3)"
    [[ -z ${pm_max_children} ]] && pm_max_children=5

    pm_start_servers="$(whiptail --title "pm.start_servers" --inputbox "Enter pm.start_servers value:" 10 60 "${pm_start_servers}" 3>&1 1>&2 2>&3)"
    [[ -z ${pm_start_servers} ]] && pm_start_servers=2

    pm_min_spare_servers="$(whiptail --title "pm.min_spare_servers" --inputbox "Enter pm.min_spare_servers value:" 10 60 "${pm_min_spare_servers}" 3>&1 1>&2 2>&3)"
    [[ -z ${pm_min_spare_servers} ]] && pm_min_spare_servers=1

    pm_max_spare_servers="$(whiptail --title "pm.max_spare_servers" --inputbox "Enter pm.max_spare_servers value:" 10 60 "${pm_max_spare_servers}" 3>&1 1>&2 2>&3)"
    [[ -z ${pm_max_spare_servers} ]] && pm_max_spare_servers=2

    pm_max_requests="$(whiptail --title "pm.max_requests" --inputbox "Enter pm.max_requests value:" 10 60 "${pm_max_requests}" 3>&1 1>&2 2>&3)"
    [[ -z ${pm_max_requests} ]] && pm_max_requests=500

    pm_process_idle_timeout="$(whiptail --title "pm.process_idle_timeout" --inputbox "Enter pm.process_idle_timeout value:" 10 60 "${pm_process_idle_timeout}" 3>&1 1>&2 2>&3)"
    [[ -z ${pm_process_idle_timeout} ]] && pm_process_idle_timeout="10s"

    # Display final values
    echo ""
    display --indent 6 --text "- Final Settings (User Modified)" --tcolor MAGENTA
    display --indent 8 --text "pm.max_children: ${pm_max_children}"
    display --indent 8 --text "pm.start_servers: ${pm_start_servers}"
    display --indent 8 --text "pm.min_spare_servers: ${pm_min_spare_servers}"
    display --indent 8 --text "pm.max_spare_servers: ${pm_max_spare_servers}"
    display --indent 8 --text "pm.max_requests: ${pm_max_requests}"
    display --indent 8 --text "pm.process_idle_timeout: ${pm_process_idle_timeout}"
  fi

  # Generate optimized pool configuration
  config_file="${php_docker_dir}/php-fpm/z-optimised.conf"

  log_event "info" "Generating configuration file: ${config_file}" "false"
  log_event "debug" "Final values to be written: max_children=${pm_max_children}, start_servers=${pm_start_servers}, min_spare=${pm_min_spare_servers}, max_spare=${pm_max_spare_servers}, max_requests=${pm_max_requests}, idle_timeout=${pm_process_idle_timeout}" "false"

  cat > "${config_file}" <<EOF
; Auto-generated by brolit-shell Environment Manager
; Generated: $(date)
; Container: ${container_name}
; PHP Version: ${php_version}

[www]
pm = dynamic
pm.max_children = ${pm_max_children}
pm.start_servers = ${pm_start_servers}
pm.min_spare_servers = ${pm_min_spare_servers}
pm.max_spare_servers = ${pm_max_spare_servers}
pm.max_requests = ${pm_max_requests}
pm.process_idle_timeout = ${pm_process_idle_timeout}
EOF

  log_event "info" "Configuration written to: ${config_file}" "false"
  display --indent 6 --text "- Writing configuration" --result "DONE" --color GREEN

  # Check if volume mount exists in docker-compose.yml
  log_event "debug" "Checking if z-optimised.conf is mounted in docker-compose.yml" "false"
  if ! grep -q "z-optimised.conf" "${compose_file}"; then
    log_event "warning" "z-optimised.conf not mounted in docker-compose.yml" "false"
    display --indent 6 --text "- Volume mount missing" --result "WARNING" --color YELLOW
    display --indent 8 --text "Add this to php-fpm volumes:" --tcolor YELLOW
    display --indent 8 --text "- ./php-${php_version}_docker/php-fpm/z-optimised.conf:/etc/php/${php_version}/fpm/pool.d/z-optimised.conf" --tcolor YELLOW
    return 1
  fi

  log_event "debug" "Volume mount verified in docker-compose.yml" "false"

  # Enable OPcache
  log_event "debug" "Enabling OPcache configuration" "false"
  docker_php_opcode_config "${project_path}" "${php_version}"

  # Reload PHP-FPM gracefully (USR2 signal)
  log_event "info" "Reloading PHP-FPM in container" "false"
  log_event "debug" "Running: docker compose -f ${compose_file} exec -T php-fpm kill -USR2 1" "false"
  docker compose -f "${compose_file}" exec -T php-fpm kill -USR2 1 2>/dev/null

  if [[ $? -eq 0 ]]; then
    display --indent 6 --text "- Reloading PHP-FPM" --result "DONE" --color GREEN
    log_event "info" "PHP-FPM reloaded successfully" "false"

    # Verify settings were applied - read from file
    echo ""
    display --indent 6 --text "- Verifying Applied Settings" --tcolor CYAN
    log_event "info" "Verifying settings were applied correctly" "false"
    log_event "debug" "Running: grep -E '^pm\\.max_children' ${config_file}" "false"

    local verified_pm_max_children
    local verified_pm_start_servers
    local verified_pm_min_spare_servers
    local verified_pm_max_spare_servers
    local verified_pm_max_requests
    local verified_pm_process_idle_timeout
    local verification_failed=false

    verified_pm_max_children="$(grep -E "^pm\.max_children" "${config_file}" 2>/dev/null | awk '{print $3}')"
    verified_pm_start_servers="$(grep -E "^pm\.start_servers" "${config_file}" 2>/dev/null | awk '{print $3}')"
    verified_pm_min_spare_servers="$(grep -E "^pm\.min_spare_servers" "${config_file}" 2>/dev/null | awk '{print $3}')"
    verified_pm_max_spare_servers="$(grep -E "^pm\.max_spare_servers" "${config_file}" 2>/dev/null | awk '{print $3}')"
    verified_pm_max_requests="$(grep -E "^pm\.max_requests" "${config_file}" 2>/dev/null | awk '{print $3}')"
    verified_pm_process_idle_timeout="$(grep -E "^pm\.process_idle_timeout" "${config_file}" 2>/dev/null | awk '{print $3}')"

    log_event "debug" "Verified values: pm.max_children=${verified_pm_max_children}, pm.start_servers=${verified_pm_start_servers}" "false"

    # Check each value
    if [[ ${verified_pm_max_children} -eq ${pm_max_children} ]]; then
      display --indent 8 --text "pm.max_children: ${verified_pm_max_children}" --result "✓" --color GREEN
    else
      display --indent 8 --text "pm.max_children: ${verified_pm_max_children} (expected: ${pm_max_children})" --result "✗" --color RED
      log_event "error" "Verification failed: pm.max_children = ${verified_pm_max_children}, expected ${pm_max_children}" "false"
      verification_failed=true
    fi

    if [[ ${verified_pm_start_servers} -eq ${pm_start_servers} ]]; then
      display --indent 8 --text "pm.start_servers: ${verified_pm_start_servers}" --result "✓" --color GREEN
    else
      display --indent 8 --text "pm.start_servers: ${verified_pm_start_servers} (expected: ${pm_start_servers})" --result "✗" --color RED
      log_event "error" "Verification failed: pm.start_servers = ${verified_pm_start_servers}, expected ${pm_start_servers}" "false"
      verification_failed=true
    fi

    if [[ ${verified_pm_min_spare_servers} -eq ${pm_min_spare_servers} ]]; then
      display --indent 8 --text "pm.min_spare_servers: ${verified_pm_min_spare_servers}" --result "✓" --color GREEN
    else
      display --indent 8 --text "pm.min_spare_servers: ${verified_pm_min_spare_servers} (expected: ${pm_min_spare_servers})" --result "✗" --color RED
      log_event "error" "Verification failed: pm.min_spare_servers = ${verified_pm_min_spare_servers}, expected ${pm_min_spare_servers}" "false"
      verification_failed=true
    fi

    if [[ ${verified_pm_max_spare_servers} -eq ${pm_max_spare_servers} ]]; then
      display --indent 8 --text "pm.max_spare_servers: ${verified_pm_max_spare_servers}" --result "✓" --color GREEN
    else
      display --indent 8 --text "pm.max_spare_servers: ${verified_pm_max_spare_servers} (expected: ${pm_max_spare_servers})" --result "✗" --color RED
      log_event "error" "Verification failed: pm.max_spare_servers = ${verified_pm_max_spare_servers}, expected ${pm_max_spare_servers}" "false"
      verification_failed=true
    fi

    if [[ ${verified_pm_max_requests} -eq ${pm_max_requests} ]]; then
      display --indent 8 --text "pm.max_requests: ${verified_pm_max_requests}" --result "✓" --color GREEN
    else
      display --indent 8 --text "pm.max_requests: ${verified_pm_max_requests} (expected: ${pm_max_requests})" --result "✗" --color RED
      log_event "error" "Verification failed: pm.max_requests = ${verified_pm_max_requests}, expected ${pm_max_requests}" "false"
      verification_failed=true
    fi

    if [[ "${verified_pm_process_idle_timeout}" == "${pm_process_idle_timeout}" ]]; then
      display --indent 8 --text "pm.process_idle_timeout: ${verified_pm_process_idle_timeout}" --result "✓" --color GREEN
    else
      display --indent 8 --text "pm.process_idle_timeout: ${verified_pm_process_idle_timeout} (expected: ${pm_process_idle_timeout})" --result "✗" --color RED
      log_event "error" "Verification failed: pm.process_idle_timeout = ${verified_pm_process_idle_timeout}, expected ${pm_process_idle_timeout}" "false"
      verification_failed=true
    fi

    # Log summary of changes
    echo ""
    display --indent 6 --text "- Optimization Summary" --tcolor GREEN
    log_event "info" "=== PHP-FPM Optimization Summary ===" "false"
    log_event "info" "Container: ${container_name}" "false"
    log_event "info" "PHP Version: ${php_version}" "false"
    log_event "info" "Config file: ${config_file}" "false"
    log_event "info" "Changes applied:" "false"
    log_event "info" "  - pm.max_children: ${current_pm_max_children} → ${pm_max_children}" "false"
    log_event "info" "  - pm.start_servers: ${current_pm_start_servers} → ${pm_start_servers}" "false"
    log_event "info" "  - pm.min_spare_servers: ${current_pm_min_spare_servers} → ${pm_min_spare_servers}" "false"
    log_event "info" "  - pm.max_spare_servers: ${current_pm_max_spare_servers} → ${pm_max_spare_servers}" "false"
    log_event "info" "  - pm.max_requests: ${current_pm_max_requests} → ${pm_max_requests}" "false"
    log_event "info" "  - pm.process_idle_timeout: ${current_pm_process_idle_timeout} → ${pm_process_idle_timeout}" "false"

    if [[ ${verification_failed} == true ]]; then
      log_event "warning" "Settings verification completed with errors" "false"
      display --indent 8 --text "Settings applied but verification found discrepancies" --tcolor YELLOW
    else
      log_event "info" "PHP-FPM optimization completed and verified successfully" "false"
      display --indent 8 --text "All settings applied, verified, and PHP-FPM reloaded" --tcolor GREEN
    fi
  else
    display --indent 6 --text "- Reloading PHP-FPM" --result "FAIL" --color RED
    log_event "error" "Failed to reload PHP-FPM with command: docker compose -f ${compose_file} exec -T php-fpm kill -USR2 1" "false"
    return 1
  fi

  return 0

}

################################################################################
# Configure OPcache for Docker PHP-FPM
#
# Arguments:
#   ${1} = ${project_path}
#   ${2} = ${php_version}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function docker_php_opcode_config() {

  local project_path="${1}"
  local php_version="${2}"
  local opcache_file

  # Find opcache configuration file
  opcache_file="$(find "${project_path}" -path "*/php-${php_version}_docker/php-fpm/opcache-prod.ini" | head -n 1)"

  if [[ -z ${opcache_file} ]]; then
    log_event "warning" "opcache-prod.ini not found for PHP ${php_version}" "false"
    return 1
  fi

  # Enable OPcache
  sed -i 's/^opcache.enable=0/opcache.enable=1/' "${opcache_file}"
  sed -i 's/^opcache.enable_cli=0/opcache.enable_cli=1/' "${opcache_file}"

  # Increase memory consumption
  sed -i 's/^opcache.memory_consumption=.*/opcache.memory_consumption=128/' "${opcache_file}"

  # Increase max accelerated files
  sed -i 's/^opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/' "${opcache_file}"

  log_event "info" "OPcache enabled in: ${opcache_file}" "false"
  display --indent 6 --text "- Enabling OPcache" --result "DONE" --color GREEN

  return 0

}

################################################################################
# Optimize Nginx in Docker container
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function docker_nginx_optimize() {

  local project_path="${1}"
  local compose_file="${project_path}/docker-compose.yml"
  local container_name
  local nginx_conf_file
  local cpus

  # Current settings
  local current_worker_processes
  local current_worker_connections
  local current_fastcgi_buffers
  local current_fastcgi_buffer_size

  # Suggested settings
  local worker_processes
  local worker_connections=2048
  local fastcgi_buffers="32 32k"
  local fastcgi_buffer_size="64k"

  log_subsection "Nginx Optimization (Docker)"

  # Get container name with debug logging
  log_event "debug" "Getting Nginx container name for project: ${project_path}" "false"
  container_name="$(docker_optimizer_get_container_name "${project_path}" "webserver")"
  log_event "debug" "Container name: ${container_name}" "false"

  if [[ -z ${container_name} ]]; then
    log_event "warning" "No Nginx container found for ${project_path}" "false"
    display --indent 6 --text "- Nginx container not found" --result "FAIL" --color RED
    return 1
  fi

  log_event "info" "Optimizing Nginx in container: ${container_name}" "false"

  # Find nginx.conf file with debug logging
  log_event "debug" "Running: find ${project_path} -path '*/nginx/nginx.conf'" "false"
  nginx_conf_file="$(find "${project_path}" -path "*/nginx/nginx.conf" | head -n 1)"
  log_event "debug" "Found nginx.conf at: ${nginx_conf_file}" "false"

  if [[ -z ${nginx_conf_file} ]]; then
    log_event "warning" "nginx.conf not found in ${project_path}" "false"
    display --indent 6 --text "- nginx.conf not found" --result "FAIL" --color RED
    return 1
  fi

  # Get CPU count
  log_event "debug" "Running: nproc" "false"
  cpus="$(nproc)"
  worker_processes="${cpus}"
  log_event "debug" "CPU cores detected: ${cpus}" "false"

  # Read current settings from nginx.conf
  log_event "debug" "Reading current settings from: ${nginx_conf_file}" "false"

  log_event "debug" "Running: grep -E '^[[:space:]]*worker_processes' ${nginx_conf_file}" "false"
  current_worker_processes="$(grep -E "^[[:space:]]*worker_processes" "${nginx_conf_file}" 2>/dev/null | awk '{print $2}' | tr -d ';' || echo "auto")"

  log_event "debug" "Running: grep -E 'worker_connections' ${nginx_conf_file}" "false"
  current_worker_connections="$(grep -E "worker_connections" "${nginx_conf_file}" 2>/dev/null | awk '{print $2}' | tr -d ';' || echo "1024")"

  log_event "debug" "Running: grep -E 'fastcgi_buffers' ${nginx_conf_file}" "false"
  current_fastcgi_buffers="$(grep -E "fastcgi_buffers" "${nginx_conf_file}" 2>/dev/null | awk '{print $2" "$3}' | tr -d ';' || echo "8 8k")"

  log_event "debug" "Running: grep -E 'fastcgi_buffer_size' ${nginx_conf_file}" "false"
  current_fastcgi_buffer_size="$(grep -E "fastcgi_buffer_size" "${nginx_conf_file}" 2>/dev/null | awk '{print $2}' | tr -d ';' || echo "8k")"

  log_event "debug" "Current settings read: worker_processes=${current_worker_processes}, worker_connections=${current_worker_connections}, fastcgi_buffers=${current_fastcgi_buffers}, fastcgi_buffer_size=${current_fastcgi_buffer_size}" "false"

  # Display system information (CYAN)
  display --indent 6 --text "- System Information" --tcolor CYAN
  display --indent 8 --text "Container: ${container_name}"
  display --indent 8 --text "CPU Cores: ${cpus}"
  display --indent 8 --text "Config file: ${nginx_conf_file}"

  # Display current settings (YELLOW)
  echo ""
  display --indent 6 --text "- Current Settings" --tcolor YELLOW
  display --indent 8 --text "worker_processes: ${current_worker_processes}"
  display --indent 8 --text "worker_connections: ${current_worker_connections}"
  display --indent 8 --text "fastcgi_buffers: ${current_fastcgi_buffers}"
  display --indent 8 --text "fastcgi_buffer_size: ${current_fastcgi_buffer_size}"

  # Display suggested settings (GREEN)
  echo ""
  display --indent 6 --text "- Suggested Settings" --tcolor GREEN
  display --indent 8 --text "worker_processes: ${worker_processes}"
  display --indent 8 --text "worker_connections: ${worker_connections}"
  display --indent 8 --text "fastcgi_buffers: ${fastcgi_buffers}"
  display --indent 8 --text "fastcgi_buffer_size: ${fastcgi_buffer_size}"

  # Ask user for confirmation
  echo ""
  whiptail --title "NGINX OPTIMIZATION" --yesno "Do you want to apply the suggested settings?\n\nSelect 'No' to modify values manually before applying." 12 70 3>&1 1>&2 2>&3

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    log_event "info" "User accepted suggested settings" "false"
  else
    log_event "info" "User wants to modify settings manually" "false"

    # Prompt for each value
    worker_processes="$(whiptail --title "worker_processes" --inputbox "Enter worker_processes value:" 10 60 "${worker_processes}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    [[ ${exitstatus} -ne 0 ]] && worker_processes="${cpus}"
    log_event "debug" "User modified worker_processes to: ${worker_processes}" "false"

    worker_connections="$(whiptail --title "worker_connections" --inputbox "Enter worker_connections value:" 10 60 "${worker_connections}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    [[ ${exitstatus} -ne 0 ]] && worker_connections="2048"
    log_event "debug" "User modified worker_connections to: ${worker_connections}" "false"

    fastcgi_buffers="$(whiptail --title "fastcgi_buffers" --inputbox "Enter fastcgi_buffers value (e.g., '32 32k'):" 10 60 "${fastcgi_buffers}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    [[ ${exitstatus} -ne 0 ]] && fastcgi_buffers="32 32k"
    log_event "debug" "User modified fastcgi_buffers to: ${fastcgi_buffers}" "false"

    fastcgi_buffer_size="$(whiptail --title "fastcgi_buffer_size" --inputbox "Enter fastcgi_buffer_size value:" 10 60 "${fastcgi_buffer_size}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    [[ ${exitstatus} -ne 0 ]] && fastcgi_buffer_size="64k"
    log_event "debug" "User modified fastcgi_buffer_size to: ${fastcgi_buffer_size}" "false"

    # Display final modified values (MAGENTA)
    echo ""
    display --indent 6 --text "- Final Settings (User Modified)" --tcolor MAGENTA
    display --indent 8 --text "worker_processes: ${worker_processes}"
    display --indent 8 --text "worker_connections: ${worker_connections}"
    display --indent 8 --text "fastcgi_buffers: ${fastcgi_buffers}"
    display --indent 8 --text "fastcgi_buffer_size: ${fastcgi_buffer_size}"
  fi

  # Apply configuration changes with logging
  log_event "info" "Applying Nginx configuration changes" "false"
  log_event "debug" "Final values to be written: worker_processes=${worker_processes}, worker_connections=${worker_connections}, fastcgi_buffers=${fastcgi_buffers}, fastcgi_buffer_size=${fastcgi_buffer_size}" "false"

  # Update worker_processes
  log_event "debug" "Checking if worker_processes exists in config" "false"
  if ! grep -q "worker_processes" "${nginx_conf_file}"; then
    log_event "debug" "Running: sed -i '1i worker_processes ${worker_processes};' ${nginx_conf_file}" "false"
    sed -i "1i worker_processes ${worker_processes};" "${nginx_conf_file}"
    log_event "info" "Added worker_processes to nginx.conf" "false"
  else
    log_event "debug" "Running: sed -i 's/worker_processes.*/worker_processes ${worker_processes};/' ${nginx_conf_file}" "false"
    sed -i "s/worker_processes.*/worker_processes ${worker_processes};/" "${nginx_conf_file}"
    log_event "info" "Updated worker_processes in nginx.conf" "false"
  fi

  # Update worker_connections
  log_event "debug" "Checking if worker_connections exists in config" "false"
  if grep -q "worker_connections" "${nginx_conf_file}"; then
    log_event "debug" "Running: sed -i 's/worker_connections.*/worker_connections ${worker_connections};/' ${nginx_conf_file}" "false"
    sed -i "s/worker_connections.*/worker_connections ${worker_connections};/" "${nginx_conf_file}"
    log_event "info" "Updated worker_connections in nginx.conf" "false"
  fi

  # Update fastcgi_buffers
  log_event "debug" "Checking if fastcgi_buffers exists in config" "false"
  if grep -q "fastcgi_buffers" "${nginx_conf_file}"; then
    log_event "debug" "Running: sed -i 's/fastcgi_buffers.*/fastcgi_buffers ${fastcgi_buffers};/' ${nginx_conf_file}" "false"
    sed -i "s/fastcgi_buffers.*/fastcgi_buffers ${fastcgi_buffers};/" "${nginx_conf_file}"
    log_event "info" "Updated fastcgi_buffers in nginx.conf" "false"
  fi

  # Update fastcgi_buffer_size
  log_event "debug" "Checking if fastcgi_buffer_size exists in config" "false"
  if grep -q "fastcgi_buffer_size" "${nginx_conf_file}"; then
    log_event "debug" "Running: sed -i 's/fastcgi_buffer_size.*/fastcgi_buffer_size ${fastcgi_buffer_size};/' ${nginx_conf_file}" "false"
    sed -i "s/fastcgi_buffer_size.*/fastcgi_buffer_size ${fastcgi_buffer_size};/" "${nginx_conf_file}"
    log_event "info" "Updated fastcgi_buffer_size in nginx.conf" "false"
  fi

  display --indent 6 --text "- Writing configuration" --result "DONE" --color GREEN

  # Test nginx configuration
  log_event "info" "Testing Nginx configuration" "false"
  log_event "debug" "Running: docker compose -f ${compose_file} exec -T webserver nginx -t" "false"
  if docker compose -f "${compose_file}" exec -T webserver nginx -t 2>&1 | grep -q "successful"; then
    display --indent 6 --text "- Testing configuration" --result "DONE" --color GREEN
    log_event "info" "Nginx configuration test successful" "false"
  else
    display --indent 6 --text "- Testing configuration" --result "FAIL" --color RED
    log_event "error" "Nginx configuration test failed" "false"
    return 1
  fi

  # Reload Nginx
  log_event "info" "Reloading Nginx in container" "false"
  log_event "debug" "Running: docker compose -f ${compose_file} exec -T webserver nginx -s reload" "false"
  docker compose -f "${compose_file}" exec -T webserver nginx -s reload 2>/dev/null

  if [[ $? -eq 0 ]]; then
    display --indent 6 --text "- Reloading Nginx" --result "DONE" --color GREEN
    log_event "info" "Nginx reloaded successfully" "false"

    # Verify settings were applied - read from file
    echo ""
    display --indent 6 --text "- Verifying Applied Settings" --tcolor CYAN
    log_event "info" "Verifying settings were applied correctly" "false"
    log_event "debug" "Running: grep -E '^[[:space:]]*worker_processes' ${nginx_conf_file}" "false"

    local verified_worker_processes
    local verified_worker_connections
    local verified_fastcgi_buffers
    local verified_fastcgi_buffer_size
    local verification_failed=false

    verified_worker_processes="$(grep -E "^[[:space:]]*worker_processes" "${nginx_conf_file}" 2>/dev/null | awk '{print $2}' | tr -d ';')"
    verified_worker_connections="$(grep -E "worker_connections" "${nginx_conf_file}" 2>/dev/null | awk '{print $2}' | tr -d ';')"
    verified_fastcgi_buffers="$(grep -E "fastcgi_buffers" "${nginx_conf_file}" 2>/dev/null | awk '{print $2" "$3}' | tr -d ';')"
    verified_fastcgi_buffer_size="$(grep -E "fastcgi_buffer_size" "${nginx_conf_file}" 2>/dev/null | awk '{print $2}' | tr -d ';')"

    log_event "debug" "Verified values: worker_processes=${verified_worker_processes}, worker_connections=${verified_worker_connections}" "false"

    # Check each value
    if [[ ${verified_worker_processes} -eq ${worker_processes} ]]; then
      display --indent 8 --text "worker_processes: ${verified_worker_processes}" --result "✓" --color GREEN
    else
      display --indent 8 --text "worker_processes: ${verified_worker_processes} (expected: ${worker_processes})" --result "✗" --color RED
      log_event "error" "Verification failed: worker_processes = ${verified_worker_processes}, expected ${worker_processes}" "false"
      verification_failed=true
    fi

    if [[ ${verified_worker_connections} -eq ${worker_connections} ]]; then
      display --indent 8 --text "worker_connections: ${verified_worker_connections}" --result "✓" --color GREEN
    else
      display --indent 8 --text "worker_connections: ${verified_worker_connections} (expected: ${worker_connections})" --result "✗" --color RED
      log_event "error" "Verification failed: worker_connections = ${verified_worker_connections}, expected ${worker_connections}" "false"
      verification_failed=true
    fi

    if [[ "${verified_fastcgi_buffers}" == "${fastcgi_buffers}" ]]; then
      display --indent 8 --text "fastcgi_buffers: ${verified_fastcgi_buffers}" --result "✓" --color GREEN
    else
      display --indent 8 --text "fastcgi_buffers: ${verified_fastcgi_buffers} (expected: ${fastcgi_buffers})" --result "✗" --color RED
      log_event "error" "Verification failed: fastcgi_buffers = ${verified_fastcgi_buffers}, expected ${fastcgi_buffers}" "false"
      verification_failed=true
    fi

    if [[ "${verified_fastcgi_buffer_size}" == "${fastcgi_buffer_size}" ]]; then
      display --indent 8 --text "fastcgi_buffer_size: ${verified_fastcgi_buffer_size}" --result "✓" --color GREEN
    else
      display --indent 8 --text "fastcgi_buffer_size: ${verified_fastcgi_buffer_size} (expected: ${fastcgi_buffer_size})" --result "✗" --color RED
      log_event "error" "Verification failed: fastcgi_buffer_size = ${verified_fastcgi_buffer_size}, expected ${fastcgi_buffer_size}" "false"
      verification_failed=true
    fi

    # Log complete summary of changes
    echo ""
    display --indent 6 --text "- Optimization Summary" --tcolor GREEN
    log_event "info" "=== Nginx Optimization Summary ===" "false"
    log_event "info" "Container: ${container_name}" "false"
    log_event "info" "Config file: ${nginx_conf_file}" "false"
    log_event "info" "Changes applied:" "false"
    log_event "info" "  - worker_processes: ${current_worker_processes} → ${worker_processes}" "false"
    log_event "info" "  - worker_connections: ${current_worker_connections} → ${worker_connections}" "false"
    log_event "info" "  - fastcgi_buffers: ${current_fastcgi_buffers} → ${fastcgi_buffers}" "false"
    log_event "info" "  - fastcgi_buffer_size: ${current_fastcgi_buffer_size} → ${fastcgi_buffer_size}" "false"

    if [[ ${verification_failed} == true ]]; then
      log_event "warning" "Settings verification completed with errors" "false"
      display --indent 8 --text "Settings applied but verification found discrepancies" --tcolor YELLOW
    else
      log_event "info" "Nginx optimization completed and verified successfully" "false"
      display --indent 8 --text "All settings applied, verified, and Nginx reloaded" --tcolor GREEN
    fi
  else
    display --indent 6 --text "- Reloading Nginx" --result "FAIL" --color RED
    log_event "error" "Failed to reload Nginx" "false"
    return 1
  fi

  return 0

}

################################################################################
# Optimize MySQL in Docker container
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function docker_mysql_optimize() {

  local project_path="${1}"
  local compose_file="${project_path}/docker-compose.yml"
  local container_name
  local mysql_conf_file
  local mysql_conf_dir

  # Current settings
  local current_innodb_buffer_pool_size
  local current_innodb_log_file_size
  local current_max_connections
  local current_tmp_table_size

  # Suggested settings
  local innodb_buffer_pool_size
  local innodb_log_file_size=256
  local max_connections=150
  local tmp_table_size=64

  log_subsection "MySQL Optimization (Docker)"

  # Get container name with debug logging
  log_event "debug" "Getting MySQL container name for project: ${project_path}" "false"
  container_name="$(docker_optimizer_get_container_name "${project_path}" "mysql")"
  log_event "debug" "Container name: ${container_name}" "false"

  if [[ -z ${container_name} ]]; then
    log_event "warning" "No MySQL container found for ${project_path}" "false"
    display --indent 6 --text "- MySQL container not found" --result "FAIL" --color RED
    return 1
  fi

  log_event "info" "Optimizing MySQL in container: ${container_name}" "false"

  # Get container memory limit with debug logging
  log_event "debug" "Running: docker inspect ${container_name} --format='{{.HostConfig.Memory}}'" "false"
  local container_mem_limit
  container_mem_limit="$(docker inspect "${container_name}" --format='{{.HostConfig.Memory}}' 2>/dev/null)"
  log_event "debug" "Container memory limit: ${container_mem_limit} bytes" "false"

  # Calculate innodb_buffer_pool_size (50% of RAM)
  if [[ -z ${container_mem_limit} || ${container_mem_limit} == "0" ]]; then
    # No limit, use host RAM
    log_event "debug" "Running: grep MemTotal /proc/meminfo" "false"
    local total_ram
    total_ram="$(grep MemTotal /proc/meminfo | awk '{print $2}' | xargs -I {} echo "scale=1; {}/1024" | bc | cut -d "." -f1)"
    innodb_buffer_pool_size=$((total_ram / 2))
    log_event "debug" "Using host RAM: ${total_ram}MB, innodb_buffer_pool_size: ${innodb_buffer_pool_size}MB (50%)" "false"
  else
    innodb_buffer_pool_size=$((container_mem_limit / 1024 / 1024 / 2))
    log_event "debug" "Using container limit: innodb_buffer_pool_size: ${innodb_buffer_pool_size}MB (50% of container limit)" "false"
  fi

  # Create MySQL configuration directory
  mysql_conf_dir="${project_path}/.mysql_data/conf.d"
  log_event "debug" "Running: mkdir -p ${mysql_conf_dir}" "false"
  mkdir -p "${mysql_conf_dir}"

  mysql_conf_file="${mysql_conf_dir}/60-tuning.cnf"
  log_event "debug" "MySQL config file: ${mysql_conf_file}" "false"

  # Read current settings if config file exists
  if [[ -f ${mysql_conf_file} ]]; then
    log_event "info" "Reading current settings from: ${mysql_conf_file}" "false"

    log_event "debug" "Running: grep 'innodb_buffer_pool_size' ${mysql_conf_file}" "false"
    current_innodb_buffer_pool_size="$(grep "innodb_buffer_pool_size" "${mysql_conf_file}" 2>/dev/null | awk '{print $3}' | tr -d 'M' || echo "128")"

    log_event "debug" "Running: grep 'innodb_log_file_size' ${mysql_conf_file}" "false"
    current_innodb_log_file_size="$(grep "innodb_log_file_size" "${mysql_conf_file}" 2>/dev/null | awk '{print $3}' | tr -d 'M' || echo "48")"

    log_event "debug" "Running: grep 'max_connections' ${mysql_conf_file}" "false"
    current_max_connections="$(grep "max_connections" "${mysql_conf_file}" 2>/dev/null | awk '{print $3}' || echo "151")"

    log_event "debug" "Running: grep 'tmp_table_size' ${mysql_conf_file}" "false"
    current_tmp_table_size="$(grep "tmp_table_size" "${mysql_conf_file}" 2>/dev/null | awk '{print $3}' | tr -d 'M' || echo "16")"

    log_event "debug" "Current settings read: innodb_buffer_pool_size=${current_innodb_buffer_pool_size}M, innodb_log_file_size=${current_innodb_log_file_size}M, max_connections=${current_max_connections}, tmp_table_size=${current_tmp_table_size}M" "false"
  else
    log_event "info" "No existing config file found, using MySQL defaults" "false"
    current_innodb_buffer_pool_size="128"
    current_innodb_log_file_size="48"
    current_max_connections="151"
    current_tmp_table_size="16"
    log_event "debug" "Using default values: innodb_buffer_pool_size=128M, innodb_log_file_size=48M, max_connections=151, tmp_table_size=16M" "false"
  fi

  # Display system information (CYAN)
  display --indent 6 --text "- System Information" --tcolor CYAN
  display --indent 8 --text "Container: ${container_name}"
  if [[ -z ${container_mem_limit} || ${container_mem_limit} == "0" ]]; then
    display --indent 8 --text "Memory: No limit (using host RAM)"
  else
    display --indent 8 --text "Memory: $((container_mem_limit / 1024 / 1024))MB (container limit)"
  fi
  display --indent 8 --text "Config file: ${mysql_conf_file}"

  # Display current settings (YELLOW)
  echo ""
  display --indent 6 --text "- Current Settings" --tcolor YELLOW
  display --indent 8 --text "innodb_buffer_pool_size: ${current_innodb_buffer_pool_size}M"
  display --indent 8 --text "innodb_log_file_size: ${current_innodb_log_file_size}M"
  display --indent 8 --text "max_connections: ${current_max_connections}"
  display --indent 8 --text "tmp_table_size: ${current_tmp_table_size}M"

  # Display suggested settings (GREEN)
  echo ""
  display --indent 6 --text "- Suggested Settings" --tcolor GREEN
  display --indent 8 --text "innodb_buffer_pool_size: ${innodb_buffer_pool_size}M"
  display --indent 8 --text "innodb_log_file_size: ${innodb_log_file_size}M"
  display --indent 8 --text "max_connections: ${max_connections}"
  display --indent 8 --text "tmp_table_size: ${tmp_table_size}M"

  # Ask user for confirmation
  echo ""
  whiptail --title "MYSQL OPTIMIZATION" --yesno "Do you want to apply the suggested settings?\n\nSelect 'No' to modify values manually before applying." 12 70 3>&1 1>&2 2>&3

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    log_event "info" "User accepted suggested settings" "false"
  else
    log_event "info" "User wants to modify settings manually" "false"

    # Prompt for each value
    innodb_buffer_pool_size="$(whiptail --title "innodb_buffer_pool_size" --inputbox "Enter innodb_buffer_pool_size value (MB):" 10 60 "${innodb_buffer_pool_size}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    [[ ${exitstatus} -ne 0 ]] && innodb_buffer_pool_size=$((container_mem_limit / 1024 / 1024 / 2))
    log_event "debug" "User modified innodb_buffer_pool_size to: ${innodb_buffer_pool_size}M" "false"

    innodb_log_file_size="$(whiptail --title "innodb_log_file_size" --inputbox "Enter innodb_log_file_size value (MB):" 10 60 "${innodb_log_file_size}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    [[ ${exitstatus} -ne 0 ]] && innodb_log_file_size="256"
    log_event "debug" "User modified innodb_log_file_size to: ${innodb_log_file_size}M" "false"

    max_connections="$(whiptail --title "max_connections" --inputbox "Enter max_connections value:" 10 60 "${max_connections}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    [[ ${exitstatus} -ne 0 ]] && max_connections="150"
    log_event "debug" "User modified max_connections to: ${max_connections}" "false"

    tmp_table_size="$(whiptail --title "tmp_table_size" --inputbox "Enter tmp_table_size value (MB):" 10 60 "${tmp_table_size}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    [[ ${exitstatus} -ne 0 ]] && tmp_table_size="64"
    log_event "debug" "User modified tmp_table_size to: ${tmp_table_size}M" "false"

    # Display final modified values (MAGENTA)
    echo ""
    display --indent 6 --text "- Final Settings (User Modified)" --tcolor MAGENTA
    display --indent 8 --text "innodb_buffer_pool_size: ${innodb_buffer_pool_size}M"
    display --indent 8 --text "innodb_log_file_size: ${innodb_log_file_size}M"
    display --indent 8 --text "max_connections: ${max_connections}"
    display --indent 8 --text "tmp_table_size: ${tmp_table_size}M"
  fi

  # Generate optimized configuration with logging
  log_event "info" "Generating MySQL configuration file: ${mysql_conf_file}" "false"
  log_event "debug" "Final values to be written: innodb_buffer_pool_size=${innodb_buffer_pool_size}M, innodb_log_file_size=${innodb_log_file_size}M, max_connections=${max_connections}, tmp_table_size=${tmp_table_size}M" "false"

  cat > "${mysql_conf_file}" <<EOF
# Auto-generated by brolit-shell Environment Manager
# Generated: $(date)
# Container: ${container_name}

[mysqld]
innodb_buffer_pool_size = ${innodb_buffer_pool_size}M
innodb_log_file_size = ${innodb_log_file_size}M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT

# Query cache (disabled in MySQL 8.0+)
query_cache_type = 0
query_cache_size = 0

# Connections
max_connections = ${max_connections}
max_connect_errors = 10000

# Buffers
join_buffer_size = 2M
sort_buffer_size = 2M
read_buffer_size = 1M
read_rnd_buffer_size = 4M

# Temporary tables
tmp_table_size = ${tmp_table_size}M
max_heap_table_size = ${tmp_table_size}M

# Logging
slow_query_log = 1
long_query_time = 2
EOF

  log_event "info" "Configuration written to: ${mysql_conf_file}" "false"
  display --indent 6 --text "- Writing configuration" --result "DONE" --color GREEN

  # Check if volume mount exists in docker-compose.yml with logging
  log_event "debug" "Running: grep '60-tuning.cnf' ${compose_file}" "false"
  if ! grep -q "60-tuning.cnf" "${compose_file}"; then
    log_event "warning" "60-tuning.cnf not mounted in docker-compose.yml" "false"
    display --indent 6 --text "- Volume mount exists" --result "WARNING" --color YELLOW
    display --indent 8 --text "Add this to mysql volumes:" --tcolor YELLOW
    display --indent 8 --text "- ./.mysql_data/conf.d/60-tuning.cnf:/etc/mysql/conf.d/60-tuning.cnf:ro" --tcolor YELLOW
  else
    log_event "info" "Volume mount verified in docker-compose.yml" "false"
    display --indent 6 --text "- Volume mount exists" --result "DONE" --color GREEN
  fi

  # Restart MySQL container (required for most settings)
  echo ""
  whiptail --title "RESTART MYSQL" --yesno "MySQL requires restart to apply settings.\n\nThis will cause brief downtime (~5-10 seconds).\n\nContinue?" 12 60 3>&1 1>&2 2>&3

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    log_event "info" "User confirmed MySQL restart" "false"
    log_event "info" "Restarting MySQL container" "false"
    log_event "debug" "Running: docker compose -f ${compose_file} restart mysql" "false"
    display --indent 6 --text "- Restarting MySQL" --result "WORKING" --color YELLOW

    docker compose -f "${compose_file}" restart mysql 2>/dev/null

    # Wait for MySQL to be ready
    log_event "info" "Waiting for MySQL to be ready..." "false"
    sleep 5
    local retries=10
    while [[ ${retries} -gt 0 ]]; do
      log_event "debug" "Running: docker compose -f ${compose_file} exec -T mysql mysqladmin ping -h localhost (retry ${retries})" "false"
      if docker compose -f "${compose_file}" exec -T mysql mysqladmin ping -h localhost 2>/dev/null | grep -q "mysqld is alive"; then
        display --indent 6 --text "- MySQL ready" --result "DONE" --color GREEN
        log_event "info" "MySQL is ready" "false"

        # Verify settings were applied - read from container
        echo ""
        display --indent 6 --text "- Verifying Applied Settings" --tcolor CYAN
        log_event "info" "Verifying settings were applied correctly" "false"
        log_event "debug" "Running: docker compose -f ${compose_file} exec -T mysql mysql -e \"SHOW VARIABLES LIKE 'innodb_buffer_pool_size';\"" "false"

        local verified_innodb_buffer_pool_size
        local verified_innodb_log_file_size
        local verified_max_connections
        local verified_tmp_table_size
        local verification_failed=false

        # Read values from MySQL using SHOW VARIABLES
        verified_innodb_buffer_pool_size="$(docker compose -f "${compose_file}" exec -T mysql mysql -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';" 2>/dev/null | tail -n 1 | awk '{print $2}')"
        # Convert bytes to MB
        verified_innodb_buffer_pool_size=$((verified_innodb_buffer_pool_size / 1024 / 1024))

        verified_innodb_log_file_size="$(docker compose -f "${compose_file}" exec -T mysql mysql -e "SHOW VARIABLES LIKE 'innodb_log_file_size';" 2>/dev/null | tail -n 1 | awk '{print $2}')"
        # Convert bytes to MB
        verified_innodb_log_file_size=$((verified_innodb_log_file_size / 1024 / 1024))

        verified_max_connections="$(docker compose -f "${compose_file}" exec -T mysql mysql -e "SHOW VARIABLES LIKE 'max_connections';" 2>/dev/null | tail -n 1 | awk '{print $2}')"

        verified_tmp_table_size="$(docker compose -f "${compose_file}" exec -T mysql mysql -e "SHOW VARIABLES LIKE 'tmp_table_size';" 2>/dev/null | tail -n 1 | awk '{print $2}')"
        # Convert bytes to MB
        verified_tmp_table_size=$((verified_tmp_table_size / 1024 / 1024))

        log_event "debug" "Verified values from MySQL: innodb_buffer_pool_size=${verified_innodb_buffer_pool_size}M, max_connections=${verified_max_connections}" "false"

        # Check each value (with tolerance for buffer pool size due to MySQL rounding)
        local buffer_pool_diff=$((verified_innodb_buffer_pool_size - innodb_buffer_pool_size))
        if [[ ${buffer_pool_diff#-} -le 10 ]]; then  # Allow ±10MB tolerance
          display --indent 8 --text "innodb_buffer_pool_size: ${verified_innodb_buffer_pool_size}M" --result "✓" --color GREEN
        else
          display --indent 8 --text "innodb_buffer_pool_size: ${verified_innodb_buffer_pool_size}M (expected: ${innodb_buffer_pool_size}M)" --result "✗" --color RED
          log_event "error" "Verification failed: innodb_buffer_pool_size = ${verified_innodb_buffer_pool_size}M, expected ${innodb_buffer_pool_size}M" "false"
          verification_failed=true
        fi

        local log_file_diff=$((verified_innodb_log_file_size - innodb_log_file_size))
        if [[ ${log_file_diff#-} -le 10 ]]; then  # Allow ±10MB tolerance
          display --indent 8 --text "innodb_log_file_size: ${verified_innodb_log_file_size}M" --result "✓" --color GREEN
        else
          display --indent 8 --text "innodb_log_file_size: ${verified_innodb_log_file_size}M (expected: ${innodb_log_file_size}M)" --result "✗" --color RED
          log_event "error" "Verification failed: innodb_log_file_size = ${verified_innodb_log_file_size}M, expected ${innodb_log_file_size}M" "false"
          verification_failed=true
        fi

        if [[ ${verified_max_connections} -eq ${max_connections} ]]; then
          display --indent 8 --text "max_connections: ${verified_max_connections}" --result "✓" --color GREEN
        else
          display --indent 8 --text "max_connections: ${verified_max_connections} (expected: ${max_connections})" --result "✗" --color RED
          log_event "error" "Verification failed: max_connections = ${verified_max_connections}, expected ${max_connections}" "false"
          verification_failed=true
        fi

        local tmp_table_diff=$((verified_tmp_table_size - tmp_table_size))
        if [[ ${tmp_table_diff#-} -le 5 ]]; then  # Allow ±5MB tolerance
          display --indent 8 --text "tmp_table_size: ${verified_tmp_table_size}M" --result "✓" --color GREEN
        else
          display --indent 8 --text "tmp_table_size: ${verified_tmp_table_size}M (expected: ${tmp_table_size}M)" --result "✗" --color RED
          log_event "error" "Verification failed: tmp_table_size = ${verified_tmp_table_size}M, expected ${tmp_table_size}M" "false"
          verification_failed=true
        fi

        # Log complete summary of changes
        echo ""
        display --indent 6 --text "- Optimization Summary" --tcolor GREEN
        log_event "info" "=== MySQL Optimization Summary ===" "false"
        log_event "info" "Container: ${container_name}" "false"
        log_event "info" "Config file: ${mysql_conf_file}" "false"
        log_event "info" "Changes applied:" "false"
        log_event "info" "  - innodb_buffer_pool_size: ${current_innodb_buffer_pool_size}M → ${innodb_buffer_pool_size}M (verified: ${verified_innodb_buffer_pool_size}M)" "false"
        log_event "info" "  - innodb_log_file_size: ${current_innodb_log_file_size}M → ${innodb_log_file_size}M (verified: ${verified_innodb_log_file_size}M)" "false"
        log_event "info" "  - max_connections: ${current_max_connections} → ${max_connections} (verified: ${verified_max_connections})" "false"
        log_event "info" "  - tmp_table_size: ${current_tmp_table_size}M → ${tmp_table_size}M (verified: ${verified_tmp_table_size}M)" "false"

        if [[ ${verification_failed} == true ]]; then
          log_event "warning" "Settings verification completed with errors" "false"
          display --indent 8 --text "Settings applied but verification found discrepancies" --tcolor YELLOW
        else
          log_event "info" "MySQL optimization completed and verified successfully" "false"
          display --indent 8 --text "All settings applied, verified, and MySQL restarted" --tcolor GREEN
        fi
        return 0
      fi
      sleep 2
      ((retries--))
    done

    display --indent 6 --text "- MySQL ready" --result "TIMEOUT" --color RED
    log_event "error" "MySQL did not become ready in time" "false"
    return 1
  else
    log_event "info" "MySQL restart cancelled by user" "false"
    display --indent 6 --text "- Restart cancelled" --result "SKIP" --color YELLOW
    display --indent 8 --text "Configuration saved but not applied (restart required)" --tcolor YELLOW
    return 0
  fi

}

################################################################################
# Optimize Redis in Docker container
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function docker_redis_optimize() {

  local project_path="${1}"
  local compose_file="${project_path}/docker-compose.yml"
  local container_name

  log_subsection "Redis Optimization (Docker)"

  # Get container name
  container_name="$(docker_optimizer_get_container_name "${project_path}" "redis")"

  if [[ -z ${container_name} ]]; then
    log_event "warning" "No Redis container found for ${project_path}" "false"
    display --indent 6 --text "- Redis container not found" --result "FAIL" --color RED
    return 1
  fi

  log_event "info" "Optimizing Redis in container: ${container_name}" "false"

  display --indent 6 --text "Container: ${container_name}"

  # Flush cache
  whiptail --title "FLUSH REDIS CACHE" --yesno "Do you want to flush all Redis cache data?" 10 60 3>&1 1>&2 2>&3

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    log_event "info" "Flushing Redis cache" "false"

    # Get key count before flush
    local keys_before
    keys_before="$(docker exec -i "${container_name}" redis-cli DBSIZE 2>/dev/null | awk '{print $2}')"

    docker exec -i "${container_name}" redis-cli FLUSHALL 2>/dev/null

    if [[ $? -eq 0 ]]; then
      display --indent 6 --text "- Flushing cache (${keys_before} keys)" --result "DONE" --color GREEN
      log_event "info" "Redis cache flushed successfully (${keys_before} keys)" "false"
    else
      display --indent 6 --text "- Flushing cache" --result "FAIL" --color RED
      log_event "error" "Failed to flush Redis cache" "false"
      return 1
    fi
  else
    display --indent 6 --text "- Flush cancelled" --result "SKIP" --color YELLOW
  fi

  # TODO: Implement maxmemory and eviction policy configuration
  display --indent 6 --text "- Configure maxmemory" --result "TODO" --color YELLOW
  log_event "info" "Redis maxmemory configuration coming in next version" "false"

  return 0

}

################################################################################
# Optimize RAM usage for Docker project
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function docker_optimize_ram_usage() {

  local project_path="${1}"
  local compose_file="${project_path}/docker-compose.yml"

  log_subsection "RAM Optimization (Docker)"

  log_event "info" "Optimizing RAM usage for: ${project_path}" "false"

  # Restart PHP-FPM container
  local php_container
  php_container="$(docker_optimizer_get_container_name "${project_path}" "php-fpm")"

  if [[ -n ${php_container} ]]; then
    log_event "info" "Restarting PHP-FPM container" "false"
    docker compose -f "${compose_file}" restart php-fpm 2>/dev/null
    display --indent 6 --text "- Restarting PHP-FPM" --result "DONE" --color GREEN
  fi

  # Flush Redis cache
  local redis_container
  redis_container="$(docker_optimizer_get_container_name "${project_path}" "redis")"

  if [[ -n ${redis_container} ]]; then
    local keys_count
    keys_count="$(docker exec -i "${redis_container}" redis-cli DBSIZE 2>/dev/null | awk '{print $2}')"

    log_event "info" "Flushing Redis cache (${keys_count} keys)" "false"
    docker exec -i "${redis_container}" redis-cli FLUSHALL 2>/dev/null
    display --indent 6 --text "- Flushing Redis (${keys_count} keys)" --result "DONE" --color GREEN
  fi

  # Docker cleanup
  log_event "info" "Running Docker cleanup" "false"

  # Remove unused images
  local images_removed
  images_removed="$(docker image prune -af 2>&1 | grep "Total reclaimed space" | awk '{print $4, $5}')"

  if [[ -n ${images_removed} ]]; then
    display --indent 6 --text "- Removing unused images (${images_removed})" --result "DONE" --color GREEN
  fi

  log_event "info" "RAM optimization completed" "false"

  return 0

}

################################################################################
# Get value from docker-compose.yml for a specific service and key
#
# Arguments:
#   ${1} = ${compose_file}
#   ${2} = ${service_name}
#   ${3} = ${key} (e.g., "mem_limit", "cpus", "deploy.resources.limits.memory")
#
# Outputs:
#   The value of the key, or empty string if not found
################################################################################

function docker_compose_get_value() {

  local compose_file="${1}"
  local service_name="${2}"
  local key="${3}"

  local value=""

  # Try yq first (supports nested keys with dot notation)
  if command -v yq &>/dev/null; then
    value="$(yq eval ".services.${service_name}.${key} // \"\"" "${compose_file}" 2>/dev/null)"
    # yq returns "null" for non-existent keys
    [[ "${value}" == "null" ]] && value=""
  else
    # Fallback to AWK for simple keys (top-level only)
    value="$(awk -v service="${service_name}" -v key="${key}" '
      /^[[:space:]][[:space:]][[:space:]][[:space:]][a-zA-Z0-9_-]+:/ {
        if ($1 == service":") {
          in_service=1
        } else if (in_service && /^[[:space:]][[:space:]][[:space:]][[:space:]][a-zA-Z0-9_-]+:/) {
          in_service=0
        }
      }
      in_service && $1 == key":" {
        print $2
        exit
      }
    ' "${compose_file}")"
  fi

  echo "${value}"
}

################################################################################
# Manage Docker Compose resource limits
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   Interactive menu to manage resource limits
################################################################################

function docker_manage_resource_limits() {

  local project_path="${1}"
  local compose_file="${project_path}/docker-compose.yml"

  log_subsection "Docker Resource Limits Manager"
  log_event "info" "Managing resource limits for project: ${project_path}" "false"

  # Verify docker-compose.yml exists
  if [[ ! -f "${compose_file}" ]]; then
    display --indent 6 --text "- Checking docker-compose.yml" --result "NOT FOUND" --color RED
    log_event "error" "docker-compose.yml not found at ${compose_file}" "false"
    return 1
  fi

  display --indent 6 --text "- Checking docker-compose.yml" --result "FOUND" --color GREEN
  log_event "debug" "Found docker-compose.yml at ${compose_file}" "false"

  # Get server resources
  display --indent 6 --text "- Detecting Server Resources" --tcolor CYAN

  local total_ram_mb
  local total_cpu_cores
  local available_ram_mb

  total_ram_mb="$(free -m | awk '/^Mem:/{print $2}')"
  available_ram_mb="$(free -m | awk '/^Mem:/{print $7}')"
  total_cpu_cores="$(nproc)"

  log_event "debug" "Server resources: RAM=${total_ram_mb}MB (${available_ram_mb}MB available), CPU=${total_cpu_cores} cores" "false"

  display --indent 8 --text "Total RAM: ${total_ram_mb}MB" --tcolor WHITE
  display --indent 8 --text "Available RAM: ${available_ram_mb}MB" --tcolor WHITE
  display --indent 8 --text "CPU Cores: ${total_cpu_cores}" --tcolor WHITE

  # Parse services from docker-compose.yml
  echo ""
  display --indent 6 --text "- Detecting Services" --tcolor CYAN

  local services

  # Try to use yq if available (more robust YAML parsing)
  if command -v yq &>/dev/null; then
    log_event "debug" "Using yq for YAML parsing" "false"
    services="$(yq eval '.services | keys | .[]' "${compose_file}" 2>/dev/null)"
  fi

  # Fallback to AWK if yq is not available or failed
  if [[ -z ${services} ]]; then
    log_event "debug" "Using AWK for YAML parsing (yq not available or failed)" "false"
    # Extract services only from the 'services:' section, excluding YAML keywords
    services="$(awk '
      BEGIN {
        # Define YAML keywords to exclude
        keywords["volumes"] = 1
        keywords["networks"] = 1
        keywords["configs"] = 1
        keywords["secrets"] = 1
        keywords["environment"] = 1
        keywords["ports"] = 1
        keywords["labels"] = 1
        keywords["healthcheck"] = 1
        keywords["depends_on"] = 1
        keywords["build"] = 1
        keywords["image"] = 1
        keywords["restart"] = 1
        keywords["command"] = 1
        keywords["entrypoint"] = 1
        keywords["working_dir"] = 1
        keywords["user"] = 1
        keywords["hostname"] = 1
        keywords["domainname"] = 1
        keywords["security_opt"] = 1
        keywords["container_name"] = 1
      }
      /^services:/ { in_services=1; next }
      /^[a-zA-Z]/ && in_services && NF > 0 { in_services=0 }
      in_services && /^[[:space:]][[:space:]][[:space:]][[:space:]][a-zA-Z0-9_-]+:/ {
        service=$1
        gsub(/:/, "", service)
        gsub(/^[[:space:]]+/, "", service)
        # Only print if NOT a keyword
        if (!(service in keywords)) {
          print service
        }
      }
    ' "${compose_file}")"
  fi

  if [[ -z ${services} ]]; then
    display --indent 6 --text "- Parsing services" --result "FAILED" --color RED
    log_event "error" "Could not parse services from docker-compose.yml" "false"
    return 1
  fi

  log_event "debug" "Found services: ${services}" "false"

  # Show current limits for each service
  echo ""
  display --indent 6 --text "- Current Resource Limits" --tcolor CYAN

  local service
  while IFS= read -r service; do
    [[ -z ${service} ]] && continue

    display --indent 8 --text "Service: ${service}" --tcolor YELLOW

    # Check for mem_limit
    local mem_limit
    mem_limit="$(docker_compose_get_value "${compose_file}" "${service}" "mem_limit")"

    if [[ -n ${mem_limit} ]]; then
      display --indent 10 --text "mem_limit: ${mem_limit}" --tcolor WHITE
    else
      display --indent 10 --text "mem_limit: not set" --tcolor GRAY
    fi

    # Check for cpus
    local cpus
    cpus="$(docker_compose_get_value "${compose_file}" "${service}" "cpus")"

    if [[ -n ${cpus} ]]; then
      display --indent 10 --text "cpus: ${cpus}" --tcolor WHITE
    else
      display --indent 10 --text "cpus: not set" --tcolor GRAY
    fi

    # Check for mem_reservation
    local mem_reservation
    mem_reservation="$(docker_compose_get_value "${compose_file}" "${service}" "mem_reservation")"

    if [[ -n ${mem_reservation} ]]; then
      display --indent 10 --text "mem_reservation: ${mem_reservation}" --tcolor WHITE
    fi

  done <<< "${services}"

  # Interactive menu to modify limits
  echo ""
  display --indent 6 --text "- Resource Limit Options" --tcolor CYAN

  local service_options=()
  while IFS= read -r service; do
    [[ -z ${service} ]] && continue
    service_options+=("${service}" "Manage ${service} limits")
  done <<< "${services}"

  service_options+=("SUGGEST" "Auto-suggest optimal limits")

  local chosen_service
  chosen_service=$(whiptail --title "Resource Limits Manager" --menu "Choose a service to manage or auto-suggest limits:" 20 78 10 "${service_options[@]}" 3>&1 1>&2 2>&3)

  local exitstatus=$?
  if [[ ${exitstatus} -ne 0 ]]; then
    log_event "info" "User cancelled resource limits management" "false"
    return 0
  fi

  # Handle BACK option
  if [[ ${chosen_service} == "BACK" ]]; then
    log_event "info" "User returned to main menu" "false"
    return 0
  fi

  # Handle SUGGEST option
  if [[ ${chosen_service} == "SUGGEST" ]]; then
    docker_suggest_resource_limits "${project_path}" "${services}" "${total_ram_mb}" "${total_cpu_cores}"
    return $?
  fi

  # Manage individual service
  docker_manage_service_limits "${project_path}" "${chosen_service}" "${total_ram_mb}" "${total_cpu_cores}"

  return $?

}

################################################################################
# Suggest optimal resource limits for all services
#
# Arguments:
#   ${1} = ${project_path}
#   ${2} = ${services} (newline-separated list)
#   ${3} = ${total_ram_mb}
#   ${4} = ${total_cpu_cores}
#
# Outputs:
#   Suggested limits and option to apply
################################################################################

function docker_suggest_resource_limits() {

  local project_path="${1}"
  local services="${2}"
  local total_ram_mb="${3}"
  local total_cpu_cores="${4}"
  local compose_file="${project_path}/docker-compose.yml"

  echo ""
  display --indent 6 --text "- Generating Optimal Suggestions" --tcolor CYAN
  log_event "info" "Auto-suggesting resource limits based on server capacity" "false"

  # Count services
  local service_count
  service_count="$(echo "${services}" | grep -c .)"

  log_event "debug" "Total services: ${service_count}" "false"

  # Get current RAM usage by Docker containers (excluding this project's containers)
  echo ""
  display --indent 6 --text "- Analyzing Current Docker Usage" --tcolor CYAN

  local project_name
  project_name="$(basename "${project_path}")"

  # Get total RAM used by all running Docker containers
  local docker_ram_used_mb
  docker_ram_used_mb="$(docker stats --no-stream --format "{{.MemUsage}}" 2>/dev/null | awk -F'/' '{print $1}' | sed 's/MiB//g; s/GiB/*1024/g; s/KiB\/1024/g' | bc 2>/dev/null | awk '{sum+=$1} END {print int(sum)}')"

  # If no containers running or error, set to 0
  [[ -z ${docker_ram_used_mb} ]] && docker_ram_used_mb=0

  # Get RAM used by OTHER projects (not this one)
  local other_containers_ram_mb
  other_containers_ram_mb="$(docker stats --no-stream --format "{{.Name}} {{.MemUsage}}" 2>/dev/null | grep -v "^${project_name}_" | awk -F'/' '{print $1}' | awk '{print $2}' | sed 's/MiB//g; s/GiB/*1024/g; s/KiB\/1024/g' | bc 2>/dev/null | awk '{sum+=$1} END {print int(sum)}')"

  [[ -z ${other_containers_ram_mb} ]] && other_containers_ram_mb=0

  display --indent 8 --text "Docker RAM in use: ${docker_ram_used_mb}MB" --tcolor WHITE
  display --indent 8 --text "Other projects RAM: ${other_containers_ram_mb}MB" --tcolor WHITE

  log_event "debug" "Docker RAM usage: total=${docker_ram_used_mb}MB, other_projects=${other_containers_ram_mb}MB" "false"

  # Calculate available resources
  # Reserve 20% of RAM for system + subtract RAM used by other containers
  local system_reserved_mb=$((total_ram_mb * 20 / 100))
  local usable_ram_mb=$((total_ram_mb - system_reserved_mb - other_containers_ram_mb))

  # Ensure we don't get negative values
  if [[ ${usable_ram_mb} -lt 512 ]]; then
    display --indent 6 --text "- Insufficient Available RAM" --result "WARNING" --color YELLOW
    log_event "warning" "Available RAM (${usable_ram_mb}MB) is too low for suggestions" "false"
    usable_ram_mb=512  # Minimum usable RAM
  fi

  local ram_per_service=$((usable_ram_mb / service_count))
  local cpu_per_service="$(echo "scale=2; ${total_cpu_cores} / ${service_count}" | bc)"

  echo ""
  display --indent 8 --text "Resource Calculation:" --tcolor CYAN
  display --indent 10 --text "Total RAM: ${total_ram_mb}MB" --tcolor WHITE
  display --indent 10 --text "System Reserved (20%): ${system_reserved_mb}MB" --tcolor WHITE
  display --indent 10 --text "Other Containers: ${other_containers_ram_mb}MB" --tcolor WHITE
  display --indent 10 --text "Available for this project: ${usable_ram_mb}MB" --tcolor GREEN
  display --indent 10 --text "Services in this project: ${service_count}" --tcolor WHITE

  echo ""
  display --indent 8 --text "Suggested Limits per Service:" --tcolor YELLOW
  display --indent 10 --text "mem_limit: ${ram_per_service}m" --tcolor WHITE
  display --indent 10 --text "mem_reservation: $((ram_per_service * 70 / 100))m" --tcolor WHITE
  display --indent 10 --text "cpus: ${cpu_per_service}" --tcolor WHITE

  # Ask user if they want to apply these suggestions
  if whiptail --title "Apply Suggestions?" --yesno "Do you want to apply these suggested limits to ALL services?\n\nThis will modify docker-compose.yml" 12 78; then

    echo ""
    display --indent 6 --text "- Applying Suggested Limits" --tcolor CYAN
    log_event "info" "User approved suggested limits, applying to all services" "false"

    # Backup docker-compose.yml
    cp "${compose_file}" "${compose_file}.bak.$(date +%Y%m%d_%H%M%S)"
    display --indent 8 --text "Backup created" --result "DONE" --color GREEN

    local service
    while IFS= read -r service; do
      [[ -z ${service} ]] && continue

      display --indent 8 --text "Applying to ${service}..." --tcolor WHITE
      docker_apply_service_limits "${compose_file}" "${service}" "${ram_per_service}m" "$((ram_per_service * 70 / 100))m" "${cpu_per_service}"

    done <<< "${services}"

    echo ""
    display --indent 6 --text "- Resource Limits Applied" --result "DONE" --color GREEN
    log_event "info" "All suggested limits have been applied successfully" "false"

    # Ask if user wants to restart containers
    if whiptail --title "Restart Containers?" --yesno "Resource limits have been applied.\n\nDo you want to restart containers for changes to take effect?" 10 78; then
      log_event "info" "Restarting containers to apply new resource limits" "false"
      cd "${project_path}" || return 1
      docker compose down
      docker compose up -d
      display --indent 6 --text "- Containers Restarted" --result "DONE" --color GREEN
    fi

  else
    log_event "info" "User declined to apply suggested limits" "false"
  fi

  return 0

}

################################################################################
# Manage resource limits for individual service
#
# Arguments:
#   ${1} = ${project_path}
#   ${2} = ${service_name}
#   ${3} = ${total_ram_mb}
#   ${4} = ${total_cpu_cores}
#
# Outputs:
#   Interactive form to set limits
################################################################################

function docker_manage_service_limits() {

  local project_path="${1}"
  local service_name="${2}"
  local total_ram_mb="${3}"
  local total_cpu_cores="${4}"
  local compose_file="${project_path}/docker-compose.yml"

  log_event "info" "Managing limits for service: ${service_name}" "false"

  # Get current values
  local current_mem_limit
  local current_mem_reservation
  local current_cpus

  current_mem_limit="$(docker_compose_get_value "${compose_file}" "${service_name}" "mem_limit")"
  current_mem_reservation="$(docker_compose_get_value "${compose_file}" "${service_name}" "mem_reservation")"
  current_cpus="$(docker_compose_get_value "${compose_file}" "${service_name}" "cpus")"

  # Get user input for each limit
  local new_mem_limit
  local new_mem_reservation
  local new_cpus

  echo ""
  display --indent 6 --text "- Configuring Limits for ${service_name}" --tcolor CYAN
  display --indent 8 --text "Server: ${total_ram_mb}MB RAM, ${total_cpu_cores} CPUs" --tcolor WHITE

  if [[ -n ${current_mem_limit} ]]; then
    display --indent 8 --text "Current mem_limit: ${current_mem_limit}" --tcolor YELLOW
  fi
  if [[ -n ${current_mem_reservation} ]]; then
    display --indent 8 --text "Current mem_reservation: ${current_mem_reservation}" --tcolor YELLOW
  fi
  if [[ -n ${current_cpus} ]]; then
    display --indent 8 --text "Current cpus: ${current_cpus}" --tcolor YELLOW
  fi

  # Ask for mem_limit
  new_mem_limit=$(whiptail --title "Set mem_limit for ${service_name}" --inputbox "Enter memory limit (e.g., 512m, 1g) or leave empty to remove:\n\nCurrent: ${current_mem_limit:-not set}" 12 78 "${current_mem_limit}" 3>&1 1>&2 2>&3)

  if [[ $? -ne 0 ]]; then
    log_event "info" "User cancelled setting limits for ${service_name}" "false"
    return 0
  fi

  # Ask for mem_reservation
  new_mem_reservation=$(whiptail --title "Set mem_reservation for ${service_name}" --inputbox "Enter memory reservation (e.g., 256m, 512m) or leave empty to remove:\n\nCurrent: ${current_mem_reservation:-not set}" 12 78 "${current_mem_reservation}" 3>&1 1>&2 2>&3)

  if [[ $? -ne 0 ]]; then
    log_event "info" "User cancelled setting limits for ${service_name}" "false"
    return 0
  fi

  # Ask for cpus
  new_cpus=$(whiptail --title "Set CPUs for ${service_name}" --inputbox "Enter CPU limit (e.g., 1.5, 2.0) or leave empty to remove:\n\nCurrent: ${current_cpus:-not set}" 12 78 "${current_cpus}" 3>&1 1>&2 2>&3)

  if [[ $? -ne 0 ]]; then
    log_event "info" "User cancelled setting limits for ${service_name}" "false"
    return 0
  fi

  log_event "debug" "User input: mem_limit=${new_mem_limit}, mem_reservation=${new_mem_reservation}, cpus=${new_cpus}" "false"

  # Backup docker-compose.yml
  cp "${compose_file}" "${compose_file}.bak.$(date +%Y%m%d_%H%M%S)"

  echo ""
  display --indent 6 --text "- Applying Changes to ${service_name}" --tcolor CYAN

  docker_apply_service_limits "${compose_file}" "${service_name}" "${new_mem_limit}" "${new_mem_reservation}" "${new_cpus}"

  display --indent 6 --text "- Resource Limits Updated" --result "DONE" --color GREEN
  log_event "info" "Resource limits updated for ${service_name}" "false"

  # Ask if user wants to restart containers
  if whiptail --title "Restart Containers?" --yesno "Resource limits have been updated.\n\nDo you want to restart containers for changes to take effect?" 10 78; then
    log_event "info" "Restarting containers to apply new resource limits" "false"
    cd "${project_path}" || return 1
    docker compose down
    docker compose up -d
    display --indent 6 --text "- Containers Restarted" --result "DONE" --color GREEN
  fi

  return 0

}

################################################################################
# Apply resource limits to a service in docker-compose.yml
#
# Arguments:
#   ${1} = ${compose_file}
#   ${2} = ${service_name}
#   ${3} = ${mem_limit} (empty to remove)
#   ${4} = ${mem_reservation} (empty to remove)
#   ${5} = ${cpus} (empty to remove)
#
# Outputs:
#   Modified docker-compose.yml
################################################################################

function docker_apply_service_limits() {

  local compose_file="${1}"
  local service_name="${2}"
  local mem_limit="${3}"
  local mem_reservation="${4}"
  local cpus="${5}"

  log_event "debug" "Applying limits to ${service_name}: mem_limit=${mem_limit}, mem_reservation=${mem_reservation}, cpus=${cpus}" "false"

  # Create temporary file
  local temp_file="${compose_file}.tmp"

  # Use AWK to modify YAML (pure bash solution)
  awk -v service="${service_name}" \
      -v mem_limit="${mem_limit}" \
      -v mem_reservation="${mem_reservation}" \
      -v cpus="${cpus}" '
  BEGIN {
    in_service = 0
    service_indent = "        "  # 8 spaces for service properties
    limits_added = 0
  }

  # Detect when we enter the target service
  /^[[:space:]][[:space:]][[:space:]][[:space:]][a-zA-Z0-9_-]+:/ {
    if ($1 == service":") {
      in_service = 1
      limits_added = 0
      print
      next
    } else if (in_service) {
      # Exiting the service, add missing limits before next service
      if (limits_added == 0) {
        if (mem_limit) print service_indent "mem_limit: " mem_limit
        if (mem_reservation) print service_indent "mem_reservation: " mem_reservation
        if (cpus) print service_indent "cpus: " cpus
        limits_added = 1
      }
      in_service = 0
      print
      next
    }
  }

  # Handle existing limit lines - replace or skip
  in_service && /^[[:space:]]+mem_limit:/ {
    if (mem_limit) {
      print service_indent "mem_limit: " mem_limit
      limits_added = 1
    }
    next
  }

  in_service && /^[[:space:]]+mem_reservation:/ {
    if (mem_reservation) {
      print service_indent "mem_reservation: " mem_reservation
    }
    next
  }

  in_service && /^[[:space:]]+cpus:/ {
    if (cpus) {
      print service_indent "cpus: " cpus
    }
    next
  }

  # Print all other lines as-is
  { print }

  # Handle end of file while still in service
  END {
    if (in_service && limits_added == 0) {
      if (mem_limit) print service_indent "mem_limit: " mem_limit
      if (mem_reservation) print service_indent "mem_reservation: " mem_reservation
      if (cpus) print service_indent "cpus: " cpus
    }
  }
  ' "${compose_file}" > "${temp_file}"

  # Check if AWK succeeded
  if [[ $? -eq 0 && -f "${temp_file}" ]]; then
    # Verify the temp file is not empty
    if [[ -s "${temp_file}" ]]; then
      mv "${temp_file}" "${compose_file}"
      log_event "info" "Successfully applied limits to ${service_name}" "false"
      return 0
    else
      log_event "error" "Generated file is empty, aborting" "false"
      rm -f "${temp_file}"
      return 1
    fi
  else
    log_event "error" "Failed to apply limits to ${service_name}" "false"
    rm -f "${temp_file}"
    return 1
  fi

}
