#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1
################################################################################
#
# System Helper: Perform system actions.
#
################################################################################

################################################################################
# Timezone configuration
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function system_timezone_configuration() {

    # Configure timezone
    local configured_timezone

    configured_timezone="$(cat /etc/timezone)"

    if [[ "${configured_timezone}" != "${SERVER_TIMEZONE}" ]]; then

        echo "${SERVER_TIMEZONE}" | tee /etc/timezone
        dpkg-reconfigure --frontend noninteractive tzdata

        # Log
        clear_previous_lines "6"
        log_event "info" "Setting Timezone: ${SERVER_TIMEZONE}" "false"
        display --indent 6 --text "- Timezone configuration" --result "DONE" --color GREEN
        display --indent 8 --text "${SERVER_TIMEZONE}"

    fi

}

################################################################################
# Change current ssh port
#
# Arguments:
#   $1 = ${new_ssh_port}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function system_change_current_ssh_port() {

    local new_ssh_port=$1

    local current_ssh_port

    log_subsection "Change SSH Port"
    log_event "info" "Trying to change current SSH port" "false"

    # Get current ssh port
    current_ssh_port=$(grep "Port" /etc/ssh/sshd_config | awk -F " " '{print $2}')
    log_event "info" "Current SSH port: ${current_ssh_port}" "false"
    display --indent 6 --text "- Current SSH port: ${current_ssh_port}"

    # Download secure sshd_config
    cp -f "${SFOLDER}/config/sshd_config" "/etc/ssh/sshd_config"

    # Change ssh default port
    sed -i "s/Port 22/Port ${new_ssh_port}/" "/etc/ssh/sshd_config"
    log_event "info" "Changes made on /etc/ssh/sshd_config" "false"
    display --indent 6 --text "- Making changes on sshd_config" --result "DONE" --color GREEN

    # Restart ssh service
    service ssh restart

    log_event "info" "SSH service restarted" "false"
    display --indent 6 --text "- Restarting ssh service" --result "DONE" --color GREEN

    log_event "info" "New SSH port: ${new_ssh_port}" "false"
    display --indent 8 --text "- New SSH port: ${new_ssh_port}"

}

################################################################################
# Change server hostname
#
# Arguments:
#   $1 = ${new_hostname}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function system_change_server_hostname() {

    local new_hostname=$1

    local cur_hostname

    log_subsection "Change Hostname"

    cur_hostname="$(cat /etc/hostname)"

    # Display the current hostname
    log_event "info" "Current hostname: ${cur_hostname}" "false"
    display --indent 6 --text "- Current hostname: ${cur_hostname}"

    # Change the hostname
    hostnamectl set-hostname "${new_hostname}"
    hostname "${new_hostname}"

    # Change hostname in /etc/hosts & /etc/hostname
    sed -i "s/${cur_hostname}/${new_hostname}/g" /etc/hosts
    sed -i "s/${cur_hostname}/${new_hostname}/g" /etc/hostname

    # Display new hostname
    log_event "info" "New hostname: ${new_hostname}" "false"
    display --indent 6 --text "- Changing hostname" --result "DONE" --color GREEN
    display --indent 8 --text "New hostname: ${new_hostname}"

}

################################################################################
# Detect IP version
#
# Arguments:
#   $1 = ${ip_address}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function system_detect_ip_version() {

    local ip_address=$1

    local ip_version

    log_subsection "Detect IP Version"

    # Detect IP version
    if [[ "${ip_address}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        ip_version="IPv4"
    elif [[ "${ip_address}" =~ ^[0-9a-fA-F]{1,4}\:[0-9a-fA-F]{1,4}\:[0-9a-fA-F]{1,4}\:[0-9a-fA-F]{1,4}$ ]]; then
        ip_version="IPv6"
    else
        ip_version="UNKNOWN"
    fi

    # Display IP version
    log_event "info" "IP version: ${ip_version}" "false"
    display --indent 6 --text "- Getting IP version" --result "${ip_version}" --color GREEN

}

################################################################################
# Add floating IP
#
# Arguments:
#   $1 = ${floating_IP}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function system_add_floating_IP() {

    local floating_IP=$1

    local ubuntu_v

    ubuntu_v="$(get_ubuntu_version)"

    log_subsection "Adding Floating IP"
    log_event "info" "Trying to add ${floating_IP} as floating ip on Ubuntu ${ubuntu_v}" "false"

    if [[ "${ubuntu_v}" == "1804" ]]; then

        cp "${SFOLDER}/config/networking/60-my-floating-ip.cfg" /etc/network/interfaces.d/60-my-floating-ip.cfg
        sed -i "s#your.float.ing.ip#${floating_IP}#" /etc/network/interfaces.d/60-my-floating-ip.cfg
        display --indent 6 --text "- Making network config changes" --result "DONE" --color GREEN

        service networking restart

        log_event "info" "New IP ${floating_IP} added" "false"
        display --indent 6 --text "- Restarting networking service" --result "DONE" --color GREEN
        display --indent 8 --text "New IP ${floating_IP} added"

        return 0

    else

        if [[ "${ubuntu_v}" == "2004" ]]; then

            cp "${SFOLDER}/config/networking/60-floating-ip.yaml" /etc/netplan/60-floating-ip.yaml
            sed -i "s#your.float.ing.ip#${floating_IP}#" /etc/netplan/60-floating-ip.yaml
            display --indent 6 --text "- Making network config changes" --result "DONE" --color GREEN

            netplan apply

            log_event "info" "New IP ${floating_IP} added" "false"
            display --indent 6 --text "- Restarting networking service" --result "DONE" --color GREEN
            display --indent 8 --text "New IP ${floating_IP} added"

            return 0

        else

            log_event "error" "This script only works on Ubuntu 20.04 or 18.04 ... Exiting" "false"
            display --indent 6 --text "- Making network config changes" --result "FAIL" --color RED
            display --indent 8 --text "This script works on Ubuntu 20.04 or 18.04"

            return 1

        fi

    fi

    # TODO: reboot prompt
    #log_event "info" "Is recommended reboot, do you want to do it now?" "true"

}