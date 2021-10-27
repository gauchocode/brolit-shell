#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.0.68-beta
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

    output="$("${DROPBOX_UPLOADER}" list "${path}" | grep "${directory}" | awk -F " " '{print $1}' 2>&1)"

    if [[ ${output} == "[D]" ]]; then

        return 0

    else

        if [[ ${output} == "[F]" ]]; then

            # Sometimes the api creates a file instead of a directory, so we need to delete it
            dropbox_delete "${path}${directory}"

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

    local dir_to_create=$1

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

            #display --indent 6 --text "- Creating dropbox directory" --result "DONE" --color GREEN
            log_event "info" "Dropbox directory ${dir_to_create} created" "false"

            return 0

        else

            #display --indent 6 --text "- Creating dropbox directory" --result "WARNING" --color YELLOW
            #display --indent 8 --text "Maybe directory already exists" --tcolor YELLOW

            log_event "debug" "Can't create directory ${dir_to_create} from dropbox. Maybe directory already exists." "false"
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

    local file_to_upload=$1
    local dropbox_directory=$2

    local output
    local dropbox_file_to_upload_result

    log_event "info" "Uploading file to Dropbox ..." "false"

    spinner_start "- Uploading file to Dropbox"

    #log_event "debug" "Running: ${DROPBOX_UPLOADER} upload ${file_to_upload} ${dropbox_directory}" "false"

    output="$("${DROPBOX_UPLOADER}" -q upload "${file_to_upload}" "${dropbox_directory}")"
    dropbox_file_to_upload_result=$?

    spinner_stop "${dropbox_file_to_upload_result}"

    # Check dropbox_file_to_upload_result
    if [[ ${dropbox_file_to_upload_result} -eq 0 ]]; then

        display --indent 6 --text "- Uploading file to Dropbox" --result "DONE" --color GREEN
        log_event "info" "Dropbox file ${file_to_upload} uploaded" "false"

        return 0

    else

        display --indent 6 --text "- Uploading file to Dropbox" --result "ERROR" --color RED
        display --indent 8 --text "Please red log file" --tcolor RED

        log_event "error" "Can't upload file ${file_to_upload} to dropbox." "false"
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

    local file_to_download=$1
    local local_directory=$2

    local tmp_file_name
    local output
    local dropbox_file_to_download_result

    tmp_file_name=$(extract_filename_from_path "${file_to_download}")

    log_event "info" "Downloading file to Dropbox ..." "false"

    spinner_start "- Downloading file to Dropbox"

    #log_event "debug" "Running: ${DROPBOX_UPLOADER} -q download ${file_to_download} ${local_directory}/${tmp_file_name}"

    output="$("${DROPBOX_UPLOADER}" -q download "${file_to_download}" "${local_directory}/${tmp_file_name}")"
    dropbox_file_to_download_result=$?

    spinner_stop "${dropbox_file_to_download_result}"

    # Check dropbox_file_to_download_result
    if [[ ${dropbox_file_to_download_result} -eq 0 ]]; then

        clear_last_line
        clear_last_line

        display --indent 6 --text "- Downloading backup from dropbox" --result "DONE" --color GREEN
        log_event "info" "${file_to_download} downloaded" "false"

        return 0

    else

        clear_last_line
        clear_last_line

        display --indent 6 --text "- Downloading backup from dropbox" --result "ERROR" --color RED
        display --indent 8 --text "Please read log file" --tcolor RED

        log_event "error" "Can't download file ${file_to_download} from dropbox." "false"
        log_event "error" "Last command executed: ${DROPBOX_UPLOADER} -q download ${file_to_download} ${local_directory}/${tmp_file_name}" "false"
        log_event "debug" "Last command output: ${output}" "false"

        return 1

    fi

}

################################################################################
# Delete file in Dropbox
#
# Arguments:
#   $1 = ${to_delete}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function dropbox_delete() {

    local to_delete=$1

    local output
    local dropbox_remove_result

    output="$("${DROPBOX_UPLOADER}" remove "${to_delete}")"
    dropbox_remove_result=$?
    if [[ ${dropbox_remove_result} -eq 0 ]]; then

        display --indent 6 --text "- Deleting files from Dropbox" --result "DONE" --color GREEN
        log_event "info" "Files deleted from Dropbox"

        return 0

    else

        display --indent 6 --text "- Deleting files from Dropbox" --result "WARNING" --color YELLOW
        display --indent 8 --text "Maybe backup file doesn't exists" --tcolor YELLOW

        log_event "warning" "Can't remove ${to_delete} from dropbox. Maybe backup file doesn't exists." "false"
        log_event "warning" "Last command executed: ${DROPBOX_UPLOADER} remove ${to_delete}"
        log_event "debug" "Last command output: ${output}"

        return 1

    fi

}
