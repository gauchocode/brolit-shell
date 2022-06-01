#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.2-rc7
################################################################################

################################################################################
# Return Dropbox account space left
#
# Arguments:
#   none
#
# Outputs:
#   ${output}
################################################################################

function dropbox_account_space() {

    local output

    output="$("${DROPBOX_UPLOADER}" space 2>&1)"

    # Return
    echo "${output}"

}

################################################################################
# Check if directory exists on Dropbox account
#
# Arguments:
#   ${1}- ${directory}
#   ${2}- ${path}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function dropbox_check_if_directory_exists() {

    local directory="$1"
    local path="$2"

    local output

    # Log
    log_event "debug" "Check if directory exists on Dropbox account: ${directory}" "false"
    log_event "debug" "Running: \"${DROPBOX_UPLOADER}\" list \"${path}\" | grep -w \"${directory}\" | awk -F \" \" "'{print $1}'" 2>&1" "false"

    # Command
    output="$("${DROPBOX_UPLOADER}" list "${path}" | grep -w "${directory}" | awk -F " " '{print $1}' 2>&1)"

    # If directory exists
    if [[ ${output} == "[D]" ]]; then

        log_event "debug" "Directory ${directory} exists" "false"

        return 0

    else # If file exists

        if [[ ${output} == "[F]" ]]; then

            log_event "debug" "File exists, but should be a directory. Deleting..." "false"

            # Sometimes the api creates a file instead of a directory, so we need to delete it
            dropbox_delete "${path}/${directory}" "true"

        fi

        return 1

    fi

}

################################################################################
# Create directory in Dropbox
#
# Arguments:
#   $1 = ${dir_to_create}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function dropbox_create_dir() {

    local dir_to_create="${1}"

    local output
    local dropbox_create_dir_result

    local path
    local directory

    # Split $dir_to_create
    directory="$(basename "${dir_to_create}")"
    path="$(dirname "${dir_to_create}")"

    dropbox_check_if_directory_exists "${directory}" "${path}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 1 ]]; then

        output="$("${DROPBOX_UPLOADER}" -q mkdir "${dir_to_create}")"

        dropbox_create_dir_result=$?
        if [[ ${dropbox_create_dir_result} -eq 0 ]]; then

            log_event "info" "Dropbox directory ${dir_to_create} created" "false"

            return 0

        else

            log_event "debug" "Can't create directory ${dir_to_create} from Dropbox. Maybe directory already exists." "false"
            log_event "debug" "Last command executed: ${DROPBOX_UPLOADER} -q mkdir ${dir_to_create}" "false"
            log_event "debug" "Last command output: ${output}" "false"

            return 1

        fi

    fi

}

################################################################################
# Upload file to Dropbox
#
# Arguments:
#   $1 = ${file_to_upload}
#   $2 = ${dropbox_directory}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function dropbox_upload() {

    local file_to_upload="${1}"
    local dropbox_directory="${2}"

    local output
    local dropbox_file_to_upload_result

    spinner_start "- Uploading file to Dropbox"

    # Log
    log_event "info" "Uploading file to Dropbox ..." "false"
    log_event "debug" "Running: \"${DROPBOX_UPLOADER}\" -q upload \"${file_to_upload}\" \"${dropbox_directory}\"" "false"

    # Command
    output="$("${DROPBOX_UPLOADER}" -q upload "${file_to_upload}" "${dropbox_directory}")"
    dropbox_file_to_upload_result=$?

    spinner_stop "${dropbox_file_to_upload_result}"

    if [[ ${dropbox_file_to_upload_result} -eq 0 ]]; then

        display --indent 6 --text "- Uploading file to Dropbox" --result "DONE" --color GREEN
        log_event "info" "Dropbox file ${file_to_upload} uploaded" "false"

        return 0

    else

        display --indent 6 --text "- Uploading file to Dropbox" --result "ERROR" --color RED
        display --indent 8 --text "Please red log file" --tcolor RED

        log_event "error" "Can't upload file ${file_to_upload} to Dropbox." "false"
        log_event "error" "Last command executed: ${DROPBOX_UPLOADER} upload ${file_to_upload} ${dropbox_directory}" "false"
        log_event "debug" "Last command output: ${output}" "false"

        return 1

    fi

}

################################################################################
# Drownload file from Dropbox
#
# Arguments:
#   $1 = ${file_to_download}
#   $2 = ${local_directory}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function dropbox_download() {

    local file_to_download="${1}"
    local local_directory="${2}"

    local tmp_file_name
    local dropbox_output
    local dropbox_file_to_download_result

    tmp_file_name="$(extract_filename_from_path "${file_to_download}")"

    # Log
    log_event "info" "Trying to download ${file_to_download} from Dropbox" "false"

    spinner_start "- Downloading file from Dropbox"

    dropbox_output="$("${DROPBOX_UPLOADER}" -q download "${file_to_download}" "${local_directory}/${tmp_file_name}")"
    dropbox_file_to_download_result=$?

    spinner_stop "${dropbox_file_to_download_result}"

    # Check dropbox_file_to_download_result
    if [[ ${dropbox_file_to_download_result} -eq 0 ]]; then

        clear_previous_lines "1"

        display --indent 6 --text "- Downloading backup from Dropbox" --result "DONE" --color GREEN
        log_event "info" "${file_to_download} downloaded" "false"

        return 0

    else

        clear_previous_lines "2"

        display --indent 6 --text "- Downloading backup from Dropbox" --result "FAIL" --color RED
        display --indent 8 --text "Please read log file" --tcolor RED

        log_event "error" "Can't download file ${file_to_download} from dropbox." "false"
        log_event "error" "Last command executed: ${DROPBOX_UPLOADER} -q download ${file_to_download} ${local_directory}/${tmp_file_name}" "false"
        log_event "debug" "Last command output: ${dropbox_output}" "false"

        return 1

    fi

}

################################################################################
# Delete file in Dropbox
#
# Arguments:
#   $1 = ${to_delete} - full path to file
#   $2 = ${force_delete}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function dropbox_delete() {

    local to_delete="${1}"
    local force_delete="${2}"

    local output
    local search_file
    local search_result
    local dropbox_remove_result

    if [[ ${force_delete} != "true" ]]; then

        # Log
        log_event "debug" "Search \"${directory}\" to delete on Dropbox account" "false"
        log_event "debug" "Running: \"${DROPBOX_UPLOADER}\" -hq search \"${to_delete}\"" "false"

        search_file="$(basename "${to_delete}")"

        # Command
        search_result="$("${DROPBOX_UPLOADER}" -hq search "${search_file}")"

    fi

    # Check if not empty
    if [[ -n ${search_result} || ${force_delete} == "true" ]]; then

        # Command
        output="$("${DROPBOX_UPLOADER}" remove "${to_delete}")"

        dropbox_remove_result=$?
        if [[ ${dropbox_remove_result} -eq 0 ]]; then

            display --indent 6 --text "- Deleting old files from Dropbox" --result "DONE" --color GREEN
            log_event "info" "Files deleted from Dropbox" "false"

            return 0

        else

            display --indent 6 --text "- Deleting old files from Dropbox" --result "WARNING" --color YELLOW
            display --indent 8 --text "Can't remove backup from Dropbox." --tcolor YELLOW

            log_event "warning" "Can't remove ${to_delete} from Dropbox." "false"
            log_event "warning" "Last command executed: ${DROPBOX_UPLOADER} remove ${to_delete}" "false"
            log_event "debug" "Last command output: ${output}" "false"

            return 1

        fi

    else

        log_event "warning" "Can't remove ${to_delete} from Dropbox, backup file doesn't exists." "false"

        return 1

    fi

}

################################################################################
# List directory on Dropbox
#
# Arguments:
#   $1 = ${directory}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function dropbox_list_directory() {

    local directory="${1}"

    local dir_list

    # Log
    log_event "debug" "Listing directory ${directory} on Dropbox" "false"

    # Dropbox API returns files names on the third column
    dir_list="$("${DROPBOX_UPLOADER}" -hq list "${directory}" | awk '{print $3;}')"

    # If dir_list is empty, try to check the second column where directory names are
    if [[ -z ${dir_list} ]]; then

        dir_list="$("${DROPBOX_UPLOADER}" -hq list "${directory}" | awk '{print $2;}')"

    fi

    # Log
    log_event "info" "Listing directory: ${directory}" "false"
    log_event "info" "Remote list: ${dir_list}" "false"
    log_event "debug" "Command executed: ${DROPBOX_UPLOADER} -hq list \"${directory}\" | awk '{print $ 3;}'" "false"

}
