#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.4
################################################################################
#
# Task Runner Library
#
# This library contains all functions related to running tasks via command-line
# flags (non-interactive mode). It includes:
# - Flag parsing (flags_handler)
# - Task routing (tasks_handler)
# - Parameter validation
# - Error handling
#
################################################################################

################################################################################
# Show help information
#
# Arguments:
#   none
#
# Outputs:
#   String with help text
################################################################################

function show_help() {

  log_section "Help Menu"

  echo -n "./runner.sh [TASK] [SUB-TASK]... [DOMAIN]...

  Options:
    -t, --task        Task to run:
                        project-backup
                        project-restore
                        project-install
                        cloudflare-api
    -st, --subtask    Sub-task to run:
                        from cloudflare-api: clear_cache, dev_mode
    -s  --site        Site path for tasks execution
    -d  --domain      Domain for tasks execution
    -pn --pname       Project Name
    -pt --ptype       Project Type (wordpress,laravel)
    -ps --pstate      Project Stage (prod,dev,test,stage)
    -q, --quiet       Quiet (no output)
    -v, --verbose     Output more information. (Items echoed to 'verbose')
    -d, --debug       Runs script in BASH debug mode (set -x)
    -h, --help        Display this help and exit
        --version     Output version information and exit

  "

}

################################################################################
# Validate required parameters for tasks
#
# Arguments:
#   ${1} = ${task_name} - Name of the task for error messages
#   ${@} = ${param_names} - Names of required parameters to validate
#
# Outputs:
#   0 if all required params are set, 1 on error
################################################################################

function validate_required_params() {

  local task_name="${1}"
  shift
  local required_params=("$@")
  local missing_params=()

  # Check each required parameter
  for param in "${required_params[@]}"; do
    # Use indirect expansion to check if variable is empty
    if [[ -z "${!param}" ]]; then
      missing_params+=("${param}")
    fi
  done

  # If any parameters are missing, log error and exit
  if [[ ${#missing_params[@]} -gt 0 ]]; then
    log_event "error" "Task '${task_name}': Missing required parameters: ${missing_params[*]}" "true"
    display --indent 2 --text "- Missing required parameters for task '${task_name}'" --result "FAIL" --color RED

    for param in "${missing_params[@]}"; do
      # Convert param name to flag format (DOMAIN -> --domain)
      local flag_name
      flag_name="--$(echo "${param}" | tr '[:upper:]' '[:lower:]' | tr '_' '-')"
      display --indent 4 --text "Missing: ${flag_name}" --tcolor YELLOW
    done

    display --indent 2 --text "- Use --help for usage information" --tcolor WHITE
    return 1
  fi

  return 0

}

################################################################################
# Validate task exists and subtask is valid
#
# Arguments:
#   ${1} = ${task} - Task name
#   ${2} = ${subtask} - Subtask name (optional for some tasks)
#   ${3} = ${valid_subtasks} - Space-separated list of valid subtasks
#
# Outputs:
#   0 if valid, 1 on error
################################################################################

function validate_task_and_subtask() {

  local task="${1}"
  local subtask="${2}"
  local valid_subtasks="${3}"

  # If valid_subtasks is provided, validate subtask
  if [[ -n "${valid_subtasks}" ]]; then

    # Check if subtask is provided
    if [[ -z "${subtask}" ]]; then
      log_event "error" "Task '${task}': Subtask is required. Valid options: ${valid_subtasks}" "true"
      display --indent 2 --text "- Subtask required for '${task}'" --result "FAIL" --color RED
      display --indent 4 --text "Valid subtasks: ${valid_subtasks}" --tcolor YELLOW
      return 1
    fi

    # Check if subtask is valid
    local is_valid=0
    for valid in ${valid_subtasks}; do
      if [[ "${subtask}" == "${valid}" ]]; then
        is_valid=1
        break
      fi
    done

    if [[ ${is_valid} -eq 0 ]]; then
      log_event "error" "Task '${task}': Invalid subtask '${subtask}'. Valid options: ${valid_subtasks}" "true"
      display --indent 2 --text "- Invalid subtask '${subtask}' for task '${task}'" --result "FAIL" --color RED
      display --indent 4 --text "Valid subtasks: ${valid_subtasks}" --tcolor YELLOW
      return 1
    fi

  fi

  return 0

}

################################################################################
# Execute task with error handling
#
# Arguments:
#   ${1} = ${task_name} - Name of the task for logging
#   ${2} = ${function_name} - Function to execute
#   ${@} = ${function_args} - Arguments to pass to the function
#
# Outputs:
#   Exit code from the function
################################################################################

function execute_task_with_error_handling() {

  local task_name="${1}"
  local function_name="${2}"
  shift 2
  local function_args=("$@")

  local start_time
  local end_time
  local duration
  local exit_code

  start_time=$(date +%s)

  log_event "info" "Starting task: ${task_name}" "false"
  display --indent 2 --text "- Executing task: ${task_name}" --tcolor YELLOW

  # Execute the function
  "${function_name}" "${function_args[@]}"
  exit_code=$?

  end_time=$(date +%s)
  duration=$((end_time - start_time))

  if [[ ${exit_code} -eq 0 ]]; then
    log_event "info" "Task '${task_name}' completed successfully in ${duration}s" "false"
    display --indent 2 --text "- Task '${task_name}' completed" --result "DONE" --color GREEN
    display --indent 4 --text "Duration: ${duration}s" --tcolor WHITE
  else
    log_event "error" "Task '${task_name}' failed with exit code ${exit_code} after ${duration}s" "true"
    display --indent 2 --text "- Task '${task_name}' failed" --result "FAIL" --color RED
    display --indent 4 --text "Exit code: ${exit_code}" --tcolor RED
    display --indent 4 --text "Duration: ${duration}s" --tcolor WHITE
  fi

  return ${exit_code}

}

################################################################################
# Tasks handler
#
# Arguments:
#   ${1} = ${task}
#
# Outputs:
#   global vars
################################################################################

function tasks_handler() {

  local task="${1}"
  local exit_code=0

  case ${task} in

  backup)
    # Validate subtask
    validate_task_and_subtask "backup" "${STASK}" "all files databases server-config project"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate required params for project backup
    if [[ "${STASK}" == "project" ]]; then
      validate_required_params "backup-project" "DOMAIN"
      exit_code=$?
      [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
    fi

    # Execute task
    execute_task_with_error_handling "backup-${STASK}" "subtasks_backup_handler" "${STASK}"
    exit_code=$?
    exit ${exit_code}
    ;;

  restore)
    # Validate subtask
    validate_task_and_subtask "restore" "${STASK}" "all files databases server-config project"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate required params for restore tasks
    case "${STASK}" in
      files|database|project)
        validate_required_params "restore-${STASK}" "DOMAIN"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
        ;;
    esac

    # Execute task
    execute_task_with_error_handling "restore-${STASK}" "subtasks_restore_handler" "${STASK}"
    exit_code=$?
    exit ${exit_code}
    ;;

  project)
    # Validate subtask
    validate_task_and_subtask "project" "${STASK}" "delete install"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate required params
    case "${STASK}" in
      delete)
        validate_required_params "project-delete" "DOMAIN"
        exit_code=$?
        ;;
      install)
        validate_required_params "project-install" "DOMAIN" "PNAME" "PTYPE" "PSTATE"
        exit_code=$?
        ;;
    esac
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Execute task
    execute_task_with_error_handling "project-${STASK}" "project_tasks_handler" "${STASK}" "${PROJECTS_PATH}"
    exit_code=$?
    exit ${exit_code}
    ;;

  project-install)
    # Validate required params
    validate_required_params "project-install" "FILE" "TYPE"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Execute task
    execute_task_with_error_handling "project-install" "project_install_tasks_handler" "${FILE}" "${TYPE}"
    exit_code=$?
    exit ${exit_code}
    ;;

  database)
    # Validate subtask
    validate_task_and_subtask "database" "${STASK}" "list_db create_db delete_db rename_db import_db export_db user_create user_delete"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate required params based on subtask
    case "${STASK}" in
      create_db|delete_db|export_db)
        validate_required_params "database-${STASK}" "DBNAME"
        exit_code=$?
        ;;
      rename_db)
        validate_required_params "database-rename" "DBNAME" "DBNAME_N"
        exit_code=$?
        ;;
      import_db)
        validate_required_params "database-import" "DBNAME"
        exit_code=$?
        ;;
      user_create)
        validate_required_params "database-user-create" "DBUSER" "DBUSERPSW"
        exit_code=$?
        ;;
      user_delete)
        validate_required_params "database-user-delete" "DBUSER"
        exit_code=$?
        ;;
    esac
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Execute task
    execute_task_with_error_handling "database-${STASK}" "database_tasks_handler" "${STASK}" "${DBNAME}" "${DBSTAGE}" "${DBNAME_N}" "${DBUSER}" "${DBUSERPSW}"
    exit_code=$?
    exit ${exit_code}
    ;;

  cloudflare-api)
    # Validate subtask
    validate_task_and_subtask "cloudflare-api" "${STASK}" "clear_cache dev_mode ssl_mode"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate required params
    validate_required_params "cloudflare-${STASK}" "DOMAIN"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate TVALUE for certain subtasks
    if [[ "${STASK}" == "dev_mode" || "${STASK}" == "ssl_mode" ]]; then
      validate_required_params "cloudflare-${STASK}" "TVALUE"
      exit_code=$?
      [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
    fi

    # Execute task
    execute_task_with_error_handling "cloudflare-${STASK}" "cloudflare_tasks_handler" "${STASK}" "${TVALUE}"
    exit_code=$?
    exit ${exit_code}
    ;;

  wpcli)
    # Validate subtask
    validate_task_and_subtask "wpcli" "${STASK}" "plugin-install plugin-activate plugin-deactivate plugin-update plugin-version clear-cache cache-activate cache-deactivate verify-installation core-update search-replace"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate required params
    validate_required_params "wpcli-${STASK}" "DOMAIN"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate TVALUE for plugin operations
    if [[ "${STASK}" == plugin-* ]]; then
      validate_required_params "wpcli-${STASK}" "TVALUE"
      exit_code=$?
      [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
    fi

    # Execute task
    execute_task_with_error_handling "wpcli-${STASK}" "wpcli_tasks_handler" "${STASK}" "${TVALUE}"
    exit_code=$?
    exit ${exit_code}
    ;;

  aliases-install)
    # Execute task
    execute_task_with_error_handling "aliases-install" "install_script_aliases"
    exit_code=$?
    exit ${exit_code}
    ;;

  ssh-keygen)
    # Set default keydir if not provided
    if [[ -z ${STASK} ]]; then
      keydir=/root/pem
    else
      keydir="${STASK}"
    fi

    # Execute task
    execute_task_with_error_handling "ssh-keygen" "brolit_ssh_keygen" "${keydir}"
    exit_code=$?
    exit ${exit_code}
    ;;

  *)
    log_event "error" "INVALID TASK: ${TASK}" "true"
    display --indent 2 --text "- Invalid task: ${TASK}" --result "FAIL" --color RED
    display --indent 2 --text "- Use --help for usage information" --tcolor WHITE
    exit 1
    ;;

  esac

}

################################################################################
# Runner flags handler
#
# Arguments:
#   $*
#
# Outputs:
#   global vars
################################################################################

function flags_handler() {

  # GLOBALS

  ## OPTIONS
  declare -g ENV=""
  declare -g SLOG=""
  declare -g TASK=""
  declare -g STASK=""
  declare -g TVALUE=""
  declare -g DEBUG="false"

  ## PROJECT
  declare -g SITE=""
  declare -g DOMAIN=""
  declare -g PNAME=""
  declare -g PTYPE=""
  declare -g PSTATE=""

  ## DATABASE
  declare -g DBNAME=""
  declare -g DBNAME_N=""
  declare -g DBSTAGE=""
  declare -g DBUSER=""
  declare -g DBUSERPSW=""

  while [ $# -ge 1 ]; do

    case ${1} in

    # OPTIONS
    -h | -\? | --help)
      show_help # Display a usage synopsis
      exit
      ;;

    -d | --debug)
      DEBUG="true"
      export DEBUG
      ;;

    -e | --env)
      shift
      ENV="${1}"
      export ENV
      ;;

    -sl | --slog)
      shift
      SLOG="${1}"
      export SLOG
      ;;

    -t | --task)
      shift
      TASK="${1}"
      export TASK
      ;;

    -tf | --file)
      shift
      FILE="${1}"
      export FILE
      ;;

    -tt | --type)
      shift
      TYPE="${1}"
      export TYPE
      ;;

    -st | --subtask)
      shift
      STASK="${1}"
      export STASK
      ;;

    -tv | --task-value)
      shift
      TVALUE="${1}"
      export TVALUE
      ;;

    # PROJECT
    -s | --site)
      shift
      SITE="${1}"
      export SITE
      ;;

    -pn | --pname)
      shift
      PNAME="${1}"
      export PNAME
      ;;

    -pt | --ptype)
      shift
      PTYPE="${1}"
      export PTYPE
      ;;

    -ps | --pstate)
      shift
      PSTATE="${1}"
      export PSTATE
      ;;

    -do | --domain)
      shift
      DOMAIN="${1}"
      export DOMAIN
      ;;

    # DATABASE

    -db | --dbname)
      shift
      DBNAME="${1}"
      export DBNAME
      ;;

    -dbn | --dbname-new)
      shift
      DBNAME_N="${1}"
      export DBNAME_N
      ;;

    -dbs | --dbstage)
      shift
      DBSTAGE="${1}"
      export DBSTAGE
      ;;

    -dbu | --dbuser)
      shift
      DBUSER="${1}"
      export DBUSER
      ;;

    -dbup | --dbuser-psw)
      shift
      DBUSERPSW="${1}"
      export DBUSERPSW
      ;;

    *)
      echo "Invalid option: ${1}" >&2
      exit
      ;;

    esac

    shift

  done

  # Script initialization
  script_init "true"

  tasks_handler "${TASK}"

}
