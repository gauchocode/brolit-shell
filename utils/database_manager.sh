#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.2
################################################################################
#
# Database Manager: Perform database actions.
#
################################################################################

# TODO: use database controller

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
  local chosen_database_manager_option
  local database_list_options
  local chosen_database_list_option

  if [[ ${PACKAGES_MARIADB_STATUS} == "enabled" || ${PACKAGES_MYSQL_STATUS} == "enabled" && ${PACKAGES_POSTGRES_STATUS} == "enabled" ]]; then
    database_engine_options=(
      "MYSQL" "      [X]"
      "POSTGRESQL" "      [X]"
    )

    chosen_database_engine_options="$(whiptail --title "DATABASE MANAGER" --menu " " 20 78 10 "${database_engine_options[@]}" 3>&1 1>&2 2>&3)"

  else

    if [[ ${PACKAGES_MARIADB_STATUS} == "enabled" || ${PACKAGES_MYSQL_STATUS} == "enabled" ]]; then
      chosen_database_engine_options="MYSQL"
    else
      chosen_database_engine_options="POSTGRESQL"
    fi

  fi

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
  )

  chosen_database_manager_option="$(whiptail --title "DATABASE MANAGER" --menu " " 20 78 10 "${database_manager_options[@]}" 3>&1 1>&2 2>&3)"

  exitstatus=$?
  if [[ ${exitstatus} -eq 0 ]]; then

    if [[ ${chosen_database_manager_option} == *"01"* ]]; then

      # LIST DATABASES
      database_list_options=("all prod stage test dev demo")

      chosen_database_list_option="$(whiptail --title "DATABASE MANAGER" --menu " " 20 78 10 $(for x in ${database_list_options}; do echo "$x [X]"; done) --default-item "all" 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then
          databases="$(mysql_list_databases "${chosen_database_list_option}")"
        else
          databases="$(postgres_list_databases "${chosen_database_list_option}")"
        fi

        display --indent 8 --text "Database:${databases}" --tcolor GREEN

      fi

    fi

    if [[ ${chosen_database_manager_option} == *"02"* ]]; then

      # CREATE DATABASE

      chosen_database_name="$(whiptail --title "DATABASE MANAGER" --inputbox "Insert the database name you want to create, example: my_domain_prod" 10 60 3>&1 1>&2 2>&3)"
      exitstatus=$?

      if [[ ${exitstatus} -eq 0 ]]; then

        if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then

          mysql_database_create "${chosen_database_name}"

        else

          postgres_database_create "${chosen_database_name}"

        fi

      fi

    fi

    if [[ ${chosen_database_manager_option} == *"03"* ]]; then

      # DELETE DATABASE

      # List databases
      if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then
        databases="$(mysql_list_databases "all")"
      else
        databases="$(postgres_list_databases "all")"
      fi

      chosen_database="$(whiptail --title "DATABASE MANAGER" --menu "Choose the database to delete" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) --default-item "${database}" 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then

          mysql_database_drop "${chosen_database}"

        else

          postgres_database_drop "${chosen_database}"

        fi

      fi

    fi

    if [[ ${chosen_database_manager_option} == "04" ]]; then

      # RENAME DATABASE

      # List databases
      if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then
        databases="$(mysql_list_databases "all")"
      else
        databases="$(postgres_list_databases "all")"
      fi
      chosen_database="$(whiptail --title "DATABASE MANAGER" --menu "Choose a database to delete" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) --default-item "${database}" 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        chosen_database_name="$(whiptail --title "DATABASE MANAGER" --inputbox "Insert the database name you want to create, example: my_domain_prod" 10 60 3>&1 1>&2 2>&3)"
        exitstatus=$?

        if [[ ${exitstatus} -eq 0 ]]; then

          if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then

            mysql_database_rename "${chosen_database}" "${chosen_database_name}"

          else

            postgres_database_rename "${chosen_database}" "${chosen_database_name}"

          fi

        fi

      fi

    fi

    if [[ ${chosen_database_manager_option} == *"05"* ]]; then

      # LIST USERS
      if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then
        mysql_list_users
      else
        postgres_list_users
      fi

    fi

    if [[ ${chosen_database_manager_option} == *"06"* ]]; then

      # CREATE USER DATABASE
      chosen_username="$(whiptail --title "DATABASE MANAGER" --inputbox "Insert the username you want to create, example: my_domain_user" 10 60 3>&1 1>&2 2>&3)"
      
      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        chosen_userpsw="$(whiptail --title "DATABASE MANAGER" --inputbox "Insert the user password (or leave it empty to create a random generate one):" 10 60 3>&1 1>&2 2>&3)"
        
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          if [[ -z ${chosen_userpsw} ]]; then
            # TODO: ask if user wants to create a random generated password or not
            chosen_userpsw="$(openssl rand -hex 12)"
          fi

          if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then

            mysql_user_create "${chosen_username}" "${chosen_userpsw}" "localhost"

          else

            postgres_user_create "${chosen_username}" "${chosen_userpsw}" "localhost"

          fi

        fi

      fi

    fi

    if [[ ${chosen_database_manager_option} == *"07"* ]]; then

      # DELETE USER

      # List users
      if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then
        database_users="$(mysql_list_users)"
      else
        database_users="$(postgres_list_users)"
      fi

      chosen_user="$(whiptail --title "DATABASE MANAGER" --menu "Choose the user you want to delete" 20 78 10 $(for x in ${database_users}; do echo "$x [U]"; done) 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then

          mysql_user_delete "${chosen_user}" "localhost"

        else

          postgres_user_delete "${chosen_user}" "localhost"

        fi

      fi

    fi

    if [[ ${chosen_database_manager_option} == *"08"* ]]; then

      # RESET MYSQL USER PASSWORD

      # List users
      if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then
        database_users="$(mysql_list_users)"
      else
        database_users="$(postgres_list_users)"
      fi

      chosen_user="$(whiptail --title "DATABASE MANAGER" --menu "Choose a user to work with" 20 78 10 $(for x in ${database_users}; do echo "$x [U]"; done) 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        new_user_psw="$(whiptail --title "MYSQL USER PASSWORD" --inputbox "Insert the new user password:" 10 60 3>&1 1>&2 2>&3)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then

            mysql_user_psw_change "${chosen_user}" "${new_user_psw}"

          else

            postgres_user_psw_change "${chosen_user}" "${new_user_psw}"

          fi

        fi

      fi

    fi

    if [[ ${chosen_database_manager_option} == *"09"* ]]; then

      # GRANT PRIVILEGES

      # List users
      if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then
        database_users="$(mysql_list_users)"
      else
        database_users="$(postgres_list_users)"
      fi

      chosen_user="$(whiptail --title "DATABASE MANAGER" --menu "Choose a user to work with" 20 78 10 $(for x in ${database_users}; do echo "$x [U]"; done) 3>&1 1>&2 2>&3)"

      exitstatus=$?
      if [[ ${exitstatus} -eq 0 ]]; then

        # List databases
        if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then
          databases="$(mysql_list_databases "all")"
        else
          databases="$(postgres_list_databases "all")"
        fi

        chosen_database="$(whiptail --title "DATABASE MANAGER" --menu "Choose the database to grant privileges" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) --default-item "${database}" 3>&1 1>&2 2>&3)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

          if [[ ${chosen_database_engine_options} == "MYSQL" ]]; then
            mysql_user_grant_privileges "${chosen_user}" "${chosen_database}" "localhost"
          else
            postgres_user_grant_privileges "${chosen_user}" "${chosen_database}" "localhost"
          fi

        fi

      fi

    fi

    prompt_return_or_finish
    database_manager_menu

  fi

  menu_main_options

}

################################################################################
# Task handler for database functions
#
# Arguments:
#  $1 = ${subtask}
#  $2 = ${dbname}
#  $3 = ${dbstage}
#  $4 = ${dbname_n}
#  $5 = ${dbuser}
#  $6 = ${dbuser_psw}
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

    mysql_list_users

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
