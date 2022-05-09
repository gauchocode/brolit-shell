#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc4
################################################################################
#
# Server Config Manager: Brolit server configuration management.
#
################################################################################

################################################################################
# Private: load server configuration
#
# Arguments:
#   $1 = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_server_config() {

    local server_config_file="${1}"

    # Globals
    declare -g SERVER_TIMEZONE
    declare -g UNATTENDED_UPGRADES
    declare -g SERVER_ROLE_WEBSERVER
    declare -g SERVER_ROLE_DATABASE

    # Read required vars from server config file
    SERVER_TIMEZONE="$(json_read_field "${server_config_file}" "SERVER_CONFIG.timezone")"
    if [ -z "${SERVER_TIMEZONE}" ]; then
        log_event "error" "Missing required config vars for server config" "true"
        exit 1
    fi

    UNATTENDED_UPGRADES="$(json_read_field "${server_config_file}" "SERVER_CONFIG.unattended_upgrades")"
    if [ -z "${UNATTENDED_UPGRADES}" ]; then
        log_event "error" "Missing required config vars for server config." "true"
        exit 1
    fi

    if [ -z "${SERVER_ROLE_WEBSERVER}" ]; then
        SERVER_ROLE_WEBSERVER="$(json_read_field "${server_config_file}" "SERVER_CONFIG.config[].webserver")"
        if [ -z "${SERVER_ROLE_WEBSERVER}" ]; then
            log_event "error" "Missing required config vars for server role." "true"
            exit 1
        fi
    fi

    if [ -z "${SERVER_ROLE_DATABASE}" ]; then
        SERVER_ROLE_DATABASE="$(json_read_field "${server_config_file}" "SERVER_CONFIG.config[].database")"
        if [ -z "${SERVER_ROLE_DATABASE}" ]; then
            log_event "error" "Missing required config vars for server role." "true"
            exit 1
        fi
    fi

    if [[ ${SERVER_ROLE_WEBSERVER} != "enabled" ]] && [[ ${SERVER_ROLE_DATABASE} != "enabled" ]]; then
        log_event "error" "At least one server role need to be defined." "true"
        log_event "error" "Please edit the file .brolit_conf.json and execute BROLIT again." "true"
        exit 1
    fi

}

################################################################################
# Private: load sftp backup configuration
#
# Arguments:
#   $1 = ${server_config_file}
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

        BACKUP_SFTP_CONFIG_SERVER_IP="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_ip")"
        BACKUP_SFTP_CONFIG_SERVER_PORT="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_port")"
        BACKUP_SFTP_CONFIG_SERVER_USER="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_user")"
        BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_user_password")"
        BACKUP_SFTP_CONFIG_SERVER_REMOTE_PATH="$(json_read_field "${server_config_file}" "BACKUPS.methods[].sftp[].config[].server_remote_path")"

        # Check if all required vars are set
        if [ -z "${BACKUP_SFTP_CONFIG_SERVER_IP}" ] || [ -z "${BACKUP_SFTP_CONFIG_SERVER_PORT}" ] || [ -z "${BACKUP_SFTP_CONFIG_SERVER_USER}" ] || [ -z "${BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD}" ] || [ -z "${BACKUP_SFTP_CONFIG_SERVER_REMOTE_PATH}" ]; then
            log_event "error" "Missing required config vars for SFTP backup method" "true"
            exit 1
        fi

    fi

    export BACKUP_SFTP_STATUS BACKUP_SFTP_CONFIG_SERVER_IP BACKUP_SFTP_CONFIG_SERVER_PORT BACKUP_SFTP_CONFIG_SERVER_USER BACKUP_SFTP_CONFIG_SERVER_USER_PASSWORD

}

################################################################################
# Private: load dropbox backup configuration
#
# Arguments:
#   $1 = ${server_config_file}
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

            exit 1

        fi

    fi

    export BACKUP_DROPBOX_STATUS BACKUP_DROPBOX_CONFIG_FILE

}

################################################################################
# Private: load local backup configuration
#
# Arguments:
#   $1 = ${server_config_file}
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
        # Check if all required vars are set
        if [ -z "${BACKUP_LOCAL_CONFIG_BACKUP_PATH}" ]; then
            log_event "error" "Missing required config vars for local backup method" "true"
            exit 1
        fi

    fi

    export BACKUP_LOCAL_STATUS BACKUP_LOCAL_CONFIG_BACKUP_PATH

}

################################################################################
# Private: load duplicity backup configuration
#
# Arguments:
#   $1 = ${server_config_file}
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

        BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH="$(json_read_field "${server_config_file}" "BACKUPS.methods[].duplicity[].config[].backup_destination_path")"

        # Check if all required vars are set
        if [ -z "${BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH}" ]; then
            log_event "error" "Missing required config vars for duplicity backup method" "true"
            exit 1
        fi

        BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY="$(json_read_field "${server_config_file}" "BACKUPS.methods[].duplicity[].config[].backup_frequency")"

        # Check if all required vars are set
        if [ -z "${BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY}" ]; then
            log_event "error" "Missing required config vars for duplicity backup method" "true"
            exit 1
        fi

        BACKUP_DUPLICITY_CONFIG_FULL_LIFE="$(json_read_field "${server_config_file}" "BACKUPS.methods[].duplicity[].config[].backup_full_life")"

        # Check if all required vars are set
        if [ -z "${BACKUP_DUPLICITY_CONFIG_FULL_LIFE}" ]; then
            log_event "error" "Missing required config vars for duplicity backup method" "true"
            exit 1
        fi

    fi

    export BACKUP_DUPLICITY_STATUS BACKUP_DUPLICITY_CONFIG_BACKUP_DESTINATION_PATH BACKUP_DUPLICITY_CONFIG_BACKUP_FREQUENCY BACKUP_DUPLICITY_CONFIG_FULL_LIFE

}

################################################################################
# Private: load backup retentions configuration
#
# Arguments:
#   $1 = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_backup_config() {

    local server_config_file="${1}"

    # Globals
    declare -g BACKUP_CONFIG_PROJECTS_STATUS
    declare -g BACKUP_CONFIG_PROJECTS_EXCLUDE_LIST
    declare -g BACKUP_CONFIG_DATABASES_STATUS
    declare -g BACKUP_CONFIG_DATABASES_EXCLUDE_LIST
    declare -g BACKUP_CONFIG_SERVER_CFG_STATUS
    declare -g BACKUP_CONFIG_COMPRESSION_TYPE

    ## Backup config projects
    BACKUP_CONFIG_PROJECTS_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.config[].projects[].status")"
    if [[ -z ${BACKUP_CONFIG_PROJECTS_STATUS} ]]; then
        log_event "error" "Missing required config vars for backup retention" "true"
        exit 1
    fi
    BACKUP_CONFIG_PROJECTS_EXCLUDE_LIST="$(json_read_field "${server_config_file}" "BACKUPS.config[].projects[].exclude")"

    ## Backup config databases
    BACKUP_CONFIG_DATABASES_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.config[].databases[].status")"
    if [[ -z ${BACKUP_CONFIG_DATABASES_STATUS} ]]; then
        log_event "error" "Missing required config vars for backup retention" "true"
        exit 1
    fi
    BACKUP_CONFIG_DATABASES_EXCLUDE_LIST="$(json_read_field "${server_config_file}" "BACKUPS.config[].databases[].exclude")"

    ## Backup config server_cfg
    BACKUP_CONFIG_SERVER_CFG_STATUS="$(json_read_field "${server_config_file}" "BACKUPS.config[].server_cfg")"
    if [[ -z ${BACKUP_CONFIG_SERVER_CFG_STATUS} ]]; then
        log_event "error" "Missing required config vars for backup retention" "true"
        exit 1
    fi

    ## Backup config compression_type
    BACKUP_CONFIG_COMPRESSION_TYPE="$(json_read_field "${server_config_file}" "BACKUPS.config[].compression_type")"
    if [[ -z ${BACKUP_CONFIG_COMPRESSION_TYPE} ]]; then
        log_event "error" "Missing required config vars for backup retention" "true"
        exit 1
    fi

    export BACKUP_CONFIG_PROJECTS_STATUS BACKUP_CONFIG_DATABASES_STATUS BACKUP_CONFIG_SERVER_CFG_STATUS BACKUP_CONFIG_PROJECTS_EXCLUDE_LIST BACKUP_CONFIG_DATABASES_EXCLUDE_LIST

}

################################################################################
# Private: load backup retentions configuration
#
# Arguments:
#   $1 = ${server_config_file}
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
    DAYSAGO="$(date --date="${BACKUP_RETENTION_KEEP_DAILY} days ago" +"%Y-%m-%d")"

    ## retention
    BACKUP_RETENTION_KEEP_DAILY="$(json_read_field "${server_config_file}" "BACKUPS.config[].retention[].keep_daily")"

    if [ -z "${BACKUP_RETENTION_KEEP_DAILY}" ]; then
        log_event "error" "Missing required config vars for backup retention" "true"
        exit 1
    fi

    BACKUP_RETENTION_KEEP_WEEKLY="$(json_read_field "${server_config_file}" "BACKUPS.config[].retention[].keep_weekly")"

    if [ -z "${BACKUP_RETENTION_KEEP_WEEKLY}" ]; then
        log_event "error" "Missing required config vars for backup retention" "true"
        exit 1
    fi

    BACKUP_RETENTION_KEEP_MONTHLY="$(json_read_field "${server_config_file}" "BACKUPS.config[].retention[].keep_monthly")"

    if [ -z "${BACKUP_RETENTION_KEEP_MONTHLY}" ]; then
        log_event "error" "Missing required config vars for backup retention" "true"
        exit 1
    fi

    export DAYSAGO BACKUP_RETENTION_KEEP_DAILY BACKUP_RETENTION_KEEP_WEEKLY BACKUP_RETENTION_KEEP_MONTHLY

}

################################################################################
# Private: load email notifications configuration
#
# Arguments:
#   $1 = ${server_config_file}
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

    #display --indent 2 --text "- Checking email notifications config"

    ### email
    NOTIFICATION_EMAIL_STATUS="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].status")"

    if [[ ${NOTIFICATION_EMAIL_STATUS} == "enabled" ]]; then

        NOTIFICATION_EMAIL_MAILA="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].maila")"
        NOTIFICATION_EMAIL_SMTP_SERVER="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_server")"
        NOTIFICATION_EMAIL_SMTP_PORT="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_port")"
        NOTIFICATION_EMAIL_SMTP_TLS="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_tls")"
        NOTIFICATION_EMAIL_SMTP_USER="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_user")"
        NOTIFICATION_EMAIL_SMTP_UPASS="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].smtp_user_pass")"

        if [[ -z "${NOTIFICATION_EMAIL_MAILA}" ]] || [[ -z "${NOTIFICATION_EMAIL_SMTP_SERVER}" ]] || [[ -z "${NOTIFICATION_EMAIL_SMTP_PORT}" ]] || [[ -z "${NOTIFICATION_EMAIL_SMTP_USER}" ]] || [[ -z "${NOTIFICATION_EMAIL_SMTP_UPASS}" ]]; then

            #clear_previous_lines "1"
            display --indent 4 --text "Missing required config vars for email notifications" --tcolor RED
            exit 1

        fi

    else

        #clear_previous_lines "1"
        display --indent 6 --text "- Checking email notifications config" --result "WARNING" --color YELLOW
        display --indent 8 --text "Email notifications are disabled"

    fi

    export NOTIFICATION_EMAIL_STATUS NOTIFICATION_EMAIL_MAILA NOTIFICATION_EMAIL_SMTP_SERVER NOTIFICATION_EMAIL_SMTP_PORT NOTIFICATION_EMAIL_SMTP_TLS NOTIFICATION_EMAIL_SMTP_USER NOTIFICATION_EMAIL_SMTP_UPASS

}

################################################################################
# Private: load telegram notifications configuration
#
# Arguments:
#   $1 = ${server_config_file}
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

        NOTIFICATION_TELEGRAM_BOT_TOKEN="$(json_read_field "${server_config_file}" "NOTIFICATIONS.telegram[].config[].bot_token")"
        NOTIFICATION_TELEGRAM_CHAT_ID="$(json_read_field "${server_config_file}" "NOTIFICATIONS.telegram[].config[].chat_id")"

        # Check if all required vars are set
        if [[ -z "${NOTIFICATION_TELEGRAM_BOT_TOKEN}" ]] || [[ -z "${NOTIFICATION_TELEGRAM_CHAT_ID}" ]]; then
            log_event "error" "Missing required config vars for telegram notifications" "true"
            exit 1
        fi

    fi

    export NOTIFICATION_TELEGRAM_STATUS NOTIFICATION_TELEGRAM_BOT_TOKEN NOTIFICATION_TELEGRAM_CHAT_ID

}

################################################################################
# Private: load ufw configuration
#
# Arguments:
#   $1 = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_firewall_ufw() {

    local server_config_file="${1}"

    # Globals
    declare -g FIREWALL_UFW_STATUS
    declare -g FIREWALL_UFW_APP_LIST_SSH

    FIREWALL_UFW_STATUS="$(json_read_field "${server_config_file}" "FIREWALL.ufw[].status")"

    if [[ ${FIREWALL_UFW_STATUS} == "enabled" ]]; then

        # Mandatory
        FIREWALL_UFW_APP_LIST_SSH="$(json_read_field "${server_config_file}" "FIREWALL.ufw[].config[].ssh")"

        # Check if all required vars are set
        if [[ -z "${FIREWALL_UFW_APP_LIST_SSH}" ]]; then
            log_event "error" "Missing required config vars for firewall" "true"
            exit 1
        fi

    fi

    _brolit_configuration_firewall_ufw

    export FIREWALL_UFW_APP_LIST_SSH FIREWALL_UFW_STATUS

}

################################################################################
# Private: load fail2ban configuration
#
# Arguments:
#   $1 = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_firewall_fail2ban() {

    local server_config_file="${1}"

    # Globals
    declare -g FIREWALL_FAIL2BAN_STATUS

    FIREWALL_FAIL2BAN_STATUS="$(json_read_field "${server_config_file}" "FIREWALL.fail2ban[].status")"

    if [[ ${FIREWALL_FAIL2BAN_STATUS} == "enabled" ]]; then

        # Check if all required vars are set
        if [[ -z "${FIREWALL_FAIL2BAN_STATUS}" ]]; then
            log_event "error" "Missing required config vars for firewall" "true"
            exit 1
        fi

    fi

    _brolit_configuration_firewall_fail2ban

    export FIREWALL_FAIL2BAN_STATUS

}

################################################################################
# Private: load cloudflare support configuration
#
# Arguments:
#   $1 = ${server_config_file}
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

    SUPPORT_CLOUDFLARE_STATUS="$(json_read_field "${server_config_file}" "SUPPORT.cloudflare[].status")"

    if [[ ${SUPPORT_CLOUDFLARE_STATUS} == "enabled" ]]; then

        SUPPORT_CLOUDFLARE_EMAIL="$(json_read_field "${server_config_file}" "SUPPORT.cloudflare[].config[].email")"
        SUPPORT_CLOUDFLARE_API_KEY="$(json_read_field "${server_config_file}" "SUPPORT.cloudflare[].config[].api_key")"

        # Write .cloudflare.conf (needed for certbot support)
        echo "dns_cloudflare_email=${SUPPORT_CLOUDFLARE_EMAIL}" >~/.cloudflare.conf
        echo "dns_cloudflare_api_key=${SUPPORT_CLOUDFLARE_API_KEY}" >>~/.cloudflare.conf

        # Check if all required vars are set
        if [[ -z "${SUPPORT_CLOUDFLARE_EMAIL}" ]] || [[ -z "${SUPPORT_CLOUDFLARE_API_KEY}" ]]; then
            log_event "error" "Missing required config vars for Cloudflare support" "true"
            exit 1
        fi

    fi

    export SUPPORT_CLOUDFLARE_STATUS SUPPORT_CLOUDFLARE_EMAIL SUPPORT_CLOUDFLARE_API_KEY

}

################################################################################
# Private: load nginx configuration
#
# Arguments:
#   $1 = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_nginx() {

    local server_config_file="${1}"

    # Globals
    declare -g PACKAGES_NGINX_STATUS
    declare -g PACKAGES_NGINX_CONFIG_VERSION
    declare -g PACKAGES_NGINX_CONFIG_PORTS

    declare -g WSERVER="/etc/nginx" # Webserver config files location

    # NGINX
    nginx_bin="$(package_is_installed "nginx")"
    exitstatus=$?

    PACKAGES_NGINX_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.nginx[].status")"

    if [[ ${PACKAGES_NGINX_STATUS} == "enabled" ]]; then

        PACKAGES_NGINX_CONFIG_VERSION="$(json_read_field "${server_config_file}" "PACKAGES.nginx[].version")"
        # Check if all required vars are set
        if [[ -z ${PACKAGES_NGINX_CONFIG_VERSION} ]]; then
            log_event "error" "Missing required config vars for nginx" "true"
            exit 1
        fi

        PACKAGES_NGINX_CONFIG_PORTS="$(json_read_field "${server_config_file}" "PACKAGES.nginx[].config[].port")"
        # Check if all required vars are set
        if [[ -z ${PACKAGES_NGINX_CONFIG_PORTS} ]]; then
            log_event "error" "Missing required config vars for nginx" "true"
            exit 1
        fi

        # Checking if nginx is not installed
        if [[ ${exitstatus} -eq 1 ]]; then
            menu_config_changes_detected "nginx" "true"
        fi

    else

        # Checking if nginx is  installed
        if [[ ${exitstatus} -eq 0 ]]; then
            menu_config_changes_detected "nginx" "true"
        fi

    fi

    export NGINX WSERVER PACKAGES_NGINX_STATUS PACKAGES_NGINX_CONFIG_VERSION PACKAGES_NGINX_CONFIG_PORTS

}

################################################################################
# Private: load php configuration
#
# Arguments:
#   $1 = ${server_config_file}
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
    declare -g PACKAGES_PHP_EXTENSIONS_COMPOSER

    # PHP
    PHP="$(command -v php)"

    PACKAGES_PHP_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.php[].status")"

    if [[ ${PACKAGES_PHP_STATUS} == "enabled" ]]; then

        source "${BROLIT_MAIN_DIR}/utils/installers/php_installer.sh"

        PACKAGES_PHP_VERSION="$(json_read_field "${server_config_file}" "PACKAGES.php[].version")"
        # Check if all required vars are set
        if [[ -z ${PACKAGES_PHP_VERSION} ]]; then

            log_event "error" "Missing required config vars for php" "true"
            exit 1

        else

            if [[ ${PACKAGES_PHP_VERSION} == "default" ]]; then

                PHP_V="$(php_get_distro_default_version)"

            else

                PHP_V="${PACKAGES_PHP_VERSION}"

            fi

        fi

        PACKAGES_PHP_CONFIG_OPCODE="$(json_read_field "${server_config_file}" "PACKAGES.php[].config[].opcode")"
        # Check if all required vars are set
        if [[ -z ${PACKAGES_PHP_CONFIG_OPCODE} ]]; then
            log_event "error" "Missing required config vars for php" "true"
            exit 1
        fi

        PACKAGES_PHP_EXTENSIONS_WPCLI="$(json_read_field "${server_config_file}" "PACKAGES.php[].extensions[].wpcli")"
        # Check if all required vars are set
        if [[ -z ${PACKAGES_PHP_EXTENSIONS_WPCLI} ]]; then
            log_event "error" "Missing required config vars for php" "true"
            exit 1
        fi

        PACKAGES_PHP_EXTENSIONS_REDIS="$(json_read_field "${server_config_file}" "PACKAGES.php[].extensions[].redis")"
        # Check if all required vars are set
        if [[ -z ${PACKAGES_PHP_EXTENSIONS_REDIS} ]]; then
            log_event "error" "Missing required config vars for php" "true"
            exit 1
        fi

        PACKAGES_PHP_EXTENSIONS_COMPOSER="$(json_read_field "${server_config_file}" "PACKAGES.php[].extensions[].composer")"
        # Check if all required vars are set
        if [[ -z ${PACKAGES_PHP_EXTENSIONS_COMPOSER} ]]; then
            log_event "error" "Missing required config vars for php" "true"
            exit 1
        fi

        #package_is_installed "php${PHP_V}-fpm"

        # Checking if php is not installed
        if [[ ! -x ${PHP} ]]; then
            menu_config_changes_detected "php" "true"
        fi

    else

        # Checking if php is  installed
        if [[ -x ${PHP} ]]; then
            menu_config_changes_detected "php" "true"
        fi

    fi

    export PHP PHP_CONF_DIR PHP_V PACKAGES_PHP_STATUS PACKAGES_PHP_VERSION PACKAGES_PHP_CONFIG_OPCODE

}

################################################################################
# Private: load mariadb configuration
#
# Arguments:
#   $1 = ${server_config_file}
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
        # Check if all required vars are set
        if [[ -z ${PACKAGES_MARIADB_CONFIG_VERSION} ]]; then
            log_event "error" "Missing required config vars for mariadb" "true"
            exit 1
        fi

        PACKAGES_MARIADB_CONFIG_PORTS="$(json_read_field "${server_config_file}" "PACKAGES.mariadb[].config[].port")"
        # Check if all required vars are set
        if [[ -z ${PACKAGES_MARIADB_CONFIG_PORTS} ]]; then
            log_event "error" "Missing required config vars for mariadb" "true"
            exit 1
        fi

        # Checking if MYSQL is not installed
        if [[ ! -x ${MYSQL} ]]; then
            menu_config_changes_detected "mariadb" "true"

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

        # ${PACKAGES_MYSQL_STATUS} == "disabled"

        if [[ -x ${MYSQL} ]]; then
            # Check which mysql version is installed
            is_mariadb="$(mysql -V | grep MariaDB)"

            # Checking if MYSQL is installed and is not MariaDB
            if [[ -n ${is_mariadb} ]]; then
                menu_config_changes_detected "mariadb" "true"
            fi

        fi

    fi

    #_brolit_configuration_app_mysql

    export MHOST MUSER MYSQL_CONF_DIR MYSQL MYSQL_CONF MYSQL_ROOT MYSQLDUMP_ROOT MYSQLDUMP
    export PACKAGES_MARIADB_STATUS PACKAGES_MARIADB_CONFIG_VERSION PACKAGES_MARIADB_CONFIG_PORTS

}

################################################################################
# Private: load mysql configuration
#
# Arguments:
#   $1 = ${server_config_file}
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
        # Check if all required vars are set
        if [[ -z ${PACKAGES_MYSQL_CONFIG_VERSION} ]]; then
            log_event "error" "Missing required config vars for mysql" "true"
            exit 1
        fi

        PACKAGES_MYSQL_CONFIG_PORTS="$(json_read_field "${server_config_file}" "PACKAGES.mysql[].config[].port")"
        # Check if all required vars are set
        if [[ -z ${PACKAGES_MYSQL_CONFIG_PORTS} ]]; then
            log_event "error" "Missing required config vars for mysql" "true"
            exit 1
        fi

        # Checking if MYSQL is not installed
        if [[ ! -x ${MYSQL} ]]; then
            menu_config_changes_detected "mysql" "true"
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

    else
        # ${PACKAGES_MYSQL_STATUS} == "disabled"

        if [[ -x ${MYSQL} ]]; then
            # Check which mysql version is installed
            is_mariadb="$(mysql -V | grep MariaDB)"

            # Checking if MYSQL is installed and is not MariaDB
            if [[ -z ${is_mariadb} ]]; then
                menu_config_changes_detected "mysql" "true"
            fi

        fi

    fi

    #_brolit_configuration_app_mysql

    export MHOST MUSER MYSQL_CONF_DIR MYSQL MYSQL_CONF MYSQL_ROOT MYSQLDUMP_ROOT MYSQLDUMP
    export PACKAGES_MYSQL_STATUS PACKAGES_MYSQL_CONFIG_VERSION PACKAGES_MYSQL_CONFIG_PORTS

}

################################################################################
# Private: load postgres configuration
#
# Arguments:
#   $1 = ${server_config_file}
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
        # Check if all required vars are set
        if [[ -z ${PACKAGES_POSTGRES_CONFIG_VERSION} ]]; then
            log_event "error" "Missing required config vars for postgres" "true"
            exit 1
        fi

        PACKAGES_POSTGRES_CONFIG_PORTS="$(json_read_field "${server_config_file}" "PACKAGES.postgres[].config[].port")"
        # Check if all required vars are set
        if [[ -z ${PACKAGES_POSTGRES_CONFIG_PORTS} ]]; then
            log_event "error" "Missing required config vars for postgres" "true"
            exit 1
        fi

        # Checking if Postgres is not installed
        if [[ ! -x ${POSTGRES} ]]; then
            menu_config_changes_detected "postgres" "true"
        fi

        PSQLDUMP="$(command -v pg_dump)"

        # Append login parameters to command
        PSQL_ROOT="sudo -u postgres -i psql --quiet"
        PSQLDUMP_ROOT="sudo -u postgres -i pg_dump --quiet"

    else

        # Checking if Postgres is installed
        if [[ -x ${POSTGRES} ]]; then
            menu_config_changes_detected "postgres" "true"
        fi

    fi

    export POSTGRES PSQLDUMP PSQL_ROOT PSQLDUMP_ROOT
    export PACKAGES_POSTGRES_STATUS PACKAGES_POSTGRES_CONFIG_VERSION PACKAGES_POSTGRES_CONFIG_PORTS

}

################################################################################
# Private: load redis configuration
#
# Arguments:
#   $1 = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_redis() {

    local server_config_file="${1}"

    # Globals
    declare -g PACKAGES_REDIS_STATUS
    declare -g PACKAGES_REDIS_CONFIG_VERSION
    declare -g PACKAGES_REDIS_CONFIG_PORTS

    REDIS="$(command -v redis-cli)"

    PACKAGES_REDIS_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.redis[].status")"

    if [[ ${PACKAGES_REDIS_STATUS} == "enabled" ]]; then

        PACKAGES_REDIS_CONFIG_VERSION="$(json_read_field "${server_config_file}" "PACKAGES.redis[].version")"
        # Check if all required vars are set
        if [[ -z ${PACKAGES_REDIS_CONFIG_VERSION} ]]; then
            log_event "error" "Missing required config vars for redis" "true"
            exit 1
        fi

        PACKAGES_REDIS_CONFIG_PORTS="$(json_read_field "${server_config_file}" "PACKAGES.redis[].config[].port")"
        # Check if all required vars are set
        if [[ -z ${PACKAGES_REDIS_CONFIG_PORTS} ]]; then
            log_event "error" "Missing required config vars for redis" "true"
            exit 1
        fi

        # Checking if Redis is not installed
        if [[ ! -x ${REDIS} ]]; then
            menu_config_changes_detected "redis" "true"
        fi

    else

        # Checking if Redis is  installed
        if [[ -x ${REDIS} ]]; then
            menu_config_changes_detected "redis" "true"
        fi

    fi

    export REDIS PACKAGES_REDIS_STATUS PACKAGES_REDIS_CONFIG_VERSION PACKAGES_REDIS_CONFIG_PORTS

}

################################################################################
# Private: load certbot configuration
#
# Arguments:
#   $1 = ${server_config_file}
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
    #CERTBOT="$(command -v certbot)"

    if [[ ${PACKAGES_CERTBOT_STATUS} == "enabled" ]]; then

        PACKAGES_CERTBOT_CONFIG_MAILA="$(json_read_field "${server_config_file}" "PACKAGES.certbot[].config[].email")"

        # Check if all required vars are set
        if [[ -z "${PACKAGES_CERTBOT_CONFIG_MAILA}" ]]; then
            log_event "error" "Missing required config vars for certbot" "true"
            exit 1
        fi

        # Checking if Certbot is not installed
        if [[ ! -x "${CERTBOT}" ]]; then
            menu_config_changes_detected "certbot" "true"
        fi

    else

        # Checking if Certbot is  installed
        if [[ -x "${CERTBOT}" ]]; then
            menu_config_changes_detected "certbot" "true"
        fi

        display --indent 6 --text "- Certbot disabled" --result "WARNING" --color YELLOW

    fi

    export CERTBOT LENCRYPT_CONF_DIR PACKAGES_CERTBOT_STATUS PACKAGES_CERTBOT_CONFIG_MAILA

}

################################################################################
# Private: load monit configuration
#
# Arguments:
#   $1 = ${server_config_file}
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

        # Check if all required vars are set
        if [[ -z ${PACKAGES_MONIT_CONFIG_MAILA} ]]; then
            log_event "error" "Missing required config vars for monit" "true"
            exit 1
        fi

        PACKAGES_MONIT_CONFIG_HTTPD_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.monit[].config[].monit_httpd[].status")"
        PACKAGES_MONIT_CONFIG_HTTPD_USER="$(json_read_field "${server_config_file}" "PACKAGES.monit[].config[].monit_httpd[].user")"
        PACKAGES_MONIT_CONFIG_HTTPD_PASS="$(json_read_field "${server_config_file}" "PACKAGES.monit[].config[].monit_httpd[].pass")"

        # Check if all required vars are set
        if [[ -z ${PACKAGES_MONIT_CONFIG_HTTPD_STATUS} ]]; then
            log_event "error" "Missing required config vars for monit" "true"
            exit 1
        fi

        MONIT_CONFIG_SERVICES="$(json_read_field "${server_config_file}" "PACKAGES.monit[].config[].monit_services[]")"

        # Check if all required vars are set
        if [[ -z ${MONIT_CONFIG_SERVICES} ]]; then
            log_event "error" "Missing required config vars for monit" "true"
            exit 1
        fi

        # Checking if Monit is not installed
        if [[ ! -x ${MONIT} ]]; then
            menu_config_changes_detected "monit" "true"
        fi

    else

        # Checking if Monit is installed
        if [[ -x ${MONIT} ]]; then
            menu_config_changes_detected "monit" "true"
        fi

    fi

    export MONIT PACKAGES_MONIT_STATUS PACKAGES_MONIT_CONFIG_MAILA PACKAGES_MONIT_CONFIG_HTTPD_STATUS PACKAGES_MONIT_CONFIG_HTTPD_USER PACKAGES_MONIT_CONFIG_HTTPD_PASS

}

################################################################################
# Private: load netdata configuration
#
# Arguments:
#   $1 = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_netdata() {

    local server_config_file="${1}"

    # Globals
    declare -g NETDATA
    declare -g NETDATA_PR
    declare -g PACKAGES_NETDATA_STATUS
    declare -g PACKAGES_NETDATA_CONFIG_SUBDOMAIN
    declare -g PACKAGES_NETDATA_CONFIG_USER
    declare -g PACKAGES_NETDATA_CONFIG_USER_PASS
    declare -g PACKAGES_NETDATA_NOTIFICATION_ALARM_LEVEL
    declare -g PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_STATUS
    declare -g PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_BOT_TOKEN
    declare -g PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_CHAT_ID

    NETDATA="$(which netdata)"
    NETDATA_PR="$(pgrep netdata)"

    PACKAGES_NETDATA_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].status")"

    if [[ ${PACKAGES_NETDATA_STATUS} == "enabled" ]]; then

        PACKAGES_NETDATA_CONFIG_SUBDOMAIN="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].config[].subdomain")"
        PACKAGES_NETDATA_CONFIG_USER="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].config[].user")"
        PACKAGES_NETDATA_CONFIG_USER_PASS="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].config[].user_pass")"

        PACKAGES_NETDATA_NOTIFICATION_ALARM_LEVEL="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].notifications[].alarm_level")"
        PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].notifications[].telegram[].status")"

        if [[ ${PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_STATUS} == "enabled" ]]; then

            PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_BOT_TOKEN="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].notifications[].telegram[].config[].bot_token")"
            PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_CHAT_ID="$(json_read_field "${server_config_file}" "PACKAGES.netdata[].notifications[].telegram[].config[].chat_id")"

            # Check if all required vars are set
            if [[ -z "${PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_BOT_TOKEN}" ]] || [[ -z "${PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_CHAT_ID}" ]]; then
                log_event "error" "Missing required config vars for netdata notifications" "true"
                exit 1
            fi

        fi

        # Check if all required vars are set
        if [[ -z "${PACKAGES_NETDATA_CONFIG_SUBDOMAIN}" ]] || [[ -z "${PACKAGES_NETDATA_CONFIG_USER}" ]] || [[ -z "${PACKAGES_NETDATA_CONFIG_USER_PASS}" ]] || [[ -z "${PACKAGES_NETDATA_NOTIFICATION_ALARM_LEVEL}" ]]; then
            log_event "error" "Missing required config vars for netdata support" "true"
            exit 1
        fi

        # Checking if Netdata is not installed
        if [[ ! -x "${NETDATA}" && -z "${NETDATA_PR}" ]]; then
            menu_config_changes_detected "netdata" "true"
        fi

    else

        # Checking if Netdata is installed
        if [[ -x "${NETDATA}" || -n "${NETDATA_PR}" ]]; then
            menu_config_changes_detected "netdata" "true"
        fi

    fi

    export PACKAGES_NETDATA_STATUS PACKAGES_NETDATA_CONFIG_SUBDOMAIN PACKAGES_NETDATA_CONFIG_USER PACKAGES_NETDATA_CONFIG_USER_PASS PACKAGES_NETDATA_NOTIFICATION_ALARM_LEVEL
    export PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_STATUS PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_BOT_TOKEN PACKAGES_NETDATA_NOTIFICATION_TELEGRAM_CHAT_ID

}

################################################################################
# Private: load cockpit configuration
#
# Arguments:
#   $1 = ${server_config_file}
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
            log_event "error" "Missing required config vars for netdata support" "true"
            exit 1
        fi

        # Checking if Cockpit is not installed
        if [[ ! -x "${COCKPIT}" && -z "${COCKPIT_PR}" ]]; then
            menu_config_changes_detected "cockpit" "true"
        fi

    else

        # Checking if Cockpit is installed
        if [[ -x "${COCKPIT}" || -n "${COCKPIT_PR}" ]]; then
            menu_config_changes_detected "cockpit" "true"
        fi

    fi

    export COCKPIT PACKAGES_COCKPIT_STATUS PACKAGES_COCKPIT_CONFIG_SUBDOMAIN PACKAGES_COCKPIT_CONFIG_NGINX_PROXY PACKAGES_COCKPIT_CONFIG_PORT

}

################################################################################
# Private: load zabbix configuration
#
# Arguments:
#   $1 = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_zabbix() {

    local server_config_file="${1}"

    # Globals
    declare -g ZABBIX
    declare -g ZABBIX_PR
    declare -g PACKAGES_ZABBIX_STATUS
    declare -g PACKAGES_ZABBIX_CONFIG_SUBDOMAIN

    ZABBIX="$(which zabbix)"
    ZABBIX_PR="$(pgrep zabbix)"

    PACKAGES_ZABBIX_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.zabbix[].status")"

    if [[ ${PACKAGES_ZABBIX_STATUS} == "enabled" ]]; then

        PACKAGES_ZABBIX_CONFIG_SUBDOMAIN="$(json_read_field "${server_config_file}" "PACKAGES.zabbix[].config[].subdomain")"

        # Check if all required vars are set
        if [[ -z "${PACKAGES_ZABBIX_CONFIG_SUBDOMAIN}" ]]; then
            log_event "error" "Missing required config vars for netdata support" "true"
            exit 1
        fi

        # Checking if Cockpit is not installed
        if [[ ! -x "${ZABBIX}" && -z "${ZABBIX_PR}" ]]; then
            menu_config_changes_detected "zabbix" "true"
        fi

    else

        # Checking if Cockpit is installed
        if [[ -x "${ZABBIX}" || -n "${ZABBIX_PR}" ]]; then
            menu_config_changes_detected "zabbix" "true"
        fi

    fi

    export ZABBIX PACKAGES_ZABBIX_STATUS PACKAGES_ZABBIX_CONFIG_SUBDOMAIN

}

################################################################################
# Private: load docker configuration
#
# Arguments:
#   $1 = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_load_docker() {

    local server_config_file="${1}"

    local exitstatus

    # Globals
    declare -g DOCKER
    declare -g PACKAGES_DOCKER_STATUS
    declare -g DOCKER_COMPOSE
    declare -g PACKAGES_DOCKER_COMPOSE_STATUS

    PACKAGES_DOCKER_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.docker[].status")"
    PACKAGES_DOCKER_COMPOSE_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.docker[].compose[].status")"

    DOCKER="$(package_is_installed "docker")"
    DOCKER_COMPOSE="$(package_is_installed "docker-compose")"

    if [[ ${PACKAGES_DOCKER_STATUS} == "enabled" ]]; then

        # Checking if docker is not installed
        if [[ -z ${DOCKER} ]]; then
            menu_config_changes_detected "docker" "true"

            if [[ ${PACKAGES_DOCKER_COMPOSE_STATUS} == "enabled" ]]; then
                menu_config_changes_detected "docker-compose" "true"
            fi

        fi

    else

        # Checking if docker is installed
        if [[ -n ${DOCKER} ]]; then
            menu_config_changes_detected "docker" "true"
        fi
        if [[ -n ${DOCKER_COMPOSE} ]]; then
            menu_config_changes_detected "docker-compose" "true"
        fi

    fi

    export DOCKER DOCKER_COMPOSE PACKAGES_DOCKER_STATUS PACKAGES_DOCKER_COMPOSE_STATUS

}

################################################################################
# Private: load portainer configuration
#
# Arguments:
#   $1 = ${server_config_file}
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

    docker="$(package_is_installed "docker")"
    docker_installed="$?"
    if [[ ${docker_installed} -eq 0 ]]; then
        log_event "debug" "Docker installed on: ${docker}. Now checking if Portainer image is present..." "false"
        PORTAINER="$(docker_get_container_id "portainer")"
    fi

    if [[ ${PACKAGES_PORTAINER_STATUS} == "enabled" ]]; then

        if [[ ${docker_installed} -eq 1 ]]; then
            log_event "error" "In order to install Portainer, docker and docker-compose must be installed." "true"
            exit 1
        fi

        PACKAGES_PORTAINER_CONFIG_PORT="$(json_read_field "${server_config_file}" "PACKAGES.portainer[].config[].port")"
        PACKAGES_PORTAINER_CONFIG_NGINX="$(json_read_field "${server_config_file}" "PACKAGES.portainer[].config[].nginx_proxy")"
        PACKAGES_PORTAINER_CONFIG_SUBDOMAIN="$(json_read_field "${server_config_file}" "PACKAGES.portainer[].config[].subdomain")"

        # Check if all required vars are set
        if [[ -z ${PACKAGES_PORTAINER_CONFIG_SUBDOMAIN} ]] || [[ -z ${PACKAGES_PORTAINER_CONFIG_PORT} ]] || [[ -z ${PACKAGES_PORTAINER_CONFIG_NGINX} ]]; then
            log_event "error" "Missing required config vars for portainer support" "true"
            exit 1
        fi

        # Checking if Portainer is not installed
        if [[ -z ${PORTAINER} ]]; then
            menu_config_changes_detected "portainer" "true"
        fi

    else

        # Checking if Portainer is installed
        if [[ -n ${PORTAINER} ]]; then
            menu_config_changes_detected "portainer" "true"
        fi

    fi

    export PORTAINER PACKAGES_PORTAINER_STATUS PACKAGES_PORTAINER_CONFIG_SUBDOMAIN PACKAGES_PORTAINER_CONFIG_PORT PACKAGES_PORTAINER_CONFIG_NGINX

}

function _brolit_configuration_load_mailcow() {

    local server_config_file="${1}"

    local docker
    local docker_installed

    # Globals
    declare -g MAILCOW
    declare -g PACKAGES_MAILCOW_STATUS
    declare -g PACKAGES_MAILCOW_CONFIG_SUBDOMAIN
    declare -g PACKAGES_MAILCOW_CONFIG_PORT
    declare -g PACKAGES_MAILCOW_CONFIG_NGINX
    ## MAILCOW BACKUP
    declare -g MAILCOW_DIR="/opt/mailcow-dockerized/"
    declare -g MAILCOW_TMP_BK="${BROLIT_MAIN_DIR}/tmp/mailcow"

    PACKAGES_MAILCOW_STATUS="$(json_read_field "${server_config_file}" "PACKAGES.mailcow[].status")"

    docker="$(package_is_installed "docker")"
    docker_installed="$?"
    if [[ ${docker_installed} -eq 0 ]]; then
        log_event "debug" "Docker installed on: ${docker}. Now checking if Portainer image is present..." "false"
        MAILCOW="$(docker_get_container_id "mailcow")"
    fi

    if [[ ${PACKAGES_MAILCOW_STATUS} == "enabled" ]]; then

        if [[ ${docker_installed} -eq 1 ]]; then
            log_event "error" "In order to install Portainer, docker and docker-compose must be installed." "true"
            exit 1
        fi

        PACKAGES_MAILCOW_CONFIG_PORT="$(json_read_field "${server_config_file}" "PACKAGES.mailcow[].config[].port")"
        PACKAGES_MAILCOW_CONFIG_NGINX="$(json_read_field "${server_config_file}" "PACKAGES.mailcow[].config[].nginx_proxy")"
        PACKAGES_MAILCOW_CONFIG_SUBDOMAIN="$(json_read_field "${server_config_file}" "PACKAGES.mailcow[].config[].subdomain")"

        # Check if all required vars are set
        if [[ -z ${PACKAGES_MAILCOW_CONFIG_SUBDOMAIN} ]] || [[ -z ${PACKAGES_MAILCOW_CONFIG_PORT} ]] || [[ -z ${PACKAGES_MAILCOW_CONFIG_NGINX} ]]; then
            log_event "error" "Missing required config vars for mailcow support" "true"
            exit 1
        fi

        # Checking if Portainer is not installed
        if [[ -z ${MAILCOW} ]]; then
            menu_config_changes_detected "mailcow" "true"
        fi

    else

        # Checking if Portainer is installed
        if [[ -n ${MAILCOW} ]]; then
            menu_config_changes_detected "mailcow" "true"
        fi

    fi

    export MAILCOW MAILCOW_DIR MAILCOW_TMP_BK PACKAGES_MAILCOW_STATUS PACKAGES_MAILCOW_CONFIG_SUBDOMAIN PACKAGES_MAILCOW_CONFIG_PORT PACKAGES_MAILCOW_CONFIG_NGINX

}

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
#   $1 = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function _brolit_configuration_firewall_ufw() {

    # Check if firewall configuration in config file
    if [[ ${FIREWALL_UFW_STATUS} == "enabled" ]]; then

        # Check firewall status
        firewall_status

        exitstatus=$?
        if [[ ${exitstatus} -eq 1 ]]; then
            # Enabling firewall
            firewall_enable

        fi

        # Get all listed apps
        app_list="$(json_read_field "${server_config_file}" "FIREWALL.ufw[].config[]")"

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
    if [[ ${FIREWALL_UFW_STATUS} == "disabled" ]]; then

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

    if [[ ${is_mysql_installed} == "true" ]]; then

        mysql_ask_root_psw

    fi

}

################################################################################
# Check brolit configuration file
#
# Arguments:
#   $1 = ${server_config_file}
#
# Outputs:
#   nothing
################################################################################

function brolit_configuration_file_check() {

    local server_config_file="${1}"

    if [[ -f "${server_config_file}" ]]; then

        log_event "info" "Brolit config file found: ${server_config_file}" "true"

    else

        display --indent 2 --text "- Checking Brolit config file" --result "WARNING" --color YELLOW
        display --indent 4 --text "Config file not found!"

        # Creating new config file
        while true; do

            echo -e "${YELLOW}${ITALIC} > Do you want to create a new config file?${ENDCOLOR}"
            read -p "Please type 'y' or 'n'" yn

            case $yn in

            [Yy]*)

                cp "${BROLIT_MAIN_DIR}/config/brolit/brolit_conf.json" "${server_config_file}"

                log_event "critical" "Please, edit brolit_conf.json first, and then run the script again." "true"

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

}
function brolit_configuration_setup_check() {

    local server_config_file="${1}"

    declare -g DEBUG
    declare -g QUIET
    declare -g SKIPTESTS
    declare -g BROLIT_TMP_DIR

    # Check if is already defined
    if [[ -z ${DEBUG} ]]; then
        # Read required vars from server config file
        DEBUG="$(json_read_field "${server_config_file}" "BROLIT_SETUP.config[].debug")"

        if [ -z "${DEBUG}" ]; then
            echo "Missing required config vars"
            exit 1
        fi
    fi
    # Check if is already defined
    if [[ -z ${QUIET} ]]; then
        QUIET="$(json_read_field "${server_config_file}" "BROLIT_SETUP.config[].quiet")"

        if [ -z "${QUIET}" ]; then
            echo "Missing required config vars"
            exit 1
        fi
    fi
    # Check if is already defined
    if [[ -z ${SKIPTESTS} ]]; then
        SKIPTESTS="$(json_read_field "${server_config_file}" "BROLIT_SETUP.config[].skip_test")"

        if [ -z "${SKIPTESTS}" ]; then
            echo "Missing required config vars"
            exit 1
        fi
    fi
    # Check if is already defined
    if [[ -z ${CHECKPKGS} ]]; then
        CHECKPKGS="$(json_read_field "${server_config_file}" "BROLIT_SETUP.config[].check_packages")"

        if [ -z "${CHECKPKGS}" ]; then
            echo "Missing required config vars"
            exit 1
        fi
    fi
    # Check if is already defined
    if [[ -z ${BROLIT_TMP_DIR} ]]; then
        BROLIT_TMP_DIR="$(json_read_field "${server_config_file}" "BROLIT_SETUP.config[].tmp_dir")"

        if [[ -z ${BROLIT_TMP_DIR} ]]; then
            echo "Missing required config vars"
            exit 1
        fi

        # Check if $BROLIT_TMP_DIR starts with "/"
        if [[ ${BROLIT_TMP_DIR} != '/'* ]]; then
            BROLIT_TMP_DIR="${BROLIT_MAIN_DIR}/${BROLIT_TMP_DIR}"
        fi

        # Creating temporary folders
        if [[ ! -d ${BROLIT_TMP_DIR} ]]; then
            mkdir "${BROLIT_TMP_DIR}"
        fi
        if [[ ! -d "${BROLIT_TMP_DIR}/${NOW}" ]]; then
            mkdir "${BROLIT_TMP_DIR}/${NOW}"
        fi
    fi

    export DEBUG QUIET SKIPTESTS CHECKPKGS BROLIT_TMP_DIR

}
################################################################################
# Load Brolit configuration
#
# Arguments:
#   $1 = ${server_config_file}
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

    #### BACKUPS Method: duplicity
    _brolit_configuration_load_backup_duplicity "${server_config_file}"

    #### if all required vars are disabled, show error
    if [[ ${BACKUP_DROPBOX_STATUS} != "enabled" ]] && [[ ${BACKUP_SFTP_STATUS} != "enabled" ]] && [[ ${BACKUP_LOCAL_STATUS} != "enabled" ]]; then

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

    # TODO: need to implement BACKUPS.directories

    ## NOTIFICATIONS

    ### Email
    _brolit_configuration_load_email "${server_config_file}"

    ### Telegram
    _brolit_configuration_load_telegram "${server_config_file}"

    ## FIREWALL
    _brolit_configuration_load_firewall_ufw "${server_config_file}"
    _brolit_configuration_load_firewall_fail2ban "${server_config_file}"

    ## SUPPORT

    ### cloudflare
    _brolit_configuration_load_cloudflare "${server_config_file}"

    ## PACKAGES

    ### nginx
    _brolit_configuration_load_nginx "${server_config_file}"

    ### php-fpm
    _brolit_configuration_load_php "${server_config_file}"

    ### mariadb
    _brolit_configuration_load_mariadb "${server_config_file}"

    ### mysql
    _brolit_configuration_load_mysql "${server_config_file}"

    ### postgresql
    _brolit_configuration_load_postgres "${server_config_file}"

    # If Server role 'database' is enabled, mariadb or mysql must be enabled
    if [[ ${PACKAGES_MARIADB_STATUS} != "enabled" ]] && [[ ${PACKAGES_MYSQL_STATUS} != "enabled" ]] && [[ ${PACKAGES_POSTGRES_STATUS} != "enabled" ]] && [[ ${SERVER_ROLE_DATABASE} == "enabled" ]]; then
        log_event "warning" "No database engine is enabled" "true"
        exit 1
    fi

    ### redis
    _brolit_configuration_load_redis "${server_config_file}"

    ### certbot
    _brolit_configuration_load_certbot "${server_config_file}"

    ### monit
    _brolit_configuration_load_monit "${server_config_file}"

    ### docker
    _brolit_configuration_load_docker "${server_config_file}"

    ### netdata
    _brolit_configuration_load_netdata "${server_config_file}"

    ### cockpit
    _brolit_configuration_load_cockpit "${server_config_file}"

    ### zabbix
    _brolit_configuration_load_zabbix "${server_config_file}"

    ### portainer
    _brolit_configuration_load_portainer "${server_config_file}"

    ### mailcow
    _brolit_configuration_load_mailcow "${server_config_file}"

    ### custom
    _brolit_configuration_load_custom_pkgs "${server_config_file}"

    # Export vars
    export PROJECTS_PATH
    export SERVER_PREPARED

}
