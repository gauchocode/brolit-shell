#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.8
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
    
    log_subsection "Test: test_mail_cert_section"

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
    display --indent 6 --text "- test_mail_cert_section" --result "DONE" --color WHITE

}

test_mail_package_section() {

    log_subsection "Test: test_mail_package_section"

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
    display --indent 6 --text "- test_mail_package_section" --result "DONE" --color WHITE

}

####################### TEST FOR mysql_helper #######################

test_mysql_helper() {

    #test_ask_mysql_root_psw
    test_mysql_user_create
    test_mysql_user_exists
    test_mysql_user_delete
    test_mysql_database_create
    test_mysql_database_exists
    test_mysql_database_drop

}

test_ask_mysql_root_psw() {

    log_subsection "Test: test_ask_mysql_root_psw"

    ask_mysql_root_psw

}

test_mysql_user_create() {

    local db_user

    log_subsection "Test: test_mysql_user_create"
    
    # DB user
    db_user="test_user"

    # Passw generator
    db_pass="$(openssl rand -hex 12)"

    mysql_user_create "${db_user}" "${db_pass}"
    user_create="$?"
    if [[ ${user_create} -eq 0 ]]; then
        display --indent 6 --text "- mysql_user_create" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- mysql_user_create" --result "FAIL" --color RED
    fi

    log_break "true"

}

test_mysql_user_exists() {

    local db_user

    log_subsection "Test: mysql_user_exists"

    # DB User
    db_user="test_user"
    
    mysql_user_exists "${db_user}"
    user_db_exists="$?"
    if [[ ${user_db_exists} -eq 0 ]]; then
        display --indent 6 --text "- mysql_user_exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- mysql_user_exists" --result "FAIL" --color RED
    fi

    log_break "true"

}

test_mysql_user_delete() {

    local db_user

    log_subsection "Test: mysql_user_delete"

    # DB User
    db_user="test_user"
    
    mysql_user_delete "${db_user}"
    user_delete="$?"
    if [[ ${user_delete} -eq 0 ]]; then
        display --indent 6 --text "- test_mysql_user_delete" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_mysql_user_delete" --result "FAIL" --color RED
    fi

    log_break "true"

}

test_mysql_database_create() {

    local mysql_db_test

    log_subsection "Test: test_mysql_database_create"

    mysql_db_test="test_db"
    
    mysql_database_create "${mysql_db_test}"
    database_create="$?"
    if [[ ${database_create} -eq 0 ]]; then 
        display --indent 6 --text "- test_mysql_database_create" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_mysql_database_create" --result "FAIL" --color RED
    fi

    log_break "true"

}

test_mysql_database_exists() {

    local mysql_db_test

    log_subsection "Test: test_mysql_database_exists"

    mysql_db_test="test_db"
    
    mysql_database_exists "${mysql_db_test}"
    database_exists=$?
    if [[ ${database_exists} -eq 0 ]]; then 
        display --indent 6 --text "- test_mysql_database_exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_mysql_database_exists" --result "FAIL" --color RED
    fi

    log_break "true"

}

test_mysql_database_drop() {

    local mysql_db_test

    log_subsection "Test: test_mysql_database_drop"

    mysql_db_test="test_db"
    
    mysql_database_drop "${mysql_db_test}"
    database_drop="$?"
    if [[ ${database_drop} -eq 0 ]]; then 
        display --indent 6 --text "- test_mysql_database_drop" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_mysql_database_drop" --result "FAIL" --color RED
    fi

    log_break "true"

}

####################### TEST FOR commons #######################

test_common_funtions() {

    test_display_functions
    test_get_root_domain
    test_extract_domain_extension

}

test_display_functions() {

    log_subsection "Testing display 1"

    display --indent 6 --text "- Testing message DONE" --result "DONE" --color WHITE
    display --indent 6 --text "- Testing message WARNING" --result "WARNING" --color YELLOW
    display --indent 6 --text "- Testing message ERROR" --result "ERROR" --color RED
    display --indent 8 --text "Testing output ERROR" --tcolor RED

    log_subsection "Testing display 2"

    display --indent 6 --text "- Testing message with color" --result "DONE" --color WHITE
    display --indent 8 --text "Testing output DONE" --tcolor WHITE --tstyle CURSIVE
    display --indent 6 --text "- Testing message with color" --result "DONE" --color WHITE
    display --indent 8 --text "Testing output WHITE in ITALIC" --tcolor WHITE --tstyle ITALIC
    display --indent 6 --text "- Testing message with color" --result "WARNING" --color YELLOW
    display --indent 8 --text "Testing output WARNING" --tcolor YELLOW

    log_break "true"

}

test_get_root_domain() {

    log_subsection "Test: get_root_domain"

    result="$(get_root_domain "www.broobe.com")"
    if [[ ${result} = "broobe.com" ]]; then 
        display --indent 6 --text "- get_root_domain with www.broobe.com" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with www.broobe.com" --result "FAIL" --color RED
    fi

    result="$(get_root_domain "dev.broobe.com")"
    if [[ ${result} = "broobe.com" ]]; then 
        display --indent 6 --text "- get_root_domain with www.broobe.com" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with www.broobe.com" --result "FAIL" --color RED
    fi

    result="$(get_root_domain "dev.www.broobe.com")"
    if [[ ${result} = "broobe.com" ]]; then 
        display --indent 6 --text "- get_root_domain with dev.www.broobe.com" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with dev.www.broobe.com" --result "FAIL" --color RED
    fi

    result="$(get_root_domain "broobe.hosting")"
    if [[ ${result} = "broobe.hosting" ]]; then 
        display --indent 6 --text "- get_root_domain with broobe.hosting" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with broobe.hosting" --result "FAIL" --color RED
    fi

    result="$(get_root_domain "www.broobe.hosting")"
    if [[ ${result} = "broobe.hosting" ]]; then 
        display --indent 6 --text "- get_root_domain with www.broobe.hosting" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with www.broobe.hosting" --result "FAIL" --color RED
    fi

    result="$(get_root_domain "www.dev.broobe.hosting")"
    if [[ ${result} = "broobe.hosting" ]]; then 
        display --indent 6 --text "- get_root_domain with www.dev.broobe.hosting" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with www.dev.broobe.hosting" --result "FAIL" --color RED
    fi
}

test_extract_domain_extension() {

    log_subsection "Testing Domain Functions"

    result="$(extract_domain_extension "broobe.com")"
    if [[ ${result} = ".com" ]]; then 
        display --indent 6 --text "- get_root_domain with broobe.com" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with broobe.com" --result "FAIL" --color RED
    fi

    result="$(extract_domain_extension "broobe.com.ar")"
    if [[ ${result} = ".com.ar" ]]; then 
        display --indent 6 --text "- get_root_domain with broobe.com.ar" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with broobe.com.ar" --result "FAIL" --color RED
    fi

    result="$(extract_domain_extension "broobe.ar")"
    if [[ ${result} = ".ar" ]]; then 
        display --indent 6 --text "- get_root_domain with broobe.ar" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with broobe.ar" --result "FAIL" --color RED
    fi

    result="$(extract_domain_extension "test.broobe.com.ar")"
    if [[ ${result} = ".com.ar" ]]; then 
        display --indent 6 --text "- get_root_domain with test.broobe.com.ar" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with test.broobe.com.ar" --result "FAIL" --color RED
    fi

    result="$(extract_domain_extension "old.test.broobe.com.ar")"
    if [[ ${result} = ".com.ar" ]]; then 
        display --indent 6 --text "- get_root_domain with old.test.broobe.com.ar" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with old.test.broobe.com.ar" --result "FAIL" --color RED
    fi

    result="$(extract_domain_extension "old.test.broobe.ar")"
    if [[ ${result} = ".ar" ]]; then 
        display --indent 6 --text "- get_root_domain with old.test.broobe.ar" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with old.test.broobe.ar" --result "FAIL" --color RED
    fi

    result="$(extract_domain_extension "old.dev.test.broobe.com")"
    if [[ ${result} = ".com" ]]; then 
        display --indent 6 --text "- get_root_domain with old.dev.test.broobe.com" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with old.dev.test.broobe.com" --result "FAIL" --color RED
    fi

    result="$(extract_domain_extension "old.dev.test.broobe")"
    if [[ ${result} = 1 ]]; then 
        display --indent 6 --text "- get_root_domain with old.dev.test.broobe" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with old.dev.test.broobe" --result "FAIL" --color RED
    fi

    result="$(get_root_domain "old.dev.test.broobe.hosting")"
    if [[ ${result} = ".hosting" ]]; then 
        display --indent 6 --text "- get_root_domain with old.dev.test.broobe.hosting" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with old.dev.test.broobe.hosting" --result "FAIL" --color RED
    fi

    result="$(get_root_domain "old.dev.test.broobe.com.ar")"
    if [[ ${result} = ".com.ar" ]]; then 
        display --indent 6 --text "- get_root_domain with old.dev.test.broobe.com.ar" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with old.dev.test.broobe.com.ar" --result "FAIL" --color RED
    fi

}

####################### TEST FOR cloudflare_helper #######################

test_cloudflare_funtions() {

    test_cloudflare_domain_exists
    test_cloudflare_change_a_record
    test_cloudflare_delete_a_record
    test_cloudflare_clear_cache

}

test_cloudflare_domain_exists() {

    log_subsection "Test: test_cloudflare_domain_exists"

    cloudflare_domain_exists "pacientesenred.com.ar"
    cf_result="$?"
    if [[ ${cf_result} -eq 0 ]]; then 
        display --indent 6 --text "- cloudflare_domain_exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- cloudflare_domain_exists" --result "FAIL" --color RED
    fi
    log_break "true"

    cloudflare_domain_exists "www.pacientesenred.com.ar"
    cf_result="$?"
    if [[ ${cf_result} -eq 1 ]]; then 
        display --indent 6 --text "- cloudflare_domain_exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- cloudflare_domain_exists" --result "FAIL" --color RED
    fi
    log_break "true"

    cloudflare_domain_exists "machupichu.com"
    cf_result="$?"
    if [[ ${cf_result} -eq 1 ]]; then 
        display --indent 6 --text "- cloudflare_domain_exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- cloudflare_domain_exists" --result "FAIL" --color RED
    fi
    log_break "true"

}

test_cloudflare_change_a_record() {

    log_subsection "Test: test_cloudflare_change_a_record"

    cloudflare_change_a_record "broobe.hosting" "bash.broobe.hosting" "false"
    cf_result="$?"
    if [[ ${cf_result} -eq 0 ]]; then 
        display --indent 6 --text "- test_cloudflare_change_a_record" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_cloudflare_change_a_record" --result "FAIL" --color RED
    fi
    log_break "true"

}

test_cloudflare_delete_a_record() {

    log_subsection "Test: test_cloudflare_delete_a_record"

    cloudflare_delete_a_record "broobe.hosting" "bash.broobe.hosting" "false"
    cf_result="$?"
    if [[ ${cf_result} -eq 0 ]]; then 
        display --indent 6 --text "- test_cloudflare_delete_a_record" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_cloudflare_delete_a_record" --result "FAIL" --color RED
    fi
    log_break "true"

}

test_cloudflare_clear_cache() {

    log_subsection "Test: test_cloudflare_clear_cache"

    cloudflare_clear_cache "broobe.hosting"
    cf_result="$?"
    if [[ ${cf_result} -eq 0 ]]; then 
        display --indent 6 --text "- test_cloudflare_clear_cache" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_cloudflare_clear_cache" --result "FAIL" --color RED
    fi
    log_break "true"

}

################################################################################
# MAIN
################################################################################

log_section "Running Tests Suite"

test_display_functions

test_common_funtions

test_mysql_helper

test_cloudflare_funtions

################################################################################
# Uncomment to run specific function
################################################################################

#test_mail_cert_section

#test_mail_package_section

#to_test="/var/www/goseries-master"
#is_wp_project "$to_test"

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

