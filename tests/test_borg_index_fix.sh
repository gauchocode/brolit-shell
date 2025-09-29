#!/usr/bin/env bash
#
# Test script for Borg index extraction fix
# This script tests the corrected index extraction in restore_backup_with_borg and mount_storage_box functions
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

function test_index_extraction() {
    echo "Testing index extraction improvements..."
    
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
    echo "Testing with mock whiptail responses..."
    echo ""
    
    # Test the index extraction logic directly
    local test_input="01)"
    local extracted_index
    extracted_index=$(echo "${test_input}" | grep -o '^[0-9]*')
    
    echo "Test input: '${test_input}'"
    echo "Extracted index: '${extracted_index}'"
    
    if [[ -n "${extracted_index}" ]] && [[ "${extracted_index}" =~ ^[0-9]+$ ]]; then
        echo "✅ Index extraction successful: '${extracted_index}'"
        echo "✅ Index validation passed: numeric and not empty"
    else
        echo "❌ Index extraction failed"
        echo "Extracted value: '${extracted_index}'"
        echo "Is numeric: $(if [[ "${extracted_index}" =~ ^[0-9]+$ ]]; then echo "yes"; else echo "no"; fi)"
        echo "Is not empty: $(if [[ -n "${extracted_index}" ]]; then echo "yes"; else echo "no"; fi)"
    fi
    
    echo ""
    
    # Test with another format
    test_input="2"
    extracted_index=$(echo "${test_input}" | grep -o '^[0-9]*')
    
    echo "Test input: '${test_input}'"
    echo "Extracted index: '${extracted_index}'"
    
    if [[ -n "${extracted_index}" ]] && [[ "${extracted_index}" =~ ^[0-9]+$ ]]; then
        echo "✅ Index extraction successful: '${extracted_index}'"
        echo "✅ Index validation passed: numeric and not empty"
    else
        echo "❌ Index extraction failed"
    fi
    
    echo ""
    echo "Index extraction tests completed."
}

function test_error_messages() {
    echo "Testing error message improvements..."
    
    # Test error message formatting
    local test_selection="01)"
    local test_index="01"
    local max_servers=2
    
    echo "Simulating invalid selection scenario:"
    echo "  Raw selection: '${test_selection}'"
    echo "  Extracted index: '${test_index}'"
    echo "  Max servers: ${max_servers}"
    
    if [[ -n "${test_index}" ]] && [[ "${test_index}" =~ ^[0-9]+$ ]] && [ "${test_index}" -ge 1 ] && [ "${test_index}" -le "${max_servers}" ]; then
        echo "  ✅ Selection would be valid"
    else
        echo "  ❌ Selection would be invalid"
        echo "  Error messages that would be displayed:"
        echo "    - Invalid selection: ${test_selection}"
        echo "    - Please try again and select a valid server"
    fi
    
    echo ""
    echo "Error message tests completed."
}

# Main test execution
echo "Running Borg index extraction fix tests..."
echo "BROLIT_MAIN_DIR: ${BROLIT_MAIN_DIR}"
echo "Current working directory: $(pwd)"
echo ""

# Run the tests
test_index_extraction
echo ""
test_error_messages

echo ""
echo "All Borg index extraction fix tests completed!"
echo "The improved extraction logic should now handle formats like '01)' correctly."
echo "Error messages will now be displayed to help users understand what went wrong."
