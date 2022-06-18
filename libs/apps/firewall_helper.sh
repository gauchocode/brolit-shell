#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc9
################################################################################
#
# Firewall Helper: Perform firewall actions.
#
# Refs: https://linuxize.com/post/how-to-setup-a-firewall-with-ufw-on-ubuntu-20-04/
#       https://linuxize.com/post/install-configure-fail2ban-on-ubuntu-20-04/
#       https://community.hetzner.com/tutorials/simple-firewall-management-with-ufw/
#       https://www.linode.com/docs/guides/using-fail2ban-to-secure-your-server-a-tutorial/
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

    # Ufw command
    ufw_output="$(ufw --force enable)"

    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        FIREWALL_UFW_STATUS="enabled"

        json_write_field "${BROLIT_CONFIG_FILE}" "FIREWALL.ufw[].status" "${FIREWALL_UFW_STATUS}"

        # new global value ("enabled")
        export FIREWALL_UFW_STATUS

        # Log
        log_event "info" "Activating firewall" "false"
        display --indent 6 --text "- Activating firewall" --result "DONE" --color GREEN
        display --indent 8 --text "${ufw_output}"

        return 0

    else

        # Log
        log_event "error" "Activating firewall" "false"
        display --indent 6 --text "- Activating firewall" --result "FAIL" --color RED
        display --indent 8 --text "${ufw_output}"

        return 1

    fi

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

    ufw_output="$(ufw --force disable)"

    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        FIREWALL_UFW_STATUS="disabled"

        json_write_field "${BROLIT_CONFIG_FILE}" "FIREWALL.ufw[].status" "${FIREWALL_UFW_STATUS}"

        # new global value ("enabled")
        export FIREWALL_UFW_STATUS

        # Log
        log_event "info" "Deactivating firewall" "false"
        display --indent 6 --text "- Deactivating firewall" --result "DONE" --color GREEN
        display --indent 8 --text "${ufw_output}"

        return 0

    else

        # Log
        log_event "error" "Deactivating firewall" "false"
        display --indent 6 --text "- Deactivating firewall" --result "FAIL" --color RED
        display --indent 8 --text "${ufw_output}"

        return 1

    fi

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
#   0 if is active, 1 on error.
################################################################################

function firewall_status() {

    # Ufw commands
    ufw_output="$(ufw status verbose)"
    ufw_status="$(ufw status | sed -n '1 p' | cut -d " " -f 2 | sed -z 's/\n//g')"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        if [[ ${ufw_status} == "active" ]]; then

            # Log
            log_event "info" "Firewall status: ${ufw_status}" "false"
            log_event "debug" "ufw status verbose ouput: ${ufw_output}" "false"

            return 0

        else

            # Log
            log_event "info" "Firewall status: ${ufw_status}" "false"
            log_event "debug" "ufw status verbose ouput: ${ufw_output}" "false"
            display --indent 6 --text "- Getting firewall status" --result "INACTIVE" --color YELLOW

            return 1

        fi

    else

        # Log
        log_event "error" "Getting firewall status" "false"
        display --indent 6 --text "- Getting firewall status" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Allow specific services on firewall.
#
# Arguments:
#   $1 = ${service} - service or port
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function firewall_allow() {

    local service="${1}"

    local ufw_output

    # ufw command
    ufw_output="$(ufw allow "${service}")"

    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        # Change brolit_conf.json
        json_write_field "${BROLIT_CONFIG_FILE}" "FIREWALL.ufw[].config[].${service}" "allow"

        if [[ ${ufw_output} == *"existing"* ]]; then

            # Log
            log_event "info" "Allowing ${service} on firewall" "false"
            log_event "info" "Skipping adding existing rule" "false"
            #display --indent 2 --text "- Allowing ${service} on firewall" --result "SKIP" --color YELLOW
            #display --indent 4 --text "Skipping adding existing rule"

            return 0

        else

            # Log
            log_event "info" "Allowing ${service} on firewall" "false"
            display --indent 6 --text "- Allowing ${service} on firewall" --result "DONE" --color GREEN

            return 0

        fi

    else

        # Log
        log_event "error" "Allowing ${service} on firewall" "false"
        display --indent 6 --text "- Allowing ${service} on firewall" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Deny specific services on firewall.
#
# Arguments:
#   $1 = ${service}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function firewall_deny() {

    local service="${1}"

    # ufw command
    ufw_output="$(ufw deny "${service}")"

    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        # Change brolit_conf.json
        json_write_field "${BROLIT_CONFIG_FILE}" "FIREWALL.ufw[].config[].${service}" "deny"

        if [[ ${ufw_output} == *"existing"* ]]; then

            # Log
            log_event "info" "Denying ${service} on firewall" "false"
            log_event "info" "Skipping adding existing rule" "false"
            #display --indent 2 --text "- Denying ${service} on firewall" --result "SKIP" --color YELLOW
            #display --indent 4 --text "Skipping adding existing rule"

            return 0

        else

            # Log
            log_event "info" "Denying ${service} on firewall" "false"
            display --indent 6 --text "- Denying ${service} on firewall" --result "DONE" --color GREEN

            return 0

        fi

    else

        # Log
        log_event "error" "Denying ${service} on firewall" "false"
        display --indent 6 --text "- Denying ${service} on firewall" --result "FAIL" --color RED

        return 1

    fi

}

################################################################################
# Fail2ban status
#
# Arguments:
#   $1 = {service} - Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function firewall_fail2ban_status() {

    local service="${1}"

    local fail2ban_output

    # Fail2ban command
    fail2ban_output="$(fail2ban-client status "${service}" >/dev/null)"

    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        log_event "info" "Getting fail2ban status" "false"
        display --indent 6 --text "- Getting fail2ban status" --result "DONE" --color GREEN
        display --indent 8 --text "Status: ${fail2ban_output}"

        return 0

    else

        # Log
        log_event "error" "Getting fail2ban status" "false"
        display --indent 6 --text "- Getting fail2ban status" --result "FAIL" --color RED

        return 1

    fi

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

    local ip="${1}"

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

    local ip="${1}"

    fail2ban-client set sshd unbanip "${ip}"

}
