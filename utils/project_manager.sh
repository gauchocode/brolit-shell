#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc9
################################################################################
#
# Database Manager: Perform database actions.
#
################################################################################

################################################################################
# Project Utils Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function project_manager_menu_new_project_type_utils() {

  local whip_title
  local whip_description
  local project_utils_options
  local chosen_project_utils_options

  whip_title="PROJECT UTILS"
  whip_description=" "

  project_utils_options=(
    "01)" "CREATE NEW PROJECT"
    "02)" "DELETE PROJECT"
    "03)" "GENERATE PROJECT CONFIG"
    "04)" "CREATE PROJECT DB  & USER"
    "05)" "RENAME DATABASE"
    "06)" "PUT PROJECT ONLINE"
    "07)" "PUT PROJECT OFFLINE"
    "08)" "CREATE NGINX SERVER"
    "09)" "BENCH PROJECT GTMETRIX"
  )

  chosen_project_utils_options="$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${project_utils_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} = 0 ]]; then

    if [[ ${chosen_project_utils_options} == *"01"* ]]; then

      # CREATE NEW PROJECT
      project_manager_menu_new_project_type_new_project

    fi

    if [[ ${chosen_project_utils_options} == *"02"* ]]; then

      # DELETE PROJECT
      project_delete ""

    fi

    if [[ ${chosen_project_utils_options} == *"03"* ]]; then

      # GENERATE PROJECT CONFIG
      log_subsection "Project config"

      # Folder where sites are hosted: $PROJECTS_PATH
      menu_title="PROJECT TO WORK WITH"
      directory_browser "${menu_title}" "${PROJECTS_PATH}"

      # Directory_broser returns: " $filepath"/"$filename
      if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

        log_event "info" "Operation cancelled!" "false"

      else

        project_generate_brolit_config "${filepath}/${filename}"

      fi

    fi

    if [[ ${chosen_project_utils_options} == *"04"* ]]; then

      # CREATE PROJECT DB & USER
      log_subsection "Create Project DB & User"

      # Folder where sites are hosted: $PROJECTS_PATH
      menu_title="PROJECT TO WORK WITH"
      directory_browser "${menu_title}" "${PROJECTS_PATH}"

      # Directory_broser returns: $filepath"/"$filename
      if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

        log_event "info" "Operation cancelled!" "false"

      else

        project_stage="$(project_ask_stage "")"

        # Filename should be the project domain
        project_name="$(project_get_name_from_domain "${filename%/}")"
        project_name="$(mysql_name_sanitize "${project_name}")"
        project_name="$(project_ask_name "${project_name}")"

        exitstatus=$?
        if [[ ${exitstatus} -eq 1 ]]; then

          log_event "info" "Operation cancelled!" "false"
          display --indent 2 --text "- Creating project database" --result SKIPPED --color YELLOW

          return 1

        fi

        log_event "info" "project_name: ${project_name}" "false"

        # TODO: Ask for database engine?

        # Database
        database_user_passw="$(openssl rand -hex 12)"

        mysql_database_create "${project_name}_${project_stage}"
        mysql_user_db_scope="$(mysql_ask_user_db_scope)"
        mysql_user_create "${project_name}_user" "${database_user_passw}" "${mysql_user_db_scope}"
        mysql_user_grant_privileges "${project_name}_user" "${project_name}_${project_stage}" "${mysql_user_db_scope}"

        # TODO: Error check
        # TODO: Ask to update project config

        project_type="$(project_get_type "${filepath}/${filename}")"
        project_set_configured_database "${filepath}/${filename}" "${project_type}" "${project_name}_${project_stage}"
        project_set_configured_database_user "${filepath}/${filename}" "${project_type}" "${project_name}_user"
        project_set_configured_database_userpassw "${filepath}/${filename}" "${project_type}" "${database_user_passw}"

      fi

    fi

    if [[ ${chosen_project_utils_options} == *"05"* ]]; then

      # RENAME DATABASE

      local chosen_db
      local new_database_name

      chosen_db="$(mysql_ask_database_selection)"

      new_database_name="$(whiptail --title "Database Name" --inputbox "Insert a new database name (only separator allow is '_'). Old name was: ${chosen_db}" 10 60 "" 3>&1 1>&2 2>&3)"
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        log_event "debug" "Setting new_database_name: ${new_database_name}" "false"

        # Return
        echo "${new_database_name}"

      else
        return 1

      fi

      mysql_database_rename "${chosen_db}" "${new_database_name}"

    fi

    if [[ ${chosen_project_utils_options} == *"06"* ]]; then

      # PUT PROJECT ONLINE
      project_change_status "online"

    fi

    if [[ ${chosen_project_utils_options} == *"07"* ]]; then

      # PUT PROJECT OFFLINE
      project_change_status "offline"

    fi

    if [[ ${chosen_project_utils_options} == *"08"* ]]; then

      # REGENERATE NGINX SERVER
      project_create_nginx_server

    fi

    if [[ ${chosen_project_utils_options} == *"09"* ]]; then

      # BENCH PROJECT GTMETRIX

      URL_TO_TEST=$(whiptail --title "GTMETRIX TEST" --inputbox "Insert test URL including http:// or https://" 10 60 3>&1 1>&2 2>&3)

      exitstatus=$?
      if [[ ${exitstatus} = 0 ]]; then

        log_section "GTMETRIX"

        display --indent 2 --text "- Testing project ${URL_TO_TEST}"

        # shellcheck source=${BROLIT_MAIN_DIR}/tools/third-party/google-insights-api-tools/gitools_v5.sh
        gtmetrix_result="$("${BROLIT_MAIN_DIR}/tools/third-party/google-insights-api-tools/gitools_v5.sh" gtmetrix "${URL_TO_TEST}")"

        gtmetrix_results_url="$(echo "${gtmetrix_result}" | grep -Po '(?<=Report:)[^"]*' | head -1 | cut -d " " -f 2)"

        clear_previous_lines "1"
        display --indent 2 --text "- Testing project ${URL_TO_TEST}" --result DONE --color GREEN
        display --indent 4 --text "Please check results on ${MAGENTA}${gtmetrix_results_url}${ENDCOLOR}"
        #display --indent 4 --text "Please check results on log file" --tcolor MAGENTA
        log_event "info" "gtmetrix_result: ${gtmetrix_result}" "false"

      fi

    fi

    prompt_return_or_finish
    project_manager_menu_new_project_type_utils

  fi

  menu_main_options

}

################################################################################
# New Project Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function project_manager_menu_new_project_type_new_project() {

  local project_type_options
  local chosen_project_type_options
  local whip_title
  local whip_description

  whip_title="PROJECT UTILS"
  whip_description=" "

  project_type_options=(
    "01)" "CREATE WP PROJECT"
    "02)" "CREATE LARAVEL PROJECT"
    "03)" "CREATE OTHER PHP PROJECT"
    "04)" "CREATE NODE JS PROJECT"
  )

  chosen_project_type_options="$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${project_type_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} = 0 ]]; then

    if [[ ${chosen_project_type_options} == *"01"* ]]; then

      # WP PROJECT
      project_install "${PROJECTS_PATH}" "wordpress"

    fi

    if [[ ${chosen_project_type_options} == *"02"* ]]; then

      # LARAVEL PROJECT
      project_install "${PROJECTS_PATH}" "laravel"

    fi

    if [[ ${chosen_project_type_options} == *"03"* ]]; then

      # OTHER PHP PROJECT
      project_install "${PROJECTS_PATH}" "php"

    fi

    if [[ ${chosen_project_type_options} == *"04"* ]]; then

      # NODE JS PROJECT
      project_install "${PROJECTS_PATH}" "node-js"

    fi

  fi

}

################################################################################
# Project Manager Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function project_manager_menu_new_project_type() {

  local installation_types
  local project_type

  # Installation types
  installation_types="Laravel,PHP"

  project_type="$(whiptail --title "INSTALLATION TYPE" --menu "Choose an Installation Type" 20 78 10 "$(for x in ${installation_types}; do echo "$x [X]"; done)" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    project_install "${PROJECTS_PATH}" "${project_type}"

  fi

  menu_main_options

}

################################################################################
# Task handler for project functions
#
# Arguments:
#  $1 = ${subtask}
#  $2 = ${sites}
#  $3 = ${ptype}
#  $4 = ${domain}
#  $5 = ${pname}
#  $6 = ${pstate}
#
# Outputs:
#   global vars
################################################################################

function project_tasks_handler() {

  local subtask="${1}"
  local sites="${2}"
  local ptype="${3}"
  local domain="${4}"
  local pname="${5}"
  local pstate="${6}"

  case ${subtask} in

  install)

    project_install "${sites}" "${ptype}" "${domain}" "${pname}" "${pstate}"

    exit
    ;;

  delete)

    # Second parameter with "true" will delete cloudflare entry
    project_delete "${domain}" "true"

    exit
    ;;

  *)

    log_event "error" "INVALID PROJECT TASK: ${subtask}" "true"

    exit
    ;;

  esac

}
