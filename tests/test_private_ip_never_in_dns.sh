#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.15
#############################################################################
#
# On 2026-11-26 `migrate` of jumpnetcorp.com.ar to gaucho-host01-vm (a Proxmox
# guest behind NAT) published 10.2.0.104 in Cloudflare and took the site down.
# get_server_public_ip() returned the address of the default interface, which is
# private behind NAT, and cloudflare_set_record() deletes the existing record
# before creating the new one.
#
# Pinned here:
#   1. network_is_private_ipv4 knows the ranges that cannot be published.
#   2. get_server_public_ip asks the outside world when the interface address is
#      private, and keeps a public interface address untouched.
#   3. cloudflare_set_record and cloudflare_update_record refuse a private A
#      content before any request is made.
# ip and curl are faked on PATH: no network.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
# shellcheck disable=SC1091
source "${TEST_LOADER_DIR}/../libs/commons.sh" >/dev/null 2>&1
# shellcheck disable=SC1090
source "${TEST_LOADER_DIR}/../libs/apps/cloudflare_helper.sh" >/dev/null 2>&1

function tpd_fake_bin() {

    local dir="${1}" iface_ip="${2}" external_ip="${3}"

    mkdir -p "${dir}"
    cat > "${dir}/ip" <<FAKE
#!/usr/bin/env bash
case "\$*" in
  route*) echo "default via 10.0.0.1 dev ens18 proto dhcp" ;;
  addr*) echo "    inet ${iface_ip}/16 brd 10.2.255.255 scope global ens18" ;;
esac
FAKE
    cat > "${dir}/curl" <<FAKE
#!/usr/bin/env bash
echo "CURL \$*" >> "${dir}/curl.log"
if [[ "\$*" == *icanhazip* ]]; then echo "${external_ip}"; fi
FAKE
    chmod +x "${dir}/ip" "${dir}/curl"

}

function test_private_ip_never_in_dns() {

    local failed=0 tmp got
    tmp="$(mktemp -d)"

    for ip in 10.2.0.104 192.168.1.5 172.16.0.1 172.31.255.254 127.0.0.1 169.254.1.1 100.64.0.1 100.127.255.1; do
        network_is_private_ipv4 "${ip}" && echo "PASS: ${ip} is private" || { echo "FAIL: ${ip} should be private"; failed=1; }
    done
    for ip in 5.161.255.48 213.199.58.220 172.15.0.1 172.32.0.1 100.63.0.1 100.128.0.1 8.8.8.8; do
        network_is_private_ipv4 "${ip}" && { echo "FAIL: ${ip} should be public"; failed=1; } || echo "PASS: ${ip} is public"
    done

    tpd_fake_bin "${tmp}/nat" "10.2.0.104" "213.199.58.220"
    got="$(PATH="${tmp}/nat:${PATH}" get_server_public_ip)"
    [[ "${got}" == "213.199.58.220" ]] && echo "PASS: behind NAT the external address is used (${got})" || { echo "FAIL: NAT got '${got}'"; failed=1; }

    tpd_fake_bin "${tmp}/direct" "5.161.255.48" "203.0.113.9"
    got="$(PATH="${tmp}/direct:${PATH}" get_server_public_ip)"
    [[ "${got}" == "5.161.255.48" ]] && echo "PASS: a public interface address is kept (${got})" || { echo "FAIL: direct got '${got}'"; failed=1; }
    [[ ! -f "${tmp}/direct/curl.log" ]] && echo "PASS: no external lookup when the interface is public" || { echo "FAIL: looked up externally"; failed=1; }

    # The guards must fire before any request: curl would log it.
    function log_event() { :; }
    function display() { :; }
    function _cloudflare_get_zone_id() { echo "zone"; }
    tpd_fake_bin "${tmp}/guard" "10.2.0.104" "10.2.0.104"
    PATH="${tmp}/guard:${PATH}" cloudflare_set_record "example.com" "example.com" "A" "false" "10.2.0.104"
    [[ $? -eq 1 && ! -f "${tmp}/guard/curl.log" ]] && echo "PASS: cloudflare_set_record refuses a private A before any request" || { echo "FAIL: set_record did not refuse"; failed=1; }
    PATH="${tmp}/guard:${PATH}" cloudflare_update_record "example.com" "example.com" "A" "false" "192.168.0.7"
    [[ $? -eq 1 && ! -f "${tmp}/guard/curl.log" ]] && echo "PASS: cloudflare_update_record refuses a private A before any request" || { echo "FAIL: update_record did not refuse"; failed=1; }

    rm -rf "${tmp}"
    return ${failed}

}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "========================================="
    echo "Private addresses never reach DNS"
    echo "========================================="
    test_private_ip_never_in_dns || exit 1
    echo "All tests completed"
fi
