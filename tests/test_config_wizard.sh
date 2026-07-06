#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.6
#############################################################################

function test_config_wizard_presets() {

    echo "=== Test: config_wizard_apply_preset ==="

    local test_config
    test_config="$(mktemp)"
    local template="${BROLIT_MAIN_DIR}/config/brolit/brolit_conf.json"

    # Mock whiptail_input to return values without prompting
    whiptail_input() {
        local title="${1}"
        local message="${2}"
        local default="${3}"

        # Return default values based on title
        case "${title}" in
            "Server Config") echo "America/Argentina/Buenos_Aires" ;;
            "Email Config") echo "test@example.com" ;;
            *) echo "${default}" ;;
        esac
        return 0
    }

    # Test WordPress preset
    cp "${template}" "${test_config}"
    config_wizard_apply_preset "wordpress" "${test_config}"

    local nginx_status
    nginx_status="$(jq -r '.PACKAGES.nginx[].status' "${test_config}")"
    local php_status
    php_status="$(jq -r '.PACKAGES.php[].status' "${test_config}")"
    local mariadb_status
    mariadb_status="$(jq -r '.PACKAGES.mariadb[].status' "${test_config}")"

    if [[ "${nginx_status}" == "enabled" && "${php_status}" == "enabled" && "${mariadb_status}" == "enabled" ]]; then
        echo "PASSED: WordPress preset applied correctly"
    else
        echo "FAILED: WordPress preset should enable nginx, php, mariadb"
    fi

    # Test Docker preset
    cp "${template}" "${test_config}"
    config_wizard_apply_preset "docker" "${test_config}"

    local docker_status
    docker_status="$(jq -r '.PACKAGES.docker[].status' "${test_config}")"
    local portainer_status
    portainer_status="$(jq -r '.PACKAGES.portainer[].status' "${test_config}")"

    if [[ "${docker_status}" == "enabled" && "${portainer_status}" == "enabled" ]]; then
        echo "PASSED: Docker preset applied correctly"
    else
        echo "FAILED: Docker preset should enable docker, portainer"
    fi

    # Test Minimal preset
    cp "${template}" "${test_config}"
    config_wizard_apply_preset "minimal" "${test_config}"

    local webserver
    webserver="$(jq -r '.SERVER_CONFIG.config[].webserver' "${test_config}")"

    if [[ "${webserver}" == "disabled" ]]; then
        echo "PASSED: Minimal preset applied correctly"
    else
        echo "FAILED: Minimal preset should disable webserver"
    fi

    # Test Monitoring preset
    cp "${template}" "${test_config}"
    config_wizard_apply_preset "monitoring" "${test_config}"

    local netdata_status
    netdata_status="$(jq -r '.PACKAGES.netdata[].status' "${test_config}")"

    if [[ "${netdata_status}" == "enabled" ]]; then
        echo "PASSED: Monitoring preset applied correctly"
    else
        echo "FAILED: Monitoring preset should enable netdata"
    fi

    rm -f "${test_config}"

    # Restore original whiptail_input
    unset -f whiptail_input

}

function test_config_wizard_json_valid() {

    echo "=== Test: config_wizard generates valid JSON ==="

    local test_config
    test_config="$(mktemp)"
    local template="${BROLIT_MAIN_DIR}/config/brolit/brolit_conf.json"

    # Mock whiptail_input
    whiptail_input() {
        echo "${3}"
        return 0
    }

    local presets=("wordpress" "docker" "minimal" "monitoring")

    for preset in "${presets[@]}"; do

        cp "${template}" "${test_config}"
        config_wizard_apply_preset "${preset}" "${test_config}"

        if jq . "${test_config}" > /dev/null 2>&1; then
            echo "PASSED: ${preset} preset generates valid JSON"
        else
            echo "FAILED: ${preset} preset generates invalid JSON"
        fi

    done

    rm -f "${test_config}"
    unset -f whiptail_input

}

# Run all tests
echo ""
echo "========================================="
echo "Config Wizard Tests"
echo "========================================="

test_config_wizard_presets
echo ""
test_config_wizard_json_valid
echo ""

echo "========================================="
echo "All tests completed"
