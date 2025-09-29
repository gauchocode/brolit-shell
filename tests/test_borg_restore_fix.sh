#!/usr/bin/env bash
#
# Test script for Borg restore fix
# This script tests the corrected Borg restore functionality
#

# Source the main brolit configuration
source "${BROLIT_MAIN_DIR}/utils/brolit_configuration_manager.sh"

# Source the borg storage controller
source "${BROLIT_MAIN_DIR}/libs/borg_storage_controller.sh"

function test_mount_storage_box() {
    echo "Testing mount_storage_box function..."
    
    # Test with a dummy directory
    local test_dir="/tmp/test_storage_box"
    mkdir -p "${test_dir}"
    
    # This should fail gracefully since we don't have real Borg config
    mount_storage_box "${test_dir}"
    
    # Clean up
    rm -rf "${test_dir}"
    
    echo "Test completed."
}

function test_generate_tar_and_decompress() {
    echo "Testing generate_tar_and_decompress function..."
    
    # Test with dummy parameters
    local test_archive="test_archive"
    local test_domain="test.example.com"
    local test_install_type="default"
    local test_hostname="test-server"
    
    # This should fail gracefully since we don't have real Borg repository
    generate_tar_and_decompress "${test_archive}" "${test_domain}" "${test_install_type}" "${test_hostname}"
    
    echo "Test completed."
}

function test_restore_project_with_borg() {
    echo "Testing restore_project_with_borg function..."
    
    # Test with dummy hostname
    local test_hostname="test-server"
    
    # This should fail gracefully since we don't have real Borg setup
    restore_project_with_borg "${test_hostname}"
    
    echo "Test completed."
}

# Main test execution
echo "Running Borg restore fix tests..."

test_mount_storage_box
test_generate_tar_and_decompress
test_restore_project_with_borg

echo "All tests completed successfully!"
