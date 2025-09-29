#!/usr/bin/env bash
#
# Test script for Borg server connectivity check
# This script tests the new check_borg_server_connectivity function
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

function test_connectivity_check() {
    echo "Testing Borg server connectivity check..."
    
    # Enable debug mode
    DEBUG="true"
    
    echo "=== Current Borg Configuration ==="
    echo "BACKUP_BORG_STATUS: ${BACKUP_BORG_STATUS}"
    echo "BACKUP_BORG_GROUP: ${BACKUP_BORG_GROUP}"
    echo "Number of servers: ${#BACKUP_BORG_USERS[@]}"
    
    for i in "${!BACKUP_BORG_USERS[@]}"; do
        echo "Server ${i}: ${BACKUP_BORG_USERS[$i]}@${BACKUP_BORG_SERVERS[$i]}:${BACKUP_BORG_PORTS[$i]}"
    done
    
    echo ""
    echo "Running connectivity check..."
    echo ""
    
    # Run the connectivity check
    check_borg_server_connectivity
    
    local result=$?
    echo ""
    echo "Connectivity check returned: ${result}"
    
    if [ ${result} -eq 0 ]; then
        echo "✅ All servers are reachable"
    else
        echo "⚠️  Some servers have connectivity issues"
    fi
    
    echo "Test completed."
}

# Main test execution
echo "Running Borg connectivity check test..."
echo "BROLIT_MAIN_DIR: ${BROLIT_MAIN_DIR}"
echo "Current working directory: $(pwd)"
echo ""

# Run the test
test_connectivity_check

echo ""
echo "Connectivity check test completed!"
echo "Check the logs and notifications for detailed results."
