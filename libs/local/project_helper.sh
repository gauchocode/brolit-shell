#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.5
################################################################################
#
# Project Helper: Perform project actions.
#
################################################################################

################################################################################
# Get project config option from env file
#
# Arguments:
#  ${1} = ${file}
#  ${2} = ${variable}
#
# Outputs:
#  ${content} if ok, 1 on error.
################################################################################

function project_get_config_var() {

  local file="${1}"
  local variable="${2}"

  local content

  # Check if config file exists
  [[ ! -f ${file} ]] && die "Config file doesn't exist: ${file}"

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
    echo "${content}" && return 0

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
#  ${1} = ${file}
#  ${2} = ${variable}
#  ${3} = ${content}
#  ${4} = ${quotes} - optional (none, single, double)
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function project_set_config_var() {

  local file="${1}"
  local variable="${2}"
  local content="${3}"
  local quotes="${4}"
  local update_only="${5:-false}"  # If true, only update existing variables, don't add new ones

  # Check if config file exists
  [[ ! -f ${file} ]] && die "Config file doesn't exist: ${file}"

  # Check if variable exists in file
  if ! grep -q "^${variable}=" "${file}"; then
    if [[ "${update_only}" == "true" ]]; then
      # Variable doesn't exist and update_only is true, skip silently
      log_event "debug" "Variable ${variable} not found in ${file}, skipping (update_only mode)" "false"
      return 0
    fi

    # Variable doesn't exist, add it to the file
    log_event "debug" "Variable ${variable} not found in ${file}, adding it" "false"

    case ${quotes} in
      single)
        echo "${variable}='${content}'" >> "${file}"
        ;;
      double)
        echo "${variable}=\"${content}\"" >> "${file}"
        ;;
      *)
        echo "${variable}=${content}" >> "${file}"
        ;;
    esac

    # Log
    log_event "info" "Adding ${variable}=${content}" "false"
    display --indent 6 --text "- Adding .env variable" --result "DONE" --color GREEN
    display --indent 8 --text "${variable}=${content}" --tcolor GREEN

    return 0
  fi

  # Variable exists, update it
  case ${quotes} in

  single)

    # Write file
    sed_output="$(sed -i "s/^${variable}\=.*/${variable}=\'${content}\'/" "${file}")"
    ;;

  double)

    # Write file
    sed_output="$(sed -i "s/^${variable}\=.*/${variable}=\"${content}\"/" "${file}")"
    ;;

  *) # empty or other different form single or double

    # Write file
    sed_output="$(sed -i "s/^${variable}\=.*/${variable}=${content}/" "${file}")"
    ;;

  esac

  sed_result=$?
  if [[ ${sed_result} -eq 0 ]]; then

    # Log
    log_event "info" "Updating ${variable}=${content}" "false"
    display --indent 6 --text "- Updating .env variable" --result "DONE" --color GREEN
    display --indent 8 --text "${variable}=${content}" --tcolor GREEN

    return 0

  else

    # Log
    log_event "error" "Updating field: ${variable}" "false"
    log_event "debug" "Output: ${sed_output}" "false"
    display --indent 6 --text "- Updating .env variable" --result "FAIL" --color RED
    display --indent 8 --text "Please read the log file" --tcolor RED

    return 1

  fi

}

################################################################################
# Check if project is listed as ignored on config
#
# Arguments:
#   $1= ${project}
#
# Outputs:
#   true or false
################################################################################

function project_is_ignored() {

  local project="${1}" #string

  local ignored="false"
  local ignored_list
  local excluded_projects_array

  ignored_list="$(string_remove_spaces "${IGNORED_PROJECTS_LIST}")"
  ignored_list="$(echo "${ignored_list}" | tr '\n' ',')"

  # String to Array
  IFS="," read -r -a excluded_projects_array <<<"${ignored_list}"
  for i in "${excluded_projects_array[@]}"; do
    :

    [[ ${project} == "${i}" ]] && ignored="true" && break

  done

  # Return
  echo "${ignored}"

}

################################################################################
# Ask project stage
#
# Arguments:
#   ${1} = ${suggested_state} - optional to select default option#
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
    echo "${project_stage}" && return 0

  else

    return 1

  fi

}

################################################################################
# Ask project name
#
# Arguments:
#   ${1} = ${project_name} - optional to select default option
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
    echo "${project_name}" && return 0

  else

    return 1

  fi

}

################################################################################
# Ask project domain
#
# Arguments:
#   ${1} = ${project_domain} - optional to select default option
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

# TODO: project_domain should be an array?
function project_ask_domain() {

  local project_domain="${1}"

  project_domain="$(whiptail --title "Subdomain" --inputbox "Insert project's subdomain. Example: www.domain.com" 10 60 "${project_domain}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Validate domain format
    if [[ ! ${project_domain} =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ ]]; then
      # Log
      log_event "error" "Invalid domain format: ${project_domain}" "false"
      display --indent 6 --text "- Domain format" --result "FAIL" --color RED
      display --indent 8 --text "Invalid domain format: ${project_domain}" --tcolor RED
      return 1
    fi

    # Return
    echo "${project_domain}" && return 0

  else

    # Log
    log_event "error" "Domain not set" "false"
    return 1

  fi

}

################################################################################
# Ask project type
#
# Arguments:
#   ${1} - ${suggested_project_type}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_ask_type() {

  local suggested_project_type="${1}"

  local project_types
  local project_type

  project_types="wordpress php html other"

  project_type="$(whiptail --title "SELECT PROJECT TYPE" --menu " " 20 78 10 $(for x in ${project_types}; do echo "${x} [D]"; done) --default-item "${suggested_project_type}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Lowercase
    project_type="$(echo "${project_type}" | tr '[A-Z]' '[a-z]')"

    # Return
    echo "${project_type}" && return 0

  else

    return 1

  fi

}

################################################################################
# Ask project isntall type
#
# Arguments:
#   ${1} - ${suggested_project_install_type}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_ask_install_type() {

  local suggested_project_install_type="${1}"

  local project_install_types
  local project_install_type

  project_install_types="default docker"

  project_install_type="$(whiptail --title "SELECT PROJECT INSTALL TYPE" --menu " " 20 78 10 $(for x in ${project_install_types}; do echo "${x} [D]"; done) --default-item "${suggested_project_install_type}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Lowercase
    project_install_type="$(echo "${project_install_type}" | tr '[A-Z]' '[a-z]')"

    # Return
    echo "${project_install_type}" && return 0

  else

    return 1

  fi

}

################################################################################
# Extract port from project .env file
#
# Arguments:
#   ${1} - ${project_path}
#
# Outputs:
#   Port number if found, empty string otherwise
################################################################################

function project_get_port_from_env() {

  local project_path="${1}"
  local env_file="${project_path}/.env"
  local port=""

  # Check if .env file exists
  if [[ ! -f "${env_file}" ]]; then
    return 0
  fi

  # Try to extract port from environment variables in priority order
  # Priority: WP_PORT (WordPress), APP_PORT (generic app), PORT (standard), then others
  # Exclude admin/utility ports like PHPMYADMIN_PORT, SSH_HOST_PORT, etc.
  for var_name in "WP_PORT" "APP_PORT" "PORT" "SERVER_PORT" "HTTP_PORT" "NODE_PORT" "WEBSERVER_PORT"; do
    port="$(grep -E "^${var_name}=" "${env_file}" | grep -v '^#' | head -n 1 | cut -d '=' -f 2 | tr -d ' "')"
    if [[ -n "${port}" ]]; then
      log_event "debug" "Found port ${port} from ${var_name} in ${env_file}" "false"
      break
    fi
  done

  # Validate port is a number
  if [[ "${port}" =~ ^[0-9]+$ ]]; then
    echo "${port}"
  fi

  return 0

}

################################################################################
# Ask project port
#
# Arguments:
#   ${1} - ${suggested_proxy_port}
#
# Outputs:
#   ${proxy_port} if ok, 1 on error.
################################################################################

function project_ask_port() {

  local suggested_proxy_port="${1}"

  local proxy_port

  proxy_port="$(whiptail --title "Domain" --inputbox "Insert the internal port you want to proxy:" 10 60 "${suggested_proxy_port}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 && -n ${proxy_port} ]]; then

    # Return
    echo "${proxy_port}" && return 0

  else

    return 1

  fi

}

################################################################################
# Ask projects main directory
#
# Arguments:
#   ${1} = ${folder_to_install}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_ask_folder_to_install() {

  local folder_to_install="${1}"

  local exitstatus

  if [[ -z ${folder_to_install} ]]; then

    folder_to_install="$(whiptail --title "Folder to work with" --inputbox "Please select the project folder you want to work with:" 10 60 "${folder_to_install}" 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      log_event "info" "Folder to work with: ${folder_to_install}" "false"
      # Return
      echo "${folder_to_install}" && return 0

    else
      return 1

    fi

  else
    log_event "info" "Folder to install: ${folder_to_install}" "false"
    # Return
    echo "${folder_to_install}" && return 0

  fi

}

################################################################################
# Get the project's database engine based on installation type
#
# Arguments:
#   ${1} = ${project_name}
#   ${2} = ${project_install_type}
#
# Outputs:
#   Database engine name (mysql, postgres) or empty string if not detected
################################################################################

function project_get_database_engine() {

    local project_name="${1}"
    local project_install_type="${2}"

    local project_path="/${PROJECTS_PATH}/${project_name}"
    
    # For Docker projects, check docker-compose configuration first
    if [[ "$project_install_type" = "docker" ]]; then
        # Check both docker-compose.yml and docker-compose.yaml
        if [[ -f "${project_path}/docker-compose.yml" ]] || [[ -f "${project_path}/docker-compose.yaml" ]]; then
            if grep -q "image:.*postgres" "${project_path}/docker-compose.yml" 2>/dev/null || 
               grep -q "image:.*postgres" "${project_path}/docker-compose.yaml" 2>/dev/null; then
                echo "postgres"
                return 0
            elif grep -q "image:.*mysql" "${project_path}/docker-compose.yml" 2>/dev/null || 
                 grep -q "image:.*mysql" "${project_path}/docker-compose.yaml" 2>/dev/null; then
                echo "mysql"
                return 0
            fi
        fi
    fi
    
    # WordPress (uses MySQL)
    if [[ -f "${project_path}/wp-config.php" ]]; then
        echo "mysql"
        return 0
    fi
    
    # Laravel/PHP frameworks (check .env)
    if [[ -f "${project_path}/.env" ]]; then
        if grep -q "DB_CONNECTION=pgsql" "${project_path}/.env"; then
            echo "postgres"
            return 0
        elif grep -q "DB_CONNECTION=mysql" "${project_path}/.env"; then
            echo "mysql"
            return 0
        fi
    fi
    
    # Node.js/Next.js (check package.json dependencies)
    if [[ -f "${project_path}/package.json" ]]; then
        if jq -e '.dependencies."pg" // .devDependencies."pg"' "${project_path}/package.json" > /dev/null; then
            echo "postgres"
            return 0
        elif jq -e '.dependencies."mysql2" // .devDependencies."mysql2" // .dependencies."mysql" // .devDependencies."mysql"' "${project_path}/package.json" > /dev/null; then
            echo "mysql"
            return 0
        fi
    fi
    
    # Default: not detected
    echo ""
    return 1
}

################################################################################
# Get project name from domain
#
# Arguments:
#   ${1} = ${project_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_get_name_from_domain() {
  local project_domain="${1}"

  local project_stages
  local project_name

  declare -a possible_project_stages_on_subdomain=("www" "demo" "stage" "test" "beta" "dev")

  # Extract project name from domain
  project_name="$(domain_extract_extension "${project_domain}")"

  # Remove stage from domain
  for p in "${possible_project_stages_on_subdomain[@]}"; do

    project_name="$(echo "${project_name}" | sed -r "s/${p}.//g")"

  done

  # Remove "-" char " and replace '.' with '_'
  project_name="$(echo "${project_name}" | sed -r 's/[-]+//g' | sed -r 's/[.]+/_/g')"

  # Log
  log_event "debug" "project_name=${project_name}" "false"

  # Return
  echo "${project_name}"

}

################################################################################
# Get project stage from domain
#
# Arguments:
#   ${1} = ${project_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_get_stage_from_domain() {

  local project_domain="${1}"

  local project_stages
  local project_stage

  project_stages="demo stage test beta dev"

  # Trying to extract project stage from domain
  subdomain_part="$(domain_get_subdomain_part "${project_domain}")"
  project_stage="$(echo "${subdomain_part}" | cut -d "." -f 1)"

  # Log
  log_event "debug" "subdomain_part=${subdomain_part}" "false"
  log_event "debug" "project_stage=${project_stage}" "false"

  if [[ ${project_stages} != *"${project_stage}"* || ${project_stage} == "" ]]; then

    project_stage="prod"

  fi

  # Log
  log_event "debug" "project_stage=${project_stage}" "false"

  # Return
  echo "${project_stage}"

}

################################################################################
# Update/Create project config file
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${project_name}
#  ${3} = ${project_stage}
#  ${4} = ${project_type}
#  ${5} = ${project_db_status}
#  ${6} = ${project_db_engine}
#  ${7} = ${project_db_name}
#  ${8} = ${project_db_host}
#  ${9} = ${project_db_user}
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
#  ${1} = ${project_path}
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

  ## Project Install Type
  project_install_type="$(project_get_install_type "${project_path}")"

  ## Project DB
  project_db_name="$(project_get_configured_database "${project_path}" "${project_type}" "${project_install_type}")"

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
    project_db_engine="$(project_get_configured_database_engine "${project_path}" "${project_type}" "${project_install_type}")"

    ## Project DB User
    project_db_user="$(project_get_configured_database_user "${project_path}" "${project_type}" "${project_install_type}")"

    ## Project DB User Pass
    project_db_pass="$(project_get_configured_database_userpassw "${project_path}" "${project_type}" "${project_install_type}")"

    ## Project DB Host
    project_db_host="$(mysql_ask_user_db_scope "localhost")"

  fi

  ## Check if file exists
  project_nginx_conf="/etc/nginx/sites-available/${project_domain}"

  # TODO: certbot, cloudflare and backup retention options

  #cert_path="/etc/letsencrypt/live/${project_domain}"

  # Create project config file

  # Arguments:
  #  ${1} = ${project_path}
  #  ${2} = ${project_name}
  #  ${3} = ${project_stage}
  #  ${4} = ${project_type}
  #  ${5} = ${project_db_status}
  #  ${6} = ${project_db_engine}
  #  ${7} = ${project_db_name}
  #  ${8} = ${project_db_host}
  #  ${9} = ${project_db_user}
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
#  ${1} = ${project_path}
#  ${2} = ${config_field}
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
    echo "${config_value}" && return 0

  else

    return 1

  fi

}

################################################################################
# Update project config
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${config_field}
#  ${3} = ${config_value}
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
    display --indent 6 --text "- Updating BROLIT project config file" --result DONE --color GREEN

  else

    # Log
    display --indent 6 --text "- BROLIT project config file dont exists" --result WARNING --color YELLOW

  fi

}

################################################################################
# Get brolit project config file
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${config_field}
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
    echo "${project_config_file}" && return 0

  else

    # Return
    echo "false" && return 1

  fi

}

function project_get_configured_docker_data_dir() {

  local project_path="${1}"

  local project_dir

  # Get WWW_DATA_DIR value from .env file
  project_dir="$(cat "${project_path}/.env" | grep WWW_DATA_DIR | cut -d "=" -f 2)"

  # Check exitstatus
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Overwrite ${project_path}, remove "." if exists at the beginning
    project_path="${project_path}${project_dir#.}"

    echo "${project_path}" && return 0

  else

    # Log
    log_event "error" "Unable to get WWW_DATA_DIR value from .env file" "false"
    display --indent 6 --text "- Unable to get WWW_DATA_DIR value from .env file" --result FAIL --color RED

    return 1

  fi

}

################################################################################
# Get project config file
#
# Arguments:
#  ${1} = ${project_path} - On default=${PROJECTS_PATH}/${project_domain} on docker=${PROJECTS_PATH}/${project_name}/(wordpress-application)
#  ${2} = ${project_type}
#  ${3} = ${project_install_type}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_get_config_file() {

  local project_path="${1}"
  local project_type="${2}"
  local project_install_type="${3}"

  local project_dir

  if [[ ${project_install_type} == "docker"* ]]; then

    project_path="$(project_get_configured_docker_data_dir "${project_path}")"

  fi

  [[ ${project_type} == "wordpress" ]] && project_config_file="${project_path}/wp-config.php" || project_config_file="${project_path}/.env"

  if [[ -f "${project_config_file}" ]]; then

    # Log
    log_event "info" "Project config file: ${project_config_file}" "false"

    # Return
    echo "${project_config_file}" && return 0

  else

    # Log
    log_event "error" "Project config file: ${project_config_file} not found!" "false"

    # Return
    return 1

  fi

}

################################################################################
# Get configured database engine
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${project_type}
#  ${3} = ${project_install_type}
#
# Outputs:
#   ${db_engine} if ok, 1 on error.
################################################################################

# First we will try to read directly from a project config file (wp-config.php or .env)
# If project config file is not present, we will try to read from brolit project config
# If not, it will fail

function project_get_configured_database_engine() {

  local project_path="${1}"
  local project_type="${2}"
  local project_install_type="${3}"

  local db_engine
  local exitstatus

  # For Docker projects, check docker-compose configuration first
  if [[ "${project_install_type}" == "docker"* ]]; then
    # Check both docker-compose.yml and docker-compose.yaml
    if [[ -f "${project_path}/docker-compose.yml" ]] || [[ -f "${project_path}/docker-compose.yaml" ]]; then
      if grep -q "image:.*postgres" "${project_path}/docker-compose.yml" 2>/dev/null || 
         grep -q "image:.*postgres" "${project_path}/docker-compose.yaml" 2>/dev/null; then
        echo "postgres"
        return 0
      elif grep -q "image:.*mysql" "${project_path}/docker-compose.yml" 2>/dev/null || 
           grep -q "image:.*mysql" "${project_path}/docker-compose.yaml" 2>/dev/null; then
        echo "mysql"
        return 0
      fi
    fi
  fi

  # Get project config file
  project_config_file="$(project_get_config_file "${project_path}" "${project_type}" "${project_install_type}")"

  # Check project .env file
  if [[ -n "${project_config_file}" ]]; then

    case ${project_type} in

    wordpress)

      # Return
      echo "mysql" && return 0

      ;;

    laravel)

      db_engine="$(project_get_config_var "${project_config_file}" "DB_CONNECTION")"
      exitstatus=$?

      # Return
      echo "${db_engine}" && return ${exitstatus}

      ;;

    php)

      db_engine="$(project_get_config_var "${project_config_file}" "DB_CONNECTION")"
      exitstatus=$?

      # Return
      echo "${db_engine}" && return ${exitstatus}

      ;;

    nodejs)

      db_engine="$(project_get_config_var "${project_config_file}" "DB_CONNECTION")"
      exitstatus=$?

      # Return
      echo "${db_engine}" && return ${exitstatus}

      ;;

    *)

      # Log
      log_event "error" "Project Type unknown. Unable to get database engine from project config file" "false"
      display --indent 6 --text "- Unable to get database engine" --result FAIL --color RED

      return 1

      ;;

    esac

  else

    log_event "debug" "Can't find project config file. Now trying to read from brolit project config ..." "false"

    db_engine="$(project_get_brolit_config_var "${project_path}" "project[].database[].engine")"
    if [[ -n ${db_engine} ]]; then

      # Return
      echo "${db_engine}" && return 0

    else

      # Log
      log_event "error" "Unable to get database engine from project config file" "false"
      display --indent 6 --text "- Unable to get database engine" --result FAIL --color RED

      # Return
      return 1

    fi

  fi

}

################################################################################
# Set/Update database engine
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${project_type}
#  ${3} = ${project_install_type}
#  ${4} = ${db_engine}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_set_configured_database_engine() {

  local project_path="${1}"
  local project_type="${2}"
  local project_install_type="${3}"
  local db_engine="${4}"

  local got_error=0

  # Get project config file
  project_config_file="$(project_get_config_file "${project_path}" "${project_type}" "${project_install_type}")"

  case ${project_type} in

  wordpress)

    # Nothing to do
    # Return
    return 0

    ;;

  laravel)

    # Set/Update Project Config File
    project_set_config_var "${project_config_file}" "DB_CONNECTION" "${db_engine}" "none"
    got_error=$?

    ;;

  php)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_CONNECTION" "${db_engine}" "none"
    got_error=$?

    ;;

  nodejs)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_CONNECTION" "${db_engine}" "none"
    got_error=$?

    ;;

  *)

    log_event "error" "Unknown project type" "false"

    got_error=1

    ;;

  esac

  if [[ ${got_error} -eq 0 ]]; then

    # Set brolit project config var
    project_set_brolit_config_var "${project_path}" "project[].database[].engine" "${db_engine}"

    # Log
    log_event "info" "Database engine set to ${db_engine}" "false"
    display --indent 6 --text "- Database engine set to ${db_engine}" --result DONE --color GREEN

    return 0

  else

    # Log
    log_event "error" "Unable to set database engine to ${db_engine}" "false"
    display --indent 6 --text "- Unable to set database engine to ${db_engine}" --result FAIL --color RED

    return 1

  fi

}

# TODO: Get configured database host

################################################################################
# Set/Update database host
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${project_type}
#  ${3} = ${project_install_type}
#  ${4} = ${database_host} (localhost, docker_service_name)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_set_configured_database_host() {

  local project_path="${1}"
  local project_type="${2}"
  local project_install_type="${3}"
  local database_host="${4}"

  local got_error=0

  # Get project config file
  project_config_file="$(project_get_config_file "${project_path}" "${project_type}" "${project_install_type}")"

  case ${project_type} in

  wordpress)

    # Check if already set
    current_host="$(grep "define('DB_HOST'" "${project_config_file}" | cut -d "'" -f 4)"
    if [[ -n "${current_host}" && "${current_host}" == "${database_host}" ]]; then
      log_event "debug" "DB_HOST already set to ${database_host}, skipping" "false"
      return 0
    fi
    # Set/Update
    _wp_config_set_option "${project_config_file}" "DB_HOST" "${database_host}"
    got_error=$?

    ;;

  laravel)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_HOST" "${database_host}" "none"
    got_error=$?

    ;;

  php)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_HOST" "${database_host}" "none"
    got_error=$?

    ;;

  nodejs)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_HOST" "${database_host}" "none"
    got_error=$?

    ;;

  *)

    log_event "error" "Can't set database host on config file. Unknown project type" "false"

    return 1

    ;;

  esac

  if [[ ${got_error} -eq 0 ]]; then

    # Set brolit project config var
    project_set_brolit_config_var "${project_path}" "project[].database[].config[].host" "${database_host}"

    # Log
    log_event "info" "Database host set to ${database_host}" "false"
    display --indent 6 --text "- Database host set to ${database_host}" --result DONE --color GREEN

    return 0

  else

    # Log
    log_event "error" "Unable to set database host to ${database_host}" "false"
    display --indent 6 --text "- Unable to set database host to ${database_host}" --result FAIL --color RED

    return 1

  fi

}

################################################################################
# Get configured database
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${project_type}
#
# Outputs:
#   ${database_name} if ok, 1 on error.
################################################################################

function project_get_configured_database() {

  local project_path="${1}"
  local project_type="${2}"
  local project_install_type="${3}"

  local project_config_file
  local database_name
  local wpconfig_path

  # Get project config file
  project_config_file="$(project_get_config_file "${project_path}" "${project_type}" "${project_install_type}")"

  # Check project config file
  if [[ -n "${project_config_file}" ]]; then

    case ${project_type} in

    wordpress)

      # Get path without filename from $project_config_file
      wpconfig_path="$(dirname "${project_config_file}")"

      # Get option value
      database_name="$(wp_config_get_option "${wpconfig_path}" "DB_NAME")"

      # Return
      [[ -z ${database_name} ]] && return 1
      echo "${database_name}" && return 0

      ;;

    laravel)

      database_name="$(project_get_config_var "${project_config_file}" "DB_DATABASE")"

      # Return
      [[ -z ${database_name} ]] && return 1
      echo "${database_name}" && return 0

      ;;

    php)

      database_name="$(project_get_config_var "${project_config_file}" "DB_DATABASE")"

      # Return
      [[ -z ${database_name} ]] && return 1
      echo "${database_name}" && return 0

      ;;

    nodejs)

      database_name="$(project_get_config_var "${project_config_file}" "DB_DATABASE")"

      # Return
      [[ -z ${database_name} ]] && return 1
      echo "${database_name}" && return 0

      ;;

    *)

      echo "no-database" && return 0

      ;;

    esac

  else

    ## Project has database?
    db_status="$(project_get_brolit_config_var "${project_path}" "project[].database[].status")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      if [[ ${db_status} == "disabled" ]]; then
        echo "no-database" && return 0
      else
        ## Get database name
        database_name="$(project_get_brolit_config_var "${project_path}" "project[].database[].config[].name")"

        # Return
        [[ -z ${database_name} ]] && return 1
        echo "${database_name}" && return 0

      fi

    fi

  fi

}

################################################################################
# Set/Update configured database
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${project_type}
#  ${3} = ${project_install_type}
#  ${4} = ${database_name}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_set_configured_database() {

  local project_path="${1}"
  local project_type="${2}"
  local project_install_type="${3}"
  local database_name="${4}"

  local got_error=0
  local project_config_file

  # Get project config file
  project_config_file="$(project_get_config_file "${project_path}" "${project_type}" "${project_install_type}")"

  case ${project_type} in

  wordpress)

    # Check if already set
    current_db="$(wp_config_get_option "${project_config_file}" "DB_NAME")"
    if [[ -n "${current_db}" && "${current_db}" == "${database_name}" ]]; then
      log_event "debug" "DB_NAME already set to ${database_name}, skipping" "false"
      got_error=0
      return 0
    fi
    # Set/Update
    _wp_config_set_option "${project_config_file}" "DB_NAME" "${database_name}"
    got_error=$?

    ;;

  laravel)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_DATABASE" "${database_name}" "none"
    got_error=$?
    ;;

  php)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_DATABASE" "${database_name}" "none"
    got_error=$?

    ;;

  nodejs)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_DATABASE" "${database_name}" "none"
    got_error=$?

    ;;

  *)

    log_event "error" "Unknown project type" "false"

    got_error=1

    ;;

  esac

  if [[ ${got_error} -eq 0 ]]; then

    # Set brolit project config var
    project_set_brolit_config_var "${project_path}" "project[].database[].config[].name" "${database_name}"

    # Log
    log_event "info" "Database name set to ${database_name}" "false"
    display --indent 6 --text "- Database name set to ${database_name}" --result DONE --color GREEN

    return 0

  else

    # Log
    log_event "error" "Unable to set database name to ${database_name}" "false"
    display --indent 6 --text "- Unable to set database name to ${database_name}" --result FAIL --color RED

    return 1

  fi

}

################################################################################
# Get configured database user
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${project_type}
#
# Outputs:
#   ${db_user} if ok, 1 on error.
################################################################################

function project_get_configured_database_user() {

  local project_path="${1}"
  local project_type="${2}"
  local project_install_type="${3}"

  local db_user
  local project_config_file

  # Get project config file
  project_config_file="$(project_get_config_file "${project_path}" "${project_type}" "${project_install_type}")"

  # Check project .env file
  if [[ -n "${project_config_file}" ]]; then

    case ${project_type} in

    wordpress)

      # Get path without filename from $project_config_file
      wpconfig_path="$(dirname "${project_config_file}")"

      # Get option value
      db_user="$(wp_config_get_option "${wpconfig_path}" "DB_USER")"

      # Return
      echo "${db_user}" && return 0

      ;;

    laravel)

      db_user="$(project_get_config_var "${project_config_file}" "DB_USERNAME")"

      # Return
      echo "${db_user}" && return 0

      ;;

    php)

      db_user="$(project_get_config_var "${project_config_file}" "DB_USERNAME")"

      # Return
      echo "${db_user}" && return 0

      ;;

    nodejs)

      db_user="$(project_get_config_var "${project_config_file}" "DB_USERNAME")"

      # Return
      echo "${db_user}" && return 0

      ;;

    *)
      log_event "debug" "No database information for project." "false"
      return 1
      ;;

    esac

  else

    # First try to read from brolit project config
    db_user="$(project_get_brolit_config_var "${project_path}" "project[].database[].config[].user")"

    if [[ -n ${db_user} ]]; then

      log_event "debug" "Extracted db_user : ${db_user}" "false"

      # Return
      echo "${db_user}" && return 0

    else

      # Log
      log_event "error" "Unable to extract db_user from brolit project config" "false"

      return 1

    fi

  fi

}

################################################################################
# Set/Update database user
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${project_type}
#  ${3} = ${project_install_type}
#  ${4} = ${database_username}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_set_configured_database_user() {

  local project_path="${1}"
  local project_type="${2}"
  local project_install_type="${3}"
  local database_username="${4}"

  local got_error=0

  # Get project config file
  project_config_file="$(project_get_config_file "${project_path}" "${project_type}" "${project_install_type}")"

  case ${project_type} in

  wordpress)

    # Check if already set
    current_user="$(wp_config_get_option "${project_config_file}" "DB_USER")"
    if [[ -n "${current_user}" && "${current_user}" == "${database_username}" ]]; then
      log_event "debug" "DB_USER already set to ${database_username}, skipping" "false"
      got_error=0
      return 0
    fi
    # Set/Update
    _wp_config_set_option "${project_config_file}" "DB_USER" "${database_username}"
    got_error=$?

    ;;

  laravel)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_USERNAME" "${database_username}" "none"
    got_error=$?

    ;;

  php)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_USERNAME" "${database_username}" "none"
    got_error=$?

    ;;

  nodejs)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_USERNAME" "${database_username}" "none"
    got_error=$?

    ;;

  *)

    log_event "error" "Unknown project type" "false"

    return 1

    ;;

  esac

  if [[ ${got_error} -eq 0 ]]; then

    # Set brolit project config var
    project_set_brolit_config_var "${project_path}" "project[].database[].config[].user" "${database_username}"

    # Log
    log_event "info" "Database username set to ${database_username}" "false"
    display --indent 6 --text "- Database username set to ${database_username}" --result DONE --color GREEN

    return 0

  else

    # Log
    log_event "error" "Unable to set database username to ${database_username}" "false"
    display --indent 6 --text "- Unable to set database username to ${database_username}" --result FAIL --color RED

    return 1

  fi

}

################################################################################
# Get configured database user password
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${project_type}
#
# Outputs:
#   ${db_pass} if ok, 1 on error.
################################################################################

function project_get_configured_database_userpassw() {

  local project_path="${1}"
  local project_type="${2}"
  local project_install_type="${3}"

  local database_userpassw

  # Get project config file
  project_config_file="$(project_get_config_file "${project_path}" "${project_type}" "${project_install_type}")"

  # Check project .env file
  if [[ -n "${project_config_file}" ]]; then

    case ${project_type} in

    wordpress)

      wpconfig_path=$(wp_config_path "${project_config_file}")

      database_userpassw="$(wp_config_get_option "${wpconfig_path}" "DB_PASSWORD")"

      # Return
      echo "${database_userpassw}" && return 0

      ;;

    laravel)

      database_userpassw="$(project_get_config_var "${project_config_file}" "DB_PASSWORD")"

      # Return
      echo "${database_userpassw}" && return 0

      ;;

    php)

      database_userpassw="$(project_get_config_var "${project_config_file}" "DB_PASSWORD")"

      # Return
      echo "${database_userpassw}" && return 0

      ;;

    nodejs)

      database_userpassw="$(project_get_config_var "${project_config_file}" "DB_PASSWORD")"

      # Return
      echo "${database_userpassw}" && return 0

      ;;

    *)

      log_event "debug" "No database information for project." "false"
      return 1
      ;;

    esac

  else

    # First try to read from brolit project config
    database_userpassw="$(project_get_brolit_config_var "${project_path}" "project[].database[].config[].pass")"

    if [[ -n ${database_userpassw} && ${database_userpassw} != "false" ]]; then

      log_event "debug" "Extracted database_userpassw: ${database_userpassw}" "false"

      # Return
      echo "${database_userpassw}" && return 0

    else

      # Log error
      log_event "error" "Unable to extract database_userpassw from brolit project config" "false"

      return 1

    fi

  fi

}

################################################################################
# Set/Update database user password
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${project_type}
#  ${3} = ${project_install_type}
#  ${4} = ${database_userpassw}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_set_configured_database_userpassw() {

  local project_path="${1}"
  local project_type="${2}"
  local project_install_type="${3}"
  local database_userpassw="${4}"

  # Get project config file
  project_config_file="$(project_get_config_file "${project_path}" "${project_type}" "${project_install_type}")"

  case ${project_type} in

  wordpress)

    # Set/Update
    _wp_config_set_option "${project_config_file}" "DB_PASSWORD" "${database_userpassw}"

    # Return
    return 0

    ;;

  laravel)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_PASSWORD" "${database_userpassw}" "none"

    return 0

    ;;

  php)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_PASSWORD" "${database_userpassw}" "none"

    return 0

    ;;

  nodejs)

    # Set/Update
    project_set_config_var "${project_config_file}" "DB_PASSWORD" "${database_userpassw}" "none"

    return 0

    ;;

  *)

    log_event "error" "Unknown project type" "false"

    return 1

    ;;

  esac

  if [[ ${got_error} -eq 0 ]]; then

    # Set brolit project config var
    project_set_brolit_config_var "${project_path}" "project[].database[].config[].pass" "${database_userpassw}"

    # Log
    log_event "info" "Database user password set to ${database_userpassw}" "false"
    display --indent 6 --text "- Database user password set to ${database_userpassw}" --result DONE --color GREEN

    return 0

  else

    # Log
    log_event "error" "Unable to set database user password to ${database_userpassw}" "false"
    display --indent 6 --text "- Unable to set database user password to ${database_userpassw}" --result FAIL --color RED

    return 1

  fi

}

################################################################################
# Project install
#
# Arguments:
#  ${1} = ${dir_path}
#  ${2} = ${project_type}
#  ${3} = ${project_domain}
#  ${4} = ${project_name}
#  ${5} = ${project_stage}
#  ${6} = ${project_root_domain}   # Optional
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

  local cert_path
  local suggested_stage
  local project_root_domain
  local project_secondary_subdomain

  log_section "Project Installer (${project_type})"

  # Check if nginx is installed
  if [[ ! $(command -v nginx) ]]; then
    # Log
    log_event "error" "Nginx is not installed" "false"
    display --indent 6 --text "- Creating ${project_type} project" --result "FAIL" --color RED
    display --indent 8 --text "Nginx is not installed" --tcolor RED
    return 1
  fi

  # Project Type
  if [[ -z ${project_type} ]]; then
    project_type="$(project_ask_type "")"
    [[ $? -eq 1 ]] && return 1
  fi

  # Check project type requirements BEFORE asking for project details
  case ${project_type} in
    wordpress)
      # WordPress requires both PHP and MySQL
      # Check if php is installed
      if [[ ! $(command -v php) ]]; then
        display --indent 6 --text "- Checking PHP installation" --result "FAIL" --color RED
        display --indent 8 --text "PHP is not installed" --tcolor RED
        log_event "error" "PHP is not installed for ${project_type} project" "false"

        # Check if docker is available
        if [[ $(command -v docker) ]]; then
          display --indent 8 --text "Docker is available on this system" --tcolor GREEN
          if whiptail --title "PHP Not Found" --yesno "PHP is not installed, but Docker is available.\n\nWould you like to create a Dockerized ${project_type} project instead?" 12 70; then
            # Call docker installation
            docker_project_install "${PROJECTS_PATH}" "${project_type}" ""
            return $?
          else
            display --indent 8 --text "Operation cancelled by user" --tcolor YELLOW
            return 1
          fi
        else
          display --indent 8 --text "Please install PHP or Docker to continue" --tcolor YELLOW
          return 1
        fi
      fi

      # Check if mysql is installed (required for WordPress)
      if [[ ! $(command -v mysql) ]]; then
        display --indent 6 --text "- Checking MySQL installation" --result "FAIL" --color RED
        display --indent 8 --text "MySQL is not installed" --tcolor RED
        log_event "error" "MySQL is not installed for ${project_type} project" "false"

        # Check if docker is available
        if [[ $(command -v docker) ]]; then
          display --indent 8 --text "Docker is available on this system" --tcolor GREEN
          if whiptail --title "MySQL Not Found" --yesno "MySQL is not installed, but Docker is available.\n\nWould you like to create a Dockerized ${project_type} project instead?" 12 70; then
            # Call docker installation
            docker_project_install "${PROJECTS_PATH}" "${project_type}" ""
            return $?
          else
            display --indent 8 --text "Operation cancelled by user" --tcolor YELLOW
            return 1
          fi
        else
          display --indent 8 --text "Please install MySQL or Docker to continue" --tcolor YELLOW
          return 1
        fi
      fi
      ;;

    php)
      # PHP projects require PHP but MySQL is optional
      # Check if php is installed
      if [[ ! $(command -v php) ]]; then
        display --indent 6 --text "- Checking PHP installation" --result "FAIL" --color RED
        display --indent 8 --text "PHP is not installed" --tcolor RED
        log_event "error" "PHP is not installed for ${project_type} project" "false"

        # Check if docker is available
        if [[ $(command -v docker) ]]; then
          display --indent 8 --text "Docker is available on this system" --tcolor GREEN
          if whiptail --title "PHP Not Found" --yesno "PHP is not installed, but Docker is available.\n\nWould you like to create a Dockerized ${project_type} project instead?" 12 70; then
            # Call docker installation
            docker_project_install "${PROJECTS_PATH}" "${project_type}" ""
            return $?
          else
            display --indent 8 --text "Operation cancelled by user" --tcolor YELLOW
            return 1
          fi
        else
          display --indent 8 --text "Please install PHP or Docker to continue" --tcolor YELLOW
          return 1
        fi
      fi

      # Check if mysql is installed (optional warning for PHP)
      if [[ ! $(command -v mysql) ]]; then
        display --indent 6 --text "- Checking MySQL installation" --result "WARN" --color YELLOW
        display --indent 8 --text "MySQL is not installed" --tcolor YELLOW
        display --indent 8 --text "Database creation will be skipped" --tcolor YELLOW
        log_event "warning" "MySQL is not installed - database creation will be skipped" "false"

        # Ask user if they want to continue without MySQL or use Docker
        if whiptail --title "MySQL Not Found" --yesno "MySQL is not installed.\n\nYou can:\n- Continue without database (for static PHP sites)\n- Use Docker version (includes MySQL)\n\nContinue without MySQL?" 14 70; then
          display --indent 8 --text "Continuing without MySQL" --tcolor GREEN
          # Set flag to skip database creation
          export SKIP_DATABASE_CREATION="true"
        else
          # User chose not to continue, check if docker is available
          if [[ $(command -v docker) ]]; then
            if whiptail --title "Use Docker Instead?" --yesno "Would you like to create a Dockerized ${project_type} project instead?\n\n(It will include MySQL)" 10 70; then
              docker_project_install "${PROJECTS_PATH}" "${project_type}" ""
              return $?
            fi
          fi
          display --indent 8 --text "Operation cancelled by user" --tcolor YELLOW
          return 1
        fi
      fi
      ;;
  esac

  # Project Domain
  if [[ -z ${project_domain} ]]; then
    project_domain="$(project_ask_domain "")"
    [[ $? -eq 1 ]] && return 1
  fi

  # If ${dir_path} is empty, use default project path
  [[ -z ${dir_path} ]] && dir_path="${PROJECTS_PATH}"

  # Project Path
  project_path="${dir_path}/${project_domain}"
  if [[ -f ${project_path} ]]; then
    # Log
    display --indent 6 --text "- Creating ${project_type} project" --result "FAIL" --color RED
    display --indent 8 --text "Destination folder '${project_path}' already exist"
    log_event "error" "Destination folder '${project_path}' already exist, aborting ..." "false"
    return 1
  fi

  # TODO: check when add www.DOMAIN.com and then select other stage != prod
  if [[ -z ${project_stage} ]]; then
    # Project stage
    suggested_stage="$(domain_get_subdomain_part "${project_domain}")"
    project_stage="$(project_ask_stage "${suggested_stage}")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 1 ]]; then
      # Log
      log_event "info" "Operation cancelled!" "false"
      display --indent 2 --text "- Asking project stage" --result SKIPPED --color YELLOW
      return 1
    fi
  fi

  if [[ -z ${project_name} ]]; then
    # Project Name
    possible_project_name="$(project_get_name_from_domain "${project_domain}")"
    project_name="$(project_ask_name "${possible_project_name}")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 1 ]]; then
      # Log
      log_event "info" "Operation cancelled!" "false"
      display --indent 2 --text "- Asking project name" --result SKIPPED --color YELLOW
      return 1
    fi
  fi

  # Project root domain
  project_root_domain="$(domain_get_root "${project_domain}")"

  [[ ${project_domain} == "${project_root_domain}" ]] && project_domain="www.${project_domain}" && project_secondary_subdomain="${project_root_domain}"

  case ${project_type} in

  wordpress)

    # Check if wp-cli is installed
    wpcli_install_if_not_installed

    # Execute function
    wordpress_project_installer "${project_path}" "${project_domain}" "${project_name}" "${project_stage}" "${project_root_domain}" "${project_install_mode}"
    [[ $? -eq 1 ]] && return 1

    ;;

  php)

    project_installer_php "${project_path}" "${project_domain}" "${project_name}" "${project_stage}" "${project_root_domain}"
    [[ $? -eq 1 ]] && return 1

    ;;

  *)
    log_event "error" "Project type '${project_type}' unkwnown, aborting ..." "false"
    return 1
    ;;

  esac

  # Project domain configuration (webserver+certbot+DNS)
  https_enable="$(project_update_domain_config "${project_domain}" "${project_type}" "default" "")"

  # Define project site url
  [[ ${https_enable} == "true" ]] && project_site_url="https://${project_domain}" || project_site_url="http://${project_domain}"

  # Startup Script for WordPress installation
  if [[ ${BROLIT_EXEC_TYPE} == "default" && ${project_type} == "wordpress" ]]; then

    wpcli_run_startup_script "${project_path}" "default" "${project_site_url}"

    if [[ $? -eq 1 ]]; then

      # Show error message
      display --indent 6 --text "- Installing WordPress project" --result "FAIL" --color RED
      display --indent 8 --text "Visit ${project_site_url} and complete the installation" --tcolor YELLOW
      display --indent 8 --text " or delete the project and star over again" --tcolor YELLOW

      return 1

    fi

  fi

  # Post-restore/install tasks
  project_install_type="default"
  project_post_install_tasks "${project_path}" "${project_type}" "${project_install_type}" "${project_name}" "${project_stage}" "${database_user_passw}" "" ""

  # TODO: refactor this
  # Cert config files
  cert_path=""
  [[ -d "/etc/letsencrypt/live/${project_domain}" ]] && cert_path="/etc/letsencrypt/live/${project_domain}"
  [[ -d "/etc/letsencrypt/live/www.${project_domain}" ]] && cert_path="/etc/letsencrypt/live/www.${project_domain}"

  # Create project config file
  project_update_brolit_config "${project_path}" "${project_name}" "${project_stage}" "${project_type} " "enabled" "mysql" "${database_name}" "localhost" "${database_user}" "${database_user_passw}" "${project_domain}" "${project_secondary_subdomain}" "/etc/nginx/sites-available/${project_domain}" "" "${cert_path}"

  # Log
  log_event "info" "New ${project_type} project installation for '${project_domain}' finished ok." "false"
  display --indent 6 --text "- ${project_type} project installation" --result "DONE" --color GREEN
  display --indent 8 --text "for domain ${project_domain}"

  # Send notification
  send_notification "${SERVER_NAME}" "New ${project_type} project installation for '${project_domain}' finished ok!" "success"

}

################################################################################
# Project delete files
#
# Arguments:
#  ${1} = ${project_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_delete_files() {

  local project_domain="${1}"

  local backup_type
  local compose_file
  local project_type
  local project_install_type

  backup_type="site"

  # Log
  log_subsection "Delete Files"

  # Trying to know project type and project install type
  project_type=$(project_get_type "${PROJECTS_PATH}/${project_domain}")
  project_install_type=$(project_get_install_type "${PROJECTS_PATH}/${project_domain}")

  #clear_previous_lines "1"

  if [[ -n ${project_type} && -n ${project_install_type} ]]; then

    # If project_install_type == "docker"*, stop and delete containers
    if [[ ${project_install_type} == "docker"* ]]; then

      compose_file="${PROJECTS_PATH}/${project_domain}/docker-compose.yml"

      if [[ -f "${compose_file}" ]]; then

        docker_compose_stop "${compose_file}"
        [[ $? -eq 1 ]] && return 1

        docker_compose_rm "${compose_file}"
        [[ $? -eq 1 ]] && return 1

      fi

    fi

    # Creating new folder structure for old projects
    storage_create_dir "/${SERVER_NAME}/projects-offline"
    storage_create_dir "/${SERVER_NAME}/projects-offline/${backup_type}"

    # Moving old project backups to another directory
    storage_move "/${SERVER_NAME}/projects-online/${backup_type}/${project_domain}" "/${SERVER_NAME}/projects-offline/${backup_type}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Delete project files on server
      rm --force --recursive "${PROJECTS_PATH}/${project_domain:?}"

      # Log
      log_event "info" "Project files deleted for ${project_domain}" "false"
      display --indent 6 --text "- Deleting project files on server" --result "DONE" --color GREEN

      # Make a copy of nginx configuration file
      copy_files "/etc/nginx/sites-available/${project_domain}" "${BROLIT_TMP_DIR}"

      return 0

    else

      # Log
      log_event "info" "Something went wrong trying to move old backups." "false"
      display --indent 6 --text "- Deleting project files on server" --result "FAIL" --color RED

      return 1

    fi

  else

    # Log
    log_event "info" "Something went wrong trying to know project type and project install type." "false"
    display --indent 6 --text "- Deleting project files on server" --result "FAIL" --color RED

    return 1

  fi

}

################################################################################
# Project delete database
#
# Arguments:
#  ${1} = ${database_name}
#  ${2} = ${database_user} - Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_delete_database() {

  local database_name="${1}"
  local database_user="${2}"
  local database_engine="${3}"
  local project_install_type="${4}"

  local databases
  local chosen_database
  local project_name
  local backup_project_database_output

  # List databases
  databases="$(database_list "all" "${database_engine}" "")"
  chosen_database="$(whiptail --title "DATABASES" --menu "Choose a Database to delete" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) --default-item "${database_name}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # Log
    log_subsection "Delete Database (${database_engine})"

    # Remove stage from database name
    project_name="${chosen_database%_*}"

    # TODO: get user from project config
    [[ -z ${database_user} ]] && database_user="${project_name}_user"

    # Make database backup
    backup_project_database_output="$(backup_project_database "${chosen_database}" "${database_engine}")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Moving deleted project backups to another directory
      storage_create_dir "/${SERVER_NAME}/projects-offline"
      storage_create_dir "/${SERVER_NAME}/projects-offline/database"
      storage_move "/${SERVER_NAME}/projects-online/database/${chosen_database}" "/${SERVER_NAME}/projects-offline/database"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Delete project database
        database_drop "${chosen_database}" "${database_engine}"

      fi

    else

      # TODO: better error handling
      log_event "error" "${backup_project_database_output}" "false"

    fi

    # Delete mysql user
    while true; do

      echo -e "${B_RED}${ITALIC} > Remove database user: ${database_user}? Maybe is used by another project.${ENDCOLOR}"
      read -r -p "Please type 'y' or 'n'" yn

      case $yn in

      [Yy]*)

        # Log
        clear_previous_lines "2"

        # User delete
        database_user_delete "${database_user}" "localhost" "${database_engine}"

        break

        ;;

      [Nn]*)

        # Log
        clear_previous_lines "2"
        log_event "warning" "Aborting database user deletion ..." "false"
        display --indent 6 --text "- Deleting database user" --result "SKIPPED" --color YELLOW

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
#  ${1} = ${project_domain}
#  ${2} = ${delete_cf_entry} - optional (true or false)
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_delete() {

  local project_domain="${1}"
  local delete_cf_entry="${2}"

  local project_type
  local project_root_domain
  local project_install_type

  local files_skipped="false"

  log_section "Project Delete"
  #log_subsection "Reading Project Config"

  if [[ -z ${project_domain} ]]; then
    
    # Folder where sites are hosted: ${PROJECTS_PATH}
    menu_title="PROJECT DIRECTORY TO DELETE"
    directory_browser "${menu_title}" "${PROJECTS_PATH}"
    
    # Directory_broser returns: " ${filepath}"/"${filename}
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
    project_type="$(project_get_type "${PROJECTS_PATH}/${project_domain}")"
    project_install_type="$(project_get_install_type "${PROJECTS_PATH}/${project_domain}")"

    # Get db credentials from project config
    project_db_name=$(project_get_configured_database "${PROJECTS_PATH}/${project_domain}" "${project_type}" "${project_install_type}")
    project_db_user=$(project_get_configured_database_user "${PROJECTS_PATH}/${project_domain}" "${project_type}" "${project_install_type}")
    project_db_engine="$(project_get_configured_database_engine "${PROJECTS_PATH}/${project_domain}" "${project_type}" "${project_install_type}")"

    [[ -z "${project_db_engine}" ]] && project_db_engine="$(database_ask_engine)"

    # For Docker projects: stop containers FIRST to ensure consistent backup
    if [[ ${project_install_type} == "docker"* ]]; then
      local compose_file="${PROJECTS_PATH}/${project_domain}/docker-compose.yml"

      if [[ -f "${compose_file}" ]]; then
        log_subsection "Stopping Docker Containers"
        docker_compose_stop "${compose_file}"
        if [[ $? -eq 1 ]]; then
          log_event "error" "Failed to stop Docker containers" "false"
          display --indent 6 --text "- Stopping docker stack" --result "FAIL" --color RED
          return 1
        fi
      fi
    fi

    # Remove unwanted output
    clear_previous_lines "1"

    # Make one last backup (now containers are stopped for Docker projects)
    backup_project "${project_domain}" "all"
    [[ $? -eq 1 ]] && return 1

    # Delete Files
    project_delete_files "${project_domain}"
    if [[ $? -eq 1 ]]; then

      # Log
      display --indent 6 --text "- Deleting project files" --result "FAIL" --color RED
      display --indent 8 --text "Please read the log file for more information:" --tcolor YELLOW
      display --indent 8 --text "${BROLIT_LOG_FILE}" --tcolor YELLOW
      log_event "error" "Project files deletion failed." "false"

      return 1

    fi

    # Delete nginx configuration file
    nginx_server_delete "${project_domain}"

    # Delete certificates
    certbot_certificate_delete "${project_domain}"

  fi

  [[ -z ${project_type} ]] && project_type="$(project_ask_type)"
  [[ -z ${project_install_type} ]] && project_install_type="default"

  # Delete Database (both for Docker and standard installations)
  if [[ -n ${project_db_engine} && -n ${project_db_name} ]]; then
    if [[ ${project_install_type} == "docker"* ]]; then
      # For Docker projects, get container name and handle database deletion
      if [[ -f "${PROJECTS_PATH}/${project_domain}/.env" ]]; then
        export $(grep -v '^#' "${PROJECTS_PATH}/${project_domain}/.env" | xargs)
        container_name="${PROJECT_NAME}_mysql"

        # Moving deleted project database backups to offline directory
        storage_create_dir "/${SERVER_NAME}/projects-offline"
        storage_create_dir "/${SERVER_NAME}/projects-offline/database"
        storage_move "/${SERVER_NAME}/projects-online/database/${project_db_name}" "/${SERVER_NAME}/projects-offline/database"

        # Delete database from Docker container
        database_drop "${project_db_name}" "${project_db_engine}" "${container_name}"

      else
        log_event "warning" ".env file not found for Docker project. Skipping database deletion." "false"
      fi
    else
      # For standard installations
      project_delete_database "${project_db_name}" "${project_db_user}" "${project_db_engine}" "${project_install_type}"
    fi
  else
    log_event "warning" "Can not determine database engine or database name. Skipping database deletion." "false"
  fi

  # Cloudflare DNS deletion (moved to end, after all deletions are done)
  if [[ ${files_skipped} == "false" && ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

    log_subsection "DNS Cleanup"

    project_root_domain="$(domain_get_root "${project_domain}")"
    project_actual_ip="$(cloudflare_get_record_details "${project_root_domain}" "${project_domain}" "content")"

    if [[ ${project_actual_ip} == "${SERVER_IP}" ]]; then

      if [[ ${delete_cf_entry} != "true" ]]; then

        # Cloudflare Manager - ask BEFORE deleting
        local cf_delete_domain
        cf_delete_domain="$(whiptail --title "CLOUDFLARE MANAGER" --yesno "Do you want to delete the Cloudflare DNS entry for: ${project_domain}?" 10 60 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          # Delete Cloudflare entries
          cloudflare_delete_record "${project_root_domain}" "${project_domain}" "A"

        else

          # Log
          log_event "info" "Cloudflare entries not deleted. Skipped by user." "false"
          display --indent 6 --text "- Deleting Cloudflare entries" --result "SKIPPED" --color YELLOW

        fi

      else

        # Delete Cloudflare entries (auto mode)
        cloudflare_delete_record "${project_root_domain}" "${project_domain}" "A"

      fi

    else

      # Log
      log_event "info" "Cloudflare entries not deleted. The Cloudflare entry's IP address differs from the server's IP address." "false"
      display --indent 6 --text "- Deleting Cloudflare entries" --result "SKIPPED" --color YELLOW
      display --indent 8 --text "The Cloudflare entry's IP address differs from the server's IP address." --tcolor YELLOW

    fi

  fi

  # TODO: backup project config file, maybe inside /site ?

  # Delete config file
  project_config="${BROLIT_CONFIG_PATH}/${project_domain}_conf.json"
  rm --force "${project_config}"

  # Log
  log_event "info" "Removing project config file: ${project_config}" "false"
  display --indent 6 --text "- Removing project config file" --result "DONE" --color GREEN

  # Send single notification at the end (after everything is deleted)
  log_subsection "Notifications"
  send_notification "${SERVER_NAME}" "Project '${project_domain}' deleted successfully!" "warning"

  # Delete tmp backups
  display --indent 2 --text "Please, remove ${BROLIT_TMP_DIR} after check backup was uploaded ok" --tcolor YELLOW

}

################################################################################
# Delete Docker Project (files, database, config, certs)
#
# @deprecated This function is deprecated. Use project_delete() instead, which
#             now handles both standard and Docker projects automatically.
#
# Arguments:
#  ${1} = ${project_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function delete_docker_project() {

  local project_domain="${1}"

  log_event "warning" "delete_docker_project() is deprecated. Use project_delete() instead." "false"

  # Redirect to unified project_delete function
  project_delete "${project_domain}" ""
  return $?

}

################################################################################
# Change project status (online or offline)
#
# Arguments:
#   ${1} = ${project_status} (online,offline)
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
# Get project install type
#
# Arguments:
#   ${1} = ${dir_path}
#
# Outputs:
#   ${project_install_type}
################################################################################

function project_get_install_type() {

  local dir_path="${1}"

  local project_install_type

  if [[ -n ${dir_path} ]]; then

    # docker-compose?
    docker="$(
      find "${dir_path}" -maxdepth 2 -name "docker-compose.yml" -type f
      find "${dir_path}" -maxdepth 2 -name "docker-compose.yaml" -type f
    )"
    if [[ -n ${docker} ]]; then

      project_install_type="docker-compose"

      # Log
      log_event "debug" "Project install type: ${project_install_type}" "false"

      # Return
      echo "${project_install_type}" && return 0

    else

      # Return
      echo "default" && return 0

    fi

  else

    # TODO: get from brolit project config?

    return 1

  fi

}

################################################################################
# Get project type
#
# Arguments:
#   ${1} = ${dir_path}
#
# Outputs:
#   ${project_type}
################################################################################

function project_get_type() {

  local dir_path="${1}"

  local project_type
  local wp_path
  local laravel
  local search_paths

  # TODO: if brolit_conf exists, should check this file and get project type

  # Ensure the directory exists
  if [[ -n ${dir_path} && -d ${dir_path} ]]; then

    # For Docker projects with Brolit standard structure, check subdirectories
    if [[ -f "${dir_path}/docker-compose.yml" ]] || [[ -f "${dir_path}/docker-compose.yaml" ]]; then
      # Check both root and standard subdirectories (wordpress/, application/)
      search_paths=("${dir_path}" "${dir_path}/wordpress" "${dir_path}/application")
      log_event "debug" "Docker project detected, searching in multiple paths" "false"
    else
      # For non-Docker projects, only check root directory
      search_paths=("${dir_path}")
    fi

    # Check for WordPress in all search paths
    for search_path in "${search_paths[@]}"; do
      if [[ -d "${search_path}" ]]; then
        wp_path="$(wp_config_path "${search_path}")"
        if [[ -n ${wp_path} ]]; then

          project_type="wordpress"

          # Log
          log_event "debug" "Project type '${project_type}' found in ${search_path}" "false"
          display --indent 8 --text "Project type: ${project_type}" --tcolor MAGENTA

          # Return
          echo "${project_type}" && return 0

        fi
      fi
    done

    # Check for React by looking for specific react-scripts in package.json
    if [[ -f "${dir_path}/package.json" ]] && grep -q "react-scripts" "${dir_path}/package.json"; then

      project_type="react"

      # Log
      log_event "debug" "Project type '${project_type}' for ${dir_path}" "false"
      display --indent 8 --text "Project type: ${project_type}" --tcolor MAGENTA

      # Return
      echo "${project_type}" && return 0

    fi

    # Check for Python
    if [[ -f "${dir_path}/setup.py" || -f "${dir_path}/Pipfile" || -f "${dir_path}/pyproject.toml" ]]; then

      project_type="python"

      # Log
      log_event "debug" "Project type '${project_type}' for ${dir_path}" "false"
      display --indent 8 --text "Project type: ${project_type}" --tcolor MAGENTA

      # Return
      echo "${project_type}" && return 0

    fi

    # Check for simple PHP in all search paths
    for search_path in "${search_paths[@]}"; do
      if [[ -d "${search_path}" ]] && [[ $(find "${search_path}" -maxdepth 1 -type f -name "*.php" | wc -l) -gt 0 ]]; then

        project_type="php"

        # Log
        log_event "debug" "Project type '${project_type}' found in ${search_path}" "false"
        display --indent 8 --text "Project type: ${project_type}" --tcolor MAGENTA

        # Return
        echo "${project_type}" && return 0

      fi
    done

    # Check for simple HTML in all search paths
    for search_path in "${search_paths[@]}"; do
      if [[ -d "${search_path}" ]] && [[ $(find "${search_path}" -maxdepth 1 -type f -name "*.html" | wc -l) -gt 0 ]] && [[ $(find "${search_path}" -maxdepth 1 -type f \( -name "*.php" -o -name "*.py" \) | wc -l) -eq 0 ]]; then

        project_type="html"

        # Log
        log_event "debug" "Project type '${project_type}' found in ${search_path}" "false"
        display --indent 8 --text "Project type: ${project_type}" --tcolor MAGENTA

        # Return
        echo "${project_type}" && return 0

      fi
    done

    # Unknown
    log_event "debug" "Project type 'unknown' for ${dir_path}" "false"

    # Return
    echo "other" && return 0

  else

    log_event "error" "Can't get project type, directory '${dir_path}' doesn't exist." "false"

    return 1

  fi

}

################################################################################
# Create nginx server for an existing project
#
# Arguments:
#   ${1} = ${dir_path}
#
# Outputs:
#   ${project_type}
################################################################################

function project_create_nginx_server() {

  local project_domain
  local project_root_domain
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
    project_root_domain="$(domain_get_root "${project_domain}")"

    # Try to get project type & project install type
    suggested_project_type="$(project_get_type "${filepath}/${filename}")"
    suggested_project_install_type=$(project_get_install_type "${filepath}/${filename}")

    # Aks project type
    project_type="$(project_ask_type "${suggested_project_type}")"
    project_install_type="$(project_ask_install_type "${suggested_project_install_type}")"

    # Docker projects need to be configured as proxy
    if [[ ${project_install_type} == "docker" ]]; then
      project_install_type="proxy"

      # Try to extract port from .env file
      suggested_port="$(project_get_port_from_env "${filepath}/${filename}")"

      # Ask for port with the suggestion from .env (if found)
      project_port="$(project_ask_port "${suggested_port}")"
    fi

    # Update project domain config
    https_enable="$(project_update_domain_config "${project_domain}" "${project_type}" "${project_install_type}" "${project_port}")"

  else

    display --indent 6 "Selecting website to work with" --result SKIPPED --color YELLOW

  fi

}

################################################################################
# Install PHP project
#
# Arguments:
#  ${1} = ${project_path}
#  ${2} = ${project_domain}
#  ${3} = ${project_name}
#  ${4} = ${project_stage}
#  ${5} = ${project_root_domain}   # Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_installer_php() {

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

  # Create database and user (only if MySQL is available and not skipped)
  if [[ "${SKIP_DATABASE_CREATION}" != "true" ]]; then
    db_project_name="$(database_name_sanitize "${project_name}")"
    database_name="${db_project_name}_${project_stage}"
    database_user="${db_project_name}_user"
    database_user_passw="$(openssl rand -hex 12)"

    # Create database and user
    mysql_database_create "${database_name}"
    mysql_user_create "${database_user}" "${database_user_passw}" ""
    mysql_user_grant_privileges "${database_user}" "${database_name}" ""

    log_event "info" "Database ${database_name} created successfully" "false"
    display --indent 6 --text "- Creating project database" --result "DONE" --color GREEN
  else
    log_event "info" "Database creation skipped (MySQL not available)" "false"
    display --indent 6 --text "- Creating project database" --result "SKIPPED" --color YELLOW
  fi

  # Create index.php
  echo "<?php phpinfo(); ?>" >"${project_path}/index.php"

  # Change ownership
  change_ownership "www-data" "www-data" "${project_path}"

}

################################################################################
# Update domain configuration (Nginx + Cloudflare)
#
# Arguments:
#  ${1} = ${project_domain}
#  ${2} = ${project_type}
#  ${3} = ${project_install_type}
#  ${4} = ${project_port}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_update_domain_config() {

  local project_domain="${1}"
  local project_type="${2}"
  local project_install_type="${3}"
  local project_port="${4}"

  local project_root_domain
  local project_https_enable="false"

  # Log
  log_subsection "Update Domain Configuration"

  project_root_domain="$(domain_get_root "${project_domain}")"

  # Validate port if provided
  if [[ -n "${project_port}" && ! "${project_port}" =~ ^[0-9]+$ ]]; then
    log_event "error" "Invalid port number: ${project_port}" "false"
    display --indent 6 --text "- Port validation" --result "FAIL" --color RED
    return 1
  fi

  # Set project type for dockerized installations (internally stored as "proxy")
  [[ ${project_install_type} == "proxy" || ${project_install_type} == "docker"* ]] && project_type="proxy"

  # Working with root domain or www?
  if [[ ${project_domain} == "${project_root_domain}" || ${project_domain} == "www.${project_root_domain}" ]]; then

    # Nginx config
    nginx_server_create "www.${project_root_domain}" "${project_type}" "root_domain" "${project_root_domain}" "${project_port}"

    # Cloudflare
    if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then
      ## Set records based on nginx root_domain configuration
      ## Nginx redirects: root_domain.com -> www.root_domain.com
      ## So Cloudflare must point: www -> server IP (A), root -> www (CNAME)

      # For www subdomain: ensure no conflicting CNAME exists, then set A record
      cloudflare_delete_record "${project_root_domain}" "www.${project_root_domain}" "CNAME" 2>/dev/null || true
      cloudflare_set_record "${project_root_domain}" "www.${project_root_domain}" "A" "false" "${SERVER_IP}"
      exitstatus=$?
      [[ ${exitstatus} -ne 0 ]] && cloudflare_exitstatus=${exitstatus}

      # For root domain: ensure no conflicting A record exists, then set CNAME
      cloudflare_delete_record "${project_root_domain}" "${project_root_domain}" "A" 2>/dev/null || true
      cloudflare_set_record "${project_root_domain}" "${project_root_domain}" "CNAME" "false" "www.${project_root_domain}"
      exitstatus=$?
      [[ ${exitstatus} -ne 0 ]] && cloudflare_exitstatus=${exitstatus}
    fi

    if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then
      # Wait for DNS propagation (independent of Cloudflare status)
      display --indent 6 --text "- Waiting for DNS propagation"
      log_event "info" "Waiting for DNS propagation..." "false"
      
      if ! dig +short "${project_domain}" @1.1.1.1 | grep -q "${SERVER_IP}"; then
        # Simple verification without full function
        sleep 5
      fi
      
      clear_previous_lines "1"
      display --indent 6 --text "- Waiting for DNS propagation" --result "DONE" --color GREEN

      # Install certificate (attempt regardless of Cloudflare status)
      # Use non-interactive mode (true) to avoid prompts during automated restoration
      if certbot_certificate_install_auto "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${project_root_domain},www.${project_root_domain}" "true"; then
        # Enable HTTP/2 only if not already enabled
        if ! grep -q "listen.*http2" "/etc/nginx/sites-available/${project_domain}"; then
          nginx_server_add_http2_support "${project_domain}"
        fi
        project_https_enable="true"
      else
        log_event "warning" "Certbot failed, proceeding with HTTP configuration" "false"
        display --indent 6 --text "- SSL Certificate" --result "WARNING" --color YELLOW
        project_https_enable="false"
      fi
    fi

  else # Working with single domain

    # Nginx config
    nginx_server_create "${project_domain}" "${project_type}" "single" "" "${project_port}"

    # Cloudflare
    if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then
      ## Set records
      cloudflare_set_record "${project_root_domain}" "${project_domain}" "A" "false" "${SERVER_IP}"
      cloudflare_exitstatus=$?
    fi

    if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then
      # Wait for DNS propagation (independent of Cloudflare status)
      display --indent 6 --text "- Waiting for DNS propagation"
      log_event "info" "Waiting for DNS propagation..." "false"
      
      if ! dig +short "${project_domain}" @1.1.1.1 | grep -q "${SERVER_IP}"; then
        # Simple verification without full function
        sleep 5
      fi
      
      clear_previous_lines "1"
      display --indent 6 --text "- Waiting for DNS propagation" --result "DONE" --color GREEN

      # Install certificate (attempt regardless of Cloudflare status)
      # Use non-interactive mode (true) to avoid prompts during automated restoration
      if certbot_certificate_install_auto "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${project_domain}" "true"; then
        # Enable HTTP/2 only if not already enabled
        if ! grep -q "listen.*http2" "/etc/nginx/sites-available/${project_domain}"; then
          nginx_server_add_http2_support "${project_domain}"
        fi
        project_https_enable="true"
      else
        log_event "warning" "Certbot failed, proceeding with HTTP configuration" "false"
        display --indent 6 --text "- SSL Certificate" --result "WARNING" --color YELLOW
        project_https_enable="false"
      fi
    fi

  fi

  echo "${project_https_enable}"

}

################################################################################
# Project post install tasks
#
# Arguments:
#  ${1} = ${project_domain}
#  ${2} = ${project_type}
#  ${3} = ${project_name}
#  ${4} = ${project_stage}
#  ${5} = ${project_db_pass} - Optional (if empty, will not change it)
#  ${6} = ${old_project_domain}
#  ${7} = ${new_project_domain}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_post_install_tasks() {

  local project_install_path="${1}"
  local project_type="${2}"
  local project_install_type="${3}"
  local project_name="${4}"
  local project_stage="${5}"
  local project_db_pass="${6}"
  local old_project_domain="${7}" # TODO: can change it for url? https://domain.com or http://domain.com
  local new_project_domain="${8}"
  local mode="${9:-new}"  # 'new' for new installations, 'restore' for standard restorations
  #local project_port="${10}"
  #local project_db_engine="${11}"

  local project_env
  local database_host="localhost"

  # TODO: update brolit project config file

  # Log
  log_subsection "Post Install Tasks"

  # Check if is a WP project
  if [[ ${project_type} == "wordpress" ]]; then

    if [[ ${project_install_type} == "docker"* ]]; then

      # Change database_host
      database_host="mysql"

      # Extract project_db_pass from .env
      project_db_pass="$(grep -oP '(MYSQL_PASSWORD=).+' "${project_install_path}/.env" | grep -oP '[^=]+$')"

    fi

    # For restore mode, only update database credentials if they don't match the backup
    # For new mode, always update them
    if [[ "${mode}" == "new" ]]; then
      # Change wp-config.php database parameters (NEW INSTALLATION)
      project_set_configured_database_host "${project_install_path}" "${project_type}" "${project_install_type}" "${database_host}"
      project_set_configured_database "${project_install_path}" "${project_type}" "${project_install_type}" "${project_name}_${project_stage}"
      project_set_configured_database_user "${project_install_path}" "${project_type}" "${project_install_type}" "${project_name}_user"
      project_set_configured_database_userpassw "${project_install_path}" "${project_type}" "${project_install_type}" "${project_db_pass}"
    else
      # RESTORE MODE: Only update DB_HOST if needed (mysql for Docker)
      log_event "debug" "Restore mode: preserving original database credentials from backup" "false"
      if [[ ${project_install_type} == "docker"* ]]; then
        project_set_configured_database_host "${project_install_path}" "${project_type}" "${project_install_type}" "${database_host}"
      fi
    fi

    # Change project_install_path
    #project_install_path="${project_install_path}/wordpress"
    project_install_path="$(project_get_configured_docker_data_dir "${project_install_path}")"

    # Change WordPress directory permissions (ALWAYS NEEDED)
    wp_change_permissions "${project_install_path}"

    # Search & Replace URLs if domain changed (ALWAYS NEEDED when domain changes)
    if [[ -n ${old_project_domain} && -n ${new_project_domain} ]]; then
      if [[ ${old_project_domain} != "${new_project_domain}" ]]; then
        # Change urls on database
        wpcli_search_and_replace "${project_install_path}" "${project_install_type}" "${old_project_domain}" "${new_project_domain}"

        # Update WP_HOME & WP_SITEURL only if domain changed
        wpcli_config_set "${project_install_path}" "${project_install_type}" "WP_HOME" "https://${new_project_domain}/"
        wpcli_config_set "${project_install_path}" "${project_install_type}" "WP_SITEURL" "https://${new_project_domain}/"
      fi
    fi

    # Operations that differ between new and restore modes
    if [[ "${mode}" == "new" ]]; then
      # NEW INSTALLATION: Shuffle salts for security
      wpcli_shuffle_salts "${project_install_path}" "${project_install_type}"

      # Update upload_path
      ## Context: https://core.trac.wordpress.org/ticket/41947
      wpcli_update_upload_path "${project_install_path}" "${project_install_type}" "wp-content/uploads"

      # Configure WordPress visibility based on stage
      if [[ ${project_stage} == "prod" ]]; then
        # Let search engines index the project
        wpcli_change_wp_seo_visibility "${project_install_path}" "${project_install_type}" "1"
        # Set debug mode to false
        wpcli_set_debug_mode "${project_install_path}" "${project_install_type}" "false"
      else
        # Block search engines indexation
        wpcli_change_wp_seo_visibility "${project_install_path}" "${project_install_type}" "0"
        # De-activate cache plugins if present
        wpcli_plugin_is_installed "${project_install_path}" "${project_install_type}" "wp-rocket" && wpcli_deactivate_plugin "${project_install_path}" "wp-rocket"
        wpcli_plugin_is_installed "${project_install_path}" "${project_install_type}" "redis-cache" && wpcli_plugin_deactivate "${project_install_path}" "redis-cache"
        wpcli_plugin_is_installed "${project_install_path}" "${project_install_type}" "w3-total-cache" && wpcli_plugin_deactivate "${project_install_path}" "w3-total-cache"
        wpcli_plugin_is_installed "${project_install_path}" "${project_install_type}" "wp-super-cache" && wpcli_plugin_deactivate "${project_install_path}" "wp-super-cache"
        # Set debug mode to true
        wpcli_set_debug_mode "${project_install_path}" "${project_install_type}" "true"
      fi
    else
      # RESTORE MODE: Keep original configuration, just update upload path
      log_event "debug" "Restore mode: preserving original WordPress configuration (salts, debug mode, SEO visibility)" "false"

      # Update upload_path (safe to run on restore)
      wpcli_update_upload_path "${project_install_path}" "${project_install_type}" "wp-content/uploads"
    fi

    # Flush cache (ALWAYS NEEDED)
    wpcli_cache_flush "${project_install_path}" "${project_install_type}"

    # If .user.ini found, rename it (Wordfence issue workaround - ALWAYS NEEDED)
    [[ -f "${project_install_path}/.user.ini" ]] && mv "${project_install_path}/.user.ini" "${project_install_path}/.user.ini.bak"

  else

    # NON-WORDPRESS PROJECTS
    project_env="${project_install_path}/.env"

    if [[ -f ${project_env} ]]; then

      if [[ "${mode}" == "new" ]]; then
        # NEW INSTALLATION: Update all .env database variables
        #project_set_config_var "${project_env}" "DB_CONNECTION" "${chosen_project}" "none"
        project_set_config_var "${project_env}" "DB_DATABASE" "${project_name}_${project_stage}" "none"
        project_set_config_var "${project_env}" "DB_USERNAME" "${project_name}_user" "none"
        project_set_config_var "${project_env}" "DB_PASSWORD" "${project_db_pass}" "none"
      else
        # RESTORE MODE: Preserve original .env values from backup
        log_event "debug" "Restore mode: preserving original .env database credentials from backup" "false"
      fi

    else

      log_event "info" ".env file not found on project directory" "false"

    fi

  fi

}
