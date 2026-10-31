#!/usr/bin/env bash
# Author: GauchoCode
# Version: 3.14
# Description: Offline regressions for certificate domain triage.
################################################################################

################################################################################
# Assert certbot_domain_triage classifies NXDOMAIN, Cloudflare-fronted, moved
# and healthy domains, using a stubbed resolver and public IP (no network).
#
# Arguments:
#   none
# Outputs:
#   0 if all assertions pass, 1 on error.
################################################################################
function test_certbot_domain_triage() (
    set -e
    local root
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${root}/libs/apps/certbot_helper.sh"

    export CERTBOT_TRIAGE_PUBLIC_IP="203.0.113.10"

    # Cloudflare range matching, including both edges of a range.
    [[ "$(_certbot_ip_is_cloudflare 104.21.57.32)" == "yes" ]]
    [[ "$(_certbot_ip_is_cloudflare 172.67.188.235)" == "yes" ]]
    [[ "$(_certbot_ip_is_cloudflare 198.41.255.255)" == "yes" ]]
    [[ "$(_certbot_ip_is_cloudflare 198.42.0.1)" == "no" ]]
    [[ "$(_certbot_ip_is_cloudflare 5.161.246.86)" == "no" ]]

    # shellcheck disable=SC2317
    function _certbot_domain_ipv4() { echo "${TEST_DNS:-}"; }

    TEST_DNS=""
    [[ "$(certbot_domain_triage dead.example)" == "nxdomain" ]]

    TEST_DNS="104.21.57.32 172.67.188.235"
    [[ "$(certbot_domain_triage cf.example)" == "cloudflare" ]]

    TEST_DNS="5.161.246.86"
    [[ "$(certbot_domain_triage moved.example)" == "moved" ]]

    TEST_DNS="203.0.113.10"
    [[ "$(certbot_domain_triage local.example)" == "ok" ]]

    # Several A records, one of them this server: healthy, not moved.
    TEST_DNS="203.0.113.10 5.161.246.86"
    [[ "$(certbot_domain_triage multi.example)" == "ok" ]]

    # Public IP unknown: must not guess "moved".
    unset CERTBOT_TRIAGE_PUBLIC_IP
    # shellcheck disable=SC2317
    function _certbot_public_ip() { echo ""; }
    TEST_DNS="5.161.246.86"
    [[ "$(certbot_domain_triage unknown-ip.example)" == "ok" ]]
)

test_certbot_domain_triage
