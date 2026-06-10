#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.6
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

  echo -n "./runner.sh [TASK] [SUB-TASK]... [OPTIONS]...

  Tasks:
    -t, --task        Task to run:
                        backup              Subtasks: all, files, databases, server-config, project
                        restore             Subtasks: from-local, from-storage, from-url, from-borg
                        project             Subtasks: delete, online, offline, regen-nginx
                        project-install     (uses -tf/-tt instead of subtask)
                        database            Subtasks: list_db, create_db, delete_db, rename_db,
                                            import_db, export_db, list_db_user, create_db_user,
                                            delete_db_user, change_db_user_psw
                        certbot             Subtasks: install, expand, force-renew, delete, list, test-renew
                        cloudflare-api      Subtasks: clear_cache, dev_mode, ssl_mode
                        wpcli               Subtasks: plugin-install, plugin-activate, plugin-deactivate,
                                            plugin-update, plugin-version, clear-cache, cache-activate,
                                            cache-deactivate, verify-installation, core-update, search-replace
                        ssh-keygen          (no subtask)
                        disk-cleanup        Subtasks: apt, journal, docker, all
                        aliases-install     (no subtask)

  Options:
    -st, --subtask    Sub-task to run (see task list above)
    -s,  --site       Site path for tasks execution
    -D,  --domain     Domain for tasks execution
    -pn, --pname      Project Name
    -pt, --ptype      Project Type (wordpress, laravel, php, etc.)
    -ps, --pstate     Project Stage (prod, dev, test, stage)
    -db, --dbname     Database name
    -dbn, --dbname-new  New database name (for rename)
    -dbs, --dbstage   Database stage
    -dbu, --dbuser    Database user
    -dbup, --dbuser-psw  Database user password
    -tf, --file       Config file path (for project-install)
    -tt, --type       Install type: clean, copy (for project-install)
    -tv, --task-value Value parameter for tasks that need it
    -dr, --dry-run    Dry-run mode (show what would be freed, no changes)
    -e,  --env        Environment
    -sl, --slog       Script log name
    -d,  --debug      Runs script in BASH debug mode (set -x)
    -h,  --help       Display this help and exit
        --version     Output version information and exit

  Examples:
    ./runner.sh -t backup -st project -D example.com
    ./runner.sh -t restore -st from-storage -D example.com -tv 2026-06-09
    ./runner.sh -t project -st online -D example.com
    ./runner.sh -t project -st regen-nginx -D example.com
    ./runner.sh -t database -st export_db -db mydb_prod
    ./runner.sh -t database -st import_db -db mydb_prod -tf /path/to/dump.sql
    ./runner.sh -t certbot -st install -D example.com
    ./runner.sh -t certbot -st force-renew -D example.com
    ./runner.sh -t cloudflare-api -st clear_cache -D example.com
    ./runner.sh -t wpcli -t search-replace -D example.com -tv "http://old.com,https://new.com"
    ./runner.sh -t disk-cleanup -st apt -dr
    ./runner.sh -t project-install -tf /path/to/config.json -tt clean

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

    # Validate required params based on subtask
    case "${STASK}" in
      project)
        validate_required_params "backup-project" "DOMAIN"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
        ;;
      databases)
        validate_required_params "backup-databases" "DBNAME"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
        ;;
    esac

    # Execute task
    execute_task_with_error_handling "backup-${STASK}" "subtasks_backup_handler" "${STASK}"
    exit_code=$?
    exit ${exit_code}
    ;;

  restore)
    # Validate subtask
    validate_task_and_subtask "restore" "${STASK}" "from-local from-storage from-url from-borg"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate required params
    case "${STASK}" in
      from-local|from-storage|from-url|from-borg)
        validate_required_params "restore-${STASK}" "DOMAIN"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
        ;;
    esac

    # Execute task
    execute_task_with_error_handling "restore-${STASK}" "subtasks_restore_handler" "${STASK}" "${DOMAIN}" "${FILE}" "${TVALUE}"
    exit_code=$?
    exit ${exit_code}
    ;;

  project)
    # Validate subtask
    validate_task_and_subtask "project" "${STASK}" "delete online offline regen-nginx"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate required params
    case "${STASK}" in
      delete|online|offline|regen-nginx)
        validate_required_params "project-${STASK}" "DOMAIN"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
        ;;
    esac

    # Execute task
    execute_task_with_error_handling "project-${STASK}" "project_tasks_handler" "${STASK}" "${PROJECTS_PATH}" "${PTYPE}" "${DOMAIN}" "${PNAME}" "${PSTATE}"
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
    validate_task_and_subtask "database" "${STASK}" "list_db create_db delete_db rename_db export_db import_db list_db_user create_db_user delete_db_user change_db_user_psw"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate required params based on subtask
    case "${STASK}" in
      create_db|delete_db|export_db|import_db)
        validate_required_params "database-${STASK}" "DBNAME"
        exit_code=$?
        ;;
      rename_db)
        validate_required_params "database-rename" "DBNAME" "DBNAME_N"
        exit_code=$?
        ;;
      create_db_user)
        validate_required_params "database-create-user" "DBUSER"
        exit_code=$?
        ;;
      delete_db_user)
        validate_required_params "database-delete-user" "DBUSER"
        exit_code=$?
        ;;
      change_db_user_psw)
        validate_required_params "database-change-psw" "DBUSER" "DBUSERPSW"
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
    execute_task_with_error_handling "cloudflare-${STASK}" "cloudflare_tasks_handler" "${STASK}" "${DOMAIN}" "${TVALUE}"
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
    execute_task_with_error_handling "wpcli-${STASK}" "wpcli_tasks_handler" "${STASK}" "${DOMAIN}" "${TVALUE}"
    exit_code=$?
    exit ${exit_code}
    ;;

  certbot)
    # Validate subtask
    validate_task_and_subtask "certbot" "${STASK}" "install expand force-renew delete list test-renew"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate required params based on subtask
    case "${STASK}" in
      install|expand|force-renew|delete|test-renew)
        validate_required_params "certbot-${STASK}" "DOMAIN"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
        ;;
    esac

    # Execute task
    execute_task_with_error_handling "certbot-${STASK}" "certbot_tasks_handler" "${STASK}" "${DOMAIN}"
    exit_code=$?
    exit ${exit_code}
    ;;

  aliases-install)
    # No subtask required
    execute_task_with_error_handling "aliases-install" "install_script_aliases"
    exit_code=$?
    exit ${exit_code}
    ;;

  ssh-keygen)
    # No subtask required. STASK used as optional keydir path.
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

  disk-cleanup)
    # Validate subtask
    validate_task_and_subtask "disk-cleanup" "${STASK}" "apt journal docker all"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate dry-run mode (pass DRY_RUN)
    export DRY_RUN

    # Execute task
    execute_task_with_error_handling "disk-cleanup-${STASK}" "clean_disk_${STASK}"
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
  declare -g DRY_RUN="false"

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
      exit 0
      ;;

    --version)
      echo "BROLIT Shell v${SCRIPT_V}"
      exit 0
      ;;

    -d | --debug)
      DEBUG="true"
      export DEBUG
      ;;

    -dr | --dry-run)
      DRY_RUN="true"
      export DRY_RUN
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

    -D | -do | --domain)
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
      exit 1
      ;;

    esac

    shift

  done

  # Script initialization
  script_init "true"

  tasks_handler "${TASK}"

}
