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
    log_event "info" "PHP-FPM optimization completed successfully" "false"
    display --indent 8 --text "All settings applied and PHP-FPM reloaded" --tcolor GREEN
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
    # Log complete summary of changes
    log_event "info" "=== Nginx Optimization Summary ===" "false"
    log_event "info" "Container: ${container_name}" "false"
    log_event "info" "Config file: ${nginx_conf_file}" "false"
    log_event "info" "Changes applied:" "false"
    log_event "info" "  - worker_processes: ${current_worker_processes} → ${worker_processes}" "false"
    log_event "info" "  - worker_connections: ${current_worker_connections} → ${worker_connections}" "false"
    log_event "info" "  - fastcgi_buffers: ${current_fastcgi_buffers} → ${fastcgi_buffers}" "false"
    log_event "info" "  - fastcgi_buffer_size: ${current_fastcgi_buffer_size} → ${fastcgi_buffer_size}" "false"
    log_event "info" "Nginx optimization completed successfully" "false"

    display --indent 6 --text "- Reloading Nginx" --result "DONE" --color GREEN
    display --indent 8 --text "All settings applied and Nginx reloaded" --tcolor GREEN
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
        # Log complete summary of changes
        log_event "info" "=== MySQL Optimization Summary ===" "false"
        log_event "info" "Container: ${container_name}" "false"
        log_event "info" "Config file: ${mysql_conf_file}" "false"
        log_event "info" "Changes applied:" "false"
        log_event "info" "  - innodb_buffer_pool_size: ${current_innodb_buffer_pool_size}M → ${innodb_buffer_pool_size}M" "false"
        log_event "info" "  - innodb_log_file_size: ${current_innodb_log_file_size}M → ${innodb_log_file_size}M" "false"
        log_event "info" "  - max_connections: ${current_max_connections} → ${max_connections}" "false"
        log_event "info" "  - tmp_table_size: ${current_tmp_table_size}M → ${tmp_table_size}M" "false"
        log_event "info" "MySQL optimization completed successfully" "false"

        display --indent 6 --text "- MySQL ready" --result "DONE" --color GREEN
        display --indent 8 --text "All settings applied and MySQL restarted" --tcolor GREEN
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
