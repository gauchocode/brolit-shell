#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.6
################################################################################
#
# Project Helper: Perform project actions.
#
################################################################################

################################################################################
# Ask project state
#
# Arguments:
#   $1 = ${suggested_state} - optional to select default option#
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function ask_project_state() {

  local suggested_state=$1

  local project_states
  local project_state

  project_states="prod demo stage test beta dev"

  project_state="$(whiptail --title "Project Stage" --menu "Choose Project Stage" 20 78 10 $(for x in ${project_states}; do echo "$x [X]"; done) --default-item "${suggested_state}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Return
    echo "${project_state}"

    return 0

  else

    return 1

  fi

}

################################################################################
# Ask project name
#
# Arguments:
#   $1 = ${project_name} - optional to select default option
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function ask_project_name() {

  local project_name=$1

  local possible_name

  # Replace '-' and '.' chars
  possible_name="$(echo "${project_name}" | sed -r 's/[.-]+/_/g')"

  project_name="$(whiptail --title "Project Name" --inputbox "Insert a project name (only separator allow is '_'). Ex: my_domain" 10 60 "${possible_name}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    log_event "info" "Project name: ${project_name}" "false"

    # Return
    echo "${project_name}"

  else

    return 1

  fi

}

################################################################################
# Ask project domain
#
# Arguments:
#   $1 = ${project_domain} - optional to select default option
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# TODO: project_domain should be an array?
function ask_project_domain() {

  local project_domain=$1

  project_domain="$(whiptail --title "Domain" --inputbox "Insert the project's domain. Example: landing.domain.com" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Return
    echo "${project_domain}"

  else

    return 1

  fi

}

################################################################################
# Ask project type
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function ask_project_type() {

  local project_types
  local project_type

  project_types="WordPress X Laravel X Basic-PHP X HTML X"

  project_type="$(whiptail --title "SELECT PROJECT TYPE" --menu " " 20 78 10 $(for x in ${project_types}; do echo "$x"; done) 3>&1 1>&2 2>&3)"
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Lowercase
    project_type="$(echo "${project_type}" | tr '[A-Z]' '[a-z]')"

    # Return
    echo "${project_type}"

  else
    return 1

  fi

}

################################################################################
# Ask projects main directory
#
# Arguments:
#   $1 = ${folder_to_install}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function ask_folder_to_install_sites() {

  local folder_to_install=$1

  if [[ -z "${folder_to_install}" ]]; then

    folder_to_install="$(whiptail --title "Folder to work with" --inputbox "Please select the project folder you want to work with:" 10 60 "${folder_to_install}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      log_event "info" "Folder to work with: ${folder_to_install}" "false"

      # Return
      echo "${folder_to_install}"

    else
      return 1

    fi

  else

    log_event "info" "Folder to install: ${folder_to_install}" "false"

    # Return
    echo "${folder_to_install}"

  fi

}

################################################################################
# Get project name from domain
#
# Arguments:
#   $1 = ${project_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_get_name_from_domain() {

  local project_domain=$1

  local project_stages
  local possible_project_name

  declare -a possible_project_stages_on_subdomain=("www" "demo" "stage" "test" "beta" "dev")

  # Extract project name from domain
  possible_project_name="$(extract_domain_extension "${project_domain}")"

  # Remove stage from domain
  for p in "${possible_project_stages_on_subdomain[@]}"; do

    possible_project_name="$(echo "${possible_project_name}" | sed -r "s/${p}.//g")"

  done

  # Replace '-' and '.' chars with '_'
  possible_project_name="$(echo "${possible_project_name}" | sed -r 's/[.-]+/_/g')"

  # Return
  echo "${possible_project_name}"

}

################################################################################
# Get project stage from domain
#
# Arguments:
#   $1 = ${project_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_get_stage_from_domain() {

  local project_domain=$1

  local project_stages
  local possible_project_stage

  project_stages="demo stage test beta dev"

  # Trying to extract project state from domain
  subdomain_part="$(get_subdomain_part "${project_domain}")"
  possible_project_stage="$(echo "${subdomain_part}" | cut -d "." -f 1)"

  # Log
  log_event "debug" "subdomain_part=${subdomain_part}" "false"
  log_event "debug" "possible_project_stage=${possible_project_stage}" "false"

  if [[ ${project_stages} != *"${possible_project_stage}"* || ${possible_project_stage} == "" ]]; then

    possible_project_stage="prod"

  fi

  # Return
  echo "${possible_project_stage}"

}

################################################################################
# Create project config file
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${project_name}
#  $3 = ${project_stage}
#  $4 = ${project_type}
#  $5 = ${project_db_status}
#  $6 = ${project_db_engine}
#  $7 = ${project_db_name}
#  $8 = ${project_db_host}
#  $9 = ${project_db_user}
#  $10 = ${project_db_pass}
#  $11 = ${project_prymary_subdomain}
#  $12 = ${project_secondary_subdomains}
#  $13 = ${project_override_nginx_conf}
#  $14 = ${project_use_http2}
#  $15 = ${project_certbot_mode}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_create_config() {

  local project_path=${1}
  local project_name=${2}
  local project_stage=${3}
  local project_type=${4}
  local project_db_status=${5}
  local project_db_engine=${6}
  local project_db_name=${7}
  local project_db_host=${8}
  local project_db_user=${9}
  local project_db_pass=${10}
  local project_prymary_subdomain=${11}
  local project_secondary_subdomains=${12}
  local project_override_nginx_conf=${13}
  local project_use_http2=${14}
  local project_certbot_mode=${15}

  local project_config_file

  # Project config file
  project_config_file="${BROLIT_CONFIG_PATH}/${project_name}_conf.json"

  if [[ -e ${project_config_file} ]]; then

    # Log
    display --indent 6 --text "- Project config file already exists" --result WARNING --color YELLOW
    display --indent 8 --text "Updating config file ..." --result WARNING --color YELLOW --tstyle ITALIC

  else

    # Copy empty config file
    cp "${SFOLDER}/config/brolit/brolit_project_conf.json" "${project_config_file}"

  fi

  # Write config file
  ## Doc: https://stackoverflow.com/a/61049639/2267761

  ## project path
  json_write_field "${project_config_file}" "project[].path" "${project_path}"

  ## project name
  json_write_field "${project_config_file}" "project[].name" "${project_name}"

  ## project stage
  json_write_field "${project_config_file}" "project[].stage" "${project_stage}"

  ## project type
  json_write_field "${project_config_file}" "project[].type" "${project_type}"

  ## project database status
  json_write_field "${project_config_file}" "project[].database[].status" "${project_db_status}"

  ## project database engine
  json_write_field "${project_config_file}" "project[].database[].status" "${project_db_engine}"

  ## project database config name
  json_write_field "${project_config_file}" "project[].database[].config[].name" "${project_db_name}"

  ## project database config host
  json_write_field "${project_config_file}" "project[].database[].config[].host" "${project_db_host}"

  ## project database config user
  json_write_field "${project_config_file}" "project[].database[].config[].user" "${project_db_user}"

  ## project database config pass
  json_write_field "${project_config_file}" "project[].database[].config[].pass" "${project_db_pass}"

  ## project primary_subdomain
  json_write_field "${project_config_file}" "project[].primary_subdomain" "${project_prymary_subdomain}"

  ## project secondary_subdomains
  ## TODO
  #json_write_field "${project_config_file}" "project[].secondary_subdomains[]" "${project_secondary_subdomains}"

  ## project override_nginx_conf
  json_write_field "${project_config_file}" "project[].override_nginx_conf" "${project_override_nginx_conf}"

  ## project use_hhtp2
  json_write_field "${project_config_file}" "project[].use_hhtp2" "${project_use_http2}"

  ## project certbot_mode
  json_write_field "${project_config_file}" "project[].certbot_mode" "${project_certbot_mode}"

  # Log
  log_event "info" "Project config file created: ${project_config_file}" "false"
  display --indent 6 --text "- Creating project config file" --result DONE --color GREEN
  display --indent 8 --text "${project_config_file}" --color YELLOW --tstyle ITALIC

}

################################################################################
# Generate project config
#
# Arguments:
#  $1 = ${project_path}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_generate_config() {

  local project_path=$1

  local project_config_file

  # TODO: Support to non-interactive

  log_event "info" "Trying to generate a new config for '${project_path}'..." "false"

  # Trying to extract project data

  ## Project Domain
  project_domain="$(basename "${project_path}")"
  project_domain="$(ask_project_domain "${project_domain}")"

  ## Project Stage
  project_stage="$(project_get_stage_from_domain "${project_domain}")"
  project_stage="$(ask_project_state "${project_stage}")"

  # TODO: maybe we could suggest change project domain.

  ## Project Name
  project_name="$(project_get_name_from_domain "${project_domain}")"
  project_name="$(ask_project_name "${project_name}")"

  # TODO: ask for secondary subdomain (could be extracted from nginx server config)

  ## Project Type
  project_type="$(project_get_type "${project_path}")"

  ## Project DB
  project_db="${project_name}_${project_stage}"

  mysql_database_exists "${project_db}"
  exitstatus=$?
  if [[ ${exitstatus} -eq 1 ]]; then

    project_db="$(mysql_ask_database_selection)"

    if [[ -z ${project_db} ]]; then

      project_db_status="disabled"
      log_event "info" "No database selected, aborting..." "false"

    fi

  fi

  ## Project DB User
  #project_db_user="${project_name}_user"

  ## Project DB Host
  project_db_host="$(mysql_ask_user_db_scope "localhost")"

  ## Check if file exists
  project_nginx_conf="/etc/nginx/sites-available/${project_domain}"

  # Create project config file
  #cert_path="/etc/letsencrypt/live/${project_domain}"
  #if [[ -d ${cert_path} ]]; then

  # Arguments:
  #  $1 = ${project_path}
  #  $2 = ${project_name}
  #  $3 = ${project_stage}
  #  $4 = ${project_type}
  #  $5 = ${project_db_status}
  #  $6 = ${project_db_engine}
  #  $7 = ${project_db_name}
  #  $8 = ${project_db_host}
  #  $9 = ${project_db_user}
  #  $10 = ${project_db_pass}
  #  $11 = ${project_prymary_subdomain}
  #  $12 = ${project_secondary_subdomains}
  #  $13 = ${project_override_nginx_conf}
  #  $14 = ${project_use_http2}
  #  $15 = ${project_certbot_mode}

  project_create_config "${project_path}" "${project_name}" "${project_stage}" "${project_type}" "${project_db_status}" "mysql" "${project_db_name}" "${project_db_host}" "${project_db_user}" "${project_db_pass}" "${project_domain}" "" "${project_nginx_conf}" "" "${cert_path}"

  #else

  #  project_create_config "${project_path}" "${project_name}" "${project_stage}" "${project_type}" "${project_db}" "${project_db_host}" "${project_domain}" "${project_nginx_conf}" ""

  #fi

}

################################################################################
# Update project config
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${config_field}
#  $3 = ${config_value}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_update_config() {

  local project_path=$1
  local config_field=$2
  local config_value=$3

  local project_domain
  local project_name
  local project_config_file

  project_domain="$(basename "${project_path}")"

  project_name="$(project_get_name_from_domain "${project_domain}")"

  # Project config file
  project_config_file="${BROLIT_CONFIG_PATH}/${project_name}_conf.json"

  if [[ -e ${project_config_file} ]]; then

    # Write config file
    ## Doc: https://stackoverflow.com/a/61049639/2267761

    ## project_name
    content="$(jq ".${config_field} = \"${config_value}\"" "${project_config_file}")" && echo "${content}" >"${project_config_file}"

    # Log
    display --indent 6 --text "- Updating project config file" --result DONE --color GREEN

  else

    # Log
    display --indent 6 --text "- Project config file dont exists" --result WARNING --color YELLOW

  fi

}

################################################################################
# Get project config
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${config_field}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_get_brolit_config_file() {

  local project_path=$1

  local project_domain
  local project_name
  local project_config_file

  project_domain="$(basename "${project_path}")"

  project_name="$(project_get_name_from_domain "${project_domain}")"

  project_config_file="${BROLIT_CONFIG_PATH}/${project_name}_conf.json"

  if [[ -e ${project_config_file} ]]; then

    # Return
    echo "${project_config_file}"

    return 0

  else

    # Return
    echo "false"

    return 1

  fi

}

################################################################################
# Get project config
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${config_field}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_get_config() {

  local project_path=$1
  local config_field=$2

  local config_value
  local project_domain
  local project_name
  local project_config_file

  project_config_file="$(project_get_brolit_config_file "${project_path}")"

  if [[ ${project_config_file} != "false" ]]; then

    config_value="$(cat "${project_config_file}" | jq -r ".${config_field}")"

    # Return
    echo "${config_value}"

    return 0

  else

    # Return
    echo "false"

    return 1

  fi

}

################################################################################
# Get configured database
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${project_type}
#
# Outputs:
#   ${db_name} if ok, 1 on error.
################################################################################

function project_get_configured_database() {

  local project_path=$1
  local project_type=$2

  local wpconfig_path

  # First try to read from brolit project config
  db_name="$(project_get_config "${project_path}" "project[].db_name")"

  if [[ ${db_name} != "false" ]]; then

    log_event "debug" "Extracted db_name : ${db_name}" "false"

    # Return
    echo "${db_name}"

    return 0

  else

    case ${project_type} in

    wordpress)

      wpconfig_path=$(wp_config_path "${project_path}")

      db_name=$(cat "${wpconfig_path}/wp-config.php" | grep DB_NAME | cut -d \' -f 4)

      log_event "debug" "Extracted db_name : ${db_name}" "false"

      # Return
      echo "${db_name}"

      ;;

    laravel)

      # Read "${project_path}"/.env to extract DB_USER
      db_name="$(grep -oP '^DB_DATABASE=\K.*' "${project_path}"/.env)"

      log_event "debug" "Extracted db_name : ${db_name}" "false"

      # Return
      echo "${db_name}"

      ;;

    node-js)

      # Read "${project_path}"/.env to extract DB_USER
      db_name="$(grep -oP '^DB_NAME=\K.*' "${project_path}"/.env)"

      log_event "debug" "Extracted db_name : ${db_name}" "false"

      # Return
      echo "${db_name}"

      ;;

    *)
      display --indent 8 --text "Project Type Unknown" --tcolor RED
      return 1
      ;;

    esac

  fi

}

################################################################################
# Get configured database user
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${project_type}
#
# Outputs:
#   ${db_user} if ok, 1 on error.
################################################################################

function project_get_configured_database_user() {

  local project_path=$1
  local project_type=$2

  # First try to read from brolit project config
  db_user="$(project_get_config "${project_path}" "project[].db_user")"

  if [[ ${db_user} != "false" ]]; then

    log_event "debug" "Extracted db_name : ${db_user}" "false"

    # Return
    echo "${db_user}"

    return 0

  else

    case $project_type in

    wordpress)

      db_user=$(cat "${project_path}"/wp-config.php | grep DB_USER | cut -d \' -f 4)

      log_event "debug" "Extracted db_user: ${db_user}" "false"

      # Return
      echo "${db_user}"

      ;;

    laravel)

      # Read "${project_path}"/.env to extract DB_USER
      db_user="$(grep -oP '^DB_USERNAME=\K.*' "${project_path}"/.env)"

      log_event "debug" "Extracted db_user: ${db_user}" "false"

      # Return
      echo "${db_user}"

      ;;

    node-js)

      # Read "${project_path}"/.env to extract DB_USER
      db_user="$(grep -oP '^DB_USER=\K.*' "${project_path}"/.env)"

      log_event "debug" "Extracted db_user: ${db_user}" "false"

      # Return
      echo "${db_user}"

      ;;

    *)
      display --indent 8 --text "Project Type Unknown" --tcolor RED
      return 1
      ;;

    esac

  fi

}

################################################################################
# Get configured database user password
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${project_type}
#
# Outputs:
#   ${db_pass} if ok, 1 on error.
################################################################################

function project_get_configured_database_userpassw() {

  local project_path=$1
  local project_type=$2

  # First try to read from brolit project config
  db_pass="$(project_get_config "${project_path}" "project[].db_pass")"

  if [[ ${db_pass} != "false" ]]; then

    log_event "debug" "Extracted db_name : ${db_pass}" "false"

    # Return
    echo "${db_pass}"

    return 0

  else

    case $project_type in

    wordpress)

      db_pass=$(cat "${project_path}"/wp-config.php | grep DB_PASSWORD | cut -d \' -f 4)

      log_event "debug" "Extracted db_pass: ${db_pass}" "false"

      # Return
      echo "${db_pass}"

      ;;

    laravel)

      # Read "${project_path}"/.env to extract DB_USER
      db_user="$(grep -oP '^DB_PASSWORD=\K.*' "${project_path}"/.env)"

      log_event "debug" "Extracted db_pass: ${db_pass}" "false"

      # Return
      echo "${db_user}"

      ;;

    \
      node-js)

      # Read "${project_path}"/.env to extract DB_USER
      db_user="$(grep -oP '^DB_PASSWORD=\K.*' "${project_path}"/.env)"

      log_event "debug" "Extracted db_pass: ${db_pass}" "false"

      # Return
      echo "${db_user}"

      ;;

    *)
      display --indent 8 --text "Project Type Unknown" --tcolor RED
      return 1
      ;;

    esac

  fi

}

################################################################################
# Project install
#
# Arguments:
#  $1 = ${dir_path}
#  $2 = ${project_type}
#  $3 = ${project_domain}
#  $4 = ${project_name}
#  $5 = ${project_state}
#  $6 = ${project_root_domain}   # Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_install() {

  local dir_path=$1
  local project_type=$2
  local project_domain=$3
  local project_name=$4
  local project_state=$5

  # TODO: need to check if user cancels some of this options

  if [[ ${project_type} == '' ]]; then
    project_type="$(ask_project_type)"
  fi

  log_section "Project Installer (${project_type})"

  if [[ ${project_domain} == '' ]]; then
    project_domain="$(ask_project_domain "")"
  fi

  folder_to_install="$(ask_folder_to_install_sites "${dir_path}")"
  project_path="${folder_to_install}/${project_domain}"

  possible_root_domain="$(get_root_domain "${project_domain}")"
  root_domain="$(cloudflare_ask_rootdomain "${possible_root_domain}")"

  if [[ ${project_name} == '' ]]; then

    possible_project_name="$(extract_domain_extension "${project_domain}")"

    project_name="$(ask_project_name "${possible_project_name}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 1 ]]; then

      log_event "info" "Operation cancelled!" "false"
      display --indent 2 --text "- Asking project name" --result SKIPPED --color YELLOW

      return 1

    fi

  fi

  # TODO: check when add www.DOMAIN.com and then select other stage != prod
  if [[ ${project_state} == '' ]]; then

    suggested_state="$(get_subdomain_part "${project_domain}")"

    project_state="$(ask_project_state "${suggested_state}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 1 ]]; then

      log_event "info" "Operation cancelled!" "false"
      display --indent 2 --text "- Asking project stage" --result SKIPPED --color YELLOW

      return 1

    fi

  fi

  case ${project_type} in

  wordpress)

    # Execute function
    wordpress_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"

    ;;

  laravel)
    # Execute function
    # laravel_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"
    # log_event "warning" "Laravel installer should be implemented soon, trying to install like pure php project ..."
    php_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"

    ;;

  php)

    php_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"

    ;;

  node-js)

    #display --indent 8 --text "Project Type NodeJS" --tcolor RED
    nodejs_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_state}" "${root_domain}"

    return 1
    ;;

  *)
    log_event "error" "Project Type ${project_type} unkwnown, aborting ..." "false"
    ;;

  esac

  log_event "info" "Project installation finished" "false"

}

################################################################################
# Project delete files
#
# Arguments:
#  $1 = ${project_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_delete_files() {

  local project_domain=$1

  local dropbox_output

  # Log
  log_subsection "Delete Files"

  # Trying to know project type
  project_type=$(project_get_type "${PROJECTS_PATH}/${project_domain}")

  log_event "info" "Project Type: ${project_type}"

  BK_TYPE="site"

  # Making a backup of project files
  make_files_backup "${BK_TYPE}" "${PROJECTS_PATH}" "${project_domain}"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Creating new folder structure for old projects
    dropbox_output="$(${DROPBOX_UPLOADER} -q mkdir "/${VPSNAME}/offline-site" 2>&1)"

    # Moving deleted project backups to another dropbox directory
    dropbox_output="$(${DROPBOX_UPLOADER} move "/${VPSNAME}/${BK_TYPE}/${project_domain}" "/${VPSNAME}/offline-site" 2>&1)"

    # TODO: if destination folder already exists, it will fail
    log_event "debug" "${DROPBOX_UPLOADER} move ${VPSNAME}/${BK_TYPE}/${project_domain} /${VPSNAME}/offline-site" "false"
    display --indent 6 --text "- Moving to offline projects on Dropbox" --result "DONE" --color GREEN

    # Delete project files
    rm --force --recursive "${PROJECTS_PATH}/${project_domain}"

    # Log
    log_event "info" "Project files deleted for ${project_domain}" "false"
    display --indent 6 --text "- Deleting project files on server" --result "DONE" --color GREEN

    # Make a copy of nginx configuration file
    cp --recursive "/etc/nginx/sites-available/${project_domain}" "${TMP_DIR}"

    # Send notification
    send_notification "⚠️ ${VPSNAME}" "Project files for '${project_domain}' deleted!"

  else

    return 1

  fi

}

################################################################################
# Project delete database
#
# Arguments:
#  $1 = ${database_name}
#  $2 = ${database_user} - Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_delete_database() {

  local database_name=$1
  local database_user=$2

  local databases
  local chosen_database

  # List databases
  databases="$(mysql_list_databases "all")"
  chosen_database="$(whiptail --title "MYSQL DATABASES" --menu "Choose a Database to delete" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) --default-item "${database_name}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Log
    log_subsection "Delete Database"

    BK_TYPE="database"

    # Remove stage from database name
    project_name="${chosen_database%_*}"

    if [[ -z ${database_user} ]]; then

      database_user="${project_name}_user"

    fi

    # Make a database Backup
    make_database_backup "${chosen_database}"

    # Moving deleted project backups to another dropbox directory
    ${DROPBOX_UPLOADER} move "/${VPSNAME}/${BK_TYPE}/${chosen_database}" "/${VPSNAME}/offline-site" 1>&2

    # Log
    clear_previous_lines "1"
    log_event "debug" "Running: dropbox_uploader.sh move ${VPSNAME}/${BK_TYPE}/${chosen_database} /${VPSNAME}/offline-site" "false"
    display --indent 6 --text "- Moving dropbox backup to offline directory" --result "DONE" --color GREEN

    # Delete project database
    mysql_database_drop "${chosen_database}"

    # Send notification
    send_notification "⚠️ ${VPSNAME}" "Project database'${chosen_database}' deleted!"

    # Delete mysql user
    while true; do

      echo -e "${B_RED}${ITALIC} > Do you want to remove database user? Maybe is used by another project.${ENDCOLOR}"
      read -p "Please type 'y' or 'n'" yn

      case $yn in

      [Yy]*)

        # Log
        clear_previous_lines "2"

        # User delete
        mysql_user_delete "${database_user}"

        break

        ;;

      [Nn]*)

        # Log
        clear_previous_lines "2"
        log_event "warning" "Aborting MySQL user deletion ..." "false"
        display --indent 6 --text "- Deleting MySQL user" --result "SKIPPED" --color YELLOW

        break

        ;;

      *) echo " > Please answer yes or no." ;;

      esac

    done

  else

    # Return
    return 1

  fi

}

################################################################################
# Project delete (files, database, config, certs)
#
# Arguments:
#  $1 = ${project_domain}
#  $2 = ${delete_cf_entry} - optional (true or false)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# TODO: NEED REFACTOR
# 1- Files backup with file_backups functions, checking if site is WP or what.
# 2- Ask for confirm delete temp files.
# 3- Ask what to do with letsencrypt and nginx server config files

function project_delete() {

  local project_domain=$1
  local delete_cf_entry=$2

  local files_skipped="false"

  log_section "Project Delete"

  if [[ ${project_domain} == "" ]]; then

    # Folder where sites are hosted: ${PROJECTS_PATH}
    menu_title="PROJECT DIRECTORY TO DELETE"
    directory_browser "${menu_title}" "${PROJECTS_PATH}"

    # Directory_broser returns: " $filepath"/"$filename
    if [[ -z "${filepath}" || "${filepath}" == "" ]]; then

      # Log
      log_event "info" "Files deletion skipped ..." "false"
      display --indent 2 --text "- Selecting directory for deletion" --result "SKIPPED" --color YELLOW

      files_skipped="true"

    else

      # Removing last slash from string
      project_domain=${filename%/}

    fi

  fi

  if [[ ${files_skipped} == "false" ]]; then

    log_event "info" "Project to delete: ${project_domain}" "false"
    display --indent 2 --text "- Selecting ${project_domain} for deletion" --result "DONE" --color GREEN

    # Get project type and db credentials before delete files_skipped
    project_type="$(project_get_type "${project_domain}")"
    project_db_name=$(project_get_configured_database "${project_domain}" "${project_type}")
    project_db_user=$(project_get_configured_database_user "${project_domain}" "${project_type}")

    # Delete Files
    project_delete_files "${project_domain}"

    # TODO: upload to dropbox config_file ??

    # Delete nginx configuration file
    nginx_server_delete "${project_domain}"

    # Delete certificates
    certbot_certificate_delete "${project_domain}"

    if [[ ${delete_cf_entry} != "true" ]]; then

      # Cloudflare Manager
      project_domain="$(whiptail --title "CLOUDFLARE MANAGER" --inputbox "Do you want to delete the Cloudflare entries for the followings subdomains?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Delete Cloudflare entries
        cloudflare_delete_a_record "${project_domain}"

      else

        log_event "info" "Cloudflare entries not deleted. Skipped by user." "false"

      fi

    else

      # Delete Cloudflare entries
      cloudflare_delete_a_record "${project_domain}"

    fi

  fi

  # Delete Database
  project_delete_database "${project_db_name}" "${project_db_user}"

  # Delete tmp backups
  display --indent 2 --text "Please, remove ${TMP_DIR} after check backup was uploaded ok" --tcolor YELLOW

}

################################################################################
# Change project status (online or offline)
#
# Arguments:
#   $1 = ${project_status} (online,offline)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_change_status() {

  local project_status=$1

  local to_change

  startdir="${PROJECTS_PATH}"
  directory_browser "${menutitle}" "${startdir}"

  to_change=${filename%/}

  nginx_server_change_status "${to_change}" "${project_status}"

}

################################################################################
# Get project type
#
# Arguments:
#   $1 = ${dir_path}
#
# Outputs:
#   ${project_type}
################################################################################

function project_get_type() {

  local dir_path=$1

  local project_type
  local is_wp

  if [[ ${dir_path} != "" ]]; then

    is_wp="$(wp_config_path "${dir_path}")"

    if [[ ${is_wp} != "" ]]; then

      project_type="wordpress"

    else

      laravel_v="$(php "${project_dir}/artisan" --version)"

      if [[ ${laravel_v} != "" ]]; then

        project_type="laravel"

      else
        # TODO: implements nodejs,pure php, and others
        project_type="project_type_unknown"

      fi

    fi

  fi

  # Return
  echo "${project_type}"

}

function check_laravel_version() {

  # TODO

  local project_dir=$1

  # Return
  echo "${laravel_v}"

}

################################################################################
# Install PHP project
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${project_domain}
#  $3 = ${project_name}
#  $4 = ${project_state}
#  $5 = ${project_root_domain}   # Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function php_project_installer() {

  local project_path=$1
  local project_domain=$2
  local project_name=$3
  local project_state=$4
  local project_root_domain=$5

  log_subsection "PHP Project Install"

  if [[ ${project_root_domain} == '' ]]; then

    possible_root_domain="$(get_root_domain "${project_domain}")"
    project_root_domain="$(cloudflare_ask_rootdomain "${possible_root_domain}")"

  fi

  if [[ ! -d "${project_path}" ]]; then
    # Download WP
    mkdir "${project_path}"
    change_ownership "www-data" "www-data" "${project_path}"

    # Log
    #display --indent 6 --text "- Making a copy of the WordPress project" --result "DONE" --color GREEN

  else

    # Log
    display --indent 6 --text "- Creating PHP project" --result "FAIL" --color RED
    display --indent 8 --text "Destination folder '${project_path}' already exist"
    log_event "error" "Destination folder '${project_path}' already exist, aborting ..."

    # Return
    return 1

  fi

  db_project_name=$(mysql_name_sanitize "${project_name}")
  database_name="${db_project_name}_${project_state}"
  database_user="${db_project_name}_user"
  database_user_passw="$(openssl rand -hex 12)"

  # Create database and user
  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}" ""
  mysql_user_grant_privileges "${database_user}" "${database_name}" ""

  # Create project directory
  mkdir "${project_path}"

  # Create index.php
  echo "<?php phpinfo(); ?>" >"${project_path}/index.php"

  # Change ownership
  change_ownership "www-data" "www-data" "${project_path}"

  # TODO: ask for Cloudflare support and check if root_domain is configured on the cf account

  # If domain contains www, should work without www too
  common_subdomain='www'
  if [[ ${project_domain} == *"${common_subdomain}"* ]]; then

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_root_domain}" "A"

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_domain}" "CNAME"

    # New site Nginx configuration
    nginx_server_create "${project_domain}" "php" "root_domain" "${project_root_domain}"

    # HTTPS with Certbot
    project_domain="$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain},${project_root_domain}" 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      certbot_certificate_install "${NOTIFICATION_EMAIL_MAILA}" "${project_domain},${project_root_domain}"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        nginx_server_add_http2_support "${project_domain}"

      fi

    else

      # Log
      log_event "info" "HTTPS support for ${project_domain} skipped"
      display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

    fi

  else

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_domain}" "A"

    # New site Nginx configuration
    nginx_create_empty_nginx_conf "${project_path}"
    nginx_create_globals_config
    nginx_server_create "${project_domain}" "php" "single"

    # HTTPS with Certbot
    cert_project_domain="$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      certbot_certificate_install "${NOTIFICATION_EMAIL_MAILA}" "${cert_project_domain}"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        nginx_server_add_http2_support "${project_domain}"

      fi

    else

      log_event "info" "HTTPS support for ${project_domain} skipped" "false"
      display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

    fi

  fi

  # Log
  log_event "info" "PHP project installation for domain ${project_domain} finished" "false"
  display --indent 6 --text "- PHP project installation for domain ${project_domain}" --result "DONE" --color GREEN

  # Send notification
  send_notification "${VPSNAME}" "PHP project installation for domain ${project_domain} finished!"

}

################################################################################
# Install nodejs project
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${project_domain}
#  $3 = ${project_name}
#  $4 = ${project_state}
#  $5 = ${project_root_domain}   # Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nodejs_project_installer() {

  local project_path=$1
  local project_domain=$2
  local project_name=$3
  local project_state=$4
  local project_root_domain=$5

  log_subsection "NodeJS Project Install"

  nodejs_installed="$(package_is_installed "nodejs")"

  if [[ ${nodejs_installed} -eq 1 ]]; then

    nodejs_installer

  fi

  if [[ ${project_root_domain} == '' ]]; then

    possible_root_domain="$(get_root_domain "${project_domain}")"
    project_root_domain="$(cloudflare_ask_rootdomain "${possible_root_domain}")"

  fi

  if [[ ! -d "${project_path}" ]]; then
    # Download WP
    mkdir "${project_path}"
    change_ownership "www-data" "www-data" "${project_path}"

  else

    # Log
    display --indent 6 --text "- Creating NodeJS project" --result "FAIL" --color RED
    display --indent 8 --text "Destination folder '${project_path}' already exist"
    log_event "error" "Destination folder '${project_path}' already exist, aborting ..."

    # Return
    return 1

  fi

  # DB
  db_project_name="$(mysql_name_sanitize "${project_name}")"
  database_name="${db_project_name}_${project_state}"
  database_user="${db_project_name}_user"
  database_user_passw="$(openssl rand -hex 12)"

  ## Create database and user
  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}" ""
  mysql_user_grant_privileges "${database_user}" "${database_name}"

  # Create project directory
  mkdir "${project_path}"

  # Create index.html
  echo "Please configure the project and remove this file." >"${project_path}/index.html"

  # Change ownership
  change_ownership "www-data" "www-data" "${project_path}"

  # TODO: ask for Cloudflare support and check if root_domain is configured on the cf account

  # If domain contains www, should work without www too
  common_subdomain='www'
  if [[ ${project_domain} == *"${common_subdomain}"* ]]; then

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_root_domain}" "A"

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_domain}" "CNAME"

    # New site Nginx configuration
    nginx_server_create "${project_domain}" "php" "root_domain" "${project_root_domain}"

    # HTTPS with Certbot
    project_domain="$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain},${project_root_domain}" 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      certbot_certificate_install "${NOTIFICATION_EMAIL_MAILA}" "${project_domain},${project_root_domain}"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        nginx_server_add_http2_support "${project_domain}"

      fi

    else

      # Log
      log_event "info" "HTTPS support for ${project_domain} skipped" "false"
      display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

    fi

  else

    # Cloudflare API to change DNS records
    cloudflare_set_record "${project_root_domain}" "${project_domain}" "A"

    # New site Nginx configuration
    nginx_create_empty_nginx_conf "${project_path}"
    nginx_create_globals_config
    nginx_server_create "${project_domain}" "nodejs" "single"

    # HTTPS with Certbot
    cert_project_domain="$(whiptail --title "CERTBOT MANAGER" --inputbox "Do you want to install a SSL Certificate on the domain?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      certbot_certificate_install "${NOTIFICATION_EMAIL_MAILA}" "${cert_project_domain}"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        nginx_server_add_http2_support "${project_domain}"

      fi

    else

      log_event "info" "HTTPS support for ${project_domain} skipped" "false"
      display --indent 6 --text "- HTTPS support for ${project_domain}" --result "SKIPPED" --color YELLOW

    fi

  fi

  # Log
  log_event "info" "NodeJS project installation for domain ${project_domain} finished" "false"
  display --indent 6 --text "- NodeJS project installation for domain ${project_domain}" --result "DONE" --color GREEN

  # Send notification
  send_notification "✅ ${VPSNAME}" "NodeJS project installation for domain ${project_domain} finished!"

}
