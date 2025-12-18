#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.4
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

        mysql_root_pass="$(whiptail_input "MySQL root password" "Please insert the MySQL root password" "${mysql_root_pass}")"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            until mysql -u root -p"${mysql_root_pass}" -e ";"; do
                read -r -s -p " > Can't connect to MySQL, please re-enter ${MUSER} password: " mysql_root_pass

            done

            # Create new MySQL credentials file
            echo "[client]" >/root/.my.cnf
            echo "user=root" >>/root/.my.cnf
            echo "password=${mysql_root_pass}" >>/root/.my.cnf

            # Return
            echo "${mysql_root_pass}" && return 0

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

function mysql_ask_user_db_scope() {

    local db_scope="${1}"

    db_scope="$(whiptail_input "MySQL User Scope" "Set the scope for the database user. You can use '%' to accept all connections." "${db_scope}")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${db_scope}" && return 0

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

function mysql_ask_database_selection() {

    local databases
    local chosen_database

    # List databases
    databases="$(mysql_list_databases "all" "")"

    # Database selection menu
    chosen_database="$(whiptail --title "MYSQL Databases" --menu "Choose a Database to work with" 20 78 10 $(for x in ${databases}; do echo "$x [DB]"; done) 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        log_event "debug" "Setting chosen_db=${chosen_database}"

        # Return
        echo "${chosen_database}" && return 0

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

function mysql_test_user_credentials() {

    local db_user="${1}"
    local db_user_psw="${2}"

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
#  ${1} = ${databases}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_count_databases() {

    local databases="${1}"

    local db
    local total_databases=0

    for db in ${databases}; do
        if [[ $EXCLUDED_DATABASES_LIST != *"${db}"* ]]; then # $EXCLUDED_DATABASES_LIST contains blacklisted databases
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
#  ${1} = ${stage}          - Options: all, prod, dev, test, stage
#  ${2} = ${container_name} - Optional
#
# Outputs:
#  ${databases}, 1 on error.
################################################################################

function mysql_list_databases() {

    local stage="${1}"
    local container_name="${2}"

    local mysql_exec
    local databases

    if [[ -n ${container_name} && ${container_name} != "false" ]]; then

        local mysql_container_user
        local mysql_container_user_pssw

        # Get MYSQL_USER and MYSQL_PASSWORD from container
        ## Ref: https://www.baeldung.com/ops/docker-get-environment-variable
        mysql_container_user="$(docker exec -i "${container_name}" printenv MYSQL_USER)"
        mysql_container_user_pssw="$(docker exec -i "${container_name}" printenv MYSQL_PASSWORD)"

        mysql_exec="docker exec -i ${container_name} mysql -u${mysql_container_user} -p${mysql_container_user_pssw}"

    else

        mysql_exec="${MYSQL_ROOT}"

    fi

    log_event "info" "Listing '${stage}' MySQL databases" "false"

    if [[ ${stage} == "all" ]]; then
        # Run command and filter out system databases
        databases="$(${mysql_exec} -Bse 'show databases' | grep -Ev '^(information_schema|performance_schema|mysql|sys)$')"
    else
        # Run command and filter out system databases
        databases="$(${mysql_exec} -Bse 'show databases' | grep -Ev '^(information_schema|performance_schema|mysql|sys)$' | grep "${stage}")"
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
        log_event "debug" "Last command executed: ${mysql_exec} -Bse 'show databases'" "false"

        return 1

    fi

}

################################################################################
# List users on MySQL
#
# Arguments:
#  ${1} = ${container_name}
#
# Outputs:
#  ${users}, 1 on error.
################################################################################

function mysql_users_list() {

    local container_name="${1}"

    local users
    local mysql_exec

    if [[ -n ${container_name} && ${container_name} != "false" ]]; then

        local mysql_container_user
        local mysql_container_user_pssw

        # Get MYSQL_USER and MYSQL_PASSWORD from container
        ## Ref: https://www.baeldung.com/ops/docker-get-environment-variable
        mysql_container_user="$(docker exec -i "${container_name}" printenv MYSQL_USER)"
        mysql_container_user_pssw="$(docker exec -i "${container_name}" printenv MYSQL_PASSWORD)"

        mysql_exec="docker exec -i ${container_name} mysql -u${mysql_container_user} -p${mysql_container_user_pssw}"

    else

        mysql_exec="${MYSQL_ROOT}"

    fi

    # Run command
    users="$(${mysql_exec} -e 'SELECT user FROM mysql.user;')"

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
        log_event "debug" "Last command executed: ${mysql_exec} -e SELECT user FROM mysql.user;'" "false"

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

function mysql_user_create() {

    local db_user="${1}"
    local db_user_psw="${2}"
    local db_user_scope="${3}"

    local query

    # Log
    display --indent 6 --text "- Creating MySQL user: ${db_user}"

    # DB user host
    [[ -z ${db_user_scope} ]] && db_user_scope="$(mysql_ask_user_db_scope "localhost")"

    # Query
    if [[ -z ${db_user_psw} ]]; then
        query="CREATE USER '${db_user}'@'${db_user_scope}';"

    else
        query="CREATE USER '${db_user}'@'${db_user_scope}' IDENTIFIED BY '${db_user_psw}';"

    fi

    # Execute mysql query
    ${MYSQL_ROOT} -e "${query}"

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 ]]; then

        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Creating MySQL user: ${db_user}" --result "DONE" --color GREEN

        if [[ -n ${db_user_psw} ]]; then
            display --indent 8 --text "User created with pass: ${db_user_psw}" --tcolor YELLOW
        fi

        log_event "info" "MySQL user ${db_user} created with pass: ${db_user_psw}" "false"

        return 0

    else

        # Log
        clear_previous_lines "2"
        display --indent 6 --text "- Creating MySQL user: ${db_user}" --result "FAIL" --color RED
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
#  ${1} = ${db_user}
#  ${2} = ${db_user_scope} - optional
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_user_delete() {

    local db_user="${1}"
    local db_user_scope="${2}"

    local query_1
    local query_2

    # Log
    display --indent 6 --text "- Deleting user ${db_user} in MySQL"
    log_event "info" "Deleting ${db_user} user in MySQL ..." "false"

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
        clear_previous_lines "2"
        log_event "info" "Database user ${db_user} deleted" "false"
        log_event "debug" "Last command executed: ${MYSQL_ROOT} -e \"${query_1}${query_2}\"" "false"
        display --indent 6 --text "- Deleting user ${db_user}" --result "DONE" --color GREEN

        return 0

    else

        # Log
        clear_previous_lines "2"
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
#  ${1} = ${db_user}
#  ${2} = ${db_user_psw}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_user_psw_change() {

    local db_user="${1}"
    local db_user_psw="${2}"

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
# Change mysql root password
#
# Arguments:
#  ${1} = ${db_user_psw}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_root_psw_change() {

    local db_root_psw="${1}"

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

    # Log the output
    display --indent 2 --text "- Setting new password for root" --tcolor YELLOW

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
#  ${1} = ${db_user}
#  ${2} = ${db_target}
#  ${3} = ${db_scope}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_user_grant_privileges() {

    local db_user="${1}"
    local db_target="${2}"
    local db_scope="${3}"

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
#  ${1} = ${db_user}
#
# Outputs:
#  0 if user exists, 1 if not.
################################################################################

function mysql_user_exists() {

    local db_user="${1}"

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
#  ${1} = ${db_user}
#
# Outputs:
#  0 if database exists, 1 if not.
################################################################################

function mysql_database_exists() {

    local database="${1}"

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
#  ${1} = ${string}
#
# Outputs:
#  Sanetized ${string}.
################################################################################

function database_name_sanitize() {

    local string="${1}"

    local clean

    #log_event "debug" "Running database_name_sanitize for ${string}" "true"

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

function mysql_database_create() {

    local database="${1}"

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
#  ${1} = ${database}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_database_drop() {

    local database="${1}"

    local query_1
    local mysql_result

    log_event "info" "Droping the database: ${database}"

    # Query
    query_1="DROP DATABASE ${database};"

    # Execute command
    ${MYSQL_ROOT} -e "${query_1}"

    mysql_result=$?
    if [[ ${mysql_result} -eq 0 ]]; then

        # Log
        log_event "info" "Database ${database} dropped successfully" "false"
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
#  ${1} = ${database} (.sql)
#  ${2} = ${container_name}
#  ${3} = ${dump_file}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_database_import() {

    local database="${1}"
    local container_name="${2}"
    local dump_file="${3}"

    local mysql_exec

    if [[ -n ${container_name} && ${container_name} != "false" ]]; then

        local mysql_container_user
        local mysql_container_user_pssw

        # Get MYSQL_USER and MYSQL_PASSWORD from container
        ## Ref: https://www.baeldung.com/ops/docker-get-environment-variable
        mysql_container_user="$(docker exec -i "${container_name}" printenv MYSQL_USER)"
        mysql_container_user_pssw="$(docker exec -i "${container_name}" printenv MYSQL_PASSWORD)"

        mysql_exec="docker exec -i ${container_name} mysql -u${mysql_container_user} -p${mysql_container_user_pssw} -f -D ${database}"

    else

        mysql_exec="${MYSQL_ROOT} -f -D ${database}"

    fi

    # Log
    display --indent 6 --text "- Importing backup into: ${database}" --tcolor YELLOW
    log_event "info" "Importing dump file ${dump_file} into database: ${database}" "false"
    log_event "debug" "Running: pv ${dump_file} | ${mysql_exec}" "false"

    # String "utf8mb4_0900_ai_ci" replaced it with "utf8mb4_general_ci"
    # This is a workaround for a bug in MySQL 5.7.x and 5.6.x where the default collation is "utf8mb4_0900_ai_ci".
    sed -i 's/utf8mb4_0900_ai_ci/utf8mb4_general_ci/g' "${dump_file}"

    # Execute command
    pv --width 70 "${dump_file}" | ${mysql_exec}

    if [[ ${PIPESTATUS[1]} -eq 0 ]]; then

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
        log_event "debug" "Last command executed: pv ${dump_file} | ${mysql_exec}"

        return 1

    fi

}

################################################################################
# Database export
#
# Arguments:
#  ${1} = ${database}
#  ${2} = ${container_name}
#  ${3} = ${dump_file}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_database_export() {

    local database="${1}"
    local container_name="${2}"
    local dump_file="${3}"

    local mysql_exec
    local dump_status

    if [[ -n ${container_name} && ${container_name} != "false" ]]; then

        local mysql_container_user
        local mysql_container_user_pssw

        # Get MYSQL_USER and MYSQL_PASSWORD from container
        ## Ref: https://www.baeldung.com/ops/docker-get-environment-variable
        mysql_container_user="$(docker exec -i "${container_name}" printenv MYSQL_USER)"
        mysql_container_user_pssw="$(docker exec -i "${container_name}" printenv MYSQL_PASSWORD)"

        mysql_exec="docker exec -i ${container_name} mysqldump -u${mysql_container_user} -p${mysql_container_user_pssw}"

    else

        mysql_exec="${MYSQLDUMP_ROOT}"

    fi

    log_event "info" "Making a database backup of: ${database}" "false"

    spinner_start "- Making a backup of: ${database}"

    # Run mysqldump
    # For large tables use --max_allowed_packet=128M or bigger (default is 25MB)
    ${mysql_exec} --max_allowed_packet=512M "${database}" >"${dump_file}"

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

#  ${2} = ${database_new_name}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_database_rename() {

    local database_old_name="${1}"
    local database_new_name="${2}"

    local dump_file="${BROLIT_TMP_DIR}/${database_old_name}_bk_before_rename_db.sql"

    mysql_database_export "${database_old_name}" "false" "${dump_file}"

    mysql_database_create "${database_new_name}"

    mysql_database_import "${database_new_name}" "false" "${dump_file}"

    mysql_database_drop "${database_old_name}"

}

# TO-CHECK
function mysql_database_clone() {

    local database_old_name="${1}"
    local database_new_name="${2}"

    local dump_file="${BROLIT_TMP_DIR}/${database_old_name}_bk_before_clone_db.sql"

    mysql_database_export "${database_old_name}" "false" "${dump_file}"

    mysql_database_create "${database_new_name}"

    mysql_database_import "${database_new_name}" "false" "${dump_file}"

}

################################################################################
# Search string in all tables of a database
#
# Arguments:
#  ${1} = ${database_name}
#  ${2} = ${search_string}
#  ${3} = ${container_name} - Optional
#
# Outputs:
#  Search results, 1 on error.
################################################################################

function mysql_database_search_string() {

    local database_name="${1}"
    local search_string="${2}"
    local container_name="${3}"

    local mysql_exec
    local tables
    local results_found=0

    if [[ -n ${container_name} && ${container_name} != "false" ]]; then

        local mysql_container_user
        local mysql_container_user_pssw

        # Get MYSQL_USER and MYSQL_PASSWORD from container
        mysql_container_user="$(docker exec -i "${container_name}" printenv MYSQL_USER)"
        mysql_container_user_pssw="$(docker exec -i "${container_name}" printenv MYSQL_PASSWORD)"

        mysql_exec="docker exec -i ${container_name} mysql -u${mysql_container_user} -p${mysql_container_user_pssw}"

    else

        mysql_exec="${MYSQL_ROOT}"

    fi

    log_event "info" "Searching for '${search_string}' in database '${database_name}'" "false"
    display --indent 6 --text "- Searching in database: ${database_name}" --tcolor YELLOW

    # Get all tables from database
    tables="$(${mysql_exec} -Bse "SHOW TABLES FROM ${database_name}")"

    # Check if tables were retrieved
    mysql_result=$?
    if [[ ${mysql_result} -ne 0 ]]; then
        display --indent 6 --text "- Getting tables from database" --result "FAIL" --color RED
        log_event "error" "Failed to get tables from database '${database_name}'" "false"
        return 1
    fi

    # Count total tables
    local total_tables
    total_tables="$(echo "${tables}" | grep -c .)"
    display --indent 6 --text "- Total tables found: ${total_tables}" --tcolor CYAN
    log_event "info" "Found ${total_tables} tables in database '${database_name}'" "false"

    local tables_processed=0

    # Search in each table
    while IFS= read -r table; do

        # Skip empty lines
        [[ -z ${table} ]] && continue

        ((tables_processed++))

        display --indent 8 --text "[${tables_processed}/${total_tables}] Searching in table: ${table}" --tcolor WHITE

        # Get all columns for the table
        local columns
        columns="$(${mysql_exec} -Bse "SHOW COLUMNS FROM ${database_name}.${table}" </dev/null | awk '{print $1}')"

        # Build WHERE clause for all columns
        local where_clause=""
        local first_column=1

        while IFS= read -r column; do
            [[ -z ${column} ]] && continue

            if [[ ${first_column} -eq 1 ]]; then
                where_clause="CAST(\`${column}\` AS CHAR) LIKE '%${search_string}%'"
                first_column=0
            else
                where_clause="${where_clause} OR CAST(\`${column}\` AS CHAR) LIKE '%${search_string}%'"
            fi
        done <<< "${columns}"

        # Execute search query
        if [[ -n ${where_clause} ]]; then
            local count
            count="$(${mysql_exec} -Bse "SELECT COUNT(*) FROM ${database_name}.\`${table}\` WHERE ${where_clause}" </dev/null)"

            if [[ ${count} -gt 0 ]]; then
                results_found=1
                display --indent 10 --text "Found ${count} matches" --result "FOUND" --color GREEN
                log_event "info" "Found ${count} matches in table '${table}'" "false"

                # Show sample results (first 5 rows)
                display --indent 10 --text "Sample results (first 5):" --tcolor CYAN
                ${mysql_exec} -e "SELECT * FROM ${database_name}.\`${table}\` WHERE ${where_clause} LIMIT 5" </dev/null
            fi
        fi

    done <<< "${tables}"

    display --indent 6 --text "- Tables processed: ${tables_processed}" --tcolor CYAN

    if [[ ${results_found} -eq 0 ]]; then
        display --indent 6 --text "- No matches found in any table" --result "INFO" --color YELLOW
        log_event "info" "No matches found for '${search_string}' in database '${database_name}'" "false"
    else
        display --indent 6 --text "- Search completed" --result "DONE" --color GREEN
    fi

    return 0

}

################################################################################
# List tables in a database
#
# Arguments:
#  ${1} = ${database_name}
#  ${2} = ${container_name} - Optional
#
# Outputs:
#  Table names, 1 on error.
################################################################################

function mysql_list_tables() {

    local database_name="${1}"
    local container_name="${2}"

    local mysql_exec
    local tables

    if [[ -n ${container_name} && ${container_name} != "false" ]]; then

        local mysql_container_user
        local mysql_container_user_pssw

        # Get MYSQL_USER and MYSQL_PASSWORD from container
        mysql_container_user="$(docker exec -i "${container_name}" printenv MYSQL_USER)"
        mysql_container_user_pssw="$(docker exec -i "${container_name}" printenv MYSQL_PASSWORD)"

        mysql_exec="docker exec -i ${container_name} mysql -u${mysql_container_user} -p${mysql_container_user_pssw}"

    else

        mysql_exec="${MYSQL_ROOT}"

    fi

    log_event "info" "Listing tables in database '${database_name}'" "false"

    # Get all tables from database
    local tables_raw
    tables_raw="$(${mysql_exec} -Bse "SHOW TABLES FROM ${database_name}")"

    # Check if tables were retrieved
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 ]]; then

        # Trim whitespace from each table name and build space-separated list
        tables=""
        while IFS= read -r table; do
            # Trim whitespace
            table="$(echo "${table}" | xargs)"
            [[ -z ${table} ]] && continue
            # Add to list with space separator
            if [[ -z ${tables} ]]; then
                tables="${table}"
            else
                tables="${tables} ${table}"
            fi
        done <<< "${tables_raw}"

        # Log
        display --indent 6 --text "- Listing tables in database '${database_name}'" --result "DONE" --color GREEN
        log_event "info" "Tables found: '${tables}'" "false"

        # Return
        echo "${tables}"

    else

        # Log
        display --indent 6 --text "- Listing tables in database '${database_name}'" --result "FAIL" --color RED
        log_event "error" "Failed to list tables in database '${database_name}'" "false"

        return 1

    fi

}

################################################################################
# Drop a table from database
#
# Arguments:
#  ${1} = ${database_name}
#  ${2} = ${table_name}
#  ${3} = ${container_name} - Optional
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function mysql_table_drop() {

    local database_name="${1}"
    local table_name="${2}"
    local container_name="${3}"

    local mysql_exec

    if [[ -n ${container_name} && ${container_name} != "false" ]]; then

        local mysql_container_user
        local mysql_container_user_pssw

        # Get MYSQL_USER and MYSQL_PASSWORD from container
        mysql_container_user="$(docker exec -i "${container_name}" printenv MYSQL_USER)"
        mysql_container_user_pssw="$(docker exec -i "${container_name}" printenv MYSQL_PASSWORD)"

        mysql_exec="docker exec -i ${container_name} mysql -u${mysql_container_user} -p${mysql_container_user_pssw}"

    else

        mysql_exec="${MYSQL_ROOT}"

    fi

    log_event "info" "Dropping table '${table_name}' from database '${database_name}'" "false"
    display --indent 6 --text "- Dropping table '${table_name}'" --tcolor YELLOW

    # Drop table
    ${mysql_exec} -e "DROP TABLE ${database_name}.\`${table_name}\`" </dev/null

    # Check result
    mysql_result=$?
    if [[ ${mysql_result} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Table '${table_name}' dropped" --result "DONE" --color GREEN
        log_event "success" "Table '${table_name}' dropped from database '${database_name}'" "false"

        return 0

    else

        # Log
        display --indent 6 --text "- Dropping table '${table_name}'" --result "FAIL" --color RED
        log_event "error" "Failed to drop table '${table_name}' from database '${database_name}'" "false"

        return 1

    fi

}

################################################################################
# Scan WordPress database for malicious code patterns
#
# Arguments:
#  ${1} = ${database_name}
#  ${2} = ${container_name} - Optional
#
# Outputs:
#  Scan results, 1 on error.
################################################################################

function mysql_wordpress_malware_scan() {

    local database_name="${1}"
    local container_name="${2}"

    local mysql_exec
    local tables
    local results_found=0

    # Ensure malware scan results directory exists
    mkdir -p "${BROLIT_TMP_DIR}/malware_scan_results"
    local detailed_results_file="${BROLIT_TMP_DIR}/malware_scan_results/mysql_${database_name}_$$.txt"

    # Clean up any previous results file
    [[ -f ${detailed_results_file} ]] && rm -f "${detailed_results_file}"

    # Malware patterns to search for (using LIKE syntax with %)
    local malware_patterns=(
        "base64_decode"
        "eval("
        "exec("
        "system("
        "assert("
        "shell_exec"
        "passthru"
        "proc_open"
        "popen"
        "curl_exec"
        "curl_multi_exec"
        "parse_ini_file"
        "show_source"
        "file_get_contents"
        "file_put_contents"
        "preg_replace"
        "create_function"
        "call_user_func"
        "\$_POST["
        "\$_GET["
        "\$_REQUEST["
        "\$_COOKIE["
        "RewriteCond"
        "RewriteRule"
        "set_time_limit(0)"
        "error_reporting(0)"
        "ini_restore"
        "ini_set"
        "<script"
        "document.write"
        "fromCharCode"
        "unescape("
        "String.fromCharCode"
        "atob("
        "btoa("
        ".ini_set("
        "phpinfo("
        "chmod("
        "onerror="
        "onload="
        "onclick="
        "onfocus="
        "onmouseover="
        "<iframe src=\"data:"
        "<iframe src=\"javascript:"
    )

    if [[ -n ${container_name} && ${container_name} != "false" ]]; then

        local mysql_container_user
        local mysql_container_user_pssw

        # Get MYSQL_USER and MYSQL_PASSWORD from container
        mysql_container_user="$(docker exec -i "${container_name}" printenv MYSQL_USER)"
        mysql_container_user_pssw="$(docker exec -i "${container_name}" printenv MYSQL_PASSWORD)"

        mysql_exec="docker exec -i ${container_name} mysql -u${mysql_container_user} -p${mysql_container_user_pssw}"

    else

        mysql_exec="${MYSQL_ROOT}"

    fi

    log_event "info" "Scanning database '${database_name}' for malware" "false"
    display --indent 6 --text "- Scanning database: ${database_name}" --tcolor YELLOW
    display --indent 8 --text "Scanning ALL tables in the database" --tcolor CYAN

    # Get ALL tables from database
    tables="$(${mysql_exec} -Bse "SHOW TABLES FROM ${database_name}" </dev/null)"

    # Check if tables were retrieved
    mysql_result=$?
    if [[ ${mysql_result} -ne 0 ]]; then
        display --indent 6 --text "- Getting tables from database" --result "FAIL" --color RED
        log_event "error" "Failed to get tables from database '${database_name}'" "false"
        return 1
    fi

    # Count total tables
    local total_tables
    total_tables="$(echo "${tables}" | grep -c .)"
    display --indent 6 --text "- Total tables found: ${total_tables}" --tcolor CYAN

    local tables_processed=0

    # Search in each table
    while IFS= read -r table; do

        # Skip empty lines
        [[ -z ${table} ]] && continue

        ((tables_processed++))

        # Get all TEXT/VARCHAR columns from this table
        local text_columns
        text_columns="$(${mysql_exec} -Bse "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = '${database_name}' AND TABLE_NAME = '${table}' AND DATA_TYPE IN ('text', 'mediumtext', 'longtext', 'varchar', 'char', 'tinytext');" </dev/null 2>/dev/null)"

        # Skip table if no text columns
        if [[ -z ${text_columns} ]]; then
            display --indent 8 --text "[${tables_processed}/${total_tables}] Scanning table: ${table}" --result "SKIPPED" --color GRAY
            continue
        fi

        # Get primary key column name for this table
        local pk_column
        pk_column="$(${mysql_exec} -Bse "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = '${database_name}' AND TABLE_NAME = '${table}' AND COLUMN_KEY = 'PRI' LIMIT 1;" </dev/null)"
        [[ -z ${pk_column} ]] && pk_column="id"  # fallback to 'id'

        # Track if table has any findings
        local table_has_findings=0

        # Scan for each malware pattern
        for pattern in "${malware_patterns[@]}"; do

            local count=0

            # Build WHERE clause for all text columns
            local where_clause=""
            while IFS= read -r col; do
                [[ -z ${col} ]] && continue
                if [[ -z ${where_clause} ]]; then
                    where_clause="\`${col}\` LIKE '%${pattern}%'"
                else
                    where_clause="${where_clause} OR \`${col}\` LIKE '%${pattern}%'"
                fi
            done <<< "${text_columns}"

            # Execute search query
            if [[ -n ${where_clause} ]]; then
                count="$(${mysql_exec} -Bse "SELECT COUNT(*) FROM ${database_name}.\`${table}\` WHERE ${where_clause}" </dev/null 2>/dev/null || echo "0")"
            fi

            if [[ ${count} -gt 0 ]]; then
                results_found=1

                # Show table name only on first finding for this table
                if [[ ${table_has_findings} -eq 0 ]]; then
                    display --indent 8 --text "[${tables_processed}/${total_tables}] Scanning table: ${table}" --result "WARNING" --color RED
                    table_has_findings=1
                fi

                display --indent 10 --text "⚠ SUSPICIOUS: '${pattern}' found ${count} times" --tcolor RED
                log_event "warning" "Malware pattern '${pattern}' found ${count} times in table '${table}'" "false"

                # Get detailed results with ID and preview
                echo "========================================" >> "${detailed_results_file}"
                echo "Pattern: ${pattern}" >> "${detailed_results_file}"
                echo "Table: ${table}" >> "${detailed_results_file}"
                echo "Occurrences: ${count}" >> "${detailed_results_file}"
                echo "Columns scanned: $(echo "${text_columns}" | tr '\n' ', ' | sed 's/,$//')" >> "${detailed_results_file}"
                echo "----------------------------------------" >> "${detailed_results_file}"

                # Get records that match the pattern (limit to first 10)
                ${mysql_exec} -Bse "SELECT ${pk_column} FROM ${database_name}.\`${table}\` WHERE ${where_clause} LIMIT 10" </dev/null 2>/dev/null | while IFS=$'\t' read -r record_id; do
                    [[ -z ${record_id} ]] && continue

                    echo "  ---" >> "${detailed_results_file}"
                    echo "  Record ID (${pk_column}): ${record_id}" >> "${detailed_results_file}"

                    # Show which columns contain the pattern and their preview
                    while IFS= read -r col; do
                        [[ -z ${col} ]] && continue
                        local col_value
                        col_value="$(${mysql_exec} -Bse "SELECT LEFT(\`${col}\`, 200) FROM ${database_name}.\`${table}\` WHERE \`${pk_column}\` = '${record_id}' AND \`${col}\` LIKE '%${pattern}%' LIMIT 1" </dev/null 2>/dev/null)"
                        if [[ -n ${col_value} ]]; then
                            echo "  Column '${col}': ${col_value}..." >> "${detailed_results_file}"
                        fi
                    done <<< "${text_columns}"

                    # Generate SQL delete command
                    local delete_sql="DELETE FROM \`${table}\` WHERE \`${pk_column}\` = '${record_id}';"
                    echo "  SQL: ${delete_sql}" >> "${detailed_results_file}"

                    # Generate the full bash command with proper escaping
                    if [[ -n ${container_name} && ${container_name} != "false" ]]; then
                        # Use single quotes to avoid backtick interpretation
                        echo "  Bash command: docker exec -i ${container_name} mysql -u${mysql_container_user} -p${mysql_container_user_pssw} ${database_name} -e 'DELETE FROM \`${table}\` WHERE \`${pk_column}\` = \"${record_id}\";'" >> "${detailed_results_file}"
                    else
                        # For host MySQL, show command with proper credentials
                        echo "  Bash command: mysql -u root -p ${database_name} -e 'DELETE FROM \`${table}\` WHERE \`${pk_column}\` = \"${record_id}\";'" >> "${detailed_results_file}"
                        echo "  (Note: Replace 'root' and add password as needed)" >> "${detailed_results_file}"
                    fi
                    echo "" >> "${detailed_results_file}"
                done

            fi

        done

        # If no findings in this table, show OK
        if [[ ${table_has_findings} -eq 0 ]]; then
            display --indent 8 --text "[${tables_processed}/${total_tables}] Scanning table: ${table}" --result "OK" --color GREEN
        fi

    done <<< "${tables}"

    display --indent 6 --text "- Tables scanned: ${tables_processed}" --tcolor CYAN

    if [[ ${results_found} -eq 0 ]]; then
        display --indent 6 --text "- No suspicious patterns found" --result "CLEAN" --color GREEN
        log_event "info" "No malware patterns found in database '${database_name}'" "false"
        # Clean up results file if no results
        [[ -f ${detailed_results_file} ]] && rm -f "${detailed_results_file}"
    else
        display --indent 6 --text "- Scan completed - SUSPICIOUS CONTENT FOUND" --result "WARNING" --color RED
        display --indent 6 --text "  ⚠ Manual review recommended!" --tcolor RED
        echo ""
        display --indent 6 --text "📄 Detailed report saved to:" --tcolor CYAN
        display --indent 8 --text "${detailed_results_file}" --tcolor WHITE
        echo ""
        display --indent 6 --text "To view the report, run:" --tcolor YELLOW

        display --indent 8 --text "cat ${detailed_results_file}" --tcolor WHITE
        echo ""

        # Ask if user wants to view the report now
        if whiptail --title "Malware Scan Results" --yesno "Suspicious content found!\n\nDetailed report saved to:\n${detailed_results_file}\n\nThe report contains:\n- Specific IDs of affected records\n- Preview of suspicious content\n- SQL commands to delete each record\n- WP-CLI commands (when applicable)\n\nDo you want to view the report now?" 18 78; then
            less "${detailed_results_file}"
        fi
    fi

    return 0

}
