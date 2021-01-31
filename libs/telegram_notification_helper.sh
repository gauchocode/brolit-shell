#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.12
################################################################################

function telegram_send_message() {

	# $1 = {notification_text}
	# $2 = {notification_type}

	local notification_text=$1
	local notification_type=$2

	local timeout 
	local notif_sound 
	local notif_text 
	local notif_url 
	#local notif_date

	display_mode="HTML"
	
	# API timeout
	timeout="10"
	
	# API URL
	notif_url="https://api.telegram.org/bot${botfather_key}/sendMessage"
		
	# notif_sound = 1 for silent notification (without sound)
	notif_sound=0
	if [[ ${notification_type} -eq 1 ]] ; then
		notif_sound=1
	fi
	
	# Notification date
	#notif_date="$(date "+%d %b %H:%M:%S")"	

	#Texto a enviar. Fecha de ejecución y primer parámetro del script.
	#notif_text="<b>${notif_date}:</b>\n<pre>${notification_text}</pre>"
	notif_text="<pre>${notification_text}</pre>"
	
	log_event "info" "Sending Telegram notification ..." "false"

	telegram_notif_response=$(curl --silent --insecure --max-time "${timeout}" --data chat_id="${telegram_user_id}" --data "disable_notification=${notif_sound}" --data "parse_mode=${display_mode}" --data "text=${notif_text}" "${notif_url}")
	telegram_notif_result=$(echo "${telegram_notif_response}" | grep "ok" | cut -d ":" -f2 | cut -d "," -f1)

	#log_event "debug" "Telegram notification response: ${telegram_notif_response}" "true"
	#log_event "debug" "Telegram notification result: ${telegram_notif_result}" "true"

	if [ "${telegram_notif_result}" = "true" ]; then
		# Log success
		log_event "success" "Telegram notification sent!" "false"
		display --indent 2 --text "- Sending Telegram notification" --result "DONE" --color GREEN
	
	else
		# Log failure
		log_event "error" "Telegram notification error!" "false"
		display --indent 2 --text "- Sending Telegram notification" --result "FAIL" --color RED

	fi
	

}