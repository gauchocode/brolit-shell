#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.6
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

    # In Proxmox mode, ensure remote directories exist
    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
        ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            "root@${OPENRESTY_VM_IP}" \
            "mkdir -p ${conf_dir}/sites-available ${conf_dir}/sites-enabled" 2>/dev/null
    fi

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

        if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
            # Write config locally then SCP to VM
            local tmp_config="/tmp/openresty_migration_${domain}.conf"
            echo "${config}" > "${tmp_config}"
            scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                "${tmp_config}" "root@${OPENRESTY_VM_IP}:${config_file}"
            rm -f "${tmp_config}"

            # Create symlink on VM
            ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                "root@${OPENRESTY_VM_IP}" \
                "ln -sf ${config_file} ${conf_dir}/sites-enabled/${domain}"
        else
            echo "${config}" > "${config_file}"
            ln -sf "${config_file}" "${conf_dir}/sites-enabled/${domain}"
        fi

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
            local cert_dir="/etc/letsencrypt/live/${domain}"

            if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
                # Create dir and write certs on VM
                ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                    "root@${OPENRESTY_VM_IP}" \
                    "mkdir -p ${cert_dir} && echo '${cert}' > ${cert_dir}/fullchain.pem && echo '${key}' > ${cert_dir}/privkey.pem"
            else
                mkdir -p "${cert_dir}"
                echo "${cert}" > "${cert_dir}/fullchain.pem"
                echo "${key}" > "${cert_dir}/privkey.pem"
            fi

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

    # In Proxmox mode, ensure remote directories exist
    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
        ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            "root@${OPENRESTY_VM_IP}" \
            "mkdir -p ${conf_dir}/sites-available ${conf_dir}/sites-enabled" 2>/dev/null
    fi

    # Generate config
    local config
    config="$(npm_generate_nginx_config \
        "${domain}" "${forward_host}" "${forward_port}" \
        "${ssl_enabled}" "${websocket}" "${advanced}")"

    # Save config
    local config_file="${conf_dir}/sites-available/${domain}"

    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
        # Write config locally then SCP to VM
        local tmp_config="/tmp/openresty_migration_${domain}.conf"
        echo "${config}" > "${tmp_config}"
        scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            "${tmp_config}" "root@${OPENRESTY_VM_IP}:${config_file}"
        rm -f "${tmp_config}"

        # Create symlink on VM
        ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            "root@${OPENRESTY_VM_IP}" \
            "ln -sf ${config_file} ${conf_dir}/sites-enabled/${domain}"
    else
        echo "${config}" > "${config_file}"
        ln -sf "${config_file}" "${conf_dir}/sites-enabled/${domain}"
    fi

    # Migrate SSL if enabled
    if [[ "${ssl_enabled}" == "true" ]]; then
        _npm_migrate_ssl_certificate "${domain}" "${host_data}"
    fi

    # Test and reload
    openresty_configuration_test

    display --indent 4 --text "- Migrated: ${domain}" --result "DONE" --color GREEN

}
