#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.12
################################################################################
#
# System Helper: Perform system actions.
#
################################################################################

################################################################################
# Enable system automatic updates
# Ref:
#   https://www.linuxbabe.com/ubuntu/automatic-security-update-unattended-upgrades-ubuntu
#   https://www.digitalocean.com/community/tutorials/how-to-keep-ubuntu-20-04-servers-updated
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function system_unnatended_upgrades() {

    # Check if unattended-upgrades is enabled on brolit_conf.json
    if [[ ${UNATTENDED_UPGRADES} == "enabled" ]]; then

        # Check if /etc/apt/apt.conf.d/20auto-upgrades exists
        if [[ -f /etc/apt/apt.conf.d/20auto-updates ]]; then

            # Log
            log_event "info" "Unnatended upgrades already configured" "false"
            display --indent 6 --text "- Unnatended upgrades" --result "ENABLED" --color GREEN

            return 0

        else

            # Enable automatic security updates
            package_update
            package_install "unattended-upgrades"
            package_install "update-notifier-common"

            # Uncomment to enable notifications
            sed -i "s#//Unattended-Upgrade::Mail \"\";#Unattended-Upgrade::Mail \"${NOTIFICATION_EMAIL_MAILA}\";#" /etc/apt/apt.conf.d/50unattended-upgrades
            sed -i "s#//Unattended-Upgrade::MailReport \"on-change\";#Unattended-Upgrade::Mail \"only-on-error\";#" /etc/apt/apt.conf.d/50unattended-upgrades
            sed -i "s#//Unattended-Upgrade::Remove-Unused-Dependencies \"false\";#Unattended-Upgrade::Remove-Unused-Dependencies \"true\";#" /etc/apt/apt.conf.d/50unattended-upgrades

            sed -i "s#//Unattended-Upgrade::Automatic-Reboot \"false\";#Unattended-Upgrade::Automatic-Reboot \"true\";#" /etc/apt/apt.conf.d/50unattended-upgrades
            sed -i "s#//Unattended-Upgrade::Automatic-Reboot-Time \"02:00\";#Unattended-Upgrade::Automatic-Reboot-Time \"03:00\";#" /etc/apt/apt.conf.d/50unattended-upgrades

            # Create /etc/apt/apt.conf.d/20auto-upgrades
            touch /etc/apt/apt.conf.d/20auto-upgrades

            # Adding new lines into /etc/apt/apt.conf.d/20auto-upgrades
            echo "APT::Periodic::Update-Package-Lists \"1\";" >>/etc/apt/apt.conf.d/20auto-upgrades
            echo "APT::Periodic::Unattended-Upgrade \"1\";" >>/etc/apt/apt.conf.d/20auto-upgrades

            # Log
            log_event "info" "Unnatended upgrades configured" "false"
            display --indent 6 --text "- Unnatended upgrades" --result "ENABLED" --color GREEN

            return 0

        fi

    else

        # Log
        log_event "info" "Unnatended upgrades not enabled on brolit_conf.json" "false"
        display --indent 6 --text "- Unnatended upgrades" --result "DISABLED" --color YELLOW

    fi

}

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
#   ${1} = ${new_ssh_port}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function system_change_current_ssh_port() {

    local new_ssh_port="${1}"

    local current_ssh_port

    # Log
    log_subsection "Change SSH Port"
    log_event "info" "Trying to change current SSH port" "false"

    # Get current ssh port
    current_ssh_port=$(grep "Port" /etc/ssh/sshd_config | awk -F " " '{print $2}')
    log_event "info" "Current SSH port: ${current_ssh_port}" "false"
    display --indent 6 --text "- Current SSH port: ${current_ssh_port}"

    # Download secure sshd_config
    cp -f "${BROLIT_MAIN_DIR}/config/sshd_config" "/etc/ssh/sshd_config"

    # Change ssh default port
    sed -i "s/Port 22/Port ${new_ssh_port}/" "/etc/ssh/sshd_config"
    log_event "info" "Changes made on /etc/ssh/sshd_config" "false"
    display --indent 6 --text "- Making changes on sshd_config" --result "DONE" --color GREEN

    # Restart ssh service
    service ssh restart

    # Log
    log_event "info" "SSH service restarted" "false"
    display --indent 6 --text "- Restarting ssh service" --result "DONE" --color GREEN
    log_event "info" "New SSH port: ${new_ssh_port}" "false"
    display --indent 8 --text "- New SSH port: ${new_ssh_port}"

}

################################################################################
# Change server hostname
#
# Arguments:
#   ${1} = ${new_hostname}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function system_change_server_hostname() {

    local new_hostname="${1}"

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
#   ${1} = ${ip_address}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function system_detect_ip_version() {

    local ip_address="${1}"

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
#   ${1} = ${floating_IP}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function system_add_floating_IP() {

    local floating_IP="${1}"

    local ubuntu_v

    log_subsection "Adding Floating IP"

    ubuntu_v="$(get_ubuntu_version)"

    log_event "info" "Trying to add ${floating_IP} as floating ip on Ubuntu ${ubuntu_v}" "false"

    if [[ ${ubuntu_v} == "2004" || ${ubuntu_v} == "2204" || ${ubuntu_v} == "2404" ]]; then

        cp "${BROLIT_MAIN_DIR}/config/networking/60-floating-ip.yaml" /etc/netplan/60-floating-ip.yaml
        sed -i "s#your.float.ing.ip#${floating_IP}#" /etc/netplan/60-floating-ip.yaml
        display --indent 6 --text "- Making network config changes" --result "DONE" --color GREEN
        chmod 600 /etc/netplan/*.yaml
        log_event "info" "Permissions updated for Netplan configuration files" "false"

        netplan apply

        log_event "info" "New IP ${floating_IP} added" "false"
        display --indent 6 --text "- Restarting networking service" --result "DONE" --color GREEN
        display --indent 8 --text "New IP ${floating_IP} added"

        return 0

    else

        log_event "error" "This script only works on Ubuntu 24.04, 22.04 or 20.04 ... Exiting" "false"
        display --indent 6 --text "- Making network config changes" --result "FAIL" --color RED
        display --indent 8 --text "This script works on Ubuntu 24.04, 22.04 or 20.04"

        return 1

    fi

    # TODO: reboot prompt
    #log_event "info" "Is recommended reboot, do you want to do it now?" "true"

}
