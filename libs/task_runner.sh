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

  echo -n "./runner.sh [TASK] [SUB-TASK]... [OPTIONS]...

  Tasks:
    -t, --task        Task to run:
                        backup              Subtasks: all, files, databases, server-config,
                                            project, full-report, list, list-all, search
                        restore             Subtasks: from-local, from-storage, from-url, from-borg,
                                            download
                        project             Subtasks: delete, online, offline, regen-nginx
                        project-install     (uses -tf/-tt instead of subtask)
                        database            Subtasks: list_db, create_db, delete_db, rename_db,
                                            import_db, export_db, list_db_user, create_db_user,
                                            delete_db_user, change_db_user_psw, search-string,
                                            clone-db
                        certbot             Subtasks: install, expand, force-renew, delete, list, test-renew
                        cloudflare-api      Subtasks: clear_cache, dev_mode, ssl_mode
                        wpcli               Subtasks: plugin-install, plugin-activate, plugin-deactivate,
                                            plugin-update, plugin-version, clear-cache, cache-activate,
                                            cache-deactivate, verify-installation, core-update, search-replace
                        server-status       Subtasks: full (default), disk, packages, certs
                        security-scan       Subtasks: full (default), clamav, wordfence, processes
                        ssh-keygen          (no subtask)
                        disk-cleanup        Subtasks: apt, journal, docker, all
                        aliases-install     (no subtask)
                        openresty           Subtasks: install, uninstall, reconfigure, status,
                                            api-status, api-routes
                        migrate-npm         Subtasks: download-configs, migrate-all, migrate-domain

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
    -de, --db-engine  Database engine: auto (default), mysql, postgres
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
    ./runner.sh -t backup -st full-report
    ./runner.sh -t restore -st from-storage -D example.com -tv 2026-06-09
    ./runner.sh -t restore -st from-local -D example.com -tf /path/to/backup.tar.gz
    ./runner.sh -t restore -st from-url -D example.com -tf https://example.com/backup.tar.gz
    ./runner.sh -t restore -st from-borg -D example.com
    ./runner.sh -t restore -st download -D example.com
    ./runner.sh -t restore -st download -D example.com -tv 2026-06-09
    ./runner.sh -t restore -st list -D example.com
    ./runner.sh -t project -st online -D example.com
    ./runner.sh -t project -st regen-nginx -D example.com
    ./runner.sh -t database -st export_db -db mydb_prod
    ./runner.sh -t database -st export_db -db mydb_prod -de postgres
    ./runner.sh -t database -st import_db -db mydb_prod -tf /path/to/dump.sql
    ./runner.sh -t database -st search-string -db mydb -tv 'suspicious_string'
    ./runner.sh -t certbot -st install -D example.com
    ./runner.sh -t cloudflare-api -st clear_cache -D example.com
    ./runner.sh -t wpcli -t search-replace -D example.com -tv \"http://old.com,https://new.com\"
    ./runner.sh -t server-status
    ./runner.sh -t server-status -st certs
    ./runner.sh -t server-status -st certs -D example.com
    ./runner.sh -t security-scan
    ./runner.sh -t security-scan -D example.com
    ./runner.sh -t security-scan -st wordfence -D example.com
    ./runner.sh -t disk-cleanup -st apt -dr
    ./runner.sh -t project-install -tf /path/to/config.json -tt clean
    ./runner.sh -t openresty -st install
    ./runner.sh -t openresty -st api-routes
    ./runner.sh -t migrate-npm -st migrate-all -D 10.2.0.100

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
# Server status handler (plain-text output)
#
# Arguments:
#   ${1} = ${subtask} (full, disk, packages, certs)
#
# Outputs:
#   Plain-text status report to stdout
################################################################################

function server_status_handler() {

  local subtask="${1:-full}"

  log_section "Server Status"

  if [[ "${subtask}" == "full" || "${subtask}" == "disk" ]]; then
    local disk_pct
    local disk_info
    disk_pct="$(calculate_disk_usage "${MAIN_VOL}")"
    disk_info="$(df -h | grep -w "${MAIN_VOL}")"
    if [[ -n "${disk_pct}" ]]; then
      local disk_num
      disk_num="$(echo "${disk_pct}" | tr -d '%')"
      if [[ ${disk_num} -ge 80 ]]; then
        display --indent 2 --text "Disk: ${disk_info}" --result "WARNING" --color RED
      elif [[ ${disk_num} -ge 45 ]]; then
        display --indent 2 --text "Disk: ${disk_info}" --result "WARNING" --color YELLOW
      else
        display --indent 2 --text "Disk: ${disk_info}" --result "OK" --color GREEN
      fi
    else
      display --indent 2 --text "Disk: unable to read" --result "WARN" --color YELLOW
    fi
  fi

  if [[ "${subtask}" == "full" || "${subtask}" == "packages" ]]; then
    local outdated_count=0
    local pkg_list=""
    for pkg in "${PACKAGES[@]}"; do
      local installed_version
      local candidate_version
      installed_version="$(apt-cache policy "${pkg}" 2>/dev/null | grep 'Installed' | awk '{print $2}')"
      candidate_version="$(apt-cache policy "${pkg}" 2>/dev/null | grep 'Candidate' | awk '{print $2}')"
      if [[ -n "${installed_version}" && "${installed_version}" != "${candidate_version}" && "${candidate_version}" != "(none)" ]]; then
        pkg_list+="  ${pkg}: ${installed_version} -> ${candidate_version}\n"
        outdated_count=$((outdated_count + 1))
      fi
    done
    if [[ ${outdated_count} -gt 0 ]]; then
      display --indent 2 --text "Packages: ${outdated_count} outdated" --result "WARNING" --color YELLOW
      echo -e "${pkg_list}"
    else
      display --indent 2 --text "Packages: all up to date" --result "OK" --color GREEN
    fi
  fi

  if [[ "${subtask}" == "full" || "${subtask}" == "certs" ]]; then
    if [[ -n "${DOMAIN}" ]]; then
      local cert_days
      cert_days="$(certbot_certificate_valid_days "${DOMAIN}")"
      if [[ -z "${cert_days}" ]]; then
        display --indent 2 --text "${DOMAIN} - no certificate" --result "MISSING" --color WHITE
      elif [[ ${cert_days} -ge 14 ]]; then
        display --indent 2 --text "${DOMAIN} - ${cert_days} days remaining" --result "OK" --color GREEN
      elif [[ ${cert_days} -ge 7 ]]; then
        display --indent 2 --text "${DOMAIN} - ${cert_days} days remaining" --result "WARNING" --color YELLOW
      else
        display --indent 2 --text "${DOMAIN} - ${cert_days} days remaining" --result "CRITICAL" --color RED
      fi
    else
      local all_sites
      all_sites="$(get_all_directories "${PROJECTS_PATH}")"
      for site in ${all_sites}; do
        local domain
        domain="$(basename "${site}")"
        if [[ "${IGNORED_PROJECTS_LIST}" == *"${domain}"* ]]; then
          continue
        fi
        local cert_days
        cert_days="$(certbot_certificate_valid_days "${domain}")"
        if [[ -z "${cert_days}" ]]; then
          display --indent 2 --text "${domain} - no certificate" --result "MISSING" --color WHITE
        elif [[ ${cert_days} -ge 14 ]]; then
          display --indent 2 --text "${domain} - ${cert_days} days remaining" --result "OK" --color GREEN
        elif [[ ${cert_days} -ge 7 ]]; then
          display --indent 2 --text "${domain} - ${cert_days} days remaining" --result "WARNING" --color YELLOW
        else
          display --indent 2 --text "${domain} - ${cert_days} days remaining" --result "CRITICAL" --color RED
        fi
      done
    fi
  fi

}

################################################################################
# Security scan handler
#
# Arguments:
#   ${1} = ${subtask} (full, clamav, wordfence, processes)
#
# Outputs:
#   Scan results and notifications
################################################################################

function security_scan_handler() {

  local subtask="${1:-full}"
  local domain="${2:-}"
  local scan_status="No Issues"
  local scan_target
  local scan_label

  if [[ -n "${domain}" ]]; then
    scan_target="${PROJECTS_PATH}/${domain}"
    scan_label="${domain}"
  else
    scan_target="${PROJECTS_PATH}"
    scan_label="all projects"
  fi

  log_section "Security Scan (${scan_label})"

  if [[ "${subtask}" == "full" || "${subtask}" == "wordfence" ]]; then
    log_subsection "Wordfence Malware Scan"
    if [[ -n "${domain}" ]]; then
      local site="${PROJECTS_PATH}/${domain}"
      if [[ -d "${site}/wordpress" ]] || { [[ -f "${site}/index.php" ]] && [[ -d "${site}/wp-content" ]]; }; then
        local wf_result
        wf_result="$(wordfencecli_malware_scan "${site}" "true")"
        if [[ "${wf_result}" == "true" ]]; then
          display --indent 2 --text "${domain}" --result "MALWARE" --color RED
          send_notification "${SERVER_NAME}" "Malware detected on ${domain}" "alert"
          scan_status="Found Issues"
        else
          display --indent 2 --text "${domain}" --result "CLEAN" --color GREEN
        fi
      else
        display --indent 2 --text "${domain} is not a WordPress site, skipping wordfence" --result "SKIP" --color YELLOW
      fi
    else
      local all_sites
      all_sites="$(get_all_directories "${PROJECTS_PATH}")"
      for site in ${all_sites}; do
        local project_name
        project_name="$(basename "${site}")"
        if [[ -d "${site}/wordpress" ]] || { [[ -f "${site}/index.php" ]] && [[ -d "${site}/wp-content" ]]; }; then
          local wf_result
          wf_result="$(wordfencecli_malware_scan "${site}" "true")"
          if [[ "${wf_result}" == "true" ]]; then
            display --indent 2 --text "${project_name}" --result "MALWARE" --color RED
            send_notification "${SERVER_NAME}" "Malware detected on ${project_name}" "alert"
            scan_status="Found Issues"
          else
            display --indent 2 --text "${project_name}" --result "CLEAN" --color GREEN
          fi
        fi
      done
    fi
  fi

  if [[ "${subtask}" == "full" || "${subtask}" == "clamav" ]]; then
    log_subsection "ClamAV Scan"
    local clamav_result
    clamav_result="$(security_clamav_scan "${scan_target}")"
    if [[ "${clamav_result}" == "true" ]]; then
      display --indent 2 --text "ClamAV scan on ${scan_label}" --result "THREATS" --color RED
      send_notification "${SERVER_NAME}" "ClamAV detected threats in ${scan_label}" "alert"
      scan_status="Found Issues"
    else
      display --indent 2 --text "ClamAV scan on ${scan_label}" --result "CLEAN" --color GREEN
    fi
  fi

  if [[ "${subtask}" == "full" || "${subtask}" == "processes" ]]; then
    log_subsection "Process Scanner"
    local proc_result
    proc_result="$(security_process_scanner)"
    if [[ "${proc_result}" == "true" ]]; then
      display --indent 2 --text "Process scanner" --result "SUSPICIOUS" --color RED
      send_notification "${SERVER_NAME}" "Suspicious processes detected on ${SERVER_NAME}" "alert"
      scan_status="Found Issues"
    else
      display --indent 2 --text "Process scanner" --result "CLEAN" --color GREEN
    fi
  fi

  display --indent 2 --text "Security scan status: ${scan_status}" --tcolor WHITE

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

  restore)
    # Validate subtask
    validate_task_and_subtask "restore" "${STASK}" "from-local from-storage from-url from-borg download"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate required params based on subtask
    case "${STASK}" in
      from-local)
        validate_required_params "restore-from-local" "DOMAIN" "FILE"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
        ;;
      from-storage)
        validate_required_params "restore-from-storage" "DOMAIN"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
        ;;
      from-url)
        validate_required_params "restore-from-url" "DOMAIN" "FILE"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
        ;;
      from-borg)
        validate_required_params "restore-from-borg" "DOMAIN"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
        ;;
      download)
        validate_required_params "restore-download" "DOMAIN"
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
    validate_task_and_subtask "database" "${STASK}" "list_db create_db delete_db rename_db export_db import_db list_db_user create_db_user delete_db_user change_db_user_psw search-string clone-db"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate required params based on subtask
    case "${STASK}" in
      create_db|delete_db|export_db|import_db)
        validate_required_params "database-${STASK}" "DBNAME"
        exit_code=$?
        ;;
      rename_db|clone-db)
        validate_required_params "database-${STASK}" "DBNAME" "DBNAME_N"
        exit_code=$?
        ;;
      search-string)
        validate_required_params "database-search-string" "DBNAME" "TVALUE"
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
    execute_task_with_error_handling "database-${STASK}" "database_tasks_handler" "${STASK}" "${DBNAME}" "${DBSTAGE}" "${DBNAME_N}" "${DBUSER}" "${DBUSERPSW}" "${DBENGINE}" "${TVALUE}"
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

  server-status)
    validate_task_and_subtask "server-status" "${STASK:-full}" "full disk packages certs"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    server_status_handler "${STASK:-full}"
    exit_code=$?
    exit ${exit_code}
    ;;

  security-scan)
    validate_task_and_subtask "security-scan" "${STASK:-full}" "full clamav wordfence processes"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
      netdata_alerts_disable
    fi

    execute_task_with_error_handling "security-${STASK:-full}" "security_scan_handler" "${STASK:-full}" "${DOMAIN}"
    exit_code=$?

    if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
      netdata_alerts_enable
    fi

    exit ${exit_code}
    ;;

  backup)
    # Validate subtask
    validate_task_and_subtask "backup" "${STASK}" "all files databases server-config project full-report list list-all search"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    if [[ "${STASK}" == "full-report" ]]; then
      if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
        netdata_alerts_disable
      fi

      execute_task_with_error_handling "backup-full-report" "subtasks_backup_handler" "full-report"
      exit_code=$?

      if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then
        netdata_alerts_enable
      fi

      exit ${exit_code}
    fi

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
      list|list-all|search)
        validate_required_params "backup-${STASK}" "DOMAIN"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}
        ;;
    esac

    # Execute task
    execute_task_with_error_handling "backup-${STASK}" "subtasks_backup_handler" "${STASK}" "${DOMAIN}" "${FILE}" "${TVALUE}"
    exit_code=$?
    exit ${exit_code}
    ;;

  config-wizard)
    # shellcheck source=${BROLIT_MAIN_DIR}/utils/config_wizard.sh
    source "${BROLIT_MAIN_DIR}/utils/config_wizard.sh"
    config_wizard_menu
    exit_code=$?
    exit ${exit_code}
    ;;

  openresty)
    # Validate subtask
    validate_task_and_subtask "openresty" "${STASK}" "install uninstall reconfigure status api-status api-routes"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Execute task
    case "${STASK}" in
      install)
        execute_task_with_error_handling "openresty-install" "openresty_installer" "apt"
        ;;
      uninstall)
        execute_task_with_error_handling "openresty-uninstall" "openresty_purge"
        ;;
      reconfigure)
        execute_task_with_error_handling "openresty-reconfigure" "openresty_reconfigure"
        ;;
      status)
        execute_task_with_error_handling "openresty-status" "proxy_get_status"
        ;;
      api-status)
        execute_task_with_error_handling "openresty-api-status" "openresty_api_status"
        ;;
      api-routes)
        execute_task_with_error_handling "openresty-api-routes" "openresty_list_routes"
        ;;
    esac
    exit_code=$?
    exit ${exit_code}
    ;;

  migrate-npm)
    # Validate subtask
    validate_task_and_subtask "migrate-npm" "${STASK}" "download-configs migrate-all migrate-domain"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Validate required params
    validate_required_params "migrate-npm" "DOMAIN"
    exit_code=$?
    [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

    # Execute task
    case "${STASK}" in
      download-configs)
        execute_task_with_error_handling "migrate-npm-download" "npm_download_configs" "${DOMAIN}" "${TVALUE}"
        ;;
      migrate-all)
        execute_task_with_error_handling "migrate-npm-all" "npm_migrate_all" "${DOMAIN}" "${TVALUE}"
        ;;
      migrate-domain)
        execute_task_with_error_handling "migrate-npm-domain" "npm_migrate_domain" "${DOMAIN}" "${TVALUE}"
        ;;
    esac
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
  declare -g DBENGINE="auto"

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

    -wiz | --wizard)
      TASK="config-wizard"
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

    -de | --db-engine)
      shift
      DBENGINE="${1}"
      export DBENGINE
      ;;

    *)
      echo "Invalid option: ${1}" >&2
      exit 1
      ;;

    esac

    shift

  done

  tasks_handler "${TASK}"

}
