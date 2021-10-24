#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.68-beta
################################################################################
#
# Firewall Helper: Perform firewall actions.
#
# Refs: https://linuxize.com/post/how-to-setup-a-firewall-with-ufw-on-ubuntu-20-04/
#       https://linuxize.com/post/install-configure-fail2ban-on-ubuntu-20-04/
#       https://community.hetzner.com/tutorials/simple-firewall-management-with-ufw
#
################################################################################

################################################################################
# Enable firewall
#
# Arguments:
#   None
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function firewall_enable() {

    ufw --force enable

}

################################################################################
# Disable firewall
#
# Arguments:
#   None
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function firewall_disable() {

    ufw --force disable

}

################################################################################
# Firewall app list
#
# Arguments:
#   None
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function firewall_app_list() {

    ufw app list

}

################################################################################
# Firewall status
#
# Arguments:
#   None
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function firewall_status() {

    ufw status verbose

}

################################################################################
# Allow specific services on firewall.
#
# Arguments:
#   $1 = ${service}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function firewall_allow() {

    local service=$1

    # Ufw command
    ufw_output="$(ufw allow "${service}")"

    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        if [[ ${ufw_output} == *"existing"* ]]; then

            # Log
            log_event "info" "Allowing ${service} on firewall" "false"
            log_event "info" "Skipping adding existing rule" "false"
            display --indent 2 --text "Allowing ${service} on firewall" --result "SKIP" --color YELLOW
            display --indent 4 --text "Skipping adding existing rule"

        else

            # Log
            log_event "info" "Allowing ${service} on firewall" "false"
            display --indent 2 --text "Allowing ${service} on firewall" --result "DONE" --color GREEN

        fi

    else

        # Log
        log_event "error" "Allowing ${service} on firewall" "false"
        display --indent 2 --text "Allowing ${service} on firewall" --result "FAIL" --color RED

        return 1
    fi

}

################################################################################
# Fail2ban status
#
# Arguments:
#   None
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function firewall_fail2ban_status() {

    local service=$1

    fail2ban-client status "${service}"

}

################################################################################
# Fail2ban service restart
#
# Arguments:
#   None
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function firewall_fail2ban_restart() {

    systemctl restart fail2ban

}

################################################################################
# Fail2ban ban IP
#
# Arguments:
#   $1 = IP
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function firewall_fail2ban_ban_ip() {

    local ip=$1

    fail2ban-client set sshd banip "${ip}"

}

################################################################################
# Fail2ban unban IP
#
# Arguments:
#   $1 = IP
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function firewall_fail2ban_unban_ip() {

    local ip=$1

    fail2ban-client set sshd unbanip "${ip}"

}
