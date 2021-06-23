#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.38
################################################################################

function firewall_allow() {

    sudo ufw --force enable
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https
    sudo ufw allow "Nginx Full"

}

function firewall_fail2ban_status() {

    fail2ban-client status

}

function firewall_fail2ban_restart() {

    systemctl restart fail2ban

}

function firewall_fail2ban_ban_ip() {

    # $1 = IP

    local ip=$1

    fail2ban-client set sshd banip "${ip}"

}

function firewall_fail2ban_unban_ip() {

    # $1 = IP

    local ip=$1

    fail2ban-client set sshd unbanip "${ip}"

}
