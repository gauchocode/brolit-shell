#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.15
#############################################################################
#
# Regression test for Docker port detection without a .env file.
#
# On 2026-11-26 `migrate site` of riverside.edu.ar failed in the remote
# restore with "Port is required for Docker projects". The project is a static
# site with no .env: its port (8081:80) is published only in
# docker-compose.yml. project_get_port_from_env() returned before trying the
# `docker compose config` strategy whenever no .env file existed, so the
# restore found no port and tried to ask a user through whiptail.
#
# docker is faked on PATH: no containers, no network.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1091
source "${TEST_LOADER_DIR}/../libs/commons.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/local/project_helper.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/apps/docker_helper.sh" >/dev/null 2>&1

function tpwe_fake_docker() {

    local dir="${1}"
    local json="${2}"

    mkdir -p "${dir}/bin"
    cat > "${dir}/bin/docker" <<FAKE
#!/usr/bin/env bash
echo '${json}'
FAKE
    chmod +x "${dir}/bin/docker"

}

function tpwe_assert_port() {

    local label="${1}" expected="${2}" project="${3}" fakebin="${4}"
    local got

    function log_event() { :; }
    got="$(PATH="${fakebin}:${PATH}" project_get_port_from_env "${project}")"

    if [[ "${got}" == "${expected}" ]]; then
        echo "PASS: ${label} (port='${got}')"
        return 0
    fi
    echo "FAIL: ${label}: expected '${expected}', got '${got}'"
    return 1

}

function test_project_port_without_env() {

    local tmp failed=0
    tmp="$(mktemp -d)"

    # 1. No .env, one published port in the compose file -> that port.
    mkdir -p "${tmp}/static"
    echo "services: {}" > "${tmp}/static/docker-compose.yml"
    tpwe_fake_docker "${tmp}/one" '{"services":{"web":{"ports":[{"published":"8081","target":80}]}}}'
    tpwe_assert_port "no .env, single published port" "8081" "${tmp}/static" "${tmp}/one/bin" || failed=1

    # 2. No .env, no published port -> empty (caller still fails closed).
    tpwe_fake_docker "${tmp}/none" '{"services":{"web":{}}}'
    tpwe_assert_port "no .env, no published port" "" "${tmp}/static" "${tmp}/none/bin" || failed=1

    # 3. No .env, ambiguous (two published ports) -> empty, never a guess.
    tpwe_fake_docker "${tmp}/two" '{"services":{"a":{"ports":[{"published":"81"}]},"b":{"ports":[{"published":"82"}]}}}'
    tpwe_assert_port "no .env, ambiguous ports" "" "${tmp}/static" "${tmp}/two/bin" || failed=1

    # 4. No .env and no compose file -> empty.
    mkdir -p "${tmp}/empty"
    tpwe_assert_port "no .env, no compose file" "" "${tmp}/empty" "${tmp}/one/bin" || failed=1

    # 5. .env still wins the fallback path when compose has no single port.
    mkdir -p "${tmp}/withenv"
    echo "services: {}" > "${tmp}/withenv/docker-compose.yml"
    printf 'APP_PORT=9090\n' > "${tmp}/withenv/.env"
    tpwe_assert_port ".env fallback unchanged" "9090" "${tmp}/withenv" "${tmp}/none/bin" || failed=1

    rm -rf "${tmp}"
    return ${failed}

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "========================================="
    echo "Project port detection without .env"
    echo "========================================="
    test_project_port_without_env || exit 1
    echo "All tests completed"
fi
