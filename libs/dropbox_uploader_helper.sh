#!/bin/bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.13
################################################################################

function dropbox_account_space() {

    local output

    output="$("${DROPBOX_UPLOADER}" space 2>&1)"

}

function dropbox_create_dir() {

    local dir_to_create=$1

    local output
    local dropbox_create_dir_result

    output="$("${DROPBOX_UPLOADER}" -q mkdir "${dir_to_create}" 2>&1)"
    dropbox_create_dir_result="$?"
    if [[ ${dropbox_create_dir_result} -eq 0 ]]; then

        display --indent 6 --text "- Creating dropbox directory" --result "DONE" --color GREEN
        log_event "success" "Dropbox directory ${dir_to_create} created"

    else

        #display --indent 6 --text "- Creating dropbox directory" --result "WARNING" --color YELLOW
        #display --indent 8 --text "Maybe directory already exists" --tcolor YELLOW

        log_event "debug" "Can't create directory ${dir_to_create} from dropbox. Maybe directory already exists."
        log_event "debug" "Last command executed: ${DROPBOX_UPLOADER} -q mkdir ${dir_to_create}"
        log_event "debug" "Last command output: ${output}"

    fi

}

function dropbox_upload() {

    local file_to_upload=$1
    local dropbox_directory=$2

    local output
    local dropbox_file_to_upload_result

    log_event "info" "Uploading file to Dropbox ..."
    display --indent 6 --text "- Uploading file to Dropbox"
    spinner_start " "

    log_event "debug" "Running: ${DROPBOX_UPLOADER} upload ${file_to_upload} ${dropbox_directory}"

    output="$("${DROPBOX_UPLOADER}" -q upload "${file_to_upload}" "${dropbox_directory}")"

    spinner_stop "$?"

    # Clear output
    clear_last_line
    clear_last_line

    dropbox_file_to_upload_result="$?"
    if [[ ${dropbox_file_to_upload_result} -eq 0 ]]; then

        display --indent 6 --text "- Uploading file to Dropbox" --result "DONE" --color GREEN
        log_event "success" "Dropbox file ${file_to_upload} uploaded"

    else

        display --indent 6 --text "- Uploading file to Dropbox" --result "ERROR" --color RED
        display --indent 8 --text "Please red log file" --tcolor RED

        log_event "error" "Can't upload file ${file_to_upload} to dropbox."
        log_event "error" "Last command executed: ${DROPBOX_UPLOADER} upload ${file_to_upload} ${dropbox_directory}"
        log_event "debug" "Last command output: ${output}"

    fi

}

function dropbox_delete() {

    local to_delete=$1

    local output
    local dropbox_remove_result

    output="$("${DROPBOX_UPLOADER}" remove "${to_delete}" 2>&1)"
    dropbox_remove_result="$?"
    if [[ ${dropbox_remove_result} -eq 0 ]]; then

        display --indent 6 --text "- Deleting files from Dropbox" --result "DONE" --color GREEN
        log_event "success" "Files deleted from Dropbox"

    else

        display --indent 6 --text "- Deleting files from Dropbox" --result "WARNING" --color YELLOW
        display --indent 8 --text "Maybe backup file doesn't exists" --tcolor YELLOW

        log_event "warning" "Can't remove ${to_delete} from dropbox. Maybe backup file doesn't exists." "false"
        log_event "warning" "Last command executed: ${DROPBOX_UPLOADER} remove ${to_delete}"
        log_event "debug" "Last command output: ${output}"

    fi

}