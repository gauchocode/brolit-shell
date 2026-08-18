#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.12
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

function dropbox_account_space_free() {

    local output

    # Log
    log_event "debug" "Getting Dropbox account space left" "false"
    log_event "debug" "Running: \"${DROPBOX_UPLOADER}\" space | grep \"Free:\" | awk -F \" \" "'{print $2}'"" "false"

    # Command
    output="$("${DROPBOX_UPLOADER}" space | grep "Free:" | awk -F " " '{print $2}' 2>&1)"

    [[ -n ${output} ]] && echo "${output}"

}

################################################################################
# Check if file exists on Dropbox account
#
# Arguments:
#   ${1} = ${file}
#   ${2} = ${path}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function dropbox_check_if_file_exists() {

    local file="${1}"
    local path="${2}"

    local output

    # Log
    log_event "debug" "Check if file exists on Dropbox account: ${file}" "false"
    log_event "debug" "Running: \"${DROPBOX_UPLOADER}\" list \"${path}\" | grep -w \"${file}\" | awk -F \" \" "'{print $1}'" 2>&1" "false"

    # Command
    output="$("${DROPBOX_UPLOADER}" list "${path}" | grep -w "${file}" | awk -F " " '{print $1}' 2>&1)"

    # If file exists
    if [[ ${output} == "[F]" ]]; then

        log_event "debug" "Directory ${file} exists" "false"

        return 0

    else # If file not exists

        log_event "debug" "File not exists" "false"

        return 1

    fi

}

################################################################################
# Check if directory exists on Dropbox account
#
# Arguments:
#   ${1} = ${directory}
#   ${2} = ${path}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function dropbox_check_if_directory_exists() {

    local directory="${1}"
    local api_directory="/${directory#/}"
    local path="${2}"

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
#   ${1} = ${dir_to_create}
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
#   ${1} = ${file_to_upload}
#   ${2} = ${dropbox_directory}
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
    log_event "debug" "Executing: \"${DROPBOX_UPLOADER}\" -q upload \"${file_to_upload}\" \"${dropbox_directory}\"" "false"

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
#   ${1} = ${file_to_download}
#   ${2} = ${local_directory}
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
    log_event "debug" "Executing: \"${DROPBOX_UPLOADER}\" -q download \"${file_to_download}\" \"${local_directory}/${tmp_file_name}\"" "false"

    spinner_start "- Downloading file from Dropbox"

    dropbox_output="$("${DROPBOX_UPLOADER}" -q download "${file_to_download}" "${local_directory}/${tmp_file_name}")"
    dropbox_file_to_download_result=$?

    spinner_stop "${dropbox_file_to_download_result}"

    if [[ ${dropbox_file_to_download_result} -eq 0 ]]; then
        # Log
        display --indent 6 --text "- Downloading file from Dropbox" --result "DONE" --color GREEN
        log_event "info" "${file_to_download} downloaded" "false"

        return 0

    else
        # Log
        clear_previous_lines "1"
        display --indent 6 --text "- Downloading file from Dropbox" --result "FAIL" --color RED
        display --indent 8 --text "Please read log file" --tcolor RED
        log_event "error" "Can't download file ${file_to_download} from dropbox." "false"
        log_event "debug" "Last command output: ${dropbox_output}" "false"

        return 1

    fi

}

################################################################################
# Delete file in Dropbox
#
# Arguments:
#   ${1} = ${to_delete} - full path to file or directory
#   ${2} = ${force_delete}
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
    local attempt
    local max_attempts=3
    local wait_seconds

    # TODO: implements dropbox_check_if_file_exists

    if [[ ${force_delete} != "true" ]]; then

        # Log
        log_event "info" "Search \"${to_delete}\" to delete on Dropbox account" "false"
        log_event "debug" "Executing: \"${DROPBOX_UPLOADER}\" -hq search \"${to_delete}\"" "false"

        search_file="$(basename "${to_delete}")"

        # Command
        search_result="$("${DROPBOX_UPLOADER}" -hq search "${search_file}")"

    fi

    # Check if not empty
    if [[ -n ${search_result} || ${force_delete} == "true" ]]; then

        # Retry with backoff: the Dropbox API can return transient errors
        # (timeouts, rate limiting) that make a single attempt unreliable.
        for ((attempt = 1; attempt <= max_attempts; attempt++)); do

            # Command
            output="$("${DROPBOX_UPLOADER}" remove "${to_delete}" 2>&1)"
            dropbox_remove_result=$?

            [[ ${dropbox_remove_result} -eq 0 ]] && break

            if [[ ${attempt} -lt ${max_attempts} ]]; then

                # Back off longer if it looks like a rate-limit response
                if echo "${output}" | grep -qi "429\|too_many_requests\|rate limit"; then
                    wait_seconds=$((attempt * 10))
                else
                    wait_seconds=$((attempt * 3))
                fi

                log_event "warning" "Attempt ${attempt}/${max_attempts} failed removing ${to_delete} from Dropbox, retrying in ${wait_seconds}s..." "false"
                log_event "debug" "Last command output: ${output}" "false"

                sleep "${wait_seconds}"

            fi

        done

        if [[ ${dropbox_remove_result} -eq 0 ]]; then

            # Log
            #display --indent 6 --text "- Deleting old files from Dropbox" --result "DONE" --color GREEN
            log_event "info" "File deleted from Dropbox: ${to_delete}" "false"

            return 0

        else

            # Log
            display --indent 6 --text "- Deleting old files from Dropbox" --result "WARNING" --color YELLOW
            display --indent 8 --text "Can't remove backup from Dropbox." --tcolor YELLOW

            log_event "error" "Can't remove ${to_delete} from Dropbox after ${max_attempts} attempts." "false"
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
#   ${1} = ${directory}
#
# Outputs:
#   ${dir_list} if ok, 1 on error.
################################################################################

function dropbox_list_directory() {

    local directory="${1}"

    local dir_list
    local attempt
    local max_attempts=3

    # Log
    log_event "debug" "Listing directory ${directory} on Dropbox" "false"
    log_event "debug" "Executing: ${DROPBOX_UPLOADER} -hq list \"${directory}\" | awk '{print $NF;}'" "false"

    # Dropbox API returns directory/file names on the last column
    for ((attempt=1; attempt<=max_attempts; attempt++)); do

        dir_list="$("${DROPBOX_UPLOADER}" -hq list "${directory}" | awk '{print $NF;}')"
        exitstatus=$?

        # If command succeeded and we got results, we're done
        if [[ ${exitstatus} -eq 0 && -n ${dir_list} ]]; then
            break
        fi

        # If command failed, don't retry
        if [[ ${exitstatus} -ne 0 ]]; then
            break
        fi

        # If empty and not the last attempt, wait and retry
        if [[ ${attempt} -lt ${max_attempts} ]]; then
            log_event "debug" "Empty response from Dropbox API, retrying in 3 seconds... (attempt ${attempt}/$((max_attempts - 1)))" "false"
            sleep 3
        fi

    done

    if [[ ${exitstatus} -eq 0 && -n ${dir_list} ]]; then

        # Log
        log_event "info" "Listing directory: ${directory}" "false"
        log_event "info" "Remote list: ${dir_list}" "false"

        # Return
        echo "${dir_list}" && return 0

    else

        # Log
        log_event "error" "Can't list directory ${directory} on Dropbox" "false"
        log_event "debug" "Command executed: ${DROPBOX_UPLOADER} -hq list \"${directory}\" | awk '{print $NF;}'" "false"

        return 1

    fi

}

################################################################################
# Get file modified date from Dropbox
#
# Arguments:
#   ${1} = ${file}
#
# Outputs:
#   ${output} if ok, 1 on error.
################################################################################

function dropbox_get_modified_date() {

    local file="${1}"

    local output
    local filename
    local remote_path

    # Get filename from file
    filename="$(basename "${file}")"

    # Get path from file
    remote_path="$(dirname "${file}")"

    # Log
    log_event "debug" "Getting modified date from ${file} on Dropbox" "false"
    log_event "debug" "Executing: ${DROPBOX_UPLOADER} -hq list \"${remote_path}\"" "false"

    # Dropbox API returns files names on the fourth column (brolit modified version)
    output="$("${DROPBOX_UPLOADER}" -hq list "${remote_path}")"
    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then

        # Match file with output
        output="$(echo "${output}" | grep -F "${filename}" | awk '{print $3;}')"

        # This will return 2023-11-16;00:56:37 need to replace ; with space
        output="$(echo "${output}" | sed 's/;/ /g')"

        # Log
        log_event "info" "Modified date: ${output}" "false"

        # Return
        echo "${output}" && return 0

    else

        # Log
        log_event "error" "Can't get modified date from ${file} on Dropbox" "false"
        log_event "debug" "Command executed: ${DROPBOX_UPLOADER} -hq list \"${file}\" | awk '{print $3;}'" "false"

        return 1

    fi

}

################################################################################
# Get a Dropbox access token using the configured refresh token.
#
# Arguments:
#   none
#
# Outputs:
#   Access token on stdout, 1 on error.
################################################################################
function _dropbox_get_access_token() {

    local config_file="${BACKUP_DROPBOX_CONFIG_FILE:-}"
    local curl_bin="${CURL_BIN:-curl}"
    local response
    local access_token

    if [[ -z "${config_file}" || ! -f "${config_file}" ]]; then
        log_event "error" "Dropbox config file not found: ${config_file}" "false"
        return 1
    fi

    # shellcheck source=/dev/null
    source "${config_file}"

    if [[ -z "${OAUTH_APP_KEY:-}" || -z "${OAUTH_APP_SECRET:-}" || -z "${OAUTH_REFRESH_TOKEN:-}" ]]; then
        log_event "error" "Dropbox OAuth refresh credentials are incomplete" "false"
        return 1
    fi

    response="$("${curl_bin}" --silent --show-error --location \
        --user "${OAUTH_APP_KEY}:${OAUTH_APP_SECRET}" \
        --data "grant_type=refresh_token" \
        --data "refresh_token=${OAUTH_REFRESH_TOKEN}" \
        "https://api.dropbox.com/oauth2/token")"
    exitstatus=$?
    if [[ ${exitstatus} -ne 0 ]]; then
        log_event "error" "Unable to refresh Dropbox access token" "false"
        return 1
    fi

    access_token="$(jq -r '.access_token // empty' <<< "${response}" 2>/dev/null)"
    if [[ -n "${access_token}" ]]; then
        echo "${access_token}"
        return 0
    fi

    log_event "error" "Dropbox access token refresh returned no token" "false"
    return 1

}

################################################################################
# List deleted files from a Dropbox directory.
#
# Arguments:
#   ${1} = ${directory}
#
# Outputs:
#   Newline-separated file names, 1 on error or when no files are found.
################################################################################
function dropbox_list_deleted() {

    local directory="${1}"
    local api_directory="/${directory#/}"
    local curl_bin="${CURL_BIN:-curl}"
    local access_token
    local response
    local cursor=""
    local has_more="true"
    local request_body
    local deleted_files=""
    local page_files
    local exitstatus

    access_token="$(_dropbox_get_access_token)"
    exitstatus=$?
    [[ ${exitstatus} -ne 0 ]] && return 1

    while [[ ${has_more} == "true" ]]; do

        if [[ -n "${cursor}" ]]; then
            request_body="$(jq -cn --arg cursor "${cursor}" '{cursor: $cursor}')"
        else
            request_body="$(jq -cn --arg path "${api_directory}" '{path: $path, recursive: false, include_media_info: false, include_deleted: true, include_has_explicit_shared_members: false}')"
        fi

        if [[ -z "${request_body}" ]]; then
            log_event "error" "Unable to build Dropbox deleted-file request" "false"
            return 1
        fi

        if [[ -n "${cursor}" ]]; then
            response="$("${curl_bin}" --silent --show-error --location \
                --request POST \
                --header "Authorization: Bearer ${access_token}" \
                --header "Content-Type: application/json" \
                --data "${request_body}" \
                "https://api.dropboxapi.com/2/files/list_folder/continue")"
        else
            response="$("${curl_bin}" --silent --show-error --location \
                --request POST \
                --header "Authorization: Bearer ${access_token}" \
                --header "Content-Type: application/json" \
                --data "${request_body}" \
                "https://api.dropboxapi.com/2/files/list_folder")"
        fi
        exitstatus=$?
        if [[ ${exitstatus} -ne 0 ]]; then
            log_event "error" "Unable to list deleted Dropbox files in ${directory}" "false"
            return 1
        fi

        if jq -e '.error_summary? // empty' <<< "${response}" >/dev/null 2>&1; then
            log_event "error" "Dropbox rejected deleted-file listing for ${directory}" "false"
            return 1
        fi

        page_files="$(jq -r '.entries[]? | select(.[".tag"] == "deleted") | .name' <<< "${response}" 2>/dev/null)"
        if [[ -n "${page_files}" ]]; then
            if [[ -n "${deleted_files}" ]]; then
                deleted_files+=$'\n'
            fi
            deleted_files+="${page_files}"
        fi

        has_more="$(jq -r '.has_more // false' <<< "${response}" 2>/dev/null)"
        cursor="$(jq -r '.cursor // empty' <<< "${response}" 2>/dev/null)"
        if [[ ${has_more} == "true" && -z "${cursor}" ]]; then
            log_event "error" "Dropbox deleted-file listing returned no cursor" "false"
            return 1
        fi

    done

    if [[ -n "${deleted_files}" ]]; then
        echo "${deleted_files}"
        return 0
    fi

    return 1

}

################################################################################
# Get the latest revision ID for a Dropbox file.
#
# Arguments:
#   ${1} = ${file_path}
#
# Outputs:
#   Revision ID on stdout, 1 on error.
################################################################################
function dropbox_get_latest_rev() {

    local file_path="${1}"
    local api_file_path="/${file_path#/}"
    local curl_bin="${CURL_BIN:-curl}"
    local access_token
    local request_body
    local response
    local revision
    local exitstatus

    access_token="$(_dropbox_get_access_token)"
    exitstatus=$?
    [[ ${exitstatus} -ne 0 ]] && return 1

    request_body="$(jq -cn --arg path "${api_file_path}" '{path: $path, mode: "path", limit: 1}')"
    response="$("${curl_bin}" --silent --show-error --location \
        --request POST \
        --header "Authorization: Bearer ${access_token}" \
        --header "Content-Type: application/json" \
        --data "${request_body}" \
        "https://api.dropboxapi.com/2/files/list_revisions")"
    exitstatus=$?
    if [[ ${exitstatus} -ne 0 ]]; then
        log_event "error" "Unable to list Dropbox revisions for ${file_path}" "false"
        return 1
    fi

    revision="$(jq -r '.entries[0].rev // empty' <<< "${response}" 2>/dev/null)"
    if [[ -n "${revision}" ]]; then
        echo "${revision}"
        return 0
    fi

    log_event "error" "No Dropbox revision found for ${file_path}" "false"
    return 1

}

################################################################################
# Restore a deleted Dropbox file to a selected revision.
#
# Arguments:
#   ${1} = ${file_path}
#   ${2} = ${revision}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################
function dropbox_restore_file() {

    local file_path="${1}"
    local api_file_path="/${file_path#/}"
    local revision="${2}"
    local curl_bin="${CURL_BIN:-curl}"
    local access_token
    local request_body
    local response
    local exitstatus

    access_token="$(_dropbox_get_access_token)"
    exitstatus=$?
    [[ ${exitstatus} -ne 0 ]] && return 1

    request_body="$(jq -cn --arg path "${api_file_path}" --arg rev "${revision}" '{path: $path, rev: $rev}')"
    response="$("${curl_bin}" --silent --show-error --location \
        --request POST \
        --header "Authorization: Bearer ${access_token}" \
        --header "Content-Type: application/json" \
        --data "${request_body}" \
        "https://api.dropboxapi.com/2/files/restore")"
    exitstatus=$?
    if [[ ${exitstatus} -ne 0 ]]; then
        log_event "error" "Unable to restore deleted Dropbox file ${file_path}" "false"
        return 1
    fi

    if jq -e '.error_summary? // empty' <<< "${response}" >/dev/null 2>&1; then
        log_event "error" "Dropbox rejected restore for ${file_path}" "false"
        return 1
    fi

    return 0

}
