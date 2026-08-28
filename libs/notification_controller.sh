#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.13
################################################################################
#
# Notification Controller: Send notification to configured apps.
#
################################################################################

################################################################################
# Send Notification: send notification to configured apps.
#
# Arguments:
#   ${1} = {notification_title}
#   ${2} = {notification_content}
#   ${3} = {notification_type} - Options: "alert", "info", "success"
#   ${4} = {exclude_channels}  - Optional, space-separated. E.g. "email" to
#          skip the email channel (useful when a detailed report was already
#          sent to email directly via mail_send_notification, so this call
#          only needs to reach the other channels).
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function send_notification() {

    local notification_title="${1}"
    local notification_content="${2}"
    local notification_type="${3}"
    local exclude_channels="${4}"

    log_subsection "Notifications"

    if [[ ${NOTIFICATION_TELEGRAM_STATUS} == "enabled" ]]; then

        telegram_send_notification "${notification_title}" "${notification_content}" "${notification_type}"

    fi

    if [[ ${NOTIFICATION_DISCORD_STATUS} == "enabled" ]]; then

        discord_send_notification "${notification_title}" "${notification_content}" "${notification_type}"

    fi

    if [[ ${NOTIFICATION_EMAIL_STATUS} == "enabled" ]] && [[ ! " ${exclude_channels} " == *" email "* ]]; then

        mail_send_notification "${notification_title}" "${notification_content}" "${notification_type}"

    fi

    if [[ ${NOTIFICATION_NTFY_STATUS} == "enabled" ]]; then

        ntfy_send_notification "${notification_title}" "${notification_content}" "${notification_type}"

    fi

}
