#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.6
################################################################################
#
# Script Name: Functions
# Description: List all functions from helpers.
#
################################################################################

################################################################################
# Description:
#   Get list of functions from specific script file
#
# Arguments:
#   $1 = ${script_file}
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################

function get_functions_from_script() {
    env -i bash --noprofile --norc -c '
    source "'"$1"'"
    typeset -f |
    grep '\''^[^{} ].* () $'\'' |
    awk "{print \$1}" |
    while read -r fcn_name; do
        type "$fcn_name" | head -n 1 | grep -q "is a function$" || continue
        echo "$fcn_name"
    done
'
}

################################################################################
# Description:
#   Get all functions from all script files.
#
# Arguments:
#   $1 = ${helper_name} - Optional
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################


function get_all_function_list() {

    # If parameter is empty get functions from all script files
    if [[ -z $1 ]]; then

        script_files="$(find -name "*_helper*" ! -path "*/tests/*")"

    else

        script_files="$(find -name "*$1_helper*" ! -path "*/tests/*")"

    fi

    for script_file in ${script_files}; do

        for function_name in $(get_functions_from_script "${script_file}"); do
            echo "${function_name}"
        done

    done

}

get_all_function_list "${1}"