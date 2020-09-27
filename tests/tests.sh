#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.3
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

####################### Test for Mails #######################

test_mail_cert_section() {

    local email_subject
    local email_content
    
    display --indent 2 --text "- Running test_mail_cert_section"

    mail_cert_section

    CERT_MAIL="${BAKWP}/cert-${NOW}.mail"
    CERT_MAIL_VAR=$(<"${CERT_MAIL}")

    # Preparing email to send
    log_event "info" "Sending Email to ${MAILA} ..." "false"

    email_subject="${STATUS_ICON_D} ${VPSNAME} - Cert Expiration Info - [${NOWDISPLAY}]"
    email_content="${HTMLOPEN} ${BODY_SRV} ${CERT_MAIL_VAR} ${MAIL_FOOTER}"

    # Sending email notification
    send_mail_notification "${email_subject}" "${email_content}"

    clear_last_line
    display --indent 2 --text "- Running test_mail_cert_section" --result "DONE" --color GREEN

}

test_mail_package_section() {

    display --indent 2 --text "- Running test_mail_package_section"

    # Compare package versions
    mail_package_status_section "${PKG_DETAILS}"
    PKG_MAIL="${BAKWP}/pkg-${NOW}.mail"
    PKG_MAIL_VAR=$(<"${PKG_MAIL}")

    # Preparing email to send
    log_event "info" "Sending Email to ${MAILA} ..." "false"

    email_subject="${EMAIL_STATUS} on ${VPSNAME} Packages Status Info - [${NOWDISPLAY}]"
    email_content="${HTMLOPEN} ${BODY_SRV} ${PKG_MAIL_VAR} ${MAIL_FOOTER}"

    # Sending email notification
    send_mail_notification "${email_subject}" "${email_content}"

    clear_last_line
    display --indent 2 --text "- Running test_mail_package_section" --result "DONE" --color GREEN

}

####################### TEST FOR ask_mysql_root_psw #######################

test_ask_mysql_root_psw() {
    echo -e "${B_CYAN} > TESTING FUNCTION: ask_mysql_root_psw${B_ENDCOLOR}"
    ask_mysql_root_psw
}

####################### TEST FOR mysql_user_exists #######################

test_mysql_user_exists() {

    local mysql_user_test

    echo -e "${B_CYAN} > TESTING FUNCTION: mysql_user_exists${B_ENDCOLOR}"

    mysql_user_test="modernschool_user"
    
    mysql_user_exists "${mysql_user_test}"
    
    user_db_exists=$?

    if [[ ${user_db_exists} -eq 0 ]]; then
        log_event "warning" "MySQL User ${mysql_user_test} doesn't exists" "false"

    else
        log_event "warning" "MySQL User ${mysql_user_test} already exists" "false"

    fi

}

####################### TEST FOR mysql_database_exists #######################

test_mysql_database_exists() {

    local mysql_db_test

    log_event "warning" "TESTING FUNCTION: mysql_database_exists" "false"

    mysql_db_test="multiplacas_test2"
    
    mysql_database_exists "${mysql_db_test}"

    db_exists=$?
    if [[ ${db_exists} -eq 1 ]]; then 
        log_event "warning" "MySQL DB ${mysql_db_test} doesn't exists" "false"

    else
        log_event "warning" "MySQL DB ${mysql_db_test} already exists" "false"

    fi

}

test_display_functions() {

    test_mail_package_section

    log_subsection "Testing display 1"

    display --indent 2 --text "- Testing message on console" --result "DONE" --color GREEN
    display --indent 2 --text "- Testing message on console" --result "WARNING" --color YELLOW
    display --indent 2 --text "- Testing message on console" --tcolor RED --result "ERROR" --color RED

    log_subsection "Testing display 2"

    display --indent 2 --text "- Testing message on console" --result "DONE" --color GREEN
    display --indent 2 --text "- Testing message on console" --result "DONE" --color GREEN
    display --indent 2 --text "- Testing message on console" --result "WARNING" --color YELLOW

    #sleep 3

    #clear_last_line

    log_break "true"

    #clear_screen

    #log_break "true"

}

test_cloudflare_change_a_record() {

    cloudflare_change_a_record "pacientesenred.com.ar" "test.pacientesenred.com.ar" "0"

}

################################################################################
# MAIN
################################################################################

log_section "Running Tests"

#log_subsection "Testing display functions"

#test_display_functions

#log_subsection "Testing mail functions"

#test_mail_cert_section

#test_mail_package_section

test_cloudflare_change_a_record

#test_mysql_user_exists
#test_mysql_database_exists

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

