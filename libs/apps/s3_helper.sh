#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.2
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

  aws --endpoint-url="${BACKUP_S3_ENDPOINT_URL}" s3api put-object --bucket="${BACKUP_S3_BUCKET}" --key="${dir_to_create}/" 

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

  aws --endpoint-url="${BACKUP_S3_ENDPOINT_URL}" s3 ls "s3://${BACKUP_S3_BUCKET}" 

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

  aws --endpoint-url="${BACKUP_S3_ENDPOINT_URL}" s3 cp "${file_to_upload}" "s3://${BACKUP_S3_BUCKET}/${s3_directory}/"

  return $?
}

################################################################################
# Upload folder to S3 storage
#
# Arguments:
#   ${1} = ${folder_to_upload}
#   ${2} = ${s3_directory}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function s3_upload_folder() {

  local folder_to_upload="${1}"
  local s3_directory="${2}"

  aws --endpoint-url="${BACKUP_S3_ENDPOINT_URL}" s3 cp "${folder_to_upload}/" "s3://${BACKUP_S3_BUCKET}/${s3_directory}/" --recursive

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

  aws --endpoint-url="${BACKUP_S3_ENDPOINT_URL}" s3 cp "s3://${BACKUP_S3_BUCKET}/${file_to_download}" "${local_directory}"

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
    aws --endpoint-url="${BACKUP_S3_ENDPOINT_URL}" s3 rm "s3://${BACKUP_S3_BUCKET}/${to_delete}" --recursive
  else
    aws --endpoint-url="${BACKUP_S3_ENDPOINT_URL}" s3 rm "s3://${BACKUP_S3_BUCKET}/${to_delete}"
  fi

  return $?
}