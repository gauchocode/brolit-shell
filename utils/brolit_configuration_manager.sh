#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.4
################################################################################
#
# Server Config Manager: Brolit server configuration management.
#
################################################################################

################################################################################
# Private: load server configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_server_config() {

    local server_config_file="${1}"

    # Globals
    declare -g SERVER_TIMEZONE
    #declare -g UNATTENDED_UPGRADES
    declare -g SERVER_ROLE_WEBSERVER
    declare -g SERVER_ROLE_DATABASE
    declare -g SERVER_ADDITIONAL_IPS

    # Read required vars from server config file
    SERVER_TIMEZONE="$(json_read_field "${server_config_file}" "SERVER_CONFIG.timezone")"
    [[ -z "${SERVER_TIMEZONE}" ]] && die "Error reading SERVER_TIMEZONE from server config file."

    #UNATTENDED_UPGRADES="$(json_read_field "${server_config_file}" "SERVER_CONFIG.unattended_upgrades")"
    #[[ -z "${UNATTENDED_UPGRADES}" ]] && die "Error reading UNATTENDED_UPGRADES from server config file."

    if [[ -z "${SERVER_ROLE_WEBSERVER}" ]]; then
        SERVER_ROLE_WEBSERVER="$(json_read_field "${server_config_file}" "SERVER_CONFIG.config[].webserver")"
        [[ -z "${SERVER_ROLE_WEBSERVER}" ]] && die "Error reading SERVER_ROLE_WEBSERVER from server config file."
    fi

    if [[ -z "${SERVER_ROLE_DATABASE}" ]]; then
        SERVER_ROLE_DATABASE="$(json_read_field "${server_config_file}" "SERVER_CONFIG.config[].database")"
        [[ -z "${SERVER_ROLE_DATABASE}" ]] && die "Error reading SERVER_ROLE_DATABASE from server config file."
    fi

    if [[ ${SERVER_ROLE_WEBSERVER} != "enabled" ]] && [[ ${SERVER_ROLE_DATABASE} != "enabled" ]]; then
        log_event "error" "At least one server role need to be defined." "true"
        log_event "error" "Please edit the file .brolit_conf.json and execute BROLIT again." "true"
        exit 1
    fi

    # Read optional vars from server config file
    SERVER_ADDITIONAL_IPS="$(json_read_field "${server_config_file}" "SERVER_CONFIG.additional_ips")"

    export SERVER_TIMEZONE SERVER_ROLE_WEBSERVER SERVER_ROLE_DATABASE SERVER_ADDITIONAL_IPS
    #export UNATTENDED_UPGRADES

}

################################################################################
# Private: load sftp backup configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_backup_sftp() {

    local server_config_file="${1}"

    # Globals
    declare -g BACKUP_SFTP_STATUS
    declare -g BACKUP_SFTP_CONFIG_SERVER_IP
    declare -g BACKUP_SFTP_CONFIG_SERVER_PORT
    declare -g BACKUP_SFTP_CONFIG_SERVER_USER
    declare -g BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD
    declare -g BACKUP_SFTP_CONFIG_SERVER_REMOTE_PATH

    BACKUP_SFTP_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].status")"

    if [[ ${BACKUP_SFTP_STATUS} == "enabled" ]]; then

        # Required
        BACKUP_SFTP_CONFIG_SERVER_IP="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_ip")"
        [[ -z "${BACKUP_SFTP_CONFIG_SERVER_IP}" ]] && die "Error reading BACKUP_SFTP_CONFIG_SERVER_IP from server config file."

        BACKUP_SFTP_CONFIG_SERVER_PORT="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_port")"
        [[ -z "${BACKUP_SFTP_CONFIG_SERVER_PORT}" ]] && die "Error reading BACKUP_SFTP_CONFIG_SERVER_PORT from server config file."

        BACKUP_SFTP_CONFIG_SERVER_USER="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_user")"
        [[ -z "${BACKUP_SFTP_CONFIG_SERVER_USER}" ]] && die "Error reading BACKUP_SFTP_CONFIG_SERVER_USER from server config file."

        BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_user_password")"
        [[ -z "${BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD}" ]] && die "Error reading BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD from server config file."

        BACKUP_SFTP_CONFIG_SERVER_REMOTE_PATH="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_remote_path")"
        [[ -z "${BACKUP_SFTP_CONFIG_SERVER_REMOTE_PATH}" ]] && die "Error reading BACKUP_SFTP_CONFIG_SERVER_REMOTE_PATH from server config file."

    fi

    export BACKUP_SFTP_STATUS BACKUP_SFTP_CONFIG_SERVER_IP BACKUP_SFTP_CONFIG_SERVER_PORT BACKUP_SFTP_CONFIG_SERVER_USER BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD

}

################################################################################
# Private: load dropbox backup configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_backup_dropbox() {

    local server_config_file="${1}"

    # Globals
    declare -g BACKUP_DROPBOX_STATUS
    declare -g BACKUP_DROPBOX_CONFIG_FILE

    BACKUP_DROPBOX_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.methods[].dropbox[].status")"

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        BACKUP_DROPBOX_CONFIG_FILE="$(json_read_field "${server_config_file}" "BACKUPS.methods[].dropbox[].config[].file")"

        # Some globals
        declare -g DPU_F
        declare -g DROPBOX_UPLOADER

        # Dropbox-uploader directory
        DPU_F="${BROLIT_MAIN_DIR}/tools/third-party/dropbox-uploader"

        # Dropbox-uploader runner
        DROPBOX_UPLOADER="${DPU_F}/dropbox_uploader.sh"

        if [ -f "${BACKUP_DROPBOX_CONFIG_FILE}" ]; then

            # shellcheck source=~/.dropbox_uploader
            source "${BACKUP_DROPBOX_CONFIG_FILE}"

            export DPU_F DROPBOX_UPLOADER

        else

            display --indent 6 --text "- Checking Dropbox config file" --result "FAIL" --color RED
            display --indent 8 --text "Config file not found: ${BACKUP_DROPBOX_CONFIG_FILE}" --tcolor YELLOW
            display --indent 8 --text "Please finish the configuration running: ${DROPBOX_UPLOADER}" --tcolor YELLOW

            die "Dropbox config file not found. Please finish the configuration running: ${DROPBOX_UPLOADER}"

        fi

    fi

    export BACKUP_DROPBOX_STATUS BACKUP_DROPBOX_CONFIG_FILE

}

################################################################################
# Private: load local backup configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_backup_local() {

    local server_config_file="${1}"

    # Globals
    declare -g BACKUP_LOCAL_STATUS
    declare -g BACKUP_LOCAL_CONFIG_BACKUP_PATH

    BACKUP_LOCAL_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.methods[].local[].status")"

    if [[ ${BACKUP_LOCAL_STATUS} == "enabled" ]]; then

        BACKUP_LOCAL_CONFIG_BACKUP_PATH="$(json_read_field "${server_config_file}" "BACKUPS.methods[].local[].config[].backup_path")"
        [[ -z "${BACKUP_LOCAL_CONFIG_BACKUP_PATH}" ]] && die "Error reading BACKUP_LOCAL_CONFIG_BACKUP_PATH from server config file."

    fi

    export BACKUP_LOCAL_STATUS BACKUP_LOCAL_CONFIG_BACKUP_PATH

}

################################################################################
# Private: load s3 backup configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_backup_s3() {

    local server_config_file="${1}"

    # Globals
    declare -g BACKUP_S3_STATUS
    declare -g BACKUP_S3_BUCKET
    declare -g BACKUP_S3_ENDPOINT_URL
    declare -g BACKUP_S3_ACCESS_KEY
    declare -g BACKUP_S3_SECRET_KEY
    declare -g BACKUP_S3_CONFIG_BACKUP_DESTINATION_PATH
    #declare -g BACKUP_S3_CONFIG_BACKUP_FREQUENCY
    #declare -g BACKUP_S3_CONFIG_FULL_LIFE

    BACKUP_S3_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.methods[].s3[].status")"

    if [[ ${BACKUP_S3_STATUS} == "enabled" ]]; then

        # Required
        BACKUP_S3_BUCKET="$(json_read_field "${server_config_file}" "BACKUPS.methods[].s3[].config[].bucket")"
        [[ -z "${BACKUP_S3_BUCKET}" ]] && die "Error reading BACKUP_S3_BUCKET from server config file."

        BACKUP_S3_ENDPOINT_URL="$(json_read_field "${server_config_file}" "BACKUPS.methods[].s3[].config[].endpoint_url")"
        [[ -z "${BACKUP_S3_ENDPOINT_URL}" ]] && die "Error reading BACKUP_S3_ENDPOINT_URL from server config file."

        BACKUP_S3_ACCESS_KEY="$(json_read_field "${server_config_file}" "BACKUPS.methods[].s3[].config[].access_key")"
        [[ -z "${BACKUP_S3_ACCESS_KEY}" ]] && die "Error reading BACKUP_S3_ACCESS_KEY from server config file."

        BACKUP_S3_SECRET_KEY="$(json_read_field "${server_config_file}" "BACKUPS.methods[].s3[].config[].secret_key")"
        [[ -z "${BACKUP_S3_SECRET_KEY}" ]] && die "Error reading BACKUP_S3_SECRET_KEY from server config file."

        BACKUP_S3_CONFIG_BACKUP_DESTINATION_PATH="$(json_read_field "${server_config_file}" "BACKUPS.methods[].s3[].config[].backup_path")"
        [[ -z "${BACKUP_S3_CONFIG_BACKUP_DESTINATION_PATH}" ]] && die "Error reading BACKUP_S3_CONFIG_BACKUP_DESTINATION_PATH from server config file."

        #BACKUP_S3_CONFIG_BACKUP_FREQUENCY="$(json_read_field "${server_config_file}" "BACKUPS.methods[].s3[].config[].backup_frequency")"
        #if [ -z "${BACKUP_S3_CONFIG_BACKUP_FREQUENCY}" ]; then
        #    log_event "error" "Missing required config vars for s3 backup method" "true"
        #    exit 1
        #fi

        #BACKUP_S3_CONFIG_FULL_LIFE="$(json_read_field "${server_config_file}" "BACKUPS.methods[].s3[].config[].backup_full_life")"
        #if [ -z "${BACKUP_S3_CONFIG_FULL_LIFE}" ]; then
        #    log_event "error" "Missing required config vars for s3 backup method" "true"
        #    exit 1
        #fi

    fi

    export BACKUP_S3_STATUS BACKUP_S3_BUCKET BACKUP_S3_ENDPOINT_URL BACKUP_S3_ACCESS_KEY BACKUP_S3_SECRET_KEY BACKUP_S3_CONFIG_BACKUP_DESTINATION_PATH

}

################################################################################
# Private: load duplicity backup configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_backup_duplicity() {

    local server_config_file="${1}"

    # Globals
    declare -g BACKUP_DUPLICITY_STATUS
    declare -g BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH
    declare -g BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY
    declare -g BACKUP_DUPLICITY_CONFIG_FULL_LIFE

    BACKUP_DUPLICITY_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.methods[].duplicity[].status")"

    if [[ ${BACKUP_DUPLICITY_STATUS} == "enabled" ]]; then

        # Required
        BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH="$(json_read_field "${server_config_file}" "BACKUPS.methods[].duplicity[].config[].backup_destination_path")"
        [[ -z "${BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH}" ]] && die "Error reading BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH from server config file."

        BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY="$(json_read_field "${server_config_file}" "BACKUPS.methods[].duplicity[].config[].backup_frequency")"
        [[ -z "${BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY}" ]] && die "Error reading BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY from server config file."

        BACKUP_DUPLICITY_CONFIG_FULL_LIFE="$(json_read_field "${server_config_file}" "BACKUPS.methods[].duplicity[].config[].backup_full_life")"
        [[ -z "${BACKUP_DUPLICITY_CONFIG_FULL_LIFE}" ]] && die "Error reading BACKUP_DUPLICITY_CONFIG_FULL_LIFE from server config file."

    fi

    export BACKUP_DUPLICITY_STATUS BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY BACKUP_DUPLICITY_CONFIG_FULL_LIFE

}

################################################################################
# Private: load backup retentions configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_backup_config() {

    local server_config_file="${1}"

    # Globals
    declare -g BACKUP_CONFIG_PROJECTS_STATUS
    declare -g BACKUP_CONFIG_DATABASES_STATUS
    declare -g BACKUP_CONFIG_SERVER_CFG_STATUS
    declare -g BACKUP_CONFIG_ADDITIONAL_DIRS
    declare -g BACKUP_CONFIG_FOLLOW_SYMLINKS
    declare -g BACKUP_CONFIG_COMPRESSION_TEST
    declare -g BACKUP_CONFIG_COMPRESSION_TYPE
    declare -g BACKUP_CONFIG_COMPRESSION_LEVEL
    declare -g BACKUP_CONFIG_COMPRESSION_CORES
    declare -g BACKUP_CONFIG_COMPRESSION_EXTENSION

    declare -g IGNORED_PROJECTS_LIST #".wp-cli,.ssh,.local,.cert,html,phpmyadmin"
    declare -g EXCLUDED_DATABASES_LIST
    declare -g EXCLUDED_FILES_LIST #"*.log,*.tmp,.git"

    ## Backup config projects
    BACKUP_CONFIG_PROJECTS_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.config[].projects[].status")"
    [[ -z ${BACKUP_CONFIG_PROJECTS_STATUS} ]] && die "Error reading BACKUP_CONFIG_PROJECTS_STATUS from server config file."

    BACKUP_CONFIG_FOLLOW_SYMLINKS="$(json_read_field "${server_config_file}" "BACKUPS.config[].projects[].follow_symlinks")"
    IGNORED_PROJECTS_LIST="$(json_read_field "${server_config_file}" "BACKUPS.config[].projects[].ignored[]")"
    EXCLUDED_FILES_LIST="$(json_read_field "${server_config_file}" "BACKUPS.config[].projects[].excluded_on_tar[]")"

    ## Backup additional directories
    BACKUP_CONFIG_ADDITIONAL_DIRS="$(json_read_field "${server_config_file}" "BACKUPS.config[].additional_dirs[]")"

    ## Backup config databases
    BACKUP_CONFIG_DATABASES_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.config[].databases[].status")"
    [[ -z ${BACKUP_CONFIG_DATABASES_STATUS} ]] && die "Error reading BACKUP_CONFIG_DATABASES_STATUS from server config file."

    EXCLUDED_DATABASES_LIST="$(json_read_field "${server_config_file}" "BACKUPS.config[].databases[].exclude[]")"

    ## Backup config server_cfg
    BACKUP_CONFIG_SERVER_CFG_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.config[].server_cfg")"
    [[ -z ${BACKUP_CONFIG_SERVER_CFG_STATUS} ]] && die "Error reading BACKUP_CONFIG_SERVER_CFG_STATUS from server config file."

    ## Backup config compression_type
    BACKUP_CONFIG_COMPRESSION_TYPE="$(json_read_field "${server_config_file}" "BACKUPS.config[].compression[].type")"
    if [[ -z ${BACKUP_CONFIG_COMPRESSION_TYPE} ]]; then
        die "Error reading BACKUP_CONFIG_COMPRESSION_TYPE from server config file."

    else

        case ${BACKUP_CONFIG_COMPRESSION_TYPE} in

        lbzip2|pbzip2|pigz)
            BACKUP_CONFIG_COMPRESSION_EXTENSION="tar.bz2"
            ;;

        zstd)
            BACKUP_CONFIG_COMPRESSION_EXTENSION="zst"
            ;;

        *)
            log_event "debug" "Backup compression type not supported!" "true"
            exit 1
            ;;

        esac

    fi

    BACKUP_CONFIG_COMPRESSION_LEVEL="$(json_read_field "${server_config_file}" "BACKUPS.config[].compression[].level")"
    BACKUP_CONFIG_COMPRESSION_CORES="$(json_read_field "${server_config_file}" "BACKUPS.config[].compression[].cores")"
    BACKUP_CONFIG_COMPRESSION_TEST="$(json_read_field "${server_config_file}" "BACKUPS.config[].compression[].test")"

    export BACKUP_CONFIG_PROJECTS_STATUS BACKUP_CONFIG_DATABASES_STATUS BACKUP_CONFIG_SERVER_CFG_STATUS BACKUP_CONFIG_ADDITIONAL_DIRS
    export BACKUP_CONFIG_FOLLOW_SYMLINKS BACKUP_CONFIG_COMPRESSION_TYPE BACKUP_CONFIG_COMPRESSION_EXTENSION BACKUP_CONFIG_COMPRESSION_LEVEL BACKUP_CONFIG_COMPRESSION_CORES
    export BACKUP_CONFIG_COMPRESSION_TEST IGNORED_PROJECTS_LIST EXCLUDED_FILES_LIST EXCLUDED_DATABASES_LIST

}

################################################################################
# Private: load backup retentions configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_backup_retention() {

    local server_config_file="${1}"

    # Globals
    declare -g BACKUP_RETENTION_KEEP_DAILY
    declare -g BACKUP_RETENTION_KEEP_WEEKLY
    declare -g BACKUP_RETENTION_KEEP_MONTHLY

    declare -g DAYSAGO

    ## retention
    BACKUP_RETENTION_KEEP_DAILY="$(json_read_field "${server_config_file}" "BACKUPS.config[].retention[].keep_daily")"
    if [[ -z ${BACKUP_RETENTION_KEEP_DAILY} ]]; then
        log_event "error" "Missing required config vars for backup retention" "true"
        exit 1
    else
        if [[ ${BACKUP_RETENTION_KEEP_DAILY} -le 0 ]]; then
            log_event "error" "keep_daily config var should be greater than 0" "true"
            exit 1
        fi
    fi

    BACKUP_RETENTION_KEEP_WEEKLY="$(json_read_field "${server_config_file}" "BACKUPS.config[].retention[].keep_weekly")"
    [[ -z ${BACKUP_RETENTION_KEEP_WEEKLY} ]] && die "Error reading BACKUP_RETENTION_KEEP_WEEKLY from server config file."

    BACKUP_RETENTION_KEEP_MONTHLY="$(json_read_field "${server_config_file}" "BACKUPS.config[].retention[].keep_monthly")"
    [[ -z ${BACKUP_RETENTION_KEEP_MONTHLY} ]] && die "Error reading BACKUP_RETENTION_KEEP_MONTHLY from server config file."

    # Calculated vars
    DAYSAGO="$(date --date="${BACKUP_RETENTION_KEEP_DAILY} days ago" +"%Y-%m-%d")"
    WEEKSAGO="$(date --date="${BACKUP_RETENTION_KEEP_WEEKLY} weeks ago" +"%Y-%m-%d")"
    MONTHSAGO="$(date --date="${BACKUP_RETENTION_KEEP_MONTHLY} months ago" +"%Y-%m-%d")"
    ## Get current month and week day number
    MONTH_DAY=$(date +"%d")
    WEEK_DAY=$(date +"%u")

    export DAYSAGO WEEKSAGO MONTHSAGO MONTH_DAY WEEK_DAY
    export BACKUP_RETENTION_KEEP_DAILY BACKUP_RETENTION_KEEP_WEEKLY BACKUP_RETENTION_KEEP_MONTHLY

}

################################################################################
# Private: load email notifications configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_email() {

    local server_config_file="${1}"

    # Globals
    declare -g NOTIFICATION_EMAIL_STATUS
    declare -g NOTIFICATION_EMAIL_MAILA
    declare -g NOTIFICATION_EMAIL_SMTP_SERVER
    declare -g NOTIFICATION_EMAIL_SMTP_PORT
    declare -g NOTIFICATION_EMAIL_SMTP_TLS
    declare -g NOTIFICATION_EMAIL_SMTP_USER
    declare -g NOTIFICATION_EMAIL_SMTP_UPASS

    ### Email
    NOTIFICATION_EMAIL_STATUS="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].status")"

    if [[ ${NOTIFICATION_EMAIL_STATUS} == "enabled" ]]; then

        # Required
        NOTIFICATION_EMAIL_MAILA="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].maila")"
        [[ -z ${NOTIFICATION_EMAIL_MAILA} ]] && die "Error reading NOTIFICATION_EMAIL_MAILA from server config file."

        NOTIFICATION_EMAIL_SMTP_SERVER="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_server")"
        [[ -z ${NOTIFICATION_EMAIL_SMTP_SERVER} ]] && die "Error reading NOTIFICATION_EMAIL_SMTP_SERVER from server config file."

        NOTIFICATION_EMAIL_SMTP_PORT="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_port")"
        [[ -z ${NOTIFICATION_EMAIL_SMTP_PORT} ]] && die "Error reading NOTIFICATION_EMAIL_SMTP_PORT from server config file."

        NOTIFICATION_EMAIL_SMTP_TLS="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_tls")"
        [[ -z ${NOTIFICATION_EMAIL_SMTP_TLS} ]] && die "Error reading NOTIFICATION_EMAIL_SMTP_TLS from server config file."

        NOTIFICATION_EMAIL_SMTP_USER="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_user")"
        [[ -z ${NOTIFICATION_EMAIL_SMTP_USER} ]] && die "Error reading NOTIFICATION_EMAIL_SMTP_USER from server config file."

        NOTIFICATION_EMAIL_SMTP_UPASS="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_user_pass")"
        [[ -z ${NOTIFICATION_EMAIL_SMTP_UPASS} ]] && die "Error reading NOTIFICATION_EMAIL_SMTP_UPASS from server config file."

    else

        display --indent 6 --text "- Checking email notifications config" --result "WARNING" --color YELLOW
        display --indent 8 --text "Email notifications are disabled"

    fi

    export NOTIFICATION_EMAIL_STATUS NOTIFICATION_EMAIL_MAILA NOTIFICATION_EMAIL_SMTP_SERVER NOTIFICATION_EMAIL_SMTP_PORT NOTIFICATION_EMAIL_SMTP_TLS NOTIFICATION_EMAIL_SMTP_USER NOTIFICATION_EMAIL_SMTP_UPASS

}

################################################################################
# Private: load Telegram notifications configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_telegram() {

    local server_config_file="${1}"

    # Globals
    declare -g NOTIFICATION_TELEGRAM_STATUS
    declare -g NOTIFICATION_TELEGRAM_BOT_TOKEN
    declare -g NOTIFICATION_TELEGRAM_CHAT_ID

    NOTIFICATION_TELEGRAM_STATUS="$(json_read_field "${server_config_file}" "NOTIFICATIONS.telegram[].status")"

    if [[ ${NOTIFICATION_TELEGRAM_STATUS} == "enabled" ]]; then

        # Required
        NOTIFICATION_TELEGRAM_BOT_TOKEN="$(json_read_field "${server_config_file}" "NOTIFICATIONS.telegram[].config[].bot_token")"
        [[ -z ${NOTIFICATION_TELEGRAM_BOT_TOKEN} ]] && die "Error reading NOTIFICATION_TELEGRAM_BOT_TOKEN from server config file."

        NOTIFICATION_TELEGRAM_CHAT_ID="$(json_read_field "${server_config_file}" "NOTIFICATIONS.telegram[].config[].chat_id")"
        [[ -z ${NOTIFICATION_TELEGRAM_CHAT_ID} ]] && die "Error reading NOTIFICATION_TELEGRAM_CHAT_ID from server config file."

    fi

    export NOTIFICATION_TELEGRAM_STATUS NOTIFICATION_TELEGRAM_BOT_TOKEN NOTIFICATION_TELEGRAM_CHAT_ID

}

################################################################################
# Private: load Discord notifications configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_discord() {

    local server_config_file="${1}"

    # Globals
    declare -g NOTIFICATION_DISCORD_STATUS
    declare -g NOTIFICATION_DISCORD_WEBHOOK

    NOTIFICATION_DISCORD_STATUS="$(json_read_field "${server_config_file}" "NOTIFICATIONS.discord[].status")"

    if [[ ${NOTIFICATION_DISCORD_STATUS} == "enabled" ]]; then

        NOTIFICATION_DISCORD_WEBHOOK="$(json_read_field "${server_config_file}" "NOTIFICATIONS.discord[].config[].webhook")"

        # Check if all required vars are set
        [[ -z "${NOTIFICATION_DISCORD_WEBHOOK}" ]] && die "Error reading NOTIFICATION_DISCORD_WEBHOOK from server config file."

    fi

    export NOTIFICATION_DISCORD_STATUS NOTIFICATION_DISCORD_WEBHOOK

}

################################################################################
# Private: load ufw configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_firewall_ufw() {

    local server_config_file="${1}"

    # Globals
    declare -g SECURITY_UFW_STATUS
    declare -g SECURITY_UFW_APP_LIST_SSH

    SECURITY_UFW_STATUS="$(json_read_field "${server_config_file}" "ufw[].status")"

    if [[ ${SECURITY_UFW_STATUS} == "enabled" ]]; then

        # Mandatory
        SECURITY_UFW_APP_LIST_SSH="$(json_read_field "${server_config_file}" "ufw[].config[].ssh")"

        # Check if all required vars are set
        [[ -z "${SECURITY_UFW_APP_LIST_SSH}" ]] && die "Error reading SECURITY_UFW_APP_LIST_SSH from server config file."

    fi

    _brolit_configuration_firewall_ufw "${server_config_file}"

    export SECURITY_UFW_APP_LIST_SSH SECURITY_UFW_STATUS

}

################################################################################
# Private: load fail2ban configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_firewall_fail2ban() {

    local server_config_file="${1}"

    # Globals
    declare -g FIREWALL_FAIL2BAN_STATUS

    FIREWALL_FAIL2BAN_STATUS="$(json_read_field "${server_config_file}" "fail2ban[].status")"

    if [[ ${FIREWALL_FAIL2BAN_STATUS} == "enabled" ]]; then

        # Check if all required vars are set
        [[ -z "${FIREWALL_FAIL2BAN_STATUS}" ]] && die "Error reading FIREWALL_FAIL2BAN_STATUS from server config file."

    fi

    _brolit_configuration_firewall_fail2ban

    export FIREWALL_FAIL2BAN_STATUS

}

################################################################################
# Private: load cloudflare support configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_cloudflare() {

    local server_config_file="${1}"

    # Globals
    declare -g SUPPORT_CLOUDFLARE_STATUS
    declare -g SUPPORT_CLOUDFLARE_EMAIL
    declare -g SUPPORT_CLOUDFLARE_API_KEY

    SUPPORT_CLOUDFLARE_STATUS="$(json_read_field "${server_config_file}" "DNS.cloudflare[].status")"

    if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

        SUPPORT_CLOUDFLARE_EMAIL="$(json_read_field "${server_config_file}" "DNS.cloudflare[].config[].email")"
        SUPPORT_CLOUDFLARE_API_KEY="$(json_read_field "${server_config_file}" "DNS.cloudflare[].config[].api_key")"

        # Write .cloudflare.conf (needed for certbot support)
        echo "dns_cloudflare_email=${SUPPORT_CLOUDFLARE_EMAIL}" >~/.cloudflare.conf
        echo "dns_cloudflare_api_key=${SUPPORT_CLOUDFLARE_API_KEY}" >>~/.cloudflare.conf

        # Check if all required vars are set
        if [[ -z "${SUPPORT_CLOUDFLARE_EMAIL}" ]] || [[ -z "${SUPPORT_CLOUDFLARE_API_KEY}" ]]; then
            die "Missing required config vars for Cloudflare support"
        fi

    fi

    export SUPPORT_CLOUDFLARE_STATUS SUPPORT_CLOUDFLARE_EMAIL SUPPORT_CLOUDFLARE_API_KEY

}

################################################################################
# Private: load nginx configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_nginx() {

    local server_config_file="${1}"

    # Globals
    declare -g PACKAGES_NGINX_STATUS
    #declare -g PACKAGES_NGINX_CONFIG_PORTS

    declare -g WSERVER="/etc/nginx" # Webserver config files location

    # NGINX
    nginx_bin="$(package_is_installed "nginx")"
    exitstatus=$?

    PACKAGES_NGINX_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.nginx[].status")"

    if [[ ${PACKAGES_NGINX_STATUS} == "enabled" ]]; then

        #PACKAGES_NGINX_CONFIG_PORTS="$(json_read_field "${server_config_file}" "PACKAGES.nginx[].config[].port")"
        #[[ -z ${PACKAGES_NGINX_CONFIG_PORTS} ]] && die "Error reading PACKAGES_NGINX_CONFIG_PORTS from server config file."

        # Checking if nginx is not installed
        [[ ${exitstatus} -eq 1 || -z ${nginx_bin} ]] && pkg_config_changes_detected "nginx" "true"

    else

        # Checking if nginx is installed
        [[ ${exitstatus} -eq 0 && -n ${nginx_bin} ]] && pkg_config_changes_detected "nginx" "true"

    fi

    export NGINX WSERVER PACKAGES_NGINX_STATUS #PACKAGES_NGINX_CONFIG_PORTS

}

################################################################################
# Private: load php configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_php() {

    local server_config_file="${1}"

    # Globals
    declare -g PHP
    declare -g PHP_V
    declare -g PHP_CONF_DIR="/etc/php" # PHP config files location
    ## Core
    declare -g PACKAGES_PHP_STATUS
    declare -g PACKAGES_PHP_VERSION
    ## Config
    declare -g PACKAGES_PHP_CONFIG_OPCODE
    ## Extensions
    declare -g PACKAGES_PHP_EXTENSIONS_WPCLI
    declare -g PACKAGES_PHP_EXTENSIONS_REDIS
    declare -g PACKAGES_PHP_EXTENSIONS_MEMCACHED
    declare -g PACKAGES_PHP_EXTENSIONS_COMPOSER

    # PHP
    PHP="$(command -v php)"

    PACKAGES_PHP_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.php[].status")"

    if [[ ${PACKAGES_PHP_STATUS} == "enabled" ]]; then

        PACKAGES_PHP_VERSION="$(json_read_field "${server_config_file}" "PACKAGES.php[].version")"
        [[ -z ${PACKAGES_PHP_VERSION} ]] && die "Missing required config vars for php"

        source "${BROLIT_MAIN_DIR}/utils/installers/php_installer.sh"

        [[ ${PACKAGES_PHP_VERSION} == "default" ]] && PHP_V="$(php_get_distro_default_version)" || PHP_V="${PACKAGES_PHP_VERSION}"

        PACKAGES_PHP_CONFIG_OPCODE="$(json_read_field "${server_config_file}" "PACKAGES.php[].config[].opcode")"
        [[ -z ${PACKAGES_PHP_CONFIG_OPCODE} ]] && die "Error reading PACKAGES_PHP_CONFIG_OPCODE from server config file."

        PACKAGES_PHP_EXTENSIONS_WPCLI="$(json_read_field "${server_config_file}" "PACKAGES.php[].extensions[].wpcli")"
        [[ -z ${PACKAGES_PHP_EXTENSIONS_WPCLI} ]] && die "Error reading PACKAGES_PHP_EXTENSIONS_WPCLI from server config file."

        PACKAGES_PHP_EXTENSIONS_REDIS="$(json_read_field "${server_config_file}" "PACKAGES.php[].extensions[].redis")"
        [[ -z ${PACKAGES_PHP_EXTENSIONS_REDIS} ]] && die "Error reading PACKAGES_PHP_EXTENSIONS_REDIS from server config file."

        PACKAGES_PHP_EXTENSIONS_MEMCACHED="$(json_read_field "${server_config_file}" "PACKAGES.php[].extensions[].memcached")"
        [[ -z ${PACKAGES_PHP_EXTENSIONS_MEMCACHED} ]] && die "Error reading PACKAGES_PHP_EXTENSIONS_MEMCACHED from server config file."

        PACKAGES_PHP_EXTENSIONS_COMPOSER="$(json_read_field "${server_config_file}" "PACKAGES.php[].extensions[].composer")"
        [[ -z ${PACKAGES_PHP_EXTENSIONS_COMPOSER} ]] && die "Error reading PACKAGES_PHP_EXTENSIONS_COMPOSER from server config file."

        # Checking if php is not installed
        [[ ! -x ${PHP} ]] && pkg_config_changes_detected "php" "true"

    else

        # Checking if php is installed
        [[ -x ${PHP} ]] && pkg_config_changes_detected "php" "true"

    fi

    export PHP PHP_CONF_DIR PHP_V PACKAGES_PHP_STATUS PACKAGES_PHP_VERSION PACKAGES_PHP_CONFIG_OPCODE PACKAGES_PHP_EXTENSIONS_REDIS PACKAGES_PHP_EXTENSIONS_MEMCACHED PACKAGES_PHP_EXTENSIONS_COMPOSER PACKAGES_PHP_EXTENSIONS_WPCLI

}

################################################################################
# Private: load mariadb configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_mariadb() {

    local server_config_file="${1}"

    local is_mariadb

    # Globals
    declare -g PACKAGES_MARIADB_STATUS
    declare -g PACKAGES_MARIADB_CONFIG_VERSION
    declare -g PACKAGES_MARIADB_CONFIG_PORTS

    ## MySQL host and user
    declare -g MHOST="localhost"
    declare -g MUSER="root"

    ## MySQL credentials file
    declare -g MYSQL_CONF="/root/.my.cnf"
    declare -g MYSQL_CONF_DIR="/etc/mysql" # MySQL config files location

    declare -g MYSQL
    declare -g MYSQLDUMP
    declare -g MYSQL_ROOT
    declare -g MYSQLDUMP_ROOT

    # Check if mysql is present
    MYSQL="$(command -v mysql)"

    PACKAGES_MARIADB_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.mariadb[].status")"

    if [[ ${PACKAGES_MARIADB_STATUS} == "enabled" ]]; then

        PACKAGES_MARIADB_CONFIG_VERSION="$(json_read_field "${server_config_file}" "PACKAGES.mariadb[].version")"
        [[ -z ${PACKAGES_MARIADB_CONFIG_VERSION} ]] && die "Error reading PACKAGES_MARIADB_CONFIG_VERSION from server config file."

        PACKAGES_MARIADB_CONFIG_PORTS="$(json_read_field "${server_config_file}" "PACKAGES.mariadb[].config[].port")"
        [[ -z ${PACKAGES_MARIADB_CONFIG_PORTS} ]] && die "Error reading PACKAGES_MARIADB_CONFIG_PORTS from server config file."

        # Checking if MYSQL is not installed
        if [[ ! -x ${MYSQL} ]]; then
            pkg_config_changes_detected "mariadb" "true"

        else
            # Check which mysql version is installed
            is_mariadb="$(mysql -V | grep MariaDB)"

            # Mysql installed but is not MariaDB
            if [[ -z ${is_mariadb} ]]; then
                log_event "error" "Other version of mysql is already installed." "true"
            fi

        fi

        MYSQLDUMP="$(command -v mysqldump)"
        if [[ -f ${MYSQL_CONF} ]]; then
            # Append login parameters to command
            MYSQL_ROOT="${MYSQL} --defaults-file=${MYSQL_CONF}"
            MYSQLDUMP_ROOT="${MYSQLDUMP} --defaults-file=${MYSQL_CONF}"

        else

            mysql_ask_root_psw

        fi

    else

        if [[ -x ${MYSQL} ]]; then

            # Check which mysql version is installed
            is_mariadb="$(mysql -V | grep MariaDB)"

            # Checking if MYSQL is installed and is not MariaDB
            [[ -n ${is_mariadb} ]] && pkg_config_changes_detected "mariadb" "true"

        fi

    fi

    export MHOST MUSER MYSQL_CONF_DIR MYSQL MYSQL_CONF MYSQL_ROOT MYSQLDUMP_ROOT MYSQLDUMP
    export PACKAGES_MARIADB_STATUS PACKAGES_MARIADB_CONFIG_VERSION PACKAGES_MARIADB_CONFIG_PORTS

}

################################################################################
# Private: load mysql configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_mysql() {

    local server_config_file="${1}"

    # Globals
    declare -g PACKAGES_MYSQL_STATUS
    declare -g PACKAGES_MYSQL_CONFIG_VERSION
    declare -g PACKAGES_MYSQL_CONFIG_PORTS

    ## MySQL host and user
    declare -g MHOST="localhost"
    declare -g MUSER="root"

    ## MySQL credentials file
    declare -g MYSQL_CONF="/root/.my.cnf"
    declare -g MYSQL_CONF_DIR="/etc/mysql" # MySQL config files location

    declare -g MYSQL
    declare -g MYSQLDUMP
    declare -g MYSQL_ROOT
    declare -g MYSQLDUMP_ROOT

    # Check if mysql is present
    MYSQL="$(command -v mysql)"

    PACKAGES_MYSQL_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.mysql[].status")"

    if [[ ${PACKAGES_MYSQL_STATUS} == "enabled" ]]; then

        PACKAGES_MYSQL_CONFIG_VERSION="$(json_read_field "${server_config_file}" "PACKAGES.mysql[].version")"
        [[ -z ${PACKAGES_MYSQL_CONFIG_VERSION} ]] && die "Error reading PACKAGES_MYSQL_CONFIG_VERSION from server config file."

        PACKAGES_MYSQL_CONFIG_PORTS="$(json_read_field "${server_config_file}" "PACKAGES.mysql[].config[].port")"
        [[ -z ${PACKAGES_MYSQL_CONFIG_PORTS} ]] && die "Error reading PACKAGES_MYSQL_CONFIG_PORTS from server config file."

        # Checking if MYSQL is not installed
        if [[ ! -x ${MYSQL} ]]; then
            pkg_config_changes_detected "mysql" "true"
        else

            # Check which mysql version is installed
            is_mariadb="$(mysql -V | grep MariaDB)"

            # Mysql installed but is MariaDB
            if [[ -n ${is_mariadb} ]]; then
                log_event "error" "Other version of mysql is already installed (MariaDB)." "true"
            fi
        fi

        MYSQLDUMP="$(command -v mysqldump)"

        if [[ -f ${MYSQL_CONF} ]]; then
            # Append login parameters to command
            MYSQL_ROOT="${MYSQL} --defaults-file=${MYSQL_CONF}"
            MYSQLDUMP_ROOT="${MYSQLDUMP} --defaults-file=${MYSQL_CONF}"

        else

            mysql_ask_root_psw

        fi

    else # ${PACKAGES_MYSQL_STATUS} == "disabled"

        if [[ -x ${MYSQL} ]]; then
            # Check which mysql version is installed
            is_mariadb="$(mysql -V | grep MariaDB)"

            # Checking if MYSQL is installed and is not MariaDB
            [[ -z ${is_mariadb} ]] && pkg_config_changes_detected "mysql" "true"

        fi

    fi

    export MHOST MUSER MYSQL_CONF_DIR MYSQL MYSQL_CONF MYSQL_ROOT MYSQLDUMP_ROOT MYSQLDUMP
    export PACKAGES_MYSQL_STATUS PACKAGES_MYSQL_CONFIG_VERSION PACKAGES_MYSQL_CONFIG_PORTS

}

################################################################################
# Private: load postgres configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_postgres() {

    local server_config_file="${1}"

    # Globals
    declare -g PACKAGES_POSTGRES_STATUS
    declare -g PACKAGES_POSTGRES_CONFIG_VERSION
    declare -g PACKAGES_POSTGRES_CONFIG_PORTS

    # Postgres
    declare -g POSTGRES
    declare -g PSQL_ROOT
    declare -g PSQLDUMP_ROOT

    PACKAGES_POSTGRES_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.postgres[].status")"

    #POSTGRES="$(which psql)"
    POSTGRES="$(command -v psql)"

    if [[ ${PACKAGES_POSTGRES_STATUS} == "enabled" ]]; then

        PACKAGES_POSTGRES_CONFIG_VERSION="$(json_read_field "${server_config_file}" "PACKAGES.postgres[].version")"
        [[ -z ${PACKAGES_POSTGRES_CONFIG_VERSION} ]] && die "Error reading PACKAGES_POSTGRES_CONFIG_VERSION from server config file."

        PACKAGES_POSTGRES_CONFIG_PORTS="$(json_read_field "${server_config_file}" "PACKAGES.postgres[].config[].port")"
        [[ -z ${PACKAGES_POSTGRES_CONFIG_PORTS} ]] && die "Error reading PACKAGES_POSTGRES_CONFIG_PORTS from server config file."

        # Checking if Postgres is not installed
        [[ ! -x ${POSTGRES} ]] && pkg_config_changes_detected "postgres" "true"

        PSQLDUMP="$(command -v pg_dump)"

        # Append login parameters to command
        PSQL_ROOT="sudo -u postgres -i psql --quiet"
        PSQLDUMP_ROOT="sudo -u postgres -i pg_dump"

    else

        # Checking if Postgres is installed
        [[ -x ${POSTGRES} ]] && pkg_config_changes_detected "postgres" "true"

    fi

    export POSTGRES PSQLDUMP PSQL_ROOT PSQLDUMP_ROOT
    export PACKAGES_POSTGRES_STATUS PACKAGES_POSTGRES_CONFIG_VERSION PACKAGES_POSTGRES_CONFIG_PORTS

}

################################################################################
# Private: load redis configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_redis() {

    local server_config_file="${1}"

    # Globals
    declare -g PACKAGES_REDIS_STATUS
    declare -g PACKAGES_REDIS_CONFIG_VERSION

    REDIS="$(command -v redis-cli)"

    PACKAGES_REDIS_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.redis[].status")"
    if [[ ${PACKAGES_REDIS_STATUS} == "enabled" ]]; then

        PACKAGES_REDIS_CONFIG_VERSION="$(json_read_field "${server_config_file}" "PACKAGES.redis[].version")"
        [[ -z ${PACKAGES_REDIS_CONFIG_VERSION} ]] && die "Error reading PACKAGES_REDIS_CONFIG_VERSION from server config file."

        # Checking if Redis is not installed
        [[ ! -x ${REDIS} ]] && pkg_config_changes_detected "redis" "true"

    else

        # Checking if Redis is  installed
        [[ -x ${REDIS} ]] && pkg_config_changes_detected "redis" "true"

    fi

    export REDIS PACKAGES_REDIS_STATUS PACKAGES_REDIS_CONFIG_VERSION

}

################################################################################
# Private: load certbot configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_certbot() {

    local server_config_file="${1}"

    # Globals
    declare -g PACKAGES_CERTBOT_STATUS
    declare -g PACKAGES_CERTBOT_CONFIG_MAILA

    declare -g LENCRYPT_CONF_DIR="/etc/letsencrypt" # Let's Encrypt config files location

    PACKAGES_CERTBOT_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.certbot[].status")"

    CERTBOT="$(which certbot)"
    if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then

        PACKAGES_CERTBOT_CONFIG_MAILA="$(json_read_field "${server_config_file}" "PACKAGES.certbot[].config[].email")"
        [[ -z "${PACKAGES_CERTBOT_CONFIG_MAILA}" ]] && die "Error reading PACKAGES_CERTBOT_CONFIG_MAILA from server config file."

        # Checking if Certbot is not installed
        [[ ! -x "${CERTBOT}" ]] && pkg_config_changes_detected "certbot" "true"

    else

        # Checking if Certbot is  installed
        [[ -x "${CERTBOT}" ]] && pkg_config_changes_detected "certbot" "true"

        display --indent 6 --text "- Certbot disabled" --result "WARNING" --color YELLOW

    fi

    export CERTBOT LENCRYPT_CONF_DIR PACKAGES_CERTBOT_STATUS PACKAGES_CERTBOT_CONFIG_MAILA

}

################################################################################
# Private: load monit configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_monit() {

    local server_config_file="${1}"

    # Globals
    declare -g PACKAGES_MONIT_STATUS
    declare -g PACKAGES_MONIT_CONFIG_MAILA

    PACKAGES_MONIT_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.monit[].status")"

    MONIT="$(which monit)"

    if [[ ${PACKAGES_MONIT_STATUS} == "enabled" ]]; then

        PACKAGES_MONIT_CONFIG_MAILA="$(json_read_field "${server_config_file}" "PACKAGES.monit[].config[].monit_maila")"
        [[ -z ${PACKAGES_MONIT_CONFIG_MAILA} ]] && die "Error reading PACKAGES_MONIT_CONFIG_MAILA from server config file."

        PACKAGES_MONIT_CONFIG_HTTPD_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.monit[].config[].monit_httpd[].status")"
        [[ -z ${PACKAGES_MONIT_CONFIG_HTTPD_STATUS} ]] && die "Error reading PACKAGES_MONIT_CONFIG_HTTPD_STATUS from server config file."

        PACKAGES_MONIT_CONFIG_HTTPD_USER="$(json_read_field "${server_config_file}" "PACKAGES.monit[].config[].monit_httpd[].user")"
        [[ -z ${PACKAGES_MONIT_CONFIG_HTTPD_USER} ]] && die "Error reading PACKAGES_MONIT_CONFIG_HTTPD_USER from server config file."

        PACKAGES_MONIT_CONFIG_HTTPD_PASS="$(json_read_field "${server_config_file}" "PACKAGES.monit[].config[].monit_httpd[].pass")"
        [[ -z ${PACKAGES_MONIT_CONFIG_HTTPD_PASS} ]] && die "Error reading PACKAGES_MONIT_CONFIG_HTTPD_PASS from server config file."

        MONIT_CONFIG_SERVICES="$(json_read_field "${server_config_file}" "PACKAGES.monit[].config[].monit_services[]")"
        [[ -z ${MONIT_CONFIG_SERVICES} ]] && die "Error reading MONIT_CONFIG_SERVICES from server config file."

        # Checking if Monit is not installed
        [[ ! -x ${MONIT} ]] && pkg_config_changes_detected "monit" "true"

    else

        # Checking if Monit is installed
        [[ -x ${MONIT} ]] && pkg_config_changes_detected "monit" "true"

    fi

    export MONIT PACKAGES_MONIT_STATUS PACKAGES_MONIT_CONFIG_MAILA PACKAGES_MONIT_CONFIG_HTTPD_STATUS PACKAGES_MONIT_CONFIG_HTTPD_USER PACKAGES_MONIT_CONFIG_HTTPD_PASS

}

################################################################################
# Private: load netdata configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_netdata() {

    local server_config_file="${1}"

    # Globals
    declare -g NETDATA
    declare -g NETDATA_PR
    declare -g NETDATA_DOCKER
    declare -g PACKAGES_NETDATA_STATUS
    declare -g PACKAGES_NETDATA_CONFIG_WEB_ADMIN
    declare -g PACKAGES_NETDATA_CONFIG_SUBDOMAIN
    declare -g PACKAGES_NETDATA_CONFIG_USER
    declare -g PACKAGES_NETDATA_CONFIG_USER_PASS
    declare -g PACKAGES_NETDATA_NOTIFICATION_ALARM_LEVEL
    declare -g PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_STATUS
    declare -g PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_BOT_TOKEN
    declare -g PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_CHAT_ID

    NETDATA="$(which netdata)"
    NETDATA_PR="$(pgrep netdata)" # This will detect if a netdata process is running, but could be a docker container
    # If docker is installed
    if [[ -x "$(command -v docker)" ]]; then
        NETDATA_DOCKER="$(docker ps -q --filter name=netdata)" # This will detect if a netdata docker container is running
    fi

    PACKAGES_NETDATA_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].status")"
    PACKAGES_NETDATA_CONFIG_WEB_ADMIN="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].config[].web_admin")"

    if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then

        if [[ ${PACKAGES_NETDATA_CONFIG_WEB_ADMIN} == "enabled" ]]; then

            # Required
            PACKAGES_NETDATA_CONFIG_SUBDOMAIN="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].config[].subdomain")"
            [[ -z "${PACKAGES_NETDATA_CONFIG_SUBDOMAIN}" ]] && die "Error reading PACKAGES_NETDATA_CONFIG_SUBDOMAIN from server config file."

            PACKAGES_NETDATA_CONFIG_USER="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].config[].user")"
            [[ -z "${PACKAGES_NETDATA_CONFIG_USER}" ]] && die "Error reading PACKAGES_NETDATA_CONFIG_USER from server config file."

            PACKAGES_NETDATA_CONFIG_USER_PASS="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].config[].user_pass")"
            [[ -z "${PACKAGES_NETDATA_CONFIG_USER_PASS}" ]] && die "Error reading PACKAGES_NETDATA_CONFIG_USER_PASS from server config file."

        fi

        PACKAGES_NETDATA_NOTIFICATION_ALARM_LEVEL="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].notifications[].alarm_level")"
        [[ -z "${PACKAGES_NETDATA_NOTIFICATION_ALARM_LEVEL}" ]] && die "Error reading PACKAGES_NETDATA_NOTIFICATION_ALARM_LEVEL from server config file."

        PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].notifications[].telegram[].status")"
        if [[ ${PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_STATUS} == "enabled" ]]; then

            # Required
            PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_BOT_TOKEN="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].notifications[].telegram[].config[].bot_token")"
            [[ -z "${PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_BOT_TOKEN}" ]] && die "Error reading PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_BOT_TOKEN from server config file."

            PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_CHAT_ID="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].notifications[].telegram[].config[].chat_id")"
            [[ -z "${PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_CHAT_ID}" ]] && die "Error reading PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_CHAT_ID from server config file."

        fi

        # Checking if Netdata is not installed
        [[ ! -x "${NETDATA}" && -z "${NETDATA_PR}" && -z ${NETDATA_DOCKER} ]] && pkg_config_changes_detected "netdata" "true"

    else

        # Checking if Netdata is installed
        [[ -x "${NETDATA}" || -n "${NETDATA_PR}" || -n ${NETDATA_DOCKER} ]] && pkg_config_changes_detected "netdata" "true"

    fi

    export PACKAGES_NETDATA_STATUS PACKAGES_NETDATA_CONFIG_WEB_ADMIN PACKAGES_NETDATA_CONFIG_SUBDOMAIN PACKAGES_NETDATA_CONFIG_USER PACKAGES_NETDATA_CONFIG_USER_PASS PACKAGES_NETDATA_NOTIFICATION_ALARM_LEVEL
    export PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_STATUS PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_BOT_TOKEN PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_CHAT_ID

}

################################################################################
# Private: load netdata agent configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_netdata_agent() {

    local server_config_file="${1}"

    local docker
    local docker_installed

    # Globals
    declare -g NETDATA_AGENT
    declare -g PACKAGES_NETDATA_AGENT_STATUS
    declare -g PACKAGES_NETDATA_AGENT_CONFIG_PORT

    declare -g NETDATA_AGENT_PATH="/root/agent_netdata"

    PACKAGES_NETDATA_AGENT_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.netdata_agent[].status")"

    if [[ ${PACKAGES_NETDATA_AGENT_STATUS} == "enabled" ]]; then

        # Check if docker or docker.io package are installed
        docker="$(package_is_installed "docker" || package_is_installed "docker.io")"
        docker_installed="$?"
        if [[ ${docker_installed} -eq 0 ]]; then
            log_event "debug" "Docker installed on: ${docker}. Now checking if Netdata Agent image is present..." "false"
            NETDATA_AGENT="$(docker_get_container_id "agent_netdata")"
        else
            # Netdata agent requires docker
            die "In order to install Netdata Agent, docker and docker-compose must be installed."
        fi

        [[ ${docker_installed} -eq 1 ]] && die "In order to install Netdata Agent, docker and docker-compose must be installed."

        # Required
        PACKAGES_NETDATA_AGENT_VERSION="$(json_read_field "${server_config_file}" "PACKAGES.netdata_agent[].version")"
        [[ -z ${PACKAGES_NETDATA_AGENT_VERSION} ]] && die "Error reading PACKAGES_NETDATA_AGENT_VERSION from config file"

        PACKAGES_NETDATA_AGENT_CONFIG_PORT="$(json_read_field "${server_config_file}" "PACKAGES.netdata_agent[].config[].port")"
        [[ -z ${PACKAGES_NETDATA_AGENT_CONFIG_PORT} ]] && die "Error reading PACKAGES_NETDATA_AGENT_CONFIG_PORT from config file"

        PACKAGES_NETDATA_AGENT_CONFIG_DOMAIN="$(json_read_field "${server_config_file}" "PACKAGES.netdata_agent[].config[].domain")"
        [[ -z ${PACKAGES_NETDATA_AGENT_CONFIG_DOMAIN} ]] && die "Error reading PACKAGES_NETDATA_AGENT_CONFIG_DOMAIN from config file"

        PACKAGES_NETDATA_AGENT_CONFIG_CLAIM_TOKEN="$(json_read_field "${server_config_file}" "PACKAGES.netdata_agent[].config[].claim_token")"
        [[ -z ${PACKAGES_NETDATA_AGENT_CONFIG_CLAIM_TOKEN} ]] && die "Error reading PACKAGES_NETDATA_AGENT_CONFIG_CLAIM_TOKEN from config file"

        # Optional
        PACKAGES_NETDATA_AGENT_CONFIG_CLAIM_ROOMS="$(json_read_field "${server_config_file}" "PACKAGES.netdata_agent[].config[].claim_rooms")"

        # Checking if Netdata Agent is not installed
        [[ -z ${NETDATA_AGENT} ]] && pkg_config_changes_detected "netdata_agent" "true"

    else

        # Checking if Netdata Agent is installed
        [[ -n ${NETDATA_AGENT} ]] && pkg_config_changes_detected "netdata_agent" "true"

    fi

    export NETDATA_AGENT NETDATA_AGENT_PATH PACKAGES_NETDATA_AGENT_STATUS PACKAGES_NETDATA_AGENT_CONFIG_PORT PACKAGES_NETDATA_AGENT_CONFIG_CLAIM_ROOMS

}

################################################################################
# Private: load Grafana configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_grafana() {

    local server_config_file="${1}"

    # Globals
    declare -g GRAFANA
    declare -g GRAFANA_PR
    declare -g GRAFANA_DOCKER
    declare -g PACKAGES_GRAFANA_STATUS
    declare -g PACKAGES_GRAFANA_CONFIG_SUBDOMAIN
    declare -g PACKAGES_GRAFANA_CONFIG_NGINX_PROXY
    declare -g PACKAGES_GRAFANA_CONFIG_PORT

    GRAFANA="$(which grafana-server)"
    GRAFANA_PR="$(pgrep grafana)" # This will detect if a grafana process is running, but could be a docker container
    # If docker is installed
    if [[ -x "$(command -v docker)" ]]; then
        GRAFANA_DOCKER="$(docker ps -q --filter name=grafana)" # This will detect if a grafana docker container is running
    fi

    PACKAGES_GRAFANA_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.grafana[].status")"

    if [[ ${PACKAGES_GRAFANA_STATUS} == "enabled" ]]; then

        # Check if docker or docker.io package are installed
        docker="$(package_is_installed "docker" || package_is_installed "docker.io")"
        docker_installed="$?"
        if [[ ${docker_installed} -eq 0 ]]; then
            log_event "debug" "Docker installed on: ${docker}. Now checking if Grafana image is present..." "false"
            NETDATA_AGENT="$(docker_get_container_id "grafana")"
        else
            # Grafana requires docker
            die "In order to install Grafana, docker and docker-compose must be installed."
        fi

        PACKAGES_GRAFANA_CONFIG_SUBDOMAIN="$(json_read_field "${server_config_file}" "PACKAGES.grafana[].config[].subdomain")"
        PACKAGES_GRAFANA_CONFIG_NGINX_PROXY="$(json_read_field "${server_config_file}" "PACKAGES.grafana[].config[].nginx_proxy")"
        PACKAGES_GRAFANA_CONFIG_PORT="$(json_read_field "${server_config_file}" "PACKAGES.grafana[].config[].port")"

        # Check if all required vars are set
        if [[ -z "${PACKAGES_GRAFANA_CONFIG_SUBDOMAIN}" ]] || [[ -z "${PACKAGES_GRAFANA_CONFIG_NGINX_PROXY}" ]] || [[ -z "${PACKAGES_GRAFANA_CONFIG_PORT}" ]]; then
            die "Missing required config vars for grafana support"
        fi

        # Checking if Grafana is not installed
        [[ ! -x "${GRAFANA}" && -z "${GRAFANA_PR}" && -z ${GRAFANA_DOCKER} ]] && pkg_config_changes_detected "grafana" "true"

    else

        # Checking if Grafana is installed
        [[ -x "${GRAFANA}" && -n "${GRAFANA_PR}" && -n ${GRAFANA_DOCKER} ]] && pkg_config_changes_detected "grafana" "true"

    fi

}

################################################################################
# Private: load Loki configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_loki() {

    local server_config_file="${1}"

    # Globals
    declare -g LOKI
    declare -g LOKI_PR
    declare -g LOKI_DOCKER
    declare -g PACKAGES_LOKI_STATUS
    declare -g PACKAGES_LOKI_CONFIG_SUBDOMAIN
    declare -g PACKAGES_LOKI_CONFIG_NGINX_PROXY
    declare -g PACKAGES_LOKI_CONFIG_PORT

    LOKI="$(which loki)"
    LOKI_PR="$(pgrep loki)" # This will detect if a loki process is running, but could be a docker container
    # If docker is installed
    if [[ -x "$(command -v docker)" ]]; then
        LOKI_DOCKER="$(docker ps -q --filter name=loki)" # This will detect if a loki docker container is running
    fi

    PACKAGES_LOKI_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.loki[].status")"

    if [[ ${PACKAGES_LOKI_STATUS} == "enabled" ]]; then

        # Check if docker or docker.io package are installed
        docker="$(package_is_installed "docker" || package_is_installed "docker.io")"
        docker_installed="$?"
        if [[ ${docker_installed} -eq 0 ]]; then
            log_event "debug" "Docker installed on: ${docker}. Now checking if Loki image is present..." "false"
            NETDATA_AGENT="$(docker_get_container_id "loki")"
        else
            # Loki requires docker
            die "In order to install Loki, docker and docker-compose must be installed."
        fi

        PACKAGES_LOKI_CONFIG_SUBDOMAIN="$(json_read_field "${server_config_file}" "PACKAGES.loki[].config[].subdomain")"
        PACKAGES_LOKI_CONFIG_NGINX_PROXY="$(json_read_field "${server_config_file}" "PACKAGES.loki[].config[].nginx_proxy")"
        PACKAGES_LOKI_CONFIG_PORT="$(json_read_field "${server_config_file}" "PACKAGES.loki[].config[].port")"

        # Check if all required vars are set
        if [[ -z "${PACKAGES_LOKI_CONFIG_SUBDOMAIN}" ]] || [[ -z "${PACKAGES_LOKI_CONFIG_NGINX_PROXY}" ]] || [[ -z "${PACKAGES_LOKI_CONFIG_PORT}" ]]; then
            die "Missing required config vars for loki support"
        fi

        # Checking if Loki is not installed
        [[ ! -x "${LOKI}" && -z "${LOKI_PR}" && -z ${LOKI_DOCKER} ]] && pkg_config_changes_detected "loki" "true"

    else

        # Checking if Loki is installed
        [[ -x "${LOKI}" && -n "${LOKI_PR}" && -n ${LOKI_DOCKER} ]] && pkg_config_changes_detected "loki" "true"

    fi

    export LOKI LOKI_PR LOKI_DOCKER PACKAGES_LOKI_STATUS PACKAGES_LOKI_CONFIG_SUBDOMAIN PACKAGES_LOKI_CONFIG_NGINX_PROXY PACKAGES_LOKI_CONFIG_PORT

}

################################################################################
# Private: load Promtail configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_promtail() {

    local server_config_file="${1}"

    # Globals
    declare -g PROMTAIL
    declare -g PACKAGES_PROMTAIL_STATUS
    declare -g PACKAGES_PROMTAIL_VERSION
    declare -g PACKAGES_PROMTAIL_CONFIG_PORT
    declare -g PACKAGES_PROMTAIL_CONFIG_HOSTNAME
    declare -g PACKAGES_PROMTAIL_CONFIG_LOKI_URL
    declare -g PACKAGES_PROMTAIL_CONFIG_LOKI_PORT

    #PROMTAIL="$(pgrep promtail)"
    PROMTAIL="/opt/promtail/promtail-linux-amd64"
    PROMTAIL_CONFIG_FILE="/opt/promtail/config-promtail.yml"

    PACKAGES_PROMTAIL_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.promtail[].status")"

    if [[ ${PACKAGES_PROMTAIL_STATUS} == "enabled" ]]; then

        PACKAGES_PROMTAIL_VERSION="$(json_read_field "${server_config_file}" "PACKAGES.promtail[].version")"
        [[ -z "${PACKAGES_PROMTAIL_VERSION}" ]] && die "Error reading PACKAGES_PROMTAIL_VERSION from server config file."

        PACKAGES_PROMTAIL_CONFIG_PORT="$(json_read_field "${server_config_file}" "PACKAGES.promtail[].config[].port")"
        [[ -z "${PACKAGES_PROMTAIL_CONFIG_PORT}" ]] && die "Error reading PACKAGES_PROMTAIL_CONFIG_PORT from server config file."

        PACKAGES_PROMTAIL_CONFIG_HOSTNAME="$(json_read_field "${server_config_file}" "PACKAGES.promtail[].config[].hostname")"
        [[ -z "${PACKAGES_PROMTAIL_CONFIG_HOSTNAME}" ]] && die "Error reading PACKAGES_PROMTAIL_CONFIG_HOSTNAME from server config file."

        PACKAGES_PROMTAIL_CONFIG_LOKI_URL="$(json_read_field "${server_config_file}" "PACKAGES.promtail[].config[].loki_url")"
        [[ -z "${PACKAGES_PROMTAIL_CONFIG_LOKI_URL}" ]] && die "Error reading PACKAGES_PROMTAIL_CONFIG_LOKI_URL from server config file."

        PACKAGES_PROMTAIL_CONFIG_LOKI_PORT="$(json_read_field "${server_config_file}" "PACKAGES.promtail[].config[].loki_port")"
        [[ -z "${PACKAGES_PROMTAIL_CONFIG_LOKI_PORT}" ]] && die "Error reading PACKAGES_PROMTAIL_CONFIG_LOKI_PORT from server config file."

        # Check if all required vars are set
        if [[ -z "${PACKAGES_PROMTAIL_CONFIG_PORT}" ]] || [[ -z "${PACKAGES_PROMTAIL_CONFIG_HOSTNAME}" ]] || [[ -z "${PACKAGES_PROMTAIL_CONFIG_LOKI_URL}" ]] || [[ -z "${PACKAGES_PROMTAIL_CONFIG_LOKI_PORT}" ]]; then
            die "Missing required config vars for promtail support"
        fi

        # Checking if Promtail is not installed
        #[[ -z "${PROMTAIL}" && ! -f ${PROMTAIL_CONFIG_FILE} ]] && pkg_config_changes_detected "promtail" "true"
        [[ ! -f "${PROMTAIL}" || ! -f ${PROMTAIL_CONFIG_FILE} ]] && pkg_config_changes_detected "promtail" "true"

    else

        # Checking if Promtail is installed
        [[ -f "${PROMTAIL}" && -f ${PROMTAIL_CONFIG_FILE} ]] && pkg_config_changes_detected "promtail" "true"

    fi

    export PROMTAIL PROMTAIL_CONFIG_FILE PACKAGES_PROMTAIL_STATUS PACKAGES_PROMTAIL_VERSION PACKAGES_PROMTAIL_CONFIG_PORT PACKAGES_PROMTAIL_CONFIG_HOSTNAME PACKAGES_PROMTAIL_CONFIG_LOKI_URL PACKAGES_PROMTAIL_CONFIG_LOKI_PORT

}

################################################################################
# Private: load cockpit configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_cockpit() {

    local server_config_file="${1}"

    # Globals
    declare -g COCKPIT
    declare -g COCKPIT_PR
    declare -g PACKAGES_COCKPIT_STATUS
    declare -g PACKAGES_COCKPIT_CONFIG_SUBDOMAIN
    declare -g PACKAGES_COCKPIT_CONFIG_NGINX_PROXY
    declare -g PACKAGES_COCKPIT_CONFIG_PORT

    COCKPIT="$(which cockpit)"
    COCKPIT_PR="$(pgrep cockpit)"

    PACKAGES_COCKPIT_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.cockpit[].status")"

    if [[ ${PACKAGES_COCKPIT_STATUS} == "enabled" ]]; then

        PACKAGES_COCKPIT_CONFIG_SUBDOMAIN="$(json_read_field "${server_config_file}" "PACKAGES.cockpit[].config[].subdomain")"
        PACKAGES_COCKPIT_CONFIG_NGINX_PROXY="$(json_read_field "${server_config_file}" "PACKAGES.cockpit[].config[].nginx_proxy")"
        PACKAGES_COCKPIT_CONFIG_PORT="$(json_read_field "${server_config_file}" "PACKAGES.cockpit[].config[].port")"

        # Check if all required vars are set
        if [[ -z "${PACKAGES_COCKPIT_CONFIG_SUBDOMAIN}" ]] || [[ -z "${PACKAGES_COCKPIT_CONFIG_NGINX_PROXY}" ]] || [[ -z "${PACKAGES_COCKPIT_CONFIG_PORT}" ]]; then
            die "Missing required config vars for netdata support"
        fi

        # Checking if Cockpit is not installed
        [[ ! -x "${COCKPIT}" && -z "${COCKPIT_PR}" ]] && pkg_config_changes_detected "cockpit" "true"

    else

        # Checking if Cockpit is installed
        [[ -x "${COCKPIT}" || -n "${COCKPIT_PR}" ]] && pkg_config_changes_detected "cockpit" "true"

    fi

    export COCKPIT PACKAGES_COCKPIT_STATUS PACKAGES_COCKPIT_CONFIG_SUBDOMAIN PACKAGES_COCKPIT_CONFIG_NGINX_PROXY PACKAGES_COCKPIT_CONFIG_PORT

}

################################################################################
# Private: load zabbix configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_zabbix() {

    local server_config_file="${1}"

    # Globals
    declare -g ZABBIX
    #declare -g ZABBIX_PR
    declare -g PACKAGES_ZABBIX_STATUS
    declare -g PACKAGES_ZABBIX_CONFIG_SUBDOMAIN

    ZABBIX="$(which zabbix)"
    #ZABBIX_PR="$(pgrep zabbix)"

    PACKAGES_ZABBIX_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.zabbix[].status")"

    if [[ ${PACKAGES_ZABBIX_STATUS} == "enabled" ]]; then

        PACKAGES_ZABBIX_CONFIG_SUBDOMAIN="$(json_read_field "${server_config_file}" "PACKAGES.zabbix[].config[].subdomain")"

        # Check if all required vars are set
        if [[ -z "${PACKAGES_ZABBIX_CONFIG_SUBDOMAIN}" ]]; then
            log_event "error" "Missing required config vars for netdata support" "true"
            exit 1
        fi

        # Checking if Cockpit is not installed
        [[ ! -x "${ZABBIX}" ]] && pkg_config_changes_detected "zabbix" "true"

    else

        # Checking if Cockpit is installed
        [[ -x "${ZABBIX}" ]] && pkg_config_changes_detected "zabbix" "true"

    fi

    export ZABBIX PACKAGES_ZABBIX_STATUS PACKAGES_ZABBIX_CONFIG_SUBDOMAIN

}

################################################################################
# Private: load docker configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_docker() {

    local server_config_file="${1}"

    local exitstatus
    local docker_installed
    local docker_compose_installed

    # Globals
    declare -g DOCKER
    declare -g PACKAGES_DOCKER_STATUS
    declare -g DOCKER_COMPOSE

    PACKAGES_DOCKER_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.docker[].status")"

    # Docker
    # Check if docker or docker.io package are installed
    DOCKER="$(package_is_installed "docker" || package_is_installed "docker.io")"
    docker_installed="$?"
    # Docker Compose
    DOCKER_COMPOSE="$(package_is_installed "docker-compose")"
    docker_compose_installed="$?"

    if [[ ${PACKAGES_DOCKER_STATUS} == "enabled" ]]; then

        # Checking if pkg is not installed
        [[ ${docker_installed} -eq 1 || ${docker_compose_installed} -eq 1 ]] && pkg_config_changes_detected "docker" "true"

    else

        # Checking if pkg is installed
        [[ ${docker_installed} -eq 0 || ${docker_compose_installed} -eq 0 ]] && pkg_config_changes_detected "docker" "true"

    fi

    export DOCKER PACKAGES_DOCKER_STATUS DOCKER_COMPOSE

}

################################################################################
# Private: load portainer configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_portainer() {

    local server_config_file="${1}"

    local docker
    local docker_installed

    # Globals
    declare -g PORTAINER
    declare -g PACKAGES_PORTAINER_STATUS
    declare -g PACKAGES_PORTAINER_CONFIG_SUBDOMAIN
    declare -g PACKAGES_PORTAINER_CONFIG_PORT
    declare -g PACKAGES_PORTAINER_CONFIG_NGINX

    PACKAGES_PORTAINER_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.portainer[].status")"

    # Check if docker or docker.io package are installed
    docker="$(package_is_installed "docker" || package_is_installed "docker.io")"
    docker_installed="$?"
    if [[ ${docker_installed} -eq 0 ]]; then
        log_event "debug" "Docker installed on: ${docker}. Now checking if Portainer image is present..." "false"
        PORTAINER="$(docker_get_container_id "portainer-ce")"
    fi

    if [[ ${PACKAGES_PORTAINER_STATUS} == "enabled" ]]; then

        [[ ${docker_installed} -eq 1 ]] && die "In order to install Portainer, docker and docker-compose must be installed."

        PACKAGES_PORTAINER_CONFIG_PORT="$(json_read_field "${server_config_file}" "PACKAGES.portainer[].config[].port")"
        PACKAGES_PORTAINER_CONFIG_NGINX="$(json_read_field "${server_config_file}" "PACKAGES.portainer[].config[].nginx_proxy")"
        PACKAGES_PORTAINER_CONFIG_SUBDOMAIN="$(json_read_field "${server_config_file}" "PACKAGES.portainer[].config[].subdomain")"

        # Check if all required vars are set
        if [[ -z ${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN} ]] || [[ -z ${PACKAGES_PORTAINER_CONFIG_PORT} ]] || [[ -z ${PACKAGES_PORTAINER_CONFIG_NGINX} ]]; then
            die "Missing required config vars for portainer support"
        fi

        # Checking if Portainer is not installed
        [[ -z ${PORTAINER} ]] && pkg_config_changes_detected "portainer" "true"

    else

        # Checking if Portainer is installed
        if [[ -n ${PORTAINER} ]]; then

            # Var needed for uninstall
            PACKAGES_PORTAINER_CONFIG_SUBDOMAIN="$(json_read_field "${server_config_file}" "PACKAGES.portainer[].config[].subdomain")"
            # Uninstall portainer
            pkg_config_changes_detected "portainer" "true"

        fi

    fi

    export PORTAINER PACKAGES_PORTAINER_STATUS PACKAGES_PORTAINER_CONFIG_SUBDOMAIN PACKAGES_PORTAINER_CONFIG_PORT PACKAGES_PORTAINER_CONFIG_NGINX

}

################################################################################
# Private: load portainer agent configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_portainer_agent() {

    local server_config_file="${1}"

    local docker
    local docker_installed

    # Globals
    declare -g PORTAINER_AGENT
    declare -g PACKAGES_PORTAINER_AGENT_STATUS
    declare -g PACKAGES_PORTAINER_AGENT_CONFIG_PORT

    declare -g PORTAINER_AGENT_PATH="/root/agent_portainer"

    PACKAGES_PORTAINER_AGENT_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.portainer_agent[].status")"

    # Check if docker or docker.io package are installed
    docker="$(package_is_installed "docker" || package_is_installed "docker.io")"
    docker_installed="$?"
    if [[ ${docker_installed} -eq 0 ]]; then
        log_event "debug" "Docker installed on: ${docker}. Now checking if Portainer Agent image is present..." "false"
        PORTAINER_AGENT="$(docker_get_container_id "portainer/agent")"
    fi

    if [[ ${PACKAGES_PORTAINER_AGENT_STATUS} == "enabled" ]]; then

        [[ ${docker_installed} -eq 1 ]] && die "In order to install Portainer Agent, docker and docker-compose must be installed."

        PACKAGES_PORTAINER_AGENT_CONFIG_PORT="$(json_read_field "${server_config_file}" "PACKAGES.portainer_agent[].config[].port")"
        [[ -z ${PACKAGES_PORTAINER_AGENT_CONFIG_PORT} ]] && die "Error reading PACKAGES_PORTAINER_AGENT_CONFIG_PORT from config file"

        # Checking if Portainer Agent is not installed
        [[ -z ${PORTAINER_AGENT} ]] && pkg_config_changes_detected "portainer_agent" "true"

    else

        # Checking if Portainer Agent is installed
        [[ -n ${PORTAINER_AGENT} ]] && pkg_config_changes_detected "portainer_agent" "true"

    fi

    export PORTAINER_AGENT PORTAINER_AGENT_PATH PACKAGES_PORTAINER_AGENT_STATUS PACKAGES_PORTAINER_AGENT_CONFIG_PORT

}

################################################################################
# Private: load custom package configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_custom_pkgs() {

    local server_config_file="${1}"

    # Globals
    declare -g PACKAGES_CUSTOM_CONFIG_STATUS

    PACKAGES_CUSTOM_CONFIG_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.custom[].status")"

    if [[ ${PACKAGES_CUSTOM_CONFIG_STATUS} == "enabled" ]]; then

        # Get all listed apps
        app_list="$(json_read_field "${server_config_file}" "PACKAGES.custom[].config[]")"

        # Get keys
        app_list_keys="$(jq -r 'keys[]' <<<"${app_list}" | sed ':a; N; $!ba; s/\n/ /g')"

        # String to array
        IFS=' ' read -r -a app_list_keys_array <<<"$app_list_keys"

        # Loop through all apps keys
        for app_list_key in "${app_list_keys_array[@]}"; do

            app_list_value="$(jq -r ."${app_list_key}" <<<"${app_list}")"

            if [[ ${app_list_value} == "true" ]]; then

                # Allow service on firewall
                package_install_if_not "${app_list_key}"

            else

                if [[ ${app_list_value} == "false" ]]; then

                    # Deny service on firewall
                    package_purge "${app_list_key}"

                fi

            fi

        done

    fi

}

################################################################################
# Private: load ufw configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

# TODO: Need a refactor to detect changes on port config.

function _brolit_configuration_firewall_ufw() {

    local server_config_file="${1}"

    # Check if firewall configuration in config file
    if [[ ${SECURITY_UFW_STATUS} == "enabled" ]]; then

        # Check firewall status
        firewall_status

        exitstatus=$?
        if [[ ${exitstatus} -eq 1 ]]; then
            # Enabling firewall
            firewall_enable

        fi

        # Get all listed apps
        app_list="$(json_read_field "${server_config_file}" "ufw[].config[]")"

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

            else

                if [[ ${app_list_value} == "deny" ]]; then

                    # Deny service on firewall
                    firewall_deny "${app_list_key}"

                fi

            fi

        done

    fi

    # Check if firewall configuration in config file
    if [[ ${SECURITY_UFW_STATUS} == "disabled" ]]; then

        # Check firewall status
        firewall_status

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
            # Disabling firewall
            firewall_disable

        fi

    fi

}

################################################################################
# Private: Fail2ban configuration settings
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_firewall_fail2ban() {

    # Check if firewall configuration in config file
    if [[ ${FIREWALL_FAIL2BAN_STATUS} == "enabled" ]]; then

        package_install_if_not "fail2ban"

        # TODO: need to configure fail2ban
        log_event "debug" "TODO: need to configure fail2ban" "false"

    fi

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

    [[ ${is_mysql_installed} == "true" ]] && mysql_ask_root_psw

}

################################################################################
# Check brolit configuration file
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function brolit_configuration_file_check() {

    local server_config_file="${1}"

    local brolit_config_template="${BROLIT_MAIN_DIR}/config/brolit/brolit_conf.json"

    local brolit_installed_config_version
    local brolit_release_config_version

    if [[ -f "${server_config_file}" ]]; then

        brolit_installed_config_version="$(json_read_field "${server_config_file}" "BROLIT_SETUP.config[].version")"
        brolit_release_config_version="$(json_read_field "${brolit_config_template}" "BROLIT_SETUP.config[].version")"

        if [[ ${brolit_installed_config_version} != "${brolit_release_config_version}" ]]; then
            log_event "error" "Brolit config version outdated! Please regenerate config file." "false"
            display --indent 6 --text "- Checking Brolit config version" --result "WARNING" --color YELLOW
            display --indent 8 --text "Brolit config version outdated!"
            exit 1
        fi

    else

        display --indent 2 --text "- Checking Brolit config file" --result "WARNING" --color YELLOW
        display --indent 4 --text "Config file not found!"

        # Creating new config file
        while true; do

            echo -e "${YELLOW}${ITALIC} > Do you want to create a new config file?${ENDCOLOR}"
            read -p "Please type 'y' or 'n'" yn

            case $yn in

            [Yy]*)

                cp "${brolit_config_template}" "${server_config_file}"

                log_event "critical" "Please, edit brolit_conf.json first, and then run the script again." "true"

                exit 1
                ;;

            [Nn]*)

                echo -e "${YELLOW}${ITALIC} > BROLIT can not run without a config file. Exiting ...${ENDCOLOR}"

                exit 1
                ;;

            *) echo " > Please answer yes or no." ;;

            esac

        done

    fi

}

################################################################################
# Load brolit setup configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function brolit_configuration_setup_check() {

    local server_config_file="${1}"

    declare -g DEBUG
    declare -g SKIPTESTS
    declare -g BROLIT_TMP_DIR

    # Read vars from server config file

    if [[ -z ${DEBUG} ]]; then
        DEBUG="$(json_read_field "${server_config_file}" "BROLIT_SETUP.config[].debug")"
        if [[ ${DEBUG} != "true" && ${DEBUG} != "false" ]]; then
            die "debug value should be 'true' or 'false'"
        fi
    fi

    if [[ -z ${SKIPTESTS} ]]; then
        SKIPTESTS="$(json_read_field "${server_config_file}" "BROLIT_SETUP.config[].skip_test")"
        if [[ ${SKIPTESTS} != "true" && ${SKIPTESTS} != "false" ]]; then
            die "skip_test value should be 'true' or 'false'"
        fi
    fi

    if [[ -z ${CHECKPKGS} ]]; then
        CHECKPKGS="$(json_read_field "${server_config_file}" "BROLIT_SETUP.config[].check_packages")"
        if [[ ${CHECKPKGS} != "true" && ${CHECKPKGS} != "false" ]]; then
            die "check_packages value should be 'true' or 'false'"
        fi
    fi

    # Check if is already defined
    if [[ -z ${BROLIT_TMP_DIR} ]]; then
        BROLIT_TMP_DIR="$(json_read_field "${server_config_file}" "BROLIT_SETUP.config[].tmp_dir")"

        if [[ -z ${BROLIT_TMP_DIR} ]]; then
            die "Missing required config vars: tmp_dir"
        fi

        # Check if $BROLIT_TMP_DIR starts with "/"
        if [[ ${BROLIT_TMP_DIR} != '/'* ]]; then
            BROLIT_TMP_DIR="${BROLIT_MAIN_DIR}/${BROLIT_TMP_DIR}"
        fi

        # Creating temporary folders
        [[ ! -d ${BROLIT_TMP_DIR} ]] && mkdir -p "${BROLIT_TMP_DIR}"
        [[ ! -d "${BROLIT_TMP_DIR}/${NOW}" ]] && mkdir -p "${BROLIT_TMP_DIR}/${NOW}"

    fi

    export DEBUG SKIPTESTS CHECKPKGS BROLIT_TMP_DIR

}
################################################################################
# Load Brolit configuration
#
# Arguments:
#   ${1} = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function brolit_configuration_load() {

    local server_config_file="${1}"

    # Globals
    declare -g PROJECTS_PATH
    declare -g SERVER_PREPARED="false"

    ## SERVER ROLES
    _brolit_configuration_load_server_config "${server_config_file}"

    ## BACKUPS

    ## BACKUPS config
    _brolit_configuration_load_backup_config "${server_config_file}"

    ## BACKUPS retention
    _brolit_configuration_load_backup_retention "${server_config_file}"

    #### BACKUPS Method: dropbox
    _brolit_configuration_load_backup_dropbox "${server_config_file}"

    #### BACKUPS Method: sftp
    _brolit_configuration_load_backup_sftp "${server_config_file}"

    #### BACKUPS Method: local
    _brolit_configuration_load_backup_local "${server_config_file}"

    #### BACKUPS Method: s3
    _brolit_configuration_load_backup_s3 "${server_config_file}"

    # TODO:
    #### BACKUPS Method: duplicity
    #_brolit_configuration_load_backup_duplicity "${server_config_file}"

    #### if all required vars are disabled, show error
    if [[ ${BACKUP_DROPBOX_STATUS} != "enabled" ]] &&
        [[ ${BACKUP_SFTP_STATUS} != "enabled" ]] &&
        [[ ${BACKUP_S3_STATUS} != "enabled" ]] &&
        [[ ${BACKUP_LOCAL_STATUS} != "enabled" ]]; then
        log_event "warning" "No backup method enabled" "false"
        display --indent 6 --text "- Backup method selected" --result "NONE" --color RED
        display --indent 8 --text "Please select at least one backup method"
    fi

    ## PROJECTS_PATH
    PROJECTS_PATH="$(json_read_field "${server_config_file}" "PROJECTS.path")"
    if [[ -z ${PROJECTS_PATH} ]]; then
        log_event "warning" "Missing required config vars for projects path" "true"
        exit 1
    fi

    ## NOTIFICATIONS

    ### Email
    _brolit_configuration_load_email "${server_config_file}"

    ### Telegram
    _brolit_configuration_load_telegram "${server_config_file}"

    ### Discord
    _brolit_configuration_load_discord "${server_config_file}"

    ## SECURITY
    SECURITY_STATUS="$(json_read_field "${server_config_file}" "SECURITY.status")"
    if [[ ${SECURITY_STATUS} == "enabled" ]]; then
        # Firewall config file
        firewall_config_file="$(json_read_field "${server_config_file}" "SECURITY.config[].file")"
        if [[ ! -f ${firewall_config_file} ]]; then
            cp "${BROLIT_MAIN_DIR}/config/brolit/brolit_firewall_conf.json" "${firewall_config_file}"
        fi
        # Load config
        BROLIT_SECURITY_CONFIG_FILE="${firewall_config_file}"
        # TODO: needs refactor
        _brolit_configuration_load_firewall_ufw "${BROLIT_SECURITY_CONFIG_FILE}"
        _brolit_configuration_load_firewall_fail2ban "${BROLIT_SECURITY_CONFIG_FILE}"

        export BROLIT_SECURITY_CONFIG_FILE
    fi

    ## DNS

    ### Cloudflare
    _brolit_configuration_load_cloudflare "${server_config_file}"

    ## PACKAGES

    ### nginx
    _brolit_configuration_load_nginx "${server_config_file}"

    ### mariadb
    _brolit_configuration_load_mariadb "${server_config_file}"

    ### mysql
    _brolit_configuration_load_mysql "${server_config_file}"

    ### postgresql
    _brolit_configuration_load_postgres "${server_config_file}"

    # If Server role 'database' is enabled, mariadb or mysql must be enabled
    if [[ ${PACKAGES_MARIADB_STATUS} != "enabled" ]] &&
        [[ ${PACKAGES_MYSQL_STATUS} != "enabled" ]] &&
        [[ ${PACKAGES_POSTGRES_STATUS} != "enabled" ]] &&
        [[ ${SERVER_ROLE_DATABASE} == "enabled" ]]; then
        log_event "warning" "No database engine is enabled" "true"
        exit 1
    fi

    ### redis
    _brolit_configuration_load_redis "${server_config_file}"

    ### php-fpm
    _brolit_configuration_load_php "${server_config_file}"

    ### certbot
    _brolit_configuration_load_certbot "${server_config_file}"

    ### monit
    _brolit_configuration_load_monit "${server_config_file}"

    ### docker
    _brolit_configuration_load_docker "${server_config_file}"

    ### netdata
    _brolit_configuration_load_netdata "${server_config_file}"
    _brolit_configuration_load_netdata_agent "${server_config_file}"

    ### grafana
    _brolit_configuration_load_grafana "${server_config_file}"

    ### loki
    _brolit_configuration_load_loki "${server_config_file}"

    ### promtail
    _brolit_configuration_load_promtail "${server_config_file}"

    ### cockpit
    _brolit_configuration_load_cockpit "${server_config_file}"

    ### zabbix
    _brolit_configuration_load_zabbix "${server_config_file}"

    ### portainer
    _brolit_configuration_load_portainer "${server_config_file}"

    ### portainer agent
    _brolit_configuration_load_portainer_agent "${server_config_file}"

    ### custom
    _brolit_configuration_load_custom_pkgs "${server_config_file}"

    # Export vars
    export PROJECTS_PATH
    export SERVER_PREPARED

}
