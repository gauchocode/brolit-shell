#!/usr/bin/env bash
# No debug log line may interpolate a credential. Logs stay on servers and are read by humans.
set -uo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
bad="$(grep -rnE 'log_event "debug".*(NTFY_PASSWORD|SMTP_UPASS|SMTP_PASS|TELEGRAM_BOT_TOKEN|notif_url|db_root_psw)' "${ROOT_DIR}/libs" "${ROOT_DIR}/utils" "${ROOT_DIR}/cron" "${ROOT_DIR}"/*.sh 2>/dev/null | cut -c1-120)"
[[ -z "${bad}" ]] || { echo "FAIL: debug log lines interpolate secrets:"; echo "${bad}"; exit 1; }
# Unattended paths (nightly, cron): no log line of any level may carry a credential header or a
# credential option with its value interpolated.
bad2="$(grep -rnE 'log_event .*(X-Auth-Token: \$\{|Authorization: [A-Za-z]+ \$\{|--ftp-password=\\"\$\{)' "${ROOT_DIR}/libs" "${ROOT_DIR}/utils" "${ROOT_DIR}/cron" "${ROOT_DIR}"/*.sh 2>/dev/null | cut -c1-120)"
[[ -z "${bad2}" ]] || { echo "FAIL: log lines interpolate credential headers/options:"; echo "${bad2}"; exit 1; }
echo "no secrets in debug logs tests passed"
