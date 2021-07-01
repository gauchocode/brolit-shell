#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.40
################################################################################
#
# Firewall Helper: Perform firewall actions.
#
# Refs: https://linuxize.com/post/how-to-setup-a-firewall-with-ufw-on-ubuntu-20-04/
#       https://linuxize.com/post/install-configure-fail2ban-on-ubuntu-20-04/
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

    ufw allow "${service}"

}

################################################################################
# Allow basic services on firewall
#
# Arguments:
#   None
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function firewall_allow_basic_services() {

    ufw allow ssh
    ufw allow http
    ufw allow https
    ufw allow "Nginx Full"

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

    fail2ban-client status

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
