#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-beta7
#############################################################################

### Checking some things...#####################################################
SFOLDER="`dirname \"$0\"`"                                                      # relative
SFOLDER="`( cd \"$SFOLDER\" && pwd )`"   

if [ -z "$SFOLDER" ]; then
  exit 1  # error; the path is not accessible
fi

# MySQL host and user
MHOST="localhost"
MUSER="root"

# BROOBE Utils config file
if test -f /root/.broobe-utils-options; then
  source /root/.broobe-utils-options
fi

source ${SFOLDER}/libs/commons.sh
source ${SFOLDER}/libs/mysql_helper.sh

####################### TEST FOR ask_mysql_root_psw #######################

test_ask_mysql_root_psw(){
    echo -e ${B_CYAN}" > TESTING FUNCTION: ask_mysql_root_psw"${B_ENDCOLOR}
    ask_mysql_root_psw
}

####################### TEST FOR mysql_user_exists #######################

test_mysql_user_exists(){

    echo -e ${B_CYAN}" > TESTING FUNCTION: mysql_user_exists"${B_ENDCOLOR}

    MYSQL_USER_TO_TEST="modernschool_user"
    
    USER_DB_EXISTS=$(mysql_user_exists "${MYSQL_USER_TO_TEST}")

    echo $USER_DB_EXISTS

    if [[ ${USER_DB_EXISTS} -eq 0 ]]; then
        echo -e ${B_RED}" > MySQL user: ${MYSQL_USER_TO_TEST} doesn't exists!"${ENDCOLOR}

    else
        echo -e ${B_GREEN}" > User ${MYSQL_USER_TO_TEST} already exists"${ENDCOLOR}

    fi

}

################################################################################
# MAIN
################################################################################

#test_mysql_user_exists