#!/usr/bin/env bash
# Author: GauchoCode
# Version: 3.14
# Description: Offline regression for the no-database borgmatic template opt-out.
################################################################################

################################################################################
# Assert a project with BROLIT_DB_ENGINE=none gets the default (no database)
# borgmatic template instead of the MySQL one whose ${database} constant would
# fail to interpolate. Also asserts the previous behaviour without the opt-out.
#
# Arguments:
#   none
# Outputs:
#   0 if all assertions pass, 1 on error.
################################################################################
function test_borg_no_db_template() (
    set -e
    local root tmp status
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    mkdir --parents "${TMPDIR:-/tmp/opencode}"
    tmp="$(mktemp -d "${TMPDIR:-/tmp/opencode}/borg-nodb.XXXXXX")"
    trap 'rm --recursive --force -- "${tmp}"' EXIT

    source "${root}/libs/local/borg_config_helper.sh"
    function project_get_install_type() { echo "default"; }
    function project_get_database_engine() { echo ""; }
    # Present so the pre-opt-out failure is the database-name validation, not a
    # missing function (which would make this test pass for the wrong reason).
    function project_get_database_name() { echo "${TEST_DB:-}"; }
    function log_event() { :; }

    mkdir --parents "${tmp}/bin" "${tmp}/templates/config/borg" "${tmp}/www/site.example" "${tmp}/out"
    touch "${tmp}/www/site.example/app"
    cp "${root}/tests/fixtures/borg_safety_yq.py" "${tmp}/bin/yq"
    chmod +x "${tmp}/bin/yq"
    export PATH="${tmp}/bin:${PATH}" BROLIT_MAIN_DIR="${tmp}/templates"

    printf '%s\n' '{"constants":{"project":"project_domain","group":"group_server","hostname":"hostname_server"},"repositories":[],"source_directories":[]}' \
        > "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template-default.yml"
    printf '%s\n' '{"constants":{"project":"project_domain","group":"group_server","hostname":"hostname_server"},"repositories":[],"source_directories":[],"mysql_databases":[{"name":"{database}"}]}' \
        > "${BROLIT_MAIN_DIR}/config/borg/borgmatic.template-mysql.yml"

    BACKUP_BORG_GROUP="fixture-group" HOSTNAME="fixture-host"
    local -a BACKUP_BORG_USERS=(user1) BACKUP_BORG_SERVERS=(one.example) BACKUP_BORG_PORTS=(22)

    # Without an opt-out, a project with no database still takes the MySQL
    # template and fails because {database} cannot be resolved.
    TEST_DB=""
    if ! status="$(generate_borg_config site.example "${tmp}/out" "${tmp}/www")"; then
        : # expected failure path, asserted below
    fi
    [[ "${status}" == "failed" ]]

    # With BROLIT_DB_ENGINE=none, it must use the default template and produce
    # a valid config with no mysql_databases section and no ${database}.
    printf 'BROLIT_DB_ENGINE=none\n' > "${tmp}/www/site.example/.env"
    status="$(generate_borg_config site.example "${tmp}/out" "${tmp}/www")"
    [[ "${status}" == "created" ]]
    [[ -f "${tmp}/out/site.example.yml" ]]
    ! grep -q 'mysql_databases' "${tmp}/out/site.example.yml"
    ! grep -q '\${database}' "${tmp}/out/site.example.yml"

    # Positive control: a resolvable database keeps the MySQL template and its
    # constant, proving the opt-out is the only thing changing the choice.
    rm -f "${tmp}/out/site.example.yml" "${tmp}/www/site.example/.env"
    TEST_DB="realdb"
    status="$(generate_borg_config site.example "${tmp}/out" "${tmp}/www")"
    [[ "${status}" == "created" ]]
    grep -q 'mysql_databases' "${tmp}/out/site.example.yml"
    grep -q 'realdb' "${tmp}/out/site.example.yml"
)

test_borg_no_db_template
