#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.4
################################################################################
#
# Project Manager: Perform project actions.
#
################################################################################

function project_manager_config_loader() {

  local project_config_file="${1}"

  # Globals
  declare -g BROLIT_PROJECT_CONFIG_VERSION
  declare -g PROJECT_NAME

  BROLIT_PROJECT_CONFIG_VERSION="$(json_read_field "${project_config_file}" "brolit_project_config_version")"

  ## PROJECT
  PROJECT_NAME="$(json_read_field "${project_config_file}" "project[].name")"
  if [[ -z ${PROJECT_NAME} ]]; then
    # Error
    log_event "error" "Required var PROJECT_NAME not set!" "true" && exit 1
  fi

  PROJECT_STAGE="$(json_read_field "${project_config_file}" "project[].stage")"
  if [[ -z ${PROJECT_STAGE} ]]; then
    # Error
    log_event "error" "Required var PROJECT_STAGE not set!" "true" && exit 1
  fi

  PROJECT_TYPE="$(json_read_field "${project_config_file}" "project[].type")"
  if [[ -z ${PROJECT_TYPE} ]]; then
    # Error
    log_event "error" "Required var PROJECT_TYPE not set!" "true" && exit 1
  fi

  # Optional
  PROJECT_PROXY_TO_PORT="$(json_read_field "${project_config_file}" "project[].proxy_to_port")"
  # TODO: check if empty or is a valid number
  #if [[ -z ${PROJECT_PROXY_TO_PORT} ]]; then
  # Error
  #  exit 1
  #fi

  PROJECT_PRIMARY_SUBDOMAIN="$(json_read_field "${project_config_file}" "project[].primary_subdomain")"
  if [[ -z ${PROJECT_PRIMARY_SUBDOMAIN} ]]; then
    # Error
    log_event "error" "Required var PROJECT_PRIMARY_SUBDOMAIN not set!" "true" && exit 1
  fi

  # TODO: read array values
  #PROJECT_SECONDARY_SUBDOMAINS="$(json_read_field "${project_config_file}" "project[].primary_subdomain")"
  #if [[ -z ${PROJECT_SECONDARY_SUBDOMAINS} ]]; then
  # Error
  #  exit 1
  #fi

  PROJECT_USE_HTTP2="$(json_read_field "${project_config_file}" "project[].use_http2")"
  [[ -z ${PROJECT_USE_HTTP2} ]] && die "Required var PROJECT_USE_HTTP2 not set!"

  PROJECT_CERTBOT_MODE="$(json_read_field "${project_config_file}" "project[].certbot_mode")"
  [[ -z ${PROJECT_CERTBOT_MODE} ]] && die "Required var PROJECT_CERTBOT_MODE not set!"

  PROJECT_FILES_STATUS="$(json_read_field "${project_config_file}" "project[].files[].status")"
  if [[ ${PROJECT_FILES_STATUS} == "enabled" ]]; then

    PROJECT_FILES_CONFIG_PATH="$(json_read_field "${project_config_file}" "project[].files[].config[].path")"
    [[ -z ${PROJECT_FILES_CONFIG_PATH} ]] && die "Required var PROJECT_FILES_CONFIG_PATH not set!"

    PROJECT_FILES_CONFIG_HOST="$(json_read_field "${project_config_file}" "project[].files[].config[].path")"
    [[ -z ${PROJECT_FILES_CONFIG_HOST} ]] && die "Required var PROJECT_FILES_CONFIG_HOST not set!"

  fi

  PROJECT_DATABASE_STATUS="$(json_read_field "${project_config_file}" "project[].database[].status")"
  if [[ ${PROJECT_DATABASE_STATUS} == "enabled" ]]; then

    PROJECT_DATABASE_ENGINE="$(json_read_field "${project_config_file}" "project[].database[].engine")"
    [[ -z ${PROJECT_DATABASE_ENGINE} ]] && die "Required var PROJECT_DATABASE_ENGINE not set!"

    PROJECT_DATABASE_CONFIG_NAME="$(json_read_field "${project_config_file}" "project[].database[].config[].name")"
    [[ -z ${PROJECT_DATABASE_CONFIG_NAME} ]] && die "Required var PROJECT_DATABASE_CONFIG_NAME not set!"

    PROJECT_DATABASE_CONFIG_HOST="$(json_read_field "${project_config_file}" "project[].database[].config[].host")"
    [[ -z ${PROJECT_DATABASE_CONFIG_HOST} ]] && die "Required var PROJECT_DATABASE_CONFIG_HOST not set!"

    PROJECT_DATABASE_CONFIG_USER="$(json_read_field "${project_config_file}" "project[].database[].config[].user")"
    [[ -z ${PROJECT_DATABASE_CONFIG_USER} ]] && die "Required var PROJECT_DATABASE_CONFIG_USER not set!"

    PROJECT_DATABASE_CONFIG_PASS="$(json_read_field "${project_config_file}" "project[].database[].config[].pass")"
    [[ -z ${PROJECT_DATABASE_CONFIG_PASS} ]] && die "Required var PROJECT_DATABASE_CONFIG_PASS not set!"

  fi

  export BROLIT_PROJECT_CONFIG_VERSION PROJECT_NAME PROJECT_STAGE PROJECT_TYPE PROJECT_PROXY_TO_PORT
  export PROJECT_PRIMARY_SUBDOMAIN PROJECT_SECONDARY_SUBDOMAINS PROJECT_USE_HTTP2 PROJECT_CERTBOT_MODE
  export PROJECT_FILES_STATUS PROJECT_FILES_CONFIG_PATH PROJECT_FILES_CONFIG_HOST
  export PROJECT_DATABASE_STATUS PROJECT_DATABASE_ENGINE PROJECT_DATABASE_CONFIG_NAME PROJECT_DATABASE_CONFIG_HOST PROJECT_DATABASE_CONFIG_USER PROJECT_DATABASE_CONFIG_PASS

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

function project_manager_menu() {

  local whip_title
  local whip_description
  local project_manager_options
  local chosen_project_manager_option

  whip_title="PROJECT MANAGER"
  whip_description=" "

  project_manager_options=(
    "01)" "PROJECT CREATION"
    "02)" "RE-GENERATE PROJECT CONFIG"
    "03)" "RE-GENERATE NGINX SERVER"
    "04)" "CREATE PROJECT DB & USER"
    "05)" "PUT PROJECT ONLINE"
    "06)" "PUT PROJECT OFFLINE"
    "07)" "DELETE PROJECT"
  )

  chosen_project_manager_option="$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${project_manager_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # PROJECT CREATION
    [[ ${chosen_project_manager_option} == *"01"* ]] && project_creation_menu

    # RE-GENERATE PROJECT CONFIG
    if [[ ${chosen_project_manager_option} == *"02"* ]]; then
      log_section "Project Utils"
      log_subsection "Project config"

      menu_title="PROJECT TO WORK WITH"
      directory_browser "${menu_title}" "${PROJECTS_PATH}"

      if [[ -z "${filepath}" ]]; then
        log_event "info" "Operation cancelled!" "false"
      else
        project_generate_brolit_config "${filepath}/${filename}"
      fi

      prompt_return_or_finish
      project_manager_menu
    fi

    # RE-GENERATE NGINX SERVER
    if [[ ${chosen_project_manager_option} == *"03"* ]]; then
      project_create_nginx_server
      prompt_return_or_finish
      project_manager_menu
    fi

    # CREATE PROJECT DB & USER
    if [[ ${chosen_project_manager_option} == *"04"* ]]; then
      log_section "Project Utils"
      log_subsection "Create Project DB & User"

      menu_title="PROJECT TO WORK WITH"
      directory_browser "${menu_title}" "${PROJECTS_PATH}"

      if [[ -z "${filepath}" || "${filepath}" == "" ]]; then
        log_event "info" "Operation cancelled!" "false"
      else
        chosen_database_engine="$(database_ask_engine)"
        project_stage="$(project_ask_stage "")"
        [[ $? -eq 1 ]] && project_manager_menu && return 1

        project_name="$(project_get_name_from_domain "${filename%/}")"
        project_name="$(database_name_sanitize "${project_name}")"
        project_name="$(project_ask_name "${project_name}")"

        exitstatus=$?
        if [[ ${exitstatus} -eq 1 ]]; then
          log_event "info" "Operation cancelled!" "false"
          display --indent 2 --text "- Creating project database" --result SKIPPED --color YELLOW
          project_manager_menu
          return 1
        fi

        log_event "info" "project_name: ${project_name}" "false"

        database_user_passw="$(openssl rand -hex 12)"
        mysql_user_db_scope="$(mysql_ask_user_db_scope "localhost")"

        mysql_database_create "${project_name}_${project_stage}"
        mysql_user_create "${project_name}_user" "${database_user_passw}" "${mysql_user_db_scope}"
        mysql_user_grant_privileges "${project_name}_user" "${project_name}_${project_stage}" "${mysql_user_db_scope}"

        project_type="$(project_get_type "${filepath}/${filename}")"
        project_install_type="$(project_get_install_type "${filepath}/${filename}")"

        project_set_configured_database "${filepath}/${filename}" "${project_type}" "${project_install_type}" "${project_name}_${project_stage}"
        project_set_configured_database_user "${filepath}/${filename}" "${project_type}" "${project_install_type}" "${project_name}_user"
        project_set_configured_database_userpassw "${filepath}/${filename}" "${project_type}" "${project_install_type}" "${database_user_passw}"
      fi

      prompt_return_or_finish
      project_manager_menu
    fi

    # PUT PROJECT ONLINE
    if [[ ${chosen_project_manager_option} == *"05"* ]]; then
      project_change_status "online"
      prompt_return_or_finish
      project_manager_menu
    fi

    # PUT PROJECT OFFLINE
    if [[ ${chosen_project_manager_option} == *"06"* ]]; then
      project_change_status "offline"
      prompt_return_or_finish
      project_manager_menu
    fi

    # DELETE PROJECT (handles both standard and Docker projects)
    if [[ ${chosen_project_manager_option} == *"07"* ]]; then
      project_delete "" ""
      prompt_return_or_finish
      project_manager_menu
    fi

  fi

  menu_main_options

}

################################################################################
# Project Creation Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function project_creation_menu() {

  local project_creation_type_options
  local project_type_options
  local chosen_project_type_options
  local whip_title
  local whip_description

  # Whip menu vars
  whip_title="PROJECT CREATION"
  whip_description=" "

  project_creation_type_options=(
    "01)" "NEW PROJECT"
    "02)" "NEW PROJECT FROM BACKUP"
    "03)" "NEW PROJECT FROM GIT REPOSITORY (DOCKER)"
    "04)" "DOCKERIZE PROJECT FROM BACKUP"
  )

  chosen_project_creation_type_option="$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${project_creation_type_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # NEW PROJECT
    if [[ ${chosen_project_creation_type_option} == *"01"* ]]; then

      project_type_options=(
        "01)" "NEW WORDPRESS PROJECT"
        "02)" "NEW WORDPRESS PROJECT (DOCKER)"
        "03)" "NEW PHP PROJECT"
        "04)" "NEW PHP PROJECT (DOCKER) -BETA-"
      )

      chosen_project_type_options="$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${project_type_options[@]}" 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # NEW WORDPRESS PROJECT
        [[ ${chosen_project_type_options} == *"01"* ]] && project_install "${PROJECTS_PATH}" "wordpress" "" "" "" "clean"

        # NEW WORDPRESS PROJECT (DOCKER)
        [[ ${chosen_project_type_options} == *"02"* ]] && docker_project_install "${PROJECTS_PATH}" "wordpress" ""

        # NEW PHP PROJECT
        [[ ${chosen_project_type_options} == *"03"* ]] && project_install "${PROJECTS_PATH}" "php" "" "" "" "clean"

        # NEW PHP PROJECT (DOCKER) -BETA-
        [[ ${chosen_project_type_options} == *"04"* ]] && docker_project_install "${PROJECTS_PATH}" "php" ""

      fi

    fi

    # NEW PROJECT FROM BACKUP
    if [[ ${chosen_project_creation_type_option} == *"02"* ]]; then

      chosen_domain="$(whiptail --title "Project Domain" --inputbox "New project's domain:" 10 60 "" 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Check if domain is a valid domainname
        if [[ ! "${chosen_domain}" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then

          # Log
          display --indent 6 --text "- Domain is not valid" --result FAIL --color RED
          log_event "error" "Domain is not valid" "false"

          prompt_return_or_finish
          project_creation_menu

        fi

        # Log
        log_event "info" "Working with domain: ${chosen_domain}"
        display --indent 6 --text "- Selecting project domain" --result "DONE" --color GREEN
        display --indent 8 --text "${chosen_domain}" --tcolor YELLOW

        # Restore backup from storage
        restore_backup_from_storage "${chosen_domain}"

      else

        return 1

      fi

    fi

    # NEW PROJECT FROM GIT REPOSITORY
    if [[ ${chosen_project_creation_type_option} == *"03"* ]]; then
      docker_project_install_from_git "${PROJECTS_PATH}" "" "" ""
    fi

    # DOCKERIZE EXISTING PROJECT
    if [[ ${chosen_project_creation_type_option} == *"04"* ]]; then
      project_dockerize_from_backup
    fi

  fi

  project_manager_menu

}

################################################################################
# Task handler for project functions
#
# Arguments:
#  ${1} = ${subtask}
#  ${2} = ${sites}
#  ${3} = ${ptype}
#  ${4} = ${domain}
#  ${5} = ${pname}
#  ${6} = ${pstate}
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

  #  install)
  #
  #    project_install "${sites}" "${ptype}" "${domain}" "${pname}" "${pstate}"
  #
  #    exit
  #    ;;

  delete)

    # Second parameter with "true" will delete cloudflare entry
    project_delete "${domain}" "true"

    exit $? # exit with the exit code
    ;;

  *)

    die "INVALID PROJECT TASK: ${subtask}"

    ;;

  esac

}

################################################################################
# Task handler for project functions
#
# Arguments:
#  ${1} = ${subtask}
#  ${2} = ${sites}
#  ${3} = ${ptype}
#  ${4} = ${domain}
#  ${5} = ${pname}
#  ${6} = ${pstate}
#
# Outputs:
#   global vars
################################################################################

function project_install_tasks_handler() {

  local project_config_file="${1}"
  local project_install_type="${2}"

  if [[ ! -f ${project_config_file} ]]; then

    die "Project config file not found! Wrong path?"

  else

    # Load config file
    project_manager_config_loader "${project_config_file}"
    log_event "debug" "PROJECT_FILES_CONFIG_PATH=${PROJECT_FILES_CONFIG_PATH}" "false"
    log_event "debug" "PROJECT_TYPE=${PROJECT_TYPE}" "false"
    log_event "debug" "PROJECT_PRIMARY_SUBDOMAIN=${PROJECT_PRIMARY_SUBDOMAIN}" "false"
    log_event "debug" "PROJECT_NAME=${PROJECT_NAME}" "false"
    log_event "debug" "PROJECT_STAGE=${PROJECT_STAGE}" "false"

  fi

  case ${project_install_type} in

  clean)

    project_install "${PROJECT_FILES_CONFIG_PATH}" "${PROJECT_TYPE}" "${PROJECT_PRIMARY_SUBDOMAIN}" "${PROJECT_NAME}" "${PROJECT_STAGE}" "${project_install_type}"

    exit $? # exit with the exit code
    ;;

  copy)

    #project_install "${sites}" "${ptype}" "${domain}" "${pname}" "${pstate}"
    die "Create new project from a template should be implemented"

    ;;

  *)

    die "Invalid project install type: ${project_install_type}"

    ;;

  esac

}

################################################################################
# Dockerize Project from Backup
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function project_dockerize_from_backup() {

  local chosen_server
  local chosen_remote_status
  local chosen_remote_type
  local chosen_remote_type_path
  local remote_list
  local backup_to_download
  local backup_to_restore
  local chosen_project
  local project_domain

  log_subsection "Dockerizing Project from Backup"

  # Backup Server selection
  chosen_server="$(storage_remote_server_list)"
  exitstatus=$?
  if [[ ${exitstatus} -ne 0 || -z "${chosen_server}" ]]; then
    log_event "error" "No server selected or operation cancelled" "false"
    display --indent 6 --text "- Selecting backup server" --result "SKIPPED" --color YELLOW
    return 1
  fi
  display --indent 6 --text "- Selected server: ${chosen_server}" --result "DONE" --color GREEN

  # List status options
  chosen_remote_status="$(storage_remote_status_list)"
  if [[ -z "${chosen_remote_status}" ]]; then
    log_event "error" "No status selected or operation cancelled" "false"
    display --indent 6 --text "- Selecting status" --result "SKIPPED" --color YELLOW
    return 1
  fi
  display --indent 6 --text "- Selected status: ${chosen_remote_status}" --result "DONE" --color GREEN

  # List type options
  chosen_remote_type="$(storage_remote_type_list)"
  if [[ -z "${chosen_remote_type}" ]]; then
    log_event "error" "No type selected or operation cancelled" "false"
    display --indent 6 --text "- Selecting type" --result "SKIPPED" --color YELLOW
    return 1
  fi
  display --indent 6 --text "- Selected type: ${chosen_remote_type}" --result "DONE" --color GREEN

  chosen_remote_type_path="${chosen_server}/projects-${chosen_remote_status}/${chosen_remote_type}"
  remote_list="$(dirname "${chosen_remote_type_path}")"

  # Select project backup
  backup_to_download="$(storage_backup_selection "${remote_list}" "site")"
  if [[ -z "${backup_to_download}" ]]; then
    log_event "error" "No backup selected or operation cancelled" "false"
    display --indent 6 --text "- Selecting backup" --result "SKIPPED" --color YELLOW
    return 1
  fi

  # Download backup
  storage_download_backup "${backup_to_download}" "${BROLIT_TMP_DIR}"
  if [[ $? -eq 1 ]]; then
    log_event "error" "Failed to download backup: ${backup_to_download}" "true"
    display --indent 6 --text "- Downloading Project Backup" --result "ERROR" --color RED
    return 1
  fi

  # Get backup file name
  backup_to_restore="$(basename "${backup_to_download}")"

  # Get project_domain
  chosen_project="$(dirname "${backup_to_download}")"
  project_domain="$(basename "${chosen_project}")"

  # Validate domain
  if [[ ! "${project_domain}" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
    log_event "error" "Invalid domain extracted: ${project_domain}" "true"
    display --indent 6 --text "Invalid domain extracted: ${project_domain}" --result "ERROR" --color RED
    return 1
  fi
  display --indent 8 --text "Project domain: ${project_domain}" --tcolor GREEN

  # Check if project already exists
  if [[ -d "${PROJECTS_PATH}/${project_domain}" ]]; then
    log_event "error" "Project directory already exists: ${PROJECTS_PATH}/${project_domain}" "true"
    display --indent 6 --text "- Project directory already exists" --result "ERROR" --color RED
    return 1
  fi

  # Docker restore project
  docker_restore_project "${backup_to_restore}" "${chosen_remote_status}" "${chosen_server}" "${project_domain}" ""
  if [[ $? -eq 0 ]]; then
    display --indent 6 --text "- Dockerizing project" --result "DONE" --color GREEN
    log_event "info" "Successfully dockerized project from backup: ${project_domain}" "false"
  else
    log_event "error" "Failed to dockerize project from backup: ${project_domain}" "true"
    display --indent 6 --text "- Dockerizing project" --result "ERROR" --color RED
    return 1
  fi

  prompt_return_or_finish
}
