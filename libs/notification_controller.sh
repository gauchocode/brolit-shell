#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.38
#############################################################################

function send_notification() {

    # $1 = {notification_title}
    # $2 = {notification_content}
    # $3 = {notification_type}

    local notification_title=$1
    local notification_content=$2
	local notification_type=$3

    if [[ ${TELEGRAM_NOTIF} == "true" ]]; then

        telegram_send_notification "${notification_title}" "${notification_content}" "${notification_type}"

    fi
    #if [[ ${MAIL_NOTIF} == "true" ]]; then
    #
    #    mail_send_notification "${notification_title}" "${notification_content}" "${notification_type}"
    #
    #fi

}