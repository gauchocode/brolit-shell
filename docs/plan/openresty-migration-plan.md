# OpenResty Migration Plan

## Overview

Replace Nginx Proxy Manager (NPM) with OpenResty + Lua API, integrated into brolit-shell with Proxmox VM detection.

## Architecture

```
Proxmox Host (213.199.58.220)
  DNAT :80/:443/:8080
    |
    v
VM 101 (10.2.0.101) - OpenResty + API
    |
    +--> VM 100 (10.2.0.100) - Docker containers (brolit managed)
    +--> VM 102 (10.2.0.102) - Docker containers (brolit managed)
    +--> VM 104 (10.2.0.104) - Docker containers (brolit managed)
```

## Files to Create

### 1. `libs/local/proxmox_helper.sh` - Proxmox detection and utilities

```bash
#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
################################################################################
#
# Proxmox Helper: Detection and utilities for Proxmox VE environments.
#
################################################################################

################################################################################
# Detect if running inside a Proxmox VM
#
# Arguments:
#   none
#
# Outputs:
#   0 if Proxmox VM detected, 1 otherwise
################################################################################

function proxmox_detect() {

    local vendor

    # Check DMI vendor (QEMU/KVM for Proxmox)
    if [[ -f /sys/class/dmi/id/sys_vendor ]]; then
        vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)"
        if [[ "${vendor}" == *"QEMU"* ]] || [[ "${vendor}" == *"Proxmox"* ]]; then
            return 0
        fi
    fi

    # Check for cloud-init (common in Proxmox VMs)
    if [[ -f /etc/cloud/cloud.cfg ]]; then
        return 0
    fi

    return 1

}

################################################################################
# Get Proxmox host IP (default gateway)
#
# Arguments:
#   none
#
# Outputs:
#   Gateway IP address
################################################################################

function proxmox_get_host_ip() {

    ip route | grep default | awk '{print $3}')

}

################################################################################
# Get public IP (from Proxmox host perspective)
#
# Arguments:
#   none
#
# Outputs:
#   Public IP address
################################################################################

function proxmox_get_public_ip() {

    curl -s --connect-timeout 3 http://ipv4.icanhazip.com 2>/dev/null

}

################################################################################
# Detect if Nginx Proxy Manager is running on Proxmox host
#
# Arguments:
#   none
#
# Outputs:
#   0 if NPM detected, 1 otherwise
################################################################################

function proxmox_npm_detect() {

    local host_ip
    local npm_status

    host_ip="$(proxmox_get_host_ip)"
    npm_status="$(curl -s -o /dev/null -w "%{http_code}" "http://${host_ip}:81" 2>/dev/null)"

    if [[ "${npm_status}" == "200" ]]; then
        return 0
    fi

    return 1

}

################################################################################
# Check if OpenResty is installed
#
# Arguments:
#   none
#
# Outputs:
#   0 if installed, 1 otherwise
################################################################################

function openresty_is_installed() {

    command -v openresty &>/dev/null

}

################################################################################
# Check if nginx is installed (not OpenResty)
#
# Arguments:
#   none
#
# Outputs:
#   0 if nginx installed (and not OpenResty), 1 otherwise
################################################################################

function nginx_is_installed() {

    if openresty_is_installed; then
        return 1
    fi
    command -v nginx &>/dev/null

}

################################################################################
# Get current proxy status
#
# Arguments:
#   none
#
# Outputs:
#   "openresty", "nginx", or "none"
################################################################################

function proxy_get_status() {

    if openresty_is_installed; then
        echo "openresty"
    elif nginx_is_installed; then
        echo "nginx"
    else
        echo "none"
    fi

}
```

### 2. `utils/installers/openresty_installer.sh` - OpenResty installer

```bash
#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
################################################################################
#
# OpenResty Installer: Install and configure OpenResty with Lua API.
#
################################################################################

################################################################################
# OpenResty installer
#
# Arguments:
#   ${1} = ${install_method} (optional, default: "apt")
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_installer() {

    local install_method="${1:-apt}"

    if openresty_is_installed; then
        log_event "info" "OpenResty is already installed" "false"
        return 0
    fi

    log_subsection "OpenResty Installer"

    if [[ "${install_method}" == "official" ]]; then
        # Install from official OpenResty repos
        apt-get install -y --no-install-recommends \
            gnupg2 ca-certificates lsb-release debian-archive-keyring

        curl -1sLf 'https://openresty.org/package/pubkey.gpg' | \
            gpg --dearmor -o /usr/share/keyrings/openresty.gpg

        echo "deb [signed-by=/usr/share/keyrings/openresty.gpg] \
            http://openresty.org/package/ubuntu $(lsb_release -sc) main" | \
            tee /etc/apt/sources.list.d/openresty.list

        apt-get update
        apt-get install -y openresty
    else
        # Install from Ubuntu repos
        apt-get update
        apt-get install -y openresty
    fi

    # Create required directories
    mkdir -p /usr/local/openresty/nginx/conf/sites-available
    mkdir -p /usr/local/openresty/nginx/conf/sites-enabled
    mkdir -p /usr/local/openresty/nginx/conf/api
    mkdir -p /usr/local/openresty/nginx/conf/globals

    # Copy base config from brolit
    cp "${BROLIT_MAIN_DIR}/config/nginx/nginx.conf" \
        "/usr/local/openresty/nginx/conf/nginx.conf"
    cp "${BROLIT_MAIN_DIR}/config/nginx/mime.types" \
        "/usr/local/openresty/nginx/conf/mime.types"

    # Copy globals
    cp -r "${BROLIT_MAIN_DIR}/config/nginx/globals/"* \
        "/usr/local/openresty/nginx/conf/globals/" 2>/dev/null || true

    # Copy Lua API module
    mkdir -p "${BROLIT_MAIN_DIR}/config/openresty/api"
    cp "${BROLIT_MAIN_DIR}/config/openresty/api/routes.lua" \
        "/usr/local/openresty/nginx/conf/api/"
    cp "${BROLIT_MAIN_DIR}/config/openresty/api/nginx.conf.lua" \
        "/usr/local/openresty/nginx/conf/api/"

    # Create systemd service
    _openresty_create_systemd_service

    log_event "info" "OpenResty installed successfully" "false"

}

################################################################################
# Create systemd service for OpenResty
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function _openresty_create_systemd_service() {

    cat > /etc/systemd/system/openresty.service << 'EOF'
[Unit]
Description=The OpenResty Application Platform
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/usr/local/openresty/nginx/logs/nginx.pid
ExecStartPre=/usr/local/openresty/bin/openresty -t
ExecStart=/usr/local/openresty/bin/openresty
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable openresty

}

################################################################################
# OpenResty purge
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_purge() {

    log_event "info" "Uninstalling OpenResty..." "false"

    systemctl stop openresty 2>/dev/null
    systemctl disable openresty 2>/dev/null
    rm -f /etc/systemd/system/openresty.service

    apt-get purge -y openresty
    apt-get autoremove -y

    log_event "info" "OpenResty uninstalled" "false"

}

################################################################################
# OpenResty installer menu
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function openresty_installer_menu() {

    local openresty_installer_options
    local chosen_openresty_installer_option

    if openresty_is_installed; then

        openresty_installer_options=(
            "01)" "UNINSTALL OPENRESTY"
            "02)" "RECONFIGURE OPENRESTY"
        )

        chosen_openresty_installer_option="$(whiptail --title "OPENRESTY INSTALLER" --menu "Choose an option" 20 78 10 "${openresty_installer_options[@]}" 3>&1 1>&2 2>&3)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_openresty_installer_option} == *"01"* ]]; then
                log_subsection "OpenResty Installer"
                openresty_purge
            fi

            if [[ ${chosen_openresty_installer_option} == *"02"* ]]; then
                log_subsection "OpenResty Installer"
                openresty_reconfigure
            fi

        fi

    else

        openresty_installer_options=(
            "01)" "INSTALL OPENRESTY (APT)"
            "02)" "INSTALL OPENRESTY (OFFICIAL REPO)"
        )

        chosen_openresty_installer_option="$(whiptail --title "OPENRESTY INSTALLER" --menu "Choose a version to install" 20 78 10 "${openresty_installer_options[@]}" 3>&1 1>&2 2>&3)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            if [[ ${chosen_openresty_installer_option} == *"01"* ]]; then
                log_subsection "OpenResty Installer"
                openresty_installer "apt"
                openresty_reconfigure
            fi

            if [[ ${chosen_openresty_installer_option} == *"02"* ]]; then
                log_subsection "OpenResty Installer"
                openresty_installer "official"
                openresty_reconfigure
            fi

        fi

    fi

}

################################################################################
# Reconfigure OpenResty
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_reconfigure() {

    local openresty_conf="/usr/local/openresty/nginx/conf"

    # Copy main config
    cp "${BROLIT_MAIN_DIR}/config/nginx/nginx.conf" \
        "${openresty_conf}/nginx.conf"
    display --indent 6 --text "- Updating openresty nginx.conf" --result "DONE" --color GREEN

    # Copy mime.types
    cp "${BROLIT_MAIN_DIR}/config/nginx/mime.types" \
        "${openresty_conf}/mime.types"
    display --indent 6 --text "- Updating openresty mime.types" --result "DONE" --color GREEN

    # Ensure directories exist
    mkdir -p "${openresty_conf}/sites-available"
    mkdir -p "${openresty_conf}/sites-enabled"
    mkdir -p "${openresty_conf}/globals"

    # Copy globals
    cp -r "${BROLIT_MAIN_DIR}/config/nginx/globals/"* \
        "${openresty_conf}/globals/" 2>/dev/null || true

    # Test and reload
    openresty_configuration_test

}
```

### 3. `libs/apps/openresty_helper.sh` - OpenResty helper functions

```bash
#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
################################################################################
#
# OpenResty Helper: Perform openresty actions via Lua API.
#
################################################################################

################################################################################
# Get OpenResty config directory
#
# Arguments:
#   none
#
# Outputs:
#   Config directory path
################################################################################

function openresty_get_conf_dir() {

    echo "/usr/local/openresty/nginx/conf"

}

################################################################################
# Test OpenResty configuration
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_configuration_test() {

    local result

    result="$(openresty -t 2>&1 | grep -w "test" | cut -d"." -f2 | cut -d" " -f4)"

    if [[ "${result}" == "successful" ]]; then

        # Reload webserver
        openresty -s reload

        # Log
        log_event "info" "OpenResty configuration test passed" "false"
        display --indent 6 --text "- Testing openresty configuration" --result "DONE" --color GREEN

        return 0

    else

        local debug
        debug="$(openresty -t 2>&1)"
        whiptail_message "WARNING" "Something went wrong changing OpenResty configuration. Please check manually."

        # Log
        log_event "error" "OpenResty configuration test failed. Debug: ${debug}"
        display --indent 6 --text "- Testing openresty configuration" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Create OpenResty server config via Lua API
#
# Arguments:
#   ${1} = ${project_domain}
#   ${2} = ${project_type} (wordpress, proxy, php, etc.)
#   ${3} = ${server_type} (single, root_domain)
#   ${4} = ${redirect_domains} (optional)
#   ${5} = ${proxy_port} (optional)
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_server_create() {

    local project_domain="${1}"
    local project_type="${2}"
    local server_type="${3}"
    local redirect_domains="${4}"
    local proxy_port="${5}"

    local api_url="http://localhost:8080/api/routes"
    local json_data

    log_event "info" "Creating openresty config for domain: ${project_domain}" "false"

    # Build JSON payload
    json_data="{\"domain\":\"${project_domain}\",\"type\":\"${project_type}\""

    if [[ -n "${proxy_port}" ]]; then
        json_data="${json_data},\"proxy_port\":\"${proxy_port}\""
    fi

    if [[ -n "${redirect_domains}" ]]; then
        json_data="${json_data},\"redirect_domains\":\"${redirect_domains}\""
    fi

    json_data="${json_data}}"

    # Call Lua API
    local result
    result="$(curl -s -X POST "${api_url}" \
        -H "Content-Type: application/json" \
        -d "${json_data}" 2>/dev/null)"

    if echo "${result}" | grep -q '"success":true'; then
        display --indent 6 --text "- Creating openresty server config" --result "DONE" --color GREEN
        return 0
    else
        display --indent 6 --text "- Creating openresty server config" --result "FAIL" --color RED
        log_event "error" "Failed to create openresty config: ${result}" "false"
        return 1
    fi

}

################################################################################
# Delete OpenResty server config via Lua API
#
# Arguments:
#   ${1} = ${project_domain}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_server_delete() {

    local project_domain="${1}"

    local api_url="http://localhost:8080/api/routes/${project_domain}"

    log_event "info" "Deleting openresty config for domain: ${project_domain}" "false"

    local result
    result="$(curl -s -X DELETE "${api_url}" 2>/dev/null)"

    if echo "${result}" | grep -q '"success":true'; then
        display --indent 6 --text "- Deleting openresty server config" --result "DONE" --color GREEN
        return 0
    else
        display --indent 6 --text "- Deleting openresty server config" --result "FAIL" --color RED
        log_event "error" "Failed to delete openresty config: ${result}" "false"
        return 1
    fi

}

################################################################################
# Change OpenResty server status (online/offline)
#
# Arguments:
#   ${1} = ${project_domain}
#   ${2} = ${project_status} (online, offline)
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_server_change_status() {

    local project_domain="${1}"
    local project_status="${2}"

    local conf_dir
    conf_dir="$(openresty_get_conf_dir)"

    case ${project_status} in

    online)

        log_event "info" "New project status: ${project_status}" "false"

        if [[ -f "${conf_dir}/sites-available/${project_domain}" ]]; then
            ln -s "${conf_dir}/sites-available/${project_domain}" \
                "${conf_dir}/sites-enabled/${project_domain}"
            log_event "info" "Project config added to sites-enabled" "false"
            display --indent 6 --text "- Changing project status to ONLINE" --result "DONE" --color GREEN
        else
            log_event "error" "${conf_dir}/sites-available/${project_domain} does not exist" "false"
            display --indent 6 --text "- Changing project status to ONLINE" --result "FAIL" --color RED
        fi
        ;;

    offline)

        log_event "info" "New project status: ${project_status}" "false"

        if [[ -L "${conf_dir}/sites-enabled/${project_domain}" ]]; then
            rm "${conf_dir}/sites-enabled/${project_domain}"
            log_event "info" "Project config deleted from sites-enabled" "false"
            display --indent 6 --text "- Changing project status to OFFLINE" --result "DONE" --color GREEN
        else
            log_event "error" "${conf_dir}/sites-enabled/${project_domain} does not exist" "false"
            display --indent 6 --text "- Changing project status to OFFLINE" --result "FAIL" --color RED
        fi
        ;;

    *)
        log_event "info" "New project status: Unknown" "false"
        return 1
        ;;

    esac

    # Test configuration
    openresty_configuration_test

}

################################################################################
# List all OpenResty routes via Lua API
#
# Arguments:
#   none
#
# Outputs:
#   JSON array of routes
################################################################################

function openresty_list_routes() {

    curl -s http://localhost:8080/api/routes 2>/dev/null

}

################################################################################
# Get OpenResty API status
#
# Arguments:
#   none
#
# Outputs:
#   JSON status object
################################################################################

function openresty_api_status() {

    curl -s http://localhost:8080/api/status 2>/dev/null

}
```

### 4. `libs/local/npm_migration_helper.sh` - NPM migration helper

```bash
#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
################################################################################
#
# NPM Migration Helper: Migrate from Nginx Proxy Manager to OpenResty.
#
################################################################################

################################################################################
# Download NPM configs via API
#
# Arguments:
#   ${1} = ${npm_host}
#   ${2} = ${npm_port} (optional, default: 81)
#   ${3} = ${npm_token} (optional, for auth)
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function npm_download_configs() {

    local npm_host="${1}"
    local npm_port="${2:-81}"
    local npm_token="${3:-}"

    local auth_header=""

    if [[ -n "${npm_token}" ]]; then
        auth_header="-H \"Authorization: Bearer ${npm_token}\""
    fi

    log_event "info" "Downloading configs from NPM at ${npm_host}:${npm_port}" "false"

    # Get proxy hosts
    eval curl -s "http://${npm_host}:${npm_port}/api/nginx/proxy-hosts" \
        ${auth_header} \
        -o /tmp/npm_proxy_hosts.json

    # Get certificates
    eval curl -s "http://${npm_host}:${npm_port}/api/nginx/certificates" \
        ${auth_header} \
        -o /tmp/npm_certificates.json

    # Get redirection hosts
    eval curl -s "http://${npm_host}:${npm_port}/api/nginx/redirection-hosts" \
        ${auth_header} \
        -o /tmp/npm_redirections.json

    log_event "info" "NPM configs downloaded" "false"

}

################################################################################
# Generate nginx config from NPM proxy host data
#
# Arguments:
#   ${1} = ${domain}
#   ${2} = ${forward_host}
#   ${3} = ${forward_port}
#   ${4} = ${ssl_enabled}
#   ${5} = ${websocket_enabled}
#   ${6} = ${advanced_config}
#
# Outputs:
#   nginx config content
################################################################################

function npm_generate_nginx_config() {

    local domain="${1}"
    local forward_host="${2}"
    local forward_port="${3}"
    local ssl_enabled="${4}"
    local websocket_enabled="${5}"
    local advanced_config="${6}"

    local template
    local config

    if [[ "${ssl_enabled}" == "true" ]]; then
        template="${BROLIT_MAIN_DIR}/config/nginx/sites-available/proxy_single_ssl"
        # Fallback to proxy_single if ssl template doesn't exist
        [[ ! -f "${template}" ]] && template="${BROLIT_MAIN_DIR}/config/nginx/sites-available/proxy_single"
    else
        template="${BROLIT_MAIN_DIR}/config/nginx/sites-available/proxy_single"
    fi

    config="$(cat "${template}")"

    # Replace placeholders
    config="$(echo "${config}" | sed "s/domain.com/${domain}/g")"
    config="$(echo "${config}" | sed "s/PROXY_PORT/${forward_port}/g")"

    # Remove WebSocket headers if not enabled
    if [[ "${websocket_enabled}" != "true" ]]; then
        config="$(echo "${config}" | grep -v "Upgrade\|connection_upgrade")"
    fi

    # Add advanced config if present
    if [[ -n "${advanced_config}" ]]; then
        config="$(echo "${config}" | sed "/location \/ {/a\\
\\    ${advanced_config}")"
    fi

    echo "${config}"

}

################################################################################
# Migrate all proxy hosts from NPM
#
# Arguments:
#   ${1} = ${npm_host}
#   ${2} = ${npm_port} (optional, default: 81)
#   ${3} = ${npm_token} (optional)
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function npm_migrate_all() {

    local npm_host="${1}"
    local npm_port="${2:-81}"
    local npm_token="${3:-}"

    log_section "NPM Migration"

    # Download configs
    npm_download_configs "${npm_host}" "${npm_port}" "${npm_token}"

    # Check if proxy hosts exist
    if [[ ! -f /tmp/npm_proxy_hosts.json ]]; then
        log_event "error" "Failed to download NPM configs" "false"
        return 1
    fi

    local proxy_count
    proxy_count="$(jq '.data | length' /tmp/npm_proxy_hosts.json 2>/dev/null)"

    if [[ "${proxy_count}" -eq 0 ]]; then
        log_event "warning" "No proxy hosts found in NPM" "false"
        return 0
    fi

    log_event "info" "Found ${proxy_count} proxy hosts to migrate" "false"

    local conf_dir
    conf_dir="$(openresty_get_conf_dir)"

    # Process each proxy host
    local i=0
    while [[ ${i} -lt ${proxy_count} ]]; do

        local host_data
        host_data="$(jq -c ".data[${i}]" /tmp/npm_proxy_hosts.json)"

        local domain
        local forward_host
        local forward_port
        local ssl_enabled
        local websocket
        local advanced

        domain="$(echo "${host_data}" | jq -r '.domain_names[0]')"
        forward_host="$(echo "${host_data}" | jq -r '.forward_host')"
        forward_port="$(echo "${host_data}" | jq -r '.forward_port')"
        ssl_enabled="$(echo "${host_data}" | jq -r '.ssl_enabled')"
        websocket="$(echo "${host_data}" | jq -r '.allow_websocket_upgrade')"
        advanced="$(echo "${host_data}" | jq -r '.advanced_config')"

        log_event "info" "Migrating: ${domain} -> ${forward_host}:${forward_port}" "false"

        # Generate config
        local config
        config="$(npm_generate_nginx_config \
            "${domain}" "${forward_host}" "${forward_port}" \
            "${ssl_enabled}" "${websocket}" "${advanced}")"

        # Save config
        local config_file="${conf_dir}/sites-available/${domain}"
        echo "${config}" > "${config_file}"

        # Create symlink
        ln -sf "${config_file}" "${conf_dir}/sites-enabled/${domain}"

        # Migrate SSL certificate if enabled
        if [[ "${ssl_enabled}" == "true" ]]; then
            _npm_migrate_ssl_certificate "${domain}" "${host_data}"
        fi

        display --indent 4 --text "- Migrated: ${domain}" --result "DONE" --color GREEN

        i=$((i + 1))

    done

    # Test and reload OpenResty
    openresty_configuration_test

    log_event "info" "Migration completed: ${proxy_count} hosts migrated" "false"

}

################################################################################
# Migrate SSL certificate from NPM
#
# Arguments:
#   ${1} = ${domain}
#   ${2} = ${host_data} (JSON from NPM)
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function _npm_migrate_ssl_certificate() {

    local domain="${1}"
    local host_data="${2}"

    local cert_id
    cert_id="$(echo "${host_data}" | jq -r '.certificate_id')"

    if [[ "${cert_id}" != "null" ]] && [[ -n "${cert_id}" ]]; then

        local npm_host="${NPM_HOST:-localhost}"
        local npm_port="${NPM_PORT:-81}"
        local npm_token="${NPM_TOKEN:-}"

        local auth_header=""
        if [[ -n "${npm_token}" ]]; then
            auth_header="-H \"Authorization: Bearer ${npm_token}\""
        fi

        # Get certificate from NPM
        local cert_data
        eval cert_data="$(curl -s \
            "http://${npm_host}:${npm_port}/api/nginx/certificates/${cert_id}" \
            ${auth_header})"

        local cert
        local key
        cert="$(echo "${cert_data}" | jq -r '.certificate')"
        key="$(echo "${cert_data}" | jq -r '.certificate_key')"

        if [[ -n "${cert}" ]] && [[ "${cert}" != "null" ]]; then
            # Create directory
            mkdir -p "/etc/letsencrypt/live/${domain}"

            # Save certificates
            echo "${cert}" > "/etc/letsencrypt/live/${domain}/fullchain.pem"
            echo "${key}" > "/etc/letsencrypt/live/${domain}/privkey.pem"

            log_event "info" "SSL certificate migrated for ${domain}" "false"
        fi

    fi

}

################################################################################
# Migrate single domain from NPM
#
# Arguments:
#   ${1} = ${domain}
#   ${2} = ${npm_host}
#   ${3} = ${npm_port} (optional)
#   ${4} = ${npm_token} (optional)
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function npm_migrate_domain() {

    local domain="${1}"
    local npm_host="${2}"
    local npm_port="${3:-81}"
    local npm_token="${4:-}"

    log_event "info" "Migrating single domain: ${domain}" "false"

    # Download configs
    npm_download_configs "${npm_host}" "${npm_port}" "${npm_token}"

    # Find domain in proxy hosts
    local host_data
    host_data="$(jq -c ".data[] | select(.domain_names[0] == \"${domain}\")" /tmp/npm_proxy_hosts.json 2>/dev/null)"

    if [[ -z "${host_data}" ]]; then
        log_event "error" "Domain ${domain} not found in NPM" "false"
        return 1
    fi

    local forward_host
    local forward_port
    local ssl_enabled
    local websocket
    local advanced

    forward_host="$(echo "${host_data}" | jq -r '.forward_host')"
    forward_port="$(echo "${host_data}" | jq -r '.forward_port')"
    ssl_enabled="$(echo "${host_data}" | jq -r '.ssl_enabled')"
    websocket="$(echo "${host_data}" | jq -r '.allow_websocket_upgrade')"
    advanced="$(echo "${host_data}" | jq -r '.advanced_config')"

    local conf_dir
    conf_dir="$(openresty_get_conf_dir)"

    # Generate config
    local config
    config="$(npm_generate_nginx_config \
        "${domain}" "${forward_host}" "${forward_port}" \
        "${ssl_enabled}" "${websocket}" "${advanced}")"

    # Save config
    local config_file="${conf_dir}/sites-available/${domain}"
    echo "${config}" > "${config_file}"

    # Create symlink
    ln -sf "${config_file}" "${conf_dir}/sites-enabled/${domain}"

    # Migrate SSL if enabled
    if [[ "${ssl_enabled}" == "true" ]]; then
        _npm_migrate_ssl_certificate "${domain}" "${host_data}"
    fi

    # Test and reload
    openresty_configuration_test

    display --indent 4 --text "- Migrated: ${domain}" --result "DONE" --color GREEN

}
```

### 5. `config/openresty/api/routes.lua` - Lua API module

```lua
-- Routes API module for OpenResty
-- Provides REST API for managing nginx routes

local cjson = require "cjson"
local io = require "io"
local os = require "os"

local _M = {}

-- Config paths
local SITES_AVAILABLE = "/usr/local/openresty/nginx/conf/sites-available"
local SITES_ENABLED = "/usr/local/openresty/nginx/conf/sites-enabled"

-- Execute shell command and return output
local function shell(cmd)
    local handle = io.popen(cmd, "r")
    if not handle then return "" end
    local result = handle:read("*a")
    handle:close()
    return result
end

-- List all routes
function _M.list_routes()
    local routes = {}
    local output = shell("ls " .. SITES_AVAILABLE .. " 2>/dev/null")
    for domain in output:gmatch("[^\r\n]+") do
        if domain ~= "" and not domain:match("%.backup$") then
            local enabled = shell("test -L " .. SITES_ENABLED .. "/" .. domain .. " && echo true || echo false")
            table.insert(routes, {
                domain = domain,
                enabled = enabled:gsub("%s+", "") == "true"
            })
        end
    end
    return cjson.encode(routes)
end

-- Get single route
function _M.get_route(domain)
    local config_path = SITES_AVAILABLE .. "/" .. domain
    local f = io.open(config_path, "r")
    if not f then
        return nil, "Route not found"
    end
    local config = f:read("*a")
    f:close()

    local enabled = shell("test -L " .. SITES_ENABLED .. "/" .. domain .. " && echo true || echo false")
    return cjson.encode({
        domain = domain,
        enabled = enabled:gsub("%s+", "") == "true",
        config = config
    })
end

-- Create route
function _M.create_route(data)
    local domain = data.domain
    if not domain then
        return nil, "Domain is required"
    end

    local config = _M.generate_config(data)
    local config_path = SITES_AVAILABLE .. "/" .. domain

    local f = io.open(config_path, "w")
    if not f then
        return nil, "Cannot write config"
    end
    f:write(config)
    f:close()

    -- Create symlink
    os.execute("ln -sf " .. config_path .. " " .. SITES_ENABLED .. "/" .. domain)

    -- Reload nginx
    os.execute("openresty -s reload")

    return cjson.encode({success = true, domain = domain})
end

-- Delete route
function _M.delete_route(domain)
    os.execute("rm -f " .. SITES_ENABLED .. "/" .. domain)
    os.execute("mv " .. SITES_AVAILABLE .. "/" .. domain .. " " .. SITES_AVAILABLE .. "/" .. domain .. ".backup 2>/dev/null")
    os.execute("openresty -s reload")
    return cjson.encode({success = true, domain = domain})
end

-- Reload nginx
function _M.reload()
    local result = shell("openresty -t 2>&1")
    if result:find("successful") then
        os.execute("openresty -s reload")
        return cjson.encode({success = true, message = "Reloaded"})
    else
        return cjson.encode({success = false, error = result})
    end
end

-- Get status
function _M.status()
    local pid = shell("cat /usr/local/openresty/nginx/logs/nginx.pid 2>/dev/null")
    pid = pid:gsub("%s+", "")
    local running = pid ~= "" and pid ~= nil
    return cjson.encode({
        running = running,
        pid = pid
    })
end

-- Generate nginx config
function _M.generate_config(data)
    local domain = data.domain
    local route_type = data.type or "proxy"
    local proxy_port = data.proxy_port or "80"

    if route_type == "proxy" then
        return [[server {
    listen 80;
    server_name ]] .. domain .. [[;

    access_log off;
    error_log /var/log/nginx/]] .. domain .. [[.error.log;

    keepalive_timeout 70;
    client_max_body_size 50m;

    location / {
        proxy_pass http://127.0.0.1:]] .. proxy_port .. [[;
        proxy_http_version 1.1;
        proxy_redirect off;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host $server_name;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;

        add_header X-Frame-Options SAMEORIGIN;
        add_header Strict-Transport-Security "max-age=31536000";
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";

        proxy_read_timeout 86400;
    }
}]]
    elseif route_type == "wordpress" then
        local php_version = data.php_version or "8.2"
        return [[server {
    listen 80;
    server_name ]] .. domain .. [[;
    root /var/www/]] .. domain .. [[;
    index index.php;

    access_log off;
    error_log /var/log/nginx/]] .. domain .. [[.error.log;

    location / {
        try_files $uri $uri/ /index.php?q=$uri&$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php]] .. php_version .. [[-fpm.sock;
    }
}]]
    end

    return nil, "Unknown route type: " .. tostring(route_type)
end

return _M
```

### 6. `config/openresty/api/nginx.conf.lua` - Lua API server config

```lua
-- Nginx API server configuration
-- This file is included in the main nginx.conf to add the API server block

local _M = {}

function _M.get_api_server_block()
    return [[
    # API Server (internal only)
    server {
        listen 8080;
        server_name _;

        # Lua API endpoint
        location /api/ {
            content_by_lua_block {
                local api = require "routes"
                local method = ngx.req.get_method()
                local uri = ngx.var.uri

                ngx.header.content_type = "application/json"

                if method == "GET" and uri == "/api/routes" then
                    ngx.say(api.list_routes())
                elseif method == "GET" and uri:match("/api/routes/(.+)") then
                    local domain = uri:match("/api/routes/(.+)")
                    local result, err = api.get_route(domain)
                    if result then
                        ngx.say(result)
                    else
                        ngx.status = 404
                        ngx.say('{"error":"' .. err .. '"}')
                    end
                elseif method == "POST" and uri == "/api/routes" then
                    ngx.req.read_body()
                    local body = ngx.req.get_body_data()
                    if body then
                        local ok, data = pcall(require("cjson").decode, body)
                        if ok then
                            local result, err = api.create_route(data)
                            if result then
                                ngx.say(result)
                            else
                                ngx.status = 400
                                ngx.say('{"error":"' .. err .. '"}')
                            end
                        else
                            ngx.status = 400
                            ngx.say('{"error":"Invalid JSON"}')
                        end
                    else
                        ngx.status = 400
                        ngx.say('{"error":"No body"}')
                    end
                elseif method == "DELETE" and uri:match("/api/routes/(.+)") then
                    local domain = uri:match("/api/routes/(.+)")
                    ngx.say(api.delete_route(domain))
                elseif method == "POST" and uri == "/api/reload" then
                    ngx.say(api.reload())
                elseif method == "GET" and uri == "/api/status" then
                    ngx.say(api.status())
                else
                    ngx.status = 404
                    ngx.say('{"error":"Not found"}')
                end
            }
        }
    }
]]
end

return _M
```

## Files to Modify

### 1. `libs/apps/nginx_helper.sh` - Add Proxmox mode switch

Add at the top after the header:

```bash
# Source Proxmox helper
source "${BROLIT_MAIN_DIR}/libs/local/proxmox_helper.sh" 2>/dev/null || true
```

Modify `nginx_reconfigure()`:

```bash
function nginx_reconfigure() {

    # Check if Proxmox mode is enabled
    if [[ "${PROXMOX_MODE}" == "enabled" ]] && openresty_is_installed; then
        # Use OpenResty
        openresty_reconfigure
        return $?
    fi

    # Default: use system nginx
    # nginx.conf gauchocode standard configuration
    cat "${BROLIT_MAIN_DIR}/config/nginx/nginx.conf" >"/etc/nginx/nginx.conf"
    display --indent 6 --text "- Updating nginx.conf" --result "DONE" --color GREEN

    # mime.types
    cat "${BROLIT_MAIN_DIR}/config/nginx/mime.types" >"/etc/nginx/mime.types"
    display --indent 6 --text "- Updating mime.types" --result "DONE" --color GREEN

    #Test the validity of the nginx configuration
    nginx_configuration_test

}
```

Modify `nginx_configuration_test()`:

```bash
function nginx_configuration_test() {

    local result

    # Check if Proxmox mode with OpenResty
    if [[ "${PROXMOX_MODE}" == "enabled" ]] && openresty_is_installed; then
        openresty_configuration_test
        return $?
    fi

    # Default: use system nginx
    #Test the validity of the nginx configuration
    result="$(nginx -t 2>&1 | grep -w "test" | cut -d"." -f2 | cut -d" " -f4)"

    if [[ ${result} == "successful" ]]; then

        # Reload webserver
        service nginx reload

        # Log
        log_event "info" "Nginx configuration changed!" "false"
        display --indent 6 --text "- Testing nginx configuration" --result "DONE" --color GREEN

        return 0

    else

        debug="$(nginx -t 2>&1)"
        whiptail_message "WARNING" "Something went wrong changing Nginx configuration. Please check manually nginx config files."

        # Log
        log_event "error" "Problem changing Nginx configuration. Debug: ${debug}"
        display --indent 6 --text "- Testing nginx configuration" --result "FAIL" --color RED

        return 1

    fi

}
```

Modify `nginx_server_create()` to add Proxmox mode:

```bash
function nginx_server_create() {

    local project_domain="${1}"
    local project_type="${2}"
    local server_type="${3}"
    local redirect_domains="${4}"
    local proxy_port="${5}"

    # Check if Proxmox mode with OpenResty
    if [[ "${PROXMOX_MODE}" == "enabled" ]] && openresty_is_installed; then
        openresty_server_create "${project_domain}" "${project_type}" "${server_type}" "${redirect_domains}" "${proxy_port}"
        return $?
    fi

    # ... existing code ...

}
```

Modify `nginx_server_delete()` to add Proxmox mode:

```bash
function nginx_server_delete() {

    local filename="${1}"

    # Check if Proxmox mode with OpenResty
    if [[ "${PROXMOX_MODE}" == "enabled" ]] && openresty_is_installed; then
        openresty_server_delete "${filename}"
        return $?
    fi

    # ... existing code ...

}
```

Modify `nginx_server_change_status()` to add Proxmox mode:

```bash
function nginx_server_change_status() {

    local project_domain="${1}"
    local project_status="${2}"

    # Check if Proxmox mode with OpenResty
    if [[ "${PROXMOX_MODE}" == "enabled" ]] && openresty_is_installed; then
        openresty_server_change_status "${project_domain}" "${project_status}"
        return $?
    fi

    # ... existing code ...

}
```

### 2. `utils/brolit_configuration_manager.sh` - Add PROXMOX_MODE

Add new global variable in `_brolit_configuration_load_server_config()`:

```bash
function _brolit_configuration_load_server_config() {

    local server_config_file="${1}"

    # Globals
    declare -g SERVER_TIMEZONE
    declare -g SERVER_ROLE_WEBSERVER
    declare -g SERVER_ROLE_DATABASE
    declare -g SERVER_ADDITIONAL_IPS
    declare -g PROXMOX_MODE

    # ... existing code ...

    # Read optional vars from server config file
    SERVER_ADDITIONAL_IPS="$(json_read_field "${server_config_file}" "SERVER_CONFIG.additional_ips")"
    PROXMOX_MODE="$(json_read_field "${server_config_file}" "SERVER_CONFIG.proxmox_mode")"
    [[ -z "${PROXMOX_MODE}" ]] && PROXMOX_MODE="disabled"

    export SERVER_TIMEZONE SERVER_ROLE_WEBSERVER SERVER_ROLE_DATABASE SERVER_ADDITIONAL_IPS PROXMOX_MODE

}
```

### 3. `config/brolit/brolit_conf.json` - Add proxmox_mode field

Add under `SERVER_CONFIG`:

```json
{
    "SERVER_CONFIG": {
        "type": "production",
        "timezone": "America/Argentina/Buenos_Aires",
        "unattended_upgrades": "disabled",
        "proxmox_mode": "disabled",
        "additional_ips": [
            "",
            ""
        ],
        "config": [
            {
                "webserver": "disabled",
                "database": "disabled"
            }
        ]
    }
}
```

### 4. `utils/server_setup.sh` - Add openresty case

Add new case in `server_app_setup()`:

```bash
function server_app_setup() {

    local app_setup="${1}"

    case "${app_setup}" in

    "nginx")

        if [[ "${PROXMOX_MODE}" == "enabled" ]]; then
            # Use OpenResty instead of nginx
            openresty_installer
            openresty_reconfigure
        else
            if [[ ${PACKAGES_NGINX_STATUS} == "enabled" ]]; then
                # Nginx Installer
                nginx_installer
                # Reconfigure
                nginx_reconfigure
                nginx_new_default_server
                nginx_create_globals_config
            else
                package_purge "nginx"
            fi
        fi

        ;;

    # ... existing cases ...

    esac

}
```

### 5. `libs/task_runner.sh` - Add new tasks

Add new tasks in `tasks_handler()`:

```bash
function tasks_handler() {

    local task="${1}"
    local exit_code=0

    case ${task} in

    # ... existing cases ...

    openresty)
        # Validate subtask
        validate_task_and_subtask "openresty" "${STASK}" "install uninstall reconfigure status api-status api-routes"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

        # Execute task
        case "${STASK}" in
            install)
                execute_task_with_error_handling "openresty-install" "openresty_installer" "apt"
                ;;
            uninstall)
                execute_task_with_error_handling "openresty-uninstall" "openresty_purge"
                ;;
            reconfigure)
                execute_task_with_error_handling "openresty-reconfigure" "openresty_reconfigure"
                ;;
            status)
                execute_task_with_error_handling "openresty-status" "proxy_get_status"
                ;;
            api-status)
                execute_task_with_error_handling "openresty-api-status" "openresty_api_status"
                ;;
            api-routes)
                execute_task_with_error_handling "openresty-api-routes" "openresty_list_routes"
                ;;
        esac
        exit_code=$?
        exit ${exit_code}
        ;;

    migrate-npm)
        # Validate subtask
        validate_task_and_subtask "migrate-npm" "${STASK}" "download-configs migrate-all migrate-domain"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

        # Validate required params
        validate_required_params "migrate-npm" "DOMAIN"
        exit_code=$?
        [[ ${exit_code} -ne 0 ]] && exit ${exit_code}

        # Execute task
        case "${STASK}" in
            download-configs)
                execute_task_with_error_handling "migrate-npm-download" "npm_download_configs" "${DOMAIN}" "${TVALUE}"
                ;;
            migrate-all)
                execute_task_with_error_handling "migrate-npm-all" "npm_migrate_all" "${DOMAIN}" "${TVALUE}"
                ;;
            migrate-domain)
                execute_task_with_error_handling "migrate-npm-domain" "npm_migrate_domain" "${DOMAIN}" "${TVALUE}"
                ;;
        esac
        exit_code=$?
        exit ${exit_code}
        ;;

    esac

}
```

### 6. `libs/commons.sh` - Source new helpers

The `_source_all_scripts()` function auto-sources from `libs/apps/` and `libs/local/`, so new files will be automatically loaded. No changes needed.

## Tests to Create

### 1. `tests/test_proxmox_helper.sh`

```bash
#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
#############################################################################

function test_proxmox_helper_functions() {

    test_proxmox_detect
    test_openresty_is_installed
    test_nginx_is_installed
    test_proxy_get_status

}

function test_proxmox_detect() {

    log_subsection "Test: test_proxmox_detect"

    # This test only runs inside a Proxmox VM
    if proxmox_detect; then
        display --indent 6 --text "- test_proxmox_detect (inside VM)" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_proxmox_detect (not in VM, expected)" --result "PASS" --color WHITE
    fi

}

function test_openresty_is_installed() {

    log_subsection "Test: test_openresty_is_installed"

    # Check function exists
    if type openresty_is_installed &>/dev/null; then
        display --indent 6 --text "- test_openresty_is_installed: function exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_openresty_is_installed: function exists" --result "FAIL" --color RED
    fi

    # Check return value is valid
    openresty_is_installed
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]] || [[ ${exitstatus} -eq 1 ]]; then
        display --indent 6 --text "- test_openresty_is_installed: valid return" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_openresty_is_installed: valid return" --result "FAIL" --color RED
    fi

}

function test_nginx_is_installed() {

    log_subsection "Test: test_nginx_is_installed"

    # Check function exists
    if type nginx_is_installed &>/dev/null; then
        display --indent 6 --text "- test_nginx_is_installed: function exists" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_nginx_is_installed: function exists" --result "FAIL" --color RED
    fi

}

function test_proxy_get_status() {

    log_subsection "Test: test_proxy_get_status"

    local status
    status="$(proxy_get_status)"

    if [[ "${status}" == "openresty" ]] || [[ "${status}" == "nginx" ]] || [[ "${status}" == "none" ]]; then
        display --indent 6 --text "- test_proxy_get_status: returns '${status}'" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_proxy_get_status: invalid return '${status}'" --result "FAIL" --color RED
    fi

}
```

### 2. `tests/test_openresty_helper.sh`

```bash
#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
#############################################################################

function test_openresty_helper_functions() {

    test_openresty_get_conf_dir
    test_openresty_configuration_test
    test_openresty_list_routes
    test_openresty_api_status

}

function test_openresty_get_conf_dir() {

    log_subsection "Test: test_openresty_get_conf_dir"

    local conf_dir
    conf_dir="$(openresty_get_conf_dir)"

    if [[ "${conf_dir}" == "/usr/local/openresty/nginx/conf" ]]; then
        display --indent 6 --text "- test_openresty_get_conf_dir" --result "PASS" --color WHITE
    else
        display --indent 6 --text "- test_openresty_get_conf_dir: got '${conf_dir}'" --result "FAIL" --color RED
    fi

}

function test_openresty_configuration_test() {

    log_subsection "Test: test_openresty_configuration_test"

    if openresty_is_installed; then
        openresty_configuration_test
        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then
            display --indent 6 --text "- test_openresty_configuration_test" --result "PASS" --color WHITE
        else
            display --indent 6 --text "- test_openresty_configuration_test" --result "FAIL" --color RED
        fi
    else
        display --indent 6 --text "- test_openresty_configuration_test (skipped, not installed)" --result "SKIP" --color YELLOW
    fi

}

function test_openresty_list_routes() {

    log_subsection "Test: test_openresty_list_routes"

    if openresty_is_installed; then
        local result
        result="$(openresty_list_routes)"
        if echo "${result}" | jq . &>/dev/null; then
            display --indent 6 --text "- test_openresty_list_routes" --result "PASS" --color WHITE
        else
            display --indent 6 --text "- test_openresty_list_routes: invalid JSON" --result "FAIL" --color RED
        fi
    else
        display --indent 6 --text "- test_openresty_list_routes (skipped, not installed)" --result "SKIP" --color YELLOW
    fi

}

function test_openresty_api_status() {

    log_subsection "Test: test_openresty_api_status"

    if openresty_is_installed; then
        local result
        result="$(openresty_api_status)"
        if echo "${result}" | jq . &>/dev/null; then
            display --indent 6 --text "- test_openresty_api_status" --result "PASS" --color WHITE
        else
            display --indent 6 --text "- test_openresty_api_status: invalid JSON" --result "FAIL" --color RED
        fi
    else
        display --indent 6 --text "- test_openresty_api_status (skipped, not installed)" --result "SKIP" --color YELLOW
    fi

}
```

### 3. `tests/test_openresty_server.sh`

```bash
#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
#############################################################################

function test_openresty_server_functions() {

    test_openresty_server_create
    test_openresty_server_delete

}

function test_openresty_server_create() {

    log_subsection "Test: test_openresty_server_create"

    if openresty_is_installed; then
        local test_domain="test-openresty-$(date +%s).local"

        openresty_server_create "${test_domain}" "proxy" "" "" "8080"
        exitstatus=$?

        if [[ ${exitstatus} -eq 0 ]]; then
            # Verify config was created
            local conf_dir
            conf_dir="$(openresty_get_conf_dir)"
            if [[ -f "${conf_dir}/sites-available/${test_domain}" ]]; then
                display --indent 6 --text "- test_openresty_server_create" --result "PASS" --color WHITE
                # Cleanup
                openresty_server_delete "${test_domain}"
            else
                display --indent 6 --text "- test_openresty_server_create: config not created" --result "FAIL" --color RED
            fi
        else
            display --indent 6 --text "- test_openresty_server_create" --result "FAIL" --color RED
        fi
    else
        display --indent 6 --text "- test_openresty_server_create (skipped, not installed)" --result "SKIP" --color YELLOW
    fi

}

function test_openresty_server_delete() {

    log_subsection "Test: test_openresty_server_delete"

    if openresty_is_installed; then
        local test_domain="test-delete-$(date +%s).local"
        local conf_dir
        conf_dir="$(openresty_get_conf_dir)"

        # Create config first
        echo "server { listen 80; server_name ${test_domain}; }" > "${conf_dir}/sites-available/${test_domain}"
        ln -sf "${conf_dir}/sites-available/${test_domain}" "${conf_dir}/sites-enabled/${test_domain}"

        # Delete
        openresty_server_delete "${test_domain}"
        exitstatus=$?

        if [[ ${exitstatus} -eq 0 ]]; then
            if [[ ! -L "${conf_dir}/sites-enabled/${test_domain}" ]]; then
                display --indent 6 --text "- test_openresty_server_delete" --result "PASS" --color WHITE
            else
                display --indent 6 --text "- test_openresty_server_delete: symlink still exists" --result "FAIL" --color RED
            fi
        else
            display --indent 6 --text "- test_openresty_server_delete" --result "FAIL" --color RED
        fi
    else
        display --indent 6 --text "- test_openresty_server_delete (skipped, not installed)" --result "SKIP" --color YELLOW
    fi

}
```

### 4. `tests/test_npm_migration.sh`

```bash
#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
#############################################################################

function test_npm_migration_functions() {

    test_npm_generate_nginx_config

}

function test_npm_generate_nginx_config() {

    log_subsection "Test: test_npm_generate_nginx_config"

    local config
    config="$(npm_generate_nginx_config "test.example.com" "127.0.0.1" "3000" "false" "true" "")"

    if [[ -n "${config}" ]]; then
        # Check domain was replaced
        if echo "${config}" | grep -q "test.example.com"; then
            display --indent 6 --text "- test_npm_generate_nginx_config: domain replaced" --result "PASS" --color WHITE
        else
            display --indent 6 --text "- test_npm_generate_nginx_config: domain not replaced" --result "FAIL" --color RED
        fi

        # Check port was replaced
        if echo "${config}" | grep -q "3000"; then
            display --indent 6 --text "- test_npm_generate_nginx_config: port replaced" --result "PASS" --color WHITE
        else
            display --indent 6 --text "- test_npm_generate_nginx_config: port not replaced" --result "FAIL" --color RED
        fi

        # Check WebSocket headers present
        if echo "${config}" | grep -q "Upgrade"; then
            display --indent 6 --text "- test_npm_generate_nginx_config: websocket headers" --result "PASS" --color WHITE
        else
            display --indent 6 --text "- test_npm_generate_nginx_config: websocket headers missing" --result "FAIL" --color RED
        fi
    else
        display --indent 6 --text "- test_npm_generate_nginx_config: empty output" --result "FAIL" --color RED
    fi

}
```

## Step-by-Step Execution Plan

### Phase 1: Configuration

1. **Update brolit_conf.json template**
   - Add `proxmox_mode` field to `SERVER_CONFIG`
   - File: `config/brolit/brolit_conf.json`

2. **Update brolit_configuration_manager.sh**
   - Add `PROXMOX_MODE` variable
   - Read from config file
   - File: `utils/brolit_configuration_manager.sh`

### Phase 2: Create New Files

3. **Create proxmox_helper.sh**
   - File: `libs/local/proxmox_helper.sh`

4. **Create openresty_installer.sh**
   - File: `utils/installers/openresty_installer.sh`

5. **Create openresty_helper.sh**
   - File: `libs/apps/openresty_helper.sh`

6. **Create npm_migration_helper.sh**
   - File: `libs/local/npm_migration_helper.sh`

7. **Create Lua API files**
   - File: `config/openresty/api/routes.lua`
   - File: `config/openresty/api/nginx.conf.lua`

### Phase 3: Modify Existing Files

8. **Modify nginx_helper.sh**
   - Add Proxmox mode checks to:
     - `nginx_reconfigure()`
     - `nginx_configuration_test()`
     - `nginx_server_create()`
     - `nginx_server_delete()`
     - `nginx_server_change_status()`

9. **Modify server_setup.sh**
   - Add openresty case in `server_app_setup()`

10. **Modify task_runner.sh**
    - Add `openresty` task
    - Add `migrate-npm` task
    - Update `show_help()` with new tasks

### Phase 4: Create Tests

11. **Create test_proxmox_helper.sh**
    - File: `tests/test_proxmox_helper.sh`

12. **Create test_openresty_helper.sh**
    - File: `tests/test_openresty_helper.sh`

13. **Create test_openresty_server.sh**
    - File: `tests/test_openresty_server.sh`

14. **Create test_npm_migration.sh**
    - File: `tests/test_npm_migration.sh`

### Phase 5: Run Tests

15. **Run syntax check**
    ```bash
    bash -n libs/local/proxmox_helper.sh
    bash -n utils/installers/openresty_installer.sh
    bash -n libs/apps/openresty_helper.sh
    bash -n libs/local/npm_migration_helper.sh
    ```

16. **Run test suite**
    ```bash
    cd /root/brolit-shell
    source libs/commons.sh
    script_init "true"
    test_proxmox_helper_functions
    test_openresty_helper_functions
    test_openresty_server_functions
    test_npm_migration_functions
    ```

### Phase 6: Migration (on VM 101)

17. **Enable Proxmox mode**
    ```bash
    # Edit ~/.brolit_conf.json
    # Set "proxmox_mode": "enabled"
    ```

18. **Install OpenResty**
    ```bash
    ./runner.sh -t openresty -st install
    ```

19. **Configure OpenResty API**
    - Add Lua API server block to nginx.conf
    - Test API: `curl http://localhost:8080/api/status`

20. **Migrate from NPM**
    ```bash
    # Set NPM connection vars
    export NPM_HOST="10.2.0.100"
    export NPM_PORT="81"
    export NPM_TOKEN="your_token"

    # Migrate all hosts
    ./runner.sh -t migrate-npm -st migrate-all -D "${NPM_HOST}"
    ```

21. **Update Proxmox DNAT**
    ```bash
    # On Proxmox host
    # Change DNAT rules to point to VM 101
    iptables -t nat -R PREROUTING -i vmbr0 -p tcp --dport 80 -j DNAT --to 10.2.0.101:80
    iptables -t nat -R PREROUTING -i vmbr0 -p tcp --dport 443 -j DNAT --to 10.2.0.101:443
    iptables -t nat -R PREROUTING -i vmbr0 -p tcp --dport 8080 -j DNAT --to 10.2.0.101:8080
    ```

22. **Verify migration**
    ```bash
    # Test API
    curl http://10.2.0.101:8080/api/routes

    # Test a migrated site
    curl -I https://your-domain.com
    ```

### Phase 7: Cleanup

23. **Stop NPM**
    ```bash
    # On VM 100
    docker stop nginx-proxy-manager
    ```

24. **Remove old NPM config**
    ```bash
    # On VM 100 (optional)
    docker rm nginx-proxy-manager
    ```
