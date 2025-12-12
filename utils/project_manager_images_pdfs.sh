#!/usr/bin/env bash
#
# Helper functions for image and PDF optimization in project manager
#

################################################################################
# Handle image optimization menu flow
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function _project_manager_optimize_images() {

  log_section "Project Utils"

  # Step 1: Ask if user wants specific project or all
  local scope_option
  scope_option="$(whiptail --title "IMAGE OPTIMIZATION SCOPE" --menu "\nSelect optimization scope:\n" 20 78 10 \
    "01)" "Select specific project" \
    "02)" "Optimize all WordPress projects" \
    3>&1 1>&2 2>&3)"

  local exitstatus=$?
  if [[ ${exitstatus} -ne 0 ]]; then
    return 1
  fi

  # Step 2: If specific project, show project selection
  local selected_project=""

  if [[ ${scope_option} == *"01"* ]]; then
    # Build list of WordPress projects
    local wordpress_projects=()

    for project_path in "${PROJECTS_PATH}"/*/; do
      [[ ! -d "${project_path}" ]] && continue

      local project_name
      project_name="$(basename "${project_path}")"

      # Check install type
      local project_install_type
      project_install_type="$(project_get_install_type "${project_path}")"

      # Check if WordPress
      local is_wordpress=false
      if [[ ${project_install_type} == "docker"* ]]; then
        local docker_data_dir
        docker_data_dir="$(project_get_configured_docker_data_dir "${project_path}")"
        [[ -f "${docker_data_dir}/wp-config.php" ]] && is_wordpress=true
      else
        [[ -f "${project_path}wp-config.php" ]] && is_wordpress=true
      fi

      [[ ${is_wordpress} == true ]] && wordpress_projects+=("${project_name}")
    done

    if [[ ${#wordpress_projects[@]} -eq 0 ]]; then
      display --indent 6 --text "- No WordPress projects found" --result "FAIL" --color RED
      return 1
    fi

    local chosen_project
    # Build menu items
    local menu_items=()
    for x in "${wordpress_projects[@]}"; do
      menu_items+=("${x}" "[WP]")
    done

    chosen_project="$(whiptail --title "Project Selection" --menu "Select the project you want to work with:" 20 78 10 "${menu_items[@]}" 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -ne 0 ]]; then
      return 1
    fi

    # Get full path
    selected_project="${PROJECTS_PATH}/${chosen_project}"
  fi

  # Step 3: Ask time filter preference
  local time_filter_option
  time_filter_option="$(whiptail --title "IMAGE OPTIMIZATION TIME FILTER" --menu "\nSelect which images to optimize:\n" 20 78 10 \
    "01)" "All images (regardless of modification date)" \
    "02)" "Only images modified in the last 7 days" \
    3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -ne 0 ]]; then
    return 1
  fi

  # Determine time filter
  local time_filter="all"
  [[ ${time_filter_option} == *"02"* ]] && time_filter="7"

  # Step 4: Execute optimization
  if [[ -n "${selected_project}" ]]; then
    optimize_images_complete "${selected_project}" "${time_filter}"
  else
    optimize_images_complete "" "${time_filter}"
  fi

  return 0
}

################################################################################
# Handle PDF optimization menu flow
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function _project_manager_optimize_pdfs() {

  log_section "Project Utils"

  # Step 1: Ask if user wants specific project or all
  local scope_option
  scope_option="$(whiptail --title "PDF OPTIMIZATION SCOPE" --menu "\nSelect optimization scope:\n" 20 78 10 \
    "01)" "Select specific project" \
    "02)" "Optimize all WordPress projects" \
    3>&1 1>&2 2>&3)"

  local exitstatus=$?
  if [[ ${exitstatus} -ne 0 ]]; then
    return 1
  fi

  # Step 2: If specific project, show project selection
  local selected_project=""

  if [[ ${scope_option} == *"01"* ]]; then
    # Build list of WordPress projects
    local wordpress_projects=()

    for project_path in "${PROJECTS_PATH}"/*/; do
      [[ ! -d "${project_path}" ]] && continue

      local project_name
      project_name="$(basename "${project_path}")"

      # Check install type
      local project_install_type
      project_install_type="$(project_get_install_type "${project_path}")"

      # Check if WordPress
      local is_wordpress=false
      if [[ ${project_install_type} == "docker"* ]]; then
        local docker_data_dir
        docker_data_dir="$(project_get_configured_docker_data_dir "${project_path}")"
        [[ -f "${docker_data_dir}/wp-config.php" ]] && is_wordpress=true
      else
        [[ -f "${project_path}wp-config.php" ]] && is_wordpress=true
      fi

      [[ ${is_wordpress} == true ]] && wordpress_projects+=("${project_name}")
    done

    if [[ ${#wordpress_projects[@]} -eq 0 ]]; then
      display --indent 6 --text "- No WordPress projects found" --result "FAIL" --color RED
      return 1
    fi

    local chosen_project
    # Build menu items
    local menu_items=()
    for x in "${wordpress_projects[@]}"; do
      menu_items+=("${x}" "[WP]")
    done

    chosen_project="$(whiptail --title "Project Selection" --menu "Select the project you want to work with:" 20 78 10 "${menu_items[@]}" 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -ne 0 ]]; then
      return 1
    fi

    # Get full path
    selected_project="${PROJECTS_PATH}/${chosen_project}"
  fi

  # Step 3: Ask time filter preference
  local time_filter_option
  time_filter_option="$(whiptail --title "PDF OPTIMIZATION TIME FILTER" --menu "\nSelect which PDFs to optimize:\n" 20 78 10 \
    "01)" "All PDFs (regardless of modification date)" \
    "02)" "Only PDFs modified in the last 7 days" \
    3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -ne 0 ]]; then
    return 1
  fi

  # Determine time filter
  local time_filter="all"
  [[ ${time_filter_option} == *"02"* ]] && time_filter="7"

  # Step 4: Execute optimization
  if [[ -n "${selected_project}" ]]; then
    optimize_pdfs "${selected_project}" "${time_filter}"
  else
    optimize_pdfs "" "${time_filter}"
  fi

  return 0
}
