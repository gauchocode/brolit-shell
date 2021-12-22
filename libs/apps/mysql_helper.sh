#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.7
################################################################################
#
# MySQL Helper: Perform mysql actions.
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

function mysql_ask_root_psw() {

    local mysql_root_pass

    # Check MySQL credentials on .my.cnf
    if [[ ! -f ${MYSQL_CONF} ]]; then

        mysql_root_pass="$(whiptail --title "MySQL root password" --inputbox "Please insert the MySQL root password" 10 60 "${mysql_root_pass}" 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            until mysql -u root -p"${mysql_root_pass}" -e ";"; do
                read -s -p " > Can't connect to MySQL, please re-enter ${MUSER} password: " mysql_root_pass

            done

            # Create new MySQL credentials file
            echo "[client]" >/root/.my.cnf
            echo "user=root" >>/root/.my.cnf
            echo "password=${mysql_root_pass}" >>/root/.my.cnf

            # Return
            echo "${mysql_root_pass}"

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
#  $1 = ${db_scope} - Optional
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_ask_user_db_scope() {

    local db_scope=$1

    db_scope="$(whiptail --title "MySQL User Scope" --inputbox "Set the scope for the database user. You can use '%' to accept all connections." 10 60 "${db_scope}" 3>&1 1>&2 2>&3)"
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
#  $1 = ${db_scope} - Optional
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_ask_database_selection() {

    local databases
    local chosen_db

    databases="$(mysql_list_databases "all")"

    chosen_db="$(whiptail --title "MYSQL DATABASES" --menu "Choose a Database to work with" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) 3>&1 1>&2 2>&3)"

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
#  $1 = ${db_user}
#  $2 = ${db_user_psw}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_test_user_credentials() {

    local db_user=$1
    local db_user_psw=$2

    local mysql_output
    local mysql_result

    # Execute command
    mysql_output="$("${MYSQL}" -u "${db_user}" -p"${db_user_psw}" -e ";")"

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Testing MySQL user credentials" --result "DONE" --color GREEN
        log_event "info" " Testing MySQL user credentials. User '${db_user}' and pass '${db_user_psw}'" "false"

        return 0

    else

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Testing MySQL user credentials" --result "FAIL" --color RED
        log_event "error" "Something went wrong testing MySQL user credentials. User '${db_user}' and pass '${db_user_psw}'" "false"
        log_event "debug" "Last command executed: ${MYSQL} -u${db_user} -p${db_user_psw} -e ;" "false"

        return 1

    fi

}

################################################################################
# Count databases on MySQL
#
# Arguments:
#  $1 = ${databases}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_count_databases() {

    local databases=$1

    local total_databases=0

    local db

    for db in ${databases}; do
        if [[ $BLACKLISTED_DATABASES != *"${db}"* ]]; then # $BLACKLISTED_DATABASES contains blacklisted databases
            total_databases=$((total_databases + 1))
        fi
    done

    # Return
    echo "${total_databases}"
}

################################################################################
# List databases on MySQL
#
# Arguments:
#  ${stage} - Options: all, prod, dev, test, stage
#
# Outputs:
#  ${databases}, 1 on error.
################################################################################

function mysql_list_databases() {

    local stage=$1

    local databases

    if [[ ${stage} == "all" ]]; then

        # Run command
        databases="$(${MYSQL_ROOT} -Bse 'show databases')"

    else

        # Run command
        databases="$(${MYSQL_ROOT} -Bse 'show databases' | grep "${stage}")"

    fi

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 && ${databases} != "error" ]]; then

        # Replace all newlines with a space
        databases="${databases//$'\n'/ }"
        # Replace all strings \n with a space
        databases="${databases//\\n/ }"

        # Log
        display --indent 6 --text "- Listing MySQL databases" --result "DONE" --color GREEN
        log_event "info" "Listing MySQL databases: '${databases}'" "false"

        # Return
        echo "${databases}"

    else

        # Log
        display --indent 6 --text "- Listing MySQL databases" --result "FAIL" --color RED
        log_event "error" "Something went wrong listing MySQL databases" "false"
        log_event "debug" "Last command executed: ${MYSQL_ROOT} -Bse 'show databases'" "false"

        return 1

    fi

}

################################################################################
# List users on MySQL
#
# Arguments:
#  none
#
# Outputs:
#  ${users}, 1 on error.
################################################################################

function mysql_list_users() {

    local users

    # Run command
    users="$(${MYSQL_ROOT} -e 'SELECT user FROM mysql.user;')"

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 && ${users} != "error" ]]; then

        # Replace all newlines with a space
        users="${users//$'\n'/ }"
        # Replace all strings \n with a space
        users="${users//\\n/ }"

        # Log
        display --indent 6 --text "- Listing MySQL users" --result "DONE" --color GREEN
        log_event "info" " Listing MySQL users: '${users}'" "false"

        # Return
        echo "${users}"
        return 0

    else

        # Log
        display --indent 6 --text "- Listing MySQL users" --result "FAIL" --color RED
        log_event "error" "Something went wrong listing MySQL users" "false"
        log_event "debug" "Last command executed: ${MYSQL_ROOT} -e SELECT user FROM mysql.user;'" "false"

        return 1

    fi

}

################################################################################
# Create database user
#
# Arguments:
#  $1 = ${db_user}
#  $2 = ${db_user_psw}
#  $3 = ${db_user_scope} - optional
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_user_create() {

    local db_user=$1
    local db_user_psw=$2
    local db_user_scope=$3

    local query

    # Log
    display --indent 6 --text "- Creating MySQL user ${db_user}"

    # DB user host
    if [[ -z ${db_user_scope} ]]; then
        db_user_scope="$(mysql_ask_user_db_scope "localhost")"
    fi

    # Query
    if [[ -z ${db_user_psw} ]]; then
        query="CREATE USER '${db_user}'@'${db_user_scope}';"

    else
        query="CREATE USER '${db_user}'@'${db_user_scope}' IDENTIFIED BY '${db_user_psw}';"

    fi

    # Execute command
    ${MYSQL_ROOT} -e "${query}"

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Creating MySQL user ${db_user}" --result "DONE" --color GREEN

        if [[ ${db_user_psw} != "" ]]; then
            display --indent 8 --text "User created with pass: ${db_user_psw}" --tcolor YELLOW
        fi

        log_event "info" "MySQL user ${db_user} created with pass: ${db_user_psw}" "false"

        return 0

    else

        # Log
        clear_previous_lines "2"
        display --indent 6 --text "- Creating MySQL user ${db_user}" --result "FAIL" --color RED
        display --indent 8 --text "Maybe the user already exists. Please read the log file." --tcolor RED

        log_event "error" "Something went wrong creating user: ${db_user}." "false"
        log_event "debug" "MySQL output: ${mysql_output}" "false"
        log_event "debug" "Last command executed: ${MYSQL_ROOT} -e ${query}" "false"

        return 1

    fi

}

################################################################################
# Delete database user
#
# Arguments:
#  $1 = ${db_user}
#  $2 = ${db_user_scope} - optional
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_user_delete() {

    local db_user=$1
    local db_user_scope=$2

    local query_1
    local query_2

    # Log
    display --indent 6 --text "- Deleting user ${db_user}"
    log_event "info" "Deleting ${db_user} user in MySQL ..."

    # DB user host
    if [[ -z ${db_user_scope} || ${db_user_scope} == "" ]]; then
        db_user_scope="$(mysql_ask_user_db_scope "localhost")"
    fi

    # Query
    query_1="DROP USER '${db_user}'@'${db_user_scope}';"
    query_2="FLUSH PRIVILEGES;"

    # Execute command
    ${MYSQL_ROOT} -e "${query_1}${query_2}"

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        log_event "info" " Database user ${db_user} deleted" "false"
        log_event "debug" "Last command executed: ${MYSQL_ROOT} -e \"${query_1}${query_2}\"" "false"
        display --indent 6 --text "- Deleting user ${db_user}" --result "DONE" --color GREEN

        return 0

    else

        # Log
        clear_previous_lines "1"
        log_event "error" "Something went wrong deleting user: ${db_user}." "false"
        log_event "debug" "Last command executed: ${MYSQL_ROOT} -e \"${query_1}${query_2}\"" "false"
        display --indent 6 --text "- Deleting ${db_user} user in MySQL" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Change user password
#
# Arguments:
#  $1 = ${db_user}
#  $2 = ${db_user_psw}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_user_psw_change() {

    local db_user=$1
    local db_user_psw=$2

    local query_1
    local query_2

    log_event "info" "Changing password for user ${db_user} in MySQL" "false"

    # Query
    query_1="ALTER USER '${db_user}'@'localhost' IDENTIFIED BY '${db_user_psw}';"
    query_2="FLUSH PRIVILEGES;"

    # Execute command
    ${MYSQL_ROOT} -e "${query_1}${query_2}"

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Changing password to user ${db_user}" --result "DONE" --color GREEN
        display --indent 8 --text "New password: ${db_user_psw}" --result "DONE" --color GREEN
        log_event "info" "New password for user ${db_user}: ${db_user_psw}" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Changing password to user ${db_user}" --result "FAIL" --color RED
        log_event "error" "Something went wrong changing password to user ${db_user}." "false"
        log_event "debug" "Last command executed: ${MYSQL_ROOT} -e \"${query_1}${query_2}\"" "false"

        return 1

    fi

}

################################################################################
# Change root password
#
# Arguments:
#  $1 = ${db_user_psw}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_root_psw_change() {

    local db_root_psw=$1

    log_event "info" "Changing password for root in MySQL"

    # Kill any mysql processes currently running
    service mysql stop
    killall -vw mysqld
    display --indent 2 --text "- Shutting down any mysql processes" --result "DONE" --color GREEN

    # Start mysql without grant tables
    mysqld_safe --skip-grant-tables >res 2>&1 &

    # Sleep for 5 while the new mysql process loads (if get a connection error you might need to increase this.)
    sleep 5

    # Creating new password if db_root_psw is empty
    if [[ "${db_root_psw}" == "" ]]; then
        db_root_psw_len=$(shuf -i 20-30 -n 1)
        db_root_psw=$(pwgen -scn "${db_root_psw_len}" 1)
        db_root_user='root'
    fi

    # Update root user with new password
    mysql mysql -e "USE mysql;UPDATE user SET Password=PASSWORD('${db_root_psw}') WHERE User='${db_root_user}';FLUSH PRIVILEGES;"

    # Kill the insecure mysql process
    killall -v mysqld

    # Starting mysql again
    service mysql restart

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Setting new password for root" --result "DONE" --color GREEN
        display --indent 8 --text "New password: ${db_root_psw}"
        log_event "info" "New password for root: ${db_root_psw}" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Setting new password for root" --result "FAIL" --color RED
        log_event "error" "Something went wrong changing MySQL root password." "false"
        log_event "debug" "Last command executed: mysql mysql -e \"USE mysql;UPDATE user SET Password=PASSWORD('${db_root_psw}') WHERE User='${db_root_user}';FLUSH PRIVILEGES;\"" "false"

        return 1

    fi

}

################################################################################
# Grant privileges to user
#
# Arguments:
#  $1 = ${db_user}
#  $2 = ${db_target}
#  $3 = ${db_scope}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_user_grant_privileges() {

    local db_user=$1
    local db_target=$2
    local db_scope=$3

    local query_1
    local query_2

    local mysql_output
    local mysql_result

    # Log
    display --indent 6 --text "- Granting privileges to ${db_user}"

    # DB user host
    if [[ ${db_scope} == "" ]]; then
        db_scope="$(mysql_ask_user_db_scope "localhost")"
    fi

    # Query
    query_1="GRANT ALL PRIVILEGES ON ${db_target}.* TO '${db_user}'@'${db_scope}';"
    query_2="FLUSH PRIVILEGES;"

    # Execute command
    ${MYSQL_ROOT} -e "${query_1}${query_2}"

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        log_event "info" "Privileges granted to user ${db_user}" "false"
        log_event "debug" "Last command executed: ${MYSQL_ROOT} -e \"${query_1}${query_2}\"" "false"
        display --indent 6 --text "- Granting privileges to ${db_user}" --result "DONE" --color GREEN

        return 0

    else

        # Log
        clear_previous_lines "1"
        log_event "error" "Something went wrong granting privileges to user ${db_user}." "false"
        log_event "debug" "Last command executed: ${MYSQL_ROOT} -e \"${query_1}${query_2}\"" "false"
        display --indent 6 --text "- Granting privileges to ${db_user}" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Check if user exists
#
# Arguments:
#  $1 = ${db_user}
#
# Outputs:
#  0 if user exists, 1 if not.
################################################################################

function mysql_user_exists() {

    local db_user=$1

    local query
    local user_exists

    query="SELECT COUNT(*) FROM mysql.user WHERE user = '${db_user}';"

    user_exists="$(${MYSQL_ROOT} -e "${query}" | grep 1)"

    log_event "debug" "Last command executed: ${MYSQL_ROOT} -e ${query} | grep 1" "false"

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
#  $1 = ${db_user}
#
# Outputs:
#  0 if database exists, 1 if not.
################################################################################

function mysql_database_exists() {

    local database=$1

    local result

    # Run command
    result="$(${MYSQL_ROOT} -e "SHOW DATABASES LIKE '${database}';")"

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
#  $1 = ${string}
#
# Outputs:
#  Sanetized ${string}.
################################################################################

function mysql_name_sanitize() {

    local string=$1

    local clean

    #log_event "debug" "Running mysql_name_sanitize for ${string}" "true"

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
#  $1 = ${database}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_database_create() {

    local database=$1

    local query_1

    local mysql_output
    local mysql_result

    log_event "info" "Creating ${database} database in MySQL ..." "false"

    # Query
    query_1="CREATE DATABASE IF NOT EXISTS ${database};"

    # Execute command
    ${MYSQL_ROOT} -e "${query_1}"

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Creating database: ${database}" --result "DONE" --color GREEN
        log_event "info" "Database ${database} created" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Creating database: ${database}" --result "ERROR" --color RED
        log_event "error" "Something went wrong creating database: ${database}." "false"
        log_event "debug" "Last command executed: ${MYSQL_ROOT} -e \"${query_1}\"" "false"

        return 1

    fi

}

################################################################################
# Delete database
#
# Arguments:
#  $1 = ${database}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_database_drop() {

    local database=$1

    local query_1
    local mysql_result

    log_event "info" "Droping the database: ${database}"

    # Query
    query_1="DROP DATABASE ${database};"

    # Execute command
    ${MYSQL_ROOT} -e "${query_1}"

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 ]]; then

        # Log
        log_event "info" "- Database ${database} dropped successfully" "false"
        display --indent 6 --text "- Dropping database: ${database}" --result "DONE" --color GREEN

        return 0

    else

        # Log
        display --indent 6 --text "- Dropping database: ${database}" --result "ERROR" --color RED
        display --indent 8 --text "Please, read the log file!" --tcolor RED

        log_event "error" "Something went wrong dropping the database: ${database}" "false"
        log_event "debug" "Last command executed: ${MYSQL_ROOT} -e \"${query_1}\"" "false"

        return 1

    fi

}

################################################################################
# Database import
#
# Arguments:
#  $1 = ${database} (.sql)
#  $2 = ${dump_file}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_database_import() {

    local database=$1
    local dump_file=$2

    local import_status

    # Log
    display --indent 6 --text "- Importing backup into database: ${database}" --tcolor YELLOW
    log_event "info" "Importing dump file ${dump_file} into database: ${database}" "false"
    log_event "debug" "Running: pv ${dump_file} | ${MYSQL_ROOT} -f -D ${database}" "false"

    # String “utf8mb4_0900_ai_ci” replaced it with “utf8mb4_general_ci“
    # This is a workaround for a bug in MySQL 5.7.x and 5.6.x where the default collation is “utf8mb4_0900_ai_ci”.
    sed -i 's/utf8mb4_0900_ai_ci/utf8mb4_general_ci/g' "${dump_file}"

    # Execute command
    pv --width 70 "${dump_file}" | ${MYSQL_ROOT} -f -D "${database}"

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
        log_event "debug" "Last command executed: pv ${dump_file} | ${MYSQL_ROOT} -f -D ${database}"

        return 1

    fi

}

################################################################################
# Database export
#
# Arguments:
#  $1 = ${database}
#  $2 = ${dump_file}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_database_export() {

    local database=$1
    local dump_file=$2

    local dump_status

    log_event "info" "Making a database backup of: ${database}" "false"

    spinner_start "- Making a backup of: ${database}"

    # Run mysqldump
    ${MYSQLDUMP_ROOT} "${database}" >"${dump_file}"

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
        log_event "error" "Last command executed: ${MYSQLDUMP_ROOT} ${database} > ${dump_file}" "false"

        return 1

    fi

}

################################################################################
# Database rename
#
# Arguments:
#  $1 = ${database_old_name}
#  $2 = ${database_new_name}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_database_rename() {

    local database_old_name=$1
    local database_new_name=$2

    local dump_file="${TMP_DIR}/${database_old_name}_bk_before_rename_db.sql"

    mysql_database_export "${database_old_name}" "${dump_file}"

    mysql_database_create "${database_new_name}"

    mysql_database_import "${database_new_name}" "${dump_file}"

    mysql_database_drop "${database_old_name}"

}

# TO-CHECK
function mysql_database_clone() {

    local database_old_name=$1
    local database_new_name=$2

    local dump_file="${TMP_DIR}/${database_old_name}_bk_before_clone_db.sql"

    mysql_database_export "${database_old_name}" "${dump_file}"

    mysql_database_create "${database_new_name}"

    mysql_database_import "${database_new_name}" "${dump_file}"

}