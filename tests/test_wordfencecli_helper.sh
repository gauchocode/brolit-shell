#!/usr/bin/env bash
#
# Author: GauchoCode
# Version: 3.14
# Description: Mocked tests for Wordfence CLI build and scan behavior.
# Docker integration (requires a valid Wordfence license):
# ./runner.sh -t security-scan -st wordfence -D <domain>
# Verify the pinned image is built, the scan completes, and tmp/<domain>_scan.csv exists.
################################################################################

function test_wordfencecli_helper() {
  (
    local test_root
    local test_status
    local test_output
    local repo_root

    test_root="$(mktemp -d)" || exit 1
    trap 'rm -rf -- "${test_root}"' EXIT

    repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
    BROLIT_MAIN_DIR="${test_root}/repo"
    BROLIT_RUNTIME_STATE_DIR="${test_root}/state"
    WORDFENCECLI_VERSION="v5.0.6"
    WORDFENCECLI_IMAGE="wordfence-cli:${WORDFENCECLI_VERSION}"
    mkdir -p "${BROLIT_MAIN_DIR}/config/docker/wordfence-cli" "${BROLIT_RUNTIME_STATE_DIR}/tmp"
    touch "${BROLIT_MAIN_DIR}/config/docker/wordfence-cli/Dockerfile"
    mkdir -p "${test_root}/site"
    : > "${test_root}/output-paths"

    local mock_image_exists="false"
    local mock_build_status="0"
    local mock_git_status="0"
    local mock_scan_status="0"
    local mock_scan_result="clean"
    local mock_build_count="0"
    local mock_run_count="0"
    local mock_expected_scan="${test_root}/site"
    local mock_output_paths="${test_root}/output-paths"

    # shellcheck source=../libs/apps/wordfencecli_helper.sh
    source "${repo_root}/libs/apps/wordfencecli_helper.sh"

    log_event() { return 0; }
    display() { return 0; }
    wordfencecli_read_license() { printf '%s\n' 'test-license'; }
    nproc() { printf '%s\n' 4; }

    git() {
      if [[ "${1}" == "clone" ]]; then
        if [[ "${mock_git_status}" -ne 0 ]]; then
          return "${mock_git_status}"
        fi
        mkdir -p "${@: -1}/.git"
        return 0
      fi
      return "${mock_git_status}"
    }

    docker() {
      case "${1:-}" in
      image)
        if [[ "${2:-}" == "inspect" && "${mock_image_exists}" == "true" ]]; then
          return 0
        fi
        return 1
        ;;
      build)
        mock_build_count=$((mock_build_count + 1))
        if [[ "${mock_build_status}" -eq 0 ]]; then
          mock_image_exists="true"
        fi
        return "${mock_build_status}"
        ;;
      run)
        mock_run_count=$((mock_run_count + 1))
        local mock_license_config
        local arg_contains_license="false"
        mock_license_config="$(cat)"
        if [[ "${mock_license_config}" != $'[DEFAULT]\nlicense = test-license' ]]; then
          echo "Wordfence license config was not delivered over stdin" >&2
          return 91
        fi
        local output_path=""
        local argument
        local next_is_output="false"
        local scan_mount_found="false"
        for argument in "$@"; do
          if [[ "${argument}" == "--license" || "${argument}" == *"test-license"* ]]; then
            arg_contains_license="true"
          fi
          if [[ "${argument}" == "type=bind,source=${mock_expected_scan},target=${mock_expected_scan},readonly" ]]; then
            scan_mount_found="true"
          fi
          if [[ "${next_is_output}" == "true" ]]; then
            output_path="${argument}"
            next_is_output="false"
          elif [[ "${argument}" == "--output-path" ]]; then
            next_is_output="true"
          fi
        done
        if [[ "${scan_mount_found}" != "true" ]]; then
          echo "Scan directory was not mounted at its absolute path" >&2
          return 90
        fi
        if [[ "${arg_contains_license}" == "true" ]]; then
          echo "Wordfence license was present in process arguments" >&2
          return 92
        fi
        printf '%s\n' "${output_path}" >> "${mock_output_paths}"
        if [[ "${mock_scan_status}" -ne 0 ]]; then
          return "${mock_scan_status}"
        fi
        local report_name
        report_name="${output_path##*/}"
        if [[ "${mock_scan_result}" == "missing" ]]; then
          return 0
        elif [[ "${mock_scan_result}" == "invalid" ]]; then
          printf 'invalid-header\n' > "${BROLIT_RUNTIME_STATE_DIR}/tmp/${report_name}"
        elif [[ "${mock_scan_result}" == "malformed-quote" ]]; then
          printf 'filename,signature_id,signature_name,signature_description,matched_text\n"unterminated,SIG001,Malware,Description,match\n' > "${BROLIT_RUNTIME_STATE_DIR}/tmp/${report_name}"
        elif [[ "${mock_scan_result}" == "invalid-encoding" ]]; then
          printf 'filename,signature_id,signature_name,signature_description,matched_text\n\377,SIG001,Malware,Description,match\n' > "${BROLIT_RUNTIME_STATE_DIR}/tmp/${report_name}"
        elif [[ "${mock_scan_result}" == "found" ]]; then
          printf 'filename,signature_id,signature_name,signature_description,matched_text\n"/var/www/site/bad.php",SIG001,Malware,"Description, with comma","match\ncontinued"\n' > "${BROLIT_RUNTIME_STATE_DIR}/tmp/${report_name}"
        elif [[ "${mock_scan_result}" == "crlf" ]]; then
          printf 'filename,signature_id,signature_name,signature_description,matched_text\r\n' > "${BROLIT_RUNTIME_STATE_DIR}/tmp/${report_name}"
        else
          printf 'filename,signature_id,signature_name,signature_description,matched_text\n' > "${BROLIT_RUNTIME_STATE_DIR}/tmp/${report_name}"
        fi
        printf 'INFO: mock scan complete\n'
        return 0
        ;;
      esac
      return 1
    }

    # Build failure must propagate and prevent the scan.
    mock_git_status=19
    test_output="$(wordfencecli_malware_scan "${test_root}/site" true 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -ne 0 && ${mock_run_count} -eq 0 ]] || { echo "FAIL: source preparation failure was not propagated" >&2; exit 1; }

    mock_git_status=0
    mock_build_status=17
    test_output="$(wordfencecli_malware_scan "${test_root}/site" true 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -ne 0 && ${mock_run_count} -eq 0 ]] || { echo "FAIL: build failure was not propagated" >&2; exit 1; }

    # A successful build is reused and clean/found results are exact stdout booleans.
    mock_build_status=0
    mock_image_exists=false
    mock_scan_result=clean
    test_output="$(wordfencecli_malware_scan "${test_root}/site" true 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -eq 0 && "${test_output}" == "false" ]] || { echo "FAIL: clean result contract" >&2; exit 1; }

    mock_scan_result=crlf
    test_output="$(wordfencecli_malware_scan "${test_root}/site" true 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -eq 0 && "${test_output}" == "false" ]] || { echo "FAIL: CRLF report was rejected" >&2; exit 1; }

    mock_scan_result=found
    test_output="$(wordfencecli_malware_scan "${test_root}/site" true 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -eq 0 && "${test_output}" == "true" ]] || { echo "FAIL: malware result contract" >&2; exit 1; }

    mock_scan_status=23
    test_output="$(wordfencecli_malware_scan "${test_root}/site" true 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -ne 0 && -z "${test_output}" ]] || { echo "FAIL: container failure reported as a result" >&2; exit 1; }

    mock_scan_status=0
    mock_scan_result=missing
    test_output="$(wordfencecli_malware_scan "${test_root}/site" true 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -ne 0 && -z "${test_output}" ]] || { echo "FAIL: missing report reported as clean" >&2; exit 1; }

    mock_scan_result=invalid
    test_output="$(wordfencecli_malware_scan "${test_root}/site" true 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -ne 0 && -z "${test_output}" ]] || { echo "FAIL: invalid report reported as clean" >&2; exit 1; }

    mock_scan_result=malformed-quote
    test_output="$(wordfencecli_malware_scan "${test_root}/site" true 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -ne 0 && -z "${test_output}" ]] || { echo "FAIL: malformed quoted CSV reported as clean" >&2; exit 1; }

    mock_scan_result=invalid-encoding
    test_output="$(wordfencecli_malware_scan "${test_root}/site" true 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -ne 0 && -z "${test_output}" ]] || { echo "FAIL: invalidly encoded CSV reported as clean" >&2; exit 1; }

    mkdir -p "${test_root}/path-one/site" "${test_root}/path-two/site"
    mock_scan_result=clean
    mock_expected_scan="${test_root}/path-one/site"
    test_output="$(wordfencecli_malware_scan "${mock_expected_scan}" false 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -eq 0 && "${test_output}" == "false" ]] || { echo "FAIL: custom scan path was not mounted" >&2; exit 1; }
    mock_expected_scan="${test_root}/path-two/site"
    test_output="$(wordfencecli_malware_scan "${mock_expected_scan}" false 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -eq 0 && "${test_output}" == "false" ]] || { echo "FAIL: second custom scan path was not mounted" >&2; exit 1; }
    local previous_output_path
    local current_output_path
    previous_output_path="$(tail -n 2 "${mock_output_paths}" | head -n 1)"
    current_output_path="$(tail -n 1 "${mock_output_paths}")"
    [[ -n "${previous_output_path}" && -n "${current_output_path}" && "${previous_output_path}" != "${current_output_path}" ]] || { echo "FAIL: scan report paths were not unique" >&2; exit 1; }

    mkdir -p "${test_root}/projects/example.test/wordpress"
    PROJECTS_PATH="${test_root}/projects"
    SERVER_NAME="test-server"
    log_section() { return 0; }
    log_subsection() { return 0; }
    get_all_directories() { printf '%s\n' "${PROJECTS_PATH}/example.test"; }
    send_notification() { return 0; }
    display() { printf '%s\n' "$*"; }
    # shellcheck source=../libs/task_runner.sh
    source "${repo_root}/libs/task_runner.sh"
    mock_scan_status=23
    test_output="$(security_scan_handler wordfence example.test 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -ne 0 && "${test_output}" == *"ERROR"* && "${test_output}" != *"CLEAN"* ]] || { echo "FAIL: CLI treated Wordfence error as clean" >&2; exit 1; }

    wordfencecli_malware_scan() { printf 'unexpected-result\n'; return 0; }
    test_output="$(security_scan_handler wordfence example.test 2>"${test_root}/stderr")"
    test_status=$?
    [[ ${test_status} -ne 0 && "${test_output}" == *"ERROR"* && "${test_output}" != *"CLEAN"* ]] || { echo "FAIL: CLI treated an invalid Wordfence result as clean" >&2; exit 1; }

    echo "PASS: Wordfence helper build and scan result tests"
  )
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_wordfencecli_helper
fi
