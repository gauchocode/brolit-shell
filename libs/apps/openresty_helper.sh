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

    local api_url
    api_url="$(openresty_get_api_url)/api/routes"
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
