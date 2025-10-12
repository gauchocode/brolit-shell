#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.4
#############################################################################
#
# SFTP Local Helper: Local sftp configuration functions
#
################################################################################

################################################################################
# Download from ftp
#
# Arguments:
#  ${1} = ftp_ip
#  ${2} = ftp_path
#  ${3} = ftp_user
#  ${4} = ftp_pass
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function ftp_download() {

    local ftp_ip="${1}"
    local ftp_path="${2}"
    local ftp_user="${3}"
    local ftp_pass="${4}"
    local local_directory="${5}"
    #local excluded_dirs="${6}"

    log_event "debug" "Running: wget -r -l 0 --reject=log,.ftpquota ftp://${ftp_ip}/${ftp_path} --ftp-user=\"${ftp_user}\" --ftp-password=\"${ftp_pass}\" -nH --cut-dirs=1 --directory-prefix=\"${local_directory}\"" "false"

    # wget -r -l 0 --reject=log,.ftpquota --exclude-directories=/public_html/cgi-bin,/public_html/.well-known ftp://"${ftp_ip}/${ftp_path}" --ftp-user="${ftp_user}" --ftp-password="${ftp_pass}" -nH --cut-dirs=1
    wget -r -l 0 --reject="log,.ftpquota" ftp://"${ftp_ip}/${ftp_path}" --ftp-user="${ftp_user}" --ftp-password="${ftp_pass}" -nH --cut-dirs=1 --directory-prefix="${local_directory}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        # Log
        log_event "info" "Download from FTP server done." "false"
        display --indent 6 --text "- Downloading from FTP" --result "DONE" --color GREEN

        return 0

    else

        # Log
        log_event "error" "Failed to download from FTP server." "false"
        display --indent 6 --text "- Downloading from FTP" --result "FAIL" --color RED

        return 1

    fi

}
