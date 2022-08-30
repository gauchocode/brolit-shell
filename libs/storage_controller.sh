#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2.1
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
# List directory content
#
# Arguments:
#   $1 = {remote_directory}
#
# Outputs:
#   ${remote_list}
################################################################################

function storage_list_dir() {

    local remote_directory="${1}"

    local remote_list

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        # Dropbox API returns files names on the third column
        remote_list="$("${DROPBOX_UPLOADER}" -hq list "${remote_directory}" | awk '{print $3;}')"

        # If remote_list is empty, try to check the second column where directory names are
        if [[ -z ${remote_list} ]]; then

            remote_list="$("${DROPBOX_UPLOADER}" -hq list "${remote_directory}" | awk '{print $2;}')"

        fi

        # Log
        log_event "info" "Listing directory: ${remote_directory}" "false"
        log_event "info" "Remote list: ${remote_list}" "false"
        log_event "debug" "Command executed: ${DROPBOX_UPLOADER} -hq list \"${remote_directory}\" | awk '{print $ 3;}'" "false"

    fi
    if [[ ${BACKUP_LOCAL_STATUS} == "enabled" ]]; then

        remote_list="$(ls "${remote_directory}")"

        # Log
        log_event "info" "Listing directory: ${remote_directory}" "false"
        log_event "info" "Remote list: ${remote_list}" "false"
        log_event "debug" "Command executed: ls ${remote_directory}" "false"

    fi

    storage_result=$?
    if [[ ${storage_result} -eq 0 && -n ${remote_list} ]]; then
        echo "${remote_list}"
    else
        return 1
    fi

}

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

function storage_create_dir() {

    local remote_directory="${1}"

    local storage_result

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        dropbox_create_dir "${remote_directory}"

    fi
    if [[ ${BACKUP_LOCAL_STATUS} == "enabled" ]]; then

        mkdir --force "${BACKUP_LOCAL_CONFIG_BACKUP_PATH}/${remote_directory}"

    fi

    storage_result=$?
    [[ ${storage_result} -eq 1 ]] && return 1

}

################################################################################
# Move files or directory
#
# Arguments:
#   $1 = {to_move}
#   $2 = {destination}
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function storage_move() {

    local to_move="${1}"
    local destination="${2}"

    local dropbox_output
    local storage_result

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        dropbox_output="$(${DROPBOX_UPLOADER} move "${to_move}" "${destination}" 2>&1)"

        # TODO: if destination folder already exists, it will fail
        display --indent 6 --text "- Moving files to offline-projects on Dropbox" --result "DONE" --color GREEN

    fi
    if [[ ${BACKUP_LOCAL_STATUS} == "enabled" ]]; then

        move_files "${to_move}" "${destination}"

    fi

    storage_result=$?
    if [[ ${storage_result} -eq 1 ]]; then

        # Log
        log_event "error" "Moving files to offline-projects on Dropbox" "false"
        log_event "debug" "${DROPBOX_UPLOADER} move ${to_move} ${destination}" "false"
        log_event "debug" "dropbox_uploader output: ${dropbox_output}" "false"
        display --indent 6 --text "- Moving files to offline-projects on Dropbox" --result "FAIL" --color RED
        display --indent 8 --text "Please move files running: ${DROPBOX_UPLOADER} move ${to_move} ${destination}" --tcolor RED

        return 1

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

function storage_upload_backup() {

    local file_to_upload="${1}"
    local remote_directory="${2}"

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        dropbox_upload "${file_to_upload}" "${remote_directory}"

    fi
    if [[ ${BACKUP_LOCAL_STATUS} == "enabled" ]]; then

        # New folder
        #mkdir --force "${remote_directory}/${backup_type}"

        # New folder with $project_name
        #mkdir --force "${remote_directory}/${backup_type}/${project_name}"

        log_event "info" "Uploading backup to local storage..." "false"
        log_event "debug" "Running:  rsync --recursive  \"${file_to_upload}\" \"${BACKUP_LOCAL_CONFIG_BACKUP_PATH}/${remote_directory}\"" "false"

        rsync --recursive "${file_to_upload}" "${BACKUP_LOCAL_CONFIG_BACKUP_PATH}/${remote_directory}"

        # TODO: check if files need to be compressed (maybe an option?).

    fi

    storage_result=$?
    [[ ${storage_result} -eq 1 ]] && return 1

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

function storage_download_backup() {

    local file_to_download="${1}"
    local remote_directory="${2}"

    local download_result

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        dropbox_download "${file_to_download}" "${remote_directory}"

    fi
    if [[ ${BACKUP_RCLONE_STATUS} == "enabled" ]]; then

        rclone_download "${file_to_download}" "${remote_directory}"

    fi

    download_result=$?s
    [[ ${download_result} -eq 1 ]] && return 1

}

################################################################################
# Delete backup to configured storage (dropbox, sftp, etc)
#
# Arguments:
#   $1 = {file_to_delete}
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function storage_delete_backup() {

    local file_to_delete="${1}"

    local delete_result

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        dropbox_delete "${file_to_delete}" "false"

    fi
    if [[ ${BACKUP_LOCAL_STATUS} == "enabled" ]]; then

        rm --recursive --force "${file_to_delete}"

        # TODO: check if files need to be compressed (maybe an option?).

    fi

    delete_result=$?
    [[ ${delete_result} -eq 1 ]] && return 1

}
