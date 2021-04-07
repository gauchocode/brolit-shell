#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.21
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
    dropbox_create_dir_result=$?
    if [[ ${dropbox_create_dir_result} -eq 0 ]]; then

        display --indent 6 --text "- Creating dropbox directory" --result "DONE" --color GREEN
        log_event "info" "Dropbox directory ${dir_to_create} created"

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

    spinner_start "- Uploading file to Dropbox"

    log_event "debug" "Running: ${DROPBOX_UPLOADER} upload ${file_to_upload} ${dropbox_directory}"

    output="$("${DROPBOX_UPLOADER}" -q upload "${file_to_upload}" "${dropbox_directory}")"
    dropbox_file_to_upload_result=$?

    spinner_stop "$dropbox_file_to_upload_result"

    # Check dropbox_file_to_upload_result
    if [[ ${dropbox_file_to_upload_result} -eq 0 ]]; then

        display --indent 6 --text "- Uploading file to Dropbox" --result "DONE" --color GREEN
        log_event "info" "Dropbox file ${file_to_upload} uploaded"

    else

        display --indent 6 --text "- Uploading file to Dropbox" --result "ERROR" --color RED
        display --indent 8 --text "Please red log file" --tcolor RED

        log_event "error" "Can't upload file ${file_to_upload} to dropbox."
        log_event "error" "Last command executed: ${DROPBOX_UPLOADER} upload ${file_to_upload} ${dropbox_directory}"
        log_event "debug" "Last command output: ${output}"

    fi

}

function dropbox_download() {

    local file_to_download=$1
    local local_directory=$2

    local tmp_file_name
    local output
    local dropbox_file_to_download_result

    tmp_file_name=$(extract_filename_from_path "${file_to_download}")

    log_event "info" "Downloading file to Dropbox ..."

    spinner_start "- Downloading file to Dropbox"

    #log_event "debug" "Running: ${DROPBOX_UPLOADER} -q download ${file_to_download} ${local_directory}/${tmp_file_name}"

    output="$("${DROPBOX_UPLOADER}" -q download "${file_to_download}" "${local_directory}/${tmp_file_name}")"
    dropbox_file_to_download_result=$?

    spinner_stop "${dropbox_file_to_download_result}"

    # Check dropbox_file_to_download_result
    if [[ ${dropbox_file_to_download_result} -eq 0 ]]; then

        display --indent 6 --text "- Downloading backup from dropbox" --result "DONE" --color GREEN
        log_event "info" "${file_to_download} downloaded"

    else

        display --indent 6 --text "- Downloading backup from dropbox" --result "ERROR" --color RED
        display --indent 8 --text "Please read log file" --tcolor RED

        log_event "error" "Can't download file ${file_to_download} from dropbox."
        log_event "error" "Last command executed: ${DROPBOX_UPLOADER} -q download ${file_to_download} ${local_directory}/${tmp_file_name}"
        log_event "debug" "Last command output: ${output}"

        return 1

    fi

}

function dropbox_delete() {

    local to_delete=$1

    local output
    local dropbox_remove_result

    output="$("${DROPBOX_UPLOADER}" remove "${to_delete}" 2>&1)"
    dropbox_remove_result=$?
    if [[ ${dropbox_remove_result} -eq 0 ]]; then

        display --indent 6 --text "- Deleting files from Dropbox" --result "DONE" --color GREEN
        log_event "info" "Files deleted from Dropbox"

    else

        display --indent 6 --text "- Deleting files from Dropbox" --result "WARNING" --color YELLOW
        display --indent 8 --text "Maybe backup file doesn't exists" --tcolor YELLOW

        log_event "warning" "Can't remove ${to_delete} from dropbox. Maybe backup file doesn't exists." "false"
        log_event "warning" "Last command executed: ${DROPBOX_UPLOADER} remove ${to_delete}"
        log_event "debug" "Last command output: ${output}"

    fi

}
