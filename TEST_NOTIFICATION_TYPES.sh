#!/usr/bin/env bash
#
# Test script for notification_type support in email notifications
# This demonstrates the new functionality added in Phase 3
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "  Email Notification Type Test Suite"
echo "========================================="
echo ""

# Check if mail_template_engine exists
if [[ ! -f "libs/local/mail_template_engine.sh" ]]; then
    echo -e "${RED}✗ ERROR: mail_template_engine.sh not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ mail_template_engine.sh found${NC}"

# Check if templates exist
TEMPLATE_DIR="templates/emails/default"
TEMPLATES=("notification-alert" "notification-warning" "notification-info" "notification-success")
MISSING=0

echo ""
echo "Checking notification templates..."
for template in "${TEMPLATES[@]}"; do
    if [[ -f "${TEMPLATE_DIR}/${template}-tpl.html" ]]; then
        echo -e "${GREEN}  ✓ ${template}-tpl.html${NC}"
    else
        echo -e "${RED}  ✗ ${template}-tpl.html MISSING${NC}"
        MISSING=$((MISSING + 1))
    fi
done

if [[ $MISSING -gt 0 ]]; then
    echo -e "\n${RED}✗ Missing $MISSING templates${NC}"
    exit 1
fi

echo -e "\n${GREEN}✓ All 4 notification templates found${NC}"

# Check modified files
echo ""
echo "Checking modified files..."

# Check mail_send_notification accepts 3 parameters
if grep -q 'local notification_type="${3:-info}"' "libs/local/mail_notification_helper.sh"; then
    echo -e "${GREEN}  ✓ mail_send_notification() accepts notification_type parameter${NC}"
else
    echo -e "${RED}  ✗ mail_send_notification() missing notification_type parameter${NC}"
    exit 1
fi

# Check notification_controller passes notification_type
if grep -q 'mail_send_notification "${notification_title}" "${notification_content}" "${notification_type}"' "libs/notification_controller.sh"; then
    echo -e "${GREEN}  ✓ notification_controller.sh passes notification_type to email${NC}"
else
    echo -e "${RED}  ✗ notification_controller.sh not passing notification_type${NC}"
    exit 1
fi

# Summary
echo ""
echo "========================================="
echo -e "${GREEN}✓ All Phase 3 changes verified!${NC}"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Test with actual email sending (requires SMTP config)"
echo "  2. Verify visual appearance of different notification types"
echo "  3. Check logs for proper template wrapping"
echo ""
echo "Example usage:"
echo "  send_notification 'Test Alert' 'This is a test' 'alert'"
echo "  send_notification 'Test Warning' 'This is a test' 'warning'"
echo "  send_notification 'Test Info' 'This is a test' 'info'"
echo "  send_notification 'Test Success' 'This is a test' 'success'"
echo ""
