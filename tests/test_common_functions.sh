#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.5
#############################################################################

function test_common_funtions() {

    #test_get_root_domain
    #test_get_subdomain_part
    #test_extract_domain_extension
    #test_jsonify_function_return
    test_json_write_function

}

function test_get_root_domain() {

    local result

    log_subsection "Test: domain_get_root"

    result="$(domain_get_root "www.gauchocode.com")"
    if [[ ${result} = "gauchocode.com" ]]; then
        display --indent 6 --text "- domain_get_root result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_root with www.gauchocode.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_root "dev.gauchocode.com")"
    if [[ ${result} = "gauchocode.com" ]]; then
        display --indent 6 --text "- domain_get_root result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_root with www.gauchocode.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_root "dev.www.gauchocode.com")"
    if [[ ${result} = "gauchocode.com" ]]; then
        display --indent 6 --text "- domain_get_root result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_root with dev.www.gauchocode.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_root "gauchocode.hosting")"
    if [[ ${result} = "gauchocode.hosting" ]]; then
        display --indent 6 --text "- domain_get_root result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_root with gauchocode.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_root "www.gauchocode.hosting")"
    if [[ ${result} = "gauchocode.hosting" ]]; then
        display --indent 6 --text "- domain_get_root result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_root with www.gauchocode.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_root "www.dev.gauchocode.hosting")"
    if [[ ${result} = "gauchocode.hosting" ]]; then
        display --indent 6 --text "- domain_get_root result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_root with www.dev.gauchocode.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

}

function test_get_subdomain_part() {

    local result

    log_subsection "Test: domain_get_subdomain_part"

    result="$(domain_get_subdomain_part "www.gauchocode.com")"
    if [[ ${result} = "www" ]]; then
        display --indent 6 --text "- domain_get_subdomain_part result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_subdomain_part with www.gauchocode.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_subdomain_part "gauchocode.com")"
    if [[ ${result} = "" ]]; then
        display --indent 6 --text "- domain_get_subdomain_part result 'empty_response'" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_subdomain_part with gauchocode.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_subdomain_part "test.gauchocode.com")"
    if [[ ${result} = "test" ]]; then
        display --indent 6 --text "- domain_get_subdomain_part result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_subdomain_part with test.gauchocode.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_subdomain_part "test.01.gauchocode.com")"
    if [[ ${result} = "test.01" ]]; then
        display --indent 6 --text "- domain_get_subdomain_part result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_subdomain_part with test.01.gauchocode.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_subdomain_part "dev.prueba.gauchocode.hosting")"
    if [[ ${result} = "dev.prueba" ]]; then
        display --indent 6 --text "- domain_get_subdomain_part result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_subdomain_part with dev.prueba.gauchocode.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

}

function test_extract_domain_extension() {

    local result

    log_subsection "Testing Domain Functions"

    result="$(domain_extract_extension "gauchocode.com")"
    if [[ ${result} = "gauchocode" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with gauchocode.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "gauchocode.com.ar")"
    if [[ ${result} = "gauchocode" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with gauchocode.com.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "gauchocode.ar")"
    if [[ ${result} = "gauchocode" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with gauchocode.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "test.gauchocode.com.ar")"
    if [[ ${result} = "test.gauchocode" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with test.gauchocode.com.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "old.test.gauchocode.com.ar")"
    if [[ ${result} = "old.test.gauchocode" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with old.test.gauchocode.com.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "old.test.gauchocode.ar")"
    if [[ ${result} = "old.test.gauchocode" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with old.test.gauchocode.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "old.dev.test.gauchocode.com")"
    if [[ ${result} = "old.dev.test.gauchocode" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with old.dev.test.gauchocode.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "old.dev.test.gauchocode")"
    if [[ ${result} = "" ]]; then
        display --indent 6 --text "- domain_extract_extension result 'empty response'" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with old.dev.test.gauchocode" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "old.dev.test.gauchocode.hosting")"
    if [[ ${result} = "old.dev.test.gauchocode" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with old.dev.test.gauchocode.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "old.dev.test.gauchocode.com.ar")"
    if [[ ${result} = "old.dev.test.gauchocode" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with old.dev.test.gauchocode.com.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

}

function test_jsonify_function_return() {

    local config_file
    local config_field
    local server_roles

    log_subsection "jsonify_function_return"

    databases="$(mysql_list_databases "all" "")"

    jsonify_output "value-list" "${databases}"

    string_to_test="function_example_name function_example_return"

    jsonify_output "key-value" "${string_to_test}"

}

function test_json_write_function() {

    local config_file
    local config_field
    local server_roles

    log_subsection "json_write_function"

    config_file="assets/brolit_shell.conf"

    config_field="SERVER_ROLES.config[].webserver"

    server_roles="true"

    # Write json
    json_write_field "${config_file}" "${config_field}" "${server_roles}"

    # Read json
    config_value="$(json_read_field "${config_file}" "${config_field}")"

    if [[ ${config_value} == "true" ]]; then
        display --indent 6 --text "- result: ${config_value}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- result: ${config_value}" --result "FAIL" --color RED
    fi

}
