#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.6
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

    ip route | grep default | awk '{print $3}'

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
# Get OpenResty VM IP from brolit config
#
# Arguments:
#   none
#
# Outputs:
#   VM IP address or empty string
################################################################################

function proxmox_get_openresty_vm_ip() {

    local config_file="${BROLIT_CONFIG_FILE}"
    local vm_ip=""

    if [[ -f "${config_file}" ]]; then
        vm_ip="$(jq -r '.server_config.openresty_vm_ip // empty' "${config_file}" 2>/dev/null)"
    fi

    echo "${vm_ip}"

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

    if [[ "${PROXMOX_MODE}" == "enabled" ]] && [[ -n "${OPENRESTY_VM_IP}" ]]; then
        # Check on the VM via SSH (try key-based first, then password)
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            "root@${OPENRESTY_VM_IP}" "command -v openresty &>/dev/null" 2>/dev/null; then
            return 0
        fi
        # Try with sshpass if OPENRESTY_VM_PASS is set
        if [[ -n "${OPENRESTY_VM_PASS}" ]]; then
            if sshpass -p "${OPENRESTY_VM_PASS}" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                "root@${OPENRESTY_VM_IP}" "command -v openresty &>/dev/null" 2>/dev/null; then
                return 0
            fi
        fi
        return 1
    else
        command -v openresty &>/dev/null
    fi

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
