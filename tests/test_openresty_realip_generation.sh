#!/usr/bin/env bash
# Author: GauchoCode
# Version: 3.14
# Description: Offline regressions for OpenResty client-IP preservation (PROXY protocol).
################################################################################

################################################################################
# Assert the generated gateway config preserves the client address when a
# fallback upstream is configured, and gains no new directive when it is not.
#
# Covers both required pieces: PROXY protocol on the stream layer and on the
# generated HTTPS listens, and the realip block that actually rewrites
# $remote_addr (a listen with proxy_protocol only accepts the header).
#
# Arguments:
#   none
# Outputs:
#   0 if all assertions pass, 1 on error.
################################################################################
function test_openresty_realip_generation() (
    set -e
    local root conf routes
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${root}/utils/installers/openresty_installer.sh"

    export OPENRESTY_API_ALLOW_NETWORK="10.2.0.0/24"
    export OPENRESTY_FALLBACK_UPSTREAM="10.2.0.100"
    conf="$(_openresty_generate_nginx_conf vm "")"

    # The public 443 is owned by the stream layer, which must speak PROXY.
    grep -qF 'proxy_protocol on;' <<<"${conf}"
    [[ "$(grep -cF 'proxy_protocol on;' <<<"${conf}")" -eq 1 ]]
    [[ "$(_openresty_ssl_listen_addr)" == "127.0.0.1:8443" ]]

    # Unmanaged SNI is relayed, so the fallback never receives a PROXY header.
    grep -qF 'default 127.0.0.1:9443;' <<<"${conf}"
    grep -qF 'listen 127.0.0.1:9443 proxy_protocol;' <<<"${conf}"
    grep -qF 'proxy_pass 10.2.0.100:443;' <<<"${conf}"
    [[ "$(grep -cF 'listen 127.0.0.1:9443 proxy_protocol;' <<<"${conf}")" -eq 1 ]]
    if grep -qF 'default 10.2.0.100:443;' <<<"${conf}"; then
        echo "fallback must not receive PROXY protocol directly" >&2
        return 1
    fi

    # realip is what rewrites $remote_addr, and therefore X-Real-IP.
    grep -qF 'set_real_ip_from 127.0.0.1;' <<<"${conf}"
    grep -qF 'real_ip_header proxy_protocol;' <<<"${conf}"

    # routes.lua must generate PROXY-aware HTTPS listens: any route created
    # after the change would otherwise stop answering once the stream layer
    # starts sending PROXY protocol.
    routes="${root}/config/openresty/api/routes.lua"
    grep -qF 'local function ssl_listen_directive(ssl_listen)' "${routes}"
    grep -qF 'if ssl_listen ~= DEFAULT_SSL_LISTEN then' "${routes}"
    grep -qF 'directive = directive .. " proxy_protocol"' "${routes}"
    if grep -qF 'listen ]] .. ssl_listen .. [[ ssl http2;' "${routes}"; then
        echo "routes.lua still generates HTTPS listens without PROXY protocol" >&2
        return 1
    fi
    [[ "$(grep -cF 'listen ]] .. ssl_listen_directive(ssl_listen) .. [[;' "${routes}")" -eq 3 ]]

    # Behavioural check of the helper itself (not just its presence), when a
    # Lua interpreter is available: PROXY only on the internal listener.
    if command -v luajit >/dev/null 2>&1; then
        local helper
        helper="$(sed -n '/^local function ssl_listen_directive/,/^end$/p' "${routes}")"
        [[ -n "${helper}" ]]
        luajit -e "DEFAULT_SSL_LISTEN = '443'; ${helper}
assert(ssl_listen_directive('127.0.0.1:8443') == '127.0.0.1:8443 ssl http2 proxy_protocol')
assert(ssl_listen_directive('443') == '443 ssl http2')"
    fi

    # Without a fallback upstream there is no stream layer and no realip:
    # the generated config must not acquire any of the new directives.
    export OPENRESTY_FALLBACK_UPSTREAM=""
    conf="$(_openresty_generate_nginx_conf vm "")"
    [[ "$(_openresty_ssl_listen_addr)" == "443" ]]
    if grep -qE 'proxy_protocol|real_ip_header|set_real_ip_from|^stream \{' <<<"${conf}"; then
        echo "config without fallback upstream must not gain stream/realip directives" >&2
        return 1
    fi
)

test_openresty_realip_generation
