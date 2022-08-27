#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.1
################################################################################
#
# Discord Notification Helper: Perform Discord actions.
#
################################################################################

################################################################################
# Discord send notification
#
# Arguments:
# 	$1 = {notification_title}
# 	$2 = {notification_content}
# 	$3 = {notification_type}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################
#

function discord_send_notification() {

    local notification_title="${1}"
    local notification_content="${2}"
    #local notification_type="${3}"

    ${CURL} -H "Content-Type: application/json" -X POST -d '{"content":"'"${notification_title} : ${notification_content}"'"}' "${NOTIFICATION_DISCORD_WEBHOOK}"

}
