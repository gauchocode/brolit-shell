#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://example.com
# Version: 3.2-rc7
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

    result="$(domain_get_root "www.example.com")"
    if [[ ${result} = "example.com" ]]; then
        display --indent 6 --text "- domain_get_root result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_root with www.example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_root "dev.example.com")"
    if [[ ${result} = "example.com" ]]; then
        display --indent 6 --text "- domain_get_root result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_root with www.example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_root "dev.www.example.com")"
    if [[ ${result} = "example.com" ]]; then
        display --indent 6 --text "- domain_get_root result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_root with dev.www.example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_root "example.hosting")"
    if [[ ${result} = "example.hosting" ]]; then
        display --indent 6 --text "- domain_get_root result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_root with example.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_root "www.example.hosting")"
    if [[ ${result} = "example.hosting" ]]; then
        display --indent 6 --text "- domain_get_root result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_root with www.example.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_root "www.dev.example.hosting")"
    if [[ ${result} = "example.hosting" ]]; then
        display --indent 6 --text "- domain_get_root result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_root with www.dev.example.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

}

function test_get_subdomain_part() {

    local result

    log_subsection "Test: domain_get_subdomain_part"

    result="$(domain_get_subdomain_part "www.example.com")"
    if [[ ${result} = "www" ]]; then
        display --indent 6 --text "- domain_get_subdomain_part result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_subdomain_part with www.example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_subdomain_part "example.com")"
    if [[ ${result} = "" ]]; then
        display --indent 6 --text "- domain_get_subdomain_part result 'empty_response'" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_subdomain_part with example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_subdomain_part "test.example.com")"
    if [[ ${result} = "test" ]]; then
        display --indent 6 --text "- domain_get_subdomain_part result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_subdomain_part with test.example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_subdomain_part "test.01.example.com")"
    if [[ ${result} = "test.01" ]]; then
        display --indent 6 --text "- domain_get_subdomain_part result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_subdomain_part with test.01.example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_get_subdomain_part "dev.prueba.example.hosting")"
    if [[ ${result} = "dev.prueba" ]]; then
        display --indent 6 --text "- domain_get_subdomain_part result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_get_subdomain_part with dev.prueba.example.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

}

function test_extract_domain_extension() {

    local result

    log_subsection "Testing Domain Functions"

    result="$(domain_extract_extension "example.com")"
    if [[ ${result} = "broobe" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "example.ar")"
    if [[ ${result} = "broobe" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with example.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "broobe.ar")"
    if [[ ${result} = "broobe" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with broobe.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "test.example.ar")"
    if [[ ${result} = "test.broobe" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with test.example.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "old.test.example.ar")"
    if [[ ${result} = "old.test.broobe" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with old.test.example.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "old.test.broobe.ar")"
    if [[ ${result} = "old.test.broobe" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with old.test.broobe.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "old.dev.test.example.com")"
    if [[ ${result} = "old.dev.test.broobe" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with old.dev.test.example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "old.dev.test.broobe")"
    if [[ ${result} = "" ]]; then
        display --indent 6 --text "- domain_extract_extension result 'empty response'" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with old.dev.test.broobe" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "old.dev.test.example.hosting")"
    if [[ ${result} = "old.dev.test.broobe" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with old.dev.test.example.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(domain_extract_extension "old.dev.test.example.ar")"
    if [[ ${result} = "old.dev.test.broobe" ]]; then
        display --indent 6 --text "- domain_extract_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- domain_extract_extension with old.dev.test.example.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

}

function test_jsonify_function_return() {

    local config_file
    local config_field
    local server_roles

    log_subsection "jsonify_function_return"

    databases="$(mysql_list_databases "all")"

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
