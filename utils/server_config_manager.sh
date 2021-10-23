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

    ## BACKUPS

    ### methods

    #### dropbox
    backup_dropbox_status="$(json_read_field "${server_config_file}" "BACKUPS.methods[].dropbox[].status")"

    if [[ ${backup_dropbox_status} == "enabled" ]]; then

        backup_dropbox_config_file="$(json_read_field "${server_config_file}" "BACKUPS.methods[].dropbox[].config[].file")"
 
        if [ -f "${backup_dropbox_config_file}" ]; then
            echo "Backup Dropbox config file found: ${backup_dropbox_config_file}"
        else
            echo "Backup Dropbox config file not found: ${backup_dropbox_config_file}"
            exit 1
        fi

    fi

    #### sftp
    backup_sftp_status="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].status")"

    if [[ ${backup_sftp_status} == "enabled" ]]; then

        backup_sftp_config_server_ip="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_ip")"
        backup_sftp_config_server_port="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_port")"
        backup_sftp_config_server_user="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_user")"
        backup_sftp_config_server_user_password="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_user_password")"
        backup_sftp_config_server_remote_path="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_remote_path")"

        # Check if all required vars are set
        if [ -z "${backup_sftp_config_server_ip}" ] || [ -z "${backup_sftp_config_server_port}" ] || [ -z "${backup_sftp_config_server_user}" ] || [ -z "${backup_sftp_config_server_user_password}" ] || [ -z "${backup_sftp_config_server_remote_path}" ]; then
            echo "Missing required config vars for SFTP backup method"
            exit 1
        fi

    fi

    #### local
    backup_local_status="$(json_read_field "${server_config_file}" "BACKUPS.methods[].local[].status")"

    if [[ ${backup_local_status} == "enabled" ]]; then

        backup_local_config_backup_path="$(json_read_field "${server_config_file}" "BACKUPS.methods[].local[].config[].backup_path")"

        # Check if all required vars are set
        if [ -z "${backup_local_config_backup_path}" ]; then
            echo "Missing required config vars for local backup method"
            exit 1
        fi

    fi

    ## retention
    backup_retention_keep_daily="$(json_read_field "${server_config_file}" "BACKUPS.retention[].keep_daily")"

    if [ -z "${backup_retention_keep_daily}" ]; then
        echo "Missing required config vars for backup retention"
        exit 1
    fi

    ## PROJECTS_PATH

    projects_path="$(json_read_field "${server_config_file}" "PROJECTS_PATH")"

    if [ -z "${projects_path}" ]; then
        echo "Missing required config vars for projects path"
        exit 1
    fi

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
            echo "Missing required config vars for email notifications"
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
            echo "Missing required config vars for telegram notifications"
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
            echo "Missing required config vars for cloudflare support"
            exit 1
        fi

    fi

    ### netdata
    support_netdata_status="$(json_read_field "${server_config_file}" "SUPPORT.netdata[].status")"

    if [[ ${support_netdata_status} == "enabled" ]]; then

        support_netdata_config_subdomain="$(json_read_field "${server_config_file}" "SUPPORT.netdata[].config[].netdata_subdomain")"
        support_netdata_config_user="$(json_read_field "${server_config_file}" "SUPPORT.netdata[].config[].netdata_user")"
        support_netdata_config_user_pass="$(json_read_field "${server_config_file}" "SUPPORT.netdata[].config[].netdata_user_pass")"
        support_netdata_config_alarm_level="$(json_read_field "${server_config_file}" "SUPPORT.netdata[].config[].netdata_alarm_level")"

        # Check if all required vars are set
        if [[ -z "${support_netdata_config_subdomain}" ]] || [[ -z "${support_netdata_config_user}" ]] || [[ -z "${support_netdata_config_user_pass}" ]] || [[ -z "${support_netdata_config_alarm_level}" ]]; then
            echo "Missing required config vars for netdata support"
            exit 1
        fi

    fi

}
