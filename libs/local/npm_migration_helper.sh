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
# Write nginx config to target (local or OpenResty VM)
#
# Arguments:
#   ${1} = ${config}
#   ${2} = ${config_file}
#   ${3} = ${domain}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function _npm_write_config_to_target() {

    local config="${1}"
    local config_file="${2}"
    local domain="${3}"

    local conf_dir
    conf_dir="$(openresty_get_conf_dir)"

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

}

################################################################################
# Migrate www redirect for root domain
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
#   0 if ok, 1 on error
################################################################################

function npm_migrate_www_redirect() {

    local domain="${1}"
    local forward_host="${2}"
    local forward_port="${3}"
    local ssl_enabled="${4}"
    local websocket="${5}"
    local advanced="${6}"

    local www_domain
    www_domain="www.${domain}"

    log_event "info" "Creating www redirect: ${www_domain} -> ${forward_host}:${forward_port}" "false"

    local config
    config="$(npm_generate_nginx_config \
        "${www_domain}" "${forward_host}" "${forward_port}" \
        "${ssl_enabled}" "${websocket}" "${advanced}")"

    local config_file
    config_file="$(openresty_get_conf_dir)/sites-available/${www_domain}"

    _npm_write_config_to_target "${config}" "${config_file}" "${www_domain}"

    display --indent 6 --text "- Created www redirect: ${www_domain}" --result "DONE" --color GREEN

}

################################################################################
# Regenerate certificates for root domains including www subdomain
#
# Arguments:
#   ${1} = ${root_domains_file} (file with one root domain per line)
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function npm_migrate_regenerate_root_certs() {

    local root_domains_file="${1}"

    if [[ ! -f "${root_domains_file}" ]] || [[ ! -s "${root_domains_file}" ]]; then
        log_event "info" "No root domains to regenerate certificates" "false"
        return 0
    fi

    if [[ -z "${PACKAGES_CERTBOT_CONFIG_MAILA}" ]]; then
        log_event "warning" "Certbot email not configured, skipping certificate regeneration" "false"
        return 0
    fi

    log_subsection "Regenerating certificates with www support"

    local domains_to_renew=""
    while IFS= read -r domain; do
        [[ -z "${domain}" ]] && continue
        if [[ -n "${domains_to_renew}" ]]; then
            domains_to_renew="${domains_to_renew},"
        fi
        domains_to_renew="${domains_to_renew}${domain},www.${domain}"
    done < "${root_domains_file}"

    if [[ -n "${domains_to_renew}" ]]; then
        log_event "info" "Regenerating certificates for: ${domains_to_renew}" "false"
        certbot_certificate_install_auto "${PACKAGES_CERTBOT_CONFIG_MAILA}" "${domains_to_renew}" "true"
    else
        log_event "info" "No root domains with www redirects found" "false"
    fi

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
    local upstream_url

    # Determine upstream protocol (HTTPS for Proxmox web UI on port 8006)
    if [[ "${forward_port}" == "8006" ]] || [[ "${forward_host}" == "213.199.58.220" ]]; then
        upstream_url="https://${forward_host}:${forward_port}"
    else
        upstream_url="http://${forward_host}:${forward_port}"
    fi

    if [[ "${PROXMOX_MODE}" == "enabled" ]] && openresty_is_installed 2>/dev/null; then
        template="${BROLIT_MAIN_DIR}/config/nginx/sites-available/proxy_single_openresty"
    elif [[ "${ssl_enabled}" == "true" ]]; then
        template="${BROLIT_MAIN_DIR}/config/nginx/sites-available/proxy_single_ssl"
        # Fallback to proxy_single if ssl template doesn't exist
        [[ ! -f "${template}" ]] && template="${BROLIT_MAIN_DIR}/config/nginx/sites-available/proxy_single"
    else
        template="${BROLIT_MAIN_DIR}/config/nginx/sites-available/proxy_single"
    fi

    config="$(cat "${template}")"

    # Replace placeholders
    config="$(echo "${config}" | sed "s/domain.com/${domain}/g")"
    config="$(echo "${config}" | sed "s|UPSTREAM_URL|${upstream_url}|g")"
    config="$(echo "${config}" | sed "s/PROXY_PORT/${forward_port}/g")"
    config="$(echo "${config}" | sed "s/127.0.0.1/${forward_host}/g")"

    # Remove WebSocket headers if not enabled
    if [[ "${websocket_enabled}" != "true" ]]; then
        config="$(echo "${config}" | grep -v "Upgrade\|connection_upgrade")"
    fi

    # Add proxy_ssl_verify off for HTTPS upstreams
    if [[ "${upstream_url}" == https://* ]]; then
        config="$(echo "${config}" | sed "s|proxy_pass ${upstream_url};|proxy_pass ${upstream_url};\n        proxy_ssl_verify off;|")"
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

    # Track root domains for certificate regeneration
    local root_domains_file="/tmp/npm_root_domains_$$.txt"
    : > "${root_domains_file}"

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

        _npm_write_config_to_target "${config}" "${config_file}" "${domain}"

        # Migrate SSL certificate if enabled
        if [[ "${ssl_enabled}" == "true" ]]; then
            _npm_migrate_ssl_certificate "${domain}" "${host_data}"
        fi

        # Generate www redirect for root domains
        local root_domain
        root_domain="$(domain_get_root "${domain}" 2>/dev/null)"
        if [[ "${domain}" == "${root_domain}" ]] && [[ -n "${root_domain}" ]]; then
            npm_migrate_www_redirect "${domain}" "${forward_host}" "${forward_port}" \
                "${ssl_enabled}" "${websocket}" "${advanced}"
            echo "${domain}" >> "${root_domains_file}"
        fi

        display --indent 4 --text "- Migrated: ${domain}" --result "DONE" --color GREEN

        i=$((i + 1))

    done

    # Regenerate certificates for root domains including www subdomain
    npm_migrate_regenerate_root_certs "${root_domains_file}"
    rm -f "${root_domains_file}"

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
