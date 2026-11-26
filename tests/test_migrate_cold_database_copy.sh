#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.15
#############################################################################
#
# The files archive of a Docker project includes a bind-mounted database data
# directory. Copied while MariaDB runs it is not consistent: the restored copy of
# jumpnetcorp.com.ar (2026-11-26) failed with "InnoDB: Data structure
# corruption" and never started. `migrate` therefore archives with the database
# stopped, and starts it again (also when cancelled).
#
# Pinned here: only a database whose data directory is inside the project is
# stopped; a failed stop refuses the copy; resume starts exactly what was stopped
# and is safe to call twice; migrate asks for the cold copy and resumes on every
# exit path. docker is faked on PATH.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1091
source "${TEST_LOADER_DIR}/../libs/commons.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/backup_helper.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/apps/docker_helper.sh" >/dev/null 2>&1

function tcd_fake_docker() {

    local dir="${1}" bind_source="${2}" stop_rc="${3:-0}"

    mkdir -p "${dir}/bin"
    cat > "${dir}/bin/docker" <<FAKE
#!/usr/bin/env bash
echo "docker \$*" >> "${dir}/docker.log"
case "\$1" in
  compose) echo "shop_mysql" ;;
  inspect)
    if [[ "\$*" == *Mounts* ]]; then printf '%s\n' "${bind_source}"; else echo "healthy"; fi ;;
  stop) exit ${stop_rc} ;;
  start) exit 0 ;;
esac
FAKE
    chmod +x "${dir}/bin/docker"
    : > "${dir}/docker.log"

}

function test_migrate_cold_database_copy() {

    local failed=0 tmp rc
    tmp="$(mktemp -d)"
    function log_event() { :; }
    function display() { :; }
    function sleep() { :; }
    PROJECTS_PATH="/var/www"
    local detected=$'mysql\tmysql'

    # 1. data directory inside the project: stopped, then started again
    tcd_fake_docker "${tmp}/in" "/var/www/shop.example.com/mysql_data"
    BACKUP_QUIESCED_CONTAINERS=()
    PATH="${tmp}/in/bin:${PATH}" backup_quiesce_project_databases "shop.example.com" "${detected}" "/var/www/shop.example.com/docker-compose.yml"
    rc=$?
    if [[ ${rc} -eq 0 && "${BACKUP_QUIESCED_CONTAINERS[*]}" == "shop_mysql" ]] && grep -q "docker stop --time 120 shop_mysql" "${tmp}/in/docker.log"; then
        echo "PASS: a data directory inside the project is stopped for the copy"
    else echo "FAIL: not stopped (rc=${rc}, list='${BACKUP_QUIESCED_CONTAINERS[*]}')"; failed=1; fi

    PATH="${tmp}/in/bin:${PATH}" backup_resume_project_databases
    rc=$?
    if [[ ${rc} -eq 0 && ${#BACKUP_QUIESCED_CONTAINERS[@]} -eq 0 ]] && grep -q "docker start shop_mysql" "${tmp}/in/docker.log"; then
        echo "PASS: resume starts what was stopped and clears the list"
    else echo "FAIL: resume (rc=${rc})"; failed=1; fi

    : > "${tmp}/in/docker.log"
    PATH="${tmp}/in/bin:${PATH}" backup_resume_project_databases
    if [[ $? -eq 0 ]] && ! grep -q "docker start" "${tmp}/in/docker.log"; then
        echo "PASS: resuming twice starts nothing the second time"
    else echo "FAIL: second resume started containers"; failed=1; fi

    # 2. data outside the project (volume or other bind): left running
    tcd_fake_docker "${tmp}/out" "/srv/data/mysql"
    BACKUP_QUIESCED_CONTAINERS=()
    PATH="${tmp}/out/bin:${PATH}" backup_quiesce_project_databases "shop.example.com" "${detected}" "/var/www/shop.example.com/docker-compose.yml"
    if [[ $? -eq 0 && ${#BACKUP_QUIESCED_CONTAINERS[@]} -eq 0 ]] && ! grep -q "docker stop" "${tmp}/out/docker.log"; then
        echo "PASS: a data directory outside the project is not touched"
    else echo "FAIL: stopped a container whose data is not in the archive"; failed=1; fi

    # a project path that merely starts with the same text must not match
    tcd_fake_docker "${tmp}/prefix" "/var/www/shop.example.com-old/mysql_data"
    BACKUP_QUIESCED_CONTAINERS=()
    PATH="${tmp}/prefix/bin:${PATH}" backup_quiesce_project_databases "shop.example.com" "${detected}" "/x/docker-compose.yml"
    ! grep -q "docker stop" "${tmp}/prefix/docker.log" && echo "PASS: a sibling directory with the same prefix is not matched" || { echo "FAIL: matched a sibling project"; failed=1; }

    # 3. a stop that fails refuses the copy
    tcd_fake_docker "${tmp}/fail" "/var/www/shop.example.com/mysql_data" 1
    BACKUP_QUIESCED_CONTAINERS=()
    PATH="${tmp}/fail/bin:${PATH}" backup_quiesce_project_databases "shop.example.com" "${detected}" "/var/www/shop.example.com/docker-compose.yml"
    [[ $? -eq 1 && ${#BACKUP_QUIESCED_CONTAINERS[@]} -eq 0 ]] && echo "PASS: a database that cannot be stopped refuses the copy" || { echo "FAIL: copy allowed with a live database"; failed=1; }

    # 4. wiring: only migrate asks for it, and it resumes on every way out
    grep -q 'declare -g BROLIT_BACKUP_QUIESCE_DB=1' "${TEST_LOADER_DIR}/../libs/local/site_migration_helper.sh" \
        && echo "PASS: migrate asks for the cold copy" || { echo "FAIL: migrate does not ask for it"; failed=1; }
    grep -q 'BROLIT_BACKUP_QUIESCE_DB:-0} == "1"' "${TEST_LOADER_DIR}/../libs/local/backup_helper.sh" \
        && echo "PASS: regular backups never stop a database (opt-in only)" || { echo "FAIL: not opt-in"; failed=1; }
    awk '/^function _migrate_on_signal/,/^}/' "${TEST_LOADER_DIR}/../libs/local/site_migration_helper.sh" | grep -q "backup_resume_project_databases" \
        && echo "PASS: a cancelled migration starts the database again" || { echo "FAIL: signal path does not resume"; failed=1; }

    rm -rf "${tmp}"
    return ${failed}

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "========================================="
    echo "migrate copies a stopped database"
    echo "========================================="
    test_migrate_cold_database_copy || exit 1
    echo "All tests completed"
fi
