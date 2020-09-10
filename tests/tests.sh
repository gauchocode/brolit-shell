#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc10
#############################################################################

### Main dir check
SFOLDER=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
SFOLDER=$( cd "$( dirname "${SFOLDER}" )" && pwd )
if [ -z "${SFOLDER}" ]; then
  exit 1  # error; the path is not accessible
fi

# shellcheck source=${SFOLDER}/libs/commons.sh
source "${SFOLDER}/libs/commons.sh"

################################################################################

script_init

# shellcheck source=${SFOLDER}/libs/mail_notification_helper.sh
source "${SFOLDER}/libs/mail_notification_helper.sh"
# shellcheck source=${SFOLDER}/libs/telegram_notification_helper.sh
source "${SFOLDER}/libs/telegram_notification_helper.sh"
# shellcheck source=${SFOLDER}/libs/wordpress_helper.sh
source "${SFOLDER}/libs/wordpress_helper.sh"
# shellcheck source=${SFOLDER}/libs/wpcli_helper.sh
source "${SFOLDER}/libs/wpcli_helper.sh"

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
    
    mysql_user_exists "${MYSQL_USER_TO_TEST}"
    
    user_db_exists=$?

    if [[ ${user_db_exists} -eq 0 ]]; then
        echo -e ${B_RED}" > MySQL user: ${MYSQL_USER_TO_TEST} doesn't exists!"${ENDCOLOR}

    else
        echo -e ${B_GREEN}" > User ${MYSQL_USER_TO_TEST} already exists"${ENDCOLOR}

    fi

}

####################### TEST FOR mysql_database_exists #######################

test_mysql_database_exists(){

    echo -e ${B_CYAN}" > TESTING FUNCTION: mysql_database_exists"${B_ENDCOLOR}

    MYSQL_DB_TO_TEST="multiplacas_test2"
    
    mysql_database_exists "${MYSQL_DB_TO_TEST}"

    db_exists=$?
    if [[ ${db_exists} -eq 1 ]]; then 
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

#cloudflare_change_a_record "domain.com" "test.domain.com"

#nginx_server_change_phpv "domain.com" "7.4"

#startdir=${SITES}
#menutitle="Site Selection Menu"

#directory_browser "$menutitle" "$startdir"
#WP_SITE=$filepath"/"$filename

#echo -e ${B_GREEN}" > WP_SITE=${WP_SITE}"${ENDCOLOR}
#install_path=$(search_wp_config "${WP_SITE}")
#echo -e ${B_GREEN}" > install_path=${install_path}"${ENDCOLOR}

#wpcli_core_reinstall "${install_path}"

#wpcli_delete_not_core_files "${install_path}"

#mapfile -t wpcli_plugin_verify_results < <( wpcli_plugin_verify "${install_path}" )

#for wpcli_plugin_verify_result in "${wpcli_plugin_verify_results[@]}"
#do
#   echo " > ${wpcli_plugin_verify_result}"
#done

#wpcli_force_reinstall_plugins "${install_path}"

#install_crontab_script "${SFOLDER}/test.sh" "01" "00"

#telegram_send_message "LEMPT UTILS SCRIPT NOTIFICATION TEST"

log_section "Testing Titles"

display --indent 2 --text "- Testing message on console" --result "DONE" --color GREEN

display --indent 2 --text "- Testing message on console" --result "WARNING" --color YELLOW

display --indent 2 --text "- Testing message on console" --tcolor RED --result "ERROR" --color RED

display --indent 2 --text "- Testing message on console" --result "WARNING" --color YELLOW

sleep 5

clear_last_line

log_break "true"

#clear_screen

#log_break "true"