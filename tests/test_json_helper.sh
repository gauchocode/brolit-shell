#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc7
#############################################################################

function test_json_helper_funtions() {

    local brolit_config="assets/brolit_conf.json"

    NETDATA_CONFIG_STATUS="$(json_read_field "${brolit_config}" "SUPPORT.netdata[].status")"

    echo "NETDATA_CONFIG_STATUS=${NETDATA_CONFIG_STATUS}"

    json_write_field "${brolit_config}" "SUPPORT.netdata[].status" "enabled"

    NETDATA_CONFIG_STATUS="$(json_read_field "${brolit_config}" "SUPPORT.netdata[].status")"

    echo "NETDATA_CONFIG_STATUS=${NETDATA_CONFIG_STATUS}"

    if [[ "${NETDATA_CONFIG_STATUS}" == "enabled" ]]; then
        echo "PASSED"
    else
        echo "FAILED"
    fi

    #MONIT_CONFIG_SERVICES="$(json_read_field "${brolit_config}" "SUPPORT.monit[].config[].monit_services")"

    #echo "MONIT_CONFIG_SERVICES=${MONIT_CONFIG_SERVICES}"

    MONIT_CONFIG_SERVICES_REDIS="$(json_read_field "${brolit_config}" "SUPPORT.monit[].config[].monit_services[].redis")"

    echo "MONIT_CONFIG_SERVICES_REDIS=${MONIT_CONFIG_SERVICES_REDIS}"

    json_write_field "${brolit_config}" "SUPPORT.monit[].config[].monit_services[].redis" "enabled"

    MONIT_CONFIG_SERVICES_REDIS="$(json_read_field "${brolit_config}" "SUPPORT.monit[].config[].monit_services[].redis")"

    echo "MONIT_CONFIG_SERVICES_REDIS=${MONIT_CONFIG_SERVICES_REDIS}"

    if [[ "${MONIT_CONFIG_SERVICES_REDIS}" == "enabled" ]]; then
        echo "PASSED"
    else
        echo "FAILED"
    fi

    json_write_field "${brolit_config}" "SUPPORT.monit[].config[].monit_services[]" "\"test\": \"disabled\""

    json_write_field "${brolit_config}" "SUPPORT.monit[].config[].monit_services[].test" "enabled"

    MONIT_CONFIG_SERVICES_TEST="$(json_read_field "${brolit_config}" "SUPPORT.monit[].config[].monit_services[].test")"

    if [[ "${MONIT_CONFIG_SERVICES_TEST}" == "enabled" ]]; then
        echo "PASSED"
    else
        echo "FAILED"
    fi

}
