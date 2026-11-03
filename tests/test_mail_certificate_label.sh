#!/usr/bin/env bash
# Author: GauchoCode
# Version: 3.14
# Description: Offline regressions for the mail certificate label decisions.
################################################################################

################################################################################
# The certificate label decision (libs/apps/certbot_helper.sh,
# mail_certificate_label) is a pure function of its inputs, so the three mail
# decisions can be tested without certificates, DNS or API calls:
#   1. no certificate: grey without a vhost; behind Cloudflare grey on
#      flexible/off, warning on full/strict, configurable on unknown
#   2. expired: always a warning, labelled with the actual cause
#   3. days remaining: green/orange/red thresholds
# plus the operator expectation map (zone suffix match, no API involved).
#
# Arguments:
#   none
# Outputs:
#   0 if all assertions pass, 1 on error.
################################################################################
function test_mail_certificate_label() (
    set -e
    local root
    root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "${root}/libs/apps/certbot_helper.sh"

    # 1) No certificate.
    [[ "$(mail_certificate_label "" "" false "" "")" == "grey|0|no certificate" ]]
    [[ "$(mail_certificate_label "" ok true "" "")" == "red|1|no certificate" ]]
    [[ "$(mail_certificate_label "" nxdomain true "" "")" == "red|1|nxdomain" ]]
    [[ "$(mail_certificate_label "" moved true "" "")" == "red|1|moved" ]]
    # Cloudflare fronted, SSL mode not queried / edge-terminated modes: grey.
    [[ "$(mail_certificate_label "" cloudflare true "" "")" == "grey|0|CF fronted" ]]
    [[ "$(mail_certificate_label "" cloudflare true flexible "")" == "grey|0|CF fronted" ]]
    [[ "$(mail_certificate_label "" cloudflare true off "")" == "grey|0|CF fronted" ]]
    # Full/strict pulls the origin certificate into the chain: warning.
    [[ "$(mail_certificate_label "" cloudflare true full "")" == "red|1|CF full: origin cert required" ]]
    [[ "$(mail_certificate_label "" cloudflare true strict "")" == "red|1|CF strict: origin cert required" ]]
    # A pinned expectation wins when the zone mode deviates from it.
    [[ "$(mail_certificate_label "" cloudflare true full flexible)" == "red|1|CF full != flexible" ]]
    # Unknown mode: grey by default so an unreachable API cannot produce daily
    # noise; BROLIT_CERT_CF_UNKNOWN=warn opts a deployment into warning.
    [[ "$(mail_certificate_label "" cloudflare true unknown "")" == "grey|0|CF fronted" ]]
    BROLIT_CERT_CF_UNKNOWN=warn
    [[ "$(mail_certificate_label "" cloudflare true unknown "")" == "red|1|CF mode unknown" ]]
    unset BROLIT_CERT_CF_UNKNOWN

    # 2) Expired: always a warning, labelled with the actual cause.
    [[ "$(mail_certificate_label EXPIRED "" true "" "")" == "red|1|EXPIRED" ]]
    [[ "$(mail_certificate_label EXPIRED nxdomain true "" "")" == "red|1|nxdomain" ]]
    [[ "$(mail_certificate_label EXPIRED moved true "" "")" == "red|1|moved" ]]
    [[ "$(mail_certificate_label EXPIRED cloudflare true "" "")" == "red|1|EXPIRED" ]]

    # 3) Days remaining thresholds.
    [[ "$(mail_certificate_label 30 ok true "" "")" == "green|0|30 days" ]]
    [[ "$(mail_certificate_label 14 ok true "" "")" == "green|0|14 days" ]]
    [[ "$(mail_certificate_label 13 ok true "" "")" == "orange|0|13 days" ]]
    [[ "$(mail_certificate_label 7 ok true "" "")" == "orange|0|7 days" ]]
    [[ "$(mail_certificate_label 6 ok true "" "")" == "red|1|6 days" ]]
    [[ "$(mail_certificate_label 1 ok true "" "")" == "red|1|1 days" ]]

    # Operator expectation map: zone suffix matching, no API involved.
    BROLIT_CLOUDFLARE_SSL_EXPECT="broobe.com=flexible example.com=full"
    [[ "$(_certbot_cloudflare_ssl_expected www.broobe.com)" == "flexible" ]]
    [[ "$(_certbot_cloudflare_ssl_expected broobe.com)" == "flexible" ]]
    [[ "$(_certbot_cloudflare_ssl_expected example.com)" == "full" ]]
    [[ "$(_certbot_cloudflare_ssl_expected other.org)" == "" ]]
    [[ "$(_certbot_cloudflare_ssl_expected "")" == "" ]]
    unset BROLIT_CLOUDFLARE_SSL_EXPECT
)

test_mail_certificate_label
