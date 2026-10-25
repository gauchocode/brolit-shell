#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Regression tests for safe, actionable process-scanner notifications.

TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
BROLIT_MAIN_DIR="$(cd "${TEST_LOADER_DIR}/.." &>/dev/null && pwd -P)"
export BROLIT_MAIN_DIR

# shellcheck disable=SC1090
source "${BROLIT_MAIN_DIR}/libs/local/security_helper.sh"

################################################################################
# Assert two strings are equal.
#
# Arguments:
#  ${1} = Expected value.
#  ${2} = Actual value.
#  ${3} = Assertion label.
#
# Outputs:
#  Failure detail on stderr when values differ.
################################################################################

function assert_equal() {
  local expected="${1}"
  local actual="${2}"
  local label="${3}"
  if [[ "${actual}" != "${expected}" ]]; then
    printf 'FAILED (%s): expected %q, got %q\n' "${label}" "${expected}" "${actual}" >&2
    return 1
  fi
}

################################################################################
# Run process-scanner notification and protocol regressions.
#
# Arguments:
#  none
#
# Outputs:
#  Failure details on stderr. Returns nonzero when any assertion fails.
################################################################################

function test_process_scanner_notifications() {
  local failed=0
  local test_tmp
  local report_file
  local summary
  local message

  test_tmp="$(mktemp -d)"
  export BROLIT_RUNTIME_STATE_DIR="${test_tmp}"
  mkdir -p "${test_tmp}/reports"
  report_file="${test_tmp}/reports/process-malware-scan-20261025_120000.log"
  echo "SCAN_COMPLETE" >"${report_file}"

  summary="$(security_process_scanner_reason_summary "suspicious_cron_download,suspicious_container_process")"
  assert_equal "cron download command requiring review; container process matching a miner signature" "${summary}" "known reason summary" || failed=1

  summary="$(security_process_scanner_reason_summary "future_untrusted_code")"
  assert_equal "unclassified critical indicator" "${summary}" "unknown reason is not reflected" || failed=1

  summary="$(security_process_scanner_reason_summary "")"
  assert_equal "unclassified critical indicator" "${summary}" "missing reason fails closed" || failed=1

  message="$(security_process_scanner_alert_message "hidden_temp_executable" "/var/lib/brolit/reports/process-malware-scan-test.log")"
  [[ "${message}" == *"hidden executable in a temporary directory"* ]] || {
    echo "FAILED: alert omits the safe reason summary" >&2
    failed=1
  }
  [[ "${message}" == *"/var/lib/brolit/reports/process-malware-scan-test.log"* ]] || {
    echo "FAILED: alert omits the report path" >&2
    failed=1
  }

  security_process_scanner_parse_machine_result "true|hidden_temp_executable|${report_file}" || {
    echo "FAILED: valid machine result was rejected" >&2
    failed=1
  }
  assert_equal "true" "${PROCESS_SCANNER_PARSED_STATUS}" "parsed status" || failed=1

  local malformed
  for malformed in \
    "true||${report_file}" \
    "true|future_untrusted_code|${report_file}" \
    "true|hidden_temp_executable,|${report_file}" \
    "false|hidden_temp_executable|${report_file}" \
    "false||/tmp/untrusted-report.log" \
    "false||${report_file}|extra"; do
    if security_process_scanner_parse_machine_result "${malformed}"; then
      echo "FAILED: malformed machine result was accepted: ${malformed}" >&2
      failed=1
    fi
  done

  security_process_scanner_should_open_menu "interactive" "true" || {
    echo "FAILED: explicit interactive critical scan should allow the menu" >&2
    failed=1
  }
  if security_process_scanner_should_open_menu "machine" "true"; then
    echo "FAILED: machine mode must never allow the interactive menu" >&2
    failed=1
  fi

  grep -Fq 'security_process_scanner "machine"' "${BROLIT_MAIN_DIR}/cron/security_tasks.sh" || {
    echo "FAILED: scheduled scanner is not explicitly non-interactive" >&2
    failed=1
  }
  grep -Fq '${SERVER_NAME} - Malware scanner alert' "${BROLIT_MAIN_DIR}/cron/security_tasks.sh" || {
    echo "FAILED: scheduled alert subject lacks context" >&2
    failed=1
  }

  rm -rf "${test_tmp}"
  return ${failed}
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_process_scanner_notifications || exit 1
  echo "Process scanner notification tests passed"
fi
