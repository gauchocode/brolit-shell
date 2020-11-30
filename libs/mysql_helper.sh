#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.7
#############################################################################

mysql_count_dabases() {

    # $1 = ${databases}

    local databases=$1
    local total_databases=0

    for db in ${databases}; do
        if [[ $DB_BL != *"${db}"* ]]; then
            total_databases=$((total_databases + 1))
        fi
    done

    # Return
    echo "${total_databases}"
}

mysql_user_create() {

    # $1 = ${db_user}
    # $2 = ${db_user_psw}

    local db_user=$1
    local db_user_psw=$2

    local sql1

    log_event "info" "Creating ${db_user} user in MySQL with pass: ${db_user_psw}" "false"
    display --indent 2 --text "- Creating ${db_user} user in MySQL"

    if [[ -z ${db_user_psw} || ${db_user_psw} == "" ]]; then
        sql1="CREATE USER '${db_user}'@'localhost';"

    else
        sql1="CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_user_psw}';"

    fi

    mysql_output="$("${MYSQL}" -u "${MUSER}" -p"${MPASS}" -e "${sql1}" 2>&1)"
    mysql_result="$?"
    if [[ ${mysql_result} -eq 0 ]]; then
        log_event "success" " MySQL user ${db_user} created with pass: ${db_user_psw}"
        clear_last_line
        display --indent 2 --text "- Creating user in MySQL: ${db_user}" --result "DONE" --color GREEN
        display --indent 4 --text "User created with pass: ${db_user_psw}" --tcolor YELLOW
        return 0

    else
        log_event "error" "Something went wrong creating user: ${db_user}. MySQL output: ${mysql_output}"
        clear_last_line
        display --indent 2 --text "- Creating ${db_user} user in MySQL" --result "FAIL" --color RED
        display --indent 4 --text "MySQL output: ${mysql_output}" --tcolor RED
        return 1

    fi

}

mysql_user_delete() {

    # $1 = ${db_user}

    local db_user=$1

    local sql1="DROP USER '${db_user}'@'localhost';"
    local sql2="FLUSH PRIVILEGES;"

    log_event "info" "Deleting ${db_user} user in MySQL ..."

    mysql_output="$("${MYSQL}" -u "${MUSER}" -p"${MPASS}" -e "${sql1}${sql2}" 2>&1)"
    mysql_result="$?"
    if [[ ${mysql_result} -eq 0 ]]; then
        log_event "success" " Database user ${db_user} deleted"
        display --indent 2 --text "- Deleting user in MySQL: ${db_user}" --result "DONE" --color GREEN
        return 0

    else
        log_event "error" "Something went wrong deleting user: ${db_user}. MySQL output: ${mysql_output}"
        display --indent 2 --text "- Deleting ${db_user} user in MySQL" --result "FAIL" --color RED
        return 1

    fi

}

mysql_user_psw_change() {

    # $1 = ${db_user}
    # $2 = ${db_user_psw}

    local db_user=$1
    local db_user_psw=$2

    local sql1 
    local sql2

    log_event "info" "Changing password for user ${db_user} in MySQL"

    sql1="ALTER USER '${db_user}'@'localhost' IDENTIFIED BY '${db_user_psw}';"
    sql2="FLUSH PRIVILEGES;"

    mysql_output="$("${MYSQL}" -u "${MUSER}" -p"${MPASS}" -e "${sql1}${sql2}" 1>&2)"
    mysql_result="$?"
    if [[ ${mysql_result} -eq 0 ]]; then
        log_event "success" "New password for user ${db_user}: ${db_user_psw}"
        return 0

    else
        log_event "error" "Something went wrong changing MySQL password to user ${db_user}. MySQL output: ${mysql_output}" "false"
        return 1

    fi

}

mysql_root_psw_change() {

    # $1 = ${db_root_psw}

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
    if [ "${db_root_psw}" = "" ];then
        db_root_psw_len=$(shuf -i 20-30 -n 1)
        db_root_psw=$(pwgen -scn "${db_root_psw_len}" 1)
        db_root_user='root'
    fi
	
	# Update root user with new password
	mysql mysql -e "USE mysql;UPDATE user SET Password=PASSWORD('$db_root_psw') WHERE User='$db_root_user';FLUSH PRIVILEGES;"
	
	# Kill the insecure mysql process
	killall -v mysqld
	
	# Starting mysql again
	service mysql restart
	
    mysql_result="$?"
    if [[ ${mysql_result} -eq 0 ]]; then
        log_event "success" "New password for root: ${db_root_psw}" "false" 
        display --indent 2 --text "- Setting new password for root" --result "DONE" --color GREEN
        display --indent 4 --text "New password: ${db_root_psw}"

        return 0

    else
        log_event "error" "Something went wrong changing MySQL root password. MySQL output: ${mysql_result}" "false"
        display --indent 2 --text "- Setting new password for root" --result "FAIL" --color RED

        return 1

    fi

}

mysql_user_grant_privileges() {

    # $1 = ${USER}
    # $2 = ${DB}

    local db_user=$1
    local db_target=$2

    local sql1 sql2 mysql_result

    log_event "info" "Granting privileges to ${db_user} on ${db_target} database in MySQL" "false"

    sql1="GRANT ALL PRIVILEGES ON ${db_target}.* TO '${db_user}'@'localhost';"
    sql2="FLUSH PRIVILEGES;"

    mysql_output="$("${MYSQL}" -u "${MUSER}" -p"${MPASS}" -e "${sql1}${sql2}" 1>&2)"
    mysql_result="$?"
    if [[ ${mysql_result} -eq 0 ]]; then
        log_event "success" "Privileges granted to user ${db_user}" "false"
        display --indent 2 --text "- Granting privileges to ${db_user}" --result "DONE" --color GREEN
        return 0

    else
        log_event "error" "Something went wrong granting privileges to user ${db_user}. MySQL output: ${mysql_output}" "false"
        display --indent 2 --text "- Granting privileges to ${db_user}" --result "FAIL" --color RED
        return 1

    fi

}

mysql_user_exists() {

    # $1 = ${DB_USER}

    local db_user=$1

    if ! echo "SELECT COUNT(*) FROM mysql.user WHERE user = '${db_user}';" | mysql -u "${MUSER}" --password="${MPASS}" | grep 1 &>/dev/null; then
        #return 0 if user don't exists
        return 0
    else
        #return 1 if user already exists
        return 1
    fi

}

mysql_database_exists() {

    # $1 = ${DB}

    local database=$1

    result=$("${MYSQL}" -u "${MUSER}" --password="${MPASS}" -e "SHOW DATABASES LIKE '${database}';")

    if [[ -z "${result}" || "${result}" = "" ]]; then
        #return 1 if database don't exists
        return 1
        
    else
        #return 0 if database exists
        return 0
    fi

}

mysql_name_sanitize(){

    # $1 = ${name} database_name or user_name

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
    clean=$(echo -n "${clean}" | tr A-Z a-z)

    #log_event "debug" "Sanitized name: ${clean}" "true"

    # Return
    echo "${clean}"

}

mysql_database_create() {

    # $1 = ${database}

    local database=$1

    local sql1
    local mysql_result

    log_event "info" "Creating ${database} database in MySQL ..." "false"

    sql1="CREATE DATABASE IF NOT EXISTS ${database};"

    mysql_output="$("${MYSQL}" -u "${MUSER}" -p"${MPASS}" -e "${sql1}" 2>&1)"
    mysql_result="$?"
    if [[ ${mysql_result} -eq 0 ]]; then
        log_event "success" "Database ${database} created successfully" "false"
        display --indent 2 --text "- Creating database: ${database}" --result "DONE" --color GREEN
        return 0

    else
        log_event "error" "Something went wrong creating database: ${database}. MySQL output: ${mysql_output}" "false"
        display --indent 2 --text "- Creating database: ${database}" --result "ERROR" --color RED
        display --indent 4 --text "MySQL output: ${mysql_output}" --tcolor RED
        return 1

    fi

}

mysql_database_drop() {

    # $1 = ${DB}

    local database=$1

    local sql1
    local mysql_result

    log_event "info" "Droping the database: ${database}"

    sql1="DROP DATABASE ${database};"
    
    mysql_output="$("${MYSQL}" -u "${MUSER}" -p"${MPASS}" -e "${sql1}" 2>&1)"
    mysql_result="$?"
    if [[ ${mysql_result} -eq 0 ]]; then
        log_event "success" "- Database ${database} deleted successfully"
        display --indent 2 --text "- Droping database: ${database}" --result "DONE" --color GREEN
        return 0

    else
        log_event "error" "Something went wrong deleting database: ${database}. MySQL output: ${mysql_output}" "false"
        display --indent 2 --text "- Droping database: ${database}" --result "ERROR" --color RED
        display --indent 4 --text "MySQL import output: ${mysql_output}" --tcolor RED
        return 1
        
    fi

}

mysql_database_import() {

    # $1 = ${database} (.sql)
    # $2 = ${dump_file}

    local database=$1
    local dump_file=$2

    local import_status

    log_event "info" "Importing dump file ${dump_file} into database: ${database}"
    display --indent 2 --text "- Importing backup into database: ${database}" --tcolor YELLOW
    log_event "info" "Running: pv ${dump_file} | ${MYSQL} -f -u${MUSER} -p${MPASS} -f -D ${database}"

    pv "${dump_file}" | ${MYSQL} -f -u"${MUSER}" -p"${MPASS}" -f -D "${database}" 2>&1
    import_status=$?

    if [ ${import_status} -eq 0 ]; then
        log_event "success" "Database ${database} imported successfully"

        #clear_last_line
        display --indent 2 --text "Database backup import" --result "DONE" --color GREEN

        return 0

    else
        log_event "error" "Something went wrong importing database: ${database}. Import output: ${import_status}"

        #clear_last_line
        display --indent 2 --text "Database backup import" --result "ERROR" --color RED
        display --indent 4 --text "MySQL import output: ${import_status}" --tcolor RED

        return 1

    fi

}

mysql_database_export() {

    # $1 = ${database}
    # $2 = ${dump_file}

    local database=$1
    local dump_file=$2

    local dump_status

    log_event "info" "Creating a database backup of: ${database}" "false"
    display --indent 2 --text "- Creating a backup of: ${database}"

    dump_output="$(${MYSQLDUMP} -u "${MUSER}" -p"${MPASS}" "${database}" > "${dump_file}" 2>&1)"
    dump_status="$?"
    if [[ ${dump_status} -eq 0 ]]; then
        log_event "success" "Database ${database} exported successfully" "false"
        
        clear_last_line
        display --indent 6 --text "- Database backup for ${database}" --result "DONE" --color GREEN

        return 0
    
    else
        log_event "error" "Something went wrong exporting database: ${database}. MySQL dump output: ${dump_status}" "false"

        clear_last_line
        display --indent 6 --text "- Database backup for ${database}" --result "ERROR" --color RED
        display --indent 8 --text "MySQL dump output: ${dump_output}" --tcolor RED

        return 1

    fi

}