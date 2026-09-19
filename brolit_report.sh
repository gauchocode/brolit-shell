#!/usr/bin/env bash

set -euo pipefail

BROLIT_MAIN_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
# shellcheck source=libs/release_manifest.sh
source "${BROLIT_MAIN_DIR}/libs/release_manifest.sh"

started_ns="$(date +%s%N)"
operation="${1:-metadata}"

if [[ "${operation}" != "metadata" && "${operation}" != "capabilities" ]]; then
    jq -n --arg operation "${operation}" '{error:"unsupported_operation", operation:$operation}'
    exit 2
fi

server_identity="null"
if [[ -r /etc/brolit/server_identity ]]; then
    identity="$(tr -d '\r\n' </etc/brolit/server_identity)"
    if [[ "${identity}" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$ ]]; then
        server_identity="$(jq -Rn --arg value "${identity}" '$value')"
    fi
fi

finished_ns="$(date +%s%N)"
duration_ms=$(( (finished_ns - started_ns) / 1000000 ))
capabilities="$(release_manifest_capabilities)"
errors_json='[]'
if ! release_manifest_is_immutable; then
    errors_json='["legacy_runtime"]'
fi

jq -n \
    --arg producer_version "$(release_manifest_value version)" \
    --arg producer_commit "$(release_manifest_commit)" \
    --arg protocol_version "$(release_manifest_value protocol_version)" \
    --arg min_admin_protocol "$(release_manifest_value min_admin_protocol)" \
    --arg hostname "${HOSTNAME:-unknown}" \
    --arg collected_at "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" \
    --argjson duration_ms "${duration_ms}" \
    --argjson server_identity "${server_identity}" \
    --argjson capabilities "${capabilities}" \
    --argjson errors "${errors_json}" \
    --arg operation "${operation}" \
    '{protocol_name:"brolit-shell-report", protocol_version:($protocol_version|tonumber), producer_version:$producer_version, producer_commit:$producer_commit, min_admin_protocol:($min_admin_protocol|tonumber), hostname:$hostname, server_identity:$server_identity, capabilities:$capabilities, operation:$operation, collected_at:$collected_at, duration_ms:$duration_ms, errors:$errors}'
