#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.5
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
#   ${1} = {remote_directory}
#
# Outputs:
#   ${remote_list}
################################################################################

function storage_list_dir() {

    local remote_directory="${1}"

    local remote_list

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        # Dropbox API returns files names on the third column
        remote_list="$(dropbox_list_directory "${remote_directory}")"

        storage_result=$?

    fi
    if [[ ${BACKUP_LOCAL_STATUS} == "enabled" ]]; then

        remote_list="$(ls "${remote_directory}")"

        storage_result=$?

        # Log
        log_event "info" "Listing directory: ${remote_directory}" "false"
        log_event "info" "Remote list: ${remote_list}" "false"
        log_event "debug" "Command executed: ls ${remote_directory}" "false"

    fi

    if [[ ${storage_result} -eq 0 && -n ${remote_list} ]]; then

        echo "${remote_list}" && return 0

    else

        return 1

    fi

}

################################################################################
# Create directory (dropbox, sftp, etc)
#
# Arguments:
#   ${1} = {file_to_download}
#   ${2} = {remote_directory}
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
    if [[ ${BACKUP_BORG_STATUS} == "enabled" ]]; then

        ssh -p "${BORG_SSH_PORT}" "${BORG_SSH_USER}@${BORG_SSH_HOST}" "mkdir --parent ${remote_directory}"

    fi

    storage_result=$?
    [[ ${storage_result} -eq 1 ]] && return 1

}

################################################################################
# Move files or directory
#
# Arguments:
#   ${1} = {to_move}
#   ${2} = {destination}
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
#   ${1} = {file_to_upload}
#   ${2} = {remote_directory}
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function storage_upload_backup() {

    local file_to_upload="${1}"
    local remote_directory="${2}"

    local got_error=0
    local error_type

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        dropbox_upload "${file_to_upload}" "${remote_directory}"

        [[ $? -eq 1 ]] && error_type="dropbox" && got_error=1

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

        [[ $? -eq 1 ]] && error_type="rsync,${error_type}" && got_error=1

    fi

    [[ ${error_type} != "none" ]] && echo "${error_type}"

    return ${got_error}

}

################################################################################
# Download backup from configured storage (dropbox, sftp, etc)
#
# Arguments:
#   ${1} = {file_to_download}
#   ${2} = {remote_directory}
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function storage_download_backup() {

    local file_to_download="${1}"
    local remote_directory="${2}"

    local got_error=0
    local error_type="none"

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        dropbox_download "${file_to_download}" "${remote_directory}"
        [[ $? -eq 1 ]] && error_type="dropbox" && got_error=1

    fi

    [[ ${error_type} != "none" ]] && echo "${error_type}"

    return ${got_error}
}

################################################################################
# Delete backup to configured storage (dropbox, sftp, etc)
#
# Arguments:
#   ${1} = {file_to_delete}
#
# Outputs:
#   0 on success, 1 on error.
################################################################################

function storage_delete_backup() {

    local file_to_delete="${1}"
    #local force_delete="${2}" # or should be a global var?

    local force_delete="true"

    local got_error=0
    #local error_msg="none"
    local error_type="none"

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        dropbox_delete "${file_to_delete}" "${force_delete}"
        [[ $? -eq 1 ]] && error_type="dropbox" && got_error=1

    fi
    if [[ ${BACKUP_LOCAL_STATUS} == "enabled" ]]; then

        rm --recursive --force "${file_to_delete}"
        # TODO: check if files need to be compressed (maybe an option?).
        [[ $? -eq 1 ]] && error_type="rsync" && got_error=1

    fi

    [[ ${error_type} != "none" ]] && echo "${error_type}"

    return ${got_error}

}

################################################################################
# Delete old backups on configured storage (dropbox, sftp, etc)
#
# Arguments:
#   ${1} = {storage_path}
#
# Outputs:
#   0 on success, 1 on error.
################################################################################

function storage_delete_old_backups() {

    local storage_path="${1}"

    # Configuration for backup retention
    local keep_daily=${BACKUP_RETENTION_KEEP_DAILY}
    local keep_weekly=${BACKUP_RETENTION_KEEP_WEEKLY}
    local keep_monthly=${BACKUP_RETENTION_KEEP_MONTHLY}

    # List all storage backups
    backup_list="$(storage_list_dir "${storage_path}")"

    # Delete old storage backups
    ## Transform backup_list into comma separated list
    backup_list="$(echo "${backup_list}" | tr '\n' ',')"

    # Log
    log_event "info" "Preparing to delete old backups" "false"
    display --indent 6 --text "- Preparing to delete old backups" --result "DONE" --color GREEN

    # Convert the string to an array
    IFS=',' read -ra filenames <<<"$backup_list"

    # Arrays to hold various types of backups
    declare -a daily_backups
    declare -a weekly_backups
    declare -a monthly_backups

    # Categorize backups into daily, weekly, and monthly
    for i in "${filenames[@]}"; do
        if [[ $i == *"-weekly"* ]]; then
            weekly_backups+=("$i")
        elif [[ $i == *"-monthly"* ]]; then
            monthly_backups+=("$i")
        else
            daily_backups+=("$i")
        fi
    done

    # Sort the arrays
    sorted_daily=($(printf '%s\n' "${daily_backups[@]}" | sort -r))
    sorted_weekly=($(printf '%s\n' "${weekly_backups[@]}" | sort -r))
    sorted_monthly=($(printf '%s\n' "${monthly_backups[@]}" | sort -r))

    # Log
    log_event "debug" "Daily backups: ${sorted_daily[@]}" "false"
    log_event "debug" "Weekly backups: ${sorted_weekly[@]}" "false"
    log_event "debug" "Monthly backups: ${sorted_monthly[@]}" "false"

    # Log
    display --indent 6 --text "- Deleting old files from Dropbox"

    # Delete old daily backups
    if [ ${#sorted_daily[@]} -gt $keep_daily ]; then
        to_delete_daily=("${sorted_daily[@]:$keep_daily}")
        for i in "${to_delete_daily[@]}"; do
            storage_delete_backup "${storage_path}/${i}"
        done
    fi

    # Delete old weekly backups
    if [ ${#sorted_weekly[@]} -gt $keep_weekly ]; then
        to_delete_weekly=("${sorted_weekly[@]:$keep_weekly}")
        for i in "${to_delete_weekly[@]}"; do
            storage_delete_backup "${storage_path}/${i}"
        done
    fi

    # Delete old monthly backups
    if [ ${#sorted_monthly[@]} -gt $keep_monthly ]; then
        to_delete_monthly=("${sorted_monthly[@]:$keep_monthly}")
        for i in "${to_delete_monthly[@]}"; do
            storage_delete_backup "${storage_path}/${i}"
        done
    fi

    # Log
    clear_previous_lines "1"
    display --indent 6 --text "- Deleting old files from Dropbox" --result "DONE" --color GREEN

}

################################################################################
# Remote Server list from storage.
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function storage_remote_server_list() {

    local remote_server_list # list servers directories
    local chosen_server      # whiptail var

    # Server selection
    remote_server_list="$(storage_list_dir "/")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Re-order Backup Directories
        remote_server_list="$(sort_array_alphabetically "${remote_server_list}")"

        # Show output
        chosen_server="$(whiptail --title "BACKUP SELECTION" --menu "Choose a server to work with" 20 78 10 $(for x in ${remote_server_list}; do echo "${x} [D]"; done) --default-item "${SERVER_NAME}" 3>&1 1>&2 2>&3)"

        exitstatus=$?
        if [[ ${exitstatus} -eq 0 ]]; then

            log_event "debug" "chosen_server: ${chosen_server}" "false"

            echo "${chosen_server}" && return 0

        else

            return 1

        fi

    else

        log_event "error" "Storage list dir failed. Output: ${remote_server_list}. Exit status: ${exitstatus}" "false"

        return 1

    fi

}

################################################################################
# Remote Type list from storage.
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function storage_remote_type_list() {

    local remote_type_list
    local chosen_restore_type

    # List options
    remote_type_list="project site database" # TODO: need to implement "other"

    chosen_restore_type="$(whiptail --title "BACKUP SELECTION" --menu "Choose a backup type. You can choose restore an entire project or only site files, database or config." 20 78 10 $(for x in ${remote_type_list}; do echo "${x} [D]"; done) 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        echo "${chosen_restore_type}" && return 0

    else

        return 1

    fi

}

################################################################################
# Remote Status list from storage.
#
# Arguments:
#   none
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function storage_remote_status_list() {

    local remote_status_list
    local chosen_restore_status

    log_event "debug" "Backup status selection" "false"

    # List options
    remote_status_list=("01) Online 02) Offline")

    chosen_restore_status="$(whiptail --title "BACKUP SELECTION" --menu "Choose the backup status:" 20 78 10 $(for x in ${remote_status_list}; do echo "${x}"; done) 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        if [[ ${chosen_restore_status} == *"01"* ]]; then
            log_event "debug" "chosen_restore_status: online" "false"
            echo "online" && return 0
        fi

        if [[ ${chosen_restore_status} == *"02"* ]]; then
            log_event "debug" "chosen_restore_status: offline" "false"
            echo "offline" && return 0
        fi

    else

        log_event "debug" "Backup status selection skipped." "false"

        return 1

    fi

}

################################################################################
# Storage Backup selection
#
# Arguments:
#   ${1} = ${remote_backup_path}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function storage_backup_selection() {

    local remote_backup_path="${1}"
    local remote_backup_type="${2}"

    local storage_project_list
    local chosen_project
    local remote_backup_path
    local remote_backup_list
    local chosen_backup_file

    # Get dropbox folders list
    storage_project_list="$(storage_list_dir "${remote_backup_path}/${remote_backup_type}")"

    # Re-order Backup Directories
    storage_project_list="$(sort_array_alphabetically "${storage_project_list}")"

    # Select Project
    chosen_project="$(whiptail --title "BACKUP SELECTION" --menu "Choose a Project Backup to work with:" 20 78 10 $(for x in ${storage_project_list}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
        # Get backup list
        remote_backup_path="${remote_backup_path}/${remote_backup_type}/${chosen_project}"
        remote_backup_list="$(storage_list_dir "${remote_backup_path}")"

    else

        display --indent 6 --text "- Selecting Project Backup" --result "SKIPPED" --color YELLOW
        return 1

    fi

    # Re-order Backup files by date
    remote_backup_list="$(sort_files_by_date "${remote_backup_list}")"

    # Select Backup File
    chosen_backup_file="$(whiptail --title "BACKUP SELECTION" --menu "Choose Backup to download" 20 78 10 $(for x in ${remote_backup_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        display --indent 6 --text "- Selecting project Backup" --result "DONE" --color GREEN
        display --indent 8 --text "${chosen_backup_file}" --tcolor YELLOW

        # Remote backup path
        chosen_backup_file="${remote_backup_path}/${chosen_backup_file}"

        echo "${chosen_backup_file}"

    else

        display --indent 6 --text "- Selecting Project Backup" --result "SKIPPED" --color YELLOW
        return 1

    fi

}
