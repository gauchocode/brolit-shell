#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.68-beta
################################################################################
#
# Server Config Manager: Brolit server configuration management.
#
################################################################################

function brolit_configuration_load() {

    local server_config_file="$1"

    # Globals
    declare -g PROJECTS_PATH

    declare -g BACKUP_DROPBOX_STATUS
    declare -g BACKUP_DROPBOX_CONFIG_FILE

    declare -g BACKUP_SFTP_STATUS
    declare -g BACKUP_SFTP_CONFIG_SERVER_IP
    declare -g BACKUP_SFTP_CONFIG_SERVER_PORT
    declare -g BACKUP_SFTP_CONFIG_SERVER_USER
    declare -g BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD
    declare -g BACKUP_SFTP_CONFIG_SERVER_REMOTE_PATH

    declare -g BACKUP_LOCAL_STATUS
    declare -g BACKUP_LOCAL_CONFIG_BACKUP_PATH

    declare -g BACKUP_RETENTION_KEEP_DAILY

    declare -g NOTIFICATION_EMAIL_STATUS
    declare -g NOTIFICATION_EMAIL_MAILA
    declare -g NOTIFICATION_EMAIL_SMTP_SERVER
    declare -g NOTIFICATION_EMAIL_SMTP_PORT
    declare -g NOTIFICATION_EMAIL_SMTP_TLS
    declare -g NOTIFICATION_EMAIL_SMTP_USER
    declare -g NOTIFICATION_EMAIL_SMTP_USER_PASS

    declare -g NOTIFICATION_TELEGRAM_STATUS
    declare -g NOTIFICATION_TELEGRAM_BOT_TOKEN
    declare -g NOTIFICATION_TELEGRAM_CHAT_ID

    declare -g FIREWALL_CONFIG_STATUS
    declare -g FIREWALL_CONFIG_APP_LIST_SSH
    declare -g FIREWALL_CONFIG_APP_LIST_HTTP
    declare -g FIREWALL_CONFIG_APP_LIST_HTTPS

    declare -g SUPPORT_CLOUDFLARE_STATUS
    declare -g SUPPORT_CLOUDFLARE_EMAIL
    declare -g SUPPORT_CLOUDFLARE_API_KEY

    declare -g SUPPORT_NETDATA_STATUS
    declare -g SUPPORT_NETDATA_CONFIG_SUBDOMAIN
    declare -g SUPPORT_NETDATA_CONFIG_USER
    declare -g SUPPORT_NETDATA_CONFIG_USER_PASS
    declare -g SUPPORT_NETDATA_CONFIG_ALARM_LEVEL

    if [ -f "${server_config_file}" ]; then

        echo "Server config file found: ${server_config_file}"
        display --indent 6 --text "- Checking Brolit config file" --result "DONE" --color GREEN

    else

        display --indent 6 --text "- Checking Brolit config file" --result "WARNING" --color YELLOW
        display --indent 8 "Config file not found: ${server_config_file}"

        # Creating new config file
        while true; do

            echo -e "${YELLOW}${ITALIC} > Do you want to create a new config file?${ENDCOLOR}"
            read -p "Please type 'y' or 'n'" yn

            case $yn in

            [Yy]*)

                cp "${SFOLDER}/config/brolit/brolit_conf.json" "${server_config_file}"

                menu_first_run

                break
                ;;

            [Nn]*)

                echo -e "${YELLOW}${ITALIC} > BROLIT can not run without a config file. Exiting ...${ENDCOLOR}"

                exit 1

                #break
                ;;

            *) echo " > Please answer yes or no." ;;

            esac
        done

    fi

    # Read required vars from server config file

    ## BACKUPS

    ### methods

    #### dropbox
    BACKUP_DROPBOX_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.methods[].dropbox[].status")"

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        BACKUP_DROPBOX_CONFIG_FILE="$(json_read_field "${server_config_file}" "BACKUPS.methods[].dropbox[].config[].file")"

        if [ -f "${BACKUP_DROPBOX_CONFIG_FILE}" ]; then

            display --indent 6 --text "- Checking Dropbox config file" --result "DONE" --color GREEN

        else

            display --indent 6 --text "- Checking Dropbox config file" --result "FAIL" --color RED
            display --indent 8 --text "Config file not found: ${BACKUP_DROPBOX_CONFIG_FILE}"

            exit 1

        fi

    fi

    #### sftp
    BACKUP_SFTP_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].status")"

    if [[ ${BACKUP_SFTP_STATUS} == "enabled" ]]; then

        BACKUP_SFTP_CONFIG_SERVER_IP="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_ip")"
        BACKUP_SFTP_CONFIG_SERVER_PORT="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_port")"
        BACKUP_SFTP_CONFIG_SERVER_USER="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_user")"
        BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_user_password")"
        BACKUP_SFTP_CONFIG_SERVER_REMOTE_PATH="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_remote_path")"

        # Check if all required vars are set
        if [ -z "${BACKUP_SFTP_CONFIG_SERVER_IP}" ] || [ -z "${BACKUP_SFTP_CONFIG_SERVER_PORT}" ] || [ -z "${BACKUP_SFTP_CONFIG_SERVER_USER}" ] || [ -z "${BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD}" ] || [ -z "${BACKUP_SFTP_CONFIG_SERVER_REMOTE_PATH}" ]; then
            echo "Missing required config vars for SFTP backup method"
            exit 1
        fi

    fi

    #### local
    BACKUP_LOCAL_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.methods[].local[].status")"

    if [[ ${BACKUP_LOCAL_STATUS} == "enabled" ]]; then

        BACKUP_LOCAL_CONFIG_BACKUP_PATH="$(json_read_field "${server_config_file}" "BACKUPS.methods[].local[].config[].backup_path")"

        # Check if all required vars are set
        if [ -z "${BACKUP_LOCAL_CONFIG_BACKUP_PATH}" ]; then
            echo "Missing required config vars for local backup method"
            exit 1
        fi

    fi

    #### if all required vars are disabled, show error
    if [[ ${BACKUP_DROPBOX_STATUS} != "enabled" ]] && [[ ${BACKUP_SFTP_STATUS} != "enabled" ]] && [[ ${BACKUP_LOCAL_STATUS} != "enabled" ]]; then
        echo "No backup method enabled"
        exit 1
    fi

    ## retention
    BACKUP_RETENTION_KEEP_DAILY="$(json_read_field "${server_config_file}" "BACKUPS.retention[].keep_daily")"

    if [ -z "${BACKUP_RETENTION_KEEP_DAILY}" ]; then
        echo "Missing required config vars for backup retention"
        exit 1
    fi

    ## PROJECTS_PATH

    PROJECTS_PATH="$(json_read_field "${server_config_file}" "PROJECTS_PATH")"

    if [ -z "${PROJECTS_PATH}" ]; then
        echo "Missing required config vars for projects path"
        exit 1
    fi

    ## NOTIFICATIONS

    ### email
    NOTIFICATION_EMAIL_STATUS="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].status")"

    if [[ ${NOTIFICATION_EMAIL_STATUS} == "enabled" ]]; then

        NOTIFICATION_EMAIL_MAILA="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].maila")"
        NOTIFICATION_EMAIL_SMTP_SERVER="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_server")"
        NOTIFICATION_EMAIL_SMTP_PORT="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_port")"
        NOTIFICATION_EMAIL_SMTP_TLS="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_tls")"
        NOTIFICATION_EMAIL_SMTP_USER="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_user")"
        NOTIFICATION_EMAIL_SMTP_USER_PASS="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_user_pass")"

        # Check if all required vars are set
        if [[ -z "${NOTIFICATION_EMAIL_MAILA}" ]] || [[ -z "${NOTIFICATION_EMAIL_SMTP_SERVER}" ]] || [[ -z "${NOTIFICATION_EMAIL_SMTP_PORT}" ]] || [[ -z "${NOTIFICATION_EMAIL_SMTP_USER}" ]] || [[ -z "${NOTIFICATION_EMAIL_SMTP_USER_PASS}" ]]; then
            echo "Missing required config vars for email notifications"
            exit 1
        fi

    fi

    ### telegram
    NOTIFICATION_TELEGRAM_STATUS="$(json_read_field "${server_config_file}" "NOTIFICATIONS.telegram[].status")"

    if [[ ${NOTIFICATION_TELEGRAM_STATUS} == "enabled" ]]; then

        NOTIFICATION_TELEGRAM_BOT_TOKEN="$(json_read_field "${server_config_file}" "NOTIFICATIONS.telegram[].config[].NOTIFICATION_TELEGRAM_BOT_TOKEN")"
        NOTIFICATION_TELEGRAM_CHAT_ID="$(json_read_field "${server_config_file}" "NOTIFICATIONS.telegram[].config[].NOTIFICATION_TELEGRAM_CHAT_ID")"

        # Check if all required vars are set
        if [[ -z "${NOTIFICATION_TELEGRAM_BOT_TOKEN}" ]] || [[ -z "${NOTIFICATION_TELEGRAM_CHAT_ID}" ]]; then
            echo "Missing required config vars for telegram notifications"
            exit 1
        fi

    fi

    ## FIREWALL

    FIREWALL_CONFIG_STATUS="$(json_read_field "${server_config_file}" "FIREWALL.config[].status")"

    if [[ ${FIREWALL_CONFIG_STATUS} == "enabled" ]]; then

        FIREWALL_CONFIG_APP_LIST_SSH="$(json_read_field "${server_config_file}" "FIREWALL.config[].app_list[].ssh")"
        FIREWALL_CONFIG_APP_LIST_HTTP="$(json_read_field "${server_config_file}" "FIREWALL.config[].app_list[].http")"
        FIREWALL_CONFIG_APP_LIST_HTTPS="$(json_read_field "${server_config_file}" "FIREWALL.config[].app_list[].https")"

        # Check if all required vars are set
        if [[ -z "${FIREWALL_CONFIG_APP_LIST_SSH}" ]] || [[ -z "${FIREWALL_CONFIG_APP_LIST_HTTP}" ]] || [[ -z "${FIREWALL_CONFIG_APP_LIST_HTTPS}" ]]; then
            echo "Missing required config vars for firewall"
            exit 1
        fi

    fi

    ## SUPPORT

    ### cloudflare
    SUPPORT_CLOUDFLARE_STATUS="$(json_read_field "${server_config_file}" "SUPPORT.cloudflare[].status")"

    if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

        SUPPORT_CLOUDFLARE_EMAIL="$(json_read_field "${server_config_file}" "SUPPORT.cloudflare[].config[].email")"
        SUPPORT_CLOUDFLARE_API_KEY="$(json_read_field "${server_config_file}" "SUPPORT.cloudflare[].config[].api_key")"

        # Check if all required vars are set
        if [[ -z "${SUPPORT_CLOUDFLARE_EMAIL}" ]] || [[ -z "${SUPPORT_CLOUDFLARE_API_KEY}" ]]; then
            echo "Missing required config vars for cloudflare support"
            exit 1
        fi

    fi

    ### netdata
    SUPPORT_NETDATA_STATUS="$(json_read_field "${server_config_file}" "SUPPORT.netdata[].status")"

    if [[ ${SUPPORT_NETDATA_STATUS} == "enabled" ]]; then

        SUPPORT_NETDATA_CONFIG_SUBDOMAIN="$(json_read_field "${server_config_file}" "SUPPORT.netdata[].config[].netdata_subdomain")"
        SUPPORT_NETDATA_CONFIG_USER="$(json_read_field "${server_config_file}" "SUPPORT.netdata[].config[].netdata_user")"
        SUPPORT_NETDATA_CONFIG_USER_PASS="$(json_read_field "${server_config_file}" "SUPPORT.netdata[].config[].netdata_user_pass")"
        SUPPORT_NETDATA_CONFIG_ALARM_LEVEL="$(json_read_field "${server_config_file}" "SUPPORT.netdata[].config[].netdata_alarm_level")"

        # Check if all required vars are set
        if [[ -z "${SUPPORT_NETDATA_CONFIG_SUBDOMAIN}" ]] || [[ -z "${SUPPORT_NETDATA_CONFIG_USER}" ]] || [[ -z "${SUPPORT_NETDATA_CONFIG_USER_PASS}" ]] || [[ -z "${SUPPORT_NETDATA_CONFIG_ALARM_LEVEL}" ]]; then
            echo "Missing required config vars for netdata support"
            exit 1
        fi

    fi

    # Export vars
    export PROJECTS_PATH
    export BACKUP_DROPBOX_STATUS BACKUP_DROPBOX_CONFIG_FILE
    export BACKUP_SFTP_STATUS BACKUP_SFTP_CONFIG_SERVER_IP BACKUP_SFTP_CONFIG_SERVER_PORT BACKUP_SFTP_CONFIG_SERVER_USER BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD
    export BACKUP_LOCAL_STATUS BACKUP_LOCAL_CONFIG_BACKUP_PATH
    export BACKUP_RETENTION_KEEP_DAILY
    export NOTIFICATION_EMAIL_STATUS NOTIFICATION_EMAIL_MAILA NOTIFICATION_EMAIL_SMTP_SERVER NOTIFICATION_EMAIL_SMTP_PORT NOTIFICATION_EMAIL_SMTP_TLS NOTIFICATION_EMAIL_SMTP_USER NOTIFICATION_EMAIL_SMTP_USER_PASS
    export NOTIFICATION_TELEGRAM_STATUS NOTIFICATION_TELEGRAM_BOT_TOKEN NOTIFICATION_TELEGRAM_CHAT_ID
    export SUPPORT_CLOUDFLARE_STATUS SUPPORT_CLOUDFLARE_EMAIL SUPPORT_CLOUDFLARE_API_KEY
    export SUPPORT_NETDATA_STATUS SUPPORT_NETDATA_CONFIG_SUBDOMAIN SUPPORT_NETDATA_CONFIG_USER SUPPORT_NETDATA_CONFIG_USER_PASS SUPPORT_NETDATA_CONFIG_ALARM_LEVEL
    export FIREWALL_CONFIG_APP_LIST_SSH FIREWALL_CONFIG_APP_LIST_HTTP FIREWALL_CONFIG_APP_LIST_HTTPS FIREWALL_CONFIG_STATUS

}

function brolit_apps_configuration_load() {

    _settings_config_mysql

    _settings_config_dropbox

}

################################################################################
# Private: mysql root password configuration
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function _settings_config_mysql() {

    if [[ "${SERVER_CONFIG}" == *"mysql"* ]]; then

        mysql_ask_root_psw

    fi

}

function _settings_config_dropbox() {

    # Checking global var
    if [[ ${BACKUP_DROPBOX_STATUS} == "true" ]]; then

        "${DROPBOX_UPLOADER}" list

        # Generating Dropbox api config file
        #generate_dropbox_config

    fi

}

################################################################################
#botfather_whip_line+=" \n "
#botfather_whip_line+=" Open Telegram and follow the next steps:\n\n"
#botfather_whip_line+=" 1) Get a bot token. Contact @BotFather (https://t.me/BotFather) and send the command /newbot.\n"
#botfather_whip_line+=" 2) Follow the instructions and paste the token to access the HTTP API:\n\n"
#telegram_id_whip_line+=" 3) Contact the @myidbot (https://t.me/myidbot) bot and send the command /getid to get \n"
#telegram_id_whip_line+=" your personal chat id or invite him into a group and issue the same command to get the group chat id.\n"
#telegram_id_whip_line+=" 4) Paste the ID here:\n\n"
