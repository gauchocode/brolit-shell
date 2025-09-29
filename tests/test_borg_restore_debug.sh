#!/usr/bin/env bash
#
# Test script for Borg restore debug
# This script tests the corrected Borg restore functionality with debug logs
#

# Source the main brolit configuration
if [[ -f "${BROLIT_MAIN_DIR}/utils/brolit_configuration_manager.sh" ]]; then
    source "${BROLIT_MAIN_DIR}/utils/brolit_configuration_manager.sh"
else
    echo "ERROR: brolit_configuration_manager.sh not found"
    exit 1
fi

# Source the borg storage controller
if [[ -f "${BROLIT_MAIN_DIR}/libs/borg_storage_controller.sh" ]]; then
    source "${BROLIT_MAIN_DIR}/libs/borg_storage_controller.sh"
else
    echo "ERROR: borg_storage_controller.sh not found"
    exit 1
fi

function test_restore_backup_with_borg() {
    echo "Testing restore_backup_with_borg function..."
    
    # Enable debug mode
    DEBUG="true"
    
    # Test with a dummy server hostname
    local test_hostname="test-server"
    
    echo "Calling restore_backup_with_borg with hostname: ${test_hostname}"
    
    # This should show the server selection process
    restore_backup_with_borg "${test_hostname}"
    
    local result=$?
    echo "Function returned: ${result}"
    
    echo "Test completed."
}

function test_mount_storage_box() {
    echo "Testing mount_storage_box function..."
    
    # Enable debug mode
    DEBUG="true"
    
    # Test with a dummy directory
    local test_dir="/tmp/test_storage_box_$(date +%s)"
    mkdir -p "${test_dir}"
    
    echo "Calling mount_storage_box with directory: ${test_dir}"
    
    # This should show the server selection and mounting process
    mount_storage_box "${test_dir}"
    
    local result=$?
    echo "Function returned: ${result}"
    
    # Clean up
    if mount | grep -q "${test_dir}"; then
        umount "${test_dir}"
    fi
    rm -rf "${test_dir}"
    
    echo "Test completed."
}

# Main test execution
echo "Running Borg restore debug tests..."
echo "BROLIT_MAIN_DIR: ${BROLIT_MAIN_DIR}"
echo "Current working directory: $(pwd)"

# Show current Borg configuration
echo "=== Current Borg Configuration ==="
echo "BACKUP_BORG_STATUS: ${BACKUP_BORG_STATUS}"
echo "BACKUP_BORG_GROUP: ${BACKUP_BORG_GROUP}"
echo "Number of servers: ${#BACKUP_BORG_USERS[@]}"

for i in "${!BACKUP_BORG_USERS[@]}"; do
    echo "Server ${i}: ${BACKUP_BORG_USERS[$i]}@${BACKUP_BORG_SERVERS[$i]}:${BACKUP_BORG_PORTS[$i]}"
done

echo ""

# Run tests
test_mount_storage_box
test_restore_backup_with_borg

echo "All debug tests completed!"
