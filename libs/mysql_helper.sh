#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc06
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

    # return
    echo "${total_databases}"
}

mysql_user_create() {

    # $1 = ${db_user}
    # $2 = ${db_user_psw}

    local db_user=$1
    local db_user_psw=$2

    local sql_1

    if [[ -z ${db_user_psw} || ${db_user_psw} == "" ]]; then
        sql_1="CREATE USER '${db_user}'@'localhost';"

    else
        sql_1="CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_user_psw}';"

    fi

    mysql -u "${MUSER}" -p"${MPASS}" -e "${sql_1}"

    if [ $? -eq 0 ]; then
        echo " > MySQL user: ${db_user} created ok!" >>$LOG
        echo -e ${GREEN}" > MySQL user: ${db_user} created ok!"${ENDCOLOR} >&2
        return 0

    else
        echo " > Something went wrong creating user: ${db_user}" >>$LOG
        echo -e ${B_RED}" > Something went wrong creating user: ${db_user}"${ENDCOLOR} >&2
        return 1

    fi

}

mysql_user_delete() {

    # $1 = ${db_user}

    local db_user=$1

    local sql_1="DROP USER '${db_user}'@'localhost';"
    local sql_2="FLUSH PRIVILEGES;"

    echo "Deleting ${db_user} user in MySQL ..." >>$LOG
    mysql -u "${MUSER}" -p"${MPASS}" -e "${sql_1}${sql_2}" >>$LOG

    if [ $? -eq 0 ]; then
        echo " > Database user: ${db_user} deleted ok!" >>$LOG
        echo -e ${GREEN}" > Database user: ${db_user} deleted ok!"${ENDCOLOR} >&2
        return 0

    else
        echo " > Something went wrong deleting user: ${db_user}" >>$LOG
        echo -e ${B_RED}" > Something went wrong deleting user: ${db_user}"${ENDCOLOR} >&2
        exit 1
        #return 1

    fi

}

mysql_user_psw_change() {

    # $1 = ${db_user}
    # $2 = ${db_user_psw}

    local db_user=$1
    local db_user_psw=$2

    SQL1="ALTER USER '${db_user}'@'localhost' IDENTIFIED BY '${db_user_psw}';"
    SQL2="FLUSH PRIVILEGES;"

    echo " > Deleting ${db_user} user in MySQL ..." >>$LOG
    mysql -u "${MUSER}" -p"${MPASS}" -e "${SQL1}${SQL2}" >>$LOG

    if [ $? -eq 0 ]; then
        echo " > DONE!" >>$LOG
        echo -e ${GREEN}" > DONE!"${ENDCOLOR}
        return 0

    else
        echo " > Something went wrong!" >>$LOG
        echo -e ${B_RED}" > Something went wrong!"${ENDCOLOR}
        exit 1

    fi

}

mysql_user_grant_privileges() {

    # $1 = ${USER}
    # $2 = ${DB}

    local db_user=$1
    local db_target=$2

    SQL1="GRANT ALL PRIVILEGES ON ${db_target}.* TO '${db_user}'@'localhost';"
    SQL2="FLUSH PRIVILEGES;"

    echo " > Granting privileges to ${db_user} on ${db_target} database in MySQL ..." >>$LOG
    mysql -u "${MUSER}" -p"${MPASS}" -e "${SQL1}${SQL2}" >>$LOG

    if [ $? -eq 0 ]; then
        echo " > Privileges granted ok!" >>$LOG
        echo -e ${GREEN}" > Privileges granted ok!"${ENDCOLOR}
        return 0

    else
        echo " > Something went wrong granting privileges to ${db_user}!" >>$LOG
        echo -e ${B_RED}" > Something went wrong granting privileges to ${db_user}!"${ENDCOLOR}
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

mysql_database_create() {

    # $1 = ${DB}

    local database=$1

    SQL1="CREATE DATABASE IF NOT EXISTS ${database};"

    mysql -u "${MUSER}" -p"${MPASS}" -e "${SQL1}" >>$LOG

    if [ $? -eq 0 ]; then
        echo " > Database ${database} created OK!" >>$LOG
        echo -e ${B_GREEN}" > Database ${database} created OK!"${ENDCOLOR}>&2
        return 0

    else
        echo " > Something went wrong creating database: ${database}!" >>$LOG
        echo -e ${B_RED}" > Something went wrong creating database: ${database}!"${ENDCOLOR}>&2
        exit 1

    fi

}

mysql_database_drop() {

    # $1 = ${DB}

    local database=$1

    SQL1="DROP DATABASE ${database};"

    echo " > Droping the database: ${database} ..." >>$LOG
    echo -e ${GREEN}" > Droping the database: ${database} ..."${ENDCOLOR} >&2

    mysql -u "${MUSER}" -p"${MPASS}" -e "${SQL1}" >>$LOG

    if [ $? -eq 0 ]; then
        echo " > Database ${database} deleted!" >>$LOG
        echo -e ${GREEN}" > Database ${database} deleted!"${ENDCOLOR} >&2
        return 0

    else
        echo " > Something went wrong deleting the database: ${database}!" >>$LOG
        echo -e ${B_RED}" > Something went wrong deleting the database: ${database}!"${ENDCOLOR} >&2
        exit 1
        
    fi

}

mysql_database_import() {

    # $1 = ${DATABASE} (.sql)
    # $2 = ${DUMP_FILE}

    local db_name=$1
    local dump_file=$2

    echo -e ${CYAN}" > Importing dump file ${dump_file} into database: ${db_name} ..."${ENDCOLOR}>&2
    echo " > Importing dump file ${dump_file} into database: ${db_name} ..." >>$LOG

    pv "${dump_file}" | mysql -f -u"${MUSER}" -p"${MPASS}" -f -D "${db_name}"

    if [ $? -eq 0 ]; then
        echo " > Import database ${db_name} OK!" >>$LOG
        echo -e ${GREEN}" > Import database ${db_name} OK!"${ENDCOLOR}>&2
        return 0

    else
        echo " > Import database ${db_name} failed!" >>$LOG
        echo -e ${B_RED}" > Import database ${db_name} failed!"${ENDCOLOR}>&2

        exit 1

    fi

}

mysql_database_export() {

    # $1 = ${database}
    # $2 = ${dump_file}

    local database=$1
    local dump_file=$2

    echo -e ${CYAN}" > Exporting database ${database} into dump file ${dump_file} ..."${ENDCOLOR}
    echo " > Exporting database ${database} into dump file ${dump_file} ..." >>$LOG
    mysqldump -u "${MUSER}" -p"${MPASS}" "${database}" > "${dump_file}"

    if [ $? -eq 0 ]; then
        echo " > DB ${database} exported successfully!" >>$LOG
        echo -e ${GREEN}" > DB ${database} exported successfully!"${ENDCOLOR}
    
    else
        echo " > DB ${database} export failed!" >>$LOG
        echo -e ${B_RED}" > DB ${database} export failed!"${ENDCOLOR}
        exit 1

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
