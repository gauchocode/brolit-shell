#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.36
#############################################################################

function _settings_config_server_configuration() {

    # Server config (new concept)
    local server_configs # Options: mysql+nginx+php, nginx+php, mysql, other
    local default_config="mysql+nginx+php"

    if [[ -z ${SERVER_CONFIG} ]]; then

        declare -g SERVER_CONFIG

        server_configs="mysql+nginx+php nginx+php mysql other"
        SERVER_CONFIG=$(whiptail --title "Server Configuration" --menu "Choose the server configuration:" 20 78 10 $(for x in ${server_configs}; do echo "$x [X]"; done) --default-item "${default_config}" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            echo "SERVER_CONFIG=${SERVER_CONFIG}" >>/root/.broobe-utils-options

        else

            return 1

        fi

    fi

}

function _settings_config_mysql() {

    if [[ ${SERVER_CONFIG} == *"mysql"* ]]; then

        ask_mysql_root_psw

    fi

}

function _settings_config_smtp() {

    if [[ -z "${SMTP_SERVER}" ]]; then
        SMTP_SERVER=$(whiptail --title "SMTP SERVER" --inputbox "Please insert the SMTP Server" 10 60 "${SMTP_SERVER_OLD}" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
            echo "SMTP_SERVER="${SMTP_SERVER} >>/root/.broobe-utils-options
        else
            return 1
        fi
    fi
    if [[ -z "${SMTP_PORT}" ]]; then
        SMTP_PORT=$(whiptail --title "SMTP SERVER" --inputbox "Please insert the SMTP Server Port" 10 60 "${SMTP_PORT_OLD}" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
            echo "SMTP_PORT=${SMTP_PORT}" >>/root/.broobe-utils-options
        else
            return 1
        fi
    fi
    # TODO: change to SMTP_TYPE (none, ssl, tls)
    if [[ -z "${SMTP_TLS}" ]]; then
        SMTP_TLS=$(whiptail --title "SMTP TLS" --inputbox "SMTP yes or no:" 10 60 "${SMTP_TLS_OLD}" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
            echo "SMTP_TLS=${SMTP_TLS}" >>/root/.broobe-utils-options
        else
            return 1
        fi
    fi
    if [[ -z "${SMTP_U}" ]]; then
        SMTP_U=$(whiptail --title "SMTP User" --inputbox "Please insert the SMTP user" 10 60 "${SMTP_U_OLD}" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
            echo "SMTP_U=${SMTP_U}" >>/root/.broobe-utils-options
        else
            return 1
        fi
    fi
    if [[ -z "${SMTP_P}" ]]; then
        SMTP_P=$(whiptail --title "SMTP Password" --inputbox "Please insert the SMTP user password" 10 60 "${SMTP_P_OLD}" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
            echo "SMTP_P=${SMTP_P}" >>/root/.broobe-utils-options
        else
            return 1
        fi
    fi

}

### BETA
##
function _settings_config_duplicity() {

    # DUPLICITY CONFIG
    if [[ -z "${DUP_BK}" ]]; then

        DUP_BK_DEFAULT=false

        #whiptail_message_with_skip_option "Duplicity Support" "This script supports Duplicity. Do you want to enable backups with it?"

        DUP_BK=$(whiptail --title "Duplicity Backup Support?" --inputbox "Please insert true or false" 10 60 "${DUP_BK_DEFAULT}" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            echo "DUP_BK=${DUP_BK}" >>/root/.broobe-utils-options

            if [[ ${DUP_BK} == true ]]; then

                if [[ -z "${DUP_ROOT}" ]]; then

                    # Duplicity Backups Directory
                    DUP_ROOT_DEFAULT="/media/backups/PROJECT_NAME"
                    DUP_ROOT=$(whiptail --title "Duplicity Backup Directory" --inputbox "Insert the directory path to storage duplicity Backup" 10 60 "${DUP_ROOT_DEFAULT}" 3>&1 1>&2 2>&3)
                    exitstatus=$?
                    if [[ ${exitstatus} -eq 0 ]]; then
                        echo "DUP_ROOT=${DUP_ROOT}" >>/root/.broobe-utils-options
                    else
                        exit 1
                    fi

                fi

                if [[ -z "${DUP_SRC_BK}" ]]; then

                    # Source of Directories to Backup
                    DUP_SRC_BK_DEFAULT="${SITES}"
                    DUP_SRC_BK=$(whiptail --title "Projects Root Directory" --inputbox "Insert the root directory of projects to backup" 10 60 "${DUP_SRC_BK_DEFAULT}" 3>&1 1>&2 2>&3)
                    exitstatus=$?
                    if [[ ${exitstatus} -eq 0 ]]; then
                        echo "DUP_SRC_BK=${DUP_SRC_BK}" >>/root/.broobe-utils-options
                    else
                        exit 1
                    fi

                fi

                if [[ -z "${DUP_FOLDERS}" ]]; then

                    # Folders to Backup
                    DUP_FOLDERS_DEFAULT="FOLDER1,FOLDER2"
                    DUP_FOLDERS=$(whiptail --title "Projects Root Directory" --inputbox "Insert the root directory of projects to backup" 10 60 "${DUP_FOLDERS_DEFAULT}" 3>&1 1>&2 2>&3)
                    exitstatus=$?
                    if [[ ${exitstatus} -eq 0 ]]; then
                        echo "DUP_FOLDERS=${DUP_FOLDERS}" >>/root/.broobe-utils-options
                    else
                        exit 1
                    fi

                fi

                if [[ -z "${DUP_BK_FULL_FREQ}" ]]; then

                    # Create a new full backup every ...
                    DUP_BK_FULL_FREQ_DEFAULT="7D"
                    DUP_BK_FULL_FREQ=$(whiptail --title "Projects Root Directory" --inputbox "Insert the root directory of projects to backup" 10 60 "${DUP_BK_FULL_FREQ_DEFAULT}" 3>&1 1>&2 2>&3)
                    exitstatus=$?
                    if [[ ${exitstatus} -eq 0 ]]; then
                        echo "DUP_BK_FULL_FREQ=${DUP_BK_FULL_FREQ}" >>/root/.broobe-utils-options
                    else
                        exit 1
                    fi

                fi

                if [[ -z "${DUP_BK_FULL_LIFE}" ]]; then

                    # Delete any backup older than this
                    DUP_BK_FULL_LIFE_DEFAULT="14D"
                    DUP_BK_FULL_LIFE=$(whiptail --title "Projects Root Directory" --inputbox "Insert the root directory of projects to backup" 10 60 "${DUP_BK_FULL_LIFE_DEFAULT}" 3>&1 1>&2 2>&3)
                    exitstatus=$?
                    if [[ ${exitstatus} -eq 0 ]]; then
                        echo "DUP_BK_FULL_LIFE=${DUP_BK_FULL_LIFE}" >>/root/.broobe-utils-options
                    else
                        exit 1
                    fi

                fi

            else

                echo "DUP_ROOT=none" >>/root/.broobe-utils-options
                echo "DUP_SRC_BK=none" >>/root/.broobe-utils-options
                echo "DUP_FOLDERS=none" >>/root/.broobe-utils-options
                echo "DUP_BK_FULL_FREQ=none" >>/root/.broobe-utils-options
                echo "DUP_BK_FULL_LIFE=none" >>/root/.broobe-utils-options

            fi

        fi

    fi
}

function _settings_config_mailcow() {

    local mailcow_default_path
    local mailcow_path
    local mailcow_support

    # MailCow Dockerized default files location
    mailcow_default_path="/opt/mailcow-dockerized"

    # Checking /root/.broobe-utils-options global var
    if [[ -z "${MAILCOW_BK}" ]]; then

        whiptail_message_with_skip_option "Mailcow Support" "This script supports Mailcow. Do you want to enable backups for it?"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Checking /root/.broobe-utils-options global vars
            if [[ -z "${MAILCOW}" && "${MAILCOW_BK}" == true ]]; then

                mailcow_path=$(whiptail --title "Mailcow Support" --inputbox "Insert the path where Mailcow is installed" 10 60 "${mailcow_default_path}" 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [[ ${exitstatus} -eq 0 ]]; then
                    mailcow_support=true
                    echo "MAILCOW_BK=${mailcow_support}" >>/root/.broobe-utils-options
                    echo "MAILCOW=${mailcow_path}" >>/root/.broobe-utils-options
                else
                    return 1

                fi

            fi

        else

            mailcow_support=false
            echo "MAILCOW_BK=${mailcow_support}" >>/root/.broobe-utils-options

        fi

    fi
}

function _settings_config_dropbox() {

    # Checking /root/.broobe-utils-options global var
    if [[ -z "${DROPBOX_ENABLE}" ]]; then

        whiptail_message_with_skip_option "Dropbox Support" "This script supports Dropbox integration via API. If you have a Dropbox account you can configure it to backup and restore projects from here. Do you want to enable Dropbox support?"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Setting option on script config file
            DROPBOX_ENABLE="true"
            echo "DROPBOX_ENABLE=${DROPBOX_ENABLE}" >>/root/.broobe-utils-options

            # Generating Dropbox api config file
            generate_dropbox_config

        else
            DROPBOX_ENABLE="false"
            echo "DROPBOX_ENABLE=${DROPBOX_ENABLE}" >>/root/.broobe-utils-options

        fi

    fi

}

function _settings_config_cloudflare() {

    # Checking /root/.broobe-utils-options global var
    if [[ -z "${CLOUDFLARE_ENABLE}" ]]; then

        whiptail_message_with_skip_option "Cloudflare Support" "This script supports Cloudflare integration via API. If you have a Cloudflare account you can configure it to manage your domains from here. Do you want to enable Cloudflare support?"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Setting option on script config file
            CLOUDFLARE_ENABLE="true"
            echo "CLOUDFLARE_ENABLE=${CLOUDFLARE_ENABLE}" >>/root/.broobe-utils-options

            # Generating Cloudflare api config file
            generate_cloudflare_config

        else
            CLOUDFLARE_ENABLE="false"
            echo "CLOUDFLARE_ENABLE=${CLOUDFLARE_ENABLE}" >>/root/.broobe-utils-options

        fi

    fi

}

function _settings_config_telegram() {

    # Checking /root/.broobe-utils-options global var
    if [[ -z "${TELEGRAM_NOTIF}" ]]; then

        whiptail_message_with_skip_option "Telegram Notification" "Do you want to enable Telegram notification support?"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Setting option on script config file
            TELEGRAM_NOTIF="true"
            echo "TELEGRAM_NOTIF=${TELEGRAM_NOTIF}" >>/root/.broobe-utils-options

            # Generating Telegram api config file
            generate_telegram_config

        else
            TELEGRAM_NOTIF="false"
            echo "TELEGRAM_NOTIF=${TELEGRAM_NOTIF}" >>/root/.broobe-utils-options

        fi

    fi

}

function _settings_config_notifications() {

    #TODO: option to select notification types (mail, telegram)

    # Checking /root/.broobe-utils-options global vars
    if [[ -z "${MAIL_NOTIF}" ]]; then

        whiptail_message_with_skip_option "E-Mail Notification" "Do you want to enable E-Mail notification support?"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Setting option on script config file
            MAIL_NOTIF="true"
            echo "MAIL_NOTIF=${MAIL_NOTIF}" >>/root/.broobe-utils-options

            if [[ -z "${MAILA}" ]]; then

                MAILA=$(whiptail --title "Notification Email" --inputbox "Insert the email where you want to receive notifications." 10 60 "${MAILA_OLD}" 3>&1 1>&2 2>&3)
                exitstatus=$?
                if [[ ${exitstatus} -eq 0 ]]; then
                    echo "MAILA=${MAILA}" >>/root/.broobe-utils-options
                else
                    return 1
                fi

            fi

            _settings_config_smtp

        else
            MAIL_NOTIF="false"
            echo "MAIL_NOTIF=${MAIL_NOTIF}" >>/root/.broobe-utils-options

        fi

    fi

}

#
#################################################################################
#
# * Public
#
#################################################################################
#

function check_script_configuration() {

    script_configuration_wizard "initial"

}

function script_configuration_wizard() {

    # Description
    # This function could run for 3 reasons:
    # Initial setup, check if all needed vars are configured or reconfigure all settings.
    # Important: Need to be runned only after load config files.

    # Parameters
    # $1 = ${config_mode} // options: initial or reconfigure

    local config_mode=$1

    if [[ ${config_mode} == "reconfigure" ]]; then

        # Backup vars
        SMTP_SERVER_OLD=${SMTP_SERVER}
        SMTP_PORT_OLD=${SMTP_PORT}
        SMTP_TLS_OLD=${SMTP_TLS}
        SMTP_U_OLD=${SMTP_U}
        SMTP_P_OLD=${SMTP_P}
        MAILA_OLD=${MAILA}
        SITES_OLD=${SITES}

        MAIL_NOTIF_OLD=${MAIL_NOTIF}
        TELEGRAM_NOTIF_OLD=${TELEGRAM_NOTIF}
        CLOUDFLARE_ENABLE_OLD=${CLOUDFLARE_ENABLE}
        DROPBOX_ENABLE_OLD=${DROPBOX_ENABLE}
        DUP_BK_OLD=${DUP_BK}
        MAILCOW_BK_OLD=${MAILCOW_BK}

        # Reset config vars
        SMTP_SERVER=""
        SMTP_PORT=""
        SMTP_TLS=""
        SMTP_U=""
        SMTP_P=""
        MAILA=""
        SITES=""

        # Notif var
        MAIL_NOTIF="true"
        TELEGRAM_NOTIF="false"

        # Cloudflare
        CLOUDFLARE_ENABLE="true"

        # Backup
        DROPBOX_ENABLE="true"
        DUP_BK="false"
        MAILCOW_BK="false"

        #Rename old config file
        mv "/root/.broobe-utils-options" "/root/.broobe-utils-options_bk"

    fi

    if [[ -z "${SITES}" ]]; then

        if [[ -n "${SITES_OLD}" ]]; then
            # SITES_OLD defined
            SITES_DEFAULT="${SITES_OLD}"
        else
            SITES_DEFAULT="/var/www"
        fi

        SITES=$(whiptail --title "Websites Root Directory" --inputbox "The path where websites are stored. Ex: /var/www or /usr/share/nginx" 10 60 "${SITES_DEFAULT}" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
            echo "SITES=${SITES}" >>/root/.broobe-utils-options
        else
            exit 1
        fi
    fi

    _settings_config_server_configuration

    _settings_config_mysql

    _settings_config_dropbox

    _settings_config_cloudflare

    _settings_config_telegram

    _settings_config_notifications

    _settings_config_mailcow

    #_settings_config_duplicity

}

function generate_dropbox_config() {

    local dropbox_config_first_msg
    local dropbox_config_second_msg
    local dropbox_config_third_msg
    local dropbox_config_fourth_msg

    local app_key
    local app_secret
    #local access_code

    local oauth_access_token

    local whip_title="Dropbox Configuration"

    RESPONSE_FILE="${TMP_DIR}/du_resp_debug"
    API_OAUTH_TOKEN="https://api.dropbox.com/oauth2/token"
    API_OAUTH_AUTHORIZE="https://www.dropbox.com/oauth2/authorize"

    # Checking var of ${DPU_CONFIG_FILE}
    if [[ -z ${OAUTH_ACCESS_TOKEN} || -z ${OAUTH_APP_SECRET} ]]; then

        dropbox_config_first_msg+=" 1) Log in: dropbox.com/developers/apps/create\n"
        dropbox_config_first_msg+=" 2) Click on 'Create App'\n"
        dropbox_config_first_msg+=" 3) Select 'Choose an API: Scoped Access'\n"
        dropbox_config_first_msg+=" 4) Choose the type of access: 'App folder'.\n"
        dropbox_config_first_msg+=" 5) Enter a \"App Name\" and create the app.\n"
        dropbox_config_first_msg+=" 6) On tab 'permissions' check \"files.metadata.read/write\" and \"files.content.read/write\"\n"
        dropbox_config_first_msg+=" 7) Click on 'Submit' button.\n"

        whiptail_message "${whip_title}" "${dropbox_config_first_msg}"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            dropbox_config_second_msg+="\n 8) Click on 'settings' and provide the following information.\n\n"
            dropbox_config_second_msg+=" 9) App key:\n\n"

            # OAUTH_APP_KEY
            app_key="$(whiptail --title "${whip_title}" --inputbox "${dropbox_config_second_msg}" 15 60 3>&1 1>&2 2>&3)"
            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then

                # Write config file
                echo "CONFIGFILE_VERSION=2.0" >"${DPU_CONFIG_FILE}"
                echo "OAUTH_APP_KEY=${app_key}" >>"${DPU_CONFIG_FILE}"

            else
                return 1

            fi

            # OAUTH_APP_SECRET
            dropbox_config_third_msg+=" 10) App secret:\n\n"
            app_secret="$(whiptail --title "${whip_title}" --inputbox "${dropbox_config_third_msg}" 15 60 3>&1 1>&2 2>&3)"
            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then

                # Write config file
                echo "OAUTH_APP_SECRET=${app_secret}" >>"${DPU_CONFIG_FILE}"

            else
                return 1

            fi

            auth_url="${API_OAUTH_AUTHORIZE}?client_id=${app_key}&token_access_type=offline&response_type=code"

            # ACCESS_CODE
            dropbox_config_fourth_msg+=" 11) Now open the following link, \n\n"
            dropbox_config_fourth_msg+=" ${auth_url} \n\n"
            dropbox_config_fourth_msg+=" Allow suggested permissions and copy paste here the Access Code:\n\n"

            oauth_access_token="$(whiptail --title "${whip_title}" --inputbox "${dropbox_config_fourth_msg}" 15 60 3>&1 1>&2 2>&3)"
            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then

                # Get $OAUTH_REFRESH_TOKEN
                curl -k $API_OAUTH_TOKEN -d code="${oauth_access_token}" -d grant_type=authorization_code -u "$app_key":"$app_secret" -o "${RESPONSE_FILE}" 2>/dev/null
                ## Extract from log
                OAUTH_REFRESH_TOKEN=$(sed -n 's/.*"refresh_token": "\([^"]*\).*/\1/p' "$RESPONSE_FILE")

                # Write config file
                echo "OAUTH_REFRESH_TOKEN=${OAUTH_REFRESH_TOKEN}" >>"${DPU_CONFIG_FILE}"

                log_event "info" "Dropbox configuration has been saved!" "false"

            else
                return 1

            fi

        else
            return 1

        fi

    fi

}

function generate_cloudflare_config() {

    # ${CLF_CONFIG_FILE} is a Global var

    local cfl_email
    local cfl_api_token
    local cfl_email_string
    local cfl_api_token_string

    # Checking vars of ${CLF_CONFIG_FILE}
    if [[ -z ${dns_cloudflare_email} || -z ${dns_cloudflare_api_key} ]]; then

        cfl_email_string="\n\nPlease insert the Cloudflare email account here:\n\n"

        cfl_email=$(whiptail --title "Cloudflare Configuration" --inputbox "${cfl_email_string}" 15 60 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            echo "dns_cloudflare_email=${cfl_email}" >"${CLF_CONFIG_FILE}"

            cfl_api_token_string+="\n Please insert the Cloudflare Global API Key.\n"
            cfl_api_token_string+=" 1) Log in on: cloudflare.com\n"
            cfl_api_token_string+=" 2) Login and go to \"My Profile\".\n"
            cfl_api_token_string+=" 3) Choose the type of access you need.\n"
            cfl_api_token_string+=" 4) Click on \"API TOKENS\" \n"
            cfl_api_token_string+=" 5) In \"Global API Key\" click on \"View\" button.\n"
            cfl_api_token_string+=" 6) Copy the code and paste it here:\n\n"

            cfl_api_token=$(whiptail --title "Cloudflare Configuration" --inputbox "${cfl_api_token_string}" 15 60 3>&1 1>&2 2>&3)
            exitstatus=$?
            if [[ ${exitstatus} -eq 0 ]]; then

                # Write config file
                echo "dns_cloudflare_api_key=${cfl_api_token}" >>"${CLF_CONFIG_FILE}"
                log_event "info" "The Cloudflare configuration has been saved!"

            else
                return 1

            fi

        else
            return 1

        fi

    fi

}

function generate_telegram_config() {

    # ${TEL_CONFIG_FILE} is a Global var

    local botfather_whip_line
    local botfather_key

    botfather_whip_line+=" \n "
    botfather_whip_line+=" Open Telegram and follow the next steps:\n\n"
    botfather_whip_line+=" 1) Get a bot token. Contact @BotFather (https://t.me/BotFather) and send the command /newbot.\n"
    botfather_whip_line+=" 2) Follow the instructions and paste the token to access the HTTP API:\n\n"

    botfather_key="$(whiptail --title "Telegram BotFather Configuration" --inputbox "${botfather_whip_line}" 15 60 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Write config file
        echo "botfather_key=${botfather_key}" >>"/root/.telegram.conf"

        telegram_id_whip_line+=" \n\n "
        telegram_id_whip_line+=" 3) Contact the @myidbot (https://t.me/myidbot) bot and send the command /getid to get \n"
        telegram_id_whip_line+=" your personal chat id or invite him into a group and issue the same command to get the group chat id.\n"
        telegram_id_whip_line+=" 4) Paste the ID here:\n\n"

        telegram_user_id="$(whiptail --title "Telegram: BotID Configuration" --inputbox "${telegram_id_whip_line}" 15 60 3>&1 1>&2 2>&3)"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            # Write config file
            echo "telegram_user_id=${telegram_user_id}" >>"/root/.telegram.conf"
            log_event "info" "The Telegram configuration has been saved!"

            # shellcheck source=${SFOLDER}/libs/telegram_notification_helper.sh
            source "${SFOLDER}/libs/telegram_notification_helper.sh"

            telegram_send_notification "✅ ${VPSNAME}" "Telegram notifications configured!" ""

        else

            return 1

        fi

    else

        return 1

    fi

}
