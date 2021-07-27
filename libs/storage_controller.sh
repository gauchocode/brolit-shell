#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.50
################################################################################
#
# Storage Controller: Controller to upload and download backups.
#
################################################################################

################################################################################
#
# Important: Backup/Restore utils selection.
#
#   Backup Uploader: 
#       Simple way to upload backup file to this cloud service.
#
#   Rclone: 
#       Good way to store backups on a SFTP Server and cloud services.
#       Option to "sync" files. 
#       Read: https://forum.rclone.org/t/incremental-backups-and-efficiency-continued/10763
#
#   Duplicity:
#       Best way to backup projects of 10GBs+. Incremental backups.
#       Need to use SFTP option (non native cloud services support).
#       Read: https://zertrin.org/how-to/installation-and-configuration-of-duplicity-for-encrypted-sftp-remote-backup/
#
################################################################################

################################################################################
# Create directory (dropbox, sftp, etc)
#
# Arguments:
#   $1 = {file_to_download}
#   $2 = {remote_directory}
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function sc_create_dir() {

    local remote_directory=$1

    if [[ ${DROPBOX_ENABLE} == "true" ]]; then

        dropbox_create_dir "${remote_directory}"

    fi
    if [[ ${RCLONE_ENABLE} == "true" ]]; then

        rclone_create_dir "${remote_directory}"

    fi

}

################################################################################
# Upload backup to configured storage (dropbox, sftp, etc)
#
# Arguments:
#   $1 = {file_to_upload}
#   $2 = {remote_directory}
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function sc_upload_backup() {

    local file_to_upload=$1
    local remote_directory=$2

    if [[ ${DROPBOX_ENABLE} == "true" ]]; then

        dropbox_upload "${file_to_upload}" "${remote_directory}"

    fi
    if [[ ${RCLONE_ENABLE} == "true" ]]; then

        rclone_upload "${file_to_upload}" "${remote_directory}"

    fi

}

################################################################################
# Download backup from configured storage (dropbox, sftp, etc)
#
# Arguments:
#   $1 = {file_to_download}
#   $2 = {remote_directory}
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function sc_download_backup() {

    local file_to_download=$1
    local remote_directory=$2

    if [[ ${DROPBOX_ENABLE} == "true" ]]; then

        dropbox_download "${file_to_download}" "${remote_directory}"

    fi
    if [[ ${RCLONE_ENABLE} == "true" ]]; then

        rclone_download "${file_to_download}" "${remote_directory}"

    fi

}
