#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc06
#############################################################################

### Checking some things...#####################################################
SFOLDER="`dirname \"$0\"`"                                                      # relative
SFOLDER="`( cd \"$SFOLDER\" && pwd )`"   

if [ -z "$SFOLDER" ]; then
  exit 1  # error; the path is not accessible
fi

# Temp folder
BAKWP="${SFOLDER}/tmp"

# MySQL host and user
MHOST="localhost"
MUSER="root"

# Backup rotation vars
NOW=$(date +"%Y-%m-%d")
NOWDISPLAY=$(date +"%d-%m-%Y")
ONEWEEKAGO=$(date --date='7 days ago' +"%Y-%m-%d")

export MHOST MUSER NOW NOWDISPLAY ONEWEEKAGO

# BROOBE Utils config file
if test -f /root/.broobe-utils-options; then
  source /root/.broobe-utils-options
fi

# Cloudflare config file
CLF_CONFIG_FILE=~/.cloudflare.conf
if [[ -e ${CLF_CONFIG_FILE} ]]; then
    # shellcheck source=${CLF_CONFIG_FILE}
    source "${CLF_CONFIG_FILE}"
else
    generate_cloudflare_config
fi

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"
# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"
# shellcheck source=${SFOLDER}/libs/packages_helper.sh
source "${SFOLDER}/libs/packages_helper.sh"
# shellcheck source=${SFOLDER}/libs/backup_helper.sh
source "${SFOLDER}/libs/backup_helper.sh"
# shellcheck source=${SFOLDER}/libs/mysql_helper.sh
source "${SFOLDER}/libs/mysql_helper.sh"
# shellcheck source=${SFOLDER}/libs/cloudflare_helper.sh
source "${SFOLDER}/libs/cloudflare_helper.sh"

####################### TEST FOR mail_cert_section #######################

test_cert_mail(){
    echo -e ${B_CYAN}" > TESTING FUNCTION: test_cert_mail"${B_ENDCOLOR}
    mail_cert_section

    CERT_MAIL="${BAKWP}/cert-${NOW}.mail"
    CERT_MAIL_VAR=$(<${CERT_MAIL})

    echo -e ${GREEN}" > Sending Email to ${MAILA} ..."${ENDCOLOR}

    EMAIL_SUBJECT="${STATUS_ICON_D} ${VPSNAME} - Cert Expiration Info - [${NOWDISPLAY}]"
    EMAIL_CONTENT="${HTMLOPEN} ${BODY_SRV} ${CERT_MAIL_VAR} ${MAIL_FOOTER}"

    # Sending email notification
    echo -e ${B_GREEN}" > send_mail_notification: ${EMAIL_SUBJECT}"${ENDCOLOR}
    send_mail_notification "${EMAIL_SUBJECT}" "${EMAIL_CONTENT}"

}

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

####################### TEST FOR mysql_database_exists #######################

test_mysql_database_exists(){

    echo -e ${B_CYAN}" > TESTING FUNCTION: mysql_database_exists"${B_ENDCOLOR}

    MYSQL_DB_TO_TEST="multiplacas_test2"
    
    DB_EXISTS=$(mysql_database_exists "${MYSQL_DB_TO_TEST}")

    echo "${DB_EXISTS}"

    if [[ ${DB_EXISTS} -eq 1 ]]; then
        echo -e ${B_RED}" > MySQL DB: ${MYSQL_DB_TO_TEST} doesn't exists!"${ENDCOLOR}

    else
        echo -e ${B_GREEN}" > MySQL DB ${MYSQL_DB_TO_TEST} already exists"${ENDCOLOR}

    fi

}

################################################################################
# MAIN
################################################################################

#test_mysql_user_exists
#test_mysql_database_exists

#test_cert_mail

#to_test="/var/www/goseries-master"
#is_wp_project "$to_test"

cloudflare_change_a_record "dwell.com.ar" "test.dwell.com.ar"
