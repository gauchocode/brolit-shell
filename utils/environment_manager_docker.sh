#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.6
################################################################################
#
# Docker Environment Manager: Manage Docker containerized services and optimizations.
#
################################################################################

################################################################################
# Docker Environment Main Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function environment_manager_docker_menu() {

  local docker_projects
  local project_list
  local chosen_project
  local project_path

  log_section "Docker Environment Manager"

  # Get list of Docker projects
  docker_projects="$(docker_optimizer_list_projects)"

  if [[ -z ${docker_projects} ]]; then
    display --indent 6 --text "- No Docker projects found" --result "FAIL" --color RED
    display --indent 8 --text "Looking for docker-compose.yml in ${PROJECTS_PATH}" --tcolor YELLOW

    read -n 1 -s -r -p "Press any key to continue"
    environment_manager_menu
    return 1
  fi

  # Build whiptail menu from project list
  project_list=()
  local index=1
  while IFS= read -r project; do
    project_name="$(basename "${project}")"
    project_list+=("${index})" "${project_name}")
    ((index++))
  done <<< "${docker_projects}"

  chosen_project="$(whiptail --title "DOCKER PROJECTS" --menu "\nSelect a Docker project to manage:\n" 20 78 10 "${project_list[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Extract project number from choice (e.g., "1)" -> 1)
    project_index="${chosen_project//[)]/}"

    # Get the actual project path
    project_path="$(echo "${docker_projects}" | sed -n "${project_index}p")"

    if [[ -n ${project_path} ]]; then
      # Show project menu
      docker_project_menu "${project_path}"
    fi

    # Return to this menu
    environment_manager_docker_menu

  fi

  # Return to environment manager menu
  environment_manager_menu

}

################################################################################
# Docker Project Menu
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   nothing
################################################################################

function docker_project_menu() {

  local project_path="${1}"
  local project_name
  local docker_project_options
  local chosen_docker_project_option

  project_name="$(basename "${project_path}")"

  log_subsection "Docker Project: ${project_name}"

  docker_project_options=(
    "01)" "VIEW CONTAINER STATUS"
    "02)" "OPTIMIZE PHP-FPM"
    "03)" "OPTIMIZE NGINX"
    "04)" "OPTIMIZE MYSQL"
    "05)" "OPTIMIZE REDIS"
    "06)" "CLEAN RAM USAGE"
    "07)" "VIEW CONTAINER LOGS"
    "08)" "RESTART CONTAINERS"
    "09)" "STOP CONTAINERS"
    "10)" "START CONTAINERS"
    "11)" "EXECUTE COMMAND IN CONTAINER"
  )

  chosen_docker_project_option="$(whiptail --title "DOCKER PROJECT: ${project_name}" --menu "\nManage Docker containers:\n" 20 78 10 "${docker_project_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # VIEW CONTAINER STATUS
    if [[ ${chosen_docker_project_option} == *"01"* ]]; then
      docker_view_container_status "${project_path}"
    fi

    # OPTIMIZE PHP-FPM
    if [[ ${chosen_docker_project_option} == *"02"* ]]; then
      docker_php_fpm_optimize "${project_path}"
    fi

    # OPTIMIZE NGINX
    if [[ ${chosen_docker_project_option} == *"03"* ]]; then
      docker_nginx_optimize "${project_path}"
    fi

    # OPTIMIZE MYSQL
    if [[ ${chosen_docker_project_option} == *"04"* ]]; then
      docker_mysql_optimize "${project_path}"
    fi

    # OPTIMIZE REDIS
    if [[ ${chosen_docker_project_option} == *"05"* ]]; then
      docker_redis_optimize "${project_path}"
    fi

    # CLEAN RAM USAGE
    if [[ ${chosen_docker_project_option} == *"06"* ]]; then
      docker_optimize_ram_usage "${project_path}"
    fi

    # VIEW CONTAINER LOGS
    if [[ ${chosen_docker_project_option} == *"07"* ]]; then
      docker_view_logs_menu "${project_path}"
    fi

    # RESTART CONTAINERS
    if [[ ${chosen_docker_project_option} == *"08"* ]]; then
      docker_restart_containers_menu "${project_path}"
    fi

    # STOP CONTAINERS
    if [[ ${chosen_docker_project_option} == *"09"* ]]; then
      docker_stop_containers_menu "${project_path}"
    fi

    # START CONTAINERS
    if [[ ${chosen_docker_project_option} == *"10"* ]]; then
      docker_start_containers_menu "${project_path}"
    fi

    # EXECUTE COMMAND IN CONTAINER
    if [[ ${chosen_docker_project_option} == *"11"* ]]; then
      docker_exec_command_menu "${project_path}"
    fi

    prompt_return_or_finish
    docker_project_menu "${project_path}"

  fi

}

################################################################################
# Docker: View Container Status
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   nothing
################################################################################

function docker_view_container_status() {

  local project_path="${1}"
  local compose_file="${project_path}/docker-compose.yml"

  log_subsection "Container Status"

  if [[ ! -f ${compose_file} ]]; then
    display --indent 6 --text "- docker-compose.yml not found" --result "FAIL" --color RED
    return 1
  fi

  # Show container status
  log_event "info" "Running: docker compose -f ${compose_file} ps" "false"
  docker compose -f "${compose_file}" ps

  echo ""
  read -n 1 -s -r -p "Press any key to continue"

}

################################################################################
# Docker: View Logs Menu
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   nothing
################################################################################

function docker_view_logs_menu() {

  local project_path="${1}"
  local compose_file="${project_path}/docker-compose.yml"
  local container_name
  local log_lines

  # Get list of containers
  local containers
  containers="$(docker compose -f "${compose_file}" ps --services)"

  if [[ -z ${containers} ]]; then
    display --indent 6 --text "- No running containers found" --result "FAIL" --color RED
    return 1
  fi

  # Build menu
  local container_list=()
  local index=1
  while IFS= read -r container; do
    container_list+=("${index})" "${container}")
    ((index++))
  done <<< "${containers}"

  chosen_container="$(whiptail --title "SELECT CONTAINER" --menu "\nView logs for:\n" 20 78 10 "${container_list[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    container_index="${chosen_container//[)]/}"
    container_name="$(echo "${containers}" | sed -n "${container_index}p")"

    log_lines="$(whiptail --title "LOG LINES" --inputbox "How many lines to show? (default: 100)" 10 60 "100" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      [[ -z ${log_lines} ]] && log_lines="100"
      log_event "info" "Showing last ${log_lines} lines for ${container_name}" "false"
      docker compose -f "${compose_file}" logs --tail="${log_lines}" "${container_name}"
      echo ""
      read -n 1 -s -r -p "Press any key to continue"
    fi
  fi

}

################################################################################
# Docker: Restart Containers Menu
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   nothing
################################################################################

function docker_restart_containers_menu() {

  local project_path="${1}"
  local compose_file="${project_path}/docker-compose.yml"

  whiptail --title "RESTART CONTAINERS" --yesno "Are you sure you want to restart all containers?\n\nThis will cause brief downtime." 12 60 3>&1 1>&2 2>&3

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    log_event "info" "Restarting containers in ${project_path}" "false"
    docker compose -f "${compose_file}" restart
    display --indent 6 --text "- Restarting containers" --result "DONE" --color GREEN
  fi

}

################################################################################
# Docker: Stop Containers Menu
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   nothing
################################################################################

function docker_stop_containers_menu() {

  local project_path="${1}"
  local compose_file="${project_path}/docker-compose.yml"

  whiptail --title "STOP CONTAINERS" --yesno "Are you sure you want to stop all containers?" 10 60 3>&1 1>&2 2>&3

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    log_event "info" "Stopping containers in ${project_path}" "false"
    docker compose -f "${compose_file}" stop
    display --indent 6 --text "- Stopping containers" --result "DONE" --color GREEN
  fi

}

################################################################################
# Docker: Start Containers Menu
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   nothing
################################################################################

function docker_start_containers_menu() {

  local project_path="${1}"
  local compose_file="${project_path}/docker-compose.yml"

  log_event "info" "Starting containers in ${project_path}" "false"
  docker compose -f "${compose_file}" start
  display --indent 6 --text "- Starting containers" --result "DONE" --color GREEN

}

################################################################################
# Docker: Execute Command Menu
#
# Arguments:
#   ${1} = ${project_path}
#
# Outputs:
#   nothing
################################################################################

function docker_exec_command_menu() {

  local project_path="${1}"
  local compose_file="${project_path}/docker-compose.yml"
  local container_name
  local command_to_exec

  # Get list of containers
  local containers
  containers="$(docker compose -f "${compose_file}" ps --services)"

  if [[ -z ${containers} ]]; then
    display --indent 6 --text "- No running containers found" --result "FAIL" --color RED
    return 1
  fi

  # Build menu
  local container_list=()
  local index=1
  while IFS= read -r container; do
    container_list+=("${index})" "${container}")
    ((index++))
  done <<< "${containers}"

  chosen_container="$(whiptail --title "SELECT CONTAINER" --menu "\nExecute command in:\n" 20 78 10 "${container_list[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then
    container_index="${chosen_container//[)]/}"
    container_name="$(echo "${containers}" | sed -n "${container_index}p")"

    command_to_exec="$(whiptail --title "EXECUTE COMMAND" --inputbox "Enter command to execute in ${container_name}:" 10 60 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && -n ${command_to_exec} ]]; then
      log_event "info" "Executing in ${container_name}: ${command_to_exec}" "false"
      docker compose -f "${compose_file}" exec "${container_name}" ${command_to_exec}
      echo ""
      read -n 1 -s -r -p "Press any key to continue"
    fi
  fi

}
