#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.15
#############################################################################
#
# On a Proxmox guest in gateway mode, nginx_server_create hands the site to the
# OpenResty gateway. It passed only the port, so the gateway proxied
# 127.0.0.1:<port> on ITSELF (nothing there) and the site answered 502 while its
# certificate was already issued (pve-test.gauchocode.com, 2026-11-26). The route
# must carry the upstream: this server's internal address and the project port.
# The gateway call and the address lookup are faked: no network, no gateway.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1091
source "${TEST_LOADER_DIR}/../libs/commons.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/apps/nginx_helper.sh" >/dev/null 2>&1

function test_openresty_route_upstream() {

    local failed=0 tmp
    tmp="$(mktemp -d)"
    mkdir -p "${tmp}/bin"
    cat > "${tmp}/bin/ip" <<'FAKE'
#!/usr/bin/env bash
echo "1.1.1.1 via 10.2.0.1 dev ens18 src 10.2.0.104 uid 0"
FAKE
    chmod +x "${tmp}/bin/ip"

    local got
    got="$(PATH="${tmp}/bin:${PATH}" network_get_internal_ip)"
    [[ "${got}" == "10.2.0.104" ]] && echo "PASS: internal address read from the default route (${got})" || { echo "FAIL: internal ip '${got}'"; failed=1; }

    CALLS_FILE="${tmp}/calls"
    : > "${CALLS_FILE}"
    function openresty_is_installed() { return 0; }
    function openresty_server_create() { printf '%s\n' "$*" >> "${CALLS_FILE}"; return 0; }
    export PROXMOX_MODE="enabled"

    PATH="${tmp}/bin:${PATH}" nginx_server_create "pve-test.example.com" "proxy" "root_domain" "www.example.com" "8081"
    grep -qx "pve-test.example.com proxy root_domain www.example.com 8081 http://10.2.0.104:8081" "${CALLS_FILE}" \
        && echo "PASS: a Dockerized site is routed to this server's internal address and port" \
        || { echo "FAIL: call was: $(cat "${CALLS_FILE}")"; failed=1; }

    : > "${CALLS_FILE}"
    PATH="${tmp}/bin:${PATH}" nginx_server_create "classic.example.com" "wordpress" "single" "" ""
    grep -qx "classic.example.com wordpress single   " "${CALLS_FILE}" \
        && echo "PASS: no port, no upstream (unchanged for non-proxy sites)" \
        || { echo "FAIL: call was: [$(cat "${CALLS_FILE}")]"; failed=1; }

    rm -rf "${tmp}"
    return ${failed}

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "========================================="
    echo "OpenResty route carries the upstream"
    echo "========================================="
    test_openresty_route_upstream || exit 1
    echo "All tests completed"
fi
