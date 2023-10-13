#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.4
################################################################################
#
# MinIO Helper: Perform minio-client actions.
#
################################################################################

################################################################################
# Config minio cloud storage
#
# Arguments:
#   ${1} = ${server_alias}
#   ${2} = ${s3endpoint}
#   ${3} = ${access_key}
#   ${4} = ${secret_key}
#   ${5} = ${api_signature}   # Optional
#
# Outputs:
#   nothing
################################################################################

function minio_add_cloud_storage() {

    local server_alias="${1}"
    local s3endpoint="${2}"
    local access_key="${3}"
    local secret_key="${4}"
    local api_signature="${5}"

    #mc alias set <ALIAS> <YOUR-S3-ENDPOINT> <YOUR-ACCESS-KEY> <YOUR-SECRET-KEY> --api <API-SIGNATURE>
    mc alias set "${server_alias}" "${s3endpoint}" "${access_key}" "${secret_key}" --api "${api_signature}"

}

################################################################################
# List files/dirs from minio storage
#
# Arguments:
#   ${1} = ${server_alias}
#   ${2} = ${bucket_name}
#
# Outputs:
#   nothing
################################################################################

function minio_list() {

    local server_alias="${1}"
    local bucket_name="${2}"

    mc ls "${server_alias}/${bucket_name}"

}

################################################################################
# Mirror directories
#
# Arguments:
#   ${1} = ${server_alias}
#   ${2} = ${bucket_name}
#   ${3} = ${file_to_delete}
#   ${4} = ${dir_name}
#   ${5} = ${to_backup}
#
# Outputs:
#   nothing
################################################################################

function minio_mirror() {

    local server_alias="${1}"
    local bucket_name="${2}"
    local file_to_delete="${3}"
    local dir_name="${4}"
    local to_backup="${5}"

    mc mirror --overwrite "${to_backup}" "${server_alias}/${bucket_name}/${dir_name}"

}

################################################################################
# Remove files on minio storage
#
# Arguments:
#   ${1} = ${server_alias}
#   ${2} = ${bucket_name}
#   ${3} = ${file_to_delete}
#
# Outputs:
#   nothing
################################################################################

function minio_remove() {

    local server_alias="${1}"
    local bucket_name="${2}"
    local file_to_delete="${3}"

    mc rm "${server_alias}/${bucket_name}/${file_to_delete}"

}
