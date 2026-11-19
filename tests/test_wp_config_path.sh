#!/usr/bin/env bash
#
# Author: GauchoCode - A Software Development Agency - https://gauchocode.com
# Version: 3.14
#############################################################################
#
# Regression tests for WordPress detection when a project holds more than one
# wp-config.php (for example the live install plus a copy under backups/).
# The inventory used to call such a project "other": find printed two lines
# and the directory check on that two-line string failed.
#
# Drives the real _wp_config_path and _project_get_type from brolit_lite.sh on
# throwaway directory trees. No network, no real configuration.

if ! declare -F _wp_config_path >/dev/null 2>&1; then
    TEST_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
    # shellcheck disable=SC1090
    source "${TEST_LOADER_DIR}/../brolit_lite.sh" >/dev/null 2>&1
fi

################################################################################
# Test setup
#
# Globals:
#   WP_CONFIG_TEST_DIR - created by setup, removed by teardown
################################################################################

function wp_config_path_setup() {

    WP_CONFIG_TEST_DIR="$(mktemp -d)"

    # Live install plus a stale copy under backups/ (the casanatalia layout)
    mkdir -p "${WP_CONFIG_TEST_DIR}/multi/wordpress" "${WP_CONFIG_TEST_DIR}/multi/backups/code_backup"
    : > "${WP_CONFIG_TEST_DIR}/multi/wordpress/wp-config.php"
    : > "${WP_CONFIG_TEST_DIR}/multi/backups/code_backup/wp-config.php"

    # Single install at the root
    mkdir -p "${WP_CONFIG_TEST_DIR}/single"
    : > "${WP_CONFIG_TEST_DIR}/single/wp-config.php"

    # Two installs at the same depth: the choice must still be deterministic
    mkdir -p "${WP_CONFIG_TEST_DIR}/tie/b" "${WP_CONFIG_TEST_DIR}/tie/a"
    : > "${WP_CONFIG_TEST_DIR}/tie/b/wp-config.php"
    : > "${WP_CONFIG_TEST_DIR}/tie/a/wp-config.php"

    # Path with a space
    mkdir -p "${WP_CONFIG_TEST_DIR}/spaced/my site/wordpress"
    : > "${WP_CONFIG_TEST_DIR}/spaced/my site/wordpress/wp-config.php"

    # No WordPress at all
    mkdir -p "${WP_CONFIG_TEST_DIR}/none"
    : > "${WP_CONFIG_TEST_DIR}/none/index.html"

}

function wp_config_path_teardown() {

    rm -rf -- "${WP_CONFIG_TEST_DIR:?}"

}

function test_wp_config_path_single() {

    local result
    result="$(_wp_config_path "${WP_CONFIG_TEST_DIR}/single")"

    if [[ ${result} != "${WP_CONFIG_TEST_DIR}/single" ]]; then
        echo "FAILED: single install must return its own directory, got '${result}'"
        return 1
    fi

    echo "PASSED: single wp-config.php returns its directory"

}

function test_wp_config_path_prefers_shallowest() {

    local result
    result="$(_wp_config_path "${WP_CONFIG_TEST_DIR}/multi")"

    if [[ ${result} != "${WP_CONFIG_TEST_DIR}/multi/wordpress" ]]; then
        echo "FAILED: with several wp-config.php the shallowest wins, got '${result}'"
        return 1
    fi

    echo "PASSED: several wp-config.php resolve to the shallowest install"

}

function test_wp_config_path_tie_is_deterministic() {

    local result
    result="$(_wp_config_path "${WP_CONFIG_TEST_DIR}/tie")"

    if [[ ${result} != "${WP_CONFIG_TEST_DIR}/tie/a" ]]; then
        echo "FAILED: equal depth must pick the first path alphabetically, got '${result}'"
        return 1
    fi

    echo "PASSED: equal depth resolves alphabetically"

}

function test_wp_config_path_with_spaces() {

    local result
    result="$(_wp_config_path "${WP_CONFIG_TEST_DIR}/spaced")"

    if [[ ${result} != "${WP_CONFIG_TEST_DIR}/spaced/my site/wordpress" ]]; then
        echo "FAILED: a path with spaces must survive, got '${result}'"
        return 1
    fi

    echo "PASSED: paths with spaces are preserved"

}

function test_wp_config_path_none() {

    local result
    result="$(_wp_config_path "${WP_CONFIG_TEST_DIR}/none")"
    local exitstatus=$?

    if [[ ${exitstatus} -eq 0 || -n ${result} ]]; then
        echo "FAILED: no wp-config.php must fail with no output, got '${result}' (${exitstatus})"
        return 1
    fi

    echo "PASSED: no wp-config.php fails cleanly"

}

function test_project_type_with_backup_copy() {

    local result
    result="$(_project_get_type "${WP_CONFIG_TEST_DIR}/multi")"

    if [[ ${result} != "wordpress" ]]; then
        echo "FAILED: a WordPress project with a backup copy must be 'wordpress', got '${result}'"
        return 1
    fi

    echo "PASSED: project with a stale backup copy is still wordpress"

}

# Run all tests when executed directly (the full suite sources libs first).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo ""
    echo "========================================="
    echo "WordPress Config Path Tests"
    echo "========================================="
    echo ""

    wp_config_path_setup

    failures=0
    for test_name in \
        test_wp_config_path_single \
        test_wp_config_path_prefers_shallowest \
        test_wp_config_path_tie_is_deterministic \
        test_wp_config_path_with_spaces \
        test_wp_config_path_none \
        test_project_type_with_backup_copy; do
        "${test_name}" || failures=$((failures + 1))
        echo ""
    done

    wp_config_path_teardown

    echo "========================================="
    echo "All tests completed (${failures} failed)"
    [[ ${failures} -eq 0 ]] || exit 1
fi
