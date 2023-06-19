#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.2-beta
################################################################################
#
# Netdata Helper
#
#   Ref: https://github.com/nextcloud/vm/blob/master/apps/netdata.sh
#
################################################################################

function netdata_alerts_disable() {

    local netdata_api_key

    # Doc: https://learn.netdata.cloud/docs/agent/web/api/health

    # The API is available by default, but it is protected by an api authorization token
    # that is stored in the file you will see in the following entry of http://NODE:19999/netdata.conf:
    # netdata management api key file = /var/lib/netdata/netdata.api.key

    netdata_api_key="$(cat /var/lib/netdata/netdata.api.key)"

    ## If all you need is temporarily disable all health checks, then you issue the following before your maintenance period starts:
    #curl "http://NODE:19999/api/v1/manage/health?cmd=DISABLE ALL" -H "X-Auth-Token: Mytoken"

    ## If you want the health checks to be running but to not receive any notifications during your maintenance period, you can instead use this:
    curl "http://localhost:19999/api/v1/manage/health?cmd=SILENCE ALL" -H "X-Auth-Token: ${netdata_api_key}"

    # Log
    log_event "info" "Disabling netdata alarms ..." "false"
    log_event "info" "Running: curl \"http://localhost:19999/api/v1/manage/health?cmd=SILENCE ALL\" -H \"X-Auth-Token: ${netdata_api_key}\"" "false"

}

function netdata_alerts_enable() {

    local netdata_api_key

    # Doc: https://learn.netdata.cloud/docs/agent/web/api/health

    # The API is available by default, but it is protected by an api authorization token
    # that is stored in the file you will see in the following entry of http://NODE:19999/netdata.conf:
    # netdata management api key file = /var/lib/netdata/netdata.api.key

    netdata_api_key="$(cat /var/lib/netdata/netdata.api.key)"

    ## If all you need is temporarily disable all health checks, then you issue the following before your maintenance period starts:
    #curl "http://NODE:19999/api/v1/manage/health?cmd=DISABLE ALL" -H "X-Auth-Token: Mytoken"

    ## If you want the health checks to be running but to not receive any notifications during your maintenance period, you can instead use this:
    curl "http://localhost:19999/api/v1/manage/health?cmd=RESET" -H "X-Auth-Token: ${netdata_api_key}"

    # Log
    log_event "info" "Restoring netdata alarms status..." "false"
    log_event "info" "Running: curl \"http://localhost:19999/api/v1/manage/health?cmd=RESET\" -H \"X-Auth-Token: ${netdata_api_key}\"" "false"

}
