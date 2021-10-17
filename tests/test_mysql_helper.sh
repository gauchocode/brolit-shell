#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.63
#############################################################################

function test_mysql_helper() {

    # TODO tests for:
    #   mysql_name_sanitize
    #   mysql_user_psw_change

    #test_mysql_ask_root_psw
    #test_mysql_test_user_credentials
    test_mysql_user_create
    test_mysql_user_exists
    test_mysql_user_delete
    test_mysql_database_create
    test_mysql_database_exists
    test_mysql_database_export
    test_mysql_database_drop

}

function test_mysql_test_user_credentials() {

    log_subsection "Test: test_mysql_test_user_credentials"

    mysql_test_user_credentials "${MUSER}" "${MPASS}"
    user_credentials=$?
    if [[ ${user_credentials} -eq 0 ]]; then
        display --indent 6 --text "- mysql_test_user_credentials" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- mysql_test_user_credentials" --result "FAIL" --color RED
    fi

}

function test_mysql_ask_root_psw() {

    log_subsection "Test: test_mysql_ask_root_psw"

    mysql_ask_root_psw

}

function test_mysql_user_create() {

    local db_user

    log_subsection "Test: test_mysql_user_create"
    
    # DB user
    db_user="test_user"

    # Passw generator
    db_pass="$(openssl rand -hex 12)"

    mysql_user_create "${db_user}" "${db_pass}" "localhost"
    user_create=$?
    if [[ ${user_create} -eq 0 ]]; then
        display --indent 6 --text "- mysql_user_create" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- mysql_user_create" --result "FAIL" --color RED
    fi

}

function test_mysql_user_exists() {

    local db_user

    log_subsection "Test: mysql_user_exists"

    # DB User
    db_user="test_user"
    
    mysql_user_exists "${db_user}"
    db_user_exists=$?
    if [[ ${db_user_exists} -eq 1 ]]; then
        display --indent 6 --text "- mysql_user_exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- mysql_user_exists" --result "FAIL" --color RED
    fi

}

function test_mysql_user_delete() {

    local db_user

    log_subsection "Test: mysql_user_delete"

    # DB User
    db_user="test_user"
    
    mysql_user_delete "${db_user}"
    user_delete=$?
    if [[ ${user_delete} -eq 0 ]]; then
        display --indent 6 --text "- test_mysql_user_delete" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_mysql_user_delete" --result "FAIL" --color RED
    fi

}

function test_mysql_database_create() {

    local mysql_db_test

    log_subsection "Test: test_mysql_database_create"

    mysql_db_test="test_db"
    
    mysql_database_create "${mysql_db_test}"
    database_create=$?
    if [[ ${database_create} -eq 0 ]]; then 
        display --indent 6 --text "- test_mysql_database_create" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_mysql_database_create" --result "FAIL" --color RED
    fi

}

function test_mysql_database_exists() {

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

}


function test_mysql_database_export() {

    local mysql_db_test
    local dump_file

    log_subsection "Test: mysql_database_export"

    mysql_db_test="test_db"
    dump_file="database_export_test.sql"

    mysql_database_export "${mysql_db_test}" "${dump_file}"
    database_export=$?
    if [[ ${database_export} -eq 0 ]]; then 
        display --indent 6 --text "- test_mysql_database_export" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_mysql_database_export" --result "FAIL" --color RED
    fi

    #rm -f "${dump_file}"

}

function test_mysql_database_drop() {

    local mysql_db_test

    log_subsection "Test: test_mysql_database_drop"

    mysql_db_test="test_db"
    
    mysql_database_drop "${mysql_db_test}"
    database_drop=$?
    if [[ ${database_drop} -eq 0 ]]; then 
        display --indent 6 --text "- test_mysql_database_drop" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_mysql_database_drop" --result "FAIL" --color RED
    fi

}