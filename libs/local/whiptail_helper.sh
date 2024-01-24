#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.8
################################################################################
#
# Whiptail Helper: whiptail functions.
#
# Ref: https://www.redhat.com/sysadmin/use-whiptail
#
################################################################################

################################################################################
# Whiptail standard message
#
# Arguments:
#  ${1} = {whip_title}
#  ${2} = {whip_message}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function whiptail_message() {

    local whip_title="${1}"
    local whip_message="${2}"

    whiptail --title "${whip_title}" --msgbox "${whip_message}" 15 60 3>&1 1>&2 2>&3
    exitstatus=$?
    [[ ${exitstatus} -eq 0 ]] && return 0 || return 1

}

################################################################################
# Whiptail message with skip option
#
# Arguments:
#  ${1} = {whip_title}
#  ${2} = {whip_message}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function whiptail_message_with_skip_option() {

    local whip_title="${1}"
    local whip_message="${2}"

    whiptail --title "${whip_title}" --yesno "${whip_message}" 15 60 3>&1 1>&2 2>&3
    exitstatus=$?
    [[ ${exitstatus} -eq 0 ]] && return 0
    return 1

}

################################################################################
# Whiptail input
#
# Arguments:
#  ${1} = {whip_title}
#  ${2} = {whip_message}
#
# Outputs:
#  ${whip_return} if ok, 1 on error.
################################################################################

function whiptail_input() {

    local whip_title="${1}"
    local whip_message="${2}"
    local whip_default="${3}"

    local whip_return

    whip_return="$(whiptail --title "${whip_title}" --inputbox "${whip_message}" 15 60 "${whip_default}" 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${whip_return}" && return 0

    else

        # Log
        log_event "error" "Executing: whiptail --title \"${whip_title}\" --inputbox \"${whip_message}\" 15 60 \"${whip_default}\" 3>&1 1>&2 2>&3" "false"

        return 1

    fi

}

################################################################################
# Whiptail selection menu
#
# Arguments:
#  ${1} = {whip_title}
#  ${2} = {whip_message}
#
# Outputs:
#  ${whip_return} if ok, 1 on error.
################################################################################

function whiptail_selection_menu() {

    local whip_title="${1}"
    local whip_message="${2}"
    local whip_options="${3}"
    local default_item="${4}"

    local whip_return

    whip_return="$(whiptail --title "${whip_title}" --menu "${whip_message}" 20 78 10 $(for x in ${whip_options}; do echo "${x}    [X]"; done) --default-item "${default_item}" 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${whip_return}" && return 0

    else

        return 1

    fi

}
