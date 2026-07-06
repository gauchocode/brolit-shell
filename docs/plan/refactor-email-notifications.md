# Refactor Plan: Email Notification System

## 📋 Executive Summary

### Context
The brolit-shell notification system uses a **multi-channel controller pattern** that allows sending notifications via Email, Telegram, Discord, and ntfy. The refactor specifically focuses on improving the Email channel, which currently has several inconsistencies and maintainability issues.

### Main Issues

1. **❌ `notification_type` parameter ignored**: Email does not respect the notification type (alert/warning/info/success) unlike other channels
2. **❌ Typo in configuration**: Field `maila` instead of `email_to`
3. **❌ Massive code duplication**: 240 lines of sed repeated across 4 functions
4. **❌ Performance**: 14 I/O operations when it could be 1
5. **❌ No error handling**: Silent failures in template construction
6. **❌ Inconsistent cleanup**: Orphaned temporary files if sending fails

### Proposed Solution

**5 phases** of refactoring that achieve:

- ✅ **Parity with other channels**: Email will respect `notification_type` just like Telegram/Discord/ntfy
- ✅ **-80% duplicated code**: Unified template engine
- ✅ **-93% I/O operations**: From 14 operations → 1
- ✅ **+700% error coverage**: All functions with robust handling
- ✅ **Configurable templates**: Support for multiple template sets
- ✅ **Backward compatibility**: Migration without breaking changes

### Schedule

**Total**: 6-10 business days distributed across 5 phases

### Diagram: Before vs After

#### BEFORE: The notification_type problem

```text
send_notification(title, content, "alert")
    ├─> telegram_send_notification(title, content, "alert") → 🔴 Red alert message
    ├─> discord_send_notification(title, content, "alert")  → 🔴 Red alert embed
    ├─> mail_send_notification(title, content)              → 📧 Generic email (ignores type)
    └─> ntfy_send_notification(title, content, "alert")    → 🔴 Red alert notification
```

#### AFTER: Parity across channels

```text
send_notification(title, content, "alert")
    ├─> telegram_send_notification(title, content, "alert") → 🔴 Red alert message
    ├─> discord_send_notification(title, content, "alert")  → 🔴 Red alert embed
    ├─> mail_send_notification(title, content, "alert")    → 🔴 Red alert email
    └─> ntfy_send_notification(title, content, "alert")    → 🔴 Red alert notification
```

---

## Current System Analysis

### Current Architecture

#### Multi-Channel Pattern (Controller)
The system uses a **centralized controller pattern** for multi-channel notifications:

```
send_notification(title, content, type)
    ├─> telegram_send_notification() [if TELEGRAM enabled]
    ├─> discord_send_notification()  [if DISCORD enabled]
    ├─> mail_send_notification()     [if EMAIL enabled]
    └─> ntfy_send_notification()     [if NTFY enabled]
```

**Files involved**:
- **Controller**: [libs/notification_controller.sh](libs/notification_controller.sh) (56 lines)
  - `send_notification(title, content, type)` - Main dispatcher
  - **Note**: `notification_type` (parameter #3) is ignored in `mail_send_notification()`
- **Email Core**: [libs/local/mail_notification_helper.sh](libs/local/mail_notification_helper.sh) (532 lines, 8 functions)
- **Config**: [utils/brolit_configuration_manager.sh](utils/brolit_configuration_manager.sh) (lines 414-464)
- **Templates**: `/templates/emails/default/` (8 HTML files)

### Tool Used
- **sendEmail** (Perl script) for SMTP sending
- Supports TLS/SSL, SMTP authentication, HTML content

### Notification Types
1. **Backup Reports** (main use)
2. **Server Status** (uptime, disk usage)
3. **Package Status** (available updates)
4. **SSL Certificate Status** (expiration)
5. **Alerts and Errors** (malware, checksums, borg errors)
6. **Composite Reports** (combination of all sections)

---

## Identified Issues

### 🔴 High Priority (Critical)

#### 1. Typo in configuration
**Location**: `utils/brolit_configuration_manager.sh:434`
```bash
NOTIFICATION_EMAIL_EMAIL_TO="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].maila")"
```
**Problem**: Field named `maila` (typo, should be `email` or `email_to`)
**Impact**: Inconsistency in naming, confusion for users

#### 2. No error handling in section constructors
**Location**: All `mail_*_section()` functions
**Problem**: They do not validate whether templates exist, they do not return error codes
**Impact**: Silent failures, difficult debugging

#### 3. Inconsistent temporary file cleanup
**Location**: `mail_notification_helper.sh:148`
```bash
_remove_mail_notifications_files() {
    rm --force "${BROLIT_TMP_DIR}"/*.mail
}
```
**Problem**: Only called if sending succeeds, files are orphaned if it fails
**Impact**: Accumulation of temporary files, potential information leak

### 🟡 Medium Priority (Performance)

#### 4. Inefficient HTML assembly
**Location**: `cron/backups_tasks.sh:419-432`
```bash
grep -v "{{server_info}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"
# Repeated 7 times for each placeholder
```
**Problem**: 7 separate grep/sed/mv operations
**Impact**: Excessive I/O, slow email generation
**Proposed solution**: Use `sed` with multiple expressions or `envsubst`

#### 5. Duplicated template variable replacement
**Location**: Each `mail_*_section()` function uses 7+ `sed` operations
**Problem**: Pattern repeated 4 times (240+ lines of duplicated code)
**Impact**: Low maintainability, duplicated bugs
**Proposed solution**: Unified template engine

### 🟢 Low Priority (Code Quality)

#### 6. Hardcoded templates
```bash
local email_template="default"
html_server_info_details="$(cat "${BROLIT_MAIN_DIR}/templates/emails/${email_template}/server_info-tpl.html")"
```
**Problem**: Template name hardcoded in 12+ locations
**Impact**: Not configurable, no fallbacks

#### 7. `notification_type` parameter ignored in emails
**Location**: `notification_controller.sh:45`
```bash
# send_notification() receives 3 parameters
send_notification "${title}" "${content}" "${type}"
    ├─> telegram_send_notification($1, $2, $3)  # ✓ Uses notification_type
    ├─> discord_send_notification($1, $2, $3)   # ✓ Uses notification_type
    ├─> mail_send_notification($1, $2)          # ✗ Does NOT use notification_type
    └─> ntfy_send_notification($1, $2, $3)      # ✓ Uses notification_type
```
**Problem**:
- Telegram, Discord, and ntfy can render different alerts based on type (alert/warning/info/success)
- Email always receives the same format, ignoring the notification type
- Inconsistency across notification channels

**Impact**:
- Generic emails without visual context of urgency level
- User cannot differentiate alert vs info in emails
- Inconsistent UX across channels

#### 8. Inconsistent notification patterns
- **Backup reports**: Complex structured HTML
- **Simple alerts** (via `send_notification()`): Plain text without formatting
- **Restore operations**: Both formats (duplication)
**Impact**: Inconsistent UX, duplicated code

---

## Refactoring Plan

### Phase 1: Critical Fixes (1-2 days)

#### 1.1 Fix configuration typo
- [ ] Rename `maila` → `email_to` in JSON schema
- [ ] Update `_brolit_configuration_load_email()` in `utils/brolit_configuration_manager.sh:434`
- [ ] Update configuration documentation
- [ ] Maintain backward compatibility (read both fields)

#### 1.2 Implement robust error handling
- [ ] Add template existence validation in all `mail_*_section()` functions
- [ ] Return error codes from construction functions
- [ ] Add error logging with context
- [ ] Implement fallback to generic templates if a specific one is missing

#### 1.3 Improve temporary file management
- [ ] Create `_create_temp_mail_file()` function that registers created files
- [ ] Use global array for tracking: `MAIL_TEMP_FILES=()`
- [ ] Implement trap for cleanup on EXIT/ERR/INT
- [ ] Add unique timestamp to filenames

**Affected files**:
- `libs/local/mail_notification_helper.sh`
- `utils/brolit_configuration_manager.sh`
- `config/brolit/brolit_conf.json`

---

### Phase 2: Unified Template Engine (2-3 days)

#### 2.1 Create centralized template engine

**New file**: `libs/local/mail_template_engine.sh`

```bash
#!/usr/bin/env bash
#
# Template Engine for Email Notifications
#

################################################################################
# Load and process email template with variable substitution
#
# Arguments:
#   $1 - Template name (e.g., "server_info")
#   $2+ - Key=value pairs for substitution
#
# Returns:
#   0 on success, 1+ on error
#
# Outputs:
#   Processed HTML to stdout
################################################################################
mail_template_render() {
    local template_name="${1}"
    shift

    local template_set="${EMAIL_TEMPLATE_SET:-default}"
    local template_path="${BROLIT_MAIN_DIR}/templates/emails/${template_set}/${template_name}-tpl.html"

    # Validate template exists
    if [[ ! -f "${template_path}" ]]; then
        log_event "error" "Template not found: ${template_path}" "false"
        return 1
    fi

    # Load template
    local template_content
    template_content="$(cat "${template_path}")"

    # Replace variables (method 1: sed)
    local result="${template_content}"
    local key value
    for pair in "$@"; do
        key="${pair%%=*}"
        value="${pair#*=}"
        result="$(echo "${result}" | sed "s|{{${key}}}|${value}|g")"
    done

    echo "${result}"
}

################################################################################
# Render template with environment variables (using envsubst)
#
# Arguments:
#   $1 - Template name
#
# Environment:
#   All variables to substitute must be exported
#
# Example:
#   export SERVER_NAME="production"
#   mail_template_render_env "server_info"
################################################################################
mail_template_render_env() {
    local template_name="${1}"
    local template_set="${EMAIL_TEMPLATE_SET:-default}"
    local template_path="${BROLIT_MAIN_DIR}/templates/emails/${template_set}/${template_name}-tpl.html"

    if [[ ! -f "${template_path}" ]]; then
        log_event "error" "Template not found: ${template_path}" "false"
        return 1
    fi

    # Use envsubst for replacement (requires gettext package)
    if command -v envsubst >/dev/null 2>&1; then
        envsubst < "${template_path}"
    else
        # Fallback to manual replacement
        cat "${template_path}"
    fi
}

################################################################################
# Assemble complete email from sections
#
# Arguments:
#   $1 - Output file path
#   $2 - Main template name
#   $3+ - Section file paths to include
#
# Returns:
#   0 on success, 1+ on error
################################################################################
mail_template_assemble() {
    local output_file="${1}"
    local main_template="${2}"
    shift 2
    local sections=("$@")

    local template_set="${EMAIL_TEMPLATE_SET:-default}"
    local main_path="${BROLIT_MAIN_DIR}/templates/emails/${template_set}/${main_template}-tpl.html"

    if [[ ! -f "${main_path}" ]]; then
        log_event "error" "Main template not found: ${main_path}" "false"
        return 1
    fi

    # Load main template
    local result
    result="$(cat "${main_path}")"

    # Replace section placeholders
    local section_name section_content
    for section_file in "${sections[@]}"; do
        if [[ -f "${section_file}" ]]; then
            section_name="$(basename "${section_file}" .mail)"
            section_content="$(cat "${section_file}")"
            result="$(echo "${result}" | sed "s|{{${section_name}}}|${section_content}|g")"
        fi
    done

    # Remove unused placeholders
    result="$(echo "${result}" | sed 's|{{[^}]*}}||g')"

    echo "${result}" > "${output_file}"
}
```

#### 2.2 Refactor section functions

**Before** (`mail_server_status_section()` - 44 lines):
```bash
mail_server_status_section() {
    local email_template="default"
    html_server_info_details="$(cat "${BROLIT_MAIN_DIR}/templates/emails/${email_template}/server_info-tpl.html")"

    # 10+ sed operations...
    html_server_info_details="$(echo "${html_server_info_details}" | sed "s|{{server_name}}|${SERVER_NAME}|")"
    # ... 9 more sed calls

    echo "${html_server_info_details}" > "${mail_file}"
}
```

**After** (8 lines):
```bash
mail_server_status_section() {
    local mail_file="${1}"

    mail_template_render "server_info" \
        "server_name=${SERVER_NAME}" \
        "server_ip=${SERVER_IP}" \
        "server_uptime=${SYSTEM_UPTIME}" \
        "disk_usage=${DISK_USAGE}" \
        "status=${SERVER_STATUS}" \
        "status_badge=${status_badge}" > "${mail_file}"
}
```

**Code reduction**: ~80% (from 240 lines → 48 lines)

#### 2.3 Optimize HTML assembly

**Before** (backups_tasks.sh):
```bash
grep -v "{{server_info}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"
# x7 repetitions
```

**After**:
```bash
mail_template_assemble "${email_html_file}" "main" \
    "${server_info_mail}" \
    "${packages_mail}" \
    "${certificates_mail}" \
    "${databases_mail}" \
    "${files_mail}" \
    "${config_mail}" \
    "${footer_mail}"
```

**Benefits**:
- 1 I/O operation instead of 14
- More readable code
- Easy to extend

**Files to create**:
- `libs/local/mail_template_engine.sh`

**Files to modify**:
- `libs/local/mail_notification_helper.sh` (refactor 4 functions)
- `cron/backups_tasks.sh` (simplify assembly)
- `libs/local/backup_helper.sh` (update calls)

---

### Phase 3: Pattern Standardization (1-2 days)

#### 3.1 Support `notification_type` in `mail_send_notification()`

**Modify function signature** in `libs/local/mail_notification_helper.sh`:

```bash
################################################################################
# Mail send notification
#
# Arguments:
#   ${1} = ${email_subject}     // Email's subject
#   ${2} = ${email_content}     // Email's content (HTML)
#   ${3} = ${notification_type} // Optional: alert, warning, info, success
#
# Outputs:
#   0 if ok, 1 on error.
################################################################################
function mail_send_notification() {

    local email_subject="${1}"
    local email_content="${2}"
    local notification_type="${3:-info}"  # Default to 'info' if not specified

    # If content is NOT complete HTML, wrap in template based on type
    if [[ ! "${email_content}" =~ ^[[:space:]]*\< ]]; then
        # It is plain text, use template based on notification_type
        email_content="$(mail_template_render "notification-${notification_type}" \
            "title=${email_subject}" \
            "content=${email_content}")"
    fi

    # ... rest of the function (unchanged)
}
```

**Update controller** in `libs/notification_controller.sh:45`:

```bash
if [[ ${NOTIFICATION_EMAIL_STATUS} == "enabled" ]]; then
    mail_send_notification "${notification_title}" "${notification_content}" "${notification_type}"
fi
```

**Create templates by type** in `/templates/emails/default/`:
- `notification-alert-tpl.html` (red, error icons)
- `notification-warning-tpl.html` (yellow, warning icons)
- `notification-info-tpl.html` (blue, informational icons)
- `notification-success-tpl.html` (green, success icons)

#### 3.2 Unify notification format with helper functions

**Create high-level helpers** (optional, for better ergonomics):

```bash
# New file: libs/local/mail_notification_helpers.sh

################################################################################
# Send formatted alert email (wrapper for common use case)
#
# Arguments:
#   $1 - Alert title
#   $2 - Alert message
#   $3 - Alert level (alert|warning|info|success)
#   $4 - Optional: additional details (HTML)
################################################################################
mail_send_alert() {
    local alert_title="${1}"
    local alert_message="${2}"
    local alert_level="${3}"
    local alert_details="${4:-}"

    local full_content="${alert_message}"
    if [[ -n "${alert_details}" ]]; then
        full_content="${alert_message}<br><br>${alert_details}"
    fi

    mail_send_notification "${alert_title}" "${full_content}" "${alert_level}"
}

################################################################################
# Send formatted report email
#
# Arguments:
#   $1 - Report title
#   $2+ - Section file paths
################################################################################
mail_send_report() {
    local report_title="${1}"
    shift
    local sections=("$@")

    local report_file="${BROLIT_TMP_DIR}/report-${NOW}.html"

    mail_template_assemble "${report_file}" "report" "${sections[@]}"

    local report_html
    report_html="$(cat "${report_file}")"

    mail_send_notification "${report_title}" "${report_html}"

    rm -f "${report_file}"
}
```

**New templates**:
- `templates/emails/default/alert-tpl.html` (for alerts)
- `templates/emails/default/report-tpl.html` (for reports)

#### 3.2 Update calls across the codebase

**Before**:
```bash
send_notification "${SERVER_NAME}" "Website ${project_name} is offline" ""
```

**After**:
```bash
mail_send_alert \
    "${SERVER_NAME} - Website Offline" \
    "The website ${project_name} is currently unreachable" \
    "error" \
    "<p>Last check: ${timestamp}</p><p>URL: ${project_url}</p>"
```

**Files to modify**:
- `cron/uptime_tasks.sh`
- `cron/security_tasks.sh`
- `cron/wordpress_tasks.sh`
- `libs/local/restore_backup_helper.sh`

---

### Phase 4: Improved Configuration (1 day)

#### 4.1 Improved configuration schema

```json
{
  "NOTIFICATIONS": {
    "email": [
      {
        "status": "enabled",
        "template_set": "default",
        "config": [
          {
            "email_to": "admin@example.com",
            "from_email": "brolit@example.com",
            "smtp_server": "smtp.gmail.com",
            "smtp_port": "587",
            "smtp_tls": "yes",
            "smtp_user": "brolit@gmail.com",
            "smtp_user_pass": "app_password_here",

            // New optional fields
            "email_cc": "",
            "email_bcc": "",
            "email_reply_to": "",
            "max_attachment_size": "10M",
            "connection_timeout": "30"
          }
        ]
      }
    ]
  }
}
```

#### 4.2 Backward compatibility

```bash
# In _brolit_configuration_load_email()

# Try new field name first, fallback to old typo
NOTIFICATION_EMAIL_EMAIL_TO="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].email_to")"
if [[ -z "${NOTIFICATION_EMAIL_EMAIL_TO}" ]]; then
    NOTIFICATION_EMAIL_EMAIL_TO="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].maila")"
    log_event "warning" "Using deprecated config field 'maila', please update to 'email_to'" "false"
fi

# Load optional new fields
EMAIL_TEMPLATE_SET="$(json_read_field "${server_config_file}" "NOTIFICATIONS.email[].config[].template_set")"
EMAIL_TEMPLATE_SET="${EMAIL_TEMPLATE_SET:-default}"
export EMAIL_TEMPLATE_SET
```

**Files to modify**:
- `utils/brolit_configuration_manager.sh`
- `config/brolit/brolit_conf.json`

---

### Phase 5: Testing and Documentation (1-2 days)

#### 5.1 Unit tests

**New file**: `tests/mail_notification_test.sh`

```bash
#!/usr/bin/env bash

# Test template rendering
test_template_render() {
    local result
    result="$(mail_template_render "test" "var1=value1" "var2=value2")"

    if [[ "${result}" =~ "value1" ]] && [[ "${result}" =~ "value2" ]]; then
        echo "✓ Template render test passed"
        return 0
    else
        echo "✗ Template render test failed"
        return 1
    fi
}

# Test email assembly
test_email_assembly() {
    # Create mock sections
    echo "<div>Section 1</div>" > /tmp/section1.mail
    echo "<div>Section 2</div>" > /tmp/section2.mail

    mail_template_assemble "/tmp/result.html" "main" /tmp/section1.mail /tmp/section2.mail

    local result
    result="$(cat /tmp/result.html)"

    if [[ "${result}" =~ "Section 1" ]] && [[ "${result}" =~ "Section 2" ]]; then
        echo "✓ Email assembly test passed"
        return 0
    else
        echo "✗ Email assembly test failed"
        return 1
    fi
}

# Test configuration loading
test_config_loading() {
    _brolit_configuration_load_email

    if [[ -n "${NOTIFICATION_EMAIL_EMAIL_TO}" ]]; then
        echo "✓ Config loading test passed"
        return 0
    else
        echo "✗ Config loading test failed"
        return 1
    fi
}

# Run all tests
test_template_render
test_email_assembly
test_config_loading
```

#### 5.2 Documentation

**New file**: `docs/EMAIL_NOTIFICATIONS.md`

```markdown
# Email Notifications System

## Architecture

[Architecture diagram]

## Configuration

### Basic Setup

1. Edit `/root/.brolit_conf.json`
2. Configure SMTP settings
3. Enable notifications

[Configuration examples for Gmail, SendGrid, Mailgun, etc.]

## Custom Templates

### Creating a Custom Template Set

1. Copy `/templates/emails/default/` to `/templates/emails/custom/`
2. Edit HTML files
3. Update config: `"template_set": "custom"`

### Template Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `{{server_name}}` | Server hostname | `web-prod-01` |
| `{{server_ip}}` | Server IP | `192.168.1.10` |
...

## Troubleshooting

### Common Issues

**Problem**: Emails not sending
**Solution**: Check SMTP credentials, test with `sendEmail` directly

[More examples...]

## API Reference

### Functions

#### `mail_send_notification(subject, html_content)`
Sends an email notification...

[Complete function documentation...]
```

**Files to create**:
- `tests/mail_notification_test.sh`
- `docs/EMAIL_NOTIFICATIONS.md`
- `docs/EMAIL_TEMPLATES.md`
- `docs/SMTP_PROVIDERS.md`

---

## Improvement Metrics

| Metric | Before | After | Improvement |
|---------|-------|---------|--------|
| Lines of code (core) | 532 | ~350 | -34% |
| Duplicated code | 240 lines | 48 lines | -80% |
| I/O operations (assembly) | 14 | 1 | -93% |
| Functions with error handling | 1/8 | 8/8 | +700% |
| Configurable templates | No | Yes | ∞ |
| Temp files cleaned up | Partial | Always | 100% |
| Test coverage | 0% | 80% | +80% |

---

## Schedule

| Phase | Duration | Dependencies |
|------|----------|--------------|
| Phase 1: Critical fixes | 1-2 days | - |
| Phase 2: Template engine | 2-3 days | Phase 1 |
| Phase 3: Standardization | 1-2 days | Phase 2 |
| Phase 4: Improved configuration | 1 day | Phase 1 |
| Phase 5: Testing and docs | 1-2 days | Phases 1-4 |

**Estimated total**: 6-10 business days

---

## Migration Strategy

### 1. Backward compatibility
- Keep old functions as deprecated but functional
- Add warnings when old functions are used
- Transition period: 3 months

### 2. Gradual migration
```bash
# Add at the beginning of mail_notification_helper.sh
if [[ "${USE_NEW_EMAIL_SYSTEM:-true}" == "true" ]]; then
    source "${BROLIT_MAIN_DIR}/libs/local/mail_template_engine.sh"
    source "${BROLIT_MAIN_DIR}/libs/local/mail_notification_types.sh"
fi
```

### 3. Rollback plan
- Keep old code commented out
- Feature flag `USE_NEW_EMAIL_SYSTEM`
- Configuration backup before migration

---

## Risks and Mitigations

| Risk | Probability | Impact | Mitigation |
|--------|--------------|---------|------------|
| Breaking changes in production | Medium | High | Feature flags, exhaustive testing |
| Lost notifications during migration | Low | High | Dual sending (old + new) temporarily |
| Incompatible templates | Medium | Medium | Template validation on startup |
| envsubst dependency | Low | Low | Fallback to manual sed |
| Old incompatible config | High | Medium | Auto-migration + backward compatibility |

---

## Implementation Checklist

### Phase 1
- [ ] Fix typo `maila` → `email_to` with backward compatibility
- [ ] Add template validation in all functions
- [ ] Implement error return codes
- [ ] Create temporary file tracking system
- [ ] Implement trap for automatic cleanup
- [ ] Manual testing of fixes

### Phase 2
- [ ] Create `libs/local/mail_template_engine.sh`
- [ ] Implement `mail_template_render()`
- [ ] Implement `mail_template_assemble()`
- [ ] Refactor `mail_server_status_section()`
- [ ] Refactor `mail_package_status_section()`
- [ ] Refactor `mail_certificates_section()`
- [ ] Refactor `mail_backup_section()`
- [ ] Update `backups_tasks.sh` to use new assembly
- [ ] Test email generation

### Phase 3
- [ ] Create `libs/local/mail_notification_types.sh`
- [ ] Implement `mail_send_alert()`
- [ ] Implement `mail_send_report()`
- [ ] Create template `alert-tpl.html`
- [ ] Create template `report-tpl.html`
- [ ] Update `uptime_tasks.sh`
- [ ] Update `security_tasks.sh`
- [ ] Update `wordpress_tasks.sh`
- [ ] Update `restore_backup_helper.sh`
- [ ] Test all notification types

### Phase 4
- [ ] Update JSON schema with new fields
- [ ] Implement configurable `template_set` loading
- [ ] Add optional fields (CC, BCC, Reply-To)
- [ ] Configuration migration script
- [ ] Test configuration

### Phase 5
- [ ] Write unit tests
- [ ] Write architecture documentation
- [ ] Document SMTP configuration for common providers
- [ ] Document template system
- [ ] Create troubleshooting guide
- [ ] Create usage examples
- [ ] Complete code review
- [ ] End-to-end integration testing

---

## References

### Key Files of the Current System
- [libs/local/mail_notification_helper.sh](libs/local/mail_notification_helper.sh) - Core email system
- [libs/notification_controller.sh](libs/notification_controller.sh) - Notification dispatcher
- [utils/brolit_configuration_manager.sh](utils/brolit_configuration_manager.sh) - Config loader
- [cron/backups_tasks.sh](cron/backups_tasks.sh) - Main email usage

### External Tools
- sendEmail: https://github.com/mogaal/sendemail
- envsubst: gettext package
- jq: JSON processor

### Best Practices
- HTML Email Design: https://www.campaignmonitor.com/dev-resources/guides/
- SMTP Best Practices: https://www.socketlabs.com/blog/smtp-best-practices/
- Email Template Security: https://cheatsheetseries.owasp.org/cheatsheets/Email_Security_Cheat_Sheet.html

---

## 💡 Usage Example: Before vs After

### Scenario: Malware alert detected

#### BEFORE refactor

```bash
# In cron/security_tasks.sh
send_notification "${SERVER_NAME}" "Malware detected in ${project_name}" ""
```

**Current result**:

- Telegram: 🔴 Red message with alert emoji
- Discord: 🔴 Red embed with danger icon
- Email: 📧 Generic plain text email without formatting
- ntfy: 🔴 Notification with high priority

**Problem**: The email does not visually communicate the urgency.

#### AFTER refactor

```bash
# In cron/security_tasks.sh (no changes to the code!)
send_notification "${SERVER_NAME}" "Malware detected in ${project_name}" "alert"
```

**Improved result**:

- Telegram: 🔴 Red message with alert emoji
- Discord: 🔴 Red embed with danger icon
- **Email**: 🔴 **Red HTML email with alert icon and urgency styles**
- ntfy: 🔴 Notification with high priority

**Benefit**: Visual consistency across all channels, without changing existing code.

### Scenario: Backup report with multiple sections

#### BEFORE refactor

```bash
# In cron/backups_tasks.sh (lines 419-432)
grep -v "{{server_info}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"

grep -v "{{packages}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"

grep -v "{{certificates}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"

grep -v "{{databases}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"

grep -v "{{files}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"

grep -v "{{config}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"

grep -v "{{footer}}" "${email_html_file}" >"${email_html_file}_tmp"
mv "${email_html_file}_tmp" "${email_html_file}"
```

**Problems**: 14 I/O operations, 7 temporary files, slow, difficult to maintain.

#### AFTER refactor

```bash
# In cron/backups_tasks.sh
mail_template_assemble "${email_html_file}" "main" \
    "${server_info_mail}" \
    "${packages_mail}" \
    "${certificates_mail}" \
    "${databases_mail}" \
    "${files_mail}" \
    "${config_mail}" \
    "${footer_mail}"
```

**Benefits**: 1 I/O operation, faster, more readable, easy to extend.

---

## 🎯 Next Steps

1. **Review this plan** and approve/adjust as necessary
2. **Prioritize phases** (all or only critical?)
3. **Assign resources** (who will implement?)
4. **Define testing** (manual, automated, both?)
5. **Plan deployment** (staged rollout, feature flags?)

---

**Last updated**: 2025-11-26
**Author**: Claude (Anthropic)
**Status**: Proposed plan - Pending approval
