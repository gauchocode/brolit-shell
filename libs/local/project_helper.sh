#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
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

  local i

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
# Find project .env file (checks .env, then .env.production)
#
# Arguments:
#   ${1} - ${project_path}
#
# Outputs:
#   Path to env file if found, empty string otherwise
################################################################################

function project_find_env_file() {

  local project_path="${1}"

  if [[ -f "${project_path}/.env" ]]; then
    echo "${project_path}/.env"
  elif [[ -f "${project_path}/.env.production" ]]; then
    echo "${project_path}/.env.production"
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
  local env_file
  env_file="$(project_find_env_file "${project_path}")"
  local port=""

  # Preferred strategy: ask Docker's own compose parser which host port was
  # actually published (resolves ${VAR} interpolation correctly, and is the
  # real ground truth for what nginx should proxy_pass to) instead of
  # guessing from .env variable naming. Only trusted when exactly one
  # service publishes a host port - with several published ports we still
  # can't tell which one is "the" web-facing service, so fall through to
  # the naming-based heuristics below (same conservative behavior as before).
  local compose_file=""
  [[ -f "${project_path}/docker-compose.yml" ]] && compose_file="${project_path}/docker-compose.yml"
  [[ -z "${compose_file}" && -f "${project_path}/docker-compose.yaml" ]] && compose_file="${project_path}/docker-compose.yaml"

  if [[ -n "${compose_file}" ]] && command -v jq >/dev/null 2>&1; then
    local published_ports
    published_ports="$(docker compose -f "${compose_file}" config --format json 2>/dev/null \
      | jq -r '[.services[].ports[]?.published] | unique | .[]' 2>/dev/null)"
    if [[ "$(echo "${published_ports}" | grep -c '.')" -eq 1 && "${published_ports}" =~ ^[0-9]+$ ]]; then
      log_event "debug" "Found port ${published_ports} via docker compose config (single published port)" "false"
      echo "${published_ports}"
      return 0
    fi
  fi

  # Without a .env file (for example a static site whose port is only published
  # in docker-compose.yml and the compose strategy found no single port) there
  # is nothing left to read.
  if [[ -z "${env_file}" ]]; then
    return 0
  fi

  # Try to extract port from environment variables in priority order
  # Priority: WP_PORT (WordPress), APP_PORT (generic app), PORT (standard), then others
  # Exclude admin/utility ports like PHPMYADMIN_PORT, SSH_HOST_PORT, etc.
  for var_name in "WP_PORT" "APP_PORT" "APP_HOST_PORT" "HOST_PORT" "PORT" "SERVER_PORT" "HTTP_PORT" "NODE_PORT" "WEBSERVER_PORT"; do
    port="$(grep -E "^${var_name}=" "${env_file}" | grep -v '^#' | head -n 1 | cut -d '=' -f 2 | tr -d ' "')"
    if [[ -n "${port}" ]]; then
      log_event "debug" "Found port ${port} from ${var_name} in ${env_file}" "false"
      break
    fi
  done

  # Last-resort fallback: any *_PORT variable not matching a known
  # non-web-facing service (database, cache, ssh, admin tools). Only used
  # if exactly one candidate remains, to avoid guessing wrong on ambiguity.
  if [[ -z "${port}" ]]; then
    local port_candidates
    port_candidates="$(grep -E '^[A-Z0-9_]*_PORT=' "${env_file}" 2>/dev/null | grep -v '^#' \
      | grep -viE '^(MYSQL|MARIADB|POSTGRES|PGSQL|REDIS|MONGO|DB|DATABASE|SSH|ADMIN|PHPMYADMIN|SMTP|FTP)_PORT=')"
    if [[ "$(echo "${port_candidates}" | grep -c '.')" -eq 1 ]]; then
      port="$(echo "${port_candidates}" | cut -d '=' -f 2 | tr -d ' "')"
      [[ "${port}" =~ ^[0-9]+$ ]] && log_event "debug" "Found port ${port} via last-resort *_PORT fallback in ${env_file}" "false"
    fi
  fi

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
# Get the project's database name (best-effort). Used to fill borgmatic's
# {database} constant -- an unresolved constant fails the *entire* config
# file to parse (not just the DB dump section). Callers must reject missing or
# unresolved values rather than guess a database name.
#
# Arguments:
#   ${1} = ${project_name}
#   ${2} = ${project_install_type}
#
# Outputs:
#   Database name, or empty string if not detected
################################################################################

function project_get_database_name() {

    local project_name="${1}"
    local project_install_type="${2}"

    local project_path="/${PROJECTS_PATH}/${project_name}"
    local db_name=""

    # Docker projects: MYSQL_DATABASE / POSTGRES_DB env var, from
    # docker-compose.yml first, then a sibling .env file
    if [[ "${project_install_type}" == "docker"* ]]; then

        local compose_file
        for compose_file in "${project_path}/docker-compose.yml" "${project_path}/docker-compose.yaml"; do
            [[ -f "${compose_file}" ]] || continue
            db_name="$(grep -Eo "(MYSQL_DATABASE|POSTGRES_DB)[[:space:]]*[:=][[:space:]]*[^[:space:]#\"']+" "${compose_file}" 2>/dev/null | head -1 | sed -E 's/^[^:=]+[:=][[:space:]]*//')"
            [[ -n "${db_name}" ]] && break
        done

        # A compose-level ${VAR} reference is not a database name. Resolve it
        # against the sibling .env instead of propagating the placeholder into
        # the generated borgmatic constants (which borgmatic then cannot
        # interpolate, failing the whole project with class "config"). Compose
        # also allows ${VAR:-default} / ${VAR-default}, so honour those too.
        local db_var="" db_default=""
        if [[ "${db_name}" =~ ^\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?$ ]]; then
            db_var="${BASH_REMATCH[1]}"
        elif [[ "${db_name}" =~ ^\$\{([A-Za-z_][A-Za-z0-9_]*):?-([^}]*)\}$ ]]; then
            db_var="${BASH_REMATCH[1]}"
            db_default="${BASH_REMATCH[2]}"
        fi

        if [[ -n "${db_var}" ]]; then
            db_name=""
            if [[ -f "${project_path}/.env" ]]; then
                # Compose applies the last assignment; strip CRLF from files
                # edited on Windows and tolerate an `export ` prefix.
                db_name="$(grep -E "^(export[[:space:]]+)?${db_var}=" "${project_path}/.env" 2>/dev/null | tail -1 | cut -d '=' -f2- | tr -d "\"'" | tr -d '\r')"
            fi
            [[ -n "${db_name}" ]] || db_name="${db_default}"
        fi

        if [[ -z "${db_name}" && -f "${project_path}/.env" ]]; then
            db_name="$(grep -E '^(export[[:space:]]+)?(MYSQL_DATABASE|POSTGRES_DB)=' "${project_path}/.env" 2>/dev/null | tail -1 | cut -d '=' -f2- | tr -d "\"'" | tr -d '\r')"
        fi

    fi

    # WordPress
    if [[ -z "${db_name}" && -f "${project_path}/wp-config.php" ]]; then
        # Read literal definitions only, without evaluating PHP or using the
        # interactive option reader (which also prints/logs the value).
        # Accept only one plain definition line. Any other DB_NAME mention
        # (including comments, duplicates and expressions) is ambiguous. This
        # deliberately conservative comment scan is not a general PHP parser.
        db_name="$(awk '
            /DB_NAME/ {
                mentions++
                if (in_block || /\/\*|\*\//) ambiguous=1
                candidate=$0
            }
            {
                rest=$0
                while (length(rest)) {
                    if (in_block) {
                        end=index(rest, "*/")
                        if (!end) break
                        in_block=0
                        rest=substr(rest, end+2)
                    } else {
                        start=index(rest, "/*")
                        if (!start) break
                        in_block=1
                        rest=substr(rest, start+2)
                    }
                }
            }
            END { if (mentions == 1 && !ambiguous && !in_block) print candidate }
        ' "${project_path}/wp-config.php" | sed -nE "s/^[[:space:]]*define[[:space:]]*\([[:space:]]*['\"]DB_NAME['\"][[:space:]]*,[[:space:]]*['\"]([^'\"]+)['\"][[:space:]]*\)[[:space:]]*;[[:space:]]*$/\1/p")"
        # Do not substitute another application configuration for an ambiguous
        # WordPress definition (for example a stale sibling .env database).
        echo "${db_name}"
        return 0
    fi

    # Laravel/PHP frameworks (.env DB_DATABASE)
    if [[ -z "${db_name}" && -f "${project_path}/.env" ]]; then
        db_name="$(grep -E '^DB_DATABASE=' "${project_path}/.env" 2>/dev/null | head -1 | cut -d '=' -f2- | tr -d "\"'")"
    fi

    echo "${db_name}"
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
# Replace the entire project[].database array in one shot
#
# project_update_brolit_config() always targets project[].database[] via
# json_write_field's blank-bracket jq semantics, which is only safe because
# there has only ever been exactly one database entry - a bare "[] = value"
# jq assignment updates EVERY matching element, not "the first"/"append".
# For Docker projects with more than one real database service (see
# docker_list_project_databases()), this writes all N entries atomically
# via a single jq call instead. project_update_brolit_config() and its
# existing single-entry callers are untouched.
#
# Arguments:
#  ${1} = ${project_config_file} - Path to the /etc/brolit/<domain>_conf.json file
#  ${2} = ${project_prymary_subdomain} - only used if the config file doesn't exist yet
#  ${@:3} = flat list of 6-tuples, repeated once per database:
#           service engine db_name db_host db_user db_pass
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function project_write_brolit_config_databases() {

  local project_config_file="${1}"
  local project_prymary_subdomain="${2}"
  shift 2

  local -a entries=()
  local entry_json
  local db_count=0

  if [[ ! -e ${project_config_file} ]]; then
    cp "${BROLIT_MAIN_DIR}/config/brolit/brolit_project.json" "${project_config_file}"
    json_write_field "${project_config_file}" "project[].primary_subdomain" "${project_prymary_subdomain}"
  fi

  while [[ $# -ge 6 ]]; do

    entry_json="$(jq -n \
      --arg service "${1}" \
      --arg engine "${2}" \
      --arg name "${3}" \
      --arg host "${4}" \
      --arg user "${5}" \
      --arg pass "${6}" \
      '{status: "enabled", engine: $engine, service: $service, config: [{name: $name, host: $host, user: $user, pass: $pass}]}')"

    entries+=("${entry_json}")
    db_count=$((db_count + 1))
    shift 6

  done

  if [[ ${db_count} -eq 0 ]]; then
    log_event "error" "project_write_brolit_config_databases: no database tuples given" "false"
    return 1
  fi

  local databases_json
  databases_json="$(printf '%s\n' "${entries[@]}" | jq -s '.')"

  if jq --argjson databases "${databases_json}" '.project[0].database = $databases' "${project_config_file}" >"${project_config_file}.tmp"; then
    mv "${project_config_file}.tmp" "${project_config_file}"
    display --indent 6 --text "- Updating project databases (${db_count} found)" --result DONE --color GREEN
    log_event "info" "Project config databases updated: ${project_config_file} (${db_count} entries)" "false"
    return 0
  else
    rm -f "${project_config_file}.tmp"
    log_event "error" "Failed writing multi-db project config: ${project_config_file}" "false"
    return 1
  fi

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
  project_nginx_conf="${WSERVER}/sites-available/${project_domain}"

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

  if [[ ! -f "${project_path}/.env" ]]; then

    # Log
    log_event "debug" "No .env file at ${project_path}, can't get WWW_DATA_DIR value" "false"

    return 1

  fi

  # Get WWW_DATA_DIR value from .env file
  project_dir="$(grep WWW_DATA_DIR "${project_path}/.env" | cut -d "=" -f 2)"

  # Check exitstatus
  exitstatus=$?
  if [[ ${exitstatus} -eq 0 && -n ${project_dir} ]]; then

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

  # Check if a webserver is available (local nginx or Proxmox mode with OpenResty)
  if [[ ! $(command -v nginx) ]]; then
    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
      if ! openresty_is_installed 2>/dev/null; then
        log_event "error" "OpenResty VM not reachable" "false"
        display --indent 6 --text "- Creating ${project_type} project" --result "FAIL" --color RED
        display --indent 8 --text "OpenResty VM not reachable" --tcolor RED
        return 1
      fi
    else
      # Log
      log_event "error" "Nginx is not installed" "false"
      display --indent 6 --text "- Creating ${project_type} project" --result "FAIL" --color RED
      display --indent 8 --text "Nginx is not installed" --tcolor RED
      return 1
    fi
  fi

  # If Proxmox mode, ensure OpenResty can be reached
  if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
    if ! openresty_is_installed 2>/dev/null; then
      log_event "error" "OpenResty VM not reachable" "false"
      display --indent 6 --text "- Creating ${project_type} project" --result "FAIL" --color RED
      display --indent 8 --text "OpenResty VM not reachable" --tcolor RED
      return 1
    fi
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
  project_update_brolit_config "${project_path}" "${project_name}" "${project_stage}" "${project_type} " "enabled" "mysql" "${database_name}" "localhost" "${database_user}" "${database_user_passw}" "${project_domain}" "${project_secondary_subdomain}" "${WSERVER}/sites-available/${project_domain}" "" "${cert_path}"

  # Log
  log_event "info" "New ${project_type} project installation for '${project_domain}' finished ok." "false"
  display --indent 6 --text "- ${project_type} project installation" --result "DONE" --color GREEN
  display --indent 8 --text "for domain ${project_domain}"

  # Send notification
  send_notification "${SERVER_NAME}" "New ${project_type} project installation for '${project_domain}' finished ok!" "success"

}

################################################################################
# Detect recognizable Compose files or COMPOSE_FILE declarations recursively,
# including hidden directories. This is not proof of complete exclusion.
#
# Arguments:
#   ${1} = project directory
#
# Outputs:
#   0 if a hint is found, 1 if none found, 2 on an inspection error.
################################################################################
function project_has_unsupported_compose_file() {
  local dir_path="${1}"
  local found env_status
  [[ -d "${dir_path}" && ! -L "${dir_path}" ]] || return 2
  # Do not follow directory symlinks out of the project. Match symlinked
  # Compose files as hints, including dangling links, without opening them.
  found="$(find -P "${dir_path}" \( -name 'docker-compose.yml' -o -name 'docker-compose.yaml' -o -name 'compose.yml' -o -name 'compose.yaml' -o -name 'docker-compose.*.yml' -o -name 'docker-compose.*.yaml' -o -name 'compose.*.yml' -o -name 'compose.*.yaml' -o -name 'docker-compose-*.yml' -o -name 'docker-compose-*.yaml' -o -name 'compose-*.yml' -o -name 'compose-*.yaml' \) ! -type d -print -quit 2>/dev/null)" || return 2
  [[ -n "${found}" ]] && return 0

  # Compose can select an arbitrary filename using COMPOSE_FILE. Inspect .env
  # files without printing their contents; inaccessible files are uncertain.
  project_dotenv_has_compose_file "${dir_path}"
  env_status=$?
  [[ ${env_status} -eq 2 ]] && return 2
  [[ ${env_status} -eq 0 ]] && return 0
  return 1
}

################################################################################
# Sanitize a Compose project name the way Docker Compose does: lowercase and
# only [a-z0-9_-] kept. Returns the sanitized name on stdout.
#
# Arguments:
#   ${1} = candidate name
#
# Outputs:
#   0 if a non empty sanitized name was produced, 1 otherwise.
################################################################################
function project_compose_sanitize_name() {
  local candidate="${1}" sanitized
  sanitized="$(printf '%s' "${candidate}" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')"
  [[ -n "${sanitized}" ]] || return 1
  printf '%s\n' "${sanitized}"
}

################################################################################
# List Compose project names that own Docker volumes: by the Compose label and
# by the Compose name prefix (<project>_ and <project>/). Detecting a volume
# that belongs to the project is enough to refuse the deletion.
#
# Arguments:
#   ${1}... = candidate Compose project names
#
# Outputs:
#   Volume names on stdout; 0 if ok, 2 on inspection error.
################################################################################
function project_compose_volume_names() {
  local name volume_name all_volumes
  [[ $# -ge 1 ]] || return 2
  command -v docker >/dev/null 2>&1 || return 2

  all_volumes="$(docker volume ls --format '{{.Name}}' 2>/dev/null)" || return 2

  for name in "$@"; do
    [[ -n "${name}" ]] || continue
    # Volumes labelled by Docker Compose for this project.
    docker volume ls --filter "label=com.docker.compose.project=${name}" --format '{{.Name}}' 2>/dev/null || return 2
    # Volumes named after the project namespace.
    while IFS= read -r volume_name; do
      [[ -n "${volume_name}" ]] || continue
      if [[ "${volume_name}" == "${name}_"* || "${volume_name}" == "${name}/"* ]]; then
        printf '%s\n' "${volume_name}"
      fi
    done <<< "${all_volumes}"
  done

  return 0
}

################################################################################
# Detect an explicit COMPOSE_FILE declaration in the project's .env files.
# File contents are never printed; an inaccessible .env is uncertain.
#
# Arguments:
#   ${1} = project directory
#
# Outputs:
#   0 if declared, 1 if not, 2 when the scan cannot be trusted.
################################################################################
function project_dotenv_has_compose_file() {
  local dir_path="${1}" env_results
  [[ -d "${dir_path}" ]] || return 2

  env_results="$(find -P "${dir_path}" -name .env ! -type d -exec sh -c '
    for file do
      if [ ! -f "$file" ]; then printf "ERROR\n"; continue; fi
      LC_ALL=C grep -qE "^[[:space:]]*(export[[:space:]]+)?COMPOSE_FILE[[:space:]]*=" -- "$file" 2>/dev/null
      status=$?
      if [ "$status" -eq 0 ]; then printf "MATCH\n"; elif [ "$status" -ne 1 ]; then printf "ERROR\n"; fi
    done
  ' sh {} + 2>/dev/null)" || return 2

  [[ "${env_results}" == *ERROR* ]] && return 2
  [[ "${env_results}" == *MATCH* ]] && return 0
  return 1
}

################################################################################
# Read COMPOSE_PROJECT_NAME from the project's top level .env files.
#
# brolit writes "${project_name}_stack" there when it installs or restores a
# Docker project, so the Compose volume namespace is not the directory name and
# must be searched as well.
#
# Arguments:
#   ${1} = project directory
#
# Outputs:
#   Sanitized names on stdout; 0 if ok, 2 when an existing file is unreadable.
################################################################################
function project_dotenv_compose_project_names() {
  local dir_path="${1}"
  local env_file value
  [[ -d "${dir_path}" ]] || return 2

  for env_file in "${dir_path}/.env" "${dir_path}/.env.docker"; do
    [[ -e "${env_file}" ]] || continue
    [[ -f "${env_file}" && -r "${env_file}" ]] || return 2

    value="$(LC_ALL=C grep -m1 -E '^[[:space:]]*(export[[:space:]]+)?COMPOSE_PROJECT_NAME[[:space:]]*=' -- "${env_file}" 2>/dev/null)"
    [[ -n "${value}" ]] || continue

    value="${value#*=}"
    value="$(printf '%s' "${value}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/^["'\'']//; s/["'\'']$//')"
    value="$(project_compose_sanitize_name "${value}")" || continue
    printf '%s\n' "${value}"
  done

  return 0
}

################################################################################
# Prove whether a Compose project can be deleted without losing persistent
# mount data that the pre-delete files backup and database dump do not cover.
#
# Covered: bind mounts whose source resolves inside the project directory (the
# files backup archives that directory) and tmpfs mounts (ephemeral).
# Uncovered: Docker volumes, bind mounts resolving outside the project, an
# unknown mount type, an unresolvable bind, an unresolvable symlink or an
# ambiguous Compose context.
#
# Arguments:
#   ${1} = project directory
#
# Outputs:
#   0 if no uncovered persistent mount exists (nothing to lose outside the
#   project directory), 1 with one item per mount, 2 when coverage cannot be
#   established. The optional second argument is "text" (default, historical
#   UNCOVERED lines) or "json" (one compact JSON object per line).
################################################################################
function project_compose_mount_coverage() {
  local dir_path="${1}"
  local output_format="${2:-text}"
  local project_dir ids id record records='' result uncovered projects
  local name candidate names=() declared=() env_names=() unique_names
  local bind_source bind_destination resolved env_name_list

  [[ -n "${dir_path}" && -d "${dir_path}" ]] || return 2
  [[ "${output_format}" == "text" || "${output_format}" == "json" ]] || return 2
  command -v docker >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 2

  project_dir="$(realpath -e -- "${dir_path}" 2>/dev/null)" || return 2
  [[ -n "${project_dir}" && "${project_dir}" != "/" ]] || return 2

  # An explicit COMPOSE_FILE means the Compose context is not the one we can
  # reason about: treat it as unknown.
  project_dotenv_has_compose_file "${project_dir}"
  case $? in
    0) return 2 ;;
    1) : ;;
    *) return 2 ;;
  esac

  # Names declared in .env files widen the volume search below. They are not
  # used for the related-container check: the Compose label is authoritative
  # there.
  if ! env_name_list="$(project_dotenv_compose_project_names "${project_dir}")"; then
    return 2
  fi
  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    env_names+=("${name}")
  done <<< "${env_name_list}"

  ids="$(docker ps --all --quiet --no-trunc 2>/dev/null)" || return 2

  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    [[ "${id}" =~ ^[a-f0-9]{12,64}$ ]] || return 2
    record="$(docker inspect --format '{"id":{{json .Id}},"project":{{json (index .Config.Labels "com.docker.compose.project")}},"working_dir":{{json (index .Config.Labels "com.docker.compose.project.working_dir")}},"mounts":{{json .Mounts}}}' "${id}" 2>/dev/null)" || return 2
    [[ -n "${record}" ]] || return 2
    records+="${record}"$'\n'
  done <<< "${ids}"

  # jq distinguishes "no label" (null) from "wrong label" without relying on
  # and/or short-circuiting, which is not guaranteed across jq versions.
  result="$(printf '%s' "${records}" | jq -s -e --arg dir "${project_dir}" '
    def within($root): . == $root or startswith($root + "/");
    if any(.[];
         (type != "object")
         or (.id | type != "string" or length == 0)
         or (.mounts | type != "array")
         or any(.mounts[];
              ((.Type | type) != "string")
              or (.Destination | type != "string" or length == 0)
              or (.Source | type != "string")))
    then error("incomplete runtime inspection") else . end |
    [ .[] | select(
        (if (.working_dir | type) == "string" then (.working_dir | within($dir)) else false end)
        or any(.mounts[];
             (.Type == "bind") and ((.Source | type) == "string") and (.Source | within($dir)))
      ) ] as $related |
    if any($related[];
         if (.project | type) == "string" then ((.project | length) == 0) else true end)
    then error("ambiguous compose context") else . end |
    {
      projects: ([ $related[].project ] | unique),
      covered_binds: [
        $related[] | .mounts[] |
        select(.Type == "bind" and (.Source | within($dir))) |
        {source: .Source, destination: .Destination}
      ],
      uncovered: [
        $related[] | .mounts[] |
        if .Type == "tmpfs" then empty
        elif .Type == "volume" then {kind:"volume",source:(.Name // ""),destination:.Destination}
        elif .Type == "bind" then
          (if (.Source | within($dir)) then empty
           else {kind:"bind",source:.Source,destination:.Destination} end)
        else {kind:.Type,source:.Source,destination:.Destination} end
      ]
    }' 2>/dev/null)" || return 2

  projects="$(printf '%s' "${result}" | jq -r '.projects[]?' 2>/dev/null)" || return 2
  uncovered="$(printf '%s' "${result}" | jq -c '.uncovered[]?' 2>/dev/null)" || return 2

  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    candidate="$(project_compose_sanitize_name "${name}")" || return 2
    names+=("${candidate}")
  done <<< "${projects}"

  # A bind mount is "inside" only if the path really resolves inside the
  # project directory: a symlink pointing out of it leaves data behind that the
  # files backup does not contain. An unresolvable path is not evidence.
  while IFS=$'\t' read -r bind_source bind_destination; do
    [[ -n "${bind_source}" ]] || continue
    # Nothing exists at the source: there is no data to lose.
    if [[ ! -e "${bind_source}" && ! -L "${bind_source}" ]]; then
      continue
    fi
    if ! resolved="$(realpath -e -- "${bind_source}" 2>/dev/null)"; then
      uncovered+="$(jq -c -n --arg source "${bind_source}" --arg destination "${bind_destination}" '{kind:"bind-unresolved",source:$source,destination:$destination}')"
      uncovered+=$'\n'
      continue
    fi
    case "${resolved}" in
      "${project_dir}"|"${project_dir}"/*) : ;;
      *)
        uncovered+="$(jq -c -n --arg source "${resolved}" --arg destination "${bind_destination}" '{kind:"bind",source:$source,destination:$destination}')"
        uncovered+=$'\n'
        ;;
    esac
  done < <(printf '%s' "${result}" | jq -r '.covered_binds[]? | [.source, .destination] | @tsv' 2>/dev/null)

  # With no related container the Compose name comes from the top level "name:"
  # of the Compose file when present, otherwise from the directory name. A
  # declared name must be unambiguous across the project's Compose files.
  if [[ ${#names[@]} -eq 0 ]]; then
    while IFS= read -r name; do
      [[ -n "${name}" ]] || continue
      # An interpolated value ("${PROJECT}") cannot be resolved here.
      [[ "${name}" == *'$'* ]] && return 2
      candidate="$(project_compose_sanitize_name "${name}")" || return 2
      declared+=("${candidate}")
    done < <(find -P "${project_dir}" -maxdepth 1 -type f \
      \( -name 'docker-compose.yml' -o -name 'docker-compose.yaml' -o -name 'compose.yml' -o -name 'compose.yaml' \) \
      -exec grep -m1 -hE '^name:[[:space:]]*' {} + 2>/dev/null \
      | sed -E 's/[[:space:]]+#.*$//; s/^name:[[:space:]]*//; s/[[:space:]]+$//; s/^["'\'']//; s/["'\'']$//')

    if [[ ${#declared[@]} -gt 0 ]]; then
      [[ "$(printf '%s\n' "${declared[@]}" | sort -u | wc -l)" -eq 1 ]] || return 2
      names+=("${declared[0]}")
    else
      candidate="$(project_compose_sanitize_name "$(basename -- "${project_dir}")")" || return 2
      names+=("${candidate}")
    fi
  fi

  if [[ ${#names[@]} -gt 1 ]]; then
    # Several Compose projects in the same namespace would make the volume
    # ownership ambiguous.
    unique_names="$(printf '%s\n' "${names[@]}" | sort -u | wc -l)"
    [[ ${unique_names} -eq 1 ]] || return 2
  fi

  # Every candidate namespace is searched. A volume found under any of them
  # blocks, so extra candidates can only make the verdict stricter.
  local existing_volumes
  for env_name in "${env_names[@]}"; do
    [[ " ${names[*]} " == *" ${env_name} "* ]] || names+=("${env_name}")
  done

  existing_volumes="$(project_compose_volume_names "${names[@]}")" || return 2

  if [[ -n "${existing_volumes}" ]]; then
    while IFS= read -r name; do
      [[ -n "${name}" ]] || continue
      uncovered+="$(jq -c -n --arg source "${name}" '{kind:"volume-namespace",source:$source,destination:"docker-volume"}')"
      uncovered+=$'\n'
    done <<< "${existing_volumes}"
  fi

  uncovered="$(printf '%s\n' "${uncovered}" | sed '/^$/d' | jq -sc 'unique_by(.kind,.source,.destination) | .[]' 2>/dev/null)" || return 2

  if [[ -n "${uncovered}" ]]; then
    if [[ "${output_format}" == "json" ]]; then
      printf '%s\n' "${uncovered}"
    else
      printf '%s\n' "${uncovered}" | jq -r '"UNCOVERED:\(.kind):\(.source):\(.destination)"'
    fi
    return 1
  fi

  return 0
}

################################################################################
# Show why a Compose deletion is blocked, distinguishing uncovered items from a
# coverage that could not be established. Nothing sensitive beyond mount paths
# and volume names is printed.
#
# Arguments:
#   ${1} = gate exit code (1 = uncovered items, 2 = cannot verify)
#   ${2} = newline separated "UNCOVERED:<kind>:<source>:<destination>" lines
#
# Outputs:
#   0 always.
################################################################################
function project_display_deletion_block() {
  local block_rc="${1:-1}" block_output="${2:-}" item

  if [[ "${block_rc}" -eq 2 ]]; then
    log_event "error" "Docker project deletion blocked: persistent mount coverage could not be verified (docker or jq unavailable, daemon error or ambiguous Compose context)." "false"
    display --indent 8 --text "- Coverage could not be verified (docker, jq, daemon error or ambiguous Compose context)" --tcolor YELLOW
    return 0
  fi

  [[ -n "${block_output}" ]] || return 0

  while IFS= read -r item; do
    [[ -n "${item}" ]] || continue
    if [[ "${item}" == \{* ]]; then
      item="$(printf '%s' "${item}" | jq -r '"UNCOVERED:\(.kind):\(.source):\(.destination)"' 2>/dev/null)" || continue
    fi
    log_event "error" "Uncovered persistent mount: ${item}" "false"
    display --indent 8 --text "- ${item}" --tcolor YELLOW
  done <<< "${block_output}"

  return 0
}

################################################################################
# Check the deletion gate; uncertainty is treated as unsafe.
#
# Arguments:
#   ${1} = project directory, ${2} = installation type
#
# Outputs:
#   0 if the deletion can proceed, 1 with uncovered mount lines on stdout when
#   persistent mount data is not covered, 2 on inspection failure (blocked).
################################################################################
function project_compose_deletion_safe() {
  local dir_path="${1}" install_type="${2}" output_format="${3:-text}" status

  # Docker projects: a files backup and a database dump do not cover Compose
  # volumes or bind mounts outside the project, so the deletion is allowed only
  # when no such mount exists.
  if [[ "${install_type}" == docker* ]]; then
    project_compose_mount_coverage "${dir_path}" "${output_format}"
    return $?
  fi

  if project_has_unsupported_compose_file "${dir_path}"; then
    return 1
  else
    status=$?
  fi
  # 2 means the scan itself failed: not the same as "a compose file was found".
  [[ ${status} -eq 1 ]] && return 0
  return 2
}

################################################################################
# Inspect runtime mounts associated with a project directory. This is an
# informational inventory, not proof of coverage or permission to delete.
# Output contains paths and volume names and must be treated as sensitive.
#
# Arguments:
#   ${1} = existing project directory
#
# Outputs:
#   JSON inventory on success; nonzero if runtime inspection is incomplete.
################################################################################
function project_compose_runtime_inventory() {
  local project_dir ids id record records='' result
  project_dir="$(realpath -e -- "${1}")" || return 1
  [[ -d "${project_dir}" ]] || return 1
  command -v docker >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 1
  ids="$(docker ps --all --quiet --no-trunc 2>/dev/null)" || return 1
  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    [[ "${id}" =~ ^[a-f0-9]{12,64}$ ]] || return 1
    # Explicitly select fields: never fetch environment, command or other
    # container configuration that may contain credentials.
    record="$(docker inspect --format '{"id":{{json .Id}},"project":{{json (index .Config.Labels "com.docker.compose.project")}},"working_dir":{{json (index .Config.Labels "com.docker.compose.project.working_dir")}},"config_files":{{json (index .Config.Labels "com.docker.compose.project.config_files")}},"mounts":{{json .Mounts}}}' "${id}" 2>/dev/null)" || return 1
    [[ -n "${record}" ]] || return 1
    records+="${record}"$'\n'
  done <<< "${ids}"
  result="$(printf '%s' "${records}" | jq -s -e --arg dir "${project_dir}" '
    def within($root): . == $root or startswith($root + "/");
    def related: (.working_dir | type == "string" and within($dir)) or
      any(.mounts[]; .Type == "bind" and (.Source | type == "string" and within($dir)));
    if any(.[]; (type != "object") or (.id | type != "string" or length == 0) or
       (.mounts | type != "array") or any(.mounts[]; (.Type != "bind" and .Type != "volume" and .Type != "tmpfs") or
         (.Destination | type != "string" or length == 0) or
         (if .Type == "bind" then (.Source | (type != "string") or ((startswith("/")) | not))
          elif .Type == "volume" then (.Name | type != "string" or length == 0) else false end)))
    then error("incomplete runtime inspection") else . end |
    . as $all | [ .[] | select(related) ] as $matched |
    if any($matched[]; (.project | type != "string" or length == 0) or
      (.working_dir | (type != "string") or ((startswith("/")) | not)) or
      (.config_files | type != "string" or length == 0))
    then error("ambiguous compose context") else
      {coverage: "unverified", exclusion: "not_proven", containers: [$matched[] | . as $container |
        {id, project, working_dir, config_files, mounts: [.mounts[] | . as $mount |
          {type: .Type, source: (if .Type == "volume" then .Name else .Source end), destination: .Destination,
           classification: (if .Type == "bind" then "bind" elif .Type == "tmpfs" then "tmpfs" elif (.Name | test("^[a-f0-9]{64}$")) then "anonymous_candidate" else "named_or_external" end),
           shared: (if .Type == "volume" then any($all[]; .id != $container.id and any(.mounts[]; .Type == "volume" and .Name == $mount.Name)) else null end),
           external: "unknown"}]}]} end' 2>/dev/null)" || return 1
  printf '%s\n' "${result}"
}

################################################################################
# Reconcile an explicit Compose context against stopped runtime containers.
# Detection only; output is sensitive and does not authorize deletion.
#
# Arguments:
#   ${1} = Compose project name, ${2} = project directory,
#   ${3}... = ordered absolute Compose configuration files
#
# Outputs:
#   JSON on success; nonzero if reconciliation cannot be established.
################################################################################
function project_compose_reconcile() {
  [[ $# -ge 3 && -n "${BROLIT_MAIN_DIR:-}" ]] || return 1
  python3 "${BROLIT_MAIN_DIR}/tools/compose-reconcile.py" "$@"
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
  local project_type
  local project_install_type
  local deletion_block_output
  local deletion_gate_rc

  backup_type="site"

  # Log
  log_subsection "Delete Files"

  # Trying to know project type and project install type
  project_type=$(project_get_type "${PROJECTS_PATH}/${project_domain}")
  project_install_type=$(project_get_install_type "${PROJECTS_PATH}/${project_domain}")

  #clear_previous_lines "1"

  if [[ -n ${project_type} && -n ${project_install_type} ]]; then

    # Docker deletion is blocked until persistent mount coverage is verified.
    deletion_block_output="$(project_compose_deletion_safe "${PROJECTS_PATH}/${project_domain}" "${project_install_type}")"
    deletion_gate_rc=$?
    if [[ ${deletion_gate_rc} -ne 0 ]]; then

      # A file backup and database dump do not establish coverage of Compose
      # volumes or external bind mounts. Even direct callers of this
      # destructive helper must fail closed.
      log_event "error" "Docker project deletion blocked: persistent mount backup coverage is not verified." "false"
      display --indent 6 --text "- Docker persistent mount backup coverage is not verified" --result "FAIL" --color RED
      project_display_deletion_block "${deletion_gate_rc}" "${deletion_block_output}"
      return 1

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

      # Make a copy of nginx configuration file, if it was ever configured as a site
      [[ -f "${WSERVER}/sites-available/${project_domain}" ]] && copy_files "${WSERVER}/sites-available/${project_domain}" "${BROLIT_TMP_DIR}"

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

################################################################################
# Archive every uncovered persistent mount before a deletion, verifying each
# uploaded archive by downloading it again and comparing its SHA-256.
#
# The gate supplies one JSON object per mount, so colons/newlines in paths are
# data, not delimiters. The stack is stopped before archiving to keep the mount
# contents stable. A failure before completion restarts it and cleans local files.
#
# Arguments:
#   ${1} = project domain
#   ${2} = newline-delimited gate JSON records
#
# Outputs:
#   Receipt path on stdout; 0 on success, 1 on any failure. The receipt is JSONL
#   and binds mount identity, archive path and checksum for finalization.
################################################################################
function project_compose_archive_deletion_mounts() (
  local project_domain="${1}" gate_output="${2}"
  local item kind source destination normalized_kind identity mount_id
  local name safe_name mountpoint archive_name archive_path archive_size archive_source
  local remote_directory remote_path verify_dir local_hash downloaded_hash
  local work_dir receipt compose_file
  local quiesced="false" keep_work="false"
  local -A seen=()

  [[ -n "${project_domain}" && -n "${gate_output}" ]] || return 1
  [[ -n "${BROLIT_TMP_DIR:-}" && -n "${NOW:-}" && -n "${SERVER_NAME:-}" ]] || return 1
  command -v docker >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 1

  compose_file="${PROJECTS_PATH}/${project_domain}/docker-compose.yml"
  [[ -f "${compose_file}" ]] || compose_file="${PROJECTS_PATH}/${project_domain}/docker-compose.yaml"
  [[ -f "${compose_file}" ]] || return 1
  cd "${PROJECTS_PATH}/${project_domain}" || return 1

  work_dir="${BROLIT_TMP_DIR}/${NOW}/mounts-${project_domain}"
  mkdir -p "${work_dir}" || return 1
  receipt="$(mktemp "${work_dir}/receipt.XXXXXX")" || return 1
  chmod 600 "${receipt}" || return 1
  remote_directory="${SERVER_NAME}/projects-online/site-mounts/${project_domain}"

  trap 'if [[ "${keep_work}" != "true" ]]; then rm -rf -- "${work_dir}"; fi; if [[ "${quiesced}" == "true" && "${keep_work}" != "true" ]]; then docker compose -f "${compose_file}" start >/dev/null 2>&1 || printf "WARNING: could not restart %s\n" "${project_domain}" >&2; fi' EXIT

  # Quiesce before taking the mount snapshot. Mark the attempt first: Compose
  # may have stopped some containers even when a later one fails to stop.
  quiesced="true"
  docker compose -f "${compose_file}" stop >/dev/null 2>&1 || return 1

  while IFS= read -r item; do
    [[ -n "${item}" ]] || continue
    printf '%s' "${item}" | jq -e '
      type == "object" and (keys == ["destination","kind","source"]) and
      (.kind | type == "string" and length > 0) and
      (.source | type == "string" and length > 0) and
      (.destination | type == "string" and length > 0)' >/dev/null 2>&1 || return 1

    kind="$(printf '%s' "${item}" | jq -r '.kind')"
    source="$(printf '%s' "${item}" | jq -r '.source')"
    destination="$(printf '%s' "${item}" | jq -r '.destination')"
    normalized_kind="${kind}"
    [[ "${kind}" == "volume-namespace" ]] && normalized_kind="volume"

    # One identity is archived once, even if the gate saw it attached to several
    # containers or reported it both by mount and by Compose namespace.
    identity="${normalized_kind}:${source}"
    [[ -n "${seen[${identity}]:-}" ]] && continue
    seen[${identity}]=1

    # A mounted socket is an IPC endpoint, not persistent file data.
    if [[ "${normalized_kind}" == "bind" && -S "${source}" ]]; then
      continue
    fi
    if [[ "${normalized_kind}" == "bind" && ! -e "${source}" && ! -L "${source}" ]]; then
      continue
    fi

    mountpoint=""
    name=""
    archive_source="${source}"
    case "${normalized_kind}" in
      volume)
        name="${source}"
        [[ -n "${name}" && "${name}" != "null" ]] || return 1
        mountpoint="$(docker volume inspect --format '{{.Mountpoint}}' "${name}" 2>/dev/null)" || return 1
        [[ -n "${mountpoint}" && "${mountpoint}" == /* && "${mountpoint}" != "/" ]] || return 1
        [[ -d "${mountpoint}" ]] || return 1
        archive_source="${mountpoint}"
        ;;
      bind)
        ;;
      *)
        # Unknown or unresolved evidence cannot be archived safely.
        return 1
        ;;
    esac

    safe_name="$(project_compose_sanitize_name "${name:-$(basename -- "${source}")}")" || return 1
    # Distinct mounts may share a basename; identity is part of the archive name.
    mount_id="$(printf '%s' "${identity}" | sha256sum | cut -c1-12)"
    safe_name="${safe_name}-${mount_id}"
    archive_name="$(backup_get_filename "${project_domain}_mount-${safe_name}" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")" || return 1
    archive_path="${work_dir}/${archive_name}"
    # Unlike nightly backups, a deletion archive cannot accept tar's
    # "file changed as we read it" warning as success.
    archive_size="$(BROLIT_STRICT_TAR=1 compress "/" "${archive_source#/}" "${archive_path}" "")" || return 1
    [[ -s "${archive_path}" ]] || return 1

    remote_path="${remote_directory}/${archive_name}"
    storage_upload_backup "${archive_path}" "${remote_directory}" "${archive_size}" >/dev/null || return 1

    verify_dir="${work_dir}/verify-${mount_id}"
    mkdir -p "${verify_dir}" || return 1
    storage_download_backup "${remote_path}" "${verify_dir}" "true" >/dev/null || return 1
    [[ -s "${verify_dir}/${archive_name}" ]] || return 1
    local_hash="$(sha256sum "${archive_path}" | awk '{print $1}')"
    downloaded_hash="$(sha256sum "${verify_dir}/${archive_name}" | awk '{print $1}')"
    [[ "${local_hash}" == "${downloaded_hash}" ]] || return 1

    jq -n -c \
      --arg kind "${normalized_kind}" \
      --arg source "${source}" \
      --arg mountpoint "${mountpoint}" \
      --arg archive "${archive_name}" \
      --arg remote "${remote_path}" \
      --arg sha256 "${local_hash}" \
      '{kind:$kind,source:$source,mountpoint:$mountpoint,archive:$archive,remote:$remote,sha256:$sha256}' \
      >> "${receipt}" || return 1
    rm -rf -- "${verify_dir}"
  done <<< "${gate_output}"

  keep_work="true"
  printf '%s\n' "${receipt}"
  return 0
)

################################################################################
# Abort a deletion after the mount snapshot was taken but before finalization.
# Restarts the stopped project and removes only local temporary archives.
################################################################################
function project_compose_abort_archived_deletion_mounts() {
  local project_domain="${1}" receipt="${2}" compose_file
  [[ -n "${receipt}" ]] || return 0
  compose_file="${PROJECTS_PATH}/${project_domain}/docker-compose.yml"
  [[ -f "${compose_file}" ]] || compose_file="${PROJECTS_PATH}/${project_domain}/docker-compose.yaml"
  if [[ -f "${compose_file}" ]]; then
    (cd "${PROJECTS_PATH}/${project_domain}" && docker compose -f "${compose_file}" start) >/dev/null 2>&1 || printf "WARNING: could not restart %s\n" "${project_domain}" >&2
  fi
  if [[ -n "${receipt}" ]]; then
    rm -rf -- "${BROLIT_TMP_DIR}/${NOW}/mounts-${project_domain}"
  fi
  return 0
}

################################################################################
# After the normal project backup succeeds, verify the mount receipt again,
# stop the Compose project and remove only the volumes whose archives matched.
# External bind contents are deliberately left in place.
#
# Arguments:
#   ${1} = project domain
#   ${2} = receipt path produced by project_compose_archive_deletion_mounts
#
# Outputs:
#   0 on success, 1 on any verification or removal failure.
################################################################################
function project_compose_finalize_archived_deletion_mounts() (
  local project_domain="${1}" receipt="${2}"
  local item kind source mountpoint archive_name remote_path expected_hash
  local identity mount_id safe_name expected_archive expected_remote
  local verify_dir actual_hash compose_file work_dir
  local down_done="false" success="false"

  # This function is a subshell: exit aborts it and runs the rollback trap,
  # without terminating the caller.
  function finalize_fail() {
    log_event "error" "Mount finalization for ${project_domain} failed: ${1}" "false"
    display --indent 8 --text "- Mount finalization: ${1}" --tcolor RED
    exit 1
  }

  work_dir="${BROLIT_TMP_DIR}/${NOW}/mounts-${project_domain}"
  compose_file="${PROJECTS_PATH}/${project_domain}/docker-compose.yml"
  [[ -f "${compose_file}" ]] || compose_file="${PROJECTS_PATH}/${project_domain}/docker-compose.yaml"

  # The rollback trap must never inherit the caller's cwd. Enter the project
  # before arming it; a cd failure uses the same guarded abort path.
  if ! cd "${PROJECTS_PATH}/${project_domain}"; then
    project_compose_abort_archived_deletion_mounts "${project_domain}" "${receipt}"
    return 1
  fi

  # Cover every return after archiving, including invalid receipt/tool/compose
  # checks, not only failures later in verification.
  trap 'if [[ "${success}" != "true" && "${down_done}" != "true" ]]; then docker compose -f "${compose_file}" start >/dev/null 2>&1 || printf "WARNING: could not restart %s\n" "${project_domain}" >&2; fi; if [[ "${success}" != "true" ]]; then rm -rf -- "${work_dir}"; fi' EXIT

  [[ -n "${project_domain}" && -n "${receipt}" && -f "${receipt}" && ! -L "${receipt}" ]] || finalize_fail "receipt is missing or unsafe"
  command -v docker >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || finalize_fail "docker or jq is unavailable"
  [[ -f "${compose_file}" ]] || finalize_fail "Compose file is missing"

  # Validate the complete receipt and every remote archive before `down`.
  while IFS= read -r item; do
    [[ -n "${item}" ]] || continue
    printf '%s' "${item}" | jq -e '
      type == "object" and (keys == ["archive","kind","mountpoint","remote","sha256","source"]) and
      (.kind == "volume" or .kind == "bind") and
      (.source | type == "string" and length > 0) and
      (.mountpoint | type == "string") and
      (.archive | type == "string" and length > 0 and (contains("/") | not)) and
      (.remote | type == "string" and length > 0) and
      (.sha256 | type == "string" and test("^[a-f0-9]{64}$"))' >/dev/null 2>&1 || finalize_fail "invalid receipt entry schema"

    kind="$(printf '%s' "${item}" | jq -r '.kind')"
    source="$(printf '%s' "${item}" | jq -r '.source')"
    mountpoint="$(printf '%s' "${item}" | jq -r '.mountpoint')"
    archive_name="$(printf '%s' "${item}" | jq -r '.archive')"
    remote_path="$(printf '%s' "${item}" | jq -r '.remote')"
    expected_hash="$(printf '%s' "${item}" | jq -r '.sha256')"

    # Recompute identity instead of trusting a source field next to a valid hash.
    identity="${kind}:${source}"
    mount_id="$(printf '%s' "${identity}" | sha256sum | cut -c1-12)"
    if [[ "${kind}" == "volume" ]]; then
      safe_name="$(project_compose_sanitize_name "${source}")" || finalize_fail "invalid volume name"
      [[ -n "${mountpoint}" ]] || finalize_fail "volume mountpoint is empty"
      [[ "$(docker volume inspect --format '{{.Mountpoint}}' "${source}" 2>/dev/null)" == "${mountpoint}" ]] || finalize_fail "volume mountpoint changed for ${source}"
    else
      safe_name="$(project_compose_sanitize_name "$(basename -- "${source}")")" || finalize_fail "invalid bind name"
    fi
    expected_archive="$(backup_get_filename "${project_domain}_mount-${safe_name}-${mount_id}" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")" || finalize_fail "could not derive archive identity"
    expected_remote="${SERVER_NAME}/projects-online/site-mounts/${project_domain}/${expected_archive}"
    [[ "${archive_name}" == "${expected_archive}" && "${remote_path}" == "${expected_remote}" ]] || finalize_fail "archive identity mismatch for ${source}"

    verify_dir="$(mktemp -d "${BROLIT_TMP_DIR}/${NOW}/mount-final-verify.XXXXXX")" || finalize_fail "could not create verification directory"
    storage_download_backup "${remote_path}" "${verify_dir}" "true" >/dev/null || { rm -rf -- "${verify_dir}"; finalize_fail "could not download archive for ${source}"; }
    actual_hash="$(sha256sum "${verify_dir}/${archive_name}" 2>/dev/null | awk '{print $1}')"
    rm -rf -- "${verify_dir}"
    [[ "${actual_hash}" == "${expected_hash}" ]] || finalize_fail "archive checksum mismatch for ${source}"
  done < "${receipt}"

  # `down` without -v removes containers but preserves volumes for the explicit,
  # receipt-bound removal below. No automatic restart is attempted after this.
  docker compose -f "${compose_file}" down >/dev/null 2>&1 || finalize_fail "Compose down failed"
  down_done="true"

  while IFS= read -r item; do
    [[ -n "${item}" ]] || continue
    kind="$(printf '%s' "${item}" | jq -r '.kind')"
    [[ "${kind}" == "volume" ]] || continue
    source="$(printf '%s' "${item}" | jq -r '.source')"
    docker volume rm -- "${source}" >/dev/null 2>&1 || finalize_fail "could not remove volume ${source}"
  done < "${receipt}"

  success="true"
  rm -rf -- "${work_dir}"
  return 0
)

################################################################################
function project_delete() {

  local project_domain="${1}"
  local delete_cf_entry="${2}"

  local project_type
  local project_root_domain
  local project_install_type
  local deletion_block_output
  local deletion_gate_rc
  local deletion_mount_receipt=""

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

    if [[ ! -d ${PROJECTS_PATH}/${project_domain} ]]; then
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

    if [[ -z ${project_type} || -z ${project_install_type} ]]; then
      log_event "error" "Project deletion blocked: project type or installation type could not be determined." "false"
      return 1
    fi

    # Block before stopping services or making any other destructive changes.
    # A files backup and a database dump do not cover Compose persistent mounts.
    deletion_block_output="$(project_compose_deletion_safe "${PROJECTS_PATH}/${project_domain}" "${project_install_type}" "json")"
    deletion_gate_rc=$?
    if [[ ${deletion_gate_rc} -ne 0 ]]; then
      if [[ ${deletion_gate_rc} -eq 1 ]]; then
        # The gate found real data outside the files backup. Archive and verify
        # it instead of refusing forever; no container or volume is changed here.
        log_event "info" "Archiving uncovered persistent mounts before deleting ${project_domain}" "false"
        deletion_mount_receipt="$(project_compose_archive_deletion_mounts "${project_domain}" "${deletion_block_output}")"
        if [[ $? -ne 0 || -z "${deletion_mount_receipt}" ]]; then
          log_event "error" "Could not archive and verify every uncovered mount; deletion aborted before any destructive change." "false"
          display --indent 6 --text "- Persistent mount backup" --result "FAIL" --color RED
          return 1
        fi
      else
        log_event "error" "Docker project deletion blocked: persistent mount backup coverage is not verified." "false"
        display --indent 6 --text "- Docker persistent mount backup coverage is not verified" --result "FAIL" --color RED
        project_display_deletion_block "${deletion_gate_rc}" "${deletion_block_output}"
        return 1
      fi
    fi

    # Get db credentials from project config
    project_db_name=$(project_get_configured_database "${PROJECTS_PATH}/${project_domain}" "${project_type}" "${project_install_type}")
    project_db_user=$(project_get_configured_database_user "${PROJECTS_PATH}/${project_domain}" "${project_type}" "${project_install_type}")
    project_db_engine="$(project_get_configured_database_engine "${PROJECTS_PATH}/${project_domain}" "${project_type}" "${project_install_type}")"

    [[ -z "${project_db_engine}" ]] && project_db_engine="$(database_ask_engine)"

    # Remove unwanted output
    clear_previous_lines "1"

    # Make one last backup.
    if ! backup_project "${project_domain}" "all" "deletion"; then
      if [[ -n "${deletion_mount_receipt}" ]]; then
        project_compose_abort_archived_deletion_mounts "${project_domain}" "${deletion_mount_receipt}"
      fi
      return 1
    fi

    # Only after both backups succeeded may the covered mounts be removed. The
    # second gate in project_delete_files then sees no remaining uncovered mount.
    if [[ -n "${deletion_mount_receipt}" ]]; then
      if ! project_compose_finalize_archived_deletion_mounts "${project_domain}" "${deletion_mount_receipt}"; then
        log_event "error" "Could not finalize the verified mount removal for ${project_domain}" "false"
        display --indent 6 --text "- Verified mount removal" --result "FAIL" --color RED
        return 1
      fi
    fi

    # Delete Files
    if ! project_delete_files "${project_domain}"; then

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

    if [[ -z ${project_root_domain} ]]; then

      # Log
      log_event "info" "Cloudflare entries not deleted. '${project_domain}' is not a valid domain/subdomain." "false"
      display --indent 6 --text "- Deleting Cloudflare entries" --result "SKIPPED" --color YELLOW
      display --indent 8 --text "'${project_domain}' is not a valid domain/subdomain." --tcolor YELLOW

    else

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
    docker=""
    local entry
    for entry in "${dir_path}"/*/; do
      if [[ -f "${entry}docker-compose.yml" ]] || [[ -f "${entry}docker-compose.yaml" ]]; then
        docker="true"
        break
      fi
    done
    if [[ -f "${dir_path}/docker-compose.yml" ]] || [[ -f "${dir_path}/docker-compose.yaml" ]]; then
      docker="true"
    fi
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
  local nginx_config_file=""  # tracks the nginx config filename (redirect_domain for root_domain type)

  # Log
  log_subsection "Update Domain Configuration"

  project_root_domain="$(domain_get_root "${project_domain}")"
  if [[ $? -ne 0 ]]; then
    display --indent 6 --text "- Update Domain Configuration" --result "FAIL" --color RED
    display --indent 8 --text "Domain extension for '${project_domain}' not supported, add it to config/domain_extension-list"
    log_event "error" "Aborting: unsupported domain extension for '${project_domain}'" "false"
    return 1
  fi

  # Validate port if provided
  if [[ -n "${project_port}" && ! "${project_port}" =~ ^[0-9]+$ ]]; then
    log_event "error" "Invalid port number: ${project_port}" "false"
    display --indent 6 --text "- Port validation" --result "FAIL" --color RED
    return 1
  fi

  # Set project type for dockerized installations (internally stored as "proxy")
  [[ ${project_install_type} == "proxy" || ${project_install_type} == "docker"* ]] && project_type="proxy"

  # Working with root domain or www?
  # Use the user-provided domain as canonical, not always www.
  # Previously this always used www.project_root_domain as primary,
  # causing infinite redirects when WordPress WP_HOME was set to non-www.
  if [[ ${project_domain} == "${project_root_domain}" ]]; then
    # User provided root domain (non-www): serve at non-www, redirect www → non-www
    # Nginx config: primary = project_domain (non-www), redirect = www
    # nginx_server_create names root_domain files after the 4th arg (redirect_domains)
    nginx_config_file="www.${project_root_domain}"
    nginx_server_create "${project_domain}" "${project_type}" "root_domain" "${nginx_config_file}" "${project_port}"

    # Cloudflare
    if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then
      ## Nginx redirects: www.root_domain.com -> root_domain.com
      ## So Cloudflare must point: root -> server IP (A), www -> root (CNAME)

      # Delete conflicting record types before creating new ones (Cloudflare rejects A if CNAME exists for same host)
      cloudflare_delete_record "${project_root_domain}" "${project_root_domain}" "CNAME" 2>/dev/null || true
      cloudflare_delete_record "${project_root_domain}" "www.${project_root_domain}" "A" 2>/dev/null || true

      cloudflare_set_record "${project_root_domain}" "${project_root_domain}" "A" "false" "${SERVER_IP}"
      exitstatus=$?
      [[ ${exitstatus} -ne 0 ]] && cloudflare_exitstatus=${exitstatus}

      cloudflare_set_record "${project_root_domain}" "www.${project_root_domain}" "CNAME" "false" "${project_root_domain}"
      exitstatus=$?
      [[ ${exitstatus} -ne 0 ]] && cloudflare_exitstatus=${exitstatus}
    fi
  elif [[ ${project_domain} == "www.${project_root_domain}" ]]; then
    # User provided www: serve at www, redirect non-www → www
    nginx_config_file="${project_root_domain}"
    nginx_server_create "${project_domain}" "${project_type}" "root_domain" "${nginx_config_file}" "${project_port}"

    # Cloudflare
    if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then
      ## Nginx redirects: root_domain.com -> www.root_domain.com
      ## So Cloudflare must point: www -> server IP (A), root -> www (CNAME)
      cloudflare_delete_record "${project_root_domain}" "www.${project_root_domain}" "CNAME" 2>/dev/null || true
      cloudflare_set_record "${project_root_domain}" "www.${project_root_domain}" "A" "false" "${SERVER_IP}"
      exitstatus=$?
      [[ ${exitstatus} -ne 0 ]] && cloudflare_exitstatus=${exitstatus}

      cloudflare_delete_record "${project_root_domain}" "${project_root_domain}" "A" 2>/dev/null || true
      cloudflare_set_record "${project_root_domain}" "${project_root_domain}" "CNAME" "false" "www.${project_root_domain}"
      exitstatus=$?
      [[ ${exitstatus} -ne 0 ]] && cloudflare_exitstatus=${exitstatus}
    fi
  fi

  if [[ ${project_domain} == "${project_root_domain}" || ${project_domain} == "www.${project_root_domain}" ]]; then

    if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then
      # Wait for DNS propagation (independent of Cloudflare status)
      display --indent 6 --text "- Waiting for DNS propagation"
      log_event "info" "Waiting for DNS propagation..." "false"

      if wait_for_dns_propagation "${project_domain}" "${SERVER_IP}" 60; then

        clear_previous_lines "1"
        display --indent 6 --text "- Waiting for DNS propagation" --result "DONE" --color GREEN

        # Install certificate (attempt regardless of Cloudflare status)
        # Use non-interactive mode (true) to avoid prompts during automated restoration
        if certbot_certificate_install_auto "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${project_root_domain},www.${project_root_domain}" "true"; then
          # Enable HTTP/2 only if not already enabled
          # Use nginx_config_file (redirect_domain) for root_domain type, project_domain for single
          if [[ -n "${nginx_config_file}" ]]; then
            nginx_server_add_http2_support "${nginx_config_file}"
          else
            nginx_server_add_http2_support "${project_domain}"
          fi
          project_https_enable="true"
        else
          log_event "warning" "Certbot failed, proceeding with HTTP configuration" "false"
          display --indent 6 --text "- SSL Certificate" --result "WARNING" --color YELLOW
          project_https_enable="false"
        fi

      else

        clear_previous_lines "1"
        display --indent 6 --text "- Waiting for DNS propagation" --result "WARNING" --color YELLOW
        log_event "warning" "DNS propagation not confirmed for ${project_domain}, skipping certbot (would fail HTTP-01 challenge)" "false"
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

      if wait_for_dns_propagation "${project_domain}" "${SERVER_IP}" 60; then

        clear_previous_lines "1"
        display --indent 6 --text "- Waiting for DNS propagation" --result "DONE" --color GREEN

        # Install certificate (attempt regardless of Cloudflare status)
        # Use non-interactive mode (true) to avoid prompts during automated restoration
        if certbot_certificate_install_auto "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${project_domain}" "true"; then
          # Enable HTTP/2 only if not already enabled
          nginx_server_add_http2_support "${project_domain}"
          project_https_enable="true"
        else
          log_event "warning" "Certbot failed, proceeding with HTTP configuration" "false"
          display --indent 6 --text "- SSL Certificate" --result "WARNING" --color YELLOW
          project_https_enable="false"
        fi

      else

        clear_previous_lines "1"
        display --indent 6 --text "- Waiting for DNS propagation" --result "WARNING" --color YELLOW
        log_event "warning" "DNS propagation not confirmed for ${project_domain}, skipping certbot (would fail HTTP-01 challenge)" "false"
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
        # Guard against re-running this against an already-migrated site.
        # The search/replace below is a plain substring match, not a
        # true rename - if new_project_domain already appears in the DB
        # (e.g. this restore already ran once, or something else already
        # wrote it), re-running would match the new domain's occurrences
        # too, since new_project_domain typically contains old_project_domain
        # as a substring (e.g. dev.example.com contains example.com),
        # corrupting them into "dev.dev.example.com". One cheap read avoids
        # a full-database, expensive-to-detect corruption.
        local already_migrated_home
        already_migrated_home="$(wpcli_option_get_home "${project_install_path}" "${project_install_type}" 2>/dev/null)"

        if [[ ${already_migrated_home} == "https://${new_project_domain}"* ]]; then

          log_event "info" "Site's home option already points at ${new_project_domain}, skipping search-replace (already migrated)" "false"
          display --indent 6 --text "- Running search and replace" --result "SKIPPED" --color YELLOW
          display --indent 8 --text "Already migrated to ${new_project_domain}" --tcolor YELLOW

        else

          # Real WP content is rarely one clean canonical URL: old posts/embeds
          # commonly mix http:// and https://, and root-level domains commonly
          # mix www./non-www links even when one is the "official" canonical.
          # A single bare-domain search (scheme-agnostic, matches both http://
          # and https://) already covers the scheme axis. The www axis needs
          # its own pass ONLY when old_project_domain is root-level - a
          # subdomain (e.g. shop.example.com) has no "www." variant to worry
          # about, and treating it as one would search/replace the bare apex
          # domain, corrupting mentions of unrelated subdomains that happen to
          # share it (e.g. blog.example.com).
          local root_domain_old
          root_domain_old="$(domain_get_root "${old_project_domain}")"

          if [[ ${old_project_domain} == "${root_domain_old}" || ${old_project_domain} == "www.${root_domain_old}" ]]; then
            # Pass 1: consolidate any www-prefixed occurrence down to the bare
            # root domain first. Must run before pass 2 - if run after, pass 2's
            # search for the bare root domain would also match (and corrupt)
            # the "<new_project_domain>" strings pass 2 just wrote, since
            # "<root_domain_old>" is typically a substring of
            # "<new_project_domain>" (e.g. dev.<root_domain_old>).
            wpcli_search_and_replace "${project_install_path}" "${project_install_type}" "www.${root_domain_old}" "${root_domain_old}"

            # Pass 2: every remaining occurrence of the bare root domain (both
            # what was already bare, and what pass 1 just consolidated) now
            # becomes the new domain, in one single pass.
            wpcli_search_and_replace "${project_install_path}" "${project_install_type}" "${root_domain_old}" "${new_project_domain}"
          else
            # Source domain is itself a subdomain - no www ambiguity, single
            # exact scheme-agnostic pass.
            wpcli_search_and_replace "${project_install_path}" "${project_install_type}" "${old_project_domain}" "${new_project_domain}"
          fi

        fi

        # Update WP_HOME & WP_SITEURL only if domain changed (idempotent
        # either way - safe to run even when the search-replace above was
        # skipped because the site was already migrated).
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

################################################################################
# Nightly backup of persistent Compose mounts
#
# A files backup archives the project directory and a database dump covers the
# databases. A named volume, or a bind mount that resolves outside the project,
# is in neither, so the nightly backup could report success while that data had
# no copy (found on tukiverse.com and tukigrowth.com, 2026-11-19).
#
# This is the scheduled counterpart of the deletion-time archive above, and it
# reuses the same primitives (the coverage gate, compress, the storage
# controller). What differs, on purpose:
#   - it never stops or pauses a container: consistency comes from a strict tar
#     pass that is retried, and a store too busy for a clean pass is recorded as
#     "live" instead of being hidden;
#   - it has its own remote directory and follows the project's retention. The
#     deletion archives are kept outside retention and are never touched;
#   - it is off unless BACKUPS.config[].projects[].mounts is "enabled".
################################################################################

################################################################################
# Is the nightly mounts backup enabled?
#
# Absent or anything other than "enabled" means off, so a server whose
# configuration predates the key keeps its current behavior.
#
# Outputs:
#   0 if enabled, 1 otherwise.
################################################################################
function project_compose_mounts_backup_enabled() {
  [[ "${BACKUP_CONFIG_MOUNTS:-disabled}" == "enabled" ]]
}

################################################################################
# Is this mount the data directory of a database that brolit dumps?
#
# Mirrors docker_list_project_databases (libs/apps/docker_helper.sh), the code
# that decides which databases are dumped: the last path segment of the image
# must be mysql/mariadb or postgres/postgresql/timescaledb AND the service must
# mount the engine's data directory. Redis, Valkey, Mongo and a database's other
# volumes are not dumped, so their data is not covered and must be archived.
#
# Arguments:
#   ${1} = image reference
#   ${2} = destination path inside the container
#
# Outputs:
#   0 if the mount is dumped database data, 1 otherwise.
################################################################################
function project_compose_is_dumped_database_mount() {
  local image="${1}" destination="${2}" repository

  [[ -n "${image}" && -n "${destination}" ]] || return 1

  repository="${image%%@*}"
  repository="${repository##*/}"
  repository="${repository%%:*}"
  repository="${repository,,}"

  case "${repository}" in
    mysql | mariadb)
      [[ "${destination}" =~ ^/var/lib/mysql ]] && return 0
      ;;
    postgres | postgresql | timescaledb)
      [[ "${destination}" =~ ^/var/lib/postgresql ]] && return 0
      ;;
  esac

  return 1
}

################################################################################
# Every mount of the containers related to a project, one JSON object per line:
# {project, type, source, destination, image, optout, resolved}.
#
# `source` is the volume name for a volume and the declared path for a bind;
# `resolved` is the real path of a bind. Only mount fields, the image and the
# brolit.backup label are read: never the environment, the command or any other
# container configuration, because those can carry credentials.
#
# Arguments:
#   ${1} = existing project directory
#
# Outputs:
#   JSON lines on success; nonzero if the runtime inspection is incomplete.
################################################################################
function project_compose_mount_details() {
  local project_dir ids id record records='' mounts_jsonl line resolved

  project_dir="$(realpath -e -- "${1}" 2>/dev/null)" || return 1
  [[ -d "${project_dir}" && "${project_dir}" != "/" ]] || return 1
  command -v docker >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 1

  ids="$(docker ps --all --quiet --no-trunc 2>/dev/null)" || return 1
  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    [[ "${id}" =~ ^[a-f0-9]{12,64}$ ]] || return 1
    record="$(docker inspect --format '{"project":{{json (index .Config.Labels "com.docker.compose.project")}},"working_dir":{{json (index .Config.Labels "com.docker.compose.project.working_dir")}},"image":{{json .Config.Image}},"optout":{{json (index .Config.Labels "brolit.backup")}},"mounts":{{json .Mounts}}}' "${id}" 2>/dev/null)" || return 1
    [[ -n "${record}" ]] || return 1
    records+="${record}"$'\n'
  done <<<"${ids}"

  mounts_jsonl="$(printf '%s' "${records}" | jq -c --arg dir "${project_dir}" '
    def within($root): . == $root or startswith($root + "/");
    def related:
      (if (.working_dir | type) == "string" then (.working_dir | within($dir)) else false end)
      or any(.mounts[]?; .Type == "bind" and ((.Source | type) == "string") and (.Source | within($dir)));
    select(related) | . as $c | .mounts[]? |
    {
      project: ($c.project // ""),
      type: .Type,
      source: (if .Type == "volume" then (.Name // "") else (.Source // "") end),
      destination: (.Destination // ""),
      image: ($c.image // ""),
      optout: ($c.optout // "")
    }' 2>/dev/null)" || return 1

  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    resolved=""
    if [[ "$(printf '%s' "${line}" | jq -r '.type')" == "bind" ]]; then
      resolved="$(realpath -e -- "$(printf '%s' "${line}" | jq -r '.source')" 2>/dev/null)" || resolved=""
    fi
    printf '%s' "${line}" | jq -c --arg resolved "${resolved}" '. + {resolved: $resolved}' || return 1
  done <<<"${mounts_jsonl}"

  return 0
}

################################################################################
# Version of the running shell, read from release/version.env.
#
# SCRIPT_V is a stale constant and BROLIT_VERSION exists only in brolit_lite.sh,
# so the release file is the one source that is right on a staged install.
#
# Outputs:
#   The version (for example 3.14.24), or "unknown".
################################################################################
function project_compose_shell_version() {
  local version=""

  if [[ -n "${BROLIT_MAIN_DIR:-}" && -f "${BROLIT_MAIN_DIR}/release/version.env" ]]; then
    version="$(sed -n 's/^BROLIT_RELEASE_VERSION="\{0,1\}\([0-9][0-9.]*\)"\{0,1\}[[:space:]]*$/\1/p' "${BROLIT_MAIN_DIR}/release/version.env" | head -n 1)"
  fi

  printf '%s\n' "${version:-unknown}"
}

################################################################################
# Archive one mount as a consistent snapshot without touching any container.
#
# tar exits with status 1 when a file changed while it was read, which is
# exactly the signal that the copy may be inconsistent. A pass without that
# warning read files that did not change, so it is a consistent snapshot of a
# file based store (SQLite with its WAL included). Up to
# BROLIT_MOUNTS_BACKUP_ATTEMPTS strict passes are tried; if every one sees a
# change, a last tolerant pass keeps the archive and the result is labelled
# "live": a crash-consistent copy, weaker evidence, never reported as consistent.
#
# SQLite's shared-memory index (*-shm) is excluded: readers update it even when
# no data changes, which would raise false "changed" warnings, and SQLite
# rebuilds it from the WAL when the database is opened.
#
# Arguments:
#   ${1} = absolute path of the directory to archive
#   ${2} = archive path
#
# Outputs:
#   "<size>|<consistent|live>|<attempts>" on stdout; 0 on success, 1 on failure.
#   A failed archive leaves no partial file behind.
################################################################################
function project_compose_archive_mount_snapshot() {
  local archive_source="${1}" archive_path="${2}"
  local attempt=0 max_attempts="${BROLIT_MOUNTS_BACKUP_ATTEMPTS:-3}" archive_size
  local -a exclude_args=("--exclude=*.db-shm" "--exclude=*.sqlite-shm" "--exclude=*.sqlite3-shm")

  [[ -n "${archive_source}" && "${archive_source}" == /* && "${archive_source}" != "/" ]] || return 1
  [[ -n "${archive_path}" ]] || return 1
  [[ "${max_attempts}" =~ ^[1-9][0-9]*$ ]] || max_attempts=3

  while [[ ${attempt} -lt ${max_attempts} ]]; do
    attempt=$((attempt + 1))
    if archive_size="$(BROLIT_STRICT_TAR=1 compress "/" "${archive_source#/}" "${archive_path}" "${exclude_args[@]}")" &&
      [[ -s "${archive_path}" ]]; then
      printf '%s|consistent|%s\n' "${archive_size}" "${attempt}"
      return 0
    fi
    rm --force -- "${archive_path}"
    [[ ${attempt} -lt ${max_attempts} ]] && sleep "${BROLIT_MOUNTS_RETRY_SLEEP:-3}"
  done

  # Every strict pass failed. Either the store is busy or tar failed for a real
  # reason; a tolerant pass tells them apart.
  if archive_size="$(compress "/" "${archive_source#/}" "${archive_path}" "${exclude_args[@]}")" &&
    [[ -s "${archive_path}" ]]; then
    printf '%s|live|%s\n' "${archive_size}" "$((attempt + 1))"
    return 0
  fi

  rm --force -- "${archive_path}"
  return 1
}

################################################################################
# Say WHY project_compose_mount_coverage cannot establish coverage.
#
# The gate answers with an exit code only. When it answers "cannot establish"
# (2) a sysadmin has to decide what to do, and cannot decide from a bare code.
# This reads the same evidence, changes nothing and prints one plain sentence
# per cause. The classifier stays as strict as it was: this only explains.
#
# The commonest cause in practice: a container that Docker Compose did not
# create (a `docker run`, a hand-made tool) mounts a path inside the project. It
# has no Compose project label, so who owns the data is ambiguous.
#
# Output contains container names, label values and mount paths only (trimmed to
# printable characters), never environment variables or command lines.
#
# Arguments:
#   ${1} = project directory
#
# Outputs:
#   the reasons on stdout, one per line; always returns 0.
################################################################################
function project_compose_mount_coverage_explain() {
  local dir_path="${1}"
  local project_dir ids id record records='' found=0 line

  if [[ -z "${dir_path}" || ! -d "${dir_path}" ]]; then
    echo "The project directory does not exist."
    return 0
  fi
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed or is not in the PATH of the backup."
    return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is not installed, which the coverage check needs."
    return 0
  fi
  if ! project_dir="$(realpath -e -- "${dir_path}" 2>/dev/null)" || [[ -z "${project_dir}" || "${project_dir}" == "/" ]]; then
    echo "The project directory cannot be resolved."
    return 0
  fi

  project_dotenv_has_compose_file "${project_dir}"
  case $? in
    0)
      echo "The .env of the project sets COMPOSE_FILE, so its Compose context cannot be reasoned about. Remove it, or pass the file on the Compose command line."
      found=1
      ;;
    1) : ;;
    *)
      echo "A .env file of the project exists but cannot be read."
      found=1
      ;;
  esac

  if ! ids="$(docker ps --all --quiet --no-trunc 2>/dev/null)"; then
    echo "docker ps failed: is the Docker daemon running?"
    return 0
  fi

  while IFS= read -r id; do
    [[ -z "${id}" ]] && continue
    if ! record="$(docker inspect --format '{"id":{{json .Id}},"name":{{json .Name}},"project":{{json (index .Config.Labels "com.docker.compose.project")}},"working_dir":{{json (index .Config.Labels "com.docker.compose.project.working_dir")}},"mounts":{{json .Mounts}}}' "${id}" 2>/dev/null)" || [[ -z "${record}" ]]; then
      echo "docker inspect failed for container ${id:0:12} (it may have been removed while it was read)."
      found=1
      continue
    fi
    records+="${record}"$'\n'
  done <<< "${ids}"

  # A container is related to the project when its Compose working directory or
  # one of its bind mounts is inside it. Related and without a Compose project
  # label is exactly what the classifier calls an ambiguous context.
  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    echo "${line}"
    found=1
  done < <(printf '%s' "${records}" | jq -r --arg dir "${project_dir}" '
    def within($root): . == $root or startswith($root + "/");
    select(type == "object") |
    ((.mounts // []) | map(select(.Type == "bind" and ((.Source | type) == "string") and (.Source | within($dir))) | .Source)) as $binds |
    select(
      ((.working_dir | type) == "string" and (.working_dir | within($dir))) or ($binds | length) > 0
    ) |
    select(((.project | type) != "string") or ((.project | length) == 0)) |
    "Container " + ((.name // (.id[0:12])) | ltrimstr("/")) +
    " was not created by Docker Compose (project label: " +
    (if (.project | type) == "string" and (.project | length) > 0 then .project else "none" end) +
    ", working directory label: " +
    (if (.working_dir | type) == "string" then .working_dir else "none" end) +
    ") but " +
    (if ($binds | length) > 0 then "it mounts " + ($binds | join(", ")) else "it uses the directory of this project" end) +
    ". Remove it, or create it with Docker Compose inside this project, so who owns that data is not ambiguous."
  ' 2>/dev/null | LC_ALL=C tr -cd '[:print:]\n' | cut -c1-400)

  if [[ ${found} -eq 0 ]]; then
    echo "Coverage could not be established for a reason this check does not name (several Compose project names for this directory, an interpolated project name, or an incomplete inspection). See the log of the run."
  fi

  return 0
}

################################################################################
# Back up the persistent mounts of a Compose project that the files backup and
# the database dumps do not cover.
#
# Selection starts from the coverage gate (project_compose_mount_coverage), the
# same classifier the deletion path trusts, and drops, recording each reason in
# the manifest: sockets, sources that do not exist, the data directory of a
# database that is dumped, mounts labelled brolit.backup=false and mounts above
# BROLIT_MOUNTS_BACKUP_MAX_MB (default 2048). Each mount gets its own remote
# directory: retention keeps the newest N files of a directory as a whole, so
# archives sharing one directory would delete each other.
#
# A failure never prevents the files and database backups that already ran, and
# it never stops a container. Any mount that could not be archived, or whose
# coverage could not be established, makes the result a failure so the project
# backup is reported as partial.
#
# Arguments:
#   ${1} = project domain
#
# Outputs:
#   0 if disabled, nothing to back up, or everything was archived; 1 otherwise.
################################################################################
function project_compose_backup_mounts() {
  local project_domain="${1}" work_dir rc

  project_compose_mounts_backup_enabled || return 0

  [[ -n "${project_domain}" && -d "${PROJECTS_PATH}/${project_domain}" ]] || return 1
  [[ -n "${BROLIT_TMP_DIR:-}" && -n "${NOW:-}" && -n "${SERVER_NAME:-}" ]] || return 1
  if ! { command -v docker >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; }; then
    log_event "error" "Mounts backup for ${project_domain} skipped: docker or jq is not available" "false"
    return 1
  fi

  work_dir="${BROLIT_TMP_DIR}/${NOW}/mounts-daily-${project_domain}"
  rm --recursive --force -- "${work_dir}"
  mkdir --parents -- "${work_dir}" || return 1

  _project_compose_backup_mounts_run "${project_domain}" "${PROJECTS_PATH}/${project_domain}" "${work_dir}"
  rc=$?

  rm --recursive --force -- "${work_dir}"
  return ${rc}
}

# Body of project_compose_backup_mounts; split so the work directory is always
# removed, whatever the path out of the loop.
function _project_compose_backup_mounts_run() {
  local project_domain="${1}" project_dir="${2}" work_dir="${3}"
  local gate_output gate_rc details item kind source destination normalized_kind identity
  local coverage_reason coverage_line
  local matches skip_reason volume_optout mountpoint archive_source image_destination image_ref
  local size_kb max_mb safe_name mount_id mount_dir archive_name archive_path snapshot
  local archive_size consistency attempts local_hash archive_bytes remote_root remote_mount_dir
  local manifest_file manifest_name manifest_json parent_dir
  local failures=0 archived=0 skipped=0
  local -A seen=()
  local -a manifest_items=() manifest_skipped=()

  remote_root="${SERVER_NAME}/projects-online/site-mounts-daily/${project_domain}"
  max_mb="${BROLIT_MOUNTS_BACKUP_MAX_MB:-2048}"
  [[ "${max_mb}" =~ ^[0-9]+$ ]] || max_mb=2048

  gate_output="$(project_compose_mount_coverage "${project_dir}" json)"
  gate_rc=$?
  case ${gate_rc} in
    0)
      log_event "info" "Mounts backup for ${project_domain}: no persistent mount outside the project directory" "false"
      return 0
      ;;
    1) ;;
    *)
      log_event "error" "Mounts backup for ${project_domain}: coverage could not be established, nothing was archived" "false"
      display --indent 6 --text "- Mounts backup for ${project_domain}" --result "FAIL" --color RED
      # Say why, in the log and for the mail, so a sysadmin can decide: the gate
      # stays as strict as it is (it also guards deletions), it only explains.
      coverage_reason="$(project_compose_mount_coverage_explain "${project_dir}" 2>/dev/null)"
      [[ -n "${coverage_reason}" ]] || coverage_reason="Coverage could not be established; see the log of the run."
      while IFS= read -r coverage_line; do
        [[ -n "${coverage_line}" ]] || continue
        log_event "error" "Mounts backup for ${project_domain}: ${coverage_line}" "false"
        display --indent 8 --text "${coverage_line}" --tcolor YELLOW
      done <<< "${coverage_reason}"
      [[ -v PROJECT_MOUNTS_FAILURE_REASON ]] || declare -g -A PROJECT_MOUNTS_FAILURE_REASON=()
      PROJECT_MOUNTS_FAILURE_REASON["${project_domain}"]="${coverage_reason}"
      return 1
      ;;
  esac

  # Without the details the dump and opt-out rules cannot be applied. Archiving
  # more is the safe direction (the size cap still bounds it), so go on.
  if ! details="$(project_compose_mount_details "${project_dir}")"; then
    details=""
    log_event "warning" "Mounts backup for ${project_domain}: mount details unavailable, database and opt-out rules not applied" "false"
  fi

  display --indent 6 --text "- Mounts backup for ${YELLOW}${project_domain}${ENDCOLOR}"

  while IFS= read -r item; do
    [[ -n "${item}" ]] || continue

    printf '%s' "${item}" | jq -e '
      type == "object" and (keys == ["destination","kind","source"]) and
      (.kind | type == "string" and length > 0) and
      (.source | type == "string" and length > 0) and
      (.destination | type == "string" and length > 0)' >/dev/null 2>&1 || {
      log_event "error" "Mounts backup for ${project_domain}: malformed coverage record" "false"
      failures=$((failures + 1))
      continue
    }

    kind="$(printf '%s' "${item}" | jq -r '.kind')"
    source="$(printf '%s' "${item}" | jq -r '.source')"
    destination="$(printf '%s' "${item}" | jq -r '.destination')"
    normalized_kind="${kind}"
    [[ "${kind}" == "volume-namespace" ]] && normalized_kind="volume"

    # One identity is archived once, even if the gate saw it on several
    # containers or reported it both by mount and by Compose namespace.
    identity="${normalized_kind}:${source}"
    [[ -n "${seen[${identity}]:-}" ]] && continue
    seen[${identity}]=1

    skip_reason=""
    mountpoint=""
    archive_source="${source}"

    case "${normalized_kind}" in
      volume | bind) ;;
      bind-unresolved)
        skip_reason="unresolvable"
        failures=$((failures + 1))
        ;;
      *)
        skip_reason="unsupported_kind"
        failures=$((failures + 1))
        ;;
    esac

    if [[ -z "${skip_reason}" && "${normalized_kind}" == "bind" ]]; then
      if [[ -S "${source}" ]]; then
        skip_reason="socket"
      elif [[ ! -e "${source}" && ! -L "${source}" ]]; then
        skip_reason="source_missing"
      fi
    fi

    # What the mount belongs to: the containers that mount it, from the details.
    matches=""
    if [[ -z "${skip_reason}" && -n "${details}" ]]; then
      matches="$(printf '%s\n' "${details}" | jq -c --arg kind "${normalized_kind}" --arg source "${source}" \
        'select(.type == $kind and (.source == $source or (.resolved // "") == $source))' 2>/dev/null)"
    fi

    if [[ -z "${skip_reason}" && -n "${matches}" ]]; then
      if printf '%s\n' "${matches}" | jq -e 'select(.optout == "false")' >/dev/null 2>&1; then
        skip_reason="opted_out"
      else
        while IFS=$'\t' read -r image_ref image_destination; do
          if project_compose_is_dumped_database_mount "${image_ref}" "${image_destination}"; then
            skip_reason="database_dump"
            break
          fi
        done < <(printf '%s\n' "${matches}" | jq -r '[.image, .destination] | @tsv')
      fi
    fi

    if [[ -z "${skip_reason}" && "${normalized_kind}" == "volume" ]]; then
      volume_optout="$(docker volume inspect --format '{{index .Labels "brolit.backup"}}' "${source}" 2>/dev/null)"
      [[ "${volume_optout}" == "false" ]] && skip_reason="opted_out"
    fi

    if [[ -z "${skip_reason}" && "${normalized_kind}" == "volume" ]]; then
      mountpoint="$(docker volume inspect --format '{{.Mountpoint}}' "${source}" 2>/dev/null)"
      if [[ -n "${mountpoint}" && "${mountpoint}" == /* && "${mountpoint}" != "/" && -d "${mountpoint}" ]]; then
        archive_source="${mountpoint}"
      else
        skip_reason="mountpoint_unavailable"
        failures=$((failures + 1))
      fi
    fi

    # Size guard. An archive that would fill the disk is the failure this
    # tool's history knows (2026-11-08 and 2026-11-11); compress has its own
    # free-space guard, this one keeps a huge volume out of a nightly run.
    if [[ -z "${skip_reason}" ]]; then
      size_kb="$(timeout 120 du --summarize --block-size=1K -- "${archive_source}" 2>/dev/null | cut -f1)"
      if [[ ! "${size_kb}" =~ ^[0-9]+$ ]]; then
        skip_reason="size_unknown"
        failures=$((failures + 1))
      elif [[ $((size_kb / 1024)) -gt ${max_mb} ]]; then
        skip_reason="too_large"
      fi
    fi

    if [[ -n "${skip_reason}" ]]; then
      skipped=$((skipped + 1))
      log_event "info" "Mounts backup for ${project_domain}: skipped a ${normalized_kind} mount (${skip_reason})" "false"
      manifest_skipped+=("$(jq -n -c --arg kind "${normalized_kind}" --arg source "${source}" --arg destination "${destination}" --arg reason "${skip_reason}" \
        '{kind:$kind,source:$source,destination:$destination,reason:$reason}')")
      continue
    fi

    safe_name="$(project_compose_sanitize_name "$(basename -- "${source}")")" || {
      failures=$((failures + 1))
      continue
    }
    # Distinct mounts may share a basename; identity is part of the name.
    mount_id="$(printf '%s' "${identity}" | sha256sum | cut -c1-12)"
    mount_dir="${safe_name}-${mount_id}"
    archive_name="$(backup_get_filename "${project_domain}_mount-${mount_dir}" "${BACKUP_CONFIG_COMPRESSION_EXTENSION}")" || {
      failures=$((failures + 1))
      continue
    }
    archive_path="${work_dir}/${archive_name}"

    if ! snapshot="$(project_compose_archive_mount_snapshot "${archive_source}" "${archive_path}")"; then
      log_event "error" "Mounts backup for ${project_domain}: could not archive a ${normalized_kind} mount" "false"
      failures=$((failures + 1))
      manifest_skipped+=("$(jq -n -c --arg kind "${normalized_kind}" --arg source "${source}" --arg destination "${destination}" --arg reason "archive_failed" \
        '{kind:$kind,source:$source,destination:$destination,reason:$reason}')")
      continue
    fi
    IFS='|' read -r archive_size consistency attempts <<<"${snapshot}"

    # One directory per mount: retention treats a directory as one series.
    remote_mount_dir="${remote_root}/${mount_dir}"
    for parent_dir in "${SERVER_NAME}" "${SERVER_NAME}/projects-online" "${SERVER_NAME}/projects-online/site-mounts-daily" "${remote_root}" "${remote_mount_dir}"; do
      storage_create_dir "${parent_dir}"
    done

    if storage_upload_backup "${archive_path}" "${remote_mount_dir}" "${archive_size}" >/dev/null; then
      archived=$((archived + 1))
      local_hash="$(sha256sum "${archive_path}" | awk '{print $1}')"
      archive_bytes="$(stat --format=%s "${archive_path}")"
      manifest_items+=("$(jq -n -c \
        --arg kind "${normalized_kind}" --arg source "${source}" --arg destination "${destination}" \
        --arg archive "${archive_name}" --arg remote "${remote_mount_dir}/${archive_name}" \
        --arg sha256 "${local_hash}" --argjson bytes "${archive_bytes}" \
        --arg consistency "${consistency}" --argjson attempts "${attempts}" \
        '{kind:$kind,source:$source,destination:$destination,archive:$archive,remote:$remote,sha256:$sha256,bytes:$bytes,consistency:$consistency,attempts:$attempts}')")
      log_event "info" "Mounts backup for ${project_domain}: archived a ${normalized_kind} mount (${consistency}, attempt ${attempts})" "false"
    else
      failures=$((failures + 1))
      log_event "error" "Mounts backup for ${project_domain}: upload failed for a ${normalized_kind} mount" "false"
      manifest_skipped+=("$(jq -n -c --arg kind "${normalized_kind}" --arg source "${source}" --arg destination "${destination}" --arg reason "upload_failed" \
        '{kind:$kind,source:$source,destination:$destination,reason:$reason}')")
    fi

    # Retention runs even when the upload failed: removing the oldest remote
    # archives is what frees quota so the next attempt can succeed.
    storage_delete_old_backups "${remote_mount_dir}"
    [[ $? -ne 0 ]] && log_event "error" "Retention cleanup failed for mounts backup: ${project_domain}" "false"

    rm --force -- "${archive_path}"
  done <<<"${gate_output}"

  # The manifest says what was archived, how consistently, and what was left
  # out and why. It lives in its own directory for the same retention reason.
  manifest_name="$(backup_get_filename "${project_domain}_mounts-manifest" "json")"
  manifest_file="${work_dir}/${manifest_name}"
  manifest_json="$(jq -n -c \
    --arg domain "${project_domain}" --arg generated_at "$(date --utc +%Y-%m-%dT%H:%M:%SZ)" \
    --arg shell_version "$(project_compose_shell_version)" --argjson failures "${failures}" \
    --argjson items "$(printf '%s' "$(printf '%s\n' "${manifest_items[@]}")" | jq -s '.')" \
    --argjson skipped "$(printf '%s' "$(printf '%s\n' "${manifest_skipped[@]}")" | jq -s '.')" \
    '{schema_version:1,domain:$domain,generated_at:$generated_at,shell_version:$shell_version,failures:$failures,items:$items,skipped:$skipped}')" || {
    log_event "error" "Mounts backup for ${project_domain}: could not build the manifest" "false"
    return 1
  }
  printf '%s\n' "${manifest_json}" >"${manifest_file}"

  for parent_dir in "${SERVER_NAME}" "${SERVER_NAME}/projects-online" "${SERVER_NAME}/projects-online/site-mounts-daily" "${remote_root}" "${remote_root}/manifest"; do
    storage_create_dir "${parent_dir}"
  done
  if storage_upload_backup "${manifest_file}" "${remote_root}/manifest" "1K" >/dev/null; then
    storage_delete_old_backups "${remote_root}/manifest"
  else
    log_event "error" "Mounts backup for ${project_domain}: manifest upload failed" "false"
    failures=$((failures + 1))
  fi
  rm --force -- "${manifest_file}"

  if [[ ${failures} -eq 0 ]]; then
    display --indent 6 --text "- Mounts backup for ${YELLOW}${project_domain}${ENDCOLOR}" --result "DONE" --color GREEN
    display --indent 8 --text "Archived: ${archived}, skipped: ${skipped}" --tcolor GREEN
    return 0
  fi

  display --indent 6 --text "- Mounts backup for ${YELLOW}${project_domain}${ENDCOLOR}" --result "FAIL" --color RED
  display --indent 8 --text "Archived: ${archived}, skipped: ${skipped}, failed: ${failures}" --tcolor RED
  return 1
}
