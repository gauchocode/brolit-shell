#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.8
################################################################################
#
# Storage Controller: Controller to upload and download backups.
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

        # Return
        echo "${remote_list}" && return 0

    else

        return 1

    fi

}

################################################################################
# Create directory (dropbox, sftp, ssh, etc)
#
# Arguments:
#   ${1} = {remote_directory}
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

        ssh -p "${BACKUP_BORG_PORT}" "${BACKUP_BORG_USER}@${BACKUP_BORG_SERVER}" "mkdir -p /home/applications/${BACKUP_BORG_GROUP}/${remote_directory}"

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
#   ${3} = {file_to_upload_size}
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function storage_upload_backup() {

    local file_to_upload="${1}"
    local remote_directory="${2}"
    local file_to_upload_size="${3}"

    local got_error=0
    local error_type
    local storage_space_free

    # Only numbers
    file_to_upload_size="$(echo "${file_to_upload_size}" | sed -E 's/[^0-9.]+//g')"

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        # Check if account has enough space
        storage_space_free="$(dropbox_account_space_free)"

        # Log
        log_event "debug" "Dropbox account space free: ${storage_space_free}" "false"
        log_event "debug" "File to upload size: ${file_to_upload_size}" "false"

        # Compare
        ## Need to do this because Bash doesn't support floating point arithmetic on [[]]
        result=$(echo "${storage_space_free} < ${file_to_upload_size}" | bc)
        [[ ${result} -eq 1 ]] && error_type="dropbox_space" && got_error=1

        # Upload
        dropbox_upload "${file_to_upload}" "${remote_directory}"
        [[ $? -eq 1 ]] && error_type="dropbox_upload" && got_error=1

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

    # Return
    return ${got_error}

}

################################################################################
# Download backup from configured storage (dropbox, sftp, etc)
#
# Arguments:
#   ${1} = {file_to_download}
#   ${2} = {local_directory}
#
# Outputs:
#   0 if it utils were installed, 1 on error.
################################################################################

function storage_download_backup() {

    local file_to_download="${1}"
    local local_directory="${2}"

    local got_error=0
    local error_type
    local backup_date
    #local local_space_free

    if [[ ${BACKUP_DROPBOX_STATUS} == "enabled" ]]; then

        # Check if local storage has enough space
        #local_space_free="$(calculate_disk_usage "${MAIN_VOL}")"
        
        # Check date from file to download
        backup_date="$(dropbox_get_modified_date "${file_to_download}")"

        # Show whiptail message
        whiptail_message_with_skip_option "Backup date" "\n\nThis backup date is: ${backup_date}\n\nDo you want to continue?"
        [[ $? -eq 1 ]] && error_type="dropbox_skipped" && return 1

        # Download
        dropbox_download "${file_to_download}" "${local_directory}"
        [[ $? -eq 1 ]] && error_type="dropbox_download" && got_error=1

    fi

    [[ ${error_type} != "none" ]] && echo "${error_type}"

    # Return
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
    local error_type="none"
    #local error_msg="none"

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

    # Return
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
    #log_event "debug" "Daily backups: ${sorted_daily[@]}" "false"
    #log_event "debug" "Weekly backups: ${sorted_weekly[@]}" "false"
    #log_event "debug" "Monthly backups: ${sorted_monthly[@]}" "false"

    # Log
    display --indent 6 --text "- Deleting old files from storage"

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
    display --indent 6 --text "- Deleting old files from storage" --result "DONE" --color GREEN

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

    # Log
    log_event "info" "Running server selection menu" "false"

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

            # Log
            log_event "debug" "chosen_server: ${chosen_server}" "false"

            # Return
            echo "${chosen_server}" && return 0

        else

            return 1

        fi

    else

        # Log
        log_event "error" "Storage list dir failed. Output: ${remote_server_list}. Exit status: ${exitstatus}" "false"

        # Return
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

    # Log
    log_event "info" "Running backup type selection menu" "false"

    # List options
    remote_type_list="project site database docker-volume"

    chosen_restore_type="$(whiptail --title "BACKUP TYPE SELECTION" --menu "Choose a backup type. You can choose restore an entire project or only site files, database or config." 20 78 10 $(for x in ${remote_type_list}; do echo "${x} [D]"; done) 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        log_event "debug" "chosen_restore_type: ${chosen_restore_type}" "false"

        # Return
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

    # Log
    log_event "debug" "Running backup status selection" "false"

    # List options
    remote_status_list=("01) Online 02) Offline")

    chosen_restore_status="$(whiptail --title "BACKUP SELECTION" --menu "Choose the backup status:" 20 78 10 $(for x in ${remote_status_list}; do echo "${x}"; done) 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        if [[ ${chosen_restore_status} == *"01"* ]]; then

            # Log
            log_event "debug" "chosen_restore_status: online" "false"

            # Return
            echo "online" && return 0

        fi

        if [[ ${chosen_restore_status} == *"02"* ]]; then

            # Log
            log_event "debug" "chosen_restore_status: offline" "false"

            # Return
            echo "offline" && return 0

        fi

    else

        # Log
        log_event "debug" "Backup status selection skipped." "false"

        # Return
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

    # Log
    log_event "info" "Running backup selection menu" "false"

    # Get dropbox folders list
    storage_project_list="$(storage_list_dir "${remote_backup_path}/${remote_backup_type}")"

    # Re-order Backup Directories
    storage_project_list="$(sort_array_alphabetically "${storage_project_list}")"

    # Select Project
    chosen_project="$(whiptail --title "BACKUP SELECTION" --menu "Choose a Project Backup to work with:" 20 78 10 $(for x in ${storage_project_list}; do echo "$x [D]"; done) 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        log_event "debug" "chosen_project: ${chosen_project}" "false"

        # Get backup list
        remote_backup_path="${remote_backup_path}/${remote_backup_type}/${chosen_project}"
        remote_backup_list="$(storage_list_dir "${remote_backup_path}")"

    else

        # Log
        display --indent 6 --text "- Selecting Project Backup" --result "SKIPPED" --color YELLOW

        # Return        
        return 1

    fi

    # Re-order Backup files by date
    remote_backup_list="$(sort_files_by_date "${remote_backup_list}")"

    # Select Backup File
    chosen_backup_file="$(whiptail --title "BACKUP SELECTION" --menu "Choose Backup to download" 20 78 10 $(for x in ${remote_backup_list}; do echo "$x [F]"; done) 3>&1 1>&2 2>&3)"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        display --indent 6 --text "- Selecting project Backup" --result "DONE" --color GREEN
        display --indent 8 --text "${chosen_backup_file}" --tcolor YELLOW

        # Remote backup path
        chosen_backup_file="${remote_backup_path}/${chosen_backup_file}"

        # Return
        echo "${chosen_backup_file}" && return 0

    else

        # Log
        display --indent 6 --text "- Selecting Project Backup" --result "SKIPPED" --color YELLOW

        # Return
        return 1

    fi

}
