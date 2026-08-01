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

    echo "${OPENRESTY_VM_IP}"

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
        # Check on the VM via SSH key auth
        openresty_vm_exec "command -v openresty &>/dev/null"
        return $?
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

################################################################################
# Get next free VMID on this Proxmox node
#
# Arguments:
#   none
#
# Outputs:
#   VMID
################################################################################

function proxmox_get_next_vmid() {

    pvesh get /cluster/nextid 2>/dev/null

}

################################################################################
# Get next free private IP (10.2.0.0/16, one octet per VMID) for a new VM
#
# Arguments:
#   ${1} = vmid
#
# Outputs:
#   IP address (e.g. 10.2.0.105)
################################################################################

function proxmox_get_next_vm_ip() {

    local vmid="${1}"

    echo "10.2.0.${vmid}"

}

################################################################################
# Get next free host port for a new SSH NAT forward (PREROUTING DNAT rules)
#
# Arguments:
#   none
#
# Outputs:
#   Port number
################################################################################

function proxmox_get_next_nat_port() {

    local max_port
    max_port="$(iptables -t nat -L PREROUTING -n 2>/dev/null | grep 'to:.*:22$' | grep -oP 'dpt:\K[0-9]+' | sort -n | tail -1)"

    if [[ -z "${max_port}" ]]; then
        echo 23
    else
        echo $((max_port + 1))
    fi

}

################################################################################
# Add a persistent SSH NAT forward: <host_port> -> <vm_ip>:22
#
# Arguments:
#   ${1} = host_port
#   ${2} = vm_ip
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function proxmox_add_ssh_nat_rule() {

    local host_port="${1}"
    local vm_ip="${2}"

    iptables -t nat -A PREROUTING -p tcp --dport "${host_port}" -j DNAT --to-destination "${vm_ip}:22"

    if command -v netfilter-persistent &>/dev/null; then
        netfilter-persistent save &>/dev/null
    fi

    log_event "info" "Added SSH NAT rule: host port ${host_port} -> ${vm_ip}:22" "false"

}

################################################################################
# Download and cache an Ubuntu cloud image for VM provisioning
#
# Arguments:
#   ${1} = ubuntu_codename (default: noble / 24.04)
#
# Outputs:
#   Path to the cached image file
################################################################################

function proxmox_get_cloud_image() {

    local codename="${1:-noble}"

    local cache_dir="/var/lib/vz/template/brolit-cloudimg"
    local image_file="${cache_dir}/${codename}-server-cloudimg-amd64.img"
    local image_url="https://cloud-images.ubuntu.com/${codename}/current/${codename}-server-cloudimg-amd64.img"

    mkdir -p "${cache_dir}"

    if [[ ! -f "${image_file}" ]]; then
        log_event "info" "Downloading Ubuntu ${codename} cloud image" "false"
        display --indent 6 --text "- Downloading Ubuntu ${codename} cloud image"
        curl -fsSL -o "${image_file}" "${image_url}"
        if [[ $? -ne 0 ]]; then
            log_event "error" "Failed to download cloud image from ${image_url}" "false"
            rm -f "${image_file}"
            return 1
        fi
        clear_previous_lines "1"
        display --indent 6 --text "- Downloading Ubuntu ${codename} cloud image" --result "DONE" --color GREEN
    fi

    echo "${image_file}"

}

################################################################################
# Create and start a new VM from an Ubuntu cloud image, with cloud-init
# network config and an injected SSH public key (no password auth).
#
# Arguments:
#   ${1} = vmid
#   ${2} = vm_name
#   ${3} = vm_ip (e.g. 10.2.0.105)
#   ${4} = ssh_pub_key_file (path to a file, one OpenSSH public key per line)
#   ${5} = cores (default: 1)
#   ${6} = memory_mb (default: 1024)
#   ${7} = disk_gb (default: 12)
#
# Outputs:
#   0 if ok, 1 on error
################################################################################

function proxmox_create_vm() {

    local vmid="${1}"
    local vm_name="${2}"
    local vm_ip="${3}"
    local ssh_pub_key_file="${4}"
    local cores="${5:-1}"
    local memory_mb="${6:-1024}"
    local disk_gb="${7:-12}"

    local image_file
    image_file="$(proxmox_get_cloud_image "noble")"
    [[ -z "${image_file}" ]] && return 1

    log_event "info" "Creating VM ${vmid} (${vm_name}) at ${vm_ip}" "false"
    display --indent 6 --text "- Creating VM ${vmid} (${vm_name})"

    qm create "${vmid}" \
        --name "${vm_name}" \
        --memory "${memory_mb}" \
        --cores "${cores}" \
        --cpu host \
        --net0 "virtio,bridge=vmbr1" \
        --scsihw virtio-scsi-pci \
        --serial0 socket \
        --vga serial0 \
        --ostype l26 || return 1

    qm importdisk "${vmid}" "${image_file}" local --format qcow2 || return 1
    qm set "${vmid}" --scsi0 "local:${vmid}/vm-${vmid}-disk-0.qcow2" || return 1
    qm set "${vmid}" --ide2 "local:cloudinit" || return 1
    qm set "${vmid}" --boot order=scsi0 || return 1
    qm set "${vmid}" --ipconfig0 "ip=${vm_ip}/16,gw=10.2.0.1" || return 1
    qm set "${vmid}" --nameserver "8.8.8.8" || return 1
    qm set "${vmid}" --ciuser root || return 1
    qm set "${vmid}" --sshkeys "${ssh_pub_key_file}" || return 1
    qm resize "${vmid}" scsi0 "${disk_gb}G" || return 1

    qm start "${vmid}" || return 1

    display --indent 6 --text "- Creating VM ${vmid} (${vm_name})" --result "DONE" --color GREEN

    return 0

}

################################################################################
# Wait for a freshly-created VM to answer SSH
#
# Arguments:
#   ${1} = vm_ip
#   ${2} = ssh_key_path
#   ${3} = timeout_seconds (default: 180)
#
# Outputs:
#   0 if reachable, 1 on timeout
################################################################################

function proxmox_wait_for_vm_ssh() {

    local vm_ip="${1}"
    local ssh_key_path="${2}"
    local timeout_seconds="${3:-180}"

    local waited=0

    display --indent 6 --text "- Waiting for VM ${vm_ip} to answer SSH"

    while [[ ${waited} -lt ${timeout_seconds} ]]; do
        if ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
            -i "${ssh_key_path}" "root@${vm_ip}" "true" &>/dev/null; then
            clear_previous_lines "1"
            display --indent 6 --text "- Waiting for VM ${vm_ip} to answer SSH" --result "DONE" --color GREEN
            return 0
        fi
        sleep 5
        waited=$((waited + 5))
    done

    clear_previous_lines "1"
    display --indent 6 --text "- Waiting for VM ${vm_ip} to answer SSH" --result "FAIL" --color RED
    return 1

}

################################################################################
# Provision a new VM on this Proxmox node to act as the OpenResty gateway:
# create it, wait for SSH, install brolit-shell + OpenResty on it, register
# a persistent SSH NAT rule, and point this node's brolit config at it.
#
# Arguments:
#   ${1} = vm_name (default: brolit-openresty)
#   ${2} = openresty_install_method (default: official - the plain "apt"
#          method needs OpenResty's own apt repo, which isn't present on a
#          stock Ubuntu image)
#
# Outputs:
#   0 if ok, 1 on error. Prints the new VM's private IP on success.
################################################################################

function proxmox_provision_openresty_vm() {

    local vm_name="${1:-brolit-openresty}"
    local install_method="${2:-official}"

    if ! proxmox_node_detect; then
        log_event "error" "proxmox_provision_openresty_vm: not running on a Proxmox node" "false"
        display --indent 6 --text "- Provisioning OpenResty VM" --result "FAIL" --color RED
        display --indent 8 --text "This is only available when running on a Proxmox VE node" --tcolor RED
        return 1
    fi

    log_subsection "Provisioning OpenResty gateway VM"

    # Ensure the dedicated OpenResty SSH keypair exists before creating the VM,
    # so we can inject its public key via cloud-init and skip password auth
    # entirely (no ssh-copy-id bootstrap needed for a VM we create ourselves).
    local ssh_key ssh_pub
    ssh_key="$(openresty_get_ssh_key)"
    ssh_pub="${ssh_key}.pub"
    if [[ ! -f "${ssh_key}" ]]; then
        mkdir -p "$(dirname "${ssh_key}")"
        chmod 700 "$(dirname "${ssh_key}")"
        ssh-keygen -t ed25519 -N "" -f "${ssh_key}" -C "brolit-openresty-vm" >/dev/null 2>&1
        chmod 600 "${ssh_key}"
        chmod 644 "${ssh_pub}"
    fi

    local vmid vm_ip nat_port
    vmid="$(proxmox_get_next_vmid)"
    if [[ -z "${vmid}" ]]; then
        log_event "error" "Could not determine next free VMID" "false"
        return 1
    fi
    vm_ip="$(proxmox_get_next_vm_ip "${vmid}")"
    nat_port="$(proxmox_get_next_nat_port)"

    display --indent 8 --text "VMID: ${vmid}  IP: ${vm_ip}  SSH port: ${nat_port}" --tcolor YELLOW

    proxmox_create_vm "${vmid}" "${vm_name}" "${vm_ip}" "${ssh_pub}" 1 1024 12
    if [[ $? -ne 0 ]]; then
        log_event "error" "Failed to create VM ${vmid}" "false"
        display --indent 6 --text "- Provisioning OpenResty VM" --result "FAIL" --color RED
        return 1
    fi

    proxmox_wait_for_vm_ssh "${vm_ip}" "${ssh_key}" 180
    if [[ $? -ne 0 ]]; then
        log_event "error" "VM ${vmid} did not come up on SSH in time" "false"
        display --indent 6 --text "- Provisioning OpenResty VM" --result "FAIL" --color RED
        return 1
    fi

    proxmox_add_ssh_nat_rule "${nat_port}" "${vm_ip}"

    # Install brolit-shell + OpenResty on the new VM (running as "local" there
    # - the new VM is the OpenResty target itself, not another delegator).
    display --indent 6 --text "- Installing brolit-shell on the new VM"
    ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -i "${ssh_key}" "root@${vm_ip}" \
        "rm -rf /root/brolit-shell && git clone --quiet https://github.com/gauchocode/brolit-shell.git /root/brolit-shell && chmod +x /root/brolit-shell/runner.sh" >/dev/null 2>&1

    if [[ $? -ne 0 ]]; then
        log_event "error" "Failed to install brolit-shell on VM ${vmid}" "false"
        display --indent 6 --text "- Installing brolit-shell on the new VM" --result "FAIL" --color RED
        return 1
    fi
    display --indent 6 --text "- Installing brolit-shell on the new VM" --result "DONE" --color GREEN

    display --indent 6 --text "- Installing OpenResty on the new VM"
    ssh -o BatchMode=yes -i "${ssh_key}" "root@${vm_ip}" \
        "cd /root/brolit-shell && export BROLIT_MAIN_DIR=/root/brolit-shell && source libs/apps/openresty_helper.sh && source utils/installers/openresty_installer.sh && _openresty_install_local '${install_method}'" >/dev/null 2>&1

    if [[ $? -ne 0 ]]; then
        log_event "error" "Failed to install OpenResty on VM ${vmid}" "false"
        display --indent 6 --text "- Installing OpenResty on the new VM" --result "FAIL" --color RED
        return 1
    fi
    display --indent 6 --text "- Installing OpenResty on the new VM" --result "DONE" --color GREEN

    # The API token was generated on the VM itself during install; fetch it
    # back so this orchestrator can also authenticate against the VM's API
    # (openresty_server_create/_delete etc. read OPENRESTY_API_TOKEN locally).
    local api_token
    api_token="$(ssh -o BatchMode=yes -i "${ssh_key}" "root@${vm_ip}" "cat /usr/local/openresty/nginx/conf/.api_token" 2>/dev/null)"

    # Point this node's brolit config at the new gateway VM
    if [[ -f "${BROLIT_CONFIG_FILE}" ]]; then
        json_write_field "${BROLIT_CONFIG_FILE}" "SERVER_CONFIG.proxmox_mode" "enabled"
        json_write_field "${BROLIT_CONFIG_FILE}" "SERVER_CONFIG.openresty_vm_ip" "${vm_ip}"
        PROXMOX_MODE="enabled"
        OPENRESTY_VM_IP="${vm_ip}"
        if [[ -n "${api_token}" ]]; then
            json_write_field "${BROLIT_CONFIG_FILE}" "SERVER_CONFIG.openresty_api_token" "${api_token}"
            OPENRESTY_API_TOKEN="${api_token}"
        fi
    fi

    display --indent 6 --text "- Provisioning OpenResty VM" --result "DONE" --color GREEN
    display --indent 8 --text "VM ${vmid} (${vm_name}) at ${vm_ip}, SSH via host port ${nat_port}" --tcolor GREEN

    echo "${vm_ip}"
    return 0

}
