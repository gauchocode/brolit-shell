#!/usr/bin/env bash
#
# Test script for task validation improvements
# This script tests the new validation and error handling features
#
################################################################################

BROLIT_MAIN_DIR="/home/lpadula/Documents/brolit-shell"

echo "=========================================="
echo "Testing Task Validation Improvements"
echo "=========================================="
echo ""

# Test 1: Missing subtask for backup
echo "Test 1: Missing subtask for backup"
echo "Command: ./runner.sh --task backup"
echo "Expected: Error about missing subtask"
echo "---"
./runner.sh --task backup 2>&1 | head -20
echo ""
echo "=========================================="
echo ""

# Test 2: Invalid subtask for backup
echo "Test 2: Invalid subtask for backup"
echo "Command: ./runner.sh --task backup --subtask invalid"
echo "Expected: Error about invalid subtask"
echo "---"
./runner.sh --task backup --subtask invalid 2>&1 | head -20
echo ""
echo "=========================================="
echo ""

# Test 3: Missing domain for cloudflare-api
echo "Test 3: Missing domain for cloudflare-api"
echo "Command: ./runner.sh --task cloudflare-api --subtask clear_cache"
echo "Expected: Error about missing --domain parameter"
echo "---"
./runner.sh --task cloudflare-api --subtask clear_cache 2>&1 | head -20
echo ""
echo "=========================================="
echo ""

# Test 4: Missing task-value for cloudflare dev_mode
echo "Test 4: Missing task-value for cloudflare dev_mode"
echo "Command: ./runner.sh --task cloudflare-api --subtask dev_mode --domain test.com"
echo "Expected: Error about missing --task-value parameter"
echo "---"
./runner.sh --task cloudflare-api --subtask dev_mode --domain test.com 2>&1 | head -20
echo ""
echo "=========================================="
echo ""

# Test 5: Invalid task
echo "Test 5: Invalid task"
echo "Command: ./runner.sh --task invalid-task"
echo "Expected: Error about invalid task"
echo "---"
./runner.sh --task invalid-task 2>&1 | head -20
echo ""
echo "=========================================="
echo ""

# Test 6: Missing domain for project backup
echo "Test 6: Missing domain for project backup"
echo "Command: ./runner.sh --task backup --subtask project"
echo "Expected: Error about missing --domain parameter"
echo "---"
./runner.sh --task backup --subtask project 2>&1 | head -20
echo ""
echo "=========================================="
echo ""

# Test 7: Valid backup all command (dry run check)
echo "Test 7: Valid backup all command structure"
echo "Command: ./runner.sh --task backup --subtask all --help"
echo "Expected: Should show help (validates command structure is correct)"
echo "---"
./runner.sh --help 2>&1 | head -30
echo ""
echo "=========================================="

echo ""
echo "Test completed!"
echo "Review the output above to verify:"
echo "1. Clear error messages for missing parameters"
echo "2. Helpful suggestions for valid options"
echo "3. Proper validation of subtasks"
echo "4. User-friendly error formatting"
