#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.43
################################################################################
#
# Storage Controller: Controller to upload and download backups.
#
################################################################################

################################################################################
# Upload backup to configured storage (dropbox, ftp, ssh)
#
# Arguments:
#   $1 = {file_to_upload}
#   $2 = {remote_directory}
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function upload_backup() {

    local file_to_upload=$1
    local remote_directory=$2

    # If dropbox enable ...
    dropbox_upload "${file_to_upload}" "${remote_directory}"

}

################################################################################
# Download backup from configured storage (dropbox, ftp, ssh)
#
# Arguments:
#   $1 = {file_to_download}
#   $2 = {remote_directory}
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function download_backup() {

    local file_to_download=$1
    local remote_directory=$2

    # If dropbox enable ...
    dropbox_download "${file_to_download}" "${remote_directory}"

}
