#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.6
#############################################################################

function test_config_migration_check() {

    echo "=== Test: config_migration_check ==="

    local test_config
    test_config="$(mktemp)"

    local template="${BROLIT_MAIN_DIR}/config/brolit/brolit_conf.json"

    # Test 1: Same version - no migration needed
    cp "${template}" "${test_config}"
    config_migration_check "${test_config}"
    if [[ "${MIGRATION_NEEDED}" == "false" ]]; then
        echo "PASSED: Same version detected correctly"
    else
        echo "FAILED: Should not need migration with same version"
    fi

    # Test 2: Different version - migration needed
    jq '.BROLIT_SETUP.config[0].version = "0.0.0"' "${test_config}" > "${test_config}.tmp" && mv "${test_config}.tmp" "${test_config}"
    config_migration_check "${test_config}"
    if [[ "${MIGRATION_NEEDED}" == "true" && "${CURRENT_VERSION}" == "0.0.0" ]]; then
        echo "PASSED: Different version detected correctly"
    else
        echo "FAILED: Should detect version difference"
    fi

    rm -f "${test_config}"

}

function test_config_migration_diff() {

    echo "=== Test: config_migration_diff ==="

    local test_config
    test_config="$(mktemp)"
    local template="${BROLIT_MAIN_DIR}/config/brolit/brolit_conf.json"

    # Create config with different structure
    cp "${template}" "${test_config}"
    jq 'del(.PACKAGES)' "${test_config}" > "${test_config}.tmp" && mv "${test_config}.tmp" "${test_config}"

    config_migration_diff "${test_config}" "${template}"

    local found=0
    for field in "${MIGRATION_FIELDS_ADDED[@]}"; do
        if [[ "${field}" == "PACKAGES" ]]; then
            found=1
            break
        fi
    done

    if [[ ${found} -eq 1 ]]; then
        echo "PASSED: Missing PACKAGES section detected"
    else
        echo "FAILED: Should detect missing PACKAGES section"
    fi

    rm -f "${test_config}"

}

function test_config_migration_merge() {

    echo "=== Test: config_migration_merge ==="

    local test_config
    test_config="$(mktemp)"
    local template="${BROLIT_MAIN_DIR}/config/brolit/brolit_conf.json"

    # Create config with old version and missing sections
    cp "${template}" "${test_config}"
    jq '.BROLIT_SETUP.config[0].version = "0.0.0" | del(.PACKAGES)' "${test_config}" > "${test_config}.tmp" && mv "${test_config}.tmp" "${test_config}"

    config_migration_merge "${test_config}" "${template}"

    local new_version
    new_version="$(jq -r '.BROLIT_SETUP.config[0].version' "${test_config}")"

    local has_packages
    has_packages="$(jq -r '.PACKAGES // empty' "${test_config}")"

    if [[ "${new_version}" != "0.0.0" ]]; then
        echo "PASSED: Version updated correctly"
    else
        echo "FAILED: Version should be updated"
    fi

    if [[ -n "${has_packages}" && "${has_packages}" != "null" ]]; then
        echo "PASSED: PACKAGES section restored"
    else
        echo "FAILED: PACKAGES section should be restored"
    fi

    rm -f "${test_config}"

}

function test_config_migration_apply() {

    echo "=== Test: config_migration_apply ==="

    local test_config
    test_config="$(mktemp)"
    local template="${BROLIT_MAIN_DIR}/config/brolit/brolit_conf.json"

    # Create config with old version
    cp "${template}" "${test_config}"
    jq '.BROLIT_SETUP.config[0].version = "0.0.0"' "${test_config}" > "${test_config}.tmp" && mv "${test_config}.tmp" "${test_config}"

    config_migration_apply "${test_config}"
    exitstatus=$?

    if [[ ${exitstatus} -eq 0 ]]; then
        echo "PASSED: Migration applied successfully"
    else
        echo "FAILED: Migration should succeed"
    fi

    # Check backup was created
    local backup_count
    backup_count=$(ls "${test_config}".bak.* 2>/dev/null | wc -l)

    if [[ ${backup_count} -gt 0 ]]; then
        echo "PASSED: Backup file created"
    else
        echo "FAILED: Backup file should be created"
    fi

    rm -f "${test_config}"
    rm -f "${test_config}".bak.*

}

# Run all tests
echo ""
echo "========================================="
echo "Config Migration Tests"
echo "========================================="

test_config_migration_check
echo ""
test_config_migration_diff
echo ""
test_config_migration_merge
echo ""
test_config_migration_apply
echo ""

echo "========================================="
echo "All tests completed"
