#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://example.com
# Version: 3.0.17
#############################################################################

function test_common_funtions() {

    test_get_root_domain
    test_extract_domain_extension

}

function test_get_root_domain() {

    log_subsection "Test: get_root_domain"

    result="$(get_root_domain "www.example.com")"
    if [[ ${result} = "example.com" ]]; then 
        display --indent 6 --text "- get_root_domain result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with www.example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(get_root_domain "dev.example.com")"
    if [[ ${result} = "example.com" ]]; then 
        display --indent 6 --text "- get_root_domain result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with www.example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(get_root_domain "dev.www.example.com")"
    if [[ ${result} = "example.com" ]]; then 
        display --indent 6 --text "- get_root_domain result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with dev.www.example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(get_root_domain "example.hosting")"
    if [[ ${result} = "example.hosting" ]]; then 
        display --indent 6 --text "- get_root_domain result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with example.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(get_root_domain "www.example.hosting")"
    if [[ ${result} = "example.hosting" ]]; then 
        display --indent 6 --text "- get_root_domain result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with www.example.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(get_root_domain "www.dev.example.hosting")"
    if [[ ${result} = "example.hosting" ]]; then 
        display --indent 6 --text "- get_root_domain result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- get_root_domain with www.dev.example.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

}

function test_extract_domain_extension() {

    log_subsection "Testing Domain Functions"

    result="$(extract_domain_extension "example.com")"
    if [[ ${result} = "broobe" ]]; then 
        display --indent 6 --text "- extract_domain_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- extract_domain_extension with example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(extract_domain_extension "example.ar")"
    if [[ ${result} = "broobe" ]]; then 
        display --indent 6 --text "- extract_domain_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- extract_domain_extension with example.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(extract_domain_extension "broobe.ar")"
    if [[ ${result} = "broobe" ]]; then 
        display --indent 6 --text "- extract_domain_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- extract_domain_extension with broobe.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(extract_domain_extension "test.example.ar")"
    if [[ ${result} = "test.broobe" ]]; then 
        display --indent 6 --text "- extract_domain_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- extract_domain_extension with test.example.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(extract_domain_extension "old.test.example.ar")"
    if [[ ${result} = "old.test.broobe" ]]; then 
        display --indent 6 --text "- extract_domain_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- extract_domain_extension with old.test.example.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(extract_domain_extension "old.test.broobe.ar")"
    if [[ ${result} = "old.test.broobe" ]]; then 
        display --indent 6 --text "- extract_domain_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- extract_domain_extension with old.test.broobe.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(extract_domain_extension "old.dev.test.example.com")"
    if [[ ${result} = "old.dev.test.broobe" ]]; then 
        display --indent 6 --text "- extract_domain_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- extract_domain_extension with old.dev.test.example.com" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(extract_domain_extension "old.dev.test.broobe")"
    if [[ ${result} = "" ]]; then 
        display --indent 6 --text "- extract_domain_extension result 'empty response'" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- extract_domain_extension with old.dev.test.broobe" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(extract_domain_extension "old.dev.test.example.hosting")"
    if [[ ${result} = "old.dev.test.broobe" ]]; then 
        display --indent 6 --text "- extract_domain_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- extract_domain_extension with old.dev.test.example.hosting" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

    result="$(extract_domain_extension "old.dev.test.example.ar")"
    if [[ ${result} = "old.dev.test.broobe" ]]; then 
        display --indent 6 --text "- extract_domain_extension result ${result}" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- extract_domain_extension with old.dev.test.example.ar" --result "FAIL" --color RED
        display --indent 6 --text "result: ${result}" --tcolor RED
    fi

}