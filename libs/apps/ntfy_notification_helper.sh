#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.5
################################################################################

################################################################################
# Ntfy Send Notification
#
# Arguments:
#   ${1} = {notification_title}
#   ${2} = {notification_content}
#   ${3} = {notification_type}
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function ntfy_send_notification() {

    local notification_title="${1}"
    local notification_content="${2}"
    local notification_type="${3}"

    # Determine notification priority based on type
    local priority

    case "${notification_type}" in

    "alert")
        priority="urgent"
        ;;
    "info")
        priority="default"
        ;;
    "success")
        priority="min"
        ;;
    *)
        priority="default"
        ;;

    esac

    # Log
    log_event "info" "Sending Ntfy notification ..." "false"
    log_event "debug" "${CURL} -H 'Title: ${notification_title}' -H 'Priority: ${priority}' -d '${notification_content}' -u '${NOTIFICATION_NTFY_USERNAME}:${NOTIFICATION_NTFY_PASSWORD}' '${NOTIFICATION_NTFY_SERVER}/${NOTIFICATION_NTFY_TOPIC}'" "false"

    # Ntfy command with priority
    ${CURL} -H "Title: ${notification_title}" -H "Priority: ${priority}" -d "${notification_content}" -u "${NOTIFICATION_NTFY_USERNAME}:${NOTIFICATION_NTFY_PASSWORD}" "${NOTIFICATION_NTFY_SERVER}/${NOTIFICATION_NTFY_TOPIC}" > /dev/null 2>&1

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log on success
        log_event "info" "Ntfy notification sent!"
        display --indent 6 --text "- Sending ntfy notification" --result "DONE" --color GREEN

        return 0

    else
        # Log on failure
        log_event "error" "Ntfy notification error." "false"
        log_event "error" "Please, check server url on .brolit_conf.json" "false"
        display --indent 6 --text "- Sending ntfy notification" --result "FAIL" --color RED
        display --indent 8 --text "Check server url on .brolit_conf.json" --tcolor YELLOW

        return 1

    fi

}
