#!/usr/bin/env bash
# Author: GauchoCode
# Version: 3.14
# Description: Offline regressions for project database-name detection.
################################################################################

################################################################################
# Assert project_get_database_name resolves compose-level placeholders from
# the sibling .env instead of leaking them into generated borgmatic configs.
#
# Arguments:
#   none
# Outputs:
#   0 if all assertions pass, 1 on error.
################################################################################
function test_project_database_name() (
    set -e
    local root tmp
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    mkdir --parents "${TMPDIR:-/tmp/opencode}"
    tmp="$(mktemp -d "${TMPDIR:-/tmp/opencode}/db-name.XXXXXX")"
    trap 'rm --recursive --force -- "${tmp}"' EXIT

    source "${root}/libs/local/project_helper.sh"
    export PROJECTS_PATH="${tmp}/www"
    mkdir --parents "${tmp}/www/site.example"

    # Compose placeholder + real value in .env: must resolve from .env.
    printf 'services:\n  db:\n    environment:\n      MYSQL_DATABASE: ${MYSQL_DATABASE}\n' \
        > "${tmp}/www/site.example/docker-compose.yml"
    printf 'MYSQL_DATABASE=support_epicahub_prod\n' > "${tmp}/www/site.example/.env"
    [[ "$(project_get_database_name site.example docker-compose)" == "support_epicahub_prod" ]]

    # A literal compose value still wins.
    printf 'services:\n  db:\n    environment:\n      MYSQL_DATABASE: real_db\n' \
        > "${tmp}/www/site.example/docker-compose.yml"
    [[ "$(project_get_database_name site.example docker-compose)" == "real_db" ]]

    # Placeholder with no value in .env: empty, never the placeholder itself.
    printf 'services:\n  db:\n    environment:\n      MYSQL_DATABASE: ${MYSQL_DATABASE}\n' \
        > "${tmp}/www/site.example/docker-compose.yml"
    : > "${tmp}/www/site.example/.env"
    [[ -z "$(project_get_database_name site.example docker-compose)" ]]

    # No compose file: the .env fallback still works.
    rm -f "${tmp}/www/site.example/docker-compose.yml"
    printf 'POSTGRES_DB=pg_db\n' > "${tmp}/www/site.example/.env"
    [[ "$(project_get_database_name site.example docker-compose)" == "pg_db" ]]
)

test_project_database_name
