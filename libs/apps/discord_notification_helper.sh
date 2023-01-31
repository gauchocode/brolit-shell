#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.3.0-beta
################################################################################
#
# Discord Notification Helper: Perform Discord actions.
#
################################################################################

################################################################################
# Discord send notification
#
# Arguments:
# 	${1} = {notification_title}
# 	${2} = {notification_content}
# 	${3} = {notification_type}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################
#

function discord_send_notification() {

    local notification_title="${1}"
    local notification_content="${2}"
    #local notification_type="${3}"

    # Log
    log_event "info" "Sending Discord notification ..." "false"
    log_event "debug" "Running: ${CURL} -H \"Content-Type: application/json\" -X POST -d '{\"content\":\"'\"${notification_title} : ${notification_content}\"'\"}' \"${NOTIFICATION_DISCORD_WEBHOOK}\"" "false"

    # Discord command
    ${CURL} -H "Content-Type: application/json" -X POST -d '{"content":"'"**${notification_title}**:\n${notification_content}"'"}' "${NOTIFICATION_DISCORD_WEBHOOK}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log on success
        log_event "info" "Discord notification sent!"
        display --indent 6 --text "- Sending Discord notification" --result "DONE" --color GREEN

        return 0

    else
        # Log on failure
        log_event "error" "Discord notification error." "false"
        log_event "error" "Please, check webhook url on .brolit_conf.json" "false"
        display --indent 6 --text "- Sending Discord notification" --result "FAIL" --color RED
        display --indent 8 --text "Check webhook url on .brolit_conf.json" --tcolor YELLOW

        return 1

    fi

}
