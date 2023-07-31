#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.2-beta
################################################################################

################################################################################
# Create directory in S3
#
# Arguments:
#   ${1} = ${dir_to_create}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function s3_create_dir() {

  local dir_to_create="${1}"

  aws --endpoint-url "{$ENDPOINT_URL}" s3api put-object --bucket "${S3_BUCKET_NAME}" --key "${dir_to_create}/" 

  return $?
}


################################################################################
# Read directory in S3
#
# Arguments:
#   ${1} = ${dir_to_read}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function s3_read_dir() {
  local dir_to_read="${1}"

  aws s3 ls "s3://${S3_BUCKET_NAME}" --endpoint-url="${ENDPOINT_URL}"

  return $?
}


################################################################################
# Upload file to S3 storage
#
# Arguments:
#   ${1} = ${file_to_upload}
#   ${2} = ${s3_directory}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function s3_upload_file() {

  local file_to_upload="${1}"
  local s3_directory="${2}"

  aws s3 cp "${file_to_upload}" "s3://${S3_BUCKET_NAME}/${s3_directory}/"

  return $?
}

################################################################################
# Drownload file from S3 storage
#
# Arguments:
#   ${1} = ${file_to_download}
#   ${2} = ${local_directory}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function s3_download_file() {

  local file_to_download="${1}"
  local local_directory="${2}"

  aws s3 cp "s3://${S3_BUCKET_NAME}/${file_to_download}" "${local_directory}"

  return $?
}

################################################################################
# Delete file in S3 storage
#
# Arguments:
#   ${1} = ${to_delete} - full path to file or directory
#   ${2} = ${force_delete}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function s3_delete_file() {

  local to_delete="${1}"
  local force_delete="${2}"

  if [[ ${force_delete} == "true" ]]; then
    aws s3 rm "s3://${S3_BUCKET_NAME}/${to_delete}" --recursive
  else
    aws s3 rm "s3://${S3_BUCKET_NAME}/${to_delete}"
  fi

  return $?
}