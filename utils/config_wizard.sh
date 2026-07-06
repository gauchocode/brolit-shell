#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
################################################################################
#
# Config Wizard: Interactive configuration wizard for brolit_conf.json.
#
################################################################################

# shellcheck source=/root/brolit-shell/libs/local/proxmox_helper.sh
source "${BROLIT_MAIN_DIR}/libs/local/proxmox_helper.sh" 2>/dev/null || true

################################################################################
# Detect Proxmox VM and configure proxmox_mode
#
# Arguments:
#   ${1} = ${config_file}
#
# Outputs:
#   0 if Proxmox detected and configured, 1 otherwise
################################################################################

function config_wizard_detect_server_type() {

    local config_file="${1}"
    local server_type

    server_type="$(server_detect_type 2>/dev/null)"

    case "${server_type}" in

    "proxmox_node")
        log_event "info" "Proxmox VE node detected" "false"
        display --indent 6 --text "- Proxmox VE node detected" --result "DONE" --color GREEN
        display --indent 8 --text "This is the hypervisor. OpenResty should run inside a VM." --tcolor YELLOW

        json_write_field "${config_file}" "SERVER_CONFIG.proxmox_mode" "enabled"

        # Ask for OpenResty VM IP
        local openresty_vm_ip
        openresty_vm_ip="$(whiptail --inputbox "Enter OpenResty VM IP (default: 10.2.0.100):" 8 78 "10.2.0.100" 3>&1 1>&2 2>&3)"
        local exitstatus=$?

        if [[ ${exitstatus} -eq 0 ]] && [[ -n "${openresty_vm_ip}" ]]; then
            json_write_field "${config_file}" "SERVER_CONFIG.openresty_vm_ip" "${openresty_vm_ip}"
        fi

        # Ask for OpenResty VM password (optional)
        local openresty_vm_pass
        openresty_vm_pass="$(whiptail --passwordbox "Enter OpenResty VM root password (optional, leave empty for key auth):" 8 78 "" 3>&1 1>&2 2>&3)"
        exitstatus=$?

        if [[ ${exitstatus} -eq 0 ]] && [[ -n "${openresty_vm_pass}" ]]; then
            json_write_field "${config_file}" "SERVER_CONFIG.openresty_vm_pass" "${openresty_vm_pass}"
        fi
        ;;

    "proxmox_vm")
        log_event "info" "Proxmox VM detected, enabling proxmox_mode" "false"
        display --indent 6 --text "- Proxmox VM detected" --result "DONE" --color GREEN

        json_write_field "${config_file}" "SERVER_CONFIG.proxmox_mode" "enabled"

        # Ask if this VM will run OpenResty
        if whiptail_message_with_skip_option "OpenResty VM" "Is this VM the OpenResty reverse proxy?"; then
            display --indent 6 --text "- This VM will run OpenResty" --result "DONE" --color GREEN
            # No VM IP needed, OpenResty runs locally in this VM
            json_write_field "${config_file}" "SERVER_CONFIG.openresty_vm_ip" "127.0.0.1"
        else
            # Ask for OpenResty VM IP
            local proxmox_vm_ip
            proxmox_vm_ip="$(whiptail --inputbox "Enter OpenResty VM IP (default: 10.2.0.100):" 8 78 "10.2.0.100" 3>&1 1>&2 2>&3)"
            local exitstatus2=$?

            if [[ ${exitstatus2} -eq 0 ]] && [[ -n "${proxmox_vm_ip}" ]]; then
                json_write_field "${config_file}" "SERVER_CONFIG.openresty_vm_ip" "${proxmox_vm_ip}"
            fi
        fi
        ;;

    "vps")
        log_event "info" "VPS detected, using standard nginx mode" "false"
        display --indent 6 --text "- VPS detected" --result "DONE" --color GREEN
        json_write_field "${config_file}" "SERVER_CONFIG.proxmox_mode" "disabled"
        ;;

    "baremetal")
        log_event "info" "Bare metal server detected, using standard nginx mode" "false"
        display --indent 6 --text "- Bare metal server detected" --result "DONE" --color GREEN
        json_write_field "${config_file}" "SERVER_CONFIG.proxmox_mode" "disabled"
        ;;

    esac

    return 0

}

################################################################################
# Show current configuration
#
# Arguments:
#   ${1} = ${config_file}
#
# Outputs:
#   Formatted JSON to terminal
################################################################################

function config_wizard_show_current() {

    local config_file="${1}"

    if [[ ! -f "${config_file}" ]]; then
        display --indent 6 --text "- Config file not found" --result "FAIL" --color RED
        return 1
    fi

    log_section "Current Configuration"
    jq . "${config_file}"
    echo ""

    local version
    version="$(json_read_field "${config_file}" "BROLIT_SETUP.config[].version")"
    display --indent 6 --text "Config version: ${version}" --tcolor CYAN

}

################################################################################
# Apply a preset configuration
#
# Arguments:
#   ${1} = ${preset_name}
#   ${2} = ${config_file}
#
# Outputs:
#   Generates config file based on preset
#   0 if ok, 1 on error
################################################################################

function config_wizard_apply_preset() {

    local preset_name="${1}"
    local config_file="${2}"

    local config_template="${BROLIT_MAIN_DIR}/config/brolit/brolit_conf.json"

    # Start from template
    cp "${config_template}" "${config_file}"

    # Auto-detect server type on first run
    config_wizard_detect_server_type "${config_file}"

    case "${preset_name}" in

    "wordpress")
        # Server config
        json_write_field "${config_file}" "SERVER_CONFIG.type" "production"
        json_write_field "${config_file}" "SERVER_CONFIG.config[].webserver" "enabled"
        json_write_field "${config_file}" "SERVER_CONFIG.config[].database" "enabled"
        # Packages
        json_write_field "${config_file}" "PACKAGES.nginx[].status" "enabled"
        json_write_field "${config_file}" "PACKAGES.php[].status" "enabled"
        json_write_field "${config_file}" "PACKAGES.php[].version" "8.2"
        json_write_field "${config_file}" "PACKAGES.php[].extensions[].wpcli" "enabled"
        json_write_field "${config_file}" "PACKAGES.php[].extensions[].redis" "enabled"
        json_write_field "${config_file}" "PACKAGES.php[].extensions[].composer" "enabled"
        json_write_field "${config_file}" "PACKAGES.mariadb[].status" "enabled"
        json_write_field "${config_file}" "PACKAGES.redis[].status" "enabled"
        json_write_field "${config_file}" "PACKAGES.certbot[].status" "enabled"
        ;;

    "docker")
        # Server config
        json_write_field "${config_file}" "SERVER_CONFIG.type" "production"
        json_write_field "${config_file}" "SERVER_CONFIG.config[].webserver" "disabled"
        json_write_field "${config_file}" "SERVER_CONFIG.config[].database" "disabled"
        # Packages
        json_write_field "${config_file}" "PACKAGES.docker[].status" "enabled"
        json_write_field "${config_file}" "PACKAGES.portainer[].status" "enabled"
        ;;

    "minimal")
        # Server config only
        json_write_field "${config_file}" "SERVER_CONFIG.type" "production"
        json_write_field "${config_file}" "SERVER_CONFIG.config[].webserver" "disabled"
        json_write_field "${config_file}" "SERVER_CONFIG.config[].database" "disabled"
        ;;

    "monitoring")
        # Server config
        json_write_field "${config_file}" "SERVER_CONFIG.type" "production"
        json_write_field "${config_file}" "SERVER_CONFIG.config[].webserver" "disabled"
        json_write_field "${config_file}" "SERVER_CONFIG.config[].database" "disabled"
        # Packages
        json_write_field "${config_file}" "PACKAGES.netdata[].status" "enabled"
        json_write_field "${config_file}" "PACKAGES.netdata[].config[].web_admin" "enabled"
        json_write_field "${config_file}" "PACKAGES.grafana[].status" "enabled"
        json_write_field "${config_file}" "PACKAGES.loki[].status" "enabled"
        json_write_field "${config_file}" "PACKAGES.promtail[].status" "enabled"
        ;;

    *)
        log_event "error" "Unknown preset: ${preset_name}" "false"
        return 1
        ;;

    esac

    # Set timezone
    local timezone
    timezone="$(whiptail_input "Server Config" "Enter server timezone:" "America/Argentina/Buenos_Aires")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && -n "${timezone}" ]]; then
        json_write_field "${config_file}" "SERVER_CONFIG.timezone" "${timezone}"
    fi

    # Set email for certbot (if enabled)
    if [[ "${preset_name}" == "wordpress" || "${preset_name}" == "monitoring" ]]; then
        local email
        email="$(whiptail_input "Email Config" "Enter email for notifications/certbot:" "")"
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 && -n "${email}" ]]; then
            json_write_field "${config_file}" "PACKAGES.certbot[].config[].email" "${email}"
        fi
    fi

    # Validate
    if jq . "${config_file}" > /dev/null 2>&1; then
        display --indent 6 --text "- Preset '${preset_name}' applied" --result "DONE" --color GREEN
        return 0
    else
        display --indent 6 --text "- Error generating config" --result "FAIL" --color RED
        return 1
    fi

}

################################################################################
# Advanced configuration - section by section
#
# Arguments:
#   ${1} = ${config_file}
#
# Outputs:
#   Interactive wizard for each config section
#   0 if ok, 1 on error
################################################################################

function config_wizard_advanced() {

    local config_file="${1}"

    local config_template="${BROLIT_MAIN_DIR}/config/brolit/brolit_conf.json"

    # Start from template
    cp "${config_template}" "${config_file}"

    # Auto-detect server type on first run
    config_wizard_detect_server_type "${config_file}"

    log_section "Advanced Configuration"

    ## 1. Server Config
    log_subsection "Server Configuration"

    local server_type
    server_type="$(whiptail_selection_menu "Server Type" "Select server type:" "production development staging" "production")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        json_write_field "${config_file}" "SERVER_CONFIG.type" "${server_type}"
    fi

    local timezone
    timezone="$(whiptail_input "Server Config" "Enter server timezone:" "America/Argentina/Buenos_Aires")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 && -n "${timezone}" ]]; then
        json_write_field "${config_file}" "SERVER_CONFIG.timezone" "${timezone}"
    fi

    local webserver_status
    webserver_status="$(whiptail_selection_menu "Webserver Role" "Enable webserver role?" "enabled disabled" "disabled")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        json_write_field "${config_file}" "SERVER_CONFIG.config[].webserver" "${webserver_status}"
    fi

    local database_status
    database_status="$(whiptail_selection_menu "Database Role" "Enable database role?" "enabled disabled" "disabled")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        json_write_field "${config_file}" "SERVER_CONFIG.config[].database" "${database_status}"
    fi

    ## 2. Packages
    log_subsection "Packages Configuration"

    # Nginx
    local nginx_status
    nginx_status="$(whiptail_selection_menu "Nginx" "Install nginx?" "enabled disabled" "disabled")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        json_write_field "${config_file}" "PACKAGES.nginx[].status" "${nginx_status}"
    fi

    # PHP
    local php_status
    php_status="$(whiptail_selection_menu "PHP" "Install PHP?" "enabled disabled" "disabled")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        json_write_field "${config_file}" "PACKAGES.php[].status" "${php_status}"
        if [[ "${php_status}" == "enabled" ]]; then
            local php_version
            php_version="$(whiptail_input "PHP Version" "Enter PHP version (or 'default'):" "8.2")"
            exitstatus=$?
            if [[ ${exitstatus} -eq 0 && -n "${php_version}" ]]; then
                json_write_field "${config_file}" "PACKAGES.php[].version" "${php_version}"
            fi
        fi
    fi

    # Database engine
    local db_engine
    db_engine="$(whiptail_selection_menu "Database Engine" "Select database engine:" "mysql mariadb postgres disabled" "disabled")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        if [[ "${db_engine}" == "disabled" ]]; then
            json_write_field "${config_file}" "PACKAGES.mysql[].status" "disabled"
            json_write_field "${config_file}" "PACKAGES.mariadb[].status" "disabled"
            json_write_field "${config_file}" "PACKAGES.postgres[].status" "disabled"
        elif [[ "${db_engine}" == "mysql" ]]; then
            json_write_field "${config_file}" "PACKAGES.mysql[].status" "enabled"
            json_write_field "${config_file}" "PACKAGES.mariadb[].status" "disabled"
            json_write_field "${config_file}" "PACKAGES.postgres[].status" "disabled"
        elif [[ "${db_engine}" == "mariadb" ]]; then
            json_write_field "${config_file}" "PACKAGES.mysql[].status" "disabled"
            json_write_field "${config_file}" "PACKAGES.mariadb[].status" "enabled"
            json_write_field "${config_file}" "PACKAGES.postgres[].status" "disabled"
        elif [[ "${db_engine}" == "postgres" ]]; then
            json_write_field "${config_file}" "PACKAGES.mysql[].status" "disabled"
            json_write_field "${config_file}" "PACKAGES.mariadb[].status" "disabled"
            json_write_field "${config_file}" "PACKAGES.postgres[].status" "enabled"
        fi
    fi

    # Redis
    local redis_status
    redis_status="$(whiptail_selection_menu "Redis" "Install Redis?" "enabled disabled" "disabled")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        json_write_field "${config_file}" "PACKAGES.redis[].status" "${redis_status}"
    fi

    # Docker
    local docker_status
    docker_status="$(whiptail_selection_menu "Docker" "Install Docker?" "enabled disabled" "disabled")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        json_write_field "${config_file}" "PACKAGES.docker[].status" "${docker_status}"
    fi

    ## 3. Certbot
    log_subsection "SSL/Certbot"

    local certbot_status
    certbot_status="$(whiptail_selection_menu "Certbot" "Install Certbot (Let's Encrypt)?" "enabled disabled" "disabled")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        json_write_field "${config_file}" "PACKAGES.certbot[].status" "${certbot_status}"
        if [[ "${certbot_status}" == "enabled" ]]; then
            local certbot_email
            certbot_email="$(whiptail_input "Certbot Email" "Enter email for Certbot:" "")"
            exitstatus=$?
            if [[ ${exitstatus} -eq 0 && -n "${certbot_email}" ]]; then
                json_write_field "${config_file}" "PACKAGES.certbot[].config[].email" "${certbot_email}"
            fi
        fi
    fi

    ## 4. Backups
    log_subsection "Backup Configuration"

    local backup_method
    backup_method="$(whiptail_selection_menu "Backup Method" "Select backup method:" "local sftp borg dropbox disabled" "disabled")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        # Disable all methods first
        json_write_field "${config_file}" "BACKUPS.methods[].local[].status" "disabled"
        json_write_field "${config_file}" "BACKUPS.methods[].sftp[].status" "disabled"
        json_write_field "${config_file}" "BACKUPS.methods[].borg[].status" "disabled"
        json_write_field "${config_file}" "BACKUPS.methods[].dropbox[].status" "disabled"

        if [[ "${backup_method}" != "disabled" ]]; then
            json_write_field "${config_file}" "BACKUPS.methods[].${backup_method}[].status" "enabled"

            # Method-specific config
            if [[ "${backup_method}" == "local" ]]; then
                local backup_path
                backup_path="$(whiptail_input "Backup Path" "Enter backup path:" "/mnt/backup")"
                exitstatus=$?
                if [[ ${exitstatus} -eq 0 && -n "${backup_path}" ]]; then
                    json_write_field "${config_file}" "BACKUPS.methods[].local[].config[].backup_path" "${backup_path}"
                fi
            fi
        fi
    fi

    ## 5. Notifications
    log_subsection "Notifications"

    local notif_method
    notif_method="$(whiptail_selection_menu "Notification Method" "Select notification method:" "email telegram discord ntfy disabled" "disabled")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        # Disable all methods first
        json_write_field "${config_file}" "NOTIFICATIONS.email[].status" "disabled"
        json_write_field "${config_file}" "NOTIFICATIONS.telegram[].status" "disabled"
        json_write_field "${config_file}" "NOTIFICATIONS.discord[].status" "disabled"
        json_write_field "${config_file}" "NOTIFICATIONS.ntfy[].status" "disabled"

        if [[ "${notif_method}" != "disabled" ]]; then
            json_write_field "${config_file}" "NOTIFICATIONS.${notif_method}[].status" "enabled"
        fi
    fi

    ## 6. DNS/Cloudflare
    log_subsection "DNS/Cloudflare"

    local cf_status
    cf_status="$(whiptail_selection_menu "Cloudflare" "Enable Cloudflare integration?" "enabled disabled" "disabled")"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        json_write_field "${config_file}" "DNS.cloudflare[].status" "${cf_status}"
        if [[ "${cf_status}" == "enabled" ]]; then
            local cf_email
            cf_email="$(whiptail_input "Cloudflare Email" "Enter Cloudflare email:" "")"
            exitstatus=$?
            if [[ ${exitstatus} -eq 0 && -n "${cf_email}" ]]; then
                json_write_field "${config_file}" "DNS.cloudflare[].config[].email" "${cf_email}"
            fi

            local cf_api_key
            cf_api_key="$(whiptail_input "Cloudflare API Key" "Enter Cloudflare API key:" "")"
            exitstatus=$?
            if [[ ${exitstatus} -eq 0 && -n "${cf_api_key}" ]]; then
                json_write_field "${config_file}" "DNS.cloudflare[].config[].api_key" "${cf_api_key}"
            fi
        fi
    fi

    # Validate final result
    if jq . "${config_file}" > /dev/null 2>&1; then
        display --indent 6 --text "- Advanced configuration completed" --result "DONE" --color GREEN
        return 0
    else
        display --indent 6 --text "- Error in configuration" --result "FAIL" --color RED
        return 1
    fi

}

################################################################################
# Configuration wizard main menu
#
# Arguments:
#   none
#
# Outputs:
#   Interactive wizard
#   0 if ok, 1 on error
################################################################################

function config_wizard_menu() {

    local config_file="${BROLIT_CONFIG_FILE:-~/.brolit_conf.json}"

    local wizard_options
    local chosen_option

    wizard_options=(
        "1)" "Quick setup (presets)"
        "2)" "Advanced setup (section by section)"
        "3)" "Show current config"
        "4)" "Exit"
    )

    log_section "Configuration Wizard"

    while true; do

        chosen_option="$(whiptail --title "CONFIGURATION WIZARD" --menu "Select an option:" 20 78 10 "${wizard_options[@]}" 3>&1 1>&2 2>&3)"
        exitstatus=$?

        if [[ ${exitstatus} -ne 0 ]]; then
            return 1
        fi

        # Quick setup (presets)
        if [[ "${chosen_option}" == *"1)"* ]]; then

            local preset_options
            local chosen_preset

            preset_options=(
                "1)" "WordPress Server (nginx+php+mysql+redis+certbot)"
                "2)" "Docker Server (docker+portainer)"
                "3)" "Monitoring (netdata+grafana+loki)"
                "4)" "Minimal (server config only)"
            )

            chosen_preset="$(whiptail --title "SELECT PRESET" --menu "Choose a configuration preset:" 20 78 10 "${preset_options[@]}" 3>&1 1>&2 2>&3)"
            exitstatus=$?

            if [[ ${exitstatus} -eq 0 ]]; then

                local preset_name
                if [[ "${chosen_preset}" == *"1)"* ]]; then
                    preset_name="wordpress"
                elif [[ "${chosen_preset}" == *"2)"* ]]; then
                    preset_name="docker"
                elif [[ "${chosen_preset}" == *"3)"* ]]; then
                    preset_name="monitoring"
                elif [[ "${chosen_preset}" == *"4)"* ]]; then
                    preset_name="minimal"
                fi

                config_wizard_apply_preset "${preset_name}" "${config_file}"
                exitstatus=$?

                if [[ ${exitstatus} -eq 0 ]]; then
                    display --indent 6 --text "- Config saved to: ${config_file}" --result "DONE" --color GREEN
                    whiptail_message "Config Wizard" "Configuration completed successfully!\n\nYou can now run brolit-shell normally."
                    return 0
                fi

            fi

        fi

        # Advanced setup
        if [[ "${chosen_option}" == *"2)"* ]]; then

            config_wizard_advanced "${config_file}"
            exitstatus=$?

            if [[ ${exitstatus} -eq 0 ]]; then
                display --indent 6 --text "- Config saved to: ${config_file}" --result "DONE" --color GREEN
                whiptail_message "Config Wizard" "Advanced configuration completed!\n\nYou can now run brolit-shell normally."
                return 0
            fi

        fi

        # Show current config
        if [[ "${chosen_option}" == *"3)"* ]]; then

            config_wizard_show_current "${config_file}"

        fi

        # Exit
        if [[ "${chosen_option}" == *"4)"* ]]; then
            return 0
        fi

    done

}
