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

    if [ -f "$server_config_file" ]; then
        echo "Server config file found: $server_config_file"
    else
        echo "Server config file not found: $server_config_file"
        exit 1
    fi

    if [ -r "$server_config_file" ]; then
        echo "Server config file is readable: $server_config_file"
    else
        echo "Server config file is not readable: $server_config_file"
        exit 1
    fi

    # Read required vars from server config file

    ## NOTIFICATIONS

    ### email
    notification_email_status="$(json_read_field "NOTIFICATIONS.email[].status" "$server_config_file")"

    if [[ ${notification_email_status} == "enabled" ]]; then

        notification_email_maila="$(json_read_field "NOTIFICATIONS.email[].config[].maila" "$server_config_file")"
        notification_email_smtp_server="$(json_read_field "NOTIFICATIONS.email[].config[].smtp_server" "$server_config_file")"
        notification_email_smtp_port="$(json_read_field "NOTIFICATIONS.email[].config[].smtp_port" "$server_config_file")"
        notification_email_smtp_user="$(json_read_field "NOTIFICATIONS.email[].config[].smtp_user" "$server_config_file")"
        notification_email_smtp_user_pass="$(json_read_field "NOTIFICATIONS.email[].config[].smtp_user_pass" "$server_config_file")"

        # Check if all required vars are set
        if [[ -z "${notification_email_maila}" ]] || [[ -z "${notification_email_smtp_server}" ]] || [[ -z "${notification_email_smtp_port}" ]] || [[ -z "${notification_email_smtp_user}" ]] || [[ -z "${notification_email_smtp_user_pass}" ]]; then
            echo "Notification email config is not complete: ${notification_email_maila} ${notification_email_smtp_server} ${notification_email_smtp_port} ${notification_email_smtp_user} ${notification_email_smtp_user_pass}"
            exit 1
        fi

    fi

}
