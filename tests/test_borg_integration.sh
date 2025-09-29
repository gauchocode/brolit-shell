#!/usr/bin/env bash
#
# Test script for Borg integration with connectivity check
# This script tests the integrated connectivity check in mount and restore functions
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

function test_mount_storage_box_integration() {
    echo "Testing mount_storage_box integration with connectivity check..."
    
    # Enable debug mode
    DEBUG="true"
    
    # Test with a dummy directory
    local test_dir="/tmp/test_storage_box_integration_$(date +%s)"
    mkdir -p "${test_dir}"
    
    echo "Calling mount_storage_box with directory: ${test_dir}"
    echo "Note: This will show the server selection menu if multiple servers are configured"
    
    # This should show the server selection and connectivity check
    mount_storage_box "${test_dir}"
    
    local result=$?
    echo "mount_storage_box returned: ${result}"
    
    # Clean up
    if mount | grep -q "${test_dir}"; then
        umount "${test_dir}"
    fi
    rm -rf "${test_dir}"
    
    echo "mount_storage_box integration test completed."
}

function test_restore_integration() {
    echo "Testing restore_backup_with_borg integration with connectivity check..."
    
    # Enable debug mode
    DEBUG="true"
    
    # Test with a dummy server hostname
    local test_hostname="test-server"
    
    echo "Calling restore_backup_with_borg with hostname: ${test_hostname}"
    echo "Note: This will show the server selection menu and connectivity check"
    
    # This should show the server selection and connectivity check
    restore_backup_with_borg "${test_hostname}"
    
    local result=$?
    echo "restore_backup_with_borg returned: ${result}"
    
    echo "restore_backup_with_borg integration test completed."
}

# Main test execution
echo "Running Borg integration tests..."
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

# Run integration tests
test_mount_storage_box_integration
echo ""
test_restore_integration

echo ""
echo "All Borg integration tests completed!"
echo "Check the logs for detailed connectivity check results."
