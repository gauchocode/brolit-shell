#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.4
################################################################################
#
# Ref: https://github.com/wordfence/wordfence-cli
#

################################################################################
# Write Worfence-cli license file
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function wordfencecli_write_license() {

    local wordfencecli_license_key="${1}"

    declare -g WORDFENCECLI_LICENSE

    local wordfencecli_license_file

    wordfencecli_license_file="/root/.config/wordfence/wordfence-cli.ini"

    if [[ ${wordfencecli_license_key} != "" ]]; then

        echo "${wordfencecli_license_key}" > ${wordfencecli_license_file}

    else

        log_event "error" "SOMETHING WENT WRONG WRITTING WORDFENCECLI LICENSE" "true"

    fi

}

################################################################################
# Read remote name from configuration file
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function wordfencecli_read_license() {

    declare -g WORDFENCECLI_LICENSE

    local wordfencecli_license_file

    wordfencecli_license_file="/root/.config/wordfence/wordfence-cli.ini"

    WORDFENCECLI_LICENSE="$(cat "${wordfencecli_license_file}")"

    if [[ ${REMOTE_NAME} != "" ]]; then

        export WORDFENCECLI_LICENSE

    else

        log_event "error" "SOMETHING WENT WRONG GETTING WORDFENCECLI LICENSE" "true"

    fi

}

################################################################################
# Malware scan directory with wordfence-cli
#
# Arguments:
#   ${1} = ${directory_to_scan}
#   ${2} = ${include_all_files} - true or false
#
# Outputs:
#   nothing
################################################################################

function wordfencecli_malware_scan() {

    local directory_to_scan="${1}"
    local include_all_files="${2}"

    local scan_option

    if [[ $include_all_files == "true" ]]; then
        local scan_option="--include-all-files"
    else
        local scan_option=""
    fi

    # Malware Scan command
    docker run -v /var/www:/var/www wordfence-cli:latest malware-scan ${scan_option} --license $(cat /root/.config/wordfence/wordfence-cli.ini) "${directory_to_scan}"

}

################################################################################
# Vulnerabilities scan directory with wordfence-cli
#
# Arguments:
#   ${1} = ${directory_to_scan}
#   ${2} = ${include_all_files} - true or false
#
# Outputs:
#   nothing
################################################################################

function wordfencecli_vulnerabilities_scan() {

    local directory_to_scan="${1}"
    local include_all_files="${2}"

    local scan_option

    if [[ $include_all_files == "true" ]]; then
        local scan_option="--include-all-files"
    else
        local scan_option=""
    fi

    # Vulnerabilities Scan command
    docker run -v /var/www:/var/www wordfence-cli:latest vuln-scan ${scan_option} --license $(cat /root/.config/wordfence/wordfence-cli.ini) "${directory_to_scan}"

}