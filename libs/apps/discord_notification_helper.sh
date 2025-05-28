#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.10
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
    local notification_type="${3}"

    # Format title based on notification type
    case "${notification_type}" in

        "alert")
            notification_title=":warning: ${notification_title}"
            ;;
        "info")
            notification_title=":information_source: ${notification_title}"
            ;;
        "success")
            notification_title=":white_check_mark: ${notification_title}"
            ;;
        *)
            # Default format
            ;;

    esac

    # Replace all <br/> occurrences with "\n"
    notification_content="${notification_content//<br\/>/\\n}"
    # Replace all <em> occurrences with "*" (bold)
    notification_content="${notification_content//<em>/**}"
    # Replace all </em> occurrences with "*" (bold)
    notification_content="${notification_content//<\/em>/**}"

    # Check ${notification_content} length
	if [[ ${#notification_content} -gt 900 ]]; then

		# Log
		log_event "warning" "Discord notification content too long, truncating ..." "false"

		# Truncate
		notification_content="${notification_content:0:120}"

	fi

    # Log
    log_event "info" "Sending Discord notification ..." "false"
    log_event "debug" "Running: ${CURL} -H \"Content-Type: application/json\" -X POST -d '{\"content\":\"'\"${notification_title} : ${notification_content}\"'\"}' \"${NOTIFICATION_DISCORD_WEBHOOK}\"" "false"

    # Discord command
    ${CURL} -H "Content-Type: application/json" -X POST -d '{"content":"'"**${notification_title}**: ${notification_content}"'"}' "${NOTIFICATION_DISCORD_WEBHOOK}"

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
