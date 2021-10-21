#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.65
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
#  $1 = {whip_title}
#  $2 = {whip_message}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function whiptail_message() {

    local whip_title=$1
    local whip_message=$2

    whiptail --title "${whip_title}" --msgbox "${whip_message}" 15 60 3>&1 1>&2 2>&3
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        return 0

    else
        return 1

    fi

}

################################################################################
# Whiptail message with skip option
#
# Arguments:
#  $1 = {whip_title}
#  $2 = {whip_message}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function whiptail_message_with_skip_option() {

    local whip_title=$1
    local whip_message=$2

    whiptail --title "${whip_title}" --yesno "${whip_message}" 15 60 3>&1 1>&2 2>&3
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        return 0

    else
        return 1

    fi

}

################################################################################
# Whiptail imput
#
# Arguments:
#  $1 = {whip_title}
#  $2 = {whip_message}
#
# Outputs:
#  ${whip_return} if ok, 1 on error.
################################################################################

function whiptail_imput() {

    local whip_title=$1
    local whip_message=$2

    local whip_return

    whip_return="$(whiptail --title "${whip_title}" --inputbox "${whip_message}" 10 60 3>&1 1>&2 2>&3)"
    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Return
        echo "${whip_return}"

    else

        return 1

    fi

}
