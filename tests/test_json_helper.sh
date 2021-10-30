#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.70-beta
#############################################################################

function test_json_helper_funtions() {

    local brolit_config="assets/brolit_conf.json"

    NETDATA_CONFIG_STATUS="$(json_read_field "${brolit_config}" "SUPPORT.netdata[].status")"

    echo "NETDATA_CONFIG_STATUS=${NETDATA_CONFIG_STATUS}"

    NETDATA_CONFIG_STATUS="$(json_write_field "${brolit_config}" "SUPPORT.netdata[].status" "enabled")"

    if [[ "${NETDATA_CONFIG_STATUS}" == "enabled" ]]; then
        echo "PASSED"
    else
        echo "FAILED"
    fi

    MONIT_CONFIG_SERVICES="$(json_read_field "${server_config_file}" "SUPPORT.monit[].config[].monit_services")"

    echo "MONIT_CONFIG_SERVICES=${MONIT_CONFIG_SERVICES}"

    MONIT_CONFIG_SERVICES_REDIS="$(json_write_field "${brolit_config}" "SUPPORT.monit[].config[].monit_services[].redis" "enabled")"

    if [[ "${MONIT_CONFIG_SERVICES_REDIS}" == "enabled" ]]; then
        echo "PASSED"
    else
        echo "FAILED"
    fi

    MONIT_CONFIG_SERVICES_CUSTOM="$(json_write_field "${brolit_config}" "SUPPORT.monit[].config[].monit_services[]" "\"test\": \"disabled\"")"

    echo "MONIT_CONFIG_SERVICES_CUSTOM=${MONIT_CONFIG_SERVICES_CUSTOM}"

    MONIT_CONFIG_SERVICES_TEST="$(json_write_field "${brolit_config}" "SUPPORT.monit[].config[].monit_services[].test" "enabled")"

    if [[ "${MONIT_CONFIG_SERVICES_TEST}" == "enabled" ]]; then
        echo "PASSED"
    else
        echo "FAILED"
    fi

}
