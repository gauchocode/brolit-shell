#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.3.2-beta
#############################################################################

source "../libs/apps/s3_helper.sh"


function generate_random_files() {
    rm -r random/
    mkdir random/
    for n in {1..100}; do
        dd if=/dev/urandom of=random/file$( printf %03d "$n" ).bin bs=1 count=$(( RANDOM + 1024 ))
    done
}

function test_s3_helper_funtions() {

    echo "Generating random files to test"
    generate_random_files

    echo "Creating directory test if not exists"
    s3_create_dir "test"

    result=$(s3_read_dir "test")

    if [[ ${result} ]]; then
        echo "s3_read_dir: OK"
    else
        echo "s3_read_dir: FAIL"
    fi

    echo "Uploading random files"

    sleep 3

    result=$(s3_upload_folder "/root/brolit-shell/random" "test")

    if [[ ${result} ]]; then
        echo "s3_upload_folder: OK"
    else
        echo "s3_upload_folder: FAIL"
    fi   
}
