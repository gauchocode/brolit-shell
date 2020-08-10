#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0-rc08
################################################################################

# TODO: make this function works!

telegram_notifications_config() {

	source "/root/.telegram.conf"

	# BotFather API Key
	botfather_key="1175005548:AAFAjqU8KP2Dqwu9XNq8GoIFeofnPZrOIF0" 

	# Chat ID, use @myidbot to get it
	telegram_user_id="-455549357"

	if [[ -z "${botfather_key}" ]]; then

		botfather_whip_line+="\n . \n"
		botfather_whip_line+=" Configure Telegram Notifications? You will need:\n"
		botfather_whip_line+=" 1) Get a bot token. Contact @BotFather (https://t.me/BotFather) and send the command /newbot.\n"
		botfather_whip_line+=" Follow the instructions and paste the token to access the HTTP API:\n"

		botfather_key=$(whiptail --title "Netdata: Telegram Configuration" --inputbox "${botfather_whip_line}" 15 60 3>&1 1>&2 2>&3)
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
			echo "botfather_key=${botfather_key}" >>"/root/.telegram.conf"
		else
			exit 1
		fi

	fi
	if [[ -z "${telegram_user_id}" ]]; then

		telegram_id_whip_line+="\n . \n"
		telegram_id_whip_line+=" 2) Contact the @myidbot (https://t.me/myidbot) bot and send the command /getid to get \n"
		telegram_id_whip_line+=" your personal chat id or invite him into a group and issue the same command to get the group chat id.\n"
		telegram_id_whip_line+=" 3) Paste the ID here:\n"
		
		telegram_user_id=$(whiptail --title "Netdata: Telegram Configuration" --inputbox "${telegram_id_whip_line}" 15 60 3>&1 1>&2 2>&3)
		exitstatus=$?
		if [ $exitstatus = 0 ]; then
			echo "telegram_user_id=${telegram_user_id}" >>"/root/.telegram.conf"
		else
			exit 1
		fi

	fi

}

telegram_send_message() {

	# $1 = {notification_text}
	# $2 = {notification_type}

	local notification_text=$1
	local notification_type=$2

	local timeout notif_sound notif_text notif_url notif_date

	# Check if telegram is config before run
	telegram_notifications_config

	DISPLAY_MODE="HTML"
	
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
	
	log_event "info" "Sending Telegram notification ..." "true"

	curl --silent --insecure --max-time "${timeout}" --data chat_id="${telegram_user_id}" --data "disable_notification=${notif_sound}" --data "parse_mode=${DISPLAY_MODE}" --data "text=${notif_text}" "${notif_url}"

	log_event "info" "Telegram notification sent" "true"

}