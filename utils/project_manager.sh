#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.3.0-beta
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
  if [[ -z ${PROJECT_USE_HTTP2} ]]; then
    # Error
    log_event "error" "Required var PROJECT_USE_HTTP2 not set!" "true" && exit 1
  fi

  PROJECT_CERTBOT_MODE="$(json_read_field "${project_config_file}" "project[].certbot_mode")"
  if [[ -z ${PROJECT_CERTBOT_MODE} ]]; then
    # Error
    log_event "error" "Required var PROJECT_CERTBOT_MODE not set!" "true" && exit 1
  fi

  PROJECT_FILES_STATUS="$(json_read_field "${project_config_file}" "project[].files[].status")"
  if [[ ${PROJECT_FILES_STATUS} == "enabled" ]]; then

    PROJECT_FILES_CONFIG_PATH="$(json_read_field "${project_config_file}" "project[].files[].config[].path")"
    if [[ -z ${PROJECT_FILES_CONFIG_PATH} ]]; then
      # Error
      exit 1
    fi

    PROJECT_FILES_CONFIG_HOST="$(json_read_field "${project_config_file}" "project[].files[].config[].path")"
    if [[ -z ${PROJECT_FILES_CONFIG_HOST} ]]; then
      # Error
      exit 1
    fi

  fi

  PROJECT_DATABASE_STATUS="$(json_read_field "${project_config_file}" "project[].database[].status")"
  if [[ ${PROJECT_DATABASE_STATUS} == "enabled" ]]; then

    PROJECT_DATABASE_ENGINE="$(json_read_field "${project_config_file}" "project[].database[].engine")"
    if [[ -z ${PROJECT_DATABASE_ENGINE} ]]; then
      # Error
      exit 1
    fi

    PROJECT_DATABASE_CONFIG_NAME="$(json_read_field "${project_config_file}" "project[].database[].config[].name")"
    if [[ -z ${PROJECT_DATABASE_CONFIG_NAME} ]]; then
      # Error
      exit 1
    fi

    PROJECT_DATABASE_CONFIG_HOST="$(json_read_field "${project_config_file}" "project[].database[].config[].host")"
    if [[ -z ${PROJECT_DATABASE_CONFIG_HOST} ]]; then
      # Error
      exit 1
    fi

    PROJECT_DATABASE_CONFIG_USER="$(json_read_field "${project_config_file}" "project[].database[].config[].user")"
    if [[ -z ${PROJECT_DATABASE_CONFIG_USER} ]]; then
      # Error
      exit 1
    fi

    PROJECT_DATABASE_CONFIG_PASS="$(json_read_field "${project_config_file}" "project[].database[].config[].pass")"
    if [[ -z ${PROJECT_DATABASE_CONFIG_PASS} ]]; then
      # Error
      exit 1
    fi

  fi

  export BROLIT_PROJECT_CONFIG_VERSION PROJECT_NAME PROJECT_STAGE PROJECT_TYPE PROJECT_PROXY_TO_PORT
  export PROJECT_PRIMARY_SUBDOMAIN PROJECT_SECONDARY_SUBDOMAINS PROJECT_USE_HTTP2 PROJECT_CERTBOT_MODE
  export PROJECT_FILES_STATUS PROJECT_FILES_CONFIG_PATH PROJECT_FILES_CONFIG_HOST
  export PROJECT_DATABASE_STATUS PROJECT_DATABASE_ENGINE PROJECT_DATABASE_CONFIG_NAME PROJECT_DATABASE_CONFIG_HOST PROJECT_DATABASE_CONFIG_USER PROJECT_DATABASE_CONFIG_PASS

}

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
    "01)" "RE-GENERATE PROJECT CONFIG"
    "02)" "RE-GENERATE NGINX SERVER"
    "03)" "DELETE PROJECT"
    "04)" "CREATE PROJECT DB  & USER"
    "05)" "RENAME DATABASE"
    "06)" "PUT PROJECT ONLINE"
    "07)" "PUT PROJECT OFFLINE"
    "08)" "BENCH PROJECT GTMETRIX"
    #"09)" "DOCKERIZE EXISTING PROJECT"
  )

  chosen_project_utils_options="$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${project_utils_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # RE-GENERATE PROJECT CONFIG
    if [[ ${chosen_project_utils_options} == *"01"* ]]; then

      log_subsection "Project config"

      # Folder where sites are hosted: $PROJECTS_PATH
      menu_title="PROJECT TO WORK WITH"
      directory_browser "${menu_title}" "${PROJECTS_PATH}"

      # Directory_broser returns: " $filepath"/"$filename
      if [[ -z "${filepath}" ]]; then

        log_event "info" "Operation cancelled!" "false"

      else

        project_generate_brolit_config "${filepath}/${filename}"

      fi

    fi

    # RE-GENERATE NGINX SERVER
    [[ ${chosen_project_utils_options} == *"02"* ]] && project_create_nginx_server

    # DELETE PROJECT
    [[ ${chosen_project_utils_options} == *"03"* ]] && project_delete "" ""

    # CREATE PROJECT DB  & USER
    if [[ ${chosen_project_utils_options} == *"04"* ]]; then

      log_subsection "Create Project DB & User"

      # Folder where sites are hosted: $PROJECTS_PATH
      menu_title="PROJECT TO WORK WITH"
      directory_browser "${menu_title}" "${PROJECTS_PATH}"

      # Directory_broser returns: $filepath"/"$filename
      if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

        log_event "info" "Operation cancelled!" "false"

      else

        project_stage="$(project_ask_stage "")"
        [[ $? -eq 1 ]] && return 1

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
        project_install_type="$(project_get_install_type "${filepath}/${filename}")"
        project_set_configured_database "${filepath}/${filename}" "${project_type}" "${project_install_type}" "${project_name}_${project_stage}"
        project_set_configured_database_user "${filepath}/${filename}" "${project_type}" "${project_install_type}" "${project_name}_user"
        project_set_configured_database_userpassw "${filepath}/${filename}" "${project_type}" "${project_install_type}" "${database_user_passw}"

      fi

    fi

    # RENAME DATABASE
    if [[ ${chosen_project_utils_options} == *"05"* ]]; then

      local chosen_db
      local new_database_name

      chosen_db="$(mysql_ask_database_selection)"

      new_database_name="$(whiptail_input "Database Name" "Insert a new database name (only separator allow is '_'). Old name was: ${chosen_db}" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        log_event "debug" "Setting new_database_name: ${new_database_name}" "false"

        # Return
        #echo "${new_database_name}"
        mysql_database_rename "${chosen_db}" "${new_database_name}"

      else

        return 1

      fi

    fi

    # PUT PROJECT ONLINE
    [[ ${chosen_project_utils_options} == *"06"* ]] && project_change_status "online"

    # PUT PROJECT OFFLINE
    [[ ${chosen_project_utils_options} == *"07"* ]] && project_change_status "offline"

    # BENCH PROJECT GTMETRIX
    if [[ ${chosen_project_utils_options} == *"08"* ]]; then

      URL_TO_TEST=$(whiptail --title "GTMETRIX TEST" --inputbox "Insert test URL including http:// or https://" 10 60 3>&1 1>&2 2>&3)

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        log_section "GTMETRIX"

        display --indent 2 --text "- Testing project ${URL_TO_TEST}"

        # shellcheck source=${BROLIT_MAIN_DIR}/tools/third-party/google-insights-api-tools/gitools_v5.sh
        gtmetrix_result="$("${BROLIT_MAIN_DIR}/tools/third-party/google-insights-api-tools/gitools_v5.sh" gtmetrix "${URL_TO_TEST}")"

        gtmetrix_results_url="$(echo "${gtmetrix_result}" | grep -Po '(?<=Report:)[^"]*' | head -1 | cut -d " " -f 2)"

        clear_previous_lines "1"
        display --indent 2 --text "- Testing project ${URL_TO_TEST}" --result DONE --color GREEN
        display --indent 4 --text "Please check results on:"
        display --indent 4 --text "${gtmetrix_results_url}" --tcolor MAGENTA
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

  local project_creation_type_options
  local project_type_options
  local chosen_project_type_options
  local whip_title
  local whip_description

  # Whip menu vars
  whip_title="PROJECT CREATION"
  whip_description=" "

  # NEW
  project_creation_type_options=(
    "01)" "NEW PROJECT"
    "02)" "NEW PROJECT FROM BACKUP"
    #"03)" "NEW PROJECT FROM GIT REPOSITORY"
  )

  chosen_project_creation_type_option="$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${project_creation_type_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # NEW PROJECT
    if [[ ${chosen_project_creation_type_option} == *"01"* ]]; then

      project_type_options=(
        "01)" "NEW WORDPRESS PROJECT"
        "02)" "NEW LARAVEL PROJECT"
        "03)" "NEW PHP PROJECT"
        "04)" "NEW NODEJS PROJECT"
        "05)" "NEW WORDPRESS PROJECT (DOCKER) -BETA-"
        "06)" "NEW PHP PROJECT (DOCKER) -BETA-"
      )

      chosen_project_type_options="$(whiptail --title "${whip_title}" --menu "${whip_description}" 20 78 10 "${project_type_options[@]}" 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # NEW WORDPRESS PROJECT
        [[ ${chosen_project_type_options} == *"01"* ]] && project_install "${PROJECTS_PATH}" "wordpress"

        # NEW LARAVEL PROJECT
        [[ ${chosen_project_type_options} == *"02"* ]] && project_install "${PROJECTS_PATH}" "laravel"

        # NEW PHP PROJECT
        [[ ${chosen_project_type_options} == *"03"* ]] && project_install "${PROJECTS_PATH}" "php"

        # NEW NODEJS PROJECT
        [[ ${chosen_project_type_options} == *"04"* ]] && project_install "${PROJECTS_PATH}" "nodejs"

        # NEW WORDPRESS PROJECT (DOCKER) -BETA-
        [[ ${chosen_project_type_options} == *"05"* ]] && docker_project_install "${PROJECTS_PATH}" "wordpress"

        # NEW PHP PROJECT (DOCKER) -BETA-
        [[ ${chosen_project_type_options} == *"06"* ]] && docker_project_install "${PROJECTS_PATH}" "php"

      fi

    fi

    # NEW PROJECT FROM BACKUP
    if [[ ${chosen_project_creation_type_option} == *"02"* ]]; then

      # TODO:
      # 1- Ask for project domain
      chosen_domain="$(whiptail --title "Project Domain" --inputbox "Want to change the project's domain? Default:" 10 60 "${domain}" 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        log_event "info" "Working with domain: ${chosen_domain}"
        display --indent 6 --text "- Selecting project domain" --result "DONE" --color GREEN
        display --indent 8 --text "${chosen_domain}" --tcolor YELLOW

        # NEW NEW NEW NEW
        #restore_project_selection "${chosen_domain}"
        restore_backup_from_storage "${chosen_domain}"

      else

        return 1

      fi

    fi

    # TODO: move to another function
    # DOCKERIZE EXISTING PROJECT
    if [[ ${chosen_project_creation_type_option} == *"04"* ]]; then
      # TODO: need to change this!
      # If a directory exists, get project type & installation type
      if [[ -d "${PROJECTS_PATH}/${chosen_project}" ]]; then
        project_type="$(project_get_type "${PROJECTS_PATH}/${chosen_project}")"
        project_install_type="$(project_get_install_type "${PROJECTS_PATH}/${chosen_project}")"
      fi

      # TODO: if project type==docker download, extract, move to /var/www, run docker commands, execute domain tasks
      # TODO: if project type!=wordpress then... needs implementation
      if [[ ${PACKAGES_DOCKER_STATUS} == "enabled" && ${project_install_type} == "docker-compose" && ${project_type} == "wordpress" ]]; then

        if [[ -d "${PROJECTS_PATH}/${chosen_project}" ]]; then

          # Warning message
          whiptail --title "Warning" --yesno "A docker project already exist for this domain. Do you want to restore the current backup on this docker stack? A backup of current directory will be stored on BROLIT tmp folder." 10 60 3>&1 1>&2 2>&3

          exitstatus=$?
          if [[ ${exitstatus} -eq 0 ]]; then

            # Backup old project
            _create_tmp_copy "${PROJECTS_PATH}/${chosen_project}" "copy"
            got_error=$?
            [[ ${got_error} -eq 1 ]] && return 1

          else

            # Log
            log_event "info" "The project directory already exist. User skipped operation." "false"
            display --indent 6 --text "- Restore files" --result "SKIPPED" --color YELLOW

            return 1

          fi

          installation_type="docker"

          # Remove actual wordpress files
          #rm -R "${PROJECTS_PATH}/${chosen_project}/wordpress/wp-content"
          rm -R "${PROJECTS_PATH}/${chosen_project}/wordpress"

          #move_files "${BROLIT_TMP_DIR}/${chosen_project}/wp-content" "${PROJECTS_PATH}/${chosen_project}/wordpress"
          move_files "${BROLIT_TMP_DIR}/${chosen_project}" "${PROJECTS_PATH}/${chosen_project}/wordpress"

          display --indent 6 --text "- Import files into docker volume" --result "DONE" --color GREEN

          # TODO: update this to match monthly and weekly backups
          project_name="$(project_get_name_from_domain "${chosen_project}")"
          project_stage="$(project_get_stage_from_domain "${chosen_project}")"

          db_name="${project_name}_${project_stage}"
          new_project_domain="${chosen_project}"

          project_backup_date="$(backup_get_date "${chosen_backup_to_restore}")"

          db_to_download="${chosen_server}/projects-${chosen_status}/database/${db_name}/${db_name}_database_${project_backup_date}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
          db_to_restore="${db_name}_database_${project_backup_date}.${BACKUP_CONFIG_COMPRESSION_EXTENSION}"
          project_backup="${db_to_restore%%.*}.sql"

          # Downloading Database Backup
          storage_download_backup "${db_to_download}" "${BROLIT_TMP_DIR}"

          # Decompress
          decompress "${BROLIT_TMP_DIR}/${db_to_restore}" "${BROLIT_TMP_DIR}" "${BACKUP_CONFIG_COMPRESSION_TYPE}"

          # Read wp-config to get WP DATABASE PREFIX and replace on docker .env file
          #database_prefix_to_restore="$(wp_config_get_option "${BROLIT_TMP_DIR}/${chosen_project}" "table_prefix")"
          database_prefix_to_restore="$(cat "${BROLIT_TMP_DIR}/${chosen_project}"/wp-config.php | grep "\$table_prefix" | cut -d \' -f 2)"
          database_prefix_actual="$(project_get_config_var "${PROJECTS_PATH}/${chosen_project}/.env" "WORDPRESS_TABLE_PREFIX")"
          if [[ ${database_prefix_to_restore} != "${database_prefix_actual}" ]]; then
            # Set new database prefix
            project_set_config_var "${PROJECTS_PATH}/${chosen_project}/.env" "WORDPRESS_TABLE_PREFIX" "${database_prefix_to_restore}" "double"
            # Rebuild docker image
            docker-compose -f "${PROJECTS_PATH}/${chosen_project}/docker-compose.yml" up --detach
            # Clear screen output
            clear_previous_lines "3"
          fi

          # TODO: update wp-config.php with .env docker stack credentials

          # Read .env to get mysql pass
          db_user_pass="$(project_get_config_var "${PROJECTS_PATH}/${chosen_project}/.env" "MYSQL_PASSWORD")"

          # Docker MySQL database import
          docker_mysql_database_import "${project_name}_mysql" "${project_name}_user" "${db_user_pass}" "${project_name}_prod" "${BROLIT_TMP_DIR}/${project_backup}"

          display --indent 6 --text "- Import database into docker volume" --result "DONE" --color GREEN

        else

          log_event "error" "Should implement restore without existing docker image!" "true"

          return 1

        fi

      fi

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

  local project_types
  local project_type

  # Installation types
  project_types="Laravel,PHP"

  project_type="$(whiptail --title "NEW PROJECT TYPE" --menu "Choose an Installation Type" 20 78 10 "$(for x in ${project_types}; do echo "$x [X]"; done)" 3>&1 1>&2 2>&3)"
  exitstatus=$?
  [[ ${exitstatus} -eq 0 ]] && project_install "${PROJECTS_PATH}" "${project_type}"

  menu_main_options

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

    log_event "error" "INVALID PROJECT TASK: ${subtask}" "true"

    exit 1
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
    log_event "error" "Project config file not found! Wrong path?" "true"
    exit 1
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
    log_event "error" "Create new project from a template should be implemented." "true"

    exit 1
    ;;

  *)

    log_event "error" "Invalid project install type: ${project_install_type}" "true"

    exit 1
    ;;

  esac

}
