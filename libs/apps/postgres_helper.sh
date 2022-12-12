#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.3.0-beta
################################################################################
#
# Postgres Helper: Perform postgres actions.
#
################################################################################

################################################################################
# Ask root password and configure it on .my.cnf
#
# Arguments:
#  None
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_ask_root_psw() {

    local postgres_root_pass

    # Check Postgres credentials on .my.cnf
    if [[ ! -f ${MYSQL_CONF} ]]; then

        postgres_root_pass="$(whiptail --title "Postgres root password" --inputbox "Please insert the Postgres root password" 10 60 "${postgres_root_pass}" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            until mysql -u root -p"${postgres_root_pass}" -e ";"; do
                read -s -p " > Can't connect to Postgres, please re-enter ${MUSER} password: " postgres_root_pass

            done

            # Create new Postgres credentials file
            echo "[client]" >/root/.my.cnf
            echo "user=root" >>/root/.my.cnf
            echo "password=${postgres_root_pass}" >>/root/.my.cnf

            # Return
            echo "${postgres_root_pass}"

            return 0

        else

            return 1

        fi

    fi

}

################################################################################
# Ask database user scope
#
# Arguments:
#  ${1} = ${db_scope} - Optional
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_ask_user_db_scope() {

    local db_scope="${1}"

    db_scope="$(whiptail --title "Postgres User Scope" --inputbox "Set the scope for the database user. You can use '%' to accept all connections." 10 60 "${db_scope}" 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${db_scope}"

        return 0

    else
        return 1

    fi

}

################################################################################
# Ask database selection
#
# Arguments:
#  ${1} = ${db_scope} - Optional
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_ask_database_selection() {

    local databases
    local chosen_db

    databases="$(postgres_list_databases "all")"

    chosen_db="$(whiptail --title "POSTGRES DATABASES" --menu "Choose a Database to work with" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "debug" "Setting chosen_db=${chosen_db}"

        # Return
        echo "${chosen_db}"

        return 0

    else
        return 1
    fi

}

################################################################################
# Test user credentials
#
# Arguments:
#  ${1} = ${db_user}
#  ${2} = ${db_user_psw}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_test_user_credentials() {

    local db_user="${1}"
    local db_user_psw="${2}"

    local postgres_output
    local postgres_result

    # Execute command
    postgres_output="$("${POSTGRES}" -u "${db_user}" -p"${db_user_psw}" -e ";")"

    # Check result
    postgres_result=$?
    if [[ ${postgres_result} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Testing Postgres user credentials" --result "DONE" --color GREEN
        log_event "info" " Testing Postgres user credentials. User '${db_user}' and pass '${db_user_psw}'" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Testing Postgres user credentials" --result "FAIL" --color RED
        log_event "error" "Something went wrong testing Postgres user credentials. User '${db_user}' and pass '${db_user_psw}'" "false"
        log_event "debug" "Last command executed: ${POSTGRES} -u${db_user} -p${db_user_psw} -e ;" "false"

        return 1

    fi

}

################################################################################
# Count databases on Postgres
#
# Arguments:
#  ${1} = ${databases}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_count_databases() {

    local databases="${1}"

    local total_databases=0

    local db

    for db in ${databases}; do

        if [[ ${EXCLUDED_DATABASES_LIST} != *"${db}"* ]]; then # $EXCLUDED_DATABASES_LIST contains blacklisted databases
            total_databases=$((total_databases + 1))
        fi

    done

    # Return
    echo "${total_databases}"
}

################################################################################
# List databases on Postgres
#
# Arguments:
#  ${stage} - Options: all, prod, dev, test, stage
#
# Outputs:
#  ${databases}, 1 on error.
################################################################################

function postgres_list_databases() {

    local stage="${1}"

    local databases

    log_event "info" "Listing '${stage}' Postgres databases" "false"

    if [[ ${stage} == "all" ]]; then

        # Run command

        # List postgress databases
        databases="$(${PSQL_ROOT} -c "SELECT datname FROM pg_database WHERE datistemplate = false;" -t)"
        #databases="$(${PSQL_ROOT} -t -A -c "SELECT datname FROM pg_database WHERE datname <> ALL ('{template0,template1,postgres}')")"

    else

        # Run command
        databases="$(${PSQL_ROOT} -c "SELECT datname FROM pg_database WHERE datistemplate = false;" -t | grep "${stage}")"

    fi

    # Check result
    postgres_result=$?
    if [[ ${postgres_result} -eq 0 && ${databases} != "error" ]]; then

        # Replace all newlines with a space
        databases="${databases//$'\n'/ }"
        # Replace all strings \n with a space
        databases="${databases//\\n/ }"

        # Log
        display --indent 6 --text "- Listing Postgres databases" --result "DONE" --color GREEN
        log_event "info" "Listing Postgres databases: '${databases}'" "false"

        # Return
        echo "${databases}"

    else

        # Log
        display --indent 6 --text "- Listing Postgres databases" --result "FAIL" --color RED
        log_event "error" "Something went wrong listing Postgres databases" "false"
        log_event "debug" "Last command executed: ${PSQL_ROOT} -c \"SELECT datname FROM pg_database WHERE datistemplate = false;\" -t" "false"

        return 1

    fi

}

################################################################################
# List users on Postgres
#
# Arguments:
#  none
#
# Outputs:
#  ${users}, 1 on error.
################################################################################

function postgres_list_users() {

    local users

    # Run command
    # https://unix.stackexchange.com/questions/201666/command-to-list-postgresql-user-accounts
    users="$(${PSQL_ROOT} -c 'SELECT u.usename AS "User Name" FROM pg_catalog.pg_user u;' -t)"

    # Check result
    postgres_result=$?
    if [[ ${postgres_result} -eq 0 && ${users} != "error" ]]; then

        # Replace all newlines with a space
        users="${users//$'\n'/ }"
        # Replace all strings \n with a space
        users="${users//\\n/ }"

        # Log
        display --indent 6 --text "- Listing Postgres users" --result "DONE" --color GREEN
        log_event "info" " Listing Postgres users: '${users}'" "false"

        # Return
        echo "${users}"
        return 0

    else

        # Log
        display --indent 6 --text "- Listing Postgres users" --result "FAIL" --color RED
        log_event "error" "Something went wrong listing Postgres users" "false"
        log_event "debug" "Last command executed: ${PSQL_ROOT} -c 'SELECT u.usename AS \"User Name\" FROM pg_catalog.pg_user u;' -t" "false"

        return 1

    fi

}

################################################################################
# Create database user
#
# Arguments:
#  ${1} = ${db_user}
#  ${2} = ${db_user_psw}
#  ${3} = ${db_user_scope} - optional
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_user_create() {

    local db_user="${1}"
    local db_user_psw="${2}"
    #local db_user_scope="${3}"

    local query

    # Log
    display --indent 6 --text "- Creating Postgres user ${db_user}"

    # DB user host
    [[ -z ${db_user_scope} ]] && db_user_scope="$(postgres_ask_user_db_scope "localhost")"

    # Query
    #if [[ -z ${db_user_psw} ]]; then
    #    query="CREATE USER '${db_user}'@'${db_user_scope}';"
    #else
    query="CREATE USER '${db_user}' WITH PASSWORD '${db_user_psw}';"
    #fi

    # Execute command
    ${PSQL_ROOT} -c "${query}"

    # Check result
    postgres_result=$?
    if [[ ${postgres_result} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Creating Postgres user ${db_user}" --result "DONE" --color GREEN

        if [[ ${db_user_psw} != "" ]]; then
            display --indent 8 --text "User created with pass: ${db_user_psw}" --tcolor YELLOW
        fi

        log_event "info" "Postgres user ${db_user} created with pass: ${db_user_psw}" "false"

        return 0

    else

        # Log
        clear_previous_lines "2"
        display --indent 6 --text "- Creating Postgres user ${db_user}" --result "FAIL" --color RED
        display --indent 8 --text "Maybe the user already exists. Please read the log file." --tcolor RED

        log_event "error" "Something went wrong creating user: ${db_user}." "false"
        log_event "debug" "Postgres output: ${postgres_output}" "false"
        log_event "debug" "Last command executed: ${PSQL_ROOT} -c ${query}" "false"

        return 1

    fi

}

################################################################################
# Delete database user
#
# Arguments:
#  ${1} = ${db_user}
#  ${2} = ${db_user_scope} - optional
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_user_delete() {

    local db_user="${1}"
    local db_user_scope="${2}"

    local query_1
    local query_2

    # Log
    display --indent 6 --text "- Deleting user ${db_user}"
    log_event "info" "Deleting ${db_user} user in Postgres ..." "false"

    # DB user host
    [[ -z ${db_user_scope} ]] && db_user_scope="$(postgres_ask_user_db_scope "localhost")"

    # Query
    query_1="DROP USER '${db_user}'@'${db_user_scope}';"
    query_2="FLUSH PRIVILEGES;"

    # Execute command
    ${PSQL_ROOT} -e "${query_1}${query_2}"

    # Check result
    postgres_result=$?
    if [[ ${postgres_result} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        log_event "info" "Database user ${db_user} deleted" "false"
        log_event "debug" "Last command executed: ${PSQL_ROOT} -e \"${query_1}${query_2}\"" "false"
        display --indent 6 --text "- Deleting user ${db_user}" --result "DONE" --color GREEN

        return 0

    else

        # Log
        clear_previous_lines "1"
        log_event "error" "Something went wrong deleting user: ${db_user}." "false"
        log_event "debug" "Last command executed: ${PSQL_ROOT} -e \"${query_1}${query_2}\"" "false"
        display --indent 6 --text "- Deleting ${db_user} user in Postgres" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Change user password
#
# Arguments:
#  ${1} = ${db_user}
#  ${2} = ${db_user_psw}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_user_psw_change() {

    local db_user="${1}"
    local db_user_psw="${2}"

    local query_1
    local query_2

    log_event "info" "Changing password for user ${db_user} in Postgres" "false"

    # Query
    query_1="ALTER USER '${db_user}'@'localhost' IDENTIFIED BY '${db_user_psw}';"
    query_2="FLUSH PRIVILEGES;"

    # Execute command
    ${PSQL_ROOT} -e "${query_1}${query_2}"

    # Check result
    postgres_result=$?
    if [[ ${postgres_result} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Changing password to user ${db_user}" --result "DONE" --color GREEN
        display --indent 8 --text "New password: ${db_user_psw}" --result "DONE" --color GREEN
        log_event "info" "New password for user ${db_user}: ${db_user_psw}" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Changing password to user ${db_user}" --result "FAIL" --color RED
        log_event "error" "Something went wrong changing password to user ${db_user}." "false"
        log_event "debug" "Last command executed: ${PSQL_ROOT} -e \"${query_1}${query_2}\"" "false"

        return 1

    fi

}

################################################################################
# Change root password
#
# Arguments:
#  ${1} = ${db_user_psw}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_root_psw_change() {

    local db_root_psw="${1}"

    log_event "info" "Changing password for root in Postgres"

    # Kill any postgres processes currently running
    service postgres stop
    killall -vw postgres
    display --indent 2 --text "- Shutting down any postgres processes" --result "DONE" --color GREEN

    # Start postgres without grant tables
    mysqld_safe --skip-grant-tables >res 2>&1 &

    # Sleep for 5 while the new postgres process loads (if get a connection error you might need to increase this.)
    sleep 5

    # Creating new password if db_root_psw is empty
    if [[ "${db_root_psw}" == "" ]]; then
        db_root_psw_len=$(shuf -i 20-30 -n 1)
        db_root_psw=$(pwgen -scn "${db_root_psw_len}" 1)
        db_root_user='root'
    fi

    # Update root user with new password
    #mysql mysql -e "USE mysql;UPDATE user SET Password=PASSWORD('${db_root_psw}') WHERE User='${db_root_user}';FLUSH PRIVILEGES;"

    # Kill the insecure postgres process
    killall -v postgres

    # Starting postgres again
    service postgres restart

    # Check result
    postgres_result=$?
    if [[ ${postgres_result} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Setting new password for root" --result "DONE" --color GREEN
        display --indent 8 --text "New password: ${db_root_psw}"
        log_event "info" "New password for root: ${db_root_psw}" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Setting new password for root" --result "FAIL" --color RED
        log_event "error" "Something went wrong changing Postgres root password." "false"
        log_event "debug" "Last command executed: mysql mysql -e \"USE mysql;UPDATE user SET Password=PASSWORD('${db_root_psw}') WHERE User='${db_root_user}';FLUSH PRIVILEGES;\"" "false"

        return 1

    fi

}

################################################################################
# Grant privileges to user
#
# Arguments:
#  ${1} = ${db_user}
#  ${2} = ${db_target}
#  ${3} = ${db_scope}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_user_grant_privileges() {

    local db_user="${1}"
    local db_target="${2}"
    local db_scope="${3}"

    local query_1
    local query_2

    local postgres_output
    local postgres_result

    # Log
    display --indent 6 --text "- Granting privileges to ${db_user}"

    # DB user host
    [[ -z ${db_scope} ]] && db_scope="$(postgres_ask_user_db_scope "localhost")"

    # Query
    query_1="GRANT ALL PRIVILEGES ON ${db_target}.* TO '${db_user}'@'${db_scope}';"
    query_2="FLUSH PRIVILEGES;"

    # Execute command
    ${PSQL_ROOT} -c "${query_1}${query_2}"

    # Check result
    postgres_result=$?
    if [[ ${postgres_result} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        log_event "info" "Privileges granted to user ${db_user}" "false"
        log_event "debug" "Last command executed: ${PSQL_ROOT} -e \"${query_1}${query_2}\"" "false"
        display --indent 6 --text "- Granting privileges to ${db_user}" --result "DONE" --color GREEN

        return 0

    else

        # Log
        clear_previous_lines "1"
        log_event "error" "Something went wrong granting privileges to user ${db_user}." "false"
        log_event "debug" "Last command executed: ${PSQL_ROOT} -e \"${query_1}${query_2}\"" "false"
        display --indent 6 --text "- Granting privileges to ${db_user}" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Check if user exists
#
# Arguments:
#  ${1} = ${db_user}
#
# Outputs:
#  0 if user exists, 1 if not.
################################################################################

function postgres_user_exists() {

    local db_user="${1}"

    local query
    local user_exists

    query="SELECT COUNT(*) FROM mysql.user WHERE user = '${db_user}';"

    user_exists="$(${PSQL_ROOT} -e "${query}" | grep 1)"

    log_event "debug" "Last command executed: ${PSQL_ROOT} -e ${query} | grep 1" "false"

    if [[ ${user_exists} == "" ]]; then
        # Return 0 if user don't exists
        return 0
    else
        # Return 1 if user already exists
        return 1
    fi

}

################################################################################
# Check if database exists
#
# Arguments:
#  ${1} = ${db_user}
#
# Outputs:
#  0 if database exists, 1 if not.
################################################################################

function postgres_database_exists() {

    local database="${1}"

    local result

    # Run command
    result="$(${PSQL_ROOT} -e "SHOW DATABASES LIKE '${database}';")"

    if [[ -z ${result} ]]; then
        # Return 1 if database don't exists
        return 1

    else
        # Return 0 if database exists
        return 0
    fi

}

################################################################################
# Sanitize database name or username
#
# Arguments:
#  ${1} = ${string}
#
# Outputs:
#  Sanetized ${string}.
################################################################################

function postgres_name_sanitize() {

    local string="${1}"

    local clean

    #log_event "debug" "Running postgres_name_sanitize for ${string}" "true"

    # First, strip "-"
    clean=${string//-/}

    # Next, replace "." with "_"
    clean=${clean//./_}

    # Now, clean out anything that's not alphanumeric or an underscore
    clean=${clean//[^a-zA-Z0-9_]/}

    # Finally, lowercase with TR
    clean="$(echo -n "${clean}" | tr A-Z a-z)"

    #log_event "debug" "Sanitized name: ${clean}" "true"

    # Return
    echo "${clean}"

}

################################################################################
# Create database
#
# Arguments:
#  ${1} = ${database}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_database_create() {

    local database="${1}"

    local query_1

    local postgres_output
    local postgres_result

    log_event "info" "Creating ${database} database in Postgres ..." "false"

    # Query
    query_1="CREATE DATABASE ${database};"

    # Execute command
    ${PSQL_ROOT} -c "${query_1}"

    # Check result
    postgres_result=$?
    if [[ ${postgres_result} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Creating database: ${database}" --result "DONE" --color GREEN
        log_event "info" "Database ${database} created" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Creating database: ${database}" --result "ERROR" --color RED
        log_event "error" "Something went wrong creating database: ${database}." "false"
        log_event "debug" "Last command executed: ${PSQL_ROOT} -c \"${query_1}\"" "false"

        return 1

    fi

}

################################################################################
# Delete database
#
# Arguments:
#  ${1} = ${database}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_database_drop() {

    local database="${1}"

    local query_1
    local postgres_result

    log_event "info" "Droping database: ${database}" "false"

    # Query
    query_1="DROP DATABASE ${database};"

    # Execute command
    ${PSQL_ROOT} -c "${query_1}"

    # Check result
    postgres_result=$?
    if [[ ${postgres_result} -eq 0 ]]; then

        # Log
        log_event "info" "Database ${database} dropped successfully" "false"
        display --indent 6 --text "- Dropping database: ${database}" --result "DONE" --color GREEN

        return 0

    else

        # Log
        display --indent 6 --text "- Dropping database: ${database}" --result "ERROR" --color RED
        display --indent 8 --text "Please, read the log file!" --tcolor RED

        log_event "error" "Something went wrong dropping the database: ${database}" "false"
        log_event "debug" "Last command executed: ${PSQL_ROOT} -e \"${query_1}\"" "false"

        return 1

    fi

}

################################################################################
# Database import
#
# Arguments:
#  ${1} = ${database} (.sql)
#  ${2} = ${dump_file}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_database_import() {

    local database="${1}"
    local dump_file="${2}"

    local import_status

    # Log
    display --indent 6 --text "- Importing into database: ${database}" --tcolor YELLOW
    log_event "info" "Importing dump file ${dump_file} into database: ${database}" "false"

    # Execute command
    ${PSQL_ROOT} "${database}" <"${dump_file}"
    #pv --width 70 "${dump_file}" | ${PSQL_ROOT} -f -D "${database}"

    # Check result
    import_status=$?
    if [[ ${import_status} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Database backup import" --result "DONE" --color GREEN
        log_event "info" "Database ${database} imported successfully" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Database backup import" --result "ERROR" --color RED
        display --indent 8 --text "Please, read the log file!" --tcolor RED
        log_event "error" "Something went wrong importing database: ${database}"
        log_event "debug" "Last command executed: pv ${dump_file} | ${PSQL_ROOT} -f -D ${database}"

        return 1

    fi

}

################################################################################
# Database export
#
# Arguments:
#  ${1} = ${database}
#  ${2} = ${dump_file}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_database_export() {

    local database="${1}"
    local dump_file="${2}"

    local dump_status

    log_event "info" "Making a database backup of: ${database}" "false"

    spinner_start "- Making a backup of: ${database}"

    # Run pg_dump
    ${PSQLDUMP_ROOT} "${database}" >"${dump_file}"

    dump_status=$?
    spinner_stop "${dump_status}"

    # Check dump result
    if [[ ${dump_status} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Database backup for ${YELLOW}${database}${ENDCOLOR}" --result "DONE" --color GREEN
        log_event "info" "Database ${database} exported successfully" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Database backup for ${YELLOW}${database}${ENDCOLOR}" --result "ERROR" --color RED
        display --indent 8 --text "Please, read the log file!" --tcolor RED
        log_event "error" "Something went wrong exporting database: ${database}." "false"
        log_event "error" "Last command executed: ${PSQLDUMP_ROOT} ${database} > ${dump_file}" "false"

        return 1

    fi

}

################################################################################
# Database rename
#
# Arguments:
#  ${1} = ${database_old_name}
#  ${2} = ${database_new_name}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function postgres_database_rename() {

    local database_old_name="${1}"
    local database_new_name="${2}"

    local dump_file="${BROLIT_TMP_DIR}/${database_old_name}_bk_before_rename_db.sql"

    postgres_database_export "${database_old_name}" "${dump_file}"

    postgres_database_create "${database_new_name}"

    postgres_database_import "${database_new_name}" "${dump_file}"

    postgres_database_drop "${database_old_name}"

}

# TO-CHECK
function postgres_database_clone() {

    local database_old_name="${1}"
    local database_new_name="${2}"

    local dump_file="${BROLIT_TMP_DIR}/${database_old_name}_bk_before_clone_db.sql"

    postgres_database_export "${database_old_name}" "${dump_file}"

    postgres_database_create "${database_new_name}"

    postgres_database_import "${database_new_name}" "${dump_file}"

}
