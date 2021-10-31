#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.70-beta
################################################################################
#
# Server Config Manager: Brolit server configuration management.
#
################################################################################

function brolit_configuration_load() {

    local server_config_file=$1

    # Globals
    declare -g PROJECTS_PATH

    if [[ -f "${server_config_file}" ]]; then

        display --indent 2 --text "- Checking Brolit config file" --result "DONE" --color GREEN

    else

        display --indent 2 --text "- Checking Brolit config file" --result "WARNING" --color YELLOW
        display --indent 4 --text "Config file not found: ${server_config_file}"

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

    # Check if is already defined
    if [ -z "${DEBUG}" ]; then
        # Read required vars from server config file
        DEBUG="$(json_read_field "${server_config_file}" "BROLIT_SETUP.config[].debug")"

        if [ -z "${DEBUG}" ]; then
            echo "Missing required config vars for projects path"
            exit 1
        fi
    fi
    # Check if is already defined
    if [ -z "${QUIET}" ]; then
        QUIET="$(json_read_field "${server_config_file}" "BROLIT_SETUP.config[].quiet")"

        if [ -z "${QUIET}" ]; then
            echo "Missing required config vars for projects path"
            exit 1
        fi
    fi
    # Check if is already defined
    if [ -z "${SKIPTESTS}" ]; then
        SKIPTESTS="$(json_read_field "${server_config_file}" "BROLIT_SETUP.config[].skip_test")"

        if [ -z "${SKIPTESTS}" ]; then
            echo "Missing required config vars for projects path"
            exit 1
        fi
    fi
    
    ## BACKUPS

    ### methods

    #### dropbox
    _brolit_configuration_load_dropbox "${server_config_file}"

    #### sftp
    _brolit_configuration_load_sftp "${server_config_file}"

    #### local
    _brolit_configuration_load_local "${server_config_file}"

    #### duplicity
    _brolit_configuration_load_duplicity "${server_config_file}"

    #### if all required vars are disabled, show error
    if [[ ${BACKUP_DROPBOX_STATUS} != "enabled" ]] && [[ ${BACKUP_SFTP_STATUS} != "enabled" ]] && [[ ${BACKUP_LOCAL_STATUS} != "enabled" ]]; then
        echo "No backup method enabled"
        exit 1
    fi

    ### retention
    _brolit_configuration_load_backup_retention "${server_config_file}"

    ## PROJECTS_PATH

    PROJECTS_PATH="$(json_read_field "${server_config_file}" "PROJECTS.path")"

    if [ -z "${PROJECTS_PATH}" ]; then
        echo "Missing required config vars for projects path"
        exit 1
    fi

    # TODO: need to implement BACKUPS.direcotries

    ## NOTIFICATIONS
    _brolit_configuration_load_email "${server_config_file}"

    ### telegram
    _brolit_configuration_load_telegram "${server_config_file}"

    ## FIREWALL
    _brolit_configuration_load_firewall "${server_config_file}"

    ## SUPPORT

    ### cloudflare
    _brolit_configuration_load_cloudflare "${server_config_file}"

    ### monit
    _brolit_configuration_load_monit "${server_config_file}"

    ### netdata
    _brolit_configuration_load_netdata "${server_config_file}"

    # Export vars
    export PROJECTS_PATH

}

function _brolit_configuration_load_sftp() {

    local server_config_file=$1

    # Globals
    declare -g BACKUP_SFTP_STATUS
    declare -g BACKUP_SFTP_CONFIG_SERVER_IP
    declare -g BACKUP_SFTP_CONFIG_SERVER_PORT
    declare -g BACKUP_SFTP_CONFIG_SERVER_USER
    declare -g BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD
    declare -g BACKUP_SFTP_CONFIG_SERVER_REMOTE_PATH

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

    export BACKUP_SFTP_STATUS BACKUP_SFTP_CONFIG_SERVER_IP BACKUP_SFTP_CONFIG_SERVER_PORT BACKUP_SFTP_CONFIG_SERVER_USER BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD

}

function _brolit_configuration_load_dropbox() {

    local server_config_file=$1

    # Globals
    declare -g BACKUP_DROPBOX_STATUS
    declare -g BACKUP_DROPBOX_CONFIG_FILE

    BACKUP_DROPBOX_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.methods[].dropbox[].status")"

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        BACKUP_DROPBOX_CONFIG_FILE="$(json_read_field "${server_config_file}" "BACKUPS.methods[].dropbox[].config[].file")"

        if [ -f "${BACKUP_DROPBOX_CONFIG_FILE}" ]; then

            display --indent 2 --text "- Checking Dropbox config file" --result "DONE" --color GREEN

        else

            display --indent 2 --text "- Checking Dropbox config file" --result "FAIL" --color RED
            display --indent 4 --text "Config file not found: ${BACKUP_DROPBOX_CONFIG_FILE}"

            _brolit_configuration_app_dropbox

            exit 1

        fi

    fi

    export BACKUP_DROPBOX_STATUS BACKUP_DROPBOX_CONFIG_FILE

}

function _brolit_configuration_load_local() {

    local server_config_file=$1

    # Globals
    declare -g BACKUP_LOCAL_STATUS
    declare -g BACKUP_LOCAL_CONFIG_BACKUP_PATH

    BACKUP_LOCAL_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.methods[].local[].status")"

    if [[ ${BACKUP_LOCAL_STATUS} == "enabled" ]]; then

        BACKUP_LOCAL_CONFIG_BACKUP_PATH="$(json_read_field "${server_config_file}" "BACKUPS.methods[].local[].config[].backup_path")"

        # Check if all required vars are set
        if [ -z "${BACKUP_LOCAL_CONFIG_BACKUP_PATH}" ]; then
            echo "Missing required config vars for local backup method"
            exit 1
        fi

    fi

    export BACKUP_LOCAL_STATUS BACKUP_LOCAL_CONFIG_BACKUP_PATH

}

function _brolit_configuration_load_duplicity() {

    local server_config_file=$1

    # Globals
    declare -g BACKUP_DUPLICITY_STATUS
    declare -g BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH
    declare -g BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY
    declare -g BACKUP_DUPLICITY_CONFIG_FULL_LIFE

    BACKUP_DUPLICITY_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.methods[].duplicity[].status")"

    if [[ ${BACKUP_DUPLICITY_STATUS} == "enabled" ]]; then

        BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH="$(json_read_field "${server_config_file}" "BACKUPS.methods[].duplicity[].config[].backup_destination_path")"

        # Check if all required vars are set
        if [ -z "${BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH}" ]; then
            echo "Missing required config vars for local backup method"
            exit 1
        fi

        BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY="$(json_read_field "${server_config_file}" "BACKUPS.methods[].duplicity[].config[].backup_frequency")"

        # Check if all required vars are set
        if [ -z "${BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY}" ]; then
            echo "Missing required config vars for local backup method"
            exit 1
        fi

        BACKUP_DUPLICITY_CONFIG_FULL_LIFE="$(json_read_field "${server_config_file}" "BACKUPS.methods[].duplicity[].config[].backup_full_life")"

        # Check if all required vars are set
        if [ -z "${BACKUP_DUPLICITY_CONFIG_FULL_LIFE}" ]; then
            echo "Missing required config vars for local backup method"
            exit 1
        fi

    fi

    export BACKUP_DUPLICITY_STATUS BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY BACKUP_DUPLICITY_CONFIG_FULL_LIFE

}

function _brolit_configuration_load_backup_retention() {

    local server_config_file=$1

    # Globals
    declare -g BACKUP_RETENTION_KEEP_DAILY
    declare -g BACKUP_RETENTION_KEEP_WEEKLY
    declare -g BACKUP_RETENTION_KEEP_MONTHLY

    ## retention
    BACKUP_RETENTION_KEEP_DAILY="$(json_read_field "${server_config_file}" "BACKUPS.retention[].keep_daily")"

    if [ -z "${BACKUP_RETENTION_KEEP_DAILY}" ]; then
        echo "Missing required config vars for backup retention"
        exit 1
    fi

    BACKUP_RETENTION_KEEP_WEEKLY="$(json_read_field "${server_config_file}" "BACKUPS.retention[].keep_weekly")"

    if [ -z "${BACKUP_RETENTION_KEEP_WEEKLY}" ]; then
        echo "Missing required config vars for backup retention"
        exit 1
    fi

    BACKUP_RETENTION_KEEP_MONTHLY="$(json_read_field "${server_config_file}" "BACKUPS.retention[].keep_monthly")"

    if [ -z "${BACKUP_RETENTION_KEEP_MONTHLY}" ]; then
        echo "Missing required config vars for backup retention"
        exit 1
    fi

    export BACKUP_RETENTION_KEEP_DAILY BACKUP_RETENTION_KEEP_WEEKLY BACKUP_RETENTION_KEEP_MONTHLY

}

function _brolit_configuration_load_email() {

    local server_config_file=$1

    # Globals
    declare -g NOTIFICATION_EMAIL_STATUS
    declare -g NOTIFICATION_EMAIL_MAILA
    declare -g NOTIFICATION_EMAIL_SMTP_SERVER
    declare -g NOTIFICATION_EMAIL_SMTP_PORT
    declare -g NOTIFICATION_EMAIL_SMTP_TLS
    declare -g NOTIFICATION_EMAIL_SMTP_USER
    declare -g NOTIFICATION_EMAIL_SMTP_USER_PASS

    display --indent 2 --text "- Checking Email notifications config"

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

            clear_last_line
            display --indent 4 --text "Missing required config vars for email notifications" --tcolor RED
            exit 1

        else

            clear_last_line
            display --indent 2 --text "- Checking Email notifications config" --result "DONE" --color GREEN

        fi

    else

        clear_last_line
        display --indent 2 --text "- Checking Email notifications config" --result "WARNING" --color YELLOW
        display --indent 4 --text "Email notifications are disabled"

    fi

    export NOTIFICATION_EMAIL_STATUS NOTIFICATION_EMAIL_MAILA NOTIFICATION_EMAIL_SMTP_SERVER NOTIFICATION_EMAIL_SMTP_PORT NOTIFICATION_EMAIL_SMTP_TLS NOTIFICATION_EMAIL_SMTP_USER NOTIFICATION_EMAIL_SMTP_USER_PASS

}

function _brolit_configuration_load_telegram() {

    local server_config_file=$1

    # Globals
    declare -g NOTIFICATION_TELEGRAM_STATUS
    declare -g NOTIFICATION_TELEGRAM_BOT_TOKEN
    declare -g NOTIFICATION_TELEGRAM_CHAT_ID

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

    export NOTIFICATION_TELEGRAM_STATUS NOTIFICATION_TELEGRAM_BOT_TOKEN NOTIFICATION_TELEGRAM_CHAT_ID

}

function _brolit_configuration_load_firewall() {

    # TODO: need a refactor to make this more generic

    local server_config_file=$1

    # Globals
    declare -g FIREWALL_CONFIG_STATUS
    declare -g FIREWALL_CONFIG_APP_LIST_SSH
    declare -g FIREWALL_CONFIG_APP_LIST_HTTP
    declare -g FIREWALL_CONFIG_APP_LIST_HTTPS

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

    export FIREWALL_CONFIG_APP_LIST_SSH FIREWALL_CONFIG_APP_LIST_HTTP FIREWALL_CONFIG_APP_LIST_HTTPS FIREWALL_CONFIG_STATUS

}

function _brolit_configuration_load_cloudflare() {

    local server_config_file=$1

    # Globals
    declare -g SUPPORT_CLOUDFLARE_STATUS
    declare -g SUPPORT_CLOUDFLARE_EMAIL
    declare -g SUPPORT_CLOUDFLARE_API_KEY

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

    export SUPPORT_CLOUDFLARE_STATUS SUPPORT_CLOUDFLARE_EMAIL SUPPORT_CLOUDFLARE_API_KEY

}

function _brolit_configuration_load_monit() {

    local server_config_file=$1

    # Globals
    declare -g MONIT_CONFIG_STATUS
    declare -g MONIT_CONFIG_MAILA

    MONIT_CONFIG_STATUS="$(json_read_field "${server_config_file}" "SUPPORT.monit[].status")"

    if [[ ${MONIT_CONFIG_STATUS} == "enabled" ]]; then

        MONIT_CONFIG_MAILA="$(json_read_field "${server_config_file}" "SUPPORT.monit[].config[].monit_maila")"

        # Check if all required vars are set
        if [[ -z "${MONIT_CONFIG_MAILA}" ]]; then

            echo "Missing required config vars for monit"
            exit 1

        fi

        MONIT_CONFIG_HTTPD="$(json_read_field "${server_config_file}" "SUPPORT.monit[].config[].monit_httpd")"

        # Check if all required vars are set
        if [[ -z "${MONIT_CONFIG_HTTPD}" ]]; then

            echo "Missing required config vars for monit"
            exit 1

        fi

        MONIT_CONFIG_SERVICES="$(json_read_field "${server_config_file}" "SUPPORT.monit[].config[].monit_services")"

        # Check if all required vars are set
        if [[ -z "${MONIT_CONFIG_SERVICES}" ]]; then

            echo "Missing required config vars for monit"
            exit 1

        fi

    fi

    export MONIT_CONFIG_STATUS MONIT_CONFIG_MAILA

}

function _brolit_configuration_load_netdata() {

    local server_config_file=$1

    # Globals
    declare -g SUPPORT_NETDATA_STATUS
    declare -g SUPPORT_NETDATA_CONFIG_SUBDOMAIN
    declare -g SUPPORT_NETDATA_CONFIG_USER
    declare -g SUPPORT_NETDATA_CONFIG_USER_PASS
    declare -g SUPPORT_NETDATA_CONFIG_ALARM_LEVEL

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

    export SUPPORT_NETDATA_STATUS SUPPORT_NETDATA_CONFIG_SUBDOMAIN SUPPORT_NETDATA_CONFIG_USER SUPPORT_NETDATA_CONFIG_USER_PASS SUPPORT_NETDATA_CONFIG_ALARM_LEVEL

}

function brolit_configuration_apps_load() {

    _brolit_configuration_app_mysql

    _brolit_configuration_app_dropbox

}

# TODO: maybe remove this from brolit_conf.json
function brolit_configuration_firewall() {

    # Check if firewall is enabled
    if [[ ${FIREWALL_CONFIG_STATUS} == "enabled" ]]; then

        # Enabling firewall
        firewall_enable

        # Get all listed apps
        app_list="$(json_read_field "/root/.brolit_conf.json" "FIREWALL.config[].app_list[]")"

        # Get keys
        app_list_keys="$(jq -r 'keys[]' <<<"${app_list}" | sed ':a; N; $!ba; s/\n/ /g')"

        # String to array
        IFS=' ' read -r -a app_list_keys_array <<<"$app_list_keys"

        # Loop through all apps keys
        for app_list_key in "${app_list_keys_array[@]}"; do

            app_list_value="$(jq -r ."${app_list_key}" <<<"${app_list}")"

            if [[ ${app_list_value} == "allow" ]]; then

                # Allow service on firewall
                firewall_allow "${app_list_key}"

            fi

        done

    else

        # Log
        log_event "info" "Firewall is disabled" "false"
        display --indent 6 --text "- Firewall disabled" --result "WARNING" --color YELLOW

    fi

}

function brolit_configuration_app_check() {

    local -n services_list=$1

    for service in "${services_list[@]}"; do

        case ${service} in

        "mysql")

            mysql_installed="$(package_is_installed "mysql-server")"

            if [[ ${mysql_installed} -eq 1 ]]; then

                mysql_installed="$(package_is_installed "mariadb-server")"

                if [[ ${mysql_installed} -eq 1 ]]; then

                    display --indent 2 --text "- Checking for installed DB engine" --result "WARNING" --color YELLOW
                    display --indent 2 --text "MySQL or MariaDB server are not installed"

                fi

            fi

            ;;

        "nginx")

            nginx_installed="$(package_is_installed "nginx")"

            if [[ ${nginx_installed} -eq 1 ]]; then

                display --indent 2 --text "- Checking for installed web server" --result "OK" --color GREEN

            else

                display --indent 2 --text "- Checking for installed web server" --result "WARNING" --color YELLOW
                display --indent 2 --text "Nginx is not installed"

            fi

            ;;

        "php")

            php_installed="$(package_is_installed "php")"

            if [[ ${php_installed} -eq 1 ]]; then

                display --indent 2 --text "- Checking for installed PHP engine" --result "OK" --color GREEN

            else

                display --indent 2 --text "- Checking for installed PHP engine" --result "WARNING" --color YELLOW
                display --indent 2 --text "PHP is not installed"

            fi

            ;;

        "python")

            python_installed="$(package_is_installed "python")"

            if [[ ${python_installed} -eq 1 ]]; then

                display --indent 2 --text "- Checking for installed Python engine" --result "OK" --color GREEN

            else

                display --indent 2 --text "- Checking for installed Python engine" --result "WARNING" --color YELLOW
                display --indent 2 --text "Python is not installed"

            fi

            ;;

        *)

            echo "Unknown service: ${service}"

            ;;

        esac

    done

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

function _brolit_configuration_app_mysql() {

    is_mysql_installed="$(package_is_installed "mysql")"

    if [[ ${is_mysql_installed} == "true" ]]; then

        mysql_ask_root_psw

    fi

}

################################################################################
# Private: check Dropbox Uploader configuration
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_app_dropbox() {

    # Checking global var
    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        output="$("${DROPBOX_UPLOADER}" list)"

        exitstatus=$?

        if [[ ${exitstatus} -eq 0 && ${output} != "" ]]; then

            display --indent 2 --text "- Checking Dropbox Uploader" --result "DONE" --color GREEN

        else

            display --indent 2 --text "Something went wrong, please finish the configuration running: ${DROPBOX_UPLOADER}"

        fi

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
