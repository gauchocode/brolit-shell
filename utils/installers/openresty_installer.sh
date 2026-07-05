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

    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
        # Install inside the VM via SSH
        _openresty_install_in_vm "${install_method}"
    else
        # Install locally
        _openresty_install_local "${install_method}"
    fi

    log_event "info" "OpenResty installed successfully" "false"

}

################################################################################
# Install OpenResty locally
#
# Arguments:
#   ${1} = ${install_method} ("apt" or "official")
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function _openresty_install_local() {

    local install_method="${1}"

    if [[ "${install_method}" == "official" ]]; then
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

}

################################################################################
# Install OpenResty inside a VM via SSH
#
# Arguments:
#   ${1} = ${install_method} ("apt" or "official")
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function _openresty_install_in_vm() {

    local install_method="${1}"
    local vm_ip="${OPENRESTY_VM_IP}"

    log_event "info" "Installing OpenResty inside VM at ${vm_ip}" "false"

    # Build remote install script
    local remote_script=""
    remote_script+="apt-get update && "
    remote_script+="apt-get install -y --no-install-recommends gnupg2 ca-certificates lsb-release debian-archive-keyring && "

    if [[ "${install_method}" == "official" ]]; then
        remote_script+="curl -1sLf 'https://openresty.org/package/pubkey.gpg' | gpg --dearmor -o /usr/share/keyrings/openresty.gpg && "
        remote_script+="echo 'deb [signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu \$(lsb_release -sc) main' > /etc/apt/sources.list.d/openresty.list && "
        remote_script+="apt-get update && "
    fi

    remote_script+="apt-get install -y openresty && "
    remote_script+="mkdir -p /usr/local/openresty/nginx/conf/sites-available && "
    remote_script+="mkdir -p /usr/local/openresty/nginx/conf/sites-enabled && "
    remote_script+="mkdir -p /usr/local/openresty/nginx/conf/api && "
    remote_script+="mkdir -p /usr/local/openresty/nginx/conf/globals && "
    remote_script+="mkdir -p /var/www/certbot/.well-known/acme-challenge && "
    remote_script+="mkdir -p /etc/letsencrypt/renewal-hooks/deploy && "
    remote_script+="echo 'OpenResty installed successfully'"

    # Execute remote install
    local install_output
    install_output="$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
        "root@${vm_ip}" "${remote_script}" 2>&1)"

    local exit_status=$?
    if [[ ${exit_status} -ne 0 ]]; then
        log_event "error" "Failed to install OpenResty on VM: ${install_output}" "false"
        display --indent 6 --text "- Installing OpenResty on VM" --result "FAIL" --color RED
        return 1
    fi

    # Copy config files to VM
    _openresty_copy_configs_to_vm "${vm_ip}"

    # Create systemd service on VM
    _openresty_create_systemd_service_vm "${vm_ip}"

    display --indent 6 --text "- Installing OpenResty on VM" --result "DONE" --color GREEN

}

################################################################################
# Copy config files to VM via SCP
#
# Arguments:
#   ${1} = ${vm_ip}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function _openresty_copy_configs_to_vm() {

    local vm_ip="${1}"

    # Create OpenResty-specific nginx.conf (not the brolit one with /etc/nginx/ paths)
    local tmp_conf="/tmp/openresty_nginx_$$.conf"
    cat > "${tmp_conf}" << 'HEREDOC'
user www-data;
worker_processes auto;
pid /run/nginx.pid;

worker_rlimit_nofile 65535;
pcre_jit on;

events {
    worker_connections 2048;
    multi_accept on;
    use epoll;
}

http {
    lua_package_path "/usr/local/openresty/nginx/conf/api/?.lua;;";
    include /usr/local/openresty/nginx/conf/mime.types;
    default_type application/octet-stream;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;

    keepalive_timeout 10s;
    keepalive_requests 5000;

    client_header_buffer_size 16m;
    large_client_header_buffers 16 8m;

    charset utf-8;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size 200M;

    map $http_upgrade $connection_upgrade {
        default upgrade;
        ""      close;
    }

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    access_log /usr/local/openresty/nginx/logs/access.log;
    error_log /usr/local/openresty/nginx/logs/error.log crit;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    # Lua API Server (internal management)
    server {
        listen 8080;
        server_name _;

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
                        ngx.say("{\"error\":\"" .. err .. "\"}")
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
                                ngx.say("{\"error\":\"" .. err .. "\"}")
                            end
                        else
                            ngx.status = 400
                            ngx.say("{\"error\":\"Invalid JSON\"}")
                        end
                    else
                        ngx.status = 400
                        ngx.say("{\"error\":\"No body\"}")
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
                    ngx.say("{\"error\":\"Not found\"}")
                end
            }
        }
    }

    # Certbot ACME challenge server block (webroot method)
    server {
        listen 80 default_server;
        server_name _;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
    }

    include /usr/local/openresty/nginx/conf/sites-enabled/*.conf;
}
HEREDOC

    # Copy OpenResty-specific nginx.conf
    scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
        "${tmp_conf}" "root@${vm_ip}:/usr/local/openresty/nginx/conf/nginx.conf"
    rm -f "${tmp_conf}"

    # Copy mime.types
    scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
        "${BROLIT_MAIN_DIR}/config/nginx/mime.types" \
        "root@${vm_ip}:/usr/local/openresty/nginx/conf/mime.types"

    # Copy globals (only http-safe ones, skip those with location directives)
    for f in logs.conf security.conf; do
        if [[ -f "${BROLIT_MAIN_DIR}/config/nginx/globals/${f}" ]]; then
            scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                "${BROLIT_MAIN_DIR}/config/nginx/globals/${f}" \
                "root@${vm_ip}:/usr/local/openresty/nginx/conf/globals/"
        fi
    done

    # Copy Lua API files
    mkdir -p "${BROLIT_MAIN_DIR}/config/openresty/api"
    if [[ -f "${BROLIT_MAIN_DIR}/config/openresty/api/routes.lua" ]]; then
        scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            "${BROLIT_MAIN_DIR}/config/openresty/api/routes.lua" \
            "root@${vm_ip}:/usr/local/openresty/nginx/conf/api/"
    fi
    if [[ -f "${BROLIT_MAIN_DIR}/config/openresty/api/nginx.conf.lua" ]]; then
        scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            "${BROLIT_MAIN_DIR}/config/openresty/api/nginx.conf.lua" \
            "root@${vm_ip}:/usr/local/openresty/nginx/conf/api/"
    fi

    # Create certbot renewal hook for OpenResty
    local hook_tmp="/tmp/openresty_reload_hook_$$.sh"
    cat > "${hook_tmp}" << 'HOOKEOF'
#!/bin/bash
# Reload OpenResty after certbot renewal
/usr/local/openresty/bin/openresty -s reload
HOOKEOF
    chmod +x "${hook_tmp}"
    scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
        "${hook_tmp}" "root@${vm_ip}:/etc/letsencrypt/renewal-hooks/deploy/openresty-reload.sh"
    rm -f "${hook_tmp}"

}

################################################################################
# Create systemd service on remote VM
#
# Arguments:
#   ${1} = ${vm_ip}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function _openresty_create_systemd_service_vm() {

    local vm_ip="${1}"

    local service_content="[Unit]
Description=The OpenResty Application Platform
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/usr/local/openresty/nginx/logs/nginx.pid
ExecStartPre=/usr/local/openresty/bin/openresty -t
ExecStart=/usr/local/openresty/bin/openresty
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target"

    # Write service file and enable on VM
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
        "root@${vm_ip}" "cat > /etc/systemd/system/openresty.service << 'HEREDOC'
${service_content}
HEREDOC
systemctl daemon-reload && systemctl enable openresty"

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

    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
        # Purge inside the VM via SSH
        ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            "root@${OPENRESTY_VM_IP}" \
            "systemctl stop openresty 2>/dev/null; systemctl disable openresty 2>/dev/null; rm -f /etc/systemd/system/openresty.service; apt-get purge -y openresty; apt-get autoremove -y"
    else
        systemctl stop openresty 2>/dev/null
        systemctl disable openresty 2>/dev/null
        rm -f /etc/systemd/system/openresty.service

        apt-get purge -y openresty
        apt-get autoremove -y
    fi

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

    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
        # Reconfigure inside the VM via SCP + SSH
        # Only copy Lua API files and mime.types (nginx.conf is managed on the VM)
        if [[ -f "${BROLIT_MAIN_DIR}/config/openresty/api/routes.lua" ]]; then
            scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                "${BROLIT_MAIN_DIR}/config/openresty/api/routes.lua" \
                "root@${OPENRESTY_VM_IP}:/usr/local/openresty/nginx/conf/api/"
        fi
        if [[ -f "${BROLIT_MAIN_DIR}/config/openresty/api/nginx.conf.lua" ]]; then
            scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                "${BROLIT_MAIN_DIR}/config/openresty/api/nginx.conf.lua" \
                "root@${OPENRESTY_VM_IP}:/usr/local/openresty/nginx/conf/api/"
        fi
        openresty_configuration_test
    else
        # Reconfigure locally
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

        # Copy globals (only http-safe ones)
        for f in logs.conf security.conf; do
            if [[ -f "${BROLIT_MAIN_DIR}/config/nginx/globals/${f}" ]]; then
                cp "${BROLIT_MAIN_DIR}/config/nginx/globals/${f}" \
                    "${openresty_conf}/globals/"
            fi
        done

        # Test and reload
        openresty_configuration_test
    fi

}
