#!/usr/bin/env bash
#
# Author: BROOBE - A Software Development Agency - https://broobe.com
# Version: 3.1.6
#############################################################################

function test_project_helper_funtions() {

    local project_domain="dev.broobe.com"

    #test_project_install "${PROJECTS_PATH}" "wordpress"
    test_project_update_config "${PROJECTS_PATH}/${project_domain}" "project_db" "broobe_dev"

}

function test_project_install() {

    local project_path
    local project_type
    local project_domain
    local project_name
    local project_state

    project_path="${PROJECTS_PATH}"
    project_type="wordpress"
    project_domain="test.domain.com"
    project_name="domain"
    project_state="test"

    project_install "${project_path}" "${project_type}" "${project_domain}" "${project_name}" "${project_state}"

    project_delete "${project_domain}" "true"

}

function test_project_update_config() {

    local project_path=$1
    local config_field=$2
    local config_value=$3

    project_update_config "${project_path}" "${config_field}" "${config_value}"

}