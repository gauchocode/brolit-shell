#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.4
################################################################################
#
# Json Helper: Functions to read and write json files.
#
################################################################################

################################################################################
# Get the value of the field in the JSON file
#
# Arguments:
#  ${1}= ${json_file}   - Path to the JSON file
#  ${2} = ${json_field} - Field to get the value from
#
# Outputs:
#  ${json_field_value}
#  0 if the operation was successful, 1 otherwise
################################################################################

function json_read_field() {

    local json_file="${1}"
    local json_field="${2}"

    local json_field_value

    json_field_value="$(cat "${json_file}" | jq -r ".${json_field}")"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then
    
        # Return
        echo "${json_field_value}"
        return 0

    else

        log_event "error" "Getting value from ${json_field}" "false"
        return 1

    fi

}

################################################################################
# Write json field value
#
# Arguments:
#  $1= ${json_file}
#  ${2} = ${json_field}
#  $3= ${json_field_value}
#
# Outputs:
#  0 if ok, 1 on error.
################################################################################

function json_write_field() {

    local json_file="${1}"
    local json_field="${2}"
    local json_field_value="${3}"

    json_field_value="$(jq ".${json_field} = \"${json_field_value}\"" "${json_file}")" && echo "${json_field_value}" >"${json_file}"

    exitstatus=$?
    if [[ ${exitstatus} -eq 0 ]]; then

        return 0

    else

        log_event "error" "Something went wrong trying to update a value in ${json_file}" "false"
        log_event "debug" "json field: ${json_field}" "false"
        log_event "debug" "json field value: ${json_field_value}" "false"
        return 1

    fi

}

################################################################################
# Transfor string to json
#
# Arguments:
#  $1= ${mode} - Options: key-value, value-list
#  $@
#
# Outputs:
#  ${json_string}
################################################################################

function jsonify_output() {

    local mode="${1}"

    display --indent 6 --text "- Running jsonify_output with mode: $mode"

    # Mode "key-value" example:
    # > echo "key1 value1 key2 value2"
    # {'key1': value1, 'key2': value2}

    # Mode "value-list" example:
    # > echo "value1 value2 value3 value4"
    # [ "value1" "value2" "value3" "value4" ]

    # Remove first parameter
    shift

    if [[ ${mode} == "key-value" ]]; then

        arr=()

        while [ $# -ge 1 ]; do
            arr=("${arr[@]}" $1)
            shift
        done

        vars=(${arr[@]})
        len=${#arr[@]}

        printf "{"
        for ((i = 0; i < len; i += 2)); do
            printf "\"${vars[i]}\": ${vars[i + 1]}"
            if [ $i -lt $((len - 2)) ]; then
                printf ", "
            fi
        done
        printf "}"
        echo

    else

        arr=()

        while [ $# -ge 1 ]; do
            arr=("${arr[@]}" $1)
            shift
        done

        vars=(${arr[@]})
        len=${#arr[@]}

        printf "["
        for ((i = 0; i < len; i += 1)); do
            printf "\"${vars[i]}\""
            if [ $i -lt $((len - 1)) ]; then
                printf ", "
            fi
        done
        printf "]"
        echo

    fi

}

################################################################################
# Load global vars from json config file
#
# Arguments:
#  $1= ${json_file} - Options: key-value, value-list
#
# Outputs:
#  ${json_field_value}
################################################################################

function json_to_vars() {

    local json_file="${1}"

    # TODO: read json file and ouput global vars.
    #
    # Example:
    #
    #    "SERVER_ROLES": {
    #    "config": [
    #        {
    #            "webserver": "true",
    #            "database": "true",
    #            "docker": "false",
    #            "cache": "false",
    #            "other": "false"
    #        }
    #       ]
    #   }
    #
    # Could transfor in:
    #
    # SERVER_ROLE=("webserver", "database")
    #

    # Ref: https://unix.stackexchange.com/questions/413878/json-array-to-bash-variables-using-jq

    jq -r '.SERVER_ROLES.config[] | to_entries | .[] | .key + "=\"" + .value + "\""'

    # Should ouput:
    # webserver="true"
    # database="true"
    # docker="false"
    # cache="false"
    # other="false"

    # Maybe we should send this to a file and then source it

}
