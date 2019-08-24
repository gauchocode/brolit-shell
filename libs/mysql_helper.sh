#!/bin/bash
#
# Autor: broobe. web + mobile development - https://broobe.com
# Script Name: Broobe Utils Scripts
# Version: 2.9.7
################################################################################
#
# Ref: https://github.com/nelson6e65/bash-mysql-helper/blob/master/src/main.sh
#
# https://stackoverflow.com/questions/34057123/difference-between-and-when-passing-arguments-to-bash-function
#

source /root/.broobe-utils-options

################################################################################

count_dabases() {

    # $1 - ${DBS}

    TOTAL_DBS=0
    for db in ${DBS}; do
        if [[ $DB_BL != *"${db}"* ]]; then
            TOTAL_DBS=$((TOTAL_DBS + 1))
        fi
    done

    # return
    echo $TOTAL_DBS
}

mysql_user_create() {

    # TODO: Checkear si el usuario ya existe
    # TODO: el GRANT USAGE debería ser otro método

    # $1 - USER (${PROJECT_NAME}_user)

    SQL1="CREATE USER '$1'@'localhost';"
    SQL2="GRANT USAGE on *.* to '$1'@'localhost';" #GRANT USAGE on *.* to '$1'@'localhost';
    SQL3="FLUSH PRIVILEGES;"

    echo "Creating $1 user in MySQL ..." >>$LOG
    mysql -u ${MUSER} -p${MPASS} -e "${SQL1}${SQL2}${SQL3}" >>$LOG

    if [ $? -eq 0 ]; then
        echo " > DONE!" >>$LOG
        echo -e ${GREN}" > DONE!"${ENDCOLOR}
    else
        echo " > Something went wrong!" >>$LOG
        echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
        exit 1
    fi

}

mysql_user_wpass_create() {

    if ! echo "SELECT COUNT(*) FROM mysql.user WHERE user = '${PROJECT_NAME}_user';" | mysql -u root --password=${MPASS} | grep 1 &>/dev/null; then

        # $1 USER (${PROJECT_NAME}_user)

        DB_PASS=$(openssl rand -hex 12)

        SQL1="CREATE USER '$1'@'localhost' IDENTIFIED BY '${DB_PASS}';"

        echo -e ${CYAN}" > Creating $1 user in MySQL with pass: ${DB_PASS}"${ENDCOLOR} >>$LOG
        echo "Creating $1 user in MySQL with pass: ${DB_PASS}" >>$LOG

        mysql -u ${MUSER} -p${MPASS} -e "${SQL1}" >>$LOG

        if [ $? -eq 0 ]; then
            echo " > DONE!" >>$LOG
            echo -e ${GREN}" > DONE!"${ENDCOLOR}
        else
            echo " > Something went wrong!" >>$LOG
            echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
            exit 1
        fi

    else

        echo -e ${YELLOW}" > User $1 already exists"${ENDCOLOR} >>$LOG

    fi

}

mysql_user_delete() {

    # $1 = ${USER_DB}

    USER_DB=$1

    SQL1="DROP USER '${USER_DB}'@'localhost';"
    SQL2="FLUSH PRIVILEGES;"

    echo "Deleting ${USER_DB} user in MySQL ..." >>$LOG
    mysql -u ${MUSER} -p${MPASS} -e "${SQL1}${SQL2}" >>$LOG

    if [ $? -eq 0 ]; then
        echo " > DONE!" >>$LOG
        echo -e ${GREN}" > DONE!"${ENDCOLOR}
    else
        echo " > Something went wrong!" >>$LOG
        echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
        exit 1
    fi

}

mysql_user_psw_change() {

    # $1 = ${USER_DB}
    # $2 = ${USER_DB_PSW}

    USER_DB=$1
    USER_DB_PSW=$2

    SQL1="ALTER USER '${USER_DB}'@'localhost' IDENTIFIED BY '${USER_DB_PSW}';"
    SQL2="FLUSH PRIVILEGES;"

    echo "Deleting ${USER_DB} user in MySQL ..." >>$LOG
    mysql -u ${MUSER} -p${MPASS} -e "${SQL1}${SQL2}" >>$LOG

    if [ $? -eq 0 ]; then
        echo " > DONE!" >>$LOG
        echo -e ${GREN}" > DONE!"${ENDCOLOR}
    else
        echo " > Something went wrong!" >>$LOG
        echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
        exit 1
    fi

}

mysql_database_create() {

    # $1 = ${DB}

    DB=$1

    SQL1="CREATE DATABASE IF NOT EXISTS ${DB};"

    echo "Creating ${DB} database in MySQL ..." >>$LOG
    mysql -u ${MUSER} -p${MPASS} -e "${SQL1}" >>$LOG

    if [ $? -eq 0 ]; then
        echo " > DONE!" >>$LOG
        echo -e ${GREN}" > DONE!"${ENDCOLOR}
    else
        echo " > Something went wrong!" >>$LOG
        echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
        exit 1
    fi

}

mysql_database_drop() {

    # $1 = ${DB}

    DB=$1

    SQL1="DROP DATABASE ${DB};"

    echo "Droping database ${DB} ..." >>$LOG
    mysql -u ${MUSER} -p${MPASS} -e "${SQL1}" >>$LOG

    if [ $? -eq 0 ]; then
        echo " > Database ${DB} deleted!" >>$LOG
        echo -e ${GREEN}" > Database ${DB} deleted!"${ENDCOLOR}
    else
        echo " > Something went wrong!" >>$LOG
        echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
        exit 1
    fi

}

mysql_database_import() {

    # $1 = ${DATABASE}
    # $2 = ${DUMP_FILE}

    echo -e ${YELLOW}" > Importing dump file $2 into database: $1 ..."${ENDCOLOR}
    echo " > Importing dump file $2 into database: $1 ..." >>$LOG

    pv $2 | mysql -f -u ${MUSER} -p ${MPASS} -f -D $1

    if [ $? -eq 0 ]; then
        echo " > Import database $1 OK!" >>$LOG
        echo -e ${GREEN}" > Import database $1 OK!"${ENDCOLOR}
    else
        echo " > Import database $1 failed!" >>$LOG
        echo -e ${RED}" > Import database $1 failed!"${ENDCOLOR}
        exit 1
    fi

}

#mysql_database_check() {
#
#    # $1 = ${DATABASE}
#
#    # TODO: check if database exists
#
#}

mysql_database_export() {

    # $1 = ${DATABASE}
    # $2 = ${DUMP_FILE}

    DATABASE=$1
    DUMP_FILE=$2

    echo -e ${YELLOW}" > Exporting database ${DATABASE} into dump file ${DUMP_FILE} ..."${ENDCOLOR}
    echo " > Exporting database ${DATABASE} into dump file ${DUMP_FILE} ..." >>$LOG
    mysqldump -u ${MUSER} -p${MPASS} ${DATABASE} > ${DUMP_FILE}

    if [ $? -eq 0 ]; then
        echo " > DB ${DATABASE} exported successfully!" >>$LOG
        echo -e ${GREEN}" > DB ${DATABASE} exported successfully!"${ENDCOLOR}
    else
        echo " > DB ${DATABASE} export failed!" >>$LOG
        echo -e ${RED}" > DB ${DATABASE} export failed!"${ENDCOLOR}
        exit 1
    fi

}

mysql_user_grant_privileges() {

    # $1 = ${USER}
    # $2 = ${DB}

    SQL1="GRANT ALL PRIVILEGES ON $2 . * TO '$1'@'localhost';"
    SQL2="FLUSH PRIVILEGES;"

    echo "Granting privileges to $1 on $2 database in MySQL ..." >>$LOG
    mysql -u ${MUSER} -p${MPASS} -e "${SQL1}${SQL2}" >>$LOG

    if [ $? -eq 0 ]; then
        echo " > DONE!" >>$LOG
        echo -e ${GREN}" > DONE!"${ENDCOLOR}
    else
        echo " > Something went wrong!" >>$LOG
        echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
        exit 1
    fi

}

#mysql_user_check() {
#
#    # $1 = ${USER}
#    # $2 = ${USER_PSW}
#    # $3 = ${DB}
#
#    # TODO: check if user can connect to database
#
#}

# TODO: PROBAR ESTO Y RETORNAR VARIABLE
mysql_get_disk_usage() {

    SQL1="SELECT SUM( data_length + index_length ) / 1024 / 1024 'Size'
        FROM information_schema.TABLES WHERE table_schema='$1'"

    mysql -u ${MUSER} -p${MPASS} -e "${SQL1}" >>$LOG

    if [ $? -eq 0 ]; then
        echo " > DONE!" >>$LOG
        echo -e ${GREN}" > DONE!"${ENDCOLOR}
    else
        echo " > Something went wrong!" >>$LOG
        echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
        exit 1
    fi

}
