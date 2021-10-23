#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.68-beta
################################################################################
#
# Server Config Manager: Brolit server configuration management.
#
################################################################################

function server_config_checker() {

    local server_config_file="$1"

    if [ -f "${server_config_file}" ]; then
        echo "Server config file found: ${server_config_file}"
    else
        echo "Server config file not found: ${server_config_file}"
        exit 1
    fi

    if [ -r "${server_config_file}" ]; then
        echo "Server config file is readable: ${server_config_file}"
    else
        echo "Server config file is not readable: ${server_config_file}"
        exit 1
    fi

    # Read required vars from server config file

    ## NOTIFICATIONS

    ### email
    notification_email_status="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].status")"

    if [[ ${notification_email_status} == "enabled" ]]; then

        notification_email_maila="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].maila")"
        notification_email_smtp_server="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_server")"
        notification_email_smtp_port="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_port")"
        notification_email_smtp_user="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_user")"
        notification_email_smtp_user_pass="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_user_pass")"

        # Check if all required vars are set
        if [[ -z "${notification_email_maila}" ]] || [[ -z "${notification_email_smtp_server}" ]] || [[ -z "${notification_email_smtp_port}" ]] || [[ -z "${notification_email_smtp_user}" ]] || [[ -z "${notification_email_smtp_user_pass}" ]]; then
            echo "Notification email config is not complete: ${notification_email_maila} ${notification_email_smtp_server} ${notification_email_smtp_port} ${notification_email_smtp_user} ${notification_email_smtp_user_pass}"
            exit 1
        fi

    fi

    ### telegram
    notification_telegram_status="$(json_read_field "${server_config_file}" "NOTIFICATIONS.telegram[].status")"

    if [[ ${notification_telegram_status} == "enabled" ]]; then

        notification_telegram_bot_token="$(json_read_field "${server_config_file}" "NOTIFICATIONS.telegram[].config[].botfather_key")"
        notification_telegram_chat_id="$(json_read_field "${server_config_file}" "NOTIFICATIONS.telegram[].config[].telegram_user_id")"

        # Check if all required vars are set
        if [[ -z "${notification_telegram_bot_token}" ]] || [[ -z "${notification_telegram_chat_id}" ]]; then
            echo "Notification telegram config is not complete: ${notification_telegram_bot_token} ${notification_telegram_chat_id}"
            exit 1
        fi

    fi

    ## SUPPORT

    ### cloudflare
    support_cloudflare_status="$(json_read_field "${server_config_file}" "SUPPORT.cloudflare[].status")"

    if [[ ${support_cloudflare_status} == "enabled" ]]; then

        support_cloudflare_email="$(json_read_field "${server_config_file}" "SUPPORT.cloudflare[].config[].email")"
        support_cloudflare_api_key="$(json_read_field "${server_config_file}" "SUPPORT.cloudflare[].config[].api_key")"

        # Check if all required vars are set
        if [[ -z "${support_cloudflare_email}" ]] || [[ -z "${support_cloudflare_api_key}" ]]; then
            echo "Support cloudflare config is not complete: ${support_cloudflare_email} ${support_cloudflare_api_key}"
            exit 1
        fi

    fi

}
