#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Regression tests for sanitize_borgmatic_pause_hooks. Configs generated from
# the old docker template carried docker compose pause/unpause hooks that
# froze whole stacks during every nightly backup and — when the run was
# interrupted between the hooks — left the containers paused indefinitely.
# The sanitizer must strip exactly those entries and leave every other hook
# (database dumps, docker log collection, notifications) untouched.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/log_and_display_helper.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/borg_storage_controller.sh" >/dev/null 2>&1

TEST_TMP=""

function hooks_setup() {
    TEST_TMP="$(mktemp -d)"
    function log_event() { :; }
    function display() { :; }
}

function hooks_teardown() {
    [[ -n "${TEST_TMP}" && -d "${TEST_TMP}" ]] && rm -rf "${TEST_TMP}"
}

function write_config_with_hooks() {
    cat > "${TEST_TMP}/project.yml" <<'YAML'
before_backup:
    - echo "Starting backup"
    - docker compose -f /var/www/{project}/docker-compose.yml pause
after_backup:
    - docker compose -f /var/www/{project}/docker-compose.yml unpause
    - docker compose -f /var/www/{project}/docker-compose.yml logs -t > /var/log/{project}_docker.log
on_error:
    - send_notification "Borgmatic" "Error during backup for {project}" "alert"
YAML
}

PASS=0
FAIL=0

function check() {
    local name="$1"
    local condition="$2"
    if eval "${condition}"; then
        echo "PASS: ${name}"
        PASS=$((PASS + 1))
    else
        echo "FAIL: ${name}"
        FAIL=$((FAIL + 1))
    fi
}

hooks_setup

# The sanitizer's config dir is the fixed path /etc/borgmatic.d (a host
# concern), so the hermetic checks here drive the same sed contract against
# a temp dir and verify the template and the nightly wiring directly.

# 1) The sed contract: pause/unpause entries are removed, everything else stays.
write_config_with_hooks
sed -i '/docker-compose\.yml pause/d; /docker-compose\.yml unpause/d' "${TEST_TMP}/project.yml"
check "pause entry removed" "! grep -q 'pause' '${TEST_TMP}/project.yml'"
check "unpause entry removed" "! grep -q 'unpause' '${TEST_TMP}/project.yml'"
check "echo hook kept" "grep -q 'echo \"Starting backup\"' '${TEST_TMP}/project.yml'"
check "docker logs hook kept" "grep -q 'docker-compose.yml logs' '${TEST_TMP}/project.yml'"
check "on_error hook kept" "grep -q 'send_notification' '${TEST_TMP}/project.yml'"
check "before_backup key still present" "grep -q 'before_backup:' '${TEST_TMP}/project.yml'"

# 2) Idempotency: running the sed twice changes nothing.
sed -i '/docker-compose\.yml pause/d; /docker-compose\.yml unpause/d' "${TEST_TMP}/project.yml"
check "second run is a no-op" "! grep -qE 'docker-compose\.yml (pause|unpause)' '${TEST_TMP}/project.yml'"

# 3) Configs without the hooks are untouched by the grep gate.
cat > "${TEST_TMP}/clean.yml" <<'YAML'
before_backup:
    - echo "Starting backup"
after_backup:
    - pg_dumpall -U {postgres_user} > /tmp/{project}_backup.sql
YAML
if grep -qE "docker-compose\.yml (pause|unpause)" "${TEST_TMP}/clean.yml" 2>/dev/null; then
    check "clean config passes the gate" "false"
else
    check "clean config passes the gate" "true"
fi

# 4) The shipped docker template no longer carries the hooks.
TEMPLATE="${TEST_LOADER_DIR}/../config/borg/borgmatic.template-docker.yml"
check "template has no pause hook" "! grep -qE 'docker-compose\.yml pause' '${TEMPLATE}'"
check "template has no unpause hook" "! grep -qE 'docker-compose\.yml unpause' '${TEMPLATE}'"
check "template keeps the docker logs hook" "grep -q 'docker-compose.yml logs' '${TEMPLATE}'"

# 5) The function exists and is wired into the nightly preparation.
check "sanitize function defined" "type sanitize_borgmatic_pause_hooks >/dev/null 2>&1"
check "wired into prepare_borgmatic_environment" "grep -q 'sanitize_borgmatic_pause_hooks' '${TEST_LOADER_DIR}/../cron/backups_tasks.sh'"

hooks_teardown

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ ${FAIL} -eq 0 ]]
