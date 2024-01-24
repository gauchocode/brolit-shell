#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.7
################################################################################


################################################################################
# Ntfy send notification
#
################################################################################

function ntfy_send_notification() {

    local notification_title="${1}"
    local notification_content="${2}"
    local notification_type="${3}"


    curl -H "${notification_title}" -d "${notification_content}" -u "${NOTIFICATION_NTFY_USERNAME}:${NOTIFICATION_NTFY_PASSWORD}" "${NTFY_URL}"



}