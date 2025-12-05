#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.5
################################################################################
#
# Database Manager: Perform database actions.
#
################################################################################

# TODO: use database controller

################################################################################
# Database Engine Menu
#
# Arguments:
#   none
#
# Outputs:
#   ${chosen_database_engine}
################################################################################

function database_ask_engine() {

  local database_engine_options
  local chosen_database_engine

  if [[ ${PACKAGES_POSTGRES_STATUS} == "enabled" ]] && { [[ ${PACKAGES_MARIADB_STATUS} == "enabled" ]] || [[ ${PACKAGES_MYSQL_STATUS} == "enabled" ]]; }; then

    database_engine_options=(
      "MYSQL" "      [X]"
      "POSTGRESQL" "      [X]"
    )

    chosen_database_engine="$(whiptail --title "DATABASE MANAGER" --menu " " 20 78 10 "${database_engine_options[@]}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    echo "${chosen_database_engine}" && return ${exitstatus}

  else

    if [[ ${PACKAGES_MARIADB_STATUS} == "enabled" || ${PACKAGES_MYSQL_STATUS} == "enabled" ]]; then

      echo "MYSQL" && return 0

    else

      [[ ${PACKAGES_POSTGRES_STATUS} == "enabled" ]] && echo "POSTGRESQL" && return 0

      return 1

    fi

  fi

}

################################################################################
# Database Delete Menu
#
# Arguments:
#   ${1} = ${database_engine}
#   ${2} = ${database_container} - Optional
#
# Outputs:
#   nothing
################################################################################

function database_delete_menu() {

  local database_engine="${1}"
  local database="${2}"

  local databases
  local chosen_database

  # List databases
  databases="$(database_list "all" "${database_engine}" "")"

  chosen_database="$(whiptail --title "DATABASE MANAGER" --menu "Choose the database to delete" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) --default-item "${database}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${database_engine} == "MYSQL" ]]; then

      mysql_database_drop "${chosen_database}"

    else

      [[ ${database_engine} == "POSTGRESQL" ]] && postgres_database_drop "${chosen_database}"

    fi

  fi

}

################################################################################
# Database List Menu
#
# Arguments:
#   ${1} = ${database_engine}
#   ${2} = ${database_container} - Optional
#
# Outputs:
#   nothing
################################################################################

function database_stage_list_menu() {

  local database_engine="${1}"
  local database_container="${2}"

  local databases
  local database_list_options
  local chosen_database_option

  database_list_options=("all prod stage test dev demo")

  chosen_database_option="$(whiptail_selection_menu "DATABASE MANAGER" "Select a project stage for the database:" "${database_list_options}" "all")"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    echo "${chosen_database_option}"

  else

    return 1

  fi

}

################################################################################
# Database Manager Menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function database_manager_menu() {

  local database_engine_options
  local database_manager_options
  local database_list_options
  local chosen_database_manager_option
  local chosen_database
  local chosen_database_name
  local chosen_database_stage
  local chosen_database_engine

  local database_container
  local database_container_selected

  # Log
  log_event "debug" "Entering Database Manager. PACKAGES_DOCKER_STATUS='${PACKAGES_DOCKER_STATUS}'" "false"
  log_subsection "Database Manager"

  # Always check for docker containers if docker available
  database_container=""
  if command -v docker >/dev/null 2>&1; then
    database_container="$(docker ps --format "{{.Names}}" | grep -iE 'mysql|mariadb|postgres')"
    log_event "debug" "Docker containers found: '${database_container}'" "false"
  else
    log_event "warn" "Docker not available" "false"
  fi

  # Is not empty?
  if [[ -n ${database_container} ]]; then
    # Whiptail to prompt user if want to use docker
    whiptail_message_with_skip_option "Docker Support" "Database containers are running, do you want to work with an specific docker container?"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

      # Database Container selection menu
      database_container_selected="$(whiptail --title "Select a Database Container" --menu "Choose a Database Container to work with" 20 78 10 $(for x in ${database_container}; do echo "$x [X]"; done) 3>&1 1>&2 2>&3)"
      exitstatus=$?
      [[ ${exitstatus} -eq 1 ]] && log_event "info" "Docker container selection cancelled" "false" && database_container_selected=""

      if [[ -n ${database_container_selected} ]]; then
        # Check if database engine is mysql or postgres
        [[ ${database_container_selected} == *"mysql"* ]] && chosen_database_engine="MYSQL"
        [[ ${database_container_selected} == *"mariadb"* ]] && chosen_database_engine="MYSQL"
        [[ ${database_container_selected} == *"postgres"* ]] && chosen_database_engine="POSTGRESQL"
        log_event "info" "Selected Docker container '${database_container_selected}' → Engine '${chosen_database_engine}'" "false"
      fi

    fi
  fi

  # Select database engine (host only if no Docker)
  if [[ -z ${chosen_database_engine} ]]; then
    log_event "debug" "No Docker engine, trying host via database_ask_engine" "false"
    chosen_database_engine="$(database_ask_engine)"
  fi
  log_event "debug" "Final engine selected: '${chosen_database_engine}'" "false"

  if [[ -z ${chosen_database_engine} ]]; then
    log_event "error" "No database engine found!" "true"
    log_event "error" "Check: Docker containers running? Host MySQL/Postgres enabled/installed?" "true"
    whiptail --title "DATABASE MANAGER ERROR" --msgbox "No database engine detected.\n\n- Verify Docker containers (mysql/postgres names).\n- Or enable/install host MySQL/MariaDB/PostgreSQL.\n\nCheck logs for details." 12 70
    prompt_return_or_finish
    database_manager_menu  # Recurse to retry
    return 1
  fi

  # Loop to keep showing menu after each action
  while true; do

  database_manager_options=(
    "01)" "LIST DATABASES"
    "02)" "CREATE DATABASE"
    "03)" "DELETE DATABASE"
    "04)" "RENAME DATABASE"
    "05)" "LIST USERS"
    "06)" "CREATE USER"
    "07)" "DELETE USER"
    "08)" "CHANGE USER PASSWORD"
    "09)" "GRANT USER PRIVILEGES"
    "10)" "EXPORT DATABASE DUMP"
    "11)" "IMPORT DUMP INTO DATABASE"
    "12)" "RENAME DATABASE (ALPHA)"
    "13)" "SEARCH STRING IN DATABASE"
    "14)" "LIST TABLES"
    "15)" "DELETE TABLE"
    "16)" "SCAN DATABASE FOR MALWARE"
  )

  chosen_database_manager_option="$(whiptail --title "DATABASE MANAGER" --menu " " 20 78 10 "${database_manager_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    # LIST DATABASES
    if [[ ${chosen_database_manager_option} == *"01"* ]]; then

      chosen_database_stage="$(database_stage_list_menu "${chosen_database_engine}" "${database_container_selected}")"

      # List databases
      databases="$(database_list "${chosen_database_stage}" "${chosen_database_engine}" "${database_container_selected}")"

      display --indent 8 --text "Databases:" --tcolor WHITE

      # Database users list
      for database in ${databases}; do
        display --indent 12 --text "${database}" --tcolor GREEN
      done

    fi

    # CREATE DATABASE
    if [[ ${chosen_database_manager_option} == *"02"* ]]; then

      chosen_database_name="$(whiptail_input "DATABASE MANAGER" "Insert the database name you want to create, example: my_domain_prod" "")"

      exitstatus=$?

      if [[ ${exitstatus} -eq 0 ]]; then

        [[ ${chosen_database_engine} == "MYSQL" ]] && mysql_database_create "${chosen_database_name}"

        [[ ${chosen_database_engine} == "POSTGRESQL" ]] && postgres_database_create "${chosen_database_name}"

      fi

    fi

    # DELETE DATABASE
    [[ ${chosen_database_manager_option} == *"03"* ]] && database_delete_menu "${chosen_database_engine}" ""

    # RENAME DATABASE
    if [[ ${chosen_database_manager_option} == "04" ]]; then

      # List databases
      databases="$(database_list "${chosen_database_stage}" "${chosen_database_engine}" "${database_container_selected}")"

      chosen_database="$(whiptail --title "DATABASE MANAGER" --menu "Choose a database to delete" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) --default-item "${database}" 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        chosen_database_name="$(whiptail_input "DATABASE MANAGER" "Insert the database name you want to create, example: my_domain_prod" "")"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          if [[ ${chosen_database_engine} == "MYSQL" ]]; then
            # MySQL
            mysql_database_rename "${chosen_database}" "${chosen_database_name}"

          else
            # PostgreSQL
            [[ ${chosen_database_engine} == "POSTGRESQL" ]] && postgres_database_rename "${chosen_database}" "${chosen_database_name}"

          fi

        fi

      fi

    fi

    # LIST USERS
    if [[ ${chosen_database_manager_option} == *"05"* ]]; then

      # Get users
      database_users="$(database_users_list "${chosen_database_engine}" "${database_container_selected}")"

      display --indent 8 --text "Database Users:" --tcolor WHITE

      # Database users list
      for database_user in ${database_users}; do
        display --indent 12 --text "${database_user}" --tcolor GREEN
      done

    fi

    # CREATE USER DATABASE
    if [[ ${chosen_database_manager_option} == *"06"* ]]; then

      chosen_username="$(whiptail_input "DATABASE MANAGER" "Insert the username you want to create, example: my_domain_user" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        local suggested_userpsw

        suggested_userpsw="$(openssl rand -hex 12)"

        chosen_userpsw="$(whiptail_input "DATABASE MANAGER" "Use this random generated password, edit or leave it empty:" "${suggested_userpsw}")"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          if [[ ${chosen_database_engine} == "MYSQL" ]]; then
            # MySQL
            mysql_user_create "${chosen_username}" "${chosen_userpsw}" "localhost"

          else
            # PostgreSQL
            [[ ${chosen_database_engine} == "POSTGRESQL" ]] && postgres_user_create "${chosen_username}" "${chosen_userpsw}" "localhost"

          fi

        fi

      fi

    fi

    # DELETE USER
    if [[ ${chosen_database_manager_option} == *"07"* ]]; then

      # List users
      database_users="$(database_users_list "${chosen_database_engine}" "${database_container_selected}")"

      chosen_user="$(whiptail --title "DATABASE MANAGER" --menu "Choose the user you want to delete" 20 78 10 $(for x in ${database_users}; do echo "$x [U]"; done) 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        database_user_delete "${chosen_user}" "localhost" "${chosen_database_engine}" "${database_container_selected}"

      fi

    fi

    # RESET MYSQL USER PASSWORD
    if [[ ${chosen_database_manager_option} == *"08"* ]]; then

      # List users
      database_users="$(database_users_list "${chosen_database_engine}" "${database_container_selected}")"

      chosen_user="$(whiptail --title "DATABASE MANAGER" --menu "Choose a user to work with" 20 78 10 $(for x in ${database_users}; do echo "$x [U]"; done) 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        new_user_psw="$(whiptail --title "MYSQL USER PASSWORD" --inputbox "Insert the new user password:" 10 60 3>&1 1>&2 2>&3)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          if [[ ${chosen_database_engine} == "MYSQL" ]]; then
            # MySQL
            mysql_user_psw_change "${chosen_user}" "${new_user_psw}"

          else
            # PostgreSQL
            [[ ${chosen_database_engine} == "POSTGRESQL" ]] && postgres_user_psw_change "${chosen_user}" "${new_user_psw}"

          fi

        fi

      fi

    fi

    # GRANT PRIVILEGES
    if [[ ${chosen_database_manager_option} == *"09"* ]]; then

      # List users
      database_users="$(database_users_list "${chosen_database_engine}" "${database_container_selected}")"

      chosen_user="$(whiptail --title "DATABASE MANAGER" --menu "Choose a user to work with" 20 78 10 $(for x in ${database_users}; do echo "$x [U]"; done) 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # List databases
        if [[ ${chosen_database_engine} == "MYSQL" ]]; then
          # MySQL
          databases="$(mysql_list_databases "all")"
        else
          # PostgreSQL
          [[ ${chosen_database_engine} == "POSTGRESQL" ]] && databases="$(postgres_list_databases "all")"
        fi

        chosen_database="$(whiptail --title "DATABASE MANAGER" --menu "Choose the database to grant privileges" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) --default-item "${database}" 3>&1 1>&2 2>&3)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          if [[ ${chosen_database_engine} == "MYSQL" ]]; then
            # MySQL
            mysql_user_grant_privileges "${chosen_user}" "${chosen_database}" "localhost"
          else
            # PostgreSQL
            [[ ${chosen_database_engine} == "POSTGRESQL" ]] && postgres_user_grant_privileges "${chosen_user}" "${chosen_database}" "localhost"
          fi

        fi

      fi

    fi

    # EXPORT DATABASE DUMP
    if [[ ${chosen_database_manager_option} == *"10"* ]]; then

      # List databases
      databases="$(database_list "${chosen_database_stage}" "${chosen_database_engine}" "${database_container_selected}")"

      chosen_database="$(whiptail --title "DATABASE MANAGER" --menu "Choose the database to export" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        if [[ ${chosen_database_engine} == "MYSQL" ]]; then
          # MySQL
          mysql_database_export "${chosen_database}" "${database_container_selected}" "${BROLIT_TMP_DIR}/${chosen_database}.sql"

        else
          # PostgreSQL
          [[ ${chosen_database_engine} == "POSTGRESQL" ]] && postgres_database_export "${chosen_database}" "${database_container_selected}" "${BROLIT_TMP_DIR}/${chosen_database}.sql"

        fi

      fi

    fi

    # IMPORT DATABASE DUMP
    if [[ ${chosen_database_manager_option} == *"11"* ]]; then

      # List databases
      databases="$(database_list "${chosen_database_stage}" "${chosen_database_engine}" "${database_container_selected}")"

      chosen_database="$(whiptail --title "DATABASE MANAGER" --menu "Choose the database to import" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Select source file
        dump_file=$(whiptail --title "Source File" --inputbox "Please insert project database's backup (full path):" 10 60 "/root/to_restore/backup.sql" 3>&1 1>&2 2>&3)

        if [[ -f ${dump_file} ]]; then

          display --indent 6 --text "Selected source: ${dump_file}"

        else

          display --indent 6 --text "Selected source: ${dump_file}" --result "ERROR" --color RED
          display --indent 6 --text "File not found" --tcolor RED
          return 1

        fi

        log_event "info" "File to restore: ${dump_file}" "false"

        if [[ ${chosen_database_engine} == "MYSQL" ]]; then
          # MySQL
          mysql_database_import "${chosen_database}" "${database_container_selected}" "${dump_file}"

        else
          # PostgreSQL
          [[ ${chosen_database_engine} == "POSTGRESQL" ]] && postgres_database_import "${chosen_database}" "${database_container_selected}" "${dump_file}"

        fi

      fi

    fi

    # RENAME DATABASE (ALPHA)
    if [[ ${chosen_database_manager_option} == *"12"* ]]; then

      log_section "Project Utils"
      log_subsection "Rename database"

      local chosen_db
      local new_database_name

      chosen_db="$(mysql_ask_database_selection)"

      new_database_name="$(whiptail_input "Database Name" "Insert a new database name (only separator allow is '_'). Old name was: ${chosen_db}" "")"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        log_event "debug" "Setting new_database_name: ${new_database_name}" "false"

        mysql_database_rename "${chosen_db}" "${new_database_name}"

      else

        return 1

      fi

    fi

    # SEARCH STRING IN DATABASE
    if [[ ${chosen_database_manager_option} == *"13"* ]]; then

      log_subsection "Search string in database"

      # List databases
      databases="$(database_list "all" "${chosen_database_engine}" "${database_container_selected}")"

      # shellcheck disable=SC2046
      chosen_database="$(whiptail --title "DATABASE MANAGER" --menu "Choose the database to search in" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        search_string="$(whiptail_input "Search String" "Enter the string you want to search for in all tables:" "")"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 && -n ${search_string} ]]; then

          if [[ ${chosen_database_engine} == "MYSQL" ]]; then
            # MySQL
            mysql_database_search_string "${chosen_database}" "${search_string}" "${database_container_selected}"

          else
            # PostgreSQL
            [[ ${chosen_database_engine} == "POSTGRESQL" ]] && postgres_database_search_string "${chosen_database}" "${search_string}" "${database_container_selected}"

          fi

        else

          display --indent 6 --text "Search cancelled or empty string" --result "SKIPPED" --color YELLOW

        fi

      fi

    fi

    # LIST TABLES
    if [[ ${chosen_database_manager_option} == *"14"* ]]; then

      log_subsection "List tables"

      # List databases
      databases="$(database_list "all" "${chosen_database_engine}" "${database_container_selected}")"

      # shellcheck disable=SC2046
      chosen_database="$(whiptail --title "DATABASE MANAGER" --menu "Choose the database to list tables from" 20 78 10 $(for x in ${databases}; do echo "$x" "[DB]"; done) 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        local tables

        if [[ ${chosen_database_engine} == "MYSQL" ]]; then
          # MySQL
          tables="$(mysql_list_tables "${chosen_database}" "${database_container_selected}")"

        else
          # PostgreSQL
          [[ ${chosen_database_engine} == "POSTGRESQL" ]] && tables="$(postgres_list_tables "${chosen_database}" "${database_container_selected}")"

        fi

        # Display tables
        display --indent 8 --text "Tables in database '${chosen_database}':" --tcolor WHITE

        for table in ${tables}; do
          # Trim whitespace
          table="$(echo "${table}" | xargs)"
          [[ -z ${table} ]] && continue
          display --indent 12 --text "${table}" --tcolor GREEN
        done

      fi

    fi

    # DELETE TABLE
    if [[ ${chosen_database_manager_option} == *"15"* ]]; then

       log_subsection "Delete table"

      # List databases
      databases="$(database_list "all" "${chosen_database_engine}" "${database_container_selected}")"

      # shellcheck disable=SC2046
      chosen_database="$(whiptail --title "DATABASE MANAGER" --menu "Choose the database" 20 78 10 $(for x in ${databases}; do echo "$x" "[DB]"; done) 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        local tables

        if [[ ${chosen_database_engine} == "MYSQL" ]]; then
          # MySQL
          tables="$(mysql_list_tables "${chosen_database}" "${database_container_selected}")"

        else
          # PostgreSQL
          [[ ${chosen_database_engine} == "POSTGRESQL" ]] && tables="$(postgres_list_tables "${chosen_database}" "${database_container_selected}")"

        fi

        # Select table to delete
        # shellcheck disable=SC2046
        chosen_table="$(whiptail --title "DATABASE MANAGER" --menu "Choose the table to delete" 20 78 10 $(for x in ${tables}; do x="$(echo "${x}" | xargs)"; [[ -n ${x} ]] && echo "$x" "[TABLE]"; done) 3>&1 1>&2 2>&3)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          # Trim whitespace from chosen table name
          chosen_table="$(echo "${chosen_table}" | xargs)"

          # Show warning and confirmation
          whiptail --title "WARNING: DELETE TABLE" \
            --yesno "You are about to DELETE the table '${chosen_table}' from database '${chosen_database}'.\n\nThis action is IRREVERSIBLE and will permanently delete all data in this table.\n\nAre you sure you want to continue?" \
            15 78

          exitstatus=$?
          if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_database_engine} == "MYSQL" ]]; then
              # MySQL
              mysql_table_drop "${chosen_database}" "${chosen_table}" "${database_container_selected}"

            else
              # PostgreSQL
              [[ ${chosen_database_engine} == "POSTGRESQL" ]] && postgres_table_drop "${chosen_database}" "${chosen_table}" "${database_container_selected}"

            fi

          else

            display --indent 6 --text "Table deletion cancelled" --result "SKIPPED" --color YELLOW

          fi

        fi

      fi

    fi

    # SCAN DATABASE FOR MALWARE
    if [[ ${chosen_database_manager_option} == *"16"* ]]; then

      log_subsection "Database Malware Scanner"

      # List databases
      databases="$(database_list "all" "${chosen_database_engine}" "${database_container_selected}")"

      # shellcheck disable=SC2046
      chosen_database="$(whiptail --title "DATABASE MANAGER" --menu "Choose the database to scan" 20 78 10 $(for x in ${databases}; do echo "$x" "[DB]"; done) 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # Show warning about scan
        if [[ ${chosen_database_engine} == "MYSQL" ]]; then
          whiptail --title "Database Malware Scanner" \
            --msgbox "This will scan the database for common malware patterns:\n\nMySQL/MariaDB (optimized for WordPress):\n- base64_decode, eval(), exec(), system()\n- Suspicious PHP functions\n- Unsafe superglobals (\$_POST, \$_GET)\n- Script injections\n\nThis may take several minutes.\n\nPress OK to continue..." \
            16 78
        else
          whiptail --title "Database Malware Scanner" \
            --msgbox "This will scan the database for common malware patterns:\n\nPostgreSQL (generic scan):\n- base64_decode, eval(), exec(), system()\n- Suspicious PHP/JS functions\n- XSS patterns (script tags, event handlers)\n- Shell commands\n\nThis may take several minutes.\n\nPress OK to continue..." \
            16 78
        fi

        if [[ ${chosen_database_engine} == "MYSQL" ]]; then
          # MySQL - WordPress optimized scan
          mysql_wordpress_malware_scan "${chosen_database}" "${database_container_selected}"

        else
          # PostgreSQL - Generic database scan
          [[ ${chosen_database_engine} == "POSTGRESQL" ]] && postgres_database_malware_scan "${chosen_database}" "${database_container_selected}"

        fi

      fi

    fi

    prompt_return_or_finish
    exitstatus=$?
    if [[ ${exitstatus} -ne 0 ]]; then
      # User chose to finish, exit loop
      break
    fi
    # User chose to return to menu, continue loop

  else
    # User cancelled menu selection, exit loop
    break
  fi

  done # End of while true loop

  menu_main_options

}

################################################################################
# Task handler for database functions
#
# Arguments:
#  ${1} = ${subtask}
#  ${2} = ${dbname}
#  ${3} = ${dbstage}
#  ${4} = ${dbname_n}
#  ${5} = ${dbuser}
#  ${6} = ${dbuser_psw}
#
# Outputs:
#   global vars
################################################################################

function database_tasks_handler() {

  local subtask="${1}"
  local dbname="${2}"
  local dbstage="${3}"
  local dbname_n="${4}"
  local dbuser="${5}"
  local dbuser_psw="${6}"

  log_subsection "Database Manager"

  case ${subtask} in

  list_db)

    mysql_list_databases "${dbstage}"

    exit
    ;;

  create_db)

    mysql_database_create "${dbname}"

    exit
    ;;

  delete_db)

    mysql_database_drop "${dbname}"

    exit
    ;;

  rename_db)

    mysql_database_rename "${dbname}" "${dbname_n}"

    exit
    ;;

  list_db_user)

    mysql_users_list

    exit
    ;;

  create_db_user)

    mysql_user_create "${dbuser}" "" ""

    exit
    ;;

  delete_db_user)

    mysql_user_delete "${dbuser}" "localhost"

    exit
    ;;

  change_db_user_psw)

    mysql_user_psw_change "${dbuser}" "${dbuser_psw}"

    exit
    ;;

  *)

    log_event "error" "INVALID DATABASE TASK: ${subtask}" "true"

    exit
    ;;

  esac

}
