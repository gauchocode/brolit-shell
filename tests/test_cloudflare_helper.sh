#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.5
#############################################################################

function test_cloudflare_funtions() {

    test_cloudflare_domain_exists
    test_cloudflare_set_record
    test_cloudflare_get_record_details
    test_cloudflare_delete_record
    test_cloudflare_clear_cache

}

function test_cloudflare_domain_exists() {

    log_subsection "Test: test_cloudflare_domain_exists"

    cloudflare_domain_exists "pacientesenred.com.ar"
    cf_result=$?
    if [[ ${cf_result} -eq 0 ]]; then 
        display --indent 6 --text "- cloudflare_domain_exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- cloudflare_domain_exists" --result "FAIL" --color RED
    fi
    log_break "true"

    cloudflare_domain_exists "www.pacientesenred.com.ar"
    cf_result=$?
    if [[ ${cf_result} -eq 1 ]]; then 
        display --indent 6 --text "- cloudflare_domain_exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- cloudflare_domain_exists" --result "FAIL" --color RED
    fi
    log_break "true"

    cloudflare_domain_exists "machupichu.com"
    cf_result=$?
    if [[ ${cf_result} -eq 1 ]]; then 
        display --indent 6 --text "- cloudflare_domain_exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- cloudflare_domain_exists" --result "FAIL" --color RED
    fi

}

function test_cloudflare_set_record() {

    log_subsection "Test: test_cloudflare_set_record"

    cloudflare_set_record "gauchocode.hosting" "bash.gauchocode.hosting" "A" "false" "${SERVER_IP}"
    cf_result=$?
    if [[ ${cf_result} -eq 0 ]]; then 
        display --indent 6 --text "- test_cloudflare_set_record" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_cloudflare_set_record" --result "FAIL" --color RED
    fi

}

function test_cloudflare_delete_record() {

    log_subsection "Test: test_cloudflare_delete_record"

    cloudflare_delete_record "gauchocode.hosting" "bash.gauchocode.hosting"
    cf_result=$?
    if [[ ${cf_result} -eq 0 ]]; then 
        display --indent 6 --text "- test_cloudflare_delete_record" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_cloudflare_delete_record" --result "FAIL" --color RED
    fi

}

function test_cloudflare_clear_cache() {

    log_subsection "Test: test_cloudflare_clear_cache"

    cloudflare_clear_cache "gauchocode.hosting"
    cf_result=$?
    if [[ ${cf_result} -eq 0 ]]; then 
        display --indent 6 --text "- test_cloudflare_clear_cache" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_cloudflare_clear_cache" --result "FAIL" --color RED
    fi

}

function test_cloudflare_get_record_details() {

    log_subsection "Test: test_cloudflare_get_record_details"

    cloudflare_get_record_details "gauchocode.hosting" "bash.gauchocode.hosting" "id"
    cloudflare_get_record_details "gauchocode.hosting" "bash.gauchocode.hosting" "type"
    cloudflare_get_record_details "gauchocode.hosting" "bash.gauchocode.hosting" "content"
    cloudflare_get_record_details "gauchocode.hosting" "bash.gauchocode.hosting" "proxied"
    cloudflare_get_record_details "gauchocode.hosting" "bash.gauchocode.hosting" "created_on"
    cloudflare_get_record_details "gauchocode.hosting" "bash.gauchocode.hosting" "modified_on"

}