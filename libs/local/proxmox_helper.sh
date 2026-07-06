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
    local virt
    local dmi_field

    # Check DMI vendor fields (QEMU/KVM for Proxmox)
    for dmi_field in /sys/class/dmi/id/sys_vendor \
        /sys/class/dmi/id/product_name \
        /sys/class/dmi/id/board_vendor \
        /sys/class/dmi/id/bios_vendor \
        /sys/class/dmi/id/chassis_vendor; do

        if [[ -f "${dmi_field}" ]]; then
            vendor="$(tr '[:upper:]' '[:lower:]' < "${dmi_field}" 2>/dev/null)"
            if [[ "${vendor}" == *"proxmox"* ]] || [[ "${vendor}" == *"qemu"* ]] || [[ "${vendor}" == *"kvm"* ]]; then
                return 0
            fi
        fi

    done

    # Check systemd-detect-virt if available
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt="$(systemd-detect-virt 2>/dev/null | tr '[:upper:]' '[:lower:]')"
        if [[ "${virt}" == "kvm" ]] || [[ "${virt}" == "qemu" ]]; then
            return 0
        fi
    fi

    # dmidecode fallback
    if command -v dmidecode >/dev/null 2>&1; then
        vendor="$(dmidecode -s system-manufacturer 2>/dev/null | tr '[:upper:]' '[:lower:]')"
        if [[ "${vendor}" == *"proxmox"* ]] || [[ "${vendor}" == *"qemu"* ]] || [[ "${vendor}" == *"kvm"* ]]; then
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
# Detect if running on a Proxmox VE node (hypervisor)
#
# Arguments:
#   none
#
# Outputs:
#   0 if Proxmox node detected, 1 otherwise
################################################################################

function proxmox_node_detect() {

    # Check for Proxmox VE packages/binaries
    if command -v pveversion >/dev/null 2>&1; then
        return 0
    fi

    if [[ -f /usr/bin/pveversion ]] || [[ -f /usr/sbin/pveversion ]]; then
        return 0
    fi

    # Check for Proxmox VE services
    if systemctl is-active pvedaemon >/dev/null 2>&1 || systemctl is-active pveproxy >/dev/null 2>&1; then
        return 0
    fi

    # Check for Proxmox VE kernel
    if [[ "$(uname -r)" == *"pve"* ]]; then
        return 0
    fi

    # Check for Proxmox VE specific directories
    if [[ -d /etc/pve ]] || [[ -d /var/lib/vz ]]; then
        return 0
    fi

    return 1

}

################################################################################
# Detect if running on a VPS (virtual private server)
#
# Arguments:
#   none
#
# Outputs:
#   0 if VPS detected, 1 otherwise
################################################################################

function vps_detect() {

    local virt

    # If it's a Proxmox VM or node, it's not a generic VPS
    proxmox_detect 2>/dev/null && return 1
    proxmox_node_detect 2>/dev/null && return 1

    # Check systemd-detect-virt
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        virt="$(systemd-detect-virt 2>/dev/null | tr '[:upper:]' '[:lower:]')"
        if [[ "${virt}" != "none" ]] && [[ -n "${virt}" ]]; then
            return 0
        fi
    fi

    # Check DMI for common VPS indicators
    local dmi_field
    local vendor
    for dmi_field in /sys/class/dmi/id/sys_vendor \
        /sys/class/dmi/id/product_name \
        /sys/class/dmi/id/board_vendor \
        /sys/class/dmi/id/bios_vendor; do

        if [[ -f "${dmi_field}" ]]; then
            vendor="$(tr '[:upper:]' '[:lower:]' < "${dmi_field}" 2>/dev/null)"
            if [[ "${vendor}" == *"amazon"* ]] || [[ "${vendor}" == *"aws"* ]] || \
               [[ "${vendor}" == *"digitalocean"* ]] || [[ "${vendor}" == *"google"* ]] || \
               [[ "${vendor}" == *"microsoft"* ]] || [[ "${vendor}" == *"azure"* ]] || \
               [[ "${vendor}" == *"linode"* ]] || [[ "${vendor}" == *"akamai"* ]] || \
               [[ "${vendor}" == *"vultr"* ]] || [[ "${vendor}" == *"hetzner"* ]] || \
               [[ "${vendor}" == *"contabo"* ]] || [[ "${vendor}" == *"ovh"* ]] || \
               [[ "${vendor}" == *"vmware"* ]] || [[ "${vendor}" == *"virtualbox"* ]] || \
               [[ "${vendor}" == *"xen"* ]] || [[ "${vendor}" == *"hyper-v"* ]]; then
                return 0
            fi
        fi

    done

    return 1

}

################################################################################
# Detect server type
#
# Arguments:
#   none
#
# Outputs:
#   Prints one of: proxmox_node, proxmox_vm, vps, baremetal
################################################################################

function server_detect_type() {

    if proxmox_node_detect 2>/dev/null; then
        echo "proxmox_node"
        return 0
    fi

    if proxmox_detect 2>/dev/null; then
        echo "proxmox_vm"
        return 0
    fi

    if vps_detect 2>/dev/null; then
        echo "vps"
        return 0
    fi

    echo "baremetal"
    return 0

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
