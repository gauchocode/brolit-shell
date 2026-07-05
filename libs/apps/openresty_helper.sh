#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.9
################################################################################
#
# OpenResty Helper: Perform openresty actions via Lua API.
#
# When PROXMOX_MODE=enabled, OpenResty runs inside a VM (OPENRESTY_VM_IP).
# All commands are executed via SSH to the VM.
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
# Get OpenResty Lua API base URL
#
# In Proxmox mode, the API runs inside the VM on port 8080.
# Locally, it runs on localhost:8080.
#
# Arguments:
#   none
#
# Outputs:
#   API base URL (e.g., "http://10.2.0.100:8080")
################################################################################

function openresty_get_api_url() {

    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
        echo "http://${OPENRESTY_VM_IP}:8080"
    else
        echo "http://localhost:8080"
    fi

}

################################################################################
# Execute a command on the OpenResty VM via SSH
#
# In local mode (PROXMOX_MODE != enabled), runs the command locally.
# In Proxmox mode, SSHes into OPENRESTY_VM_IP and runs the command there.
#
# Arguments:
#   ${1} = command to execute
#
# Outputs:
#   Command output
#   Returns: SSH/command exit status
################################################################################

function openresty_vm_exec() {

    local cmd="${1}"

    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
        # Try key-based first, then password if OPENRESTY_VM_PASS is set
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            "root@${OPENRESTY_VM_IP}" "${cmd}" 2>/dev/null; then
            return 0
        fi
        if [[ -n "${OPENRESTY_VM_PASS}" ]]; then
            sshpass -p "${OPENRESTY_VM_PASS}" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                "root@${OPENRESTY_VM_IP}" "${cmd}"
            return $?
        fi
        return 1
    else
        eval "${cmd}"
    fi

}

################################################################################
# Copy a file to the OpenResty VM via SCP
#
# Arguments:
#   ${1} = local file path
#   ${2} = remote path on VM
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_vm_scp() {

    local local_path="${1}"
    local remote_path="${2}"

    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
        # Try key-based first, then password if OPENRESTY_VM_PASS is set
        if scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            "${local_path}" "root@${OPENRESTY_VM_IP}:${remote_path}" 2>/dev/null; then
            return 0
        fi
        if [[ -n "${OPENRESTY_VM_PASS}" ]]; then
            sshpass -p "${OPENRESTY_VM_PASS}" scp -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                "${local_path}" "root@${OPENRESTY_VM_IP}:${remote_path}"
            return $?
        fi
        return 1
    else
        cp "${local_path}" "${remote_path}"
    fi

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
    local test_output

    test_output="$(openresty_vm_exec "openresty -t 2>&1")"
    result="$(echo "${test_output}" | grep -w "test" | cut -d"." -f2 | cut -d" " -f4)"

    if [[ "${result}" == "successful" ]]; then

        # Reload webserver
        openresty_vm_exec "openresty -s reload"

        # Log
        log_event "info" "OpenResty configuration test passed" "false"
        display --indent 6 --text "- Testing openresty configuration" --result "DONE" --color GREEN

        return 0

    else

        local debug
        debug="${test_output}"
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
    local upstream_url="${6:-}"

    local api_url
    api_url="$(openresty_get_api_url)/api/routes"
    local json_data

    log_event "info" "Creating openresty config for domain: ${project_domain}" "false"

    # Build JSON payload
    json_data="{\"domain\":\"${project_domain}\",\"type\":\"${project_type}\""

    if [[ -n "${proxy_port}" ]]; then
        json_data="${json_data},\"proxy_port\":\"${proxy_port}\""
    fi

    if [[ -n "${upstream_url}" ]]; then
        json_data="${json_data},\"upstream_url\":\"${upstream_url}\""
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

    local api_url
    api_url="$(openresty_get_api_url)/api/routes/${project_domain}"

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

        local file_exists
        file_exists="$(openresty_vm_exec "test -f ${conf_dir}/sites-available/${project_domain} && echo yes || echo no")"

        if [[ "${file_exists}" == "yes" ]]; then
            openresty_vm_exec "ln -s ${conf_dir}/sites-available/${project_domain} ${conf_dir}/sites-enabled/${project_domain}"
            log_event "info" "Project config added to sites-enabled" "false"
            display --indent 6 --text "- Changing project status to ONLINE" --result "DONE" --color GREEN
        else
            log_event "error" "${conf_dir}/sites-available/${project_domain} does not exist" "false"
            display --indent 6 --text "- Changing project status to ONLINE" --result "FAIL" --color RED
        fi
        ;;

    offline)

        log_event "info" "New project status: ${project_status}" "false"

        local link_exists
        link_exists="$(openresty_vm_exec "test -L ${conf_dir}/sites-enabled/${project_domain} && echo yes || echo no")"

        if [[ "${link_exists}" == "yes" ]]; then
            openresty_vm_exec "rm ${conf_dir}/sites-enabled/${project_domain}"
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

    local api_url
    api_url="$(openresty_get_api_url)"
    curl -s "${api_url}/api/routes" 2>/dev/null

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

    local api_url
    api_url="$(openresty_get_api_url)"
    curl -s "${api_url}/api/status" 2>/dev/null

}

################################################################################
# Set domain on OpenResty server configuration
#
# Arguments:
#   ${1} = ${nginx_server_file}
#   ${2} = ${domain_name}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_server_set_domain() {

    local nginx_server_file="${1}"
    local domain_name="${2}"
    local conf_dir
    conf_dir="$(openresty_get_conf_dir)"

    openresty_vm_exec "sed -i 's/domain.com/${domain_name}/g' ${conf_dir}/sites-available/${nginx_server_file}"

}

################################################################################
# Change domain on OpenResty server configuration
#
# Arguments:
#  ${1} = ${nginx_server_file}
#  ${2} = ${domain_name_old}
#  ${3} = ${domain_name_new}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_server_change_domain() {

    local nginx_server_file="${1}"
    local domain_name_old="${2}"
    local domain_name_new="${3}"
    local conf_dir
    conf_dir="$(openresty_get_conf_dir)"

    openresty_vm_exec "sed -i 's/${domain_name_old}/${domain_name_new}/g' ${conf_dir}/sites-available/${nginx_server_file}"

}

################################################################################
# Get configured PHP version on OpenResty server
#
# Arguments:
#  ${1} = ${nginx_server_file}
#
# Outputs:
#   ${current_php_v}
################################################################################

function openresty_server_get_current_phpv() {

    local nginx_server_file="${1}"
    local conf_dir
    conf_dir="$(openresty_get_conf_dir)"
    local current_php_v_string

    current_php_v_string="$(openresty_vm_exec "grep fastcgi_pass ${conf_dir}/sites-available/${nginx_server_file} 2>/dev/null | cut -d '/' -f 4 | cut -d '-' -f 1")"
    echo "${current_php_v_string#php}"

}

################################################################################
# Change PHP version on OpenResty server configuration
#
# Arguments:
#  ${1} = ${nginx_server_file}
#  ${2} = ${new_php_v}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_server_change_phpv() {

    local nginx_server_file="${1}"
    local new_php_v="${2}"
    local conf_dir
    conf_dir="$(openresty_get_conf_dir)"
    local current_php_v

    current_php_v="$(openresty_server_get_current_phpv "${nginx_server_file}")"

    log_event "info" "Changing PHP version on OpenResty server file" "false"
    display --indent 6 --text "- Changing PHP version on openresty server file"

    openresty_vm_exec "sed -i 's#${current_php_v}#${new_php_v}#' ${conf_dir}/sites-available/${nginx_server_file}"

    clear_previous_lines "1"
    display --indent 6 --text "- Changing PHP version on openresty server file" --result "DONE" --color GREEN
    display --indent 8 --text "PHP version changed to ${new_php_v}"
    log_event "info" "PHP version for ${nginx_server_file} changed from ${current_php_v} to ${new_php_v}" "false"

    openresty_configuration_test

}

################################################################################
# Create OpenResty default server
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_new_default_server() {

    log_event "info" "OpenResty default server is managed in nginx.conf, skipping" "false"
    return 0

}

################################################################################
# Delete OpenResty default directory for sites
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_delete_default_directory() {

    log_event "info" "Default directory deletion not applicable for OpenResty VM" "false"
    return 0

}

################################################################################
# Create globals config files for OpenResty
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_create_globals_config() {

    log_event "info" "Globals config for OpenResty is managed in nginx.conf, skipping" "false"
    return 0

}

################################################################################
# Create empty nginx.conf file on OpenResty VM project path
#
# Arguments:
#   ${1} = ${path}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_create_empty_nginx_conf() {

    local path="${1}"

    openresty_vm_exec "if [[ -d ${path} \u0026\u0026 ! -f ${path}/nginx.conf ]]; then touch ${path}/nginx.conf \u0026\u0026 exit 0; else exit 1; fi"

}

################################################################################
# Generate encrypted auth for OpenResty
#
# Arguments:
#   ${1} = ${user}
#   ${2} = ${psw}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_generate_encrypted_auth() {

    local user="${1}"
    local psw="${2}"
    local encrypted_psw

    log_event "info" "Creating OpenResty encrypted authentication" "false"

    if [[ -n ${psw} ]]; then
        encrypted_psw="$(mkpasswd -m sha-512 "${psw}")"
    fi

    log_event "info" "User: ${user}" "false"
    log_event "info" "Saving auth data on: /usr/local/openresty/nginx/.passwords" "false"

    openresty_vm_exec "printf '${user}:${encrypted_psw}' > /usr/local/openresty/nginx/.passwords \u0026\u0026 chmod 640 /usr/local/openresty/nginx/.passwords \u0026\u0026 chown www-data:www-data /usr/local/openresty/nginx/.passwords"

}

################################################################################
# Add http2 support to OpenResty server configuration
#
# Arguments:
#   ${1} = ${nginx_server_file}
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function openresty_server_add_http2_support() {

    local nginx_server_file="${1}"
    local conf_dir
    conf_dir="$(openresty_get_conf_dir)"

    log_event "info" "Adding http2 support to ${nginx_server_file}" "false"
    display --indent 6 --text "- Adding http2 support" --result "DONE" --color GREEN

    openresty_vm_exec "sed -i 's/listen 443 ssl;/listen 443 ssl http2;/g; s/listen \[::\]:443 ssl;/listen [::]:443 ssl http2;/g' ${conf_dir}/sites-available/${nginx_server_file}"

    return 0

}
