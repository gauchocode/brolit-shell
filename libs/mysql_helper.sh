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

# TODO: agregar control de error de mysql y mysqldump

mysql_databases_list() {

    DBS="$(${MYSQL} -u ${MUSER} -p${MPASS} -Bse 'show databases')"

}

mysql_user_create() {

    # TODO: Checkear si el usuario ya existe
    # TODO: el GRANT USAGE debería ser otro método

    # $1 USER (${PROJECT_NAME}_user)

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

    # $1 USER (${PROJECT_NAME}_user)

    SQL1="DROP USER '$1'@'localhost';"
    SQL2="FLUSH PRIVILEGES;"

    echo "Deleting $1 user in MySQL ..." >>$LOG
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

    # $1 USER (${PROJECT_NAME}_user)
    # $2 PASSWORD

    SQL1="ALTER USER '$1'@'localhost' IDENTIFIED BY '$2';"
    SQL2="FLUSH PRIVILEGES;"

    echo "Deleting $1 user in MySQL ..." >>$LOG
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

    # $1 DB ($PROJECT_NAME_$PROJECT_STATE)

    SQL1="CREATE DATABASE IF NOT EXISTS $1;"

    echo "Creating $1 database in MySQL ..." >>$LOG
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

    # $1 DB ($PROJECT_NAME_$PROJECT_STATE)

    SQL1="DROP DATABASE $1;"

    echo "Droping database $1 ..." >>$LOG
    mysql -u ${MUSER} -p${MPASS} -e "${SQL1}" >>$LOG

    if [ $? -eq 0 ]; then
        echo " > Database $1 deleted!" >>$LOG
        echo -e ${GREN}" > Database $1 deleted!"${ENDCOLOR}
    else
        echo " > Something went wrong!" >>$LOG
        echo -e ${RED}" > Something went wrong!"${ENDCOLOR}
        exit 1
    fi

}

mysql_database_import() {

    # $1 DATABASE
    # $2 DUMP_FILE

    echo -e ${YELLOW}" > Importing dump file $2 into database: $1 ..."${ENDCOLOR}
    echo " > Importing dump file $2 into database: $1 ..." >>$LOG
    #mysql -u ${MUSER} -p${MPASS} $1 < $2
    pv $2 | mysql -f -u ${MUSER} -p ${MPASS} -f -D $1

}

#mysql_database_check() {
#
#    # $1 DB ($PROJECT_NAME_$PROJECT_STATE)
#
#    # TODO: check if database exists
#
#}

mysql_database_export() {

    # $1 DATABASE
    # $2 DUMP_FILE

    echo -e ${YELLOW}" > Exporting database $1 into dump file $2 ..."${ENDCOLOR}
    echo " > Exporting database $1 into dump file $2 ..." >>$LOG
    mysqldump -u ${MUSER} -p${MPASS} $1 >$2

    if [ $? -eq 0 ]; then
        echo " > DB ${CHOSEN_BACKUP} exported successfully!" >>$LOG
        echo -e ${GREEN}" > DB ${CHOSEN_BACKUP} exported successfully!"${ENDCOLOR}
    else
        echo " > DB ${CHOSEN_BACKUP} export failed!" >>$LOG
        echo -e ${RED}" > DB ${CHOSEN_BACKUP} export failed!"${ENDCOLOR}
        exit 1
    fi

}

mysql_user_grant_privileges() {

    # $1 USER (${PROJECT_NAME}_user)
    # $2 DB ($PROJECT_NAME_$PROJECT_STATE)

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
#    # $1 USER (${PROJECT_NAME}_user)
#    # $2 USER_PSW
#    # $3 DB ($PROJECT_NAME_$PROJECT_STATE)
#
#    # TODO: check if user can connect to database
#
#}

# TODO: PROBAR ESTO Y RETORNAR A VARIABLE
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
