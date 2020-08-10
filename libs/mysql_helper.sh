#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
#############################################################################

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

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

    log_event "info" "Creating ${db_user} user in MySQL with pass: ${db_user_psw}" "true"

    if [[ -z ${db_user_psw} || ${db_user_psw} == "" ]]; then
        sql1="CREATE USER '${db_user}'@'localhost';"

    else
        sql1="CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_user_psw}';"

    fi

    ${MYSQL} -u "${MUSER}" -p"${MPASS}" -e "${sql1}"
    mysql_result=$?
    
    if [ "${mysql_result}" -eq 0 ]; then
        log_event "success" " MySQL user ${db_user} created" "true"
        return 0

    else
        log_event "error" "Something went wrong creating user: ${db_user}. MySQL output: ${mysql_result}" "true"
        return 1

    fi

}

mysql_user_delete() {

    # $1 = ${db_user}

    local db_user=$1

    local sql1="DROP USER '${db_user}'@'localhost';"
    local sql2="FLUSH PRIVILEGES;"

    log_event "info" "Deleting ${db_user} user in MySQL ..." "true"

    ${MYSQL} -u "${MUSER}" -p"${MPASS}" -e "${sql1}${sql2}" >>"${LOG}"
    mysql_result=$?
    
    if [ "${mysql_result}" -eq 0 ]; then
        log_event "success" " Database user ${db_user} deleted" "true"
        return 0

    else
        log_event "error" "Something went wrong deleting user: ${db_user}. MySQL output: ${mysql_result}" "true"
        return 1

    fi

}

mysql_user_psw_change() {

    # $1 = ${db_user}
    # $2 = ${db_user_psw}

    local db_user=$1
    local db_user_psw=$2

    local sql1 sql2

    log_event "info" "Changing password for user ${db_user} in MySQL" "true"

    sql1="ALTER USER '${db_user}'@'localhost' IDENTIFIED BY '${db_user_psw}';"
    sql2="FLUSH PRIVILEGES;"

    ${MYSQL} -u "${MUSER}" -p"${MPASS}" -e "${sql1}${sql2}"
    mysql_result=$?
    
    if [ "${mysql_result}" -eq 0 ]; then
        log_event "success" "New password for user ${db_user}: ${db_user_psw}" "true" 
        return 0

    else
        log_event "error" "Something went wrong changing MySQL password to user ${db_user}. MySQL output: ${mysql_result}" "true"
        return 1

    fi

}

mysql_user_grant_privileges() {

    # $1 = ${USER}
    # $2 = ${DB}

    local db_user=$1
    local db_target=$2

    local sql1 sql2 mysql_result

    log_event "info" "Granting privileges to ${db_user} on ${db_target} database in MySQL" "true"

    sql1="GRANT ALL PRIVILEGES ON ${db_target}.* TO '${db_user}'@'localhost';"
    sql2="FLUSH PRIVILEGES;"

    ${MYSQL} -u "${MUSER}" -p"${MPASS}" -e "${sql1}${sql2}"
    mysql_result=$?
    
    if [ "${mysql_result}" -eq 0 ]; then
        log_event "success" "Privileges granted to user ${db_user}" "true"
        return 0

    else
        log_event "error" "Something went wrong granting privileges to user ${db_user}" "true"
        return 1

    fi

}

mysql_user_exists() {

    # $1 = ${DB_USER}

    local db_user=$1

    if ! echo "SELECT COUNT(*) FROM mysql.user WHERE user = '${db_user}';" | mysql -u "${MUSER}" --password="${MPASS}" | grep 1 &>/dev/null; then
        #return 0 if user don't exists
        echo 0
    else
        #return 1 if user already exists
        echo 1
    fi

}

mysql_database_exists() {

    # $1 = ${DB}

    local database=$1

    result=$(mysql -u "${MUSER}" --password="${MPASS}" -e "SHOW DATABASES LIKE '${database}';")

    if [[ -z "${result}" || "${result}" = "" ]]; then
        #return 1 if database don't exists
        echo 1
        
    else
        #return 0 if database exists
        echo 0
    fi

}

mysql_name_sanitize(){

    # $1 = ${name} database_name or user_name

    local string=$1

    local clean

    log_event "info" "Running mysql_name_sanitize for ${string}" "true"

    # First, strip "-"
    clean=${string//-/}

    # Next, replace "." with "_"
    clean=${clean//./_}

    # Now, clean out anything that's not alphanumeric or an underscore
    clean=${clean//[^a-zA-Z0-9_]/}

    # Finally, lowercase with TR
    clean=$(echo -n "${clean}" | tr A-Z a-z)

    log_event "info" "Sanitized name: ${clean}" "true"

    # Return
    echo "${clean}"

}

mysql_database_create() {

    # $1 = ${database}

    local database=$1

    local sql1 mysql_result

    log_event "info" "Creating ${database} database in MySQL ..." "true"

    sql1="CREATE DATABASE IF NOT EXISTS ${database};"

    ${MYSQL} -u "${MUSER}" -p"${MPASS}" -e "${sql1}"
    mysql_result=$?

    if [ "${mysql_result}" -eq 0 ]; then
        log_event "success" "Database ${database} created successfully" "true"
        return 0

    else
        log_event "error" "Something went wrong creating database: ${database}. MySQL output: ${mysql_result}" "true"
        return 1

    fi

}

mysql_database_drop() {

    # $1 = ${DB}

    local database=$1

    local sql1 mysql_result

    log_event "info" "Droping the database: ${database}" "true"

    sql1="DROP DATABASE ${database};"
    
    ${MYSQL} -u "${MUSER}" -p"${MPASS}" -e "${sql1}"
    mysql_result=$?

    if [ "${mysql_result}" -eq 0 ]; then
        log_event "success" "Database ${database} deleted successfully" "true"
        return 0

    else
        log_event "error" "Something went wrong deleting database: ${database}. MySQL output: ${mysql_result}" "true"
        return 1
        
    fi

}

mysql_database_import() {

    # $1 = ${database} (.sql)
    # $2 = ${dump_file}

    local database=$1
    local dump_file=$2

    local import_status

    log_event "info" "Importing dump file ${dump_file} into database: ${database}" "true"

    pv "${dump_file}" | ${MYSQL} -f -u"${MUSER}" -p"${MPASS}" -f -D "${database}"
    import_status=$?

    if [ ${import_status} -eq 0 ]; then
        log_event "success" "Database ${database} imported successfully" "true"
        return 0

    else
        log_event "error" "Something went wrong importing database: ${database}. Import output: ${import_status}" "true"
        return 1

    fi

}

mysql_database_export() {

    # $1 = ${database}
    # $2 = ${dump_file}

    local database=$1
    local dump_file=$2

    local dump_status

    log_event "info" "Creating a dump file of: ${database}" "true"
    ${MYSQLDUMP} -u "${MUSER}" -p"${MPASS}" "${database}" > "${dump_file}"
    
    dump_status=$?
    if [ ${dump_status} -eq 0 ]; then
        log_event "success" "Database ${database} exported successfully" "true"
        return 0
    
    else
        log_event "error" "Something went wrong exporting database: ${database}. MySQL dump output: ${dump_status}" "true"
        return 1

    fi

}

# TODO: NEED TEST
#mysql_get_disk_usage() {
#
#    SQL1="SELECT SUM( data_length + index_length ) / 1024 / 1024 'Size'
#        FROM information_schema.TABLES WHERE table_schema='$1'"
#
#    mysql -u ${MUSER} -p${MPASS} -e "${SQL1}" >>$LOG
#
#    if [ $? -eq 0 ]; then
#
#        return 0
#
#    else
#        echo " > Something went wrong!" >>$LOG
#        echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
#        exit 1
#
#    fi
#
#}