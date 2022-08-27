#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.1
################################################################################
#
# Project Helper: Perform project actions.
#
################################################################################

################################################################################
# Get project config option from env file
#
# Arguments:
#  $1 = ${file}
#  $2 = ${variable}
#
# Outputs:
#  ${content} if ok, 1 on error.
################################################################################

function project_get_config_var() {

  local file="${1}"
  local variable="${2}"

  local content

  if [[ ! -f ${file} ]]; then

    log_event "error" "Config file doesn't exist: ${file}" "false"
    exit 1

  fi

  # Read "${file}"/.env to extract ${variable}
  content="$(grep -oP "^${variable}=\K.*" "${file}")"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Log
    log_event "debug" "Reading variable '${variable}' content from file: ${file}" "false"
    log_event "debug" "${variable}=${content}" "false"
    display --indent 6 --text "- Reading .env variable" --result "DONE" --color GREEN
    display --indent 8 --text "${variable}=${content}" --tcolor GREEN

    content="$(string_remove_quotes "${content}")"

    # Return
    echo "${content}"

    return 0

  else

    # Log
    log_event "error" "Reading variable '${variable}' content from file: ${file}" "false"
    log_event "debug" "Output: ${content}" "false"
    display --indent 6 --text "- Reading .env variable" --result "FAIL" --color RED
    display --indent 8 --text "Please read the log file" --tcolor RED

    return 1

  fi

}

################################################################################
# Set project config option
#
# Arguments:
#  $1 = ${file}
#  $2 = ${variable}
#  $3 = ${content}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function project_set_config_var() {

  local file="${1}"
  local variable="${2}"
  local content="${3}"

  if [[ ! -f ${file} ]]; then

    log_event "error" "Config file doesn't exist: ${file}" "false"
    exit 1

  fi

  sed_output="$(sed -i "s/^${variable}\=.*/${variable}=\"${content}\"/" "${file}")"

  sed_result=$?
  if [[ ${sed_result} -eq 0 ]]; then

    # Log
    log_event "info" "Setting ${variable}=${content}" "false"
    display --indent 6 --text "- Setting .env option" --result "DONE" --color GREEN
    display --indent 8 --text "${variable}=${content}" --tcolor GREEN

    return 0

  else

    # Log
    log_event "error" "Setting/updating field: ${variable}" "false"
    log_event "debug" "Output: ${sed_output}" "false"
    display --indent 6 --text "- Setting .env option" --result "FAIL" --color RED
    display --indent 8 --text "Please read the log file" --tcolor RED

    return 1

  fi

}

################################################################################
# Check if project is excluded on config
#
# Arguments:
#   $1= ${project}
#
# Outputs:
#   1 on true or 0 on false.
################################################################################

function project_is_ignored() {

  local project="${1}" #string

  ignored_projects_list="$(string_remove_spaces "${IGNORED_PROJECTS_LIST}")"
  ignored_projects_list="$(echo "${ignored_projects_list}" | tr '\n' ',')"

  # String to Array
  IFS="," read -a excluded_projects_array <<<"${ignored_projects_list}"
  for i in "${excluded_projects_array[@]}"; do
    :

    if [[ ${project} == "${i}" ]]; then

      return 1

    fi

  done

  return 0

}

################################################################################
# Ask project stage
#
# Arguments:
#   $1 = ${suggested_state} - optional to select default option#
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_ask_stage() {

  local suggested_state="${1}"

  local project_stages
  local project_stage

  project_stages="prod demo stage test beta dev"

  project_stage="$(whiptail --title "Project Stage" --menu "Choose Project Stage" 20 78 10 $(for x in ${project_stages}; do echo "$x [X]"; done) --default-item "${suggested_state}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Return
    echo "${project_stage}"

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

function project_ask_name() {

  local project_name="${1}"

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
function project_ask_domain() {

  local project_domain="${1}"

  project_domain="$(whiptail --title "Domain" --inputbox "Insert the project's domain. Example: landing.domain.com" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Return
    echo "${project_domain}"

    return 0

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

function project_ask_type() {

  local suggested_project_type="${1}"

  local project_types
  local project_type

  project_types="wordpress laravel php react html docker proxy"

  project_type="$(whiptail --title "SELECT PROJECT TYPE" --menu " " 20 78 10 $(for x in ${project_types}; do echo "${x} [D]"; done) --default-item "${suggested_project_type}" 3>&1 1>&2 2>&3)"

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
# Ask project port
#
# Arguments:
#   ${suggested_proxy_port}
#
# Outputs:
#   ${proxy_port} if ok, 1 on error.
################################################################################

function project_ask_port() {

  local suggested_proxy_port="${1}"

  local proxy_port

  proxy_port="$(whiptail --title "Domain" --inputbox "Insert the internal port you want to proxy:" 10 60 "${suggested_proxy_port}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Return
    echo "${proxy_port}"

    return 0

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

function project_ask_folder_to_install() {

  local folder_to_install="${1}"

  if [[ -z ${folder_to_install} ]]; then

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

  local project_domain="${1}"

  local project_stages
  local possible_project_name

  declare -a possible_project_stages_on_subdomain=("www" "demo" "stage" "test" "beta" "dev")

  # Extract project name from domain
  possible_project_name="$(domain_extract_extension "${project_domain}")"

  # Remove stage from domain
  for p in "${possible_project_stages_on_subdomain[@]}"; do

    possible_project_name="$(echo "${possible_project_name}" | sed -r "s/${p}.//g")"

  done

  # Remove "-" char " and replace '.' with '_'
  possible_project_name="$(echo "${possible_project_name}" | sed -r 's/[-]+//g' | sed -r 's/[.]+/_/g')"

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

  local project_domain="${1}"

  local project_stages
  local possible_project_stage

  project_stages="demo stage test beta dev"

  # Trying to extract project stage from domain
  subdomain_part="$(domain_get_subdomain_part "${project_domain}")"
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
# Update/Create project config file
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

function project_update_brolit_config() {

  local project_path="${1}"
  local project_name="${2}"
  local project_stage="${3}"
  local project_type="${4}"
  local project_db_status="${5}"
  local project_db_engine="${6}"
  local project_db_name="${7}"
  local project_db_host="${8}"
  local project_db_user="${9}"
  local project_db_pass="${10}"
  local project_prymary_subdomain="${11}"
  local project_secondary_subdomains="${12}"
  local project_override_nginx_conf="${13}"
  local project_use_http2="${14}"
  local project_certbot_mode="${15}"

  local project_config_file

  # Log
  log_subsection "Update Project Config"

  # Project config file
  project_config_file="${BROLIT_CONFIG_PATH}/${project_prymary_subdomain}_conf.json"

  if [[ -e ${project_config_file} ]]; then

    # Log
    display --indent 6 --text "- Project config file already exists" --result WARNING --color YELLOW
    display --indent 8 --text "Updating config file ..." --color YELLOW --tstyle ITALIC

  else

    # Log
    display --indent 6 --text "- Creating BROLIT project config"

    # Copy empty config file
    cp "${BROLIT_MAIN_DIR}/config/brolit/brolit_project.json" "${project_config_file}"

  fi

  # Write config file
  ## Doc: https://stackoverflow.com/a/61049639/2267761

  ## project name
  json_write_field "${project_config_file}" "project[].name" "${project_name}"

  ## project stage
  json_write_field "${project_config_file}" "project[].stage" "${project_stage}"

  ## project type
  json_write_field "${project_config_file}" "project[].type" "${project_type}"

  ## project files status
  json_write_field "${project_config_file}" "project[].files[].status" "enabled"

  ## project files path
  json_write_field "${project_config_file}" "project[].files[].config[].path" "${project_path}"

  ## project database status
  json_write_field "${project_config_file}" "project[].database[].status" "${project_db_status}"

  ## project database engine
  json_write_field "${project_config_file}" "project[].database[].engine" "${project_db_engine}"

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

  ## project use_http2
  #json_write_field "${project_config_file}" "project[].use_http2" "${project_use_http2}"

  ## project certbot_mode
  #json_write_field "${project_config_file}" "project[].certbot_mode" "${project_certbot_mode}"

  # Log
  clear_previous_lines "1"
  display --indent 6 --text "- Creating BROLIT project config" --result DONE --color GREEN
  display --indent 8 --text "${project_config_file}" --color GREEN --tstyle ITALIC

  log_event "info" "Project config file created: ${project_config_file}" "false"

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

function project_generate_brolit_config() {

  local project_path="${1}"

  local project_config_file

  # TODO: Support to non-interactive

  log_event "info" "Trying to generate a new config for '${project_path}'..." "false"

  # Trying to extract project data

  ## Project Domain
  project_domain="$(basename "${project_path}")"
  project_domain="$(project_ask_domain "${project_domain}")"
  exitstatus=$?
  if [[ ${exitstatus} -eq 1 ]]; then
    # Log
    log_event "info" "Operation aborted by user..." "false"
    return 1
  fi

  ## Project Stage
  project_stage="$(project_get_stage_from_domain "${project_domain}")"
  project_stage="$(project_ask_stage "${project_stage}")"
  exitstatus=$?
  if [[ ${exitstatus} -eq 1 ]]; then
    # Log
    log_event "info" "Operation aborted by user..." "false"
    return 1
  fi

  # TODO: maybe we could suggest change project domain.

  ## Project Name
  project_name="$(project_get_name_from_domain "${project_domain}")"
  project_name="$(project_ask_name "${project_name}")"
  exitstatus=$?
  if [[ ${exitstatus} -eq 1 ]]; then
    # Log
    log_event "info" "Operation aborted by user..." "false"
    return 1
  fi

  # TODO: ask for secondary subdomain (could be extracted from nginx server config)

  ## Project Type
  project_type="$(project_get_type "${project_path}")"

  ## Project DB
  project_db_name="$(project_get_configured_database "${project_path}" "${project_type}")"

  mysql_database_exists "${project_db_name}"
  exitstatus=$?
  if [[ ${exitstatus} -eq 1 ]]; then

    project_db_name="$(mysql_ask_database_selection)"
    if [[ -z ${project_db_name} ]]; then
      project_db_status="disabled"
      log_event "info" "No database selected, aborting..." "false"
      return 1
    fi

  else

    ## Project DB status
    project_db_status="enabled"

    ## Project DB Engine
    project_db_engine="$(project_get_configured_database_engine "${project_path}" "${project_type}")"

    ## Project DB User
    project_db_user="$(project_get_configured_database_user "${project_path}" "${project_type}")"

    ## Project DB User Pass
    project_db_pass="$(project_get_configured_database_userpassw "${project_path}" "${project_type}")"

    ## Project DB Host
    project_db_host="$(mysql_ask_user_db_scope "localhost")"

  fi

  ## Check if file exists
  project_nginx_conf="/etc/nginx/sites-available/${project_domain}"

  # TODO: certbot, cloudflare and backup retention options

  #cert_path="/etc/letsencrypt/live/${project_domain}"

  # Create project config file

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

  project_update_brolit_config "${project_path}" "${project_name}" "${project_stage}" "${project_type}" "${project_db_status}" "${project_db_engine}" "${project_db_name}" "${project_db_host}" "${project_db_user}" "${project_db_pass}" "${project_domain}" "" "${project_nginx_conf}" "" "${cert_path}"

}

################################################################################
# Get project config var
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${config_field}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_get_brolit_config_var() {

  local project_path="${1}"
  local config_field="${2}"

  local config_value
  local project_config_file

  project_config_file="$(project_get_brolit_config_file "${project_path}")"

  if [[ ${project_config_file} != "false" ]]; then

    config_value="$(cat "${project_config_file}" | jq -r ".${config_field}")"

    # Return
    echo "${config_value}"

    return 0

  else

    return 1

  fi

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

function project_set_brolit_config_var() {

  local project_path="${1}"
  local config_field="${2}"
  local config_value="${3}"

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

  local project_path="${1}"

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
# Get configured database engine
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${project_type}
#
# Outputs:
#   ${db_engine} if ok, 1 on error.
################################################################################

function project_get_configured_database_engine() {

  local project_path="${1}"
  local project_type="${2}"

  # First try to read from brolit project config
  db_engine="$(project_get_brolit_config_var "${project_path}" "project[].database[].engine")"

  if [[ -z ${db_engine} ]]; then

    case ${project_type} in

    wordpress)

      # Return
      echo "mysql"

      ;;

    laravel)

      db_engine="$(project_get_config_var "${project_path}/.env" "DB_CONNECTION")"

      # Return
      echo "${db_engine}"

      ;;

    php)

      db_engine="$(project_get_config_var "${project_path}/.env" "DB_CONNECTION")"

      # Return
      echo "${db_engine}"

      ;;

    nodejs)

      db_engine="$(project_get_config_var "${project_path}/.env" "DB_CONNECTION")"

      # Return
      echo "${db_engine}"

      ;;

    *)

      log_event "debug" "No database information for project." "false"

      return 1

      ;;

    esac

  else

    echo "${db_engine}"

  fi

}

################################################################################
# Set/Update database engine
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${project_type}
#  $3 = ${db_engine}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_set_configured_database_engine() {

  local project_path="${1}"
  local project_type="${2}"
  local db_engine="${3}"

  # Set brolit project config var
  project_set_brolit_config_var "${project_path}" "project[].database[].engine" "${db_engine}"

  case ${project_type} in

  wordpress)

    # Nothing to do

    # Return
    return 0

    ;;

  laravel)

    # Set/Update
    project_set_config_var "${project_path}/.env" "DB_CONNECTION" "${db_engine}"

    return 0

    ;;

  php)

    # Set/Update
    project_set_config_var "${project_path}/.env" "DB_CONNECTION" "${db_engine}"

    return 0

    ;;

  nodejs)

    # Set/Update
    project_set_config_var "${project_path}/.env" "DB_CONNECTION" "${db_engine}"

    return 0

    ;;

  *)

    log_event "error" "Unknown project type" "false"

    return 1

    ;;

  esac

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

  local project_path="${1}"
  local project_type="${2}"

  local db_name
  local wpconfig_path

  # First try to read from brolit project config
  db_name="$(project_get_brolit_config_var "${project_path}" "project[].database[].config[].name")"

  if [[ -n ${db_name} ]]; then

    log_event "debug" "Extracted db_name: ${db_name}" "false"

    # Return
    echo "${db_name}"

    return 0

  else

    case ${project_type} in

    wordpress)

      wpconfig_path=$(wp_config_path "${project_path}")

      db_name="$(wp_config_get_option "${wpconfig_path}" "DB_NAME")"

      # TODO: error check or empty $db_name

      # Return
      echo "${db_name}"

      ;;

    laravel)

      db_name="$(project_get_config_var "${project_path}/.env" "DB_DATABASE")"

      # Return
      echo "${db_name}"

      ;;

    php)

      db_name="$(project_get_config_var "${project_path}/.env" "DB_DATABASE")"

      # Return
      echo "${db_name}"

      ;;

    nodejs)

      db_name="$(project_get_config_var "${project_path}/.env" "DB_DATABASE")"

      # Return
      echo "${db_name}"

      ;;

    *)

      log_event "debug" "No database information for project." "false"
      return 1

      ;;

    esac

  fi

}

################################################################################
# Set/Update configured database
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${project_type}
#  $3 = ${db_name}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_set_configured_database() {

  local project_path="${1}"
  local project_type="${2}"
  local db_name="${3}"

  # Set brolit project config var
  project_set_brolit_config_var "${project_path}" "project[].database[].config[].name" "${db_name}"

  case ${project_type} in

  wordpress)

    # Set/Update
    wp_config_set_option "${project_path}" "DB_NAME" "${db_name}"

    # Return
    return 0

    ;;

  laravel)

    # Set/Update
    project_set_config_var "${project_path}/.env" "DB_DATABASE" "${db_name}"

    return 0

    ;;

  php)

    # Set/Update
    project_set_config_var "${project_path}/.env" "DB_DATABASE" "${db_name}"

    return 0

    ;;

  nodejs)

    # Set/Update
    project_set_config_var "${project_path}/.env" "DB_DATABASE" "${db_name}"

    return 0

    ;;

  *)

    log_event "error" "Unknown project type" "false"

    return 1

    ;;

  esac

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

  local project_path="${1}"
  local project_type="${2}"

  local db_user

  # First try to read from brolit project config
  db_user="$(project_get_brolit_config_var "${project_path}" "project[].database[].config[].user")"

  if [[ -n ${db_user} ]]; then

    log_event "debug" "Extracted db_user : ${db_user}" "false"

    # Return
    echo "${db_user}"

  else

    case ${project_type} in

    wordpress)

      db_user="$(wp_config_get_option "${project_path}" "DB_USER")"

      # Return
      echo "${db_user}"

      ;;

    laravel)

      db_user="$(project_get_config_var "${project_path}/.env" "DB_USERNAME")"

      # Return
      echo "${db_user}"

      ;;

    php)

      db_user="$(project_get_config_var "${project_path}/.env" "DB_USERNAME")"

      # Return
      echo "${db_user}"

      ;;

    nodejs)

      db_user="$(project_get_config_var "${project_path}/.env" "DB_USERNAME")"

      # Return
      echo "${db_user}"

      ;;

    *)
      log_event "debug" "No database information for project." "false"
      return 1
      ;;

    esac

  fi

  return 0

}

################################################################################
# Set/Update database user
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${project_type}
#  $3 = ${db_user}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_set_configured_database_user() {

  local project_path="${1}"
  local project_type="${2}"
  local db_user_passw="${3}"

  # Set brolit project config var
  project_set_brolit_config_var "${project_path}" "project[].database[].config[].user" "${db_user}"

  case ${project_type} in

  wordpress)

    # Set/Update
    wp_config_set_option "${project_path}" "DB_USER" "${db_user_passw}"

    # Return
    return 0

    ;;

  laravel)

    # Set/Update
    project_set_config_var "${project_path}/.env" "DB_USERNAME" "${db_user_passw}"

    return 0

    ;;

  php)

    # Set/Update
    project_set_config_var "${project_path}/.env" "DB_USERNAME" "${db_user_passw}"

    return 0

    ;;

  nodejs)

    # Set/Update
    project_set_config_var "${project_path}/.env" "DB_USERNAME" "${db_user_passw}"

    return 0

    ;;

  *)

    log_event "error" "Unknown project type" "false"

    return 1

    ;;

  esac

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

  local project_path="${1}"
  local project_type="${2}"

  local db_user_passw

  # First try to read from brolit project config
  db_user_passw="$(project_get_brolit_config_var "${project_path}" "project[].database[].config[].pass")"

  if [[ ${db_user_passw} != "false" ]]; then

    log_event "debug" "Extracted db_name: ${db_user_passw}" "false"

    # Return
    echo "${db_user_passw}"

    return 0

  else

    case ${project_type} in

    wordpress)

      db_user_passw="$(wp_config_get_option "${project_path}" "DB_PASSWORD")"

      # Return
      echo "${db_user_passw}"

      ;;

    laravel)

      db_user_passw="$(project_get_config_var "${project_path}/.env" "DB_PASSWORD")"

      # Return
      echo "${db_user_passw}"

      ;;

    php)

      db_user_passw="$(project_get_config_var "${project_path}/.env" "DB_PASSWORD")"

      # Return
      echo "${db_user_passw}"

      ;;

    nodejs)

      db_user_passw="$(project_get_config_var "${project_path}/.env" "DB_PASSWORD")"

      # Return
      echo "${db_user_passw}"

      ;;

    *)

      log_event "debug" "No database information for project." "false"
      return 1
      ;;

    esac

  fi

}

################################################################################
# Set/Update database user password
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${project_type}
#  $3 = ${db_user_passw}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_set_configured_database_userpassw() {

  local project_path="${1}"
  local project_type="${2}"
  local db_user_passw="${3}"

  # Set brolit project config var
  project_set_brolit_config_var "${project_path}" "project[].database[].config[].pass" "${db_user_passw}"

  case ${project_type} in

  wordpress)

    # Set/Update
    wp_config_set_option "${project_path}" "DB_PASSWORD" "${db_user_passw}"

    # Return
    return 0

    ;;

  laravel)

    # Set/Update
    project_set_config_var "${project_path}/.env" "DB_PASSWORD" "${db_user_passw}"

    return 0

    ;;

  php)

    # Set/Update
    project_set_config_var "${project_path}/.env" "DB_PASSWORD" "${db_user_passw}"

    return 0

    ;;

  nodejs)

    # Set/Update
    project_set_config_var "${project_path}/.env" "DB_PASSWORD" "${db_user_passw}"

    return 0

    ;;

  *)

    log_event "error" "Unknown project type" "false"

    return 1

    ;;

  esac

}

################################################################################
# Project install
#
# Arguments:
#  $1 = ${dir_path}
#  $2 = ${project_type}
#  $3 = ${project_domain}
#  $4 = ${project_name}
#  $5 = ${project_stage}
#  $6 = ${project_root_domain}   # Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_install() {

  local dir_path="${1}"
  local project_type="${2}"
  local project_domain="${3}"
  local project_name="${4}"
  local project_stage="${5}"
  local project_install_mode="${6}" # clean or copy

  if [[ -z ${project_type} ]]; then
    project_type="$(project_ask_type "")"
    [[ $? -eq 1 ]] && return 1
  fi

  log_section "Project Installer (${project_type})"

  if [[ -z ${project_domain} ]]; then
    project_domain="$(project_ask_domain "")"
  fi

  # If ${dir_path} is empty, use default project path
  [[ -z ${dir_path} ]] && dir_path="${PROJECTS_PATH}"

  project_path="${dir_path}/${project_domain}"

  root_domain="$(domain_get_root "${project_domain}")"

  # TODO: check when add www.DOMAIN.com and then select other stage != prod
  if [[ -z ${project_stage} ]]; then

    suggested_state="$(domain_get_subdomain_part "${project_domain}")"

    # Project stage
    project_stage="$(project_ask_stage "${suggested_state}")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 1 ]]; then
      # Log
      log_event "info" "Operation cancelled!" "false"
      display --indent 2 --text "- Asking project stage" --result SKIPPED --color YELLOW
      return 1
    fi

  fi

  if [[ -z ${project_name} ]]; then

    possible_project_name="$(project_get_name_from_domain "${project_domain}")"

    # Project Name
    project_name="$(project_ask_name "${possible_project_name}")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 1 ]]; then
      # Log
      log_event "info" "Operation cancelled!" "false"
      display --indent 2 --text "- Asking project name" --result SKIPPED --color YELLOW
      return 1
    fi

  fi

  case ${project_type} in

  wordpress)

    # Check if wp-cli is installed
    wpcli_install_if_not_installed

    # Execute function
    wordpress_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_stage}" "${root_domain}" "${project_install_mode}"

    # Startup Script for WordPress installation
    # TODO: should pass https://$project_domain instead?
    [[ ${EXEC_TYPE} == "default" ]] && wpcli_run_startup_script "${project_path}" "${project_domain}"

    ;;

  laravel)
    # Execute function
    # laravel_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_stage}" "${root_domain}"
    # log_event "warning" "Laravel installer should be implemented soon, trying to install like pure php project ..."
    php_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_stage}" "${root_domain}"

    ;;

  php)

    php_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_stage}" "${root_domain}"

    ;;

  nodejs)

    #display --indent 8 --text "Project Type NodeJS" --tcolor RED
    nodejs_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_stage}" "${root_domain}"

    #return 1
    ;;

  *)
    log_event "error" "Project type '${project_type}' unkwnown, aborting ..." "false"
    return 1
    ;;

  esac

  ### NEW ###

  # TODO: ask for Cloudflare support and check if root_domain is configured on the cf account

  # Project domain configuration (webserver+certbot+DNS)
  project_update_domain_config "${project_domain}" "${project_type}" ""

  # Post-restore/install tasks
  project_post_install_tasks "${project_path}" "${project_type}" "${project_name}" "${project_stage}" "${database_user_passw}" "" ""

  # TODO: refactor this
  # Cert config files
  cert_path=""
  if [[ -d "/etc/letsencrypt/live/${project_domain}" ]]; then
    cert_path="/etc/letsencrypt/live/${project_domain}"
  else
    if [[ -d "/etc/letsencrypt/live/www.${project_domain}" ]]; then
      cert_path="/etc/letsencrypt/live/www.${project_domain}"
    fi
  fi

  # Create project config file
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
  project_update_brolit_config "${project_path}" "${project_name}" "${project_stage}" "${project_type} " "enabled" "mysql" "${database_name}" "localhost" "${database_user}" "${database_user_passw}" "${project_domain}" "" "/etc/nginx/sites-available/${project_domain}" "" "${cert_path}"

  # Log
  log_event "info" "${project_type} project installation for domain ${project_domain} finished" "false"
  display --indent 6 --text "- ${project_type} project installation" --result "DONE" --color GREEN
  display --indent 8 --text "for domain ${project_domain}"

  # Send notification
  send_notification "✅ ${SERVER_NAME}" "${project_type} project  installation for domain ${project_domain} finished" ""

  ### END NEW ###

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

  local project_domain="${1}"

  BK_TYPE="site"

  # Log
  log_subsection "Delete Files"

  # Trying to know project type
  project_type=$(project_get_type "${PROJECTS_PATH}/${project_domain}")

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Creating new folder structure for old projects
    storage_create_dir "/${SERVER_NAME}/projects-offline"
    storage_create_dir "/${SERVER_NAME}/projects-offline/site"

    # Moving old project backups to another directory
    storage_move "/${SERVER_NAME}/projects-online/${BK_TYPE}/${project_domain}" "/${SERVER_NAME}/projects-offline/site"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
      # Delete project files on server
      #storage_delete_backup ""
      rm --force --recursive "${PROJECTS_PATH}/${project_domain:?}"

      # Log
      log_event "info" "Project files deleted for ${project_domain}" "false"
      display --indent 6 --text "- Deleting project files on server" --result "DONE" --color GREEN

      # Make a copy of nginx configuration file
      cp --recursive "/etc/nginx/sites-available/${project_domain}" "${BROLIT_TMP_DIR}"

      # Send notification
      send_notification "⚠️ ${SERVER_NAME}" "Project files for '${project_domain}' deleted."

    else

      # Log
      log_event "info" "Something went wrong trying to move old backups." "false"
      display --indent 6 --text "- Deleting project files on server" --result "FAIL" --color RED

      return 1

    fi

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

  local database_name="${1}"
  local database_user="${2}"

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

    # TODO: check database engine
    # Make database backup
    backup_file="$(backup_project_database "${chosen_database}" "mysql")"

    if [[ ${backup_file} != "" ]]; then

      # Moving deleted project backups to another directory
      storage_create_dir "/${SERVER_NAME}/projects-offline"
      storage_create_dir "/${SERVER_NAME}/projects-offline/${BK_TYPE}"
      storage_move "/${SERVER_NAME}/projects-online/${BK_TYPE}/${chosen_database}" "/${SERVER_NAME}/projects-offline/${BK_TYPE}"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # TODO: check database engine
        # Delete project database
        mysql_database_drop "${chosen_database}"

        # Send notification
        send_notification "⚠️ ${SERVER_NAME}" "Project database'${chosen_database}' deleted!"

      fi

    fi

    # TODO: check database engine
    # Delete mysql user
    while true; do

      echo -e "${B_RED}${ITALIC} > Remove database user: ${database_user}? Maybe is used by another project.${ENDCOLOR}"
      read -p "Please type 'y' or 'n'" yn

      case $yn in

      [Yy]*)

        # Log
        clear_previous_lines "2"

        # User delete
        mysql_user_delete "${database_user}" "localhost"

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

function project_delete() {

  local project_domain="${1}"
  local delete_cf_entry="${2}"

  local files_skipped="false"

  log_section "Project Delete"

  if [[ -z ${project_domain} ]]; then

    # Folder where sites are hosted: ${PROJECTS_PATH}
    menu_title="PROJECT DIRECTORY TO DELETE"
    directory_browser "${menu_title}" "${PROJECTS_PATH}"

    # Directory_broser returns: " $filepath"/"$filename
    if [[ -z ${filepath} ]]; then

      # Log
      log_event "info" "Files deletion skipped ..." "false"
      display --indent 6 --text "- Selecting directory for deletion" --result "SKIPPED" --color YELLOW

      files_skipped="true"

    else

      # Removing last slash from string
      project_domain=${filename%/}

    fi

  else

    if [[ ! -f ${PROJECTS_PATH}/${project_domain} ]]; then
      log_event "error" "Project directory to delete not found: ${PROJECTS_PATH}/${project_domain}" "true"
      return 1
    fi

  fi

  if [[ ${files_skipped} == "false" ]]; then

    log_event "info" "Project to delete: ${project_domain}" "false"
    display --indent 6 --text "- Selecting ${project_domain} for deletion" --result "DONE" --color GREEN

    # Get project type and db credentials before delete files_skipped
    project_type="$(project_get_type "${project_domain}")"
    project_db_name=$(project_get_configured_database "${project_domain}" "${project_type}")
    project_db_user=$(project_get_configured_database_user "${project_domain}" "${project_type}")

    # Delete Files
    project_delete_files "${project_domain}"

    # Delete nginx configuration file
    nginx_server_delete "${project_domain}"

    # Delete certificates
    certbot_certificate_delete "${project_domain}"

    if [[ ${delete_cf_entry} != "true" && ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

      # Cloudflare Manager
      project_domain="$(whiptail --title "CLOUDFLARE MANAGER" --inputbox "Do you want to delete the Cloudflare entries for the followings subdomains?" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Delete Cloudflare entries
        root_domain="$(domain_get_root "${project_domain}")"
        cloudflare_delete_record "${root_domain}" "${project_domain}" "A"

      else

        log_event "info" "Cloudflare entries not deleted. Skipped by user." "false"

      fi

    else

      # Delete Cloudflare entries
      root_domain="$(domain_get_root "${project_domain}")"
      cloudflare_delete_record "${root_domain}" "${project_domain}" "A"

    fi

  fi

  # Delete Database
  project_delete_database "${project_db_name}" "${project_db_user}"

  # TODO: upload config_file to dropbox

  # Delete config file
  project_config="${BROLIT_CONFIG_PATH}/${project_name}_conf.json"
  rm --force "${project_config}"

  # Log
  log_event "info" "Removing project config file: ${project_config}" "false"
  display --indent 6 --text "- Removing project config file" --result "DONE" --color GREEN

  # Delete tmp backups
  display --indent 2 --text "Please, remove ${BROLIT_TMP_DIR} after check backup was uploaded ok" --tcolor YELLOW

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

  local project_status="${1}"

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

  local dir_path="${1}"

  local project_type

  local wp_path
  local laravel
  local php
  local nodejs
  local react
  local html
  local docker

  # TODO: if brolit_conf exists, should check this file and get project type

  if [[ -n ${dir_path} ]]; then

    # docker-compose?
    docker="$(
      find "${dir_path}" -maxdepth 2 -name "docker-compose.yml" -type f
      find "${dir_path}" -maxdepth 2 -name "docker-compose.yaml" -type f
    )"
    if [[ -n ${docker} ]]; then

      project_type="docker"

      # Log
      log_event "debug" "Project type: ${project_type}" "false"
      display --indent 8 --text "Project type: ${project_type}" --tcolor MAGENTA

      # Return
      echo "${project_type}"

      return 0

    fi

    # WP?
    wp_path="$(wp_config_path "${dir_path}")"
    if [[ -n ${wp_path} ]]; then

      project_type="wordpress"

      # Log
      log_event "debug" "Project type: ${project_type}" "false"
      display --indent 8 --text "Project type: ${project_type}" --tcolor MAGENTA

      # Return
      echo "${project_type}"

      return 0

    fi

    # Laravel?
    laravel="$(php "${dir_path}/artisan" --version | grep -oE "Laravel Framework [0-9]+\.[0-9]+\.[0-9]+")"
    if [[ -n ${laravel} ]]; then

      project_type="laravel"

      # Log
      log_event "debug" "Project type: ${project_type}" "false"
      display --indent 8 --text "Project type: ${project_type}" --tcolor MAGENTA

      # Return
      echo "${project_type}"

      return 0

    fi

    # other-php?
    php="$(find "${dir_path}" -name "index.php" -type f)"
    if [[ -n ${php} ]]; then

      project_type="php"

      # Log
      log_event "debug" "Project type: ${project_type}" "false"
      display --indent 8 --text "Project type: ${project_type}" --tcolor MAGENTA

      # Return
      echo "${project_type}"

      return 0

    fi

    # node.js?
    nodejs="$(find "${dir_path}" -name "package.json" -type f)"
    if [[ -n ${nodejs} ]]; then

      project_type="nodejs"

      # Log
      log_event "debug" "Project type: ${project_type}" "false"
      display --indent 8 --text "Project type: ${project_type}" --tcolor MAGENTA

      # Return
      echo "${project_type}"

      return 0

    fi

    # React?
    react="$(find "${dir_path}/node_modules/react/cjs/" -name "react.development.js" -type f)"
    if [[ -n ${react} ]]; then

      project_type="react"

      # Log
      log_event "debug" "Project type: ${project_type}" "false"
      display --indent 8 --text "Project type: ${project_type}" --tcolor MAGENTA

      # Return
      echo "${project_type}"

      return 0

    fi

    # html-only?
    html="$(find "${dir_path}" -name "index.html" -type f)"
    if [[ -n ${html} ]]; then

      project_type="html"

      # Log
      log_event "debug" "Project type: ${project_type}" "false"
      display --indent 8 --text "Project type: ${project_type}" --tcolor MAGENTA

      # Return
      echo "${project_type}"

      return 0

    fi

    # Unknown
    log_event "debug" "Project type: unknown" "false"

    # Return
    echo "other"

    return 0

  else

    log_event "error" "Can't get project type, working directory doesn't exist." "false"

    return 1

  fi

}

################################################################################
# Create nginx server for an existing project
#
# Arguments:
#   $1 = ${dir_path}
#
# Outputs:
#   ${project_type}
################################################################################

function project_create_nginx_server() {

  local project_domain
  local root_domain
  local project_type
  local exitstatus
  local cloudflare_exitstatus

  log_section "Project Manager"

  log_subsection "Nginx server creation"

  # Select project to work with
  directory_browser "Select a project to work with" "${PROJECTS_PATH}" #return $filename

  if [[ -n ${filename} ]]; then

    filename="${filename::-1}" # remove '/'

    display --indent 6 --text "- Selecting project" --result DONE --color GREEN
    display --indent 8 --text "${filename}"

    # Aks project domain
    project_domain="$(project_ask_domain "${filename}")"

    # Extract root domain
    root_domain="$(domain_get_root "${project_domain}")"

    # Try to get project type
    suggested_project_type="$(project_get_type "${filepath}/${filename}")"

    # Aks project type
    project_type="$(project_ask_type "${suggested_project_type}")"
    if [[ ${project_type} == "docker" || ${project_type} == "proxy" ]]; then
      project_type="proxy"
      project_port="$(project_ask_port "")"
    fi

    # Update project domain config
    project_update_domain_config "${project_domain}" "${project_type}" "${project_port}"

  else

    display --indent 6 "Selecting website to work with" --result SKIPPED --color YELLOW

  fi

}

################################################################################
# Install PHP project
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${project_domain}
#  $3 = ${project_name}
#  $4 = ${project_stage}
#  $5 = ${project_root_domain}   # Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function php_project_installer() {

  local project_path="${1}"
  local project_domain="${2}"
  local project_name="${3}"
  local project_stage="${4}"
  local project_root_domain="${5}"

  log_subsection "PHP Project Install"

  if [[ ! -d ${project_path} ]]; then

    # Create project directory
    mkdir -p "${project_path}"

  else

    # Log
    display --indent 6 --text "- Creating PHP project" --result "FAIL" --color RED
    display --indent 8 --text "Destination folder '${project_path}' already exist"
    log_event "error" "Destination folder '${project_path}' already exist, aborting ..." "false"

    # Return
    return 1

  fi

  db_project_name=$(mysql_name_sanitize "${project_name}")
  database_name="${db_project_name}_${project_stage}"
  database_user="${db_project_name}_user"
  database_user_passw="$(openssl rand -hex 12)"

  # Create database and user
  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}" ""
  mysql_user_grant_privileges "${database_user}" "${database_name}" ""

  # Create index.php
  echo "<?php phpinfo(); ?>" >"${project_path}/index.php"

  # Change ownership
  change_ownership "www-data" "www-data" "${project_path}"

}

################################################################################
# Install nodejs project
#
# Arguments:
#  $1 = ${project_path}
#  $2 = ${project_domain}
#  $3 = ${project_name}
#  $4 = ${project_stage}
#  $5 = ${project_root_domain}   # Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function nodejs_project_installer() {

  local project_path="${1}"
  local project_domain="${2}"
  local project_name="${3}"
  local project_stage="${4}"
  local project_root_domain="${5}"

  log_subsection "NodeJS Project Install"

  nodejs_installed="$(package_is_installed "nodejs")"

  if [[ ${nodejs_installed} -eq 1 ]]; then

    nodejs_installer

  fi

  if [[ ${project_root_domain} == '' ]]; then

    possible_root_domain="$(domain_get_root "${project_domain}")"
    project_root_domain="$(cloudflare_ask_rootdomain "${possible_root_domain}")"

  fi

  if [[ ! -d "${project_path}" ]]; then

    # Create project directory
    mkdir -p "${project_path}"
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
  database_name="${db_project_name}_${project_stage}"
  database_user="${db_project_name}_user"
  database_user_passw="$(openssl rand -hex 12)"

  ## Create database and user
  mysql_database_create "${database_name}"
  mysql_user_create "${database_user}" "${database_user_passw}" ""
  mysql_user_grant_privileges "${database_user}" "${database_name}"

  # Create index.html
  echo "Please configure the project and remove this file." >"${project_path}/index.html"

  # Change ownership
  change_ownership "www-data" "www-data" "${project_path}"

}

function check_laravel_version() {

  # TODO

  local project_dir="${1}"

  # Return
  echo "${laravel_v}"

}

################################################################################
# Update domain configuration (Nginx + Cloudflare)
#
# Arguments:
#  $1 = ${project_domain}
#  $2 = ${project_type}
#  $3 = ${project_port}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_update_domain_config() {

  local project_domain="${1}"
  local project_type="${2}"
  local project_port="${3}"

  local root_domain

  # Log
  log_subsection "Update Domain Configuration"

  root_domain="$(domain_get_root "${project_domain}")"
  #root_domain="$(ask_root_domain "${possible_root_domain}")"

  # TODO: if ${project_domain} == ${chosen_domain}, maybe ask if want to restore nginx and let's encrypt config files
  # restore_letsencrypt_site_files "${chosen_domain}" "${project_backup_date}"
  # restore_nginx_site_files "${chosen_domain}" "${project_backup_date}"

  # Working with root domain or www?
  if [[ ${project_domain} == "${root_domain}" || ${project_domain} == "www.${root_domain}" ]]; then

    # Nginx config
    nginx_server_create "www.${root_domain}" "${project_type}" "root_domain" "${root_domain}" "" "${project_port}"

    # Cloudflare
    if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then
      ## Set records
      cloudflare_set_record "${root_domain}" "${root_domain}" "A" "false" "${SERVER_IP}"
      cloudflare_set_record "${root_domain}" "www.${root_domain}" "CNAME" "false" "${root_domain}"
      cloudflare_exitstatus=$?
    fi

    if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then
      if [[ ${cloudflare_exitstatus} -ne 1 ]]; then # If ${cloudflare_exitstatus} is empty, will pass too
        # Let's Encrypt
        certbot_certificate_install "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${root_domain},www.${root_domain}"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then nginx_server_add_http2_support "${project_domain}"; fi
      fi
    fi

  else # Working with single domain

    # Nginx config
    nginx_server_create "${project_domain}" "${project_type}" "single" "" "${project_port}"

    # Cloudflare
    if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then
      ## Set records
      cloudflare_set_record "${root_domain}" "${project_domain}" "A" "false" "${SERVER_IP}"
      cloudflare_exitstatus=$?
    fi

    if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then
      if [[ ${cloudflare_exitstatus} -ne 1 ]]; then # If ${cloudflare_exitstatus} is empty, will pass too
        # Let's Encrypt
        certbot_certificate_install "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${project_domain}"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then nginx_server_add_http2_support "${project_domain}"; fi
      fi
    fi

  fi

}

function project_post_install_tasks() {

  local install_path="${1}"
  local project_type="${2}"
  local project_name="${3}"
  local project_stage="${4}"
  local project_db_pass="${5}"
  local old_project_domain="${6}"
  local new_project_domain="${7}"
  #local project_port="${8}"

  local project_env

  # Log
  log_subsection "Post Install Tasks"

  # Check if is a WP project
  if [[ ${project_type} == "wordpress" ]]; then

    wp_change_permissions "${install_path}"

    # Change wp-config.php database parameters
    wp_update_wpconfig "${install_path}" "${project_name}" "${project_stage}" "${project_db_pass}"

    # TODO: non protocol before domains (need to check if http or https before)?
    if [[ -n ${old_project_domain} && -n ${new_project_domain} ]]; then
      if [[ ${old_project_domain} != "${new_project_domain}" ]]; then
        # Change urls on database
        wpcli_search_and_replace "${install_path}" "${old_project_domain}" "${new_project_domain}"
      fi
    fi

    # Shuffle salts
    wpcli_set_salts "${install_path}"

    # Update upload_path
    ## Context: https://core.trac.wordpress.org/ticket/41947
    wpcli_update_upload_path "${install_path}" "wp-content/uploads"

    # Changing WordPress visibility
    if [[ ${project_stage} == "prod" ]]; then
      # Let search engines index the project
      wpcli_change_wp_seo_visibility "${install_path}" "1"
      # Set debug mode to false
      wpcli_set_debug_mode "${install_path}" "false"
    else
      wpcli_change_wp_seo_visibility "${install_path}" "0"
    fi

    wpcli_cache_flush "${install_path}"

  else

    # TODO: search .env file
    project_env="${PROJECTS_PATH}/${new_project_domain}/.env"

    if [[ -f ${project_env} ]]; then

      # Update project .env file
      #project_set_config_var "${project_env}" "DB_CONNECTION" "${chosen_project}"
      project_set_config_var "${project_env}" "DB_DATABASE" "${project_name}_${project_stage}"
      project_set_config_var "${project_env}" "DB_USERNAME" "${project_name}_user"
      project_set_config_var "${project_env}" "DB_PASSWORD" "${project_db_pass}"

    else

      log_event "info" ".env file not found on project directory" "false"

    fi

  fi

}
