#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
################################################################################
#
# Ref: https://github.com/wordfence/wordfence-cli
#

readonly WORDFENCECLI_VERSION="${WORDFENCECLI_VERSION:-v5.0.6}"
readonly WORDFENCECLI_IMAGE="wordfence-cli:${WORDFENCECLI_VERSION}"

################################################################################
# Write Worfence-cli license file
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function wordfencecli_write_license() {

    local wordfencecli_license_key="${1}"

    declare -g WORDFENCECLI_LICENSE

    local wordfencecli_license_file

    wordfencecli_license_file="/root/.config/wordfence/wordfence-cli.ini"

    if [[ ${wordfencecli_license_key} != "" ]]; then

        # Create directory if not exists
        mkdir -p /root/.config
        mkdir -p /root/.config/wordfence

        # Restrict the license file and avoid expanding it into another command's arguments.
        if ! (umask 077; printf '%s\n' "${wordfencecli_license_key}" > "${wordfencecli_license_file}"); then
            log_event "error" "Unable to write Wordfence CLI license file" "true"
            return 1
        fi
        chmod 600 "${wordfencecli_license_file}" || return 1

        return 0

    else

        log_event "error" "Something went wrong writing Wordfence-cli license" "false"

        return 1

    fi

}

################################################################################
# Read remote name from configuration file
#
# Arguments:
#   none
#
# Outputs:
#   nothing
################################################################################

function wordfencecli_read_license() {

    declare -g WORDFENCECLI_LICENSE

    local wordfencecli_license_file

    wordfencecli_license_file="/root/.config/wordfence/wordfence-cli.ini"

    WORDFENCECLI_LICENSE="$(cat "${wordfencecli_license_file}")"

    if [[ ${WORDFENCECLI_LICENSE} != "" ]]; then

        export WORDFENCECLI_LICENSE
        
        # Return
        echo "${WORDFENCECLI_LICENSE}" && return 0

    else

        log_event "error" "Something went wrong reading Wordfence-cli license" "false"

        return 1

    fi

}

################################################################################
# Build Wordfence CLI Docker image
#
# Arguments:
#   none
#
# Outputs:
#   0 if the image builds and is available, non-zero otherwise.
################################################################################

function build_wordfencecli_docker_image() {

    local target_directory="${BROLIT_RUNTIME_STATE_DIR:-${BROLIT_MAIN_DIR}}/tmp/wordfence-cli"
    local dockerfile="${BROLIT_MAIN_DIR}/config/docker/wordfence-cli/Dockerfile"

    if [[ ! -d "${target_directory}/.git" ]]; then
        if [[ -e "${target_directory}" ]]; then
            log_event "error" "Wordfence CLI source path exists but is not a Git checkout: ${target_directory}" "true"
            return 1
        fi
        mkdir -p "$(dirname "${target_directory}")" || return 1
        if ! git clone --depth 1 --branch "${WORDFENCECLI_VERSION}" https://github.com/wordfence/wordfence-cli.git "${target_directory}" >&2; then
            log_event "error" "Unable to clone Wordfence CLI ${WORDFENCECLI_VERSION}" "true"
            return 1
        fi
    else
        if ! git -C "${target_directory}" fetch --depth 1 origin "refs/tags/${WORDFENCECLI_VERSION}:refs/tags/${WORDFENCECLI_VERSION}" >&2; then
            log_event "error" "Unable to fetch Wordfence CLI ${WORDFENCECLI_VERSION}" "true"
            return 1
        fi
        if ! git -C "${target_directory}" checkout --detach "${WORDFENCECLI_VERSION}" >&2; then
            log_event "error" "Unable to check out Wordfence CLI ${WORDFENCECLI_VERSION}" "true"
            return 1
        fi
    fi

    if [[ ! -f "${dockerfile}" ]]; then
        log_event "error" "Wordfence CLI Dockerfile not found: ${dockerfile}" "true"
        return 1
    fi

    log_event "info" "Building Wordfence CLI image ${WORDFENCECLI_IMAGE}" "true"
    if ! docker build --file "${dockerfile}" --tag "${WORDFENCECLI_IMAGE}" --tag wordfence-cli:latest "${target_directory}" >&2; then
        log_event "error" "Docker build failed for ${WORDFENCECLI_IMAGE}" "true"
        return 1
    fi

    if ! docker image inspect "${WORDFENCECLI_IMAGE}" > /dev/null 2>&1; then
        log_event "error" "Wordfence CLI image was not created: ${WORDFENCECLI_IMAGE}" "true"
        return 1
    fi

    return 0

}


################################################################################
# Run Wordfence in Docker with its license delivered over stdin.
#
# Arguments:
#   ${1} = ${image}
#   ${2} = ${license}
#   Remaining arguments before `--` = docker run options
#   Remaining arguments after `--` = Wordfence CLI arguments
#
# Outputs:
#   Wordfence CLI output; returns its exit status.
################################################################################

function wordfencecli_docker_run_with_license() {

    local image="${1}"
    local license="${2}"
    shift 2

    local docker_options=()
    local wordfence_arguments=()

    while [[ ${#} -gt 0 && "${1}" != "--" ]]; do
        docker_options+=("${1}")
        shift
    done

    if [[ "${1:-}" != "--" ]]; then
        log_event "error" "Wordfence Docker command separator is missing" "true"
        return 2
    fi
    shift
    wordfence_arguments=("$@")

    # Deliver the key as INI over stdin, not in docker/Wordfence argv or env.
    printf '[DEFAULT]\nlicense = %s\n' "${license}" | docker run --rm --interactive \
        "${docker_options[@]}" --entrypoint /bin/sh "${image}" -c '
            umask 077
            config_file="$(mktemp /tmp/wordfence-cli.XXXXXX)" || exit 1
            if ! cat > "${config_file}"; then
                rm -f -- "${config_file}"
                exit 1
            fi
            wordfence --configuration "${config_file}" "$@"
            exit_code=$?
            rm -f -- "${config_file}"
            exit "${exit_code}"
        ' wordfence-cli "${wordfence_arguments[@]}"

}


################################################################################
# Malware scan directory with wordfence-cli
#
# Arguments:
#   ${1} = ${directory_to_scan}
#   ${2} = ${include_all_files} - true or false
#
# Outputs:
#   `true` if malware is found, `false` if clean; non-zero on execution errors.
################################################################################

function wordfencecli_malware_scan() {

    local directory_to_scan="${1}"
    local include_all_files="${2}"

    local license
    local scan_option=()
    local image="${WORDFENCECLI_IMAGE}"
    local scan_directory
    local runtime_tmp="${BROLIT_RUNTIME_STATE_DIR:-${BROLIT_MAIN_DIR}}/tmp"

    if [[ ! -d "${directory_to_scan}" ]]; then
        log_event "error" "Wordfence scan directory does not exist: ${directory_to_scan}" "true"
        return 2
    fi
    scan_directory="$(cd -- "${directory_to_scan}" && pwd -P)" || return 2

    # Build the Wordfence CLI Docker image
    if ! docker image inspect "${image}" > /dev/null 2>&1; then
        build_wordfencecli_docker_image || return 2
    fi

    if ! docker image inspect "${image}" > /dev/null 2>&1; then
        log_event "error" "Wordfence CLI image is unavailable: ${image}" "true"
        return 2
    fi

    # Read license 
    license="$(wordfencecli_read_license)" || {
        display --indent 6 --text "- No license found for wordfence-cli" --result "ERROR" --color RED >&2
        display --indent 8 --text "- Please get a new one from here: https://www.wordfence.com/products/wordfence-cli/" --tcolor RED >&2
        return 1
    }

    if [[ -n "${license}" ]]; then

        # If include_all_files is true, set scan_option
        [[ ${include_all_files} == "true" ]] && scan_option=(--include-all-files)

        # Log
        log_event "info" "Starting malware scan on: ${scan_directory}" "false"
        log_event "debug" "Running Wordfence malware scan in ${image} on ${scan_directory}; license sent via stdin" "false"
        display --indent 6 --text "- Starting malware scan on: ${scan_directory}" >&2

        # Use a unique in-progress report to avoid overlapping scans sharing a file.
        local output_file
        local scan_report_file
        output_file="${runtime_tmp}/${scan_directory##*/}_scan.csv"
        scan_report_file="$(mktemp --tmpdir="${runtime_tmp}" ".${scan_directory##*/}_scan.XXXXXX.csv")" || {
            log_event "error" "Unable to create temporary Wordfence report in ${runtime_tmp}" "true"
            return 2
        }

        # Calculate workers
        local workers
        workers=$(( $(nproc) / 2 ))
        [[ ${workers} -lt 1 ]] && workers=1

        # Malware Scan command - capture output
        local scan_output
        local scan_exit=0
        scan_output=$(wordfencecli_docker_run_with_license "${image}" "${license}" \
            --mount "type=bind,source=${scan_directory},target=${scan_directory},readonly" \
            --mount "type=bind,source=${runtime_tmp},target=/output" \
            -- malware-scan "${scan_option[@]}" --workers "${workers}" \
            --accept-terms "${scan_directory}" \
            --output-path "/output/${scan_report_file##*/}" 2>&1) || scan_exit=$?
        if [[ ${scan_exit} -ne 0 ]]; then
            log_event "error" "Wordfence scan failed with exit code ${scan_exit}" "false"
            rm --force -- "${scan_report_file}"
            return 2
        fi

        # Display formatted output
        while IFS= read -r line; do
            if [[ "${line}" =~ ^WARNING: ]]; then
                display --indent 6 --text "  ${line}" --tcolor YELLOW >&2
            elif [[ "${line}" =~ ^INFO: ]]; then
                display --indent 6 --text "  ${line}" --tcolor BLUE >&2
            elif [[ "${line}" =~ error ]]; then
                display --indent 6 --text "  ${line}" --tcolor RED >&2
            else
                echo "      ${line}" >&2
            fi
        done <<< "${scan_output}"

        # Parse and display suspicious files
        if [[ -s "${scan_report_file}" ]]; then
            local suspicious_count
            suspicious_count="$(python3 - "${scan_report_file}" <<'PY'
import csv
import sys

report_path = sys.argv[1]
expected_header = [
    'filename', 'signature_id', 'signature_name',
    'signature_description', 'matched_text'
]

try:
    with open(report_path, 'r', newline='', encoding='utf-8') as report_file:
        reader = csv.DictReader(report_file, strict=True)
        if reader.fieldnames != expected_header:
            raise ValueError('unexpected CSV header')

        findings = 0
        for row in reader:
            if None in row or any(value is None for value in row.values()):
                raise ValueError('malformed CSV row')
            findings += 1
            print(f"File: {row['filename']}", file=sys.stderr)
            print(
                f"Signature: {row['signature_name']} ({row['signature_id']})",
                file=sys.stderr
            )
except (OSError, csv.Error, ValueError) as error:
    print(f'Unable to parse Wordfence CSV report: {error}', file=sys.stderr)
    sys.exit(1)

print(findings)
PY
            )" || {
                log_event "error" "Unable to parse Wordfence CSV report: ${scan_report_file}" "true"
                rm --force -- "${scan_report_file}"
                return 2
            }

            if ! mv --force -- "${scan_report_file}" "${output_file}"; then
                log_event "error" "Unable to publish Wordfence CSV report: ${output_file}" "true"
                rm --force -- "${scan_report_file}"
                return 2
            fi

            if [[ ${suspicious_count} -gt 0 ]]; then
                display --indent 6 --text "- Found ${suspicious_count} suspicious file(s)" --result "WARNING" --color YELLOW >&2
                display --indent 8 --text "Suspicious Files:" --tcolor YELLOW >&2

                display --indent 8 --text "Full report saved to: ${output_file}" --tcolor BLUE >&2
                printf 'true\n'
            else
                display --indent 6 --text "- No suspicious files found" --result "DONE" --color GREEN >&2
                printf 'false\n'
            fi
        else
            log_event "error" "Wordfence scan did not produce a CSV report: ${scan_report_file}" "true"
            rm --force -- "${scan_report_file}"
            return 2
        fi

    else

        # Log
        log_event "error" "Not license found for wordfence-cli" "false"
        display --indent 6 --text "- No license found for wordfence-cli" --result "ERROR" --color RED >&2
        display --indent 8 --text "- Please get a new one from here: https://www.wordfence.com/products/wordfence-cli/" --tcolor RED >&2

        return 1

    fi

}

################################################################################
# Vulnerabilities scan directory with wordfence-cli
#
# Arguments:
#   ${1} = ${directory_to_scan}
#   ${2} = ${include_all_files} - true or false
#
# Outputs:
#   Vulnerability scan output; non-zero on execution errors.
################################################################################

function wordfencecli_vulnerabilities_scan() {

    local directory_to_scan="${1}"
    local include_all_files="${2}"

    local scan_option=()
    local license
    local scan_directory

    if [[ ! -d "${directory_to_scan}" ]]; then
        log_event "error" "Wordfence scan directory does not exist: ${directory_to_scan}" "true"
        return 2
    fi
    scan_directory="$(cd -- "${directory_to_scan}" && pwd -P)" || return 2

    # Build the Wordfence CLI Docker image
    build_wordfencecli_docker_image || return 2

    # Read license 
    license="$(wordfencecli_read_license)" || return 1

    if [[ -n "${license}" ]]; then
    
        # If include_all_files is true, set scan_option
        [[ ${include_all_files} == "true" ]] && scan_option=(--include-all-files)

        # Log
        log_event "info" "Starting wordfence-cli vulnerabilities scan on: ${scan_directory}" "false"
        log_event "debug" "Running Wordfence vulnerability scan in ${WORDFENCECLI_IMAGE} on ${scan_directory}; license sent via stdin" "false"
        display --indent 6 --text "- Starting wordfence-cli vulnerabilities scan on: ${scan_directory}"

        # Vulnerabilities Scan command
        wordfencecli_docker_run_with_license "${WORDFENCECLI_IMAGE}" "${license}" \
            --mount "type=bind,source=${scan_directory},target=${scan_directory},readonly" \
            -- vuln-scan "${scan_option[@]}" --accept-terms "${scan_directory}"

    else

        # Log
        log_event "error" "Not license found for wordfence-cli" "false"
        display --indent 6 --text "- Not license found for wordfence-cli" --result "ERROR" --color RED
        display --indent 8 --text "- Please get a new one from here: https://www.wordfence.com/products/wordfence-cli/" --tcolor RED

        return 1

    fi

}
