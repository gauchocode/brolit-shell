#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.2-beta
#############################################################################

source "../libs/apps/s3_helper.sh"

function test_s3_helper_funtions() {

    s3_create_dir "test"

    result=$(s3_read_dir "test")

    if [[ ${result} == "test" ]]; then
        echo "s3_read_dir: OK"
    else
        echo "s3_read_dir: FAIL"
    fi

}
