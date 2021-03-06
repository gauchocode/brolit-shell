#!/usr/bin/env bash
#
# Autor: BROOBE. web + mobile development - https://broobe.com
# Version: 3.0.18
#############################################################################

function test_project_helper_funtions() {

    test_project_install "${SITES}" "wordpress"

}

function test_project_install() {

    local project_path
    local project_type
    local project_domain
    local project_name
    local project_state

    project_path="${SITES}"
    project_type="wordpress"
    project_domain="test.domain.com"
    project_name="domain"
    project_state="test"

    project_install "${project_path}" "${project_type}" "${project_domain}" "${project_name}" "${project_state}"

    project_delete

}