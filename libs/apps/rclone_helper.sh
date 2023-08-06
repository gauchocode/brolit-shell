#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.2
################################################################################

################################################################################
# Generate configuration file
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function rclone_generate_config() {

    # Rclone configuration wizard
    rclone config

    # Read configured remote name
    rclone_read_config

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

function rclone_read_config() {

    declare -g REMOTE_NAME

    local rclone_config
    local rclone_config_file

    rclone_config_file="/root/.config/rclone/rclone.conf"

    rclone_config="$(cat "${rclone_config_file}")"

    REMOTE_NAME="$(echo "${rclone_config}" | cut -d "[" -f2 | cut -d "]" -f1)"

    if [[ ${REMOTE_NAME} != "" ]]; then

        export REMOTE_NAME

    else

        log_event "error" "SOMETHING WENT WRONG GETTING RCLONE REMOTE NAME" "true"

    fi

}

################################################################################
# Create directory on rclone remote host
#
# Arguments:
#   ${1} = ${remote_directory}
#
# Outputs:
#   nothing
################################################################################

function rclone_create_dir() {

    local remote_directory="${1}"

    # Create Backup Dir
    rclone mkdir "${REMOTE_NAME}:${remote_directory}"

}

################################################################################
# Upload backup from rclone remote host
#
# Arguments:
#   ${1} = ${file_to_upload} (entire file path)
#   ${2} = ${remote_directory}
#
# Outputs:
#   nothing
################################################################################

# TODO: https://forum.rclone.org/t/can-i-use-min-age-to-retain-backups-for-xx-days/4946

function rclone_upload() {

    local file_to_upload="${1}"
    local remote_directory="${2}"

    # Sync backup
    rclone sync "${file_to_upload}" "${REMOTE_NAME}:${remote_directory}" --progress

}

################################################################################
# Download backup from rclone remote host
#
# Arguments:
#   ${1} = ${file_to_download} (entire file path)
#   ${2} = ${remote_directory}
#
# Outputs:
#   nothing
################################################################################

function rclone_download() {

    local file_to_download="${1}"
    local remote_directory="${2}"

    # Download backup
    rclone copy "${REMOTE_NAME}:${remote_directory}/${file_to_download}" "${BROLIT_TMP_DIR}" -P

}
