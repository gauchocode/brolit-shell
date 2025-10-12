#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.4
################################################################################
#
# Ref: https://github.com/wordfence/wordfence-cli
#

################################################################################
# Write Worfence-cli license file
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function wordfencecli_write_license() {

    local wordfencecli_license_key="${1}"

    declare -g WORDFENCECLI_LICENSE

    local wordfencecli_license_file

    wordfencecli_license_file="/root/.config/wordfence/wordfence-cli.ini"

    if [[ ${wordfencecli_license_key} != "" ]]; then

        # Create directory if not exists
        mkdir -p /root/.config
        mkdir -p /root/.config/wordfence

        # Write license
        echo "${wordfencecli_license_key}" > ${wordfencecli_license_file}

        return 0

    else

        log_event "error" "Something went wrong writing Wordfence-cli license" "false"

        return 1

    fi

}

################################################################################
# Read remote name from configuration file
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function wordfencecli_read_license() {

    declare -g WORDFENCECLI_LICENSE

    local wordfencecli_license_file

    wordfencecli_license_file="/root/.config/wordfence/wordfence-cli.ini"

    WORDFENCECLI_LICENSE="$(cat "${wordfencecli_license_file}")"

    if [[ ${WORDFENCECLI_LICENSE} != "" ]]; then

        export WORDFENCECLI_LICENSE
        
        # Return
        echo "${WORDFENCECLI_LICENSE}" && return 0

    else

        log_event "error" "Something went wrong reading Wordfence-cli license" "false"

        return 1

    fi

}

################################################################################
# Build Wordfence CLI Docker image
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function build_wordfencecli_docker_image() {

    local target_directory="/root/brolit-shell/tmp"

    if [[ ! -d "${target_directory}/wordfence-cli" ]]; then
        git clone https://github.com/wordfence/wordfence-cli.git "${target_directory}/wordfence-cli"
    else
        echo "Wordfence CLI repository already cloned."
    fi

    cd "${target_directory}/wordfence-cli"
    docker build -t wordfence-cli:latest . > /dev/null 2>&1
    cd "${target_directory}"

}


################################################################################
# Malware scan directory with wordfence-cli
#
# Arguments:
#   ${1} = ${directory_to_scan}
#   ${2} = ${include_all_files} - true or false
#
# Outputs:
#   nothing
################################################################################

function wordfencecli_malware_scan() {

    local directory_to_scan="${1}"
    local include_all_files="${2}"

    local scan_option
    local license

    # Build the Wordfence CLI Docker image
    if [[ "$(docker images -q wordfence-cli:latest 2> /dev/null)" == "" ]]; then
        log_event "info" "Building Wordfence CLI Docker image..." "false"
        build_wordfencecli_docker_image
    fi

    # Read license 
    license="$(wordfencecli_read_license)"

    if [[ $? -eq 0 ]]; then

        # If include_all_files is true, set scan_option
        [[ $include_all_files == "true" ]] && scan_option="--include-all-files" || scan_option=""

        # Log
        log_event "info" "Starting wordfence-cli malware scan on: ${directory_to_scan}" "false"
        log_event "debug" "Running: docker run -v /var/www:/var/www wordfence-cli:latest malware-scan ${scan_option} --accept-terms --license ${license} ${directory_to_scan}" "false"
        display --indent 6 --text "- Starting wordfence-cli malware scan on: ${directory_to_scan}"

        # Malware Scan command
        docker run -v /var/www:/var/www -v /root/brolit-shell/tmp:/output wordfence-cli:latest malware-scan ${scan_option} --workers $(echo $(( $(nproc) / 2 ))) --accept-terms --license ${license} "${directory_to_scan}" --output-path /output/$(basename "${directory_to_scan}")_scan.csv

    else

        # Log
        log_event "error" "Not license found for wordfence-cli" "false"
        display --indent 6 --text "- Not license found for wordfence-cli" --result "ERROR" --color RED
        display --indent 8 --text "- Please get a new one from here: https://www.wordfence.com/products/wordfence-cli/" --tcolor RED

        return 1

    fi

}

################################################################################
# Vulnerabilities scan directory with wordfence-cli
#
# Arguments:
#   ${1} = ${directory_to_scan}
#   ${2} = ${include_all_files} - true or false
#
# Outputs:
#   nothing
################################################################################

function wordfencecli_vulnerabilities_scan() {

    local directory_to_scan="${1}"
    local include_all_files="${2}"

    local scan_option
    local license

    # Build the Wordfence CLI Docker image
    build_wordfencecli_docker_image

    # Read license 
    license="$(wordfencecli_read_license)"

    if [[ $? -eq 0 ]]; then
    
        # If include_all_files is true, set scan_option
        [[ $include_all_files == "true" ]] && scan_option="--include-all-files" || scan_option=""

        # Log
        log_event "info" "Starting wordfence-cli vulnerabilities scan on: ${directory_to_scan}" "false"
        log_event "debug" "Running: docker run -v /var/www:/var/www wordfence-cli:latest vuln-scan ${scan_option} --accept-terms --license ${license} ${directory_to_scan}" "false"
        display --indent 6 --text "- Starting wordfence-cli vulnerabilities scan on: ${directory_to_scan}"

        # Vulnerabilities Scan command
        docker run -v /var/www:/var/www wordfence-cli:latest vuln-scan ${scan_option} --accept-terms --license ${license} "${directory_to_scan}"

    else

        # Log
        log_event "error" "Not license found for wordfence-cli" "false"
        display --indent 6 --text "- Not license found for wordfence-cli" --result "ERROR" --color RED
        display --indent 8 --text "- Please get a new one from here: https://www.wordfence.com/products/wordfence-cli/" --tcolor RED

        return 1

    fi

}